import Foundation
import SwiftData

@Model
final class LLMModel {
    var id: String          // e.g. "gemma-3-1b-q4"
    var displayName: String
    var modelDescription: String
    var repoID: String      // HuggingFace repo
    var filename: String    // the .gguf filename
    var downloadURL: String
    var sizeBytes: Int64
    var parameterLabel: String  // "1B", "3.8B", etc.
    var quantLabel: String      // "Q4_K_M", "Q8_0", etc.
    var isDownloaded: Bool
    var isDefault: Bool
    var downloadedAt: Date?

    init(
        id: String,
        displayName: String,
        modelDescription: String,
        repoID: String,
        filename: String,
        downloadURL: String,
        sizeBytes: Int64,
        parameterLabel: String,
        quantLabel: String
    ) {
        self.id = id
        self.displayName = displayName
        self.modelDescription = modelDescription
        self.repoID = repoID
        self.filename = filename
        self.downloadURL = downloadURL
        self.sizeBytes = sizeBytes
        self.parameterLabel = parameterLabel
        self.quantLabel = quantLabel
        self.isDownloaded = false
        self.isDefault = false
    }

    var formattedSize: String {
        let gb = Double(sizeBytes) / 1_000_000_000
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(sizeBytes) / 1_000_000
        return String(format: "%.0f MB", mb)
    }

    var localURL: URL? {
        guard isDownloaded else { return nil }
        return LLMModel.modelsDirectory.appendingPathComponent(filename)
    }

    static var modelsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

// MARK: - Catalog

extension LLMModel {
    /// Hard-coded catalog of small GGUF models.
    /// Ordered from fastest to slowest. Models above 1B are too slow for iPhone 13 and older.
    static var catalog: [CatalogEntry] { [

        // MARK: Sub-500M — recommended for iPhone 13 and older

        CatalogEntry(
            id: "smollm2-135m-q4",
            displayName: "SmolLM2 135M",
            modelDescription: "Smallest available model. Generates in under a second on any iPhone. DM quality is simple but instant — good for trying the app.",
            repoID: "HuggingFaceTB/SmolLM2-135M-Instruct-GGUF",
            filename: "smollm2-135m-instruct-q4_k_m.gguf",
            downloadURL: "https://huggingface.co/HuggingFaceTB/SmolLM2-135M-Instruct-GGUF/resolve/main/smollm2-135m-instruct-q4_k_m.gguf",
            sizeBytes: 90_000_000,
            parameterLabel: "135M",
            quantLabel: "Q4_K_M"
        ),
        CatalogEntry(
            id: "smollm2-360m-q4",
            displayName: "SmolLM2 360M",
            modelDescription: "Best choice for iPhone 13 and older. Fast generation (2–4 seconds), good DM quality. Recommended starting point.",
            repoID: "HuggingFaceTB/SmolLM2-360M-Instruct-GGUF",
            filename: "smollm2-360m-instruct-q4_k_m.gguf",
            downloadURL: "https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q4_k_m.gguf",
            sizeBytes: 230_000_000,
            parameterLabel: "360M",
            quantLabel: "Q4_K_M"
        ),
        CatalogEntry(
            id: "qwen2.5-0.5b-q4",
            displayName: "Qwen 2.5 0.5B",
            modelDescription: "Alibaba's compact instruct model. Noticeably better writing than 360M, still smooth on iPhone 13. Good everyday choice.",
            repoID: "bartowski/Qwen2.5-0.5B-Instruct-GGUF",
            filename: "Qwen2.5-0.5B-Instruct-Q4_K_M.gguf",
            downloadURL: "https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf",
            sizeBytes: 395_000_000,
            parameterLabel: "0.5B",
            quantLabel: "Q4_K_M"
        ),

        // MARK: 1B — usable on iPhone 14 Pro+, slow on iPhone 13

        CatalogEntry(
            id: "gemma-3-1b-q4",
            displayName: "Gemma 3 1B",
            modelDescription: "Best DM quality in this catalog, but slow on iPhone 13 (15–30 sec/generation). Recommended for iPhone 14 Pro or newer.",
            repoID: "lmstudio-community/gemma-3-1b-it-GGUF",
            filename: "gemma-3-1b-it-Q4_K_M.gguf",
            downloadURL: "https://huggingface.co/lmstudio-community/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf",
            sizeBytes: 772_000_000,
            parameterLabel: "1B",
            quantLabel: "Q4_K_M"
        ),
    ] }

    struct CatalogEntry {
        let id: String
        let displayName: String
        let modelDescription: String
        let repoID: String
        let filename: String
        let downloadURL: String
        let sizeBytes: Int64
        let parameterLabel: String
        let quantLabel: String
    }
}
