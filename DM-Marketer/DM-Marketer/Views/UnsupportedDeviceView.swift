import SwiftUI
import FoundationModels

/// Shown instead of the app when Apple Intelligence can't write on this device.
struct UnsupportedDeviceView: View {
    let reason: SystemLanguageModel.Availability.UnavailableReason

    var body: some View {
        VStack(spacing: 20) {
            DropletMascot(size: 90)
            Text(title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if reason != .deviceNotEligible {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch reason {
        case .deviceNotEligible:         "This iPhone can't run DM Marketer"
        case .appleIntelligenceNotEnabled: "Turn on Apple Intelligence"
        case .modelNotReady:             "Apple Intelligence is still getting ready"
        @unknown default:                "Apple Intelligence isn't available"
        }
    }

    private var message: String {
        switch reason {
        case .deviceNotEligible:
            "DM Marketer writes with Apple Intelligence, which runs on iPhone 15 Pro and newer. Your messages and context never leave your phone."
        case .appleIntelligenceNotEnabled:
            "Go to Settings → Apple Intelligence & Siri and switch it on. Everything stays on your device."
        case .modelNotReady:
            "The on-device model is still downloading. Try again in a few minutes."
        @unknown default:
            "Check Settings → Apple Intelligence & Siri."
        }
    }
}
