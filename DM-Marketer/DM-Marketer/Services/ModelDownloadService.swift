import Foundation

enum DownloadEvent {
    case progress(Double)   // 0.0 – 1.0
    case completed(URL)
    case failed(Error)
}

/// Thread-safe download manager. No @MainActor — delegate callbacks must move
/// the temp file synchronously before URLSession cleans it up.
final class ModelDownloadService: NSObject {
    static let shared = ModelDownloadService()

    /// Where downloaded .gguf files are stored. Same path used by LLMModel.modelsDirectory.
    static var modelsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private let lock = NSLock()
    private var continuations:    [String: AsyncStream<DownloadEvent>.Continuation] = [:]
    private var pendingFilenames: [String: String] = [:]

    private lazy var session: URLSession = {
        // delegateQueue nil → callbacks on URLSession's internal serial queue
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Public API

    func download(modelID: String, from urlString: String, filename: String) -> AsyncStream<DownloadEvent> {
        AsyncStream { continuation in
            guard let url = URL(string: urlString) else {
                continuation.yield(.failed(URLError(.badURL)))
                continuation.finish()
                return
            }
            lock.withLock {
                self.continuations[modelID]    = continuation
                self.pendingFilenames[modelID] = filename
            }
            let task = session.downloadTask(with: url)
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

        // ⚠️ Move the file SYNCHRONOUSLY right here.
        // URLSession deletes `location` the moment this method returns —
        // dispatching to another queue/actor means the file is already gone.
        let filename = lock.withLock { pendingFilenames[modelID] }
        guard let filename else { return }

        let dest = Self.modelsDirectory.appendingPathComponent(filename)
        let result: Result<URL, Error>
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: location, to: dest)
            result = .success(dest)
        } catch {
            result = .failure(error)
        }

        let continuation = lock.withLock {
            let c = continuations[modelID]
            continuations[modelID]    = nil
            pendingFilenames[modelID] = nil
            return c
        }

        switch result {
        case .success(let url): continuation?.yield(.completed(url))
        case .failure(let err): continuation?.yield(.failed(err))
        }
        continuation?.finish()
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
}
