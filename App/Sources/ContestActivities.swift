// iOS-only: ActivityKit has no macOS presence, and the macOS app target
// compiles this directory wholesale - same guard style as BackgroundRefresh.
#if os(iOS)
import ActivityKit
import CompHuntKit
import Foundation

/// The impure half of the contest Live Activity (COMP-37): starts, updates,
/// and ends activities. Every decision - which face, which target, when a face
/// expires - comes from `ContestActivityPlan` in the kit; this only applies
/// them. Same split as `ReminderPlan` / `ReminderScheduler`.
///
/// There is no stored follow list: `Activity.activities` IS the state. A
/// second copy in UserDefaults would be a mirror kept in sync by hand with
/// what the system already knows.
@MainActor
enum ContestActivities {
    /// The user can veto Live Activities per app in Settings; a request made
    /// anyway throws. The menu checks this so the action never shows dead.
    static var areEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func isFollowing(key: String) -> Bool {
        Activity<ContestActivityAttributes>.activities
            .contains { $0.attributes.key == key }
    }

    /// Whether the Follow action should appear: activities allowed and the
    /// plan has a face to show for this competition right now.
    static func canFollow(_ competition: Competition, now: Date = .now) -> Bool {
        areEnabled && ContestActivityPlan.plan(for: competition, now: now) != nil
    }

    static func follow(_ competition: Competition) {
        guard !isFollowing(key: competition.key),
              let plan = ContestActivityPlan.plan(for: competition) else { return }
        do {
            _ = try Activity.request(
                attributes: ContestActivityAttributes(competition: competition),
                content: .init(state: plan.state, staleDate: plan.staleDate))
        } catch {
            // Menus are transient, so the failure surfaces as a notification -
            // same reasoning as YouTrack filing outcomes.
            Notifier.post("Could not start the countdown",
                          body: error.localizedDescription)
        }
    }

    static func unfollow(key: String) {
        Task {
            for activity in Activity<ContestActivityAttributes>.activities
            where activity.attributes.key == key {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Brings every live activity up to date with the fresh store: the face
    /// advances (registration -> pre-start -> running), and an activity whose
    /// plan ran out - contest over, multi-day event past its start, row gone
    /// from the store - ends. Runs after every refresh and on foregrounding;
    /// there is no per-minute tick to gate, so no signature cache either.
    static func reconcile(competitions: [Competition], now: Date = .now) async {
        let byKey = Dictionary(competitions.map { ($0.key, $0) },
                               uniquingKeysWith: { first, _ in first })
        for activity in Activity<ContestActivityAttributes>.activities {
            if let competition = byKey[activity.attributes.key],
               let plan = ContestActivityPlan.plan(for: competition, now: now) {
                await activity.update(.init(state: plan.state,
                                            staleDate: plan.staleDate))
            } else {
                // Keep the final content on the Lock Screen briefly rather
                // than vanishing mid-glance; the system removes it.
                await activity.end(activity.content, dismissalPolicy: .default)
            }
        }
    }
}
#endif
