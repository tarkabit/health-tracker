import Foundation

/// One logged session/day — a single row in `log.md`.
/// Values are stored as raw strings keyed by field id; typed accessors interpret them.
struct LogEntry: Identifiable, Hashable {
    let id: UUID
    var date: Date                  // normalized to start-of-day
    var values: [String: String]    // fieldId -> raw value

    init(id: UUID = UUID(), date: Date, values: [String: String] = [:]) {
        self.id = id
        self.date = DayMath.startOfDay(date)
        self.values = values
    }

    // MARK: Typed accessors

    func string(_ fieldId: String) -> String? {
        let v = values[fieldId]?.trimmingCharacters(in: .whitespaces)
        return (v?.isEmpty ?? true) ? nil : v
    }

    func bool(_ fieldId: String) -> Bool {
        guard let v = values[fieldId]?.lowercased() else { return false }
        return ["true", "yes", "x", "1", "✓", "done"].contains(v)
    }

    func int(_ fieldId: String) -> Int? {
        guard let v = string(fieldId) else { return nil }
        return Int(v)
    }

    var dateString: String { DayMath.iso.string(from: date) }
}

// MARK: - Date helpers (week starts Monday)

enum DayMath {
    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Monday
        return c
    }()

    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let monthAbbr: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return f
    }()

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func parse(_ s: String) -> Date? {
        iso.date(from: s.trimmingCharacters(in: .whitespaces))
    }

    static func sameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// Monday 00:00 of the week containing `date`.
    static func startOfWeek(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? startOfDay(date)
    }

    static func isInCurrentWeek(_ date: Date, reference: Date = Date()) -> Bool {
        startOfWeek(date) == startOfWeek(reference)
    }

    static func daysAgo(_ n: Int, from date: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -n, to: startOfDay(date)) ?? date
    }
}
