# SlydeBack: project state (2026-10-21)

Branch `v2/apple-intelligence-only` (PR #1 to `main`). Repo: github.com/alikhundmiri/DM-Marketer.

## What it is
iPhone app (display name **SlydeBack**, Xcode project still `DM-Marketer`). Share a post from X or Safari, pick a format (tweet reply / X DM / email reply), get a draft written on-device by Apple Intelligence, tap Copy & close, paste it yourself. Nothing is posted or sent for you, and there is no bulk mode.

## Decisions
- **Apple Intelligence only.** The llama.cpp / downloaded-model path is gone. Unsupported devices see an explanation screen. Needs iPhone 15 Pro or newer.
- **Context is small.** Apple's on-device model has a 4,096-token window shared by instructions, prompt and output. So context lives on two short cards: Product Card (a Topic's description, 600 chars) and Voice Card (500 chars). A Bookshelf of long chapters was dropped for this reason.
- **One-time purchase, 10 free drafts.** StoreKit introductory offers are subscription-only, so the trial is a draft count. Counted per new post; rewrites and hints are free. Placeholder price $14.99; `Products.storekit` is the local test file. Product ID `com.alikhundmiri.dm-marketer.unlock` (create it in App Store Connect before launch).
- **No X API.** Pay-per-use (~$0.005 per post read, paid by the developer) breaks one-time-purchase economics. Replies are tracked manually ("Mark replied").
- **No Mac app or keyboard yet.** Revisit after the tester results. A Mac app would need iCloud sync, which weakens the "never leaves your phone" claim.
- Brand: **SlydeBack**, icon is a yapping red-lipped mouth on lilac. Colours `cfLip` / `cfBerry` / `cfLilac`. Icon source: `design/app-icon-gen.py` (+ SVGs). In-app mascot `YapMascot` draws the same paths.

## Code map
- `DM-Marketer/ShareExtension/ShareViewController.swift`: share sheet (reads post, drafts, hint box, quota, queues Replies).
- `DM-Marketer/Shared/` (compiled into app and extension): `PostContext`, `TweetFetcher` (FxTwitter + oEmbed), `SharedTopicStore`, `VoiceCardStore` / `ContextBudget`, `DraftQuota`, `EngagementInbox`, `UsageStats`, `PendingShareStore`.
- `DM-Marketer/DM-Marketer/`: `AppState` (Apple Intelligence availability), `AppleModelService`, `PurchaseStore`, onboarding, paywall, Topics, Voice Card, Replies (`Engagement` model), Stats screen, `UnsupportedDeviceView`.
- App Group: `group.com.alikhundmiri.dm-marketer`. Bundle IDs `com.alikhundmiri.DM-Marketer` and `...ShareExtension`. Team `93K7NCG9TB`.
- Minimum iOS 26.0. Tests: `DM-MarketerTests` (9 tests, run on a simulator).

## Distribution state
- App Store Connect app id **6825219386** ("SlydeBack").
- TestFlight: internal group "Yapper Tester" (0 testers). External group **"Yapper"** with public link `https://testflight.apple.com/join/gxcPSmrJ`, limit 20, criteria iPhone iOS 26 to 27.
- Build **1.0 (2)** is Waiting for Review (submitted 2026-10-21). Build 1 was removed from review. **Do not share the link until the build shows Ready to Test.**
- Archive and upload from the command line: raise `CURRENT_PROJECT_VERSION`, then
  `xcodebuild archive -scheme DM-Marketer -configuration Release -destination 'generic/platform=iOS' -archivePath X.xcarchive -allowProvisioningUpdates`
  then `xcodebuild -exportArchive` with an ExportOptions plist (`method app-store-connect`, `destination upload`, team id, automatic signing).
- Only one build per version can be in Beta App Review at a time.
- Devices: iPad Air M4 (Sofiya's iPad) and iPhone 17 Pro have the dev build installed with `xcrun devicectl device install app`. Developer Mode must be on.

## Not done yet
- Privacy policy URL (needed for external TestFlight info and the real App Store); feedback email in Test Information.
- In-app purchase product in App Store Connect; sandbox purchase test.
- Real-user test (plan: `design/persona-feedback-v2.md`, section D). Success thresholds are in that section.
- Screenshots for the App Store (need an Apple Intelligence device). Listing draft: `design/app-store-listing.md`.
- Unverified on device: X app share sheet with the new activation rule, thread / quote tweets, long-thread retry, free-draft counter and paywall, Replies list, Stats screen.
- `llama.xcframework` folder is still on disk (unlinked from the project); the working tree has unrelated dSYM deletions and `.DS_Store` changes that are not part of the PR.
- Open question: FxTwitter is unofficial, so decide whether it ships.

## Reports
`design/persona-mock-test-report.md` (5 personas, first pass), `design/persona-feedback-v2.md` (v2 plan, verified facts, TAM/SAM/SOM, test plan, build list), `design/app-store-listing.md`.
