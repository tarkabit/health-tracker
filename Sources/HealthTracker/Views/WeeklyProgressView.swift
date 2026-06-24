import SwiftUI

struct WeeklyProgressView: View {
    let habit: Habit
    let progress: WeekProgress

    private var color: Color { Color(hex: habit.color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week").font(.headline)

            if progress.items.isEmpty {
                Text("No weekly target — entries are kept for your record.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(progress.items) { item in
                    ProgressBarRow(item: item, color: color)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
    }
}
