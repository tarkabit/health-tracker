import SwiftUI

/// One habit on the Today screen, with an inline quick-logger chosen from its fields.
struct HabitCardView: View {
    @EnvironmentObject var state: AppState
    let habit: Habit

    private var color: Color { Color(hex: habit.color) }
    private var today: LogEntry { state.dailyEntry(for: habit) }
    private var progress: WeekProgress { state.progress(for: habit) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider().opacity(0.5)
            logger
            footer
            Spacer(minLength: 0)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner)
                .strokeBorder(color.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: habit.icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(habit.name).font(.headline)
                    Button {
                        state.selection = habit.id
                    } label: {
                        Image(systemName: "chart.bar.xaxis").font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Open details")
                }
                Text(contextLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if progress.fraction > 0 || !progress.items.filter({ $0.target > 0 }).isEmpty {
                RingView(fraction: progress.fraction, color: color)
                    .frame(width: 40, height: 40)
            }
        }
    }

    private var contextLine: String {
        switch habit.goal {
        case .higherIsBetter:
            let best = state.entries(for: habit).compactMap { $0.int(counterId) }.max() ?? 0
            let last = state.entries(for: habit).last?.int(counterId) ?? 0
            return "Last \(last) · Best \(best)"
        case .lowerIsBetter:
            let f = habit.toggleFields.first?.id
            let week = state.entries(for: habit).filter {
                DayMath.isInCurrentWeek($0.date) && (f.map { $0 } != nil ? $0.bool(f!) : true)
            }.count
            return "\(week) this week — fewer is better"
        case .completion:
            return habit.details
        }
    }

    private var counterId: String { habit.counterFields.first?.id ?? "" }

    // MARK: Logger (switches on field composition)

    @ViewBuilder
    private var logger: some View {
        if let choice = habit.choiceField {
            choiceLogger(choice)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if !habit.toggleFields.isEmpty { toggleLogger }
                ForEach(habit.counterFields) { field in
                    counterLogger(field)
                }
            }
        }
    }

    /// One session type per day: a single-select. Tap to set today's type, tap again to clear.
    /// Weekly progress across types is shown in the footer.
    private func choiceLogger(_ field: HabitField) -> some View {
        let selected = today.string(field.id)
        return HStack(spacing: 8) {
            ForEach(field.choices ?? [], id: \.self) { option in
                let isOn = selected == option
                Button {
                    state.setDaily(habit, field: field.id, value: isOn ? nil : option)
                } label: {
                    Text(option.capitalized)
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isOn ? color : color.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(isOn ? .white : color)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var toggleLogger: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)],
                  alignment: .leading, spacing: 8) {
            ForEach(habit.toggleFields) { field in
                ToggleChip(label: field.label,
                           isOn: today.bool(field.id),
                           color: color) {
                    state.toggleDaily(habit, field: field.id)
                }
            }
        }
    }

    private func counterLogger(_ field: HabitField) -> some View {
        HStack {
            Text(field.label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            CounterControl(value: today.int(field.id) ?? 0, color: color) { newValue in
                state.setCounter(habit, field: field.id, value: newValue)
            }
        }
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if !progress.summary.isEmpty {
            Text(progress.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
