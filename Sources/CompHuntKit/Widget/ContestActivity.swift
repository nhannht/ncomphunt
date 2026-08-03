import Foundation

/// The Live Activity's data, shared between the app (which starts and updates
/// the activity) and the widget extension (which renders it). Same
/// cross-process role as `WidgetSnapshot`, so it lives beside it.
///
/// Plain `Codable` here; the `ActivityAttributes` conformance is attached below
/// only where ActivityKit exists, so the kit still builds for macOS and
/// `swift test`.
public struct ContestActivityAttributes: Codable, Hashable, Sendable {
    /// The competition's dedupe key: the island's tap deep-links back through
    /// `competitionDeepLink(key:)` exactly like a widget row or reminder tap.
    public var key: String
    public var title: String
    /// `CompetitionCategory.shortCode`, so the extension can tint with the
    /// kit's one category mapping without carrying the whole enum across.
    public var categoryCode: String

    public init(key: String, title: String, categoryCode: String) {
        self.key = key
        self.title = title
        self.categoryCode = categoryCode
    }

    public init(competition: Competition) {
        self.init(key: competition.key, title: competition.title,
                  categoryCode: competition.category.shortCode)
    }

    public struct ContentState: Codable, Hashable, Sendable {
        /// Which face the activity wears. The system only re-renders on an
        /// update from the app, so the face is state, not a view-side check
        /// of the clock.
        public var phase: Phase
        /// What the countdown runs to: the deadline, the start, or the end.
        public var target: Date
        /// Carried for the expanded view (start time, duration) and the
        /// running progress bar. Optional because sources often know only one
        /// date.
        public var start: Date?
        public var end: Date?

        public init(phase: Phase, target: Date, start: Date? = nil, end: Date? = nil) {
            self.phase = phase
            self.target = target
            self.start = start
            self.end = end
        }

        public enum Phase: String, Codable, Hashable, Sendable {
            case registration
            case preStart
            case running

            /// The countdown's verb, shared by the island and the Lock Screen
            /// card so the two surfaces can never phrase one face differently.
            /// Same wording family as `ReminderPlan.body`.
            public var countdownLabel: String {
                switch self {
                case .registration: "Registration closes"
                case .preStart: "Starts"
                case .running: "Ends"
                }
            }
        }
    }
}

/// The pure half of the Live Activity: which face to show right now and when
/// that face expires. The app's `ContestActivities` applies it; the extension
/// only renders. Same split as `ReminderPlan` / `ReminderScheduler`.
public enum ContestActivityPlan {
    /// The system shows a Live Activity for at most 8 hours, so a running face
    /// is only offered when the whole contest fits inside it. Multi-day events
    /// (CTFs) keep the pre-start countdown as their only face.
    public static let islandCap: TimeInterval = 8 * 3600

    /// The state the activity should show at `now`, plus the moment that face
    /// stops being true (`staleDate`) - the system dims the activity past it,
    /// so a phase flip the app has not applied yet reads as stale rather than
    /// as a countdown lying at zero.
    ///
    /// nil means there is nothing left to follow: dateless, ended, running
    /// beyond the cap, or started with no known end. The applier ends the
    /// activity on nil.
    ///
    /// Face order mirrors `whenChoice` in Schedule.swift: the registration
    /// deadline outranks the start (it is the more urgent of the two), the
    /// start outranks the end.
    public static func plan(
        for competition: Competition, now: Date = .now
    ) -> (state: ContestActivityAttributes.ContentState, staleDate: Date)? {
        // No `isCurrent` guard on purpose: that helper reads a past deadline
        // with no end date as "over", which is right for browsing but wrong
        // for a follower - they registered, and the start countdown is the
        // face they are waiting for. The cascade below already yields nil for
        // everything genuinely over.
        let start = competition.startDate
        let end = competition.endDate

        if let deadline = competition.registrationDeadline, deadline > now {
            return (.init(phase: .registration, target: deadline,
                          start: start, end: end),
                    deadline)
        }
        if let start, start > now {
            return (.init(phase: .preStart, target: start,
                          start: start, end: end),
                    start)
        }
        if let start, let end, start <= now, end > now,
           end.timeIntervalSince(start) <= islandCap {
            return (.init(phase: .running, target: end,
                          start: start, end: end),
                    end)
        }
        return nil
    }
}

// The macOS SDK ships the ActivityKit module with the protocol marked
// unavailable, so `canImport` alone passes there and then fails to conform -
// the os check is what actually scopes this to iOS.
#if canImport(ActivityKit) && os(iOS)
import ActivityKit

extension ContestActivityAttributes: ActivityAttributes {}
#endif
