import Foundation

enum DownloadEvent {
    case progress(Double)   // 0.0 – 1.0
    case completed
    case failed(Error)
}

/// Thread-safe download manager using a background URLSession so downloads
/// continue even when the app is suspended or killed by the OS.
final class ModelDownloadService: NSObject {
    static let shared = ModelDownloadService()

    /// Where downloaded .gguf files are stored. Matches LLMModel.modelsDirectory.
    static var modelsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Set by AppDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:).
    /// Must be called on the main queue after all background events are handled.
    var backgroundCompletionHandler: (() -> Void)?

    private let lock = NSLock()
    private var continuations: [String: AsyncStream<DownloadEvent>.Continuation] = [:]

    // pendingFilenames is persisted to UserDefaults so the modelID→filename
    // mapping survives app restarts (the background daemon keeps the task alive).
    private static let pendingKey = "com.alikhundmiri.dm-marketer.pendingDownloads"
    private var pendingFilenames: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: Self.pendingKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Self.pendingKey) }
    }

    // Background URLSession — the OS keeps downloads running even after the app is killed.
    // Using the same identifier reconnects to in-progress tasks on relaunch.
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.alikhundmiri.dm-marketer.download"
        )
        config.sessionSendsLaunchEvents = true   // iOS can relaunch app when download finishes
        config.isDiscretionary = false           // don't defer to low-power/low-traffic windows
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Public API

    /// Call once at app launch to reconnect to any background tasks that survived a restart.
    func reconnect() { _ = session }

    func download(modelID: String, from urlString: String, filename: String) -> AsyncStream<DownloadEvent> {
        AsyncStream { continuation in
            guard let url = URL(string: urlString) else {
                continuation.yield(.failed(URLError(.badURL)))
                continuation.finish()
                return
            }
            self.lock.withLock {
                self.continuations[modelID] = continuation
                var pending = self.pendingFilenames
                pending[modelID] = filename
                self.pendingFilenames = pending
            }
            let task = self.session.downloadTask(with: url)
            task.taskDescription = modelID
            task.resume()
        }
    }

    func cancel(modelID: String) {
        lock.withLock {
            continuations[modelID]?.finish()
            continuations[modelID] = nil
        }
    }

    func deleteModel(filename: String) throws {
        let url = Self.modelsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadService: URLSessionDownloadDelegate {

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let modelID = downloadTask.taskDescription else { return }
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        lock.withLock { continuations[modelID] }?.yield(.progress(progress))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let modelID = downloadTask.taskDescription else { return }

        // Recover the filename — may come from UserDefaults if the app was relaunched.
        let filename = lock.withLock { pendingFilenames[modelID] }
        guard let filename else { return }

        // ⚠️ Move SYNCHRONOUSLY — URLSession deletes `location` the moment this returns.
        let dest = Self.modelsDirectory.appendingPathComponent(filename)
        let moveResult: Result<Void, Error>
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: location, to: dest)
            moveResult = .success(())
        } catch {
            moveResult = .failure(error)
        }

        // Clean up persisted state and grab the continuation (may be nil after relaunch).
        let continuation = lock.withLock {
            var pending = self.pendingFilenames
            pending.removeValue(forKey: modelID)
            self.pendingFilenames = pending
            let c = continuations[modelID]
            continuations[modelID] = nil
            return c
        }

        switch moveResult {
        case .success:
            continuation?.yield(.completed)
            continuation?.finish()
            // If the app was relaunched from background there's no live continuation.
            // ModelsView.reconcileDownloads() will detect the file on next appear.
        case .failure(let error):
            continuation?.yield(.failed(error))
            continuation?.finish()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let modelID = task.taskDescription else { return }
        let continuation = lock.withLock {
            let c = continuations[modelID]
            continuations[modelID] = nil
            return c
        }
        continuation?.yield(.failed(error))
        continuation?.finish()
    }

    /// Called when all background events have been delivered.
    /// Must invoke backgroundCompletionHandler so iOS knows we're done.
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
