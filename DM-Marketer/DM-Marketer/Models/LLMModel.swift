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
    /// Hard-coded catalog of small GGUF models that run on iPhone.
    /// These are the model IDs — the app checks which ones are in SwiftData and syncs.
    static var catalog: [CatalogEntry] { [
        CatalogEntry(
            id: "gemma-3-1b-q4",
            displayName: "Gemma 3 1B",
            modelDescription: "Google's fastest on-device model. Great for quick DM drafts with minimal battery impact.",
            repoID: "lmstudio-community/gemma-3-1b-it-GGUF",
            filename: "gemma-3-1b-it-Q4_K_M.gguf",
            downloadURL: "https://huggingface.co/lmstudio-community/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf",
            sizeBytes: 772_000_000,
            parameterLabel: "1B",
            quantLabel: "Q4_K_M"
        ),
        CatalogEntry(
            id: "llama-3.2-1b-q8",
            displayName: "Llama 3.2 1B",
            modelDescription: "Meta's compact 1B model. Good balance of speed and quality for personalized outreach.",
            repoID: "bartowski/Llama-3.2-1B-Instruct-GGUF",
            filename: "Llama-3.2-1B-Instruct-Q8_0.gguf",
            downloadURL: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q8_0.gguf",
            sizeBytes: 1_321_000_000,
            parameterLabel: "1B",
            quantLabel: "Q8_0"
        ),
        CatalogEntry(
            id: "smollm2-1.7b-q4",
            displayName: "SmolLM2 1.7B",
            modelDescription: "HuggingFace's small but capable instruct model. Excellent for short, punchy DMs.",
            repoID: "HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF",
            filename: "smollm2-1.7b-instruct-q4_k_m.gguf",
            downloadURL: "https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf",
            sizeBytes: 1_040_000_000,
            parameterLabel: "1.7B",
            quantLabel: "Q4_K_M"
        ),
        CatalogEntry(
            id: "phi-3-mini-q4",
            displayName: "Phi-3 Mini 3.8B",
            modelDescription: "Microsoft's efficient 3.8B model. Noticeably better DM quality — worth the extra size.",
            repoID: "microsoft/Phi-3-mini-4k-instruct-gguf",
            filename: "Phi-3-mini-4k-instruct-q4.gguf",
            downloadURL: "https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf",
            sizeBytes: 2_176_000_000,
            parameterLabel: "3.8B",
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
