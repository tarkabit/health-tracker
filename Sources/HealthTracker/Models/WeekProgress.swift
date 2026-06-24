import Foundation

struct ProgressItem: Identifiable, Hashable {
    let id = UUID()
    var label: String
    var current: Int
    var target: Int          // 0 = informational (no fixed target)
    var done: Bool { target > 0 && current >= target }
}

struct WeekProgress {
    var items: [ProgressItem]
    var summary: String       // compact, e.g. "easy 1/2 · fast 2/2 ✓ · long 0/1"
    var fraction: Double      // 0...1 across target-bearing items

    static let empty = WeekProgress(items: [], summary: "", fraction: 0)
}

enum WeekProgressCalculator {

    static func compute(habit: Habit, entries: [LogEntry], now: Date = Date()) -> WeekProgress {
        let week = entries.filter { DayMath.isInCurrentWeek($0.date, reference: now) }
        var items: [ProgressItem] = []

        for target in habit.targets {
            switch target.kind {
            case .dailyAllToggles:
                let toggles = habit.toggleFields
                let days = Set(week.map { $0.date })
                let cleanDays = days.filter { day in
                    let dayEntries = week.filter { DayMath.sameDay($0.date, day) }
                    return !toggles.isEmpty && toggles.allSatisfy { f in
                        dayEntries.contains { $0.bool(f.id) }
                    }
                }.count
                items.append(ProgressItem(label: "Clean days", current: cleanDays, target: 7))

            case .weeklyCount:
                let fid = target.field ?? habit.fields.first?.id ?? ""
                let field = habit.field(fid)
                let count = week.filter { entry in
                    switch field?.kind {
                    case .toggle: return entry.bool(fid)
                    case .none: return true
                    default: return entry.string(fid) != nil
                    }
                }.count
                items.append(ProgressItem(label: field?.label ?? "Sessions",
                                          current: count, target: target.n ?? 0))

            case .weeklyChoiceCounts:
                let fid = target.field ?? habit.choiceField?.id ?? ""
                let order = habit.field(fid)?.choices ?? Array(target.counts?.keys ?? [:].keys)
                for option in order {
                    guard let need = target.counts?[option] else { continue }
                    let c = week.filter { $0.string(fid) == option }.count
                    items.append(ProgressItem(label: option.capitalized, current: c, target: need))
                }

            case .counterTrendUp:
                let fid = target.field ?? habit.counterFields.first?.id ?? ""
                let weekMax = week.compactMap { $0.int(fid) }.max() ?? 0
                let allTimeBest = entries.compactMap { $0.int(fid) }.max() ?? 0
                items.append(ProgressItem(label: "Best this week",
                                          current: weekMax, target: allTimeBest))
            }
        }

        let targeted = items.filter { $0.target > 0 }
        let fraction = targeted.isEmpty ? 0 :
            targeted.map { min(Double($0.current) / Double($0.target), 1) }
                    .reduce(0, +) / Double(targeted.count)

        let summary = items.map { item -> String in
            let mark = item.done ? " ✓" : ""
            if item.target > 0 {
                return "\(item.label.lowercased()) \(item.current)/\(item.target)\(mark)"
            } else {
                return "\(item.label.lowercased()) \(item.current)"
            }
        }.joined(separator: " · ")

        return WeekProgress(items: items, summary: summary, fraction: fraction)
    }
}
