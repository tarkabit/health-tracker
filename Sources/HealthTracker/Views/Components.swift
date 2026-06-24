import SwiftUI

/// A pill toggle used for checklist items (Food) and boolean fields.
struct ToggleChip: View {
    let label: String
    let isOn: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                Text(label)
            }
            .font(.callout.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isOn ? color.opacity(0.18) : Color.gray.opacity(0.12), in: Capsule())
            .foregroundStyle(isOn ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

/// A round icon button used by the steppers.
struct RoundButton: View {
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 30, height: 30)
                .background(color.opacity(0.15), in: Circle())
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}

/// Big +/- counter for numeric fields (pull-ups, tablets, minutes…).
struct CounterControl: View {
    let value: Int
    let color: Color
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            RoundButton(symbol: "minus", color: color) { onChange(max(0, value - 1)) }
            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 46)
            RoundButton(symbol: "plus", color: color) { onChange(value + 1) }
        }
    }
}

/// Per-option stepper for choice habits (run type, lift session).
struct ChoiceStepper: View {
    let option: String
    let count: Int
    let target: Int
    let color: Color
    let onAdd: () -> Void
    let onRemove: () -> Void

    private var done: Bool { target > 0 && count >= target }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(option.capitalized)
                    .font(.subheadline.weight(.semibold))
                if done { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
            }
            .foregroundStyle(done ? color : .primary)

            HStack(spacing: 10) {
                RoundButton(symbol: "minus", color: color, action: onRemove)
                Text(target > 0 ? "\(count)/\(target)" : "\(count)")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .frame(minWidth: 40)
                RoundButton(symbol: "plus", color: color, action: onAdd)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(done ? color.opacity(0.12) : Color.gray.opacity(0.08))
        )
    }
}

/// A thin labelled progress bar for a single target item.
struct ProgressBarRow: View {
    let item: ProgressItem
    let color: Color

    private var fraction: Double {
        item.target > 0 ? min(Double(item.current) / Double(item.target), 1) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.label)
                    .font(.caption.weight(.medium))
                Spacer()
                Text(item.target > 0 ? "\(item.current)/\(item.target)" : "\(item.current)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(item.done ? color : .secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
            .frame(height: 6)
        }
    }
}

/// A circular completion ring (used in the detail header).
struct RingView: View {
    let fraction: Double
    let color: Color
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(fraction, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((min(fraction, 1)) * 100))%")
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
    }
}
