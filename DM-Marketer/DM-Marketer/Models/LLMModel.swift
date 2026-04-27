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
    /// Hard-coded catalog of GGUF models, ordered fastest → slowest.
    static var catalog: [CatalogEntry] { [

        // MARK: Sub-500M — fast on all iPhones including iPhone 13

        CatalogEntry(
            id: "qwen2.5-0.5b-q4",
            displayName: "Qwen 2.5 0.5B",
            modelDescription: "Generates DMs in 2–4 seconds on any iPhone. Great quality for its size and the best place to start.",
            repoID: "bartowski/Qwen2.5-0.5B-Instruct-GGUF",
            filename: "Qwen2.5-0.5B-Instruct-Q4_K_M.gguf",
            downloadURL: "https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf",
            sizeBytes: 395_000_000,
            parameterLabel: "0.5B",
            quantLabel: "Q4_K_M",
            contextWindow: 4096,
            organization: "Alibaba",
            minimumRAMGB: 4
        ),

        // MARK: 1–2B — good on iPhone 14 Pro+, slow on iPhone 13

        CatalogEntry(
            id: "gemma-3-1b-q4",
            displayName: "Gemma 3 1B",
            modelDescription: "Excellent DM quality with stronger writing than 0.5B models. Takes 15–30 seconds on iPhone 13 — faster on iPhone 14 Pro and newer.",
            repoID: "lmstudio-community/gemma-3-1b-it-GGUF",
            filename: "gemma-3-1b-it-Q4_K_M.gguf",
            downloadURL: "https://huggingface.co/lmstudio-community/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf",
            sizeBytes: 772_000_000,
            parameterLabel: "1B",
            quantLabel: "Q4_K_M",
            contextWindow: 4096,
            organization: "Google",
            minimumRAMGB: 4
        ),
        CatalogEntry(
            id: "deepseek-r1-1.5b-q4",
            displayName: "DeepSeek R1 1.5B",
            modelDescription: "Reasoning model — thinks through the situation before writing, producing more deliberate and targeted DMs. Slow on iPhone 13, faster on iPhone 14 Pro and newer.",
            repoID: "bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF",
            filename: "DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf",
            downloadURL: "https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf",
            sizeBytes: 1_202_790_400,
            parameterLabel: "1.5B",
            quantLabel: "Q4_K_M",
            contextWindow: 4096,
            organization: "DeepSeek",
            minimumRAMGB: 4
        ),
        CatalogEntry(
            id: "qwen3.5-2b-q4",
            displayName: "Qwen 3.5 2B",
            modelDescription: "Strong instruction following and natural, fluent writing. Supports thinking mode for more deliberate DMs. Requires iPhone 14 Pro or newer for smooth performance.",
            repoID: "bartowski/Qwen_Qwen3.5-2B-GGUF",
            filename: "Qwen_Qwen3.5-2B-Q4_K_M.gguf",
            downloadURL: "https://huggingface.co/bartowski/Qwen_Qwen3.5-2B-GGUF/resolve/main/Qwen_Qwen3.5-2B-Q4_K_M.gguf",
            sizeBytes: 1_428_897_792,
            parameterLabel: "2B",
            quantLabel: "Q4_K_M",
            contextWindow: 4096,
            organization: "Alibaba",
            minimumRAMGB: 6
        ),

        // MARK: 2B MoE — requires iPhone 15 Pro or newer (8 GB RAM)

        CatalogEntry(
            id: "gemma-4-e2b-q4",
            displayName: "Gemma 4 E2B",
            modelDescription: "Google's newest model — a mixture-of-experts architecture with 2B active parameters. The highest DM quality in the catalog. The 3.7 GB weights require iPhone 15 Pro or newer.",
            repoID: "bartowski/google_gemma-4-E2B-it-GGUF",
            filename: "google_gemma-4-E2B-it-Q4_K_M.gguf",
            downloadURL: "https://huggingface.co/bartowski/google_gemma-4-E2B-it-GGUF/resolve/main/google_gemma-4-E2B-it-Q4_K_M.gguf",
            sizeBytes: 3_717_652_480,
            parameterLabel: "2B (MoE)",
            quantLabel: "Q4_K_M",
            contextWindow: 4096,
            organization: "Google",
            minimumRAMGB: 8
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
        let contextWindow: Int
        let organization: String
        /// Minimum device physical RAM (GB) required to load this model.
        let minimumRAMGB: Int

        var isCompatibleWithDevice: Bool {
            // physicalMemory on iPhone 13 is ~3.74 GB — round to nearest GB before comparing.
            let roundedGB = (ProcessInfo.processInfo.physicalMemory + 500_000_000) / 1_000_000_000
            return roundedGB >= UInt64(minimumRAMGB)
        }
    }

    /// Returns the context window (n_ctx) for a given model filename, falling back to 2048.
    static func contextWindow(forFilename filename: String) -> Int {
        catalog.first { $0.filename == filename }?.contextWindow ?? 2048
    }
}
