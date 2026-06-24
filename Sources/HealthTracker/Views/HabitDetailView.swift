import SwiftUI
import AppKit

/// Identifies which entry the editor sheet is editing (existing) or creating (new on a date).
private struct EditTarget: Identifiable {
    let id = UUID()
    var entry: LogEntry
    var isNew: Bool
}

struct HabitDetailView: View {
    @EnvironmentObject var state: AppState
    let habit: Habit

    @State private var editTarget: EditTarget?
    @State private var editingHabit = false
    @State private var confirmingDelete = false

    private var color: Color { Color(hex: habit.color) }
    private var entries: [LogEntry] { state.entries(for: habit) }
    private var progress: WeekProgress { state.progress(for: habit) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gutter) {
                header
                summaryCard
                heatmapCard
                historyCard
            }
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(habit.name)
        .toolbar {
            ToolbarItemGroup {
                Button { editTarget = EditTarget(entry: LogEntry(date: Date()), isNew: true) } label: {
                    Label("Add Entry", systemImage: "plus")
                }
                Button { revealInFinder() } label: { Label("Reveal in Finder", systemImage: "folder") }
                Button { editingHabit = true } label: { Label("Edit Habit", systemImage: "pencil") }
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $editingHabit) {
            NewHabitView(editing: habit)
        }
        .sheet(item: $editTarget) { target in
            EntryEditorView(habit: habit, entry: target.entry, isNew: target.isNew) { saved in
                if target.isNew { state.addEntry(saved, to: habit) }
                else { state.updateEntry(saved, in: habit) }
            }
        }
        .confirmationDialog("Delete “\(habit.name)”? Its folder is moved to the Trash.",
                            isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Habit", role: .destructive) { state.deleteHabit(habit) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.subheadline.weight(.semibold))
    }

    // MARK: Header (compact)

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: habit.icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name).font(.title2.weight(.bold))
                Text(habit.details).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 6) {
                    tag(habit.cadence.label, "calendar")
                    tag(goalLabel, goalIcon)
                }
            }
            Spacer()
            if !progress.items.filter({ $0.target > 0 }).isEmpty {
                RingView(fraction: progress.fraction, color: color, lineWidth: 8)
                    .frame(width: 50, height: 50)
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
    }

    private func tag(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Color.gray.opacity(0.12), in: Capsule())
        .foregroundStyle(.secondary)
    }

    private var goalLabel: String {
        switch habit.goal {
        case .completion: return "Complete the target"
        case .higherIsBetter: return "Higher is better"
        case .lowerIsBetter: return "Fewer is better"
        }
    }
    private var goalIcon: String {
        switch habit.goal {
        case .completion: return "checkmark.circle"
        case .higherIsBetter: return "arrow.up.right"
        case .lowerIsBetter: return "arrow.down.right"
        }
    }

    // MARK: Summary — "This week" + "Stats" side by side in one card

    private var summaryCard: some View {
        let items = progress.items
        let chips = statChips()
        return HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("This week")
                if items.isEmpty {
                    Text("No weekly target — entries are kept for your record.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(items) { ProgressBarRow(item: $0, color: color) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !chips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("Stats")
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                        GridItem(.flexible(), alignment: .leading)],
                              alignment: .leading, spacing: 10) {
                        ForEach(chips, id: \.0) { chip in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(chip.1).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(color)
                                Text(chip.0).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
    }

    // MARK: Heatmap (compact)

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Activity")
                Spacer()
                Text("Tap any day to log or edit it")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HeatmapView(habit: habit, entries: entries, onSelect: openDay)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
    }

    private func openDay(_ day: Date) {
        if let existing = entries.first(where: { DayMath.sameDay($0.date, day) }) {
            editTarget = EditTarget(entry: existing, isNew: false)
        } else {
            editTarget = EditTarget(entry: LogEntry(date: day), isNew: true)
        }
    }

    /// A few habit-goal-aware headline stats.
    private func statChips() -> [(String, String)] {
        let now = Date()
        let since30 = DayMath.daysAgo(29, from: now)

        switch habit.goal {
        case .lowerIsBetter:
            let tf = habit.toggleFields.first?.id
            let occ = entries.filter { tf == nil || $0.bool(tf!) }
            let occ30 = occ.filter { $0.date >= since30 }.count
            var chips: [(String, String)] = [("Last 30 days", "\(occ30)"), ("Total logged", "\(occ.count)")]
            if let last = occ.map({ $0.date }).max() {
                let d = DayMath.calendar.dateComponents([.day], from: last, to: DayMath.startOfDay(now)).day ?? 0
                chips.append(("Days since last", "\(d)"))
            }
            if let cf = habit.counterFields.first?.id {
                let t30 = occ.filter { $0.date >= since30 }.compactMap { $0.int(cf) }.reduce(0, +)
                chips.append(("Tablets (30d)", "\(t30)"))
            }
            return chips

        case .higherIsBetter:
            let cf = habit.counterFields.first?.id ?? ""
            let best = entries.compactMap { $0.int(cf) }.max() ?? 0
            let latest = entries.last { $0.int(cf) != nil }?.int(cf) ?? 0
            let n30 = entries.filter { $0.date >= since30 && $0.int(cf) != nil }.count
            return [("Best", "\(best)"), ("Latest", "\(latest)"), ("Sessions (30d)", "\(n30)")]

        case .completion:
            let active30 = Set(entries.filter { $0.date >= since30 }.map { $0.date }).count
            return [("Active days (30d)", "\(active30)"), ("Total entries", "\(entries.count)")]
        }
    }

    // MARK: History (compact)

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("History")
                Spacer()
                Text("\(entries.count) entries").font(.caption2).foregroundStyle(.secondary)
            }

            if entries.isEmpty {
                Text("No entries yet.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(entries.reversed()) { entry in
                    historyRow(entry)
                    if entry.id != entries.first?.id { Divider().opacity(0.35) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
    }

    private func historyRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(entry.date.formatted(.dateTime.weekday(.abbreviated).day().month()))
                .font(.caption.weight(.semibold))
                .frame(width: 104, alignment: .leading)
            Text(summary(of: entry))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("Edit") { editTarget = EditTarget(entry: entry, isNew: false) }
                Button("Delete", role: .destructive) { state.deleteEntry(entry, in: habit) }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { editTarget = EditTarget(entry: entry, isNew: false) }
    }

    private func summary(of entry: LogEntry) -> String {
        let parts: [String] = habit.fields.compactMap { field in
            switch field.kind {
            case .toggle: return entry.bool(field.id) ? field.label : nil
            case .counter:
                if let v = entry.int(field.id), v > 0 { return "\(field.label): \(v)" }
                return nil
            case .choice: return entry.string(field.id)?.capitalized
            case .note: return entry.string(field.id)
            }
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private func revealInFinder() {
        let url = state.store.folderURL(for: habit)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
