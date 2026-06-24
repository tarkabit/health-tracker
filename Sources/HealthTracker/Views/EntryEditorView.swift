import SwiftUI

/// Sheet for adding or editing a single log entry (date + each field).
struct EntryEditorView: View {
    let habit: Habit
    let isNew: Bool
    let onSave: (LogEntry) -> Void

    @State private var entry: LogEntry
    @Environment(\.dismiss) private var dismiss

    init(habit: Habit, entry: LogEntry, isNew: Bool, onSave: @escaping (LogEntry) -> Void) {
        self.habit = habit
        self.isNew = isNew
        self.onSave = onSave
        _entry = State(initialValue: entry)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: habit.icon).foregroundStyle(Color(hex: habit.color))
                Text(isNew ? "Add entry — \(habit.name)" : "Edit entry — \(habit.name)")
                    .font(.headline)
            }
            .padding()

            Divider()

            Form {
                DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                ForEach(habit.fields) { field in
                    fieldEditor(field)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    onSave(entry)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400)
    }

    // MARK: Field editors

    @ViewBuilder
    private func fieldEditor(_ field: HabitField) -> some View {
        switch field.kind {
        case .toggle:
            Toggle(field.label, isOn: boolBinding(field.id))
        case .counter:
            Stepper(value: intBinding(field.id), in: 0...100_000) {
                HStack {
                    Text(field.label)
                    Spacer()
                    Text("\(entry.int(field.id) ?? 0)").monospacedDigit().foregroundStyle(.secondary)
                }
            }
        case .choice:
            Picker(field.label, selection: strBinding(field.id)) {
                Text("—").tag("")
                ForEach(field.choices ?? [], id: \.self) { option in
                    Text(option.capitalized).tag(option)
                }
            }
        case .note:
            VStack(alignment: .leading, spacing: 4) {
                Text(field.label).font(.caption).foregroundStyle(.secondary)
                TextField("", text: strBinding(field.id), axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: Bindings

    private var dateBinding: Binding<Date> {
        Binding(get: { entry.date },
                set: { entry.date = DayMath.startOfDay($0) })
    }

    private func strBinding(_ id: String) -> Binding<String> {
        Binding(get: { entry.values[id] ?? "" },
                set: { v in
                    if v.isEmpty { entry.values.removeValue(forKey: id) } else { entry.values[id] = v }
                })
    }

    private func boolBinding(_ id: String) -> Binding<Bool> {
        Binding(get: { entry.bool(id) },
                set: { on in
                    if on { entry.values[id] = "true" } else { entry.values.removeValue(forKey: id) }
                })
    }

    private func intBinding(_ id: String) -> Binding<Int> {
        Binding(get: { entry.int(id) ?? 0 },
                set: { v in
                    if v > 0 { entry.values[id] = String(v) } else { entry.values.removeValue(forKey: id) }
                })
    }
}
