#if os(macOS)
import CoreGraphics
#else
import UIKit
#endif
import CompHuntKit
import Foundation

/// Is the user actually at the machine right now, and have they just come back?
///
/// The impure half of `ArrivalLog`: this takes the samples, the kit decides what
/// they mean, and the result is persisted here.
///
/// ## Why the predicate is what it is
///
/// A sleeping Mac dark-wakes every few minutes all night and nCompHunt runs
/// through every one of them - measured 2026-08-05 at 02:41, 06:32, 07:38,
/// 07:49, 08:06. So "the app is running" says nothing about whether anyone is
/// there, and sampling on the timer alone would report a fresh arrival in the
/// middle of the night. What distinguishes a dark wake from a person is the
/// SCREEN: during a dark wake the display stays asleep.
///
/// Sampling is therefore safe to call from anywhere, including the once-a-minute
/// tick, because the predicate throws away every sample taken while nobody is
/// looking. That is also why no wake or unlock observers are needed: the gap
/// forms on its own out of the samples that were never taken.
@MainActor
enum Presence {
    private enum Key {
        static let lastSeen = "presence.lastSeen"
        static let arrivals = "presence.arrivals"
    }

    /// True only while a person could actually see a banner.
    ///
    /// macOS asks the window server directly. Both reads are synchronous,
    /// cheap, and need no entitlement or permission prompt.
    static var isUserPresent: Bool {
        #if os(macOS)
        // Display asleep covers both a dark wake and the screen having simply
        // timed out while the machine stayed up.
        guard CGDisplayIsAsleep(CGMainDisplayID()) == 0 else { return false }
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        else { return false }
        // String literals rather than the CF constants: these keys are declared
        // as CFSTR macros in CGSession.h and only some of them surface in Swift,
        // so a literal is the portable spelling.
        //
        // Spelled from the dictionary as it actually is on macOS 26, dumped
        // 2026-08-05, NOT from the header name. The console key carries a double
        // S - `kCGSSessionOnConsoleKey` - while the surrounding API is spelled
        // `CGSession`. Using the single-S spelling reads nil, defaults to false,
        // and pins presence to false forever with nothing to see: exactly the
        // silent failure this whole feature exists to stop. Do not "correct" it.
        //
        // The lock key is absent entirely while unlocked rather than present and
        // false, so its default has to be false, not true.
        let onConsole = session["kCGSSessionOnConsoleKey"] as? Bool ?? false
        let locked = session["CGSSessionScreenIsLocked"] as? Bool ?? false
        return onConsole && !locked
        #else
        // Foreground and active is the phone's equivalent, and the check is not
        // a formality: iOS wakes the app for background refresh at hours nobody
        // is awake for, and counting those as presence would teach the learned
        // morning a habit the user does not have.
        return UIApplication.shared.applicationState == .active
        #endif
    }

    // MARK: persisted state

    static var lastSeen: Date? {
        get { UserDefaults.standard.object(forKey: Key.lastSeen) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Key.lastSeen) }
    }

    /// Bounded by `ArrivalLog.sampleLimit`, so this stays a small plist array
    /// and never needs pruning.
    static var arrivals: [Date] {
        get { UserDefaults.standard.array(forKey: Key.arrivals) as? [Date] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Key.arrivals) }
    }

    /// The hour the user typically comes back, or nil while still learning.
    /// Read by iOS to schedule its digest, and by Settings to show what was
    /// learned. macOS never consults it - it posts on the arrival itself.
    static var learnedMorning: DateComponents? {
        ArrivalLog.learnedMorning(from: arrivals)
    }

    static var arrivalCount: Int { arrivals.count }

    // MARK: sampling

    /// Record that the user is here, if they are.
    ///
    /// Returns true exactly once per return - on the sample that crossed the
    /// absence threshold - so the caller can act on the edge without tracking
    /// state of its own.
    @discardableResult
    static func sample(now: Date = .now) -> Bool {
        guard isUserPresent else { return false }
        let update = ArrivalLog.observe(now, lastPresence: lastSeen,
                                        arrivals: arrivals)
        lastSeen = update.lastPresence
        if update.isArrival { arrivals = update.arrivals }
        return update.isArrival
    }
}
