import SwiftUI
import StoreKit

/// Shown when the free drafts run out, and from the "Unlock" bar at any time.
struct PaywallView: View {
    @Environment(PurchaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                DropletMascot(size: 90)
                Text(DraftQuota.remaining == 0 ? "You've used your free drafts" : "Unlock DM Marketer")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 10) {
                    Label("Unlimited drafts", systemImage: "infinity")
                    Label("Written on your phone with Apple Intelligence", systemImage: "iphone")
                    Label("Your context never leaves your device", systemImage: "lock.fill")
                    Label("Pay once. No subscription.", systemImage: "checkmark.seal.fill")
                }
                .foregroundStyle(.secondary)
                Spacer()
                if let error = store.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Button {
                    Task { await store.buy() }
                } label: {
                    Group {
                        if store.isWorking {
                            ProgressView().tint(.white)
                        } else {
                            Text(store.product.map { "Unlock for \($0.displayPrice)" } ?? "Unlock")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(LinearGradient.cfPrimary, in: Capsule())
                }
                .disabled(store.product == nil || store.isWorking)
                Button("Restore purchase") { Task { await store.restore() } }
                    .font(.subheadline)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
            }
            .onChange(of: store.isUnlocked) { _, unlocked in
                if unlocked { dismiss() }
            }
        }
    }
}

/// Small bar at the bottom of the Topics list: drafts left, or nothing once unlocked.
struct QuotaBar: View {
    @Environment(PurchaseStore.self) private var store
    @State private var showingPaywall = false

    var body: some View {
        if !store.isUnlocked {
            Button { showingPaywall = true } label: {
                HStack {
                    Text("\(DraftQuota.remaining) of \(DraftQuota.freeLimit) free drafts left")
                    Spacer()
                    Text("Unlock").fontWeight(.semibold)
                }
                .font(.footnote)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingPaywall) { PaywallView() }
        }
    }
}
