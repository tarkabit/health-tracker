import SwiftUI

/// A GitHub-style contribution grid: columns = weeks (Mon top), intensity = how complete the day was.
/// Month + weekday labels give temporal context; cells are clickable (tap a day to log/edit it).
struct HeatmapView: View {
    let habit: Habit
    let entries: [LogEntry]
    var weeks: Int = 18
    var onSelect: (Date) -> Void = { _ in }

    private var color: Color { Color(hex: habit.color) }
    private let cell: CGFloat = 15
    private let spacing: CGFloat = 3
    private let weekdayCol: CGFloat = 26

    private var startMonday: Date {
        DayMath.startOfWeek(DayMath.daysAgo((weeks - 1) * 7))
    }

    private func date(week w: Int, weekday d: Int) -> Date {
        DayMath.calendar.date(byAdding: .day, value: w * 7 + d, to: startMonday) ?? startMonday
    }

    var body: some View {
        let map = intensityByDay
        let today = DayMath.startOfDay(Date())

        VStack(alignment: .leading, spacing: 6) {
            monthLabels
            HStack(alignment: .top, spacing: spacing) {
                weekdayLabels
                HStack(spacing: spacing) {
                    ForEach(0..<weeks, id: \.self) { w in
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { d in
                                let day = date(week: w, weekday: d)
                                cellButton(day: day, intensity: map[day] ?? 0, isFuture: day > today)
                            }
                        }
                    }
                }
            }
            legend
        }
    }

    // MARK: Labels

    private var monthLabels: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: weekdayCol + spacing, height: 11)
            ForEach(Array(monthGroups.enumerated()), id: \.offset) { _, group in
                Text(group.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: CGFloat(group.count) * (cell + spacing), alignment: .leading)
            }
        }
    }

    private var weekdayLabels: some View {
        let names = ["Mon", "", "Wed", "", "Fri", "", ""]
        return VStack(spacing: spacing) {
            ForEach(0..<7, id: \.self) { d in
                Text(names[d])
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: weekdayCol, height: cell, alignment: .trailing)
            }
        }
    }

    /// Groups consecutive week-columns by the month of their Monday, for spanning month headers.
    private var monthGroups: [(label: String, count: Int)] {
        var groups: [(String, Int)] = []
        for w in 0..<weeks {
            let m = DayMath.monthAbbr.string(from: date(week: w, weekday: 0))
            if let last = groups.last, last.0 == m {
                groups[groups.count - 1].1 += 1
            } else {
                groups.append((m, 1))
            }
        }
        return groups.map { (label: $0.0, count: $0.1) }
    }

    // MARK: Cell

    private func cellButton(day: Date, intensity: Double, isFuture: Bool) -> some View {
        let isToday = DayMath.sameDay(day, Date())
        return Button {
            if !isFuture { onSelect(day) }
        } label: {
            RoundedRectangle(cornerRadius: 3)
                .fill(fill(intensity: intensity, isFuture: isFuture))
                .frame(width: cell, height: cell)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(isToday ? Color.primary.opacity(0.75) : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .help(tooltip(day: day))
    }

    private func tooltip(day: Date) -> String {
        let label = day.formatted(.dateTime.weekday(.abbreviated).day().month().year())
        let es = entries.filter { DayMath.sameDay($0.date, day) }
        guard !es.isEmpty else { return "\(label) — no entry. Click to add." }
        let detail = es.map { entrySummary($0) }.filter { !$0.isEmpty }.joined(separator: " | ")
        return "\(label) — \(detail.isEmpty ? "logged" : detail). Click to edit."
    }

    private func entrySummary(_ entry: LogEntry) -> String {
        habit.fields.compactMap { field -> String? in
            switch field.kind {
            case .toggle: return entry.bool(field.id) ? field.label : nil
            case .counter: if let v = entry.int(field.id), v > 0 { return "\(field.label) \(v)" }; return nil
            case .choice: return entry.string(field.id)?.capitalized
            case .note: return entry.string(field.id)
            }
        }.joined(separator: ", ")
    }

    private func fill(intensity: Double, isFuture: Bool) -> Color {
        if isFuture { return Color.gray.opacity(0.04) }
        if intensity <= 0 { return Color.gray.opacity(0.10) }
        return color.opacity(0.20 + 0.80 * min(intensity, 1))
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("Less").font(.caption2).foregroundStyle(.secondary)
            ForEach([0.0, 0.3, 0.6, 1.0], id: \.self) { v in
                RoundedRectangle(cornerRadius: 2)
                    .fill(fill(intensity: v, isFuture: false))
                    .frame(width: 11, height: 11)
            }
            Text("More").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    // MARK: Intensity model

    private var intensityByDay: [Date: Double] {
        var map: [Date: Double] = [:]
        for day in Set(entries.map { $0.date }) {
            map[day] = intensity(on: day)
        }
        return map
    }

    private func intensity(on day: Date) -> Double {
        let es = entries.filter { DayMath.sameDay($0.date, day) }
        guard !es.isEmpty else { return 0 }

        let toggles = habit.toggleFields
        if habit.targets.contains(where: { $0.kind == .dailyAllToggles }), !toggles.isEmpty {
            let done = toggles.filter { f in es.contains { $0.bool(f.id) } }.count
            return Double(done) / Double(toggles.count)
        }
        if let cf = habit.counterFields.first, habit.goal == .higherIsBetter {
            let value = es.compactMap { $0.int(cf.id) }.max() ?? 0
            let best = entries.compactMap { $0.int(cf.id) }.max() ?? 0
            return best > 0 ? Double(value) / Double(best) : (value > 0 ? 1 : 0)
        }
        return 1
    }
}
