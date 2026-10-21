import Foundation

// Compiled into both the app and the Share Extension.

/// Local-only counters for the test group. Nothing is uploaded; testers copy the report and send it.
nonisolated enum UsageStats {
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: PendingShareStore.appGroup) ?? .standard
    }

    private static func bump(_ key: String, by n: Int = 1) {
        defaults.set(defaults.integer(forKey: key) + n, forKey: key)
    }

    static func recordActiveDay() {
        if defaults.object(forKey: "stat-first-seen") == nil {
            defaults.set(Date(), forKey: "stat-first-seen")
        }
        let day = ISO8601DateFormatter().string(from: Date()).prefix(10)
        var days = defaults.stringArray(forKey: "stat-active-days") ?? []
        if !days.contains(String(day)) {
            days.append(String(day))
            defaults.set(days, forKey: "stat-active-days")
        }
    }

    static func recordDraft(milliseconds: Int) {
        bump("stat-drafts-timed")
        bump("stat-draft-ms", by: milliseconds)
    }
    static func recordCopy() { bump("stat-copies") }
    static func recordRewrite() { bump("stat-rewrites") }
    static func recordError() { bump("stat-errors") }

    static func report() -> String {
        let timed = defaults.integer(forKey: "stat-drafts-timed")
        let avg = timed == 0 ? 0 : defaults.integer(forKey: "stat-draft-ms") / timed
        let first = (defaults.object(forKey: "stat-first-seen") as? Date).map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "-"
        return """
        SlydeBack test stats
        First opened: \(first)
        Active days: \((defaults.stringArray(forKey: "stat-active-days") ?? []).count)
        Posts drafted: \(DraftQuota.used)
        Replies copied: \(defaults.integer(forKey: "stat-copies"))
        Rewrites: \(defaults.integer(forKey: "stat-rewrites"))
        Avg time to draft: \(avg) ms
        Errors: \(defaults.integer(forKey: "stat-errors"))
        Unlocked: \(DraftQuota.isUnlocked ? "yes" : "no")
        """
    }
}
