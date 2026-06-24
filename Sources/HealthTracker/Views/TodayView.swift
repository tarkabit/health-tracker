import SwiftUI

private struct GridWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct TodayView: View {
    @EnvironmentObject var state: AppState
    @State private var contentWidth: CGFloat = 0

    private var loggedCount: Int {
        state.habits.filter { !state.todayEntries(for: $0).isEmpty }.count
    }

    /// Equal-width columns (1–3) chosen from the measured content width, ~320pt each.
    private var columnCount: Int {
        guard contentWidth > 0 else { return 2 }
        return max(1, min(3, Int(contentWidth / 320)))
    }

    private var rows: [[Habit]] {
        let n = columnCount
        return stride(from: 0, to: state.habits.count, by: n).map {
            Array(state.habits[$0 ..< min($0 + n, state.habits.count)])
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gutter) {
                header
                if state.habits.isEmpty {
                    ContentUnavailableView("No habits yet",
                                           systemImage: "plus.circle",
                                           description: Text("Use the + button to create your first habit."))
                        .padding(.top, 60)
                } else {
                    // SwiftUI `Grid` gives equal-height rows + equal-width columns with no overlap.
                    Grid(horizontalSpacing: Theme.gutter, verticalSpacing: Theme.gutter) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            GridRow {
                                ForEach(0..<columnCount, id: \.self) { i in
                                    if i < row.count {
                                        HabitCardView(habit: row[i])
                                    } else {
                                        Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .background(GeometryReader { p in
                Color.clear.preference(key: GridWidthKey.self, value: p.size.width)
            })
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onPreferenceChange(GridWidthKey.self) { contentWidth = $0 }
        .navigationTitle("Today")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Today")
                .font(.title.weight(.bold))
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(loggedCount)/\(state.habits.count) logged")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }
}
