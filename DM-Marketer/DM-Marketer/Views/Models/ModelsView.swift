import SwiftUI
import SwiftData

struct ModelsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var savedModels: [LLMModel]

    private let downloader = ModelDownloadService.shared

    // Download state (ephemeral, not persisted)
    @State private var downloadProgress: [String: Double] = [:]
    @State private var downloadingIDs: Set<String> = []
    @State private var downloadErrors: [String: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                activeModelSection
                catalogSection
                footerSection
            }
            .navigationTitle("Models")
            .confirmationDialog(
                "Delete model?",
                isPresented: Binding(
                    get: { entryPendingDelete != nil },
                    set: { if !$0 { entryPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let entry = entryPendingDelete {
                    Button("Delete \(entry.displayName) (\(formatSize(entry.sizeBytes)))", role: .destructive) {
                        confirmDelete(entry)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This model file will be removed from your device. You can re-download it later.")
            }
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(bytes) / 1_000_000)
    }

    // MARK: - Sections

    @ViewBuilder
    private var activeModelSection: some View {
        if let activeModel = savedModels.first(where: { $0.isDefault && $0.isDownloaded }) {
            Section("Active Model") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeModel.displayName)
                            .font(.headline)
                        Text("\(activeModel.parameterLabel) · \(activeModel.quantLabel) · \(activeModel.formattedSize)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var catalogSection: some View {
        Section("Available Models") {
            ForEach(LLMModel.catalog, id: \.id) { entry in
                let saved = savedModels.first { $0.id == entry.id }
                ModelRow(
                    entry: entry,
                    saved: saved,
                    isDownloading: downloadingIDs.contains(entry.id),
                    progress: downloadProgress[entry.id] ?? 0,
                    error: downloadErrors[entry.id],
                    onDownload:   { startDownload(entry) },
                    onSetDefault: { setDefault(entry.id) },
                    onDelete:     { deleteModel(entry) }
                )
            }
        }
    }

    private var footerSection: some View {
        Section {
            Text("Models are stored locally — all inference runs 100% on-device. No data leaves your phone.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func startDownload(_ entry: LLMModel.CatalogEntry) {
        downloadingIDs.insert(entry.id)
        downloadProgress[entry.id] = 0
        downloadErrors[entry.id] = nil

        Task {
            let stream = downloader.download(
                modelID: entry.id,
                from: entry.downloadURL,
                filename: entry.filename
            )
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
                            id: entry.id,
                            displayName: entry.displayName,
                            modelDescription: entry.modelDescription,
                            repoID: entry.repoID,
                            filename: entry.filename,
                            downloadURL: entry.downloadURL,
                            sizeBytes: entry.sizeBytes,
                            parameterLabel: entry.parameterLabel,
                            quantLabel: entry.quantLabel
                        )
                        new.isDownloaded = true
                        new.downloadedAt = Date()
                        modelContext.insert(new)
                        record = new
                    }
                    // Auto-set as default and load if none is set yet
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
        if let model = savedModels.first(where: { $0.id == id }),
           let url = model.localURL {
            model.isDefault = true
            Task {
                await appState.loadModel(at: url, displayName: model.displayName)
            }
        }
    }

    @State private var entryPendingDelete: LLMModel.CatalogEntry?

    private func deleteModel(_ entry: LLMModel.CatalogEntry) {
        entryPendingDelete = entry
    }

    private func confirmDelete(_ entry: LLMModel.CatalogEntry) {
        let wasDefault = savedModels.first(where: { $0.id == entry.id })?.isDefault == true
        try? downloader.deleteModel(filename: entry.filename)
        if let saved = savedModels.first(where: { $0.id == entry.id }) {
            modelContext.delete(saved)
        }
        if wasDefault {
            appState.unloadModel()
        }
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
    private var isDefault:    Bool { saved?.isDefault == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.displayName)
                            .font(.headline)
                        if isDefault {
                            Text("DEFAULT")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text("\(entry.parameterLabel) · \(entry.quantLabel) · \(formatSize(entry.sizeBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                actionButton
            }

            Text(entry.modelDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            if isDownloading {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: progress)
                    Text(String(format: "%.0f%%", progress * 100))
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
                Button("Set as Default", action: onSetDefault)
                    .font(.caption.weight(.medium))
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButton: some View {
        if isDownloading {
            ProgressView().controlSize(.small)
        } else if isDownloaded {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        } else {
            Button(action: onDownload) {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(bytes) / 1_000_000)
    }
}
