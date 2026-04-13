import UIKit
import UniformTypeIdentifiers

/// Minimal share extension entry point.
/// Extracts the shared post text + URL, detects the source platform,
/// then hands everything to the main app via the dmmarketer:// URL scheme.
/// No SwiftData, no SwiftUI — keeps the extension binary tiny.
class ShareViewController: UIViewController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground
        showLoadingUI()
        extractSharedContent { [weak self] text, sourceURL, platform in
            DispatchQueue.main.async {
                self?.openMainApp(text: text, sourceURL: sourceURL, platform: platform)
            }
        }
    }

    // MARK: - Loading UI

    private func showLoadingUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "ellipsis.bubble.fill"))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 44).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let label = UILabel()
        label.text = "Opening DM Marketer…"
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .label

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(label)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Content extraction

    private func extractSharedContent(completion: @escaping (String, String, String) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            completion("", "", "other")
            return
        }

        let group = DispatchGroup()
        var extractedText = ""
        var extractedURL  = ""
        var platform      = "other"

        // Grab plain text
        if let provider = item.attachments?.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                extractedText = (item as? String) ?? ""
                group.leave()
            }
        }

        // Grab URL (for platform detection)
        if let provider = item.attachments?.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                if let url = item as? URL {
                    extractedURL = url.absoluteString
                    let host = url.host ?? ""
                    if host.contains("twitter") || host.contains("x.com")  { platform = "Twitter / X" }
                    else if host.contains("linkedin")                       { platform = "LinkedIn" }
                    else if host.contains("reddit")                         { platform = "Reddit" }
                }
                group.leave()
            }
        }

        group.notify(queue: .global()) {
            completion(extractedText, extractedURL, platform)
        }
    }

    // MARK: - Open main app

    private func openMainApp(text: String, sourceURL: String, platform: String) {
        // Encode the post into a dmmarketer://share URL.
        // The main app reads these query params and shows the topic picker.
        var components = URLComponents()
        components.scheme   = "dmmarketer"
        components.host     = "share"
        components.queryItems = [
            URLQueryItem(name: "text",     value: String(text.prefix(2000))),
            URLQueryItem(name: "url",      value: sourceURL),
            URLQueryItem(name: "platform", value: platform),
        ]

        guard let url = components.url else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        extensionContext?.open(url) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
