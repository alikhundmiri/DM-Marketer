import SwiftUI
import SwiftData

struct ModelsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var savedModels: [LLMModel]

    private let downloader = ModelDownloadService.shared

    @State private var downloadProgress: [String: Double] = [:]
    @State private var downloadingIDs: Set<String> = []
    @State private var downloadErrors: [String: String] = [:]
    @State private var entryPendingDelete: LLMModel.CatalogEntry?

    private var deviceRAMGB: Int {
        // Round to nearest GB — physicalMemory on iPhone 13 is ~3.74 GB, which rounds to 4.
        Int((ProcessInfo.processInfo.physicalMemory + 500_000_000) / 1_000_000_000)
    }

    private var compatibleModels: [LLMModel.CatalogEntry] {
        LLMModel.catalog.filter { $0.minimumRAMGB <= deviceRAMGB }
    }

    private var incompatibleModels: [LLMModel.CatalogEntry] {
        LLMModel.catalog.filter { $0.minimumRAMGB > deviceRAMGB }
    }

    var body: some View {
        NavigationStack {
            List {
                deviceSection
                modelSection(title: "Works on your iPhone", entries: compatibleModels)
                if !incompatibleModels.isEmpty {
                    modelSection(title: "Requires more RAM", entries: incompatibleModels)
                }
                footerSection
            }
            .listSectionSpacing(8)
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.large)
            .task { reconcileDownloads() }
            .confirmationDialog(
                "Delete model?",
                isPresented: Binding(
                    get: { entryPendingDelete != nil },
                    set: { if !$0 { entryPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let entry = entryPendingDelete {
                    Button("Delete \(entry.displayName) (\(formatBytes(entry.sizeBytes)))", role: .destructive) {
                        confirmDelete(entry)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This model will be removed from your device. You can re-download it later.")
            }
        }
    }

    // MARK: - Sections

    private var deviceSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "memorychip.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your iPhone")
                        .font(.subheadline.weight(.medium))
                    Text("\(deviceRAMGB) GB RAM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let active = savedModels.first(where: { $0.isDefault && $0.isDownloaded }) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Active model")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(active.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("No model active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func modelSection(title: String, entries: [LLMModel.CatalogEntry]) -> some View {
        Section(title) {
            ForEach(entries, id: \.id) { entry in
                let saved = savedModels.first { $0.id == entry.id }
                ModelRow(
                    entry: entry,
                    saved: saved,
                    isDownloading: downloadingIDs.contains(entry.id),
                    progress: downloadProgress[entry.id] ?? 0,
                    error: downloadErrors[entry.id],
                    onDownload:   { startDownload(entry) },
                    onSetDefault: { setDefault(entry.id) },
                    onDelete:     { entryPendingDelete = entry }
                )
            }
        }
    }

    private var footerSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.secondary)
                Text("All inference runs 100% on-device. No data ever leaves your phone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Actions

    private func reconcileDownloads() {
        let validFilenames = Set(LLMModel.catalog.map { $0.filename })
        if let files = try? FileManager.default.contentsOfDirectory(atPath: ModelDownloadService.modelsDirectory.path) {
            for file in files where file.hasSuffix(".gguf") && !validFilenames.contains(file) {
                try? FileManager.default.removeItem(at: ModelDownloadService.modelsDirectory.appendingPathComponent(file))
            }
        }

        for saved in savedModels where saved.isDownloaded {
            if let entry = LLMModel.catalog.first(where: { $0.id == saved.id }) {
                let fileURL = ModelDownloadService.modelsDirectory.appendingPathComponent(entry.filename)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    saved.isDownloaded = false
                    saved.downloadedAt = nil
                    if saved.isDefault { saved.isDefault = false }
                }
            }
        }

        for entry in LLMModel.catalog {
            let fileURL = ModelDownloadService.modelsDirectory.appendingPathComponent(entry.filename)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }

            if let saved = savedModels.first(where: { $0.id == entry.id }) {
                if !saved.isDownloaded {
                    saved.isDownloaded = true
                    saved.downloadedAt = Date()
                }
            } else {
                let new = LLMModel(
                    id: entry.id, displayName: entry.displayName,
                    modelDescription: entry.modelDescription, repoID: entry.repoID,
                    filename: entry.filename, downloadURL: entry.downloadURL,
                    sizeBytes: entry.sizeBytes, parameterLabel: entry.parameterLabel,
                    quantLabel: entry.quantLabel
                )
                new.isDownloaded = true
                new.downloadedAt = Date()
                modelContext.insert(new)
            }
        }
        if savedModels.filter({ $0.isDefault }).isEmpty,
           let first = savedModels.first(where: { $0.isDownloaded }) {
            first.isDefault = true
            if let url = first.localURL, !appState.isModelLoaded {
                Task { await appState.loadModel(at: url, displayName: first.displayName) }
            }
        }
    }

    private func startDownload(_ entry: LLMModel.CatalogEntry) {
        downloadingIDs.insert(entry.id)
        downloadProgress[entry.id] = 0
        downloadErrors[entry.id] = nil

        Task {
            let stream = downloader.download(modelID: entry.id, from: entry.downloadURL, filename: entry.filename)
            for await event in stream {
                switch event {
                case .progress(let p):
                    downloadProgress[entry.id] = p
                case .completed:
                    downloadingIDs.remove(entry.id)
                    let record: LLMModel
                    if let existing = savedModels.first(where: { $0.id == entry.id }) {
                        existing.isDownloaded = true
                        existing.downloadedAt = Date()
                        record = existing
                    } else {
                        let new = LLMModel(
                            id: entry.id, displayName: entry.displayName,
                            modelDescription: entry.modelDescription, repoID: entry.repoID,
                            filename: entry.filename, downloadURL: entry.downloadURL,
                            sizeBytes: entry.sizeBytes, parameterLabel: entry.parameterLabel,
                            quantLabel: entry.quantLabel
                        )
                        new.isDownloaded = true
                        new.downloadedAt = Date()
                        modelContext.insert(new)
                        record = new
                    }
                    if savedModels.filter({ $0.isDefault }).isEmpty {
                        record.isDefault = true
                        if let url = record.localURL {
                            await appState.loadModel(at: url, displayName: record.displayName)
                        }
                    }
                case .failed(let error):
                    downloadingIDs.remove(entry.id)
                    downloadErrors[entry.id] = error.localizedDescription
                }
            }
        }
    }

    private func setDefault(_ id: String) {
        savedModels.forEach { $0.isDefault = false }
        if let model = savedModels.first(where: { $0.id == id }), let url = model.localURL {
            model.isDefault = true
            Task { await appState.loadModel(at: url, displayName: model.displayName) }
        }
    }

    private func confirmDelete(_ entry: LLMModel.CatalogEntry) {
        let wasDefault = savedModels.first(where: { $0.id == entry.id })?.isDefault == true
        try? downloader.deleteModel(filename: entry.filename)
        if let saved = savedModels.first(where: { $0.id == entry.id }) {
            modelContext.delete(saved)
        }
        if wasDefault { appState.unloadModel() }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(bytes) / 1_000_000)
    }
}

// MARK: - ModelRow

private struct ModelRow: View {
    let entry: LLMModel.CatalogEntry
    let saved: LLMModel?
    let isDownloading: Bool
    let progress: Double
    let error: String?
    let onDownload: () -> Void
    let onSetDefault: () -> Void
    let onDelete: () -> Void

    private var isDownloaded: Bool { saved?.isDownloaded == true }
    private var isDefault: Bool { saved?.isDefault == true }
    private var isCompatible: Bool { entry.isCompatibleWithDevice }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                OrgBadge(organization: entry.organization)
                    .opacity(isCompatible ? 1 : 0.5)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.displayName)
                            .font(.headline)
                            .foregroundStyle(isCompatible ? .primary : .secondary)
                        if isDefault {
                            Text("ACTIVE")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    // Stats row
                    HStack(spacing: 5) {
                        Text(entry.parameterLabel)
                        Text("·")
                        Text(entry.quantLabel)
                        Text("·")
                        Text(formatBytes(entry.sizeBytes))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                    Text("by \(entry.organization)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
                actionButton
            }

            // Description
            Text(entry.modelDescription)
                .font(.caption)
                .foregroundStyle(isCompatible ? .secondary : Color(.tertiaryLabel))
                .fixedSize(horizontal: false, vertical: true)

            // Tags
            HStack(spacing: 6) {
                compatibilityTag
                if isCompatible { speedTag }
            }

            // Download progress
            if isDownloading {
                VStack(alignment: .leading, spacing: 3) {
                    ProgressView(value: progress)
                        .tint(Color.cfCyan)
                    Text(String(format: "%.0f%%  of  %@", progress * 100, formatBytes(entry.sizeBytes)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if isDownloaded && !isDefault {
                Button("Set as Active Model", action: onSetDefault)
                    .font(.caption.weight(.medium))
                    .buttonStyle(.bordered)
                    .tint(Color.cfCyan)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var actionButton: some View {
        if !isCompatible {
            VStack(alignment: .center, spacing: 3) {
                Image(systemName: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(.tertiaryLabel))
                Text("Needs \(entry.minimumRAMGB) GB")
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        } else if isDownloading {
            ProgressView().controlSize(.small)
        } else if isDownloaded {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        } else {
            Button(action: onDownload) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cfCyan, .cfBlue],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var compatibilityTag: some View {
        if isCompatible {
            Label("Works on your iPhone", systemImage: "checkmark.circle.fill")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Color.cfCyan.opacity(0.1))
                .foregroundStyle(Color.cfCyan)
                .clipShape(Capsule())
        } else {
            Label("Requires \(entry.minimumRAMGB) GB RAM", systemImage: "memorychip")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var speedTag: some View {
        let (label, icon, color) = speedInfo
        Label(label, systemImage: icon)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var speedInfo: (String, String, Color) {
        let deviceGB = (ProcessInfo.processInfo.physicalMemory + 500_000_000) / 1_000_000_000

        if entry.sizeBytes < 500_000_000 {
            return ("Fast on your iPhone", "bolt.fill", .cfCyan)
        }
        if deviceGB >= 6 {
            return ("Fast on your iPhone", "bolt.fill", .cfCyan)
        } else {
            return ("May be slow on your iPhone", "tortoise.fill", .orange)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(bytes) / 1_000_000)
    }
}

// MARK: - Org Badge

private struct OrgBadge: View {
    let organization: String

    var body: some View {
        Text(String(organization.prefix(1)))
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(badgeColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var badgeColor: Color {
        switch organization {
        case "Alibaba":  return Color(red: 1.0, green: 0.42, blue: 0.0)
        case "Google":   return Color(red: 0.26, green: 0.52, blue: 0.96)
        case "DeepSeek": return Color(red: 0.13, green: 0.7, blue: 0.67)
        default:         return .gray
        }
    }
}
