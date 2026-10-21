import Foundation

// Compiled into both the app and the Share Extension.

/// X's share sheet hands over only a link, so we fetch the text ourselves.
///
/// FxTwitter (third-party, keyless) gives the thread parents and quoted post;
/// X's own oEmbed endpoint is the fallback and only returns the single post.
nonisolated enum TweetFetcher {

    static func isTweetURL(_ url: URL) -> Bool {
        statusID(url) != nil
    }

    static func statusID(_ url: URL) -> String? {
        guard let host = url.host?.lowercased(),
              host.hasSuffix("x.com") || host.hasSuffix("twitter.com") else { return nil }
        let parts = url.pathComponents
        guard let i = parts.firstIndex(of: "status"), i + 1 < parts.count else { return nil }
        let id = parts[i + 1]
        return id.allSatisfy(\.isNumber) ? id : nil
    }

    /// Fetches the post, up to `maxParents` earlier posts in its thread, and any quoted post.
    static func fetch(_ url: URL, maxParents: Int = 6) async throws -> PostContext {
        guard let id = statusID(url) else { throw URLError(.badURL) }
        do {
            return try await fetchFx(id: id, url: url, maxParents: maxParents)
        } catch {
            return try await fetchOEmbed(url: url)
        }
    }

    // MARK: FxTwitter

    private struct FxResponse: Decodable { let tweet: FxTweet? }
    private struct FxAuthor: Decodable { let name: String; let screenName: String }
    private struct FxQuote: Decodable { let text: String; let author: FxAuthor }
    private struct FxTweet: Decodable {
        let text: String
        let author: FxAuthor
        let replyingToStatus: String?
        let quote: FxQuote?
    }

    private static func fxTweet(_ id: String) async throws -> FxTweet {
        var request = URLRequest(url: URL(string: "https://api.fxtwitter.com/status/\(id)")!)
        request.setValue("ColdFlow-iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let tweet = try decoder.decode(FxResponse.self, from: data).tweet else {
            throw URLError(.cannotParseResponse)
        }
        return tweet
    }

    private static func fetchFx(id: String, url: URL, maxParents: Int) async throws -> PostContext {
        let tweet = try await fxTweet(id)

        // Walk up the reply chain. A failed parent just ends the walk.
        var thread: [PostContext.Post] = []
        var parentID = tweet.replyingToStatus
        while let pid = parentID, thread.count < maxParents,
              let parent = try? await fxTweet(pid) {
            thread.insert(post(parent.author, parent.text), at: 0)
            parentID = parent.replyingToStatus
        }

        return PostContext(
            url: url.absoluteString,
            platform: "Twitter / X",
            thread: thread,
            target: post(tweet.author, tweet.text),
            quoted: tweet.quote.map { post($0.author, $0.text) }
        )
    }

    private static func post(_ author: FxAuthor, _ text: String) -> PostContext.Post {
        PostContext.Post(name: author.name, handle: author.screenName, text: clean(text))
    }

    // MARK: oEmbed fallback

    private static func fetchOEmbed(url: URL) async throws -> PostContext {
        var comps = URLComponents(string: "https://publish.x.com/oembed")!
        comps.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(name: "omit_script", value: "1"),
        ]
        var request = URLRequest(url: comps.url!)
        request.timeoutInterval = 8
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let text = embedText(json?["html"] as? String ?? "")
        guard !text.isEmpty else { throw URLError(.cannotParseResponse) }
        let handle = (json?["author_url"] as? String).flatMap { URL(string: $0)?.lastPathComponent } ?? ""
        return PostContext(
            url: url.absoluteString,
            platform: "Twitter / X",
            thread: [],
            target: PostContext.Post(name: json?["author_name"] as? String ?? "", handle: handle, text: clean(text)),
            quoted: nil
        )
    }

    static func embedText(_ html: String) -> String {
        guard let open = html.range(of: "<p"),
              let gt = html.range(of: ">", range: open.upperBound..<html.endIndex),
              let close = html.range(of: "</p>", range: gt.upperBound..<html.endIndex)
        else { return "" }
        var s = String(html[gt.upperBound..<close.lowerBound])
        s = s.replacingOccurrences(of: "<br>", with: "\n")
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (entity, char) in ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&mdash;": "—"] {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        return s
    }

    // MARK: Cleanup

    /// Drops leading reply mentions ("@a @b actual text") and t.co links — noise for the model.
    static func clean(_ text: String) -> String {
        var s = text.replacingOccurrences(of: #"^(?:@\w+\s+)+"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"https://t\.co/\w+"#, with: "", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
