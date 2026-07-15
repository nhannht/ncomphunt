import Foundation

/// Builds RFC 5545 .ics payloads so a competition can be handed to Calendar
/// without any EventKit permission dance: write the payload to a temp file,
/// open it, and the calendar app shows its native import sheet.
public enum ICSBuilder {
    /// One-VEVENT calendar for a competition. Explicit start/end dates bound
    /// the event when known; otherwise the registration deadline becomes a
    /// one-hour block ending at the deadline, titled "Deadline: <title>".
    /// Returns nil when there is no date to anchor an event on. The event shape
    /// comes from the shared `CalendarEventPlan` so this `.ics` and the live
    /// EventKit calendar never diverge.
    public static func calendar(for competition: Competition, now: Date = .now) -> String? {
        guard let plan = CalendarEventPlan.plan(for: competition, now: now) else { return nil }

        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//nhannht//nCompHunt//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "BEGIN:VEVENT",
            "UID:\(escape(plan.key))@ncomphunt",
            "DTSTAMP:\(format(now))",
            "DTSTART:\(format(plan.start))",
            "DTEND:\(format(plan.end))",
            "SUMMARY:\(escape(plan.title))",
            "DESCRIPTION:\(escape(plan.notes))",
            "URL:\(escape(plan.url))",
        ]
        if !plan.location.isEmpty {
            lines.append("LOCATION:\(escape(plan.location))")
        }
        lines += [
            "BEGIN:VALARM",
            "ACTION:DISPLAY",
            "DESCRIPTION:\(escape(plan.title))",
            "TRIGGER:-P1D",
            "END:VALARM",
            "END:VEVENT",
            "END:VCALENDAR",
        ]
        return lines.flatMap(fold).map { $0 + "\r\n" }.joined()
    }

    /// UTC timestamp in the ics basic format, e.g. 20260728T165959Z.
    static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    /// RFC 5545 TEXT escaping: backslash, semicolon, comma, newline.
    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// RFC 5545 line folding: content lines cap at 75 octets; continuations
    /// start with a single space. Splits on character boundaries so multi-byte
    /// UTF-8 sequences stay intact.
    static func fold(_ line: String) -> [String] {
        var folded: [String] = []
        var current = ""
        var budget = 75
        for character in line {
            let width = String(character).utf8.count
            if budget - width < 0 {
                folded.append(current)
                current = " "
                budget = 74
            }
            current.append(character)
            budget -= width
        }
        folded.append(current)
        return folded
    }
}
