import Foundation

/// Builds RFC 5545 .ics payloads so a competition can be handed to Calendar
/// without any EventKit permission dance: write the payload to a temp file,
/// open it, and the calendar app shows its native import sheet.
public enum ICSBuilder {
    /// One-VEVENT calendar for a competition. Explicit start/end dates bound
    /// the event when known; otherwise the registration deadline becomes a
    /// one-hour block ending at the deadline, titled "Deadline: <title>".
    /// Returns nil when there is no date to anchor an event on.
    public static func calendar(for competition: Competition, now: Date = .now) -> String? {
        let summary: String
        let start: Date
        let end: Date
        if let eventStart = competition.startDate {
            summary = competition.title
            start = eventStart
            end = competition.endDate ?? eventStart.addingTimeInterval(2 * 3600)
        } else if let deadline = competition.registrationDeadline {
            summary = "Deadline: \(competition.title)"
            start = deadline.addingTimeInterval(-3600)
            end = deadline
        } else {
            return nil
        }

        var description = ["URL: \(competition.url)"]
        if !competition.organizer.isEmpty {
            description.append("Organizer: \(competition.organizer)")
        }
        if !competition.prize.isEmpty {
            description.append("Prize: \(competition.prize)")
        }
        description.append("Found via \(competition.source) (CompHunt)")

        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//nhannht//CompHunt//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "BEGIN:VEVENT",
            "UID:\(escape(competition.key))@comphunt",
            "DTSTAMP:\(format(now))",
            "DTSTART:\(format(start))",
            "DTEND:\(format(end))",
            "SUMMARY:\(escape(summary))",
            "DESCRIPTION:\(escape(description.joined(separator: "\n")))",
            "URL:\(escape(competition.url))",
        ]
        if !competition.location.isEmpty {
            lines.append("LOCATION:\(escape(competition.location))")
        }
        lines += [
            "BEGIN:VALARM",
            "ACTION:DISPLAY",
            "DESCRIPTION:\(escape(summary))",
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
