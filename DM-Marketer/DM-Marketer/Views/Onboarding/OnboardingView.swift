import SwiftUI
import SwiftData

/// First-run flow: what the app is, what it needs, then set up the two cards it writes from.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var topics: [Topic]
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage(VoiceCardStore.key, store: VoiceCardStore.defaults) private var voice = ""

    @State private var page = 0
    @State private var name = ""
    @State private var what = ""
    @State private var link = ""

    private let lastPage = 4
    private var canSaveTopic: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !what.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                infoPage(
                    mascot: true,
                    title: "Reply to the right post in 20 seconds",
                    text: "Find someone with a problem you solve. Share their post to DM Marketer. Get a reply that sounds like you."
                ).tag(0)

                infoPage(
                    icon: "square.and.arrow.up",
                    title: "It lives in your share sheet",
                    text: "In X or Safari, tap Share, then DM Marketer. If you don't see it, scroll right, tap More, and pin it. Copy the draft, then paste it into your reply."
                ).tag(1)

                infoPage(
                    icon: "lock.iphone",
                    title: "Private, and made for one post at a time",
                    text: "Needs Apple Intelligence, so your writing and your context never leave this phone. No account. It drafts one reply for one person. It will never send anything for you or send in bulk."
                ).tag(2)

                topicPage.tag(3)
                voicePage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(action: next) {
                Text(page == lastPage ? "Start" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(LinearGradient.cfPrimary, in: Capsule())
            }
            .disabled(page == 3 && topics.isEmpty && !canSaveTopic)
            .opacity(page == 3 && topics.isEmpty && !canSaveTopic ? 0.4 : 1)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: Pages

    private func infoPage(mascot: Bool = false, icon: String = "", title: String, text: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            if mascot {
                DropletMascot(size: 110)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundStyle(Color.cfCyan)
            }
            Text(title)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var topicPage: some View {
        Form {
            Section {
                TextField("Name, e.g. My invoice app", text: $name)
                TextEditor(text: $what)
                    .frame(minHeight: 110)
                    .onChange(of: what) { _, new in
                        if new.count > ContextBudget.productCardLimit {
                            what = String(new.prefix(ContextBudget.productCardLimit))
                        }
                    }
                TextField("Link (optional)", text: $link)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("What are you promoting?")
            } footer: {
                Text("\(what.count)/\(ContextBudget.productCardLimit). What it is and the problem it solves. Keep it short.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var voicePage: some View {
        Form {
            Section {
                TextEditor(text: $voice)
                    .frame(minHeight: 140)
                    .onChange(of: voice) { _, new in
                        if new.count > ContextBudget.voiceCardLimit {
                            voice = String(new.prefix(ContextBudget.voiceCardLimit))
                        }
                    }
            } header: {
                Text("How do you write?")
            } footer: {
                Text("Optional, and you can change it later. \(voice.count)/\(ContextBudget.voiceCardLimit). Tone, habits, and a line or two you've really written. Example: casual, lowercase, short sentences, dry humour.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: Actions

    private func next() {
        if page == 3, topics.isEmpty { saveTopic() }
        if page == lastPage {
            hasOnboarded = true
        } else {
            withAnimation { page += 1 }
        }
    }

    private func saveTopic() {
        guard canSaveTopic else { return }
        modelContext.insert(Topic(
            name: name.trimmingCharacters(in: .whitespaces),
            promotionDescription: what.trimmingCharacters(in: .whitespacesAndNewlines),
            link: link.trimmingCharacters(in: .whitespaces)
        ))
    }
}
