import SwiftUI

/// Create a new habit, or edit an existing one (pass `editing:`).
struct NewHabitView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    private let editing: Habit?

    @State private var name: String
    @State private var details: String
    @State private var icon: String
    @State private var color: String
    @State private var cadence: Cadence
    @State private var goal: Goal
    @State private var fields: [HabitField]

    @State private var targetMode: TargetMode
    @State private var targetFieldId: String
    @State private var targetN: Int
    @State private var choiceCounts: [String: Int]

    enum TargetMode: String, CaseIterable, Identifiable {
        case none = "No target"
        case dailyAll = "Daily checklist (all toggles)"
        case weeklyCount = "Weekly count of a field"
        case weeklyChoice = "Weekly count per choice"
        case trendUp = "Counter trending up"
        var id: String { rawValue }
    }

    init(editing: Habit? = nil) {
        self.editing = editing
        let h = editing
        _name = State(initialValue: h?.name ?? "")
        _details = State(initialValue: h?.details ?? "")
        _icon = State(initialValue: h?.icon ?? "checkmark.circle.fill")
        _color = State(initialValue: h?.color ?? Theme.palette[0])
        _cadence = State(initialValue: h?.cadence ?? .daily)
        _goal = State(initialValue: h?.goal ?? .completion)
        _fields = State(initialValue: h?.fields ?? [HabitField(id: "done", label: "Done", kind: .toggle)])

        let t = h?.targets.first
        let mode: TargetMode
        switch t?.kind {
        case .dailyAllToggles: mode = .dailyAll
        case .weeklyCount: mode = .weeklyCount
        case .weeklyChoiceCounts: mode = .weeklyChoice
        case .counterTrendUp: mode = .trendUp
        case .none: mode = .none
        }
        _targetMode = State(initialValue: mode)
        _targetFieldId = State(initialValue: t?.field ?? "")
        _targetN = State(initialValue: t?.n ?? 3)
        _choiceCounts = State(initialValue: t?.counts ?? [:])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(editing == nil ? "New Habit" : "Edit Habit").font(.headline)
                Spacer()
            }
            .padding()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    basicsSection
                    appearanceSection
                    fieldsSection
                    targetSection
                }
                .padding(20)
            }

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(editing == nil ? "Create" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 520, height: 640)
    }

    // MARK: Sections

    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Basics")
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            TextField("Description", text: $details, axis: .vertical)
                .lineLimit(1...3).textFieldStyle(.roundedBorder)
            HStack(spacing: 16) {
                Picker("Cadence", selection: $cadence) {
                    ForEach(Cadence.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("Goal", selection: $goal) {
                    Text("Complete target").tag(Goal.completion)
                    Text("Higher is better").tag(Goal.higherIsBetter)
                    Text("Fewer is better").tag(Goal.lowerIsBetter)
                }
            }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Appearance")
            HStack(spacing: 8) {
                ForEach(Theme.palette, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(.primary, lineWidth: color == hex ? 2 : 0))
                        .onTapGesture { color = hex }
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 8) {
                ForEach(Theme.symbols, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .frame(width: 36, height: 36)
                        .background(icon == symbol ? Color(hex: color).opacity(0.2) : Color.gray.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(icon == symbol ? Color(hex: color) : .secondary)
                        .onTapGesture { icon = symbol }
                }
            }
        }
    }

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Fields to log")
                Spacer()
                Button { addField() } label: { Label("Add", systemImage: "plus") }
                    .buttonStyle(.borderless)
            }
            ForEach($fields) { $field in
                FieldRow(field: $field) { removeField(field) }
            }
        }
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Weekly target")
            Picker("Target", selection: $targetMode) {
                ForEach(TargetMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()

            switch targetMode {
            case .none, .dailyAll:
                EmptyView()
            case .weeklyCount:
                HStack {
                    fieldPicker(kinds: [.toggle, .counter, .note, .choice])
                    Stepper("Times per week: \(targetN)", value: $targetN, in: 1...21)
                }
            case .trendUp:
                fieldPicker(kinds: [.counter])
            case .weeklyChoice:
                fieldPicker(kinds: [.choice])
                if let f = fields.first(where: { $0.id == targetFieldId }), f.kind == .choice {
                    ForEach(f.choices ?? [], id: \.self) { option in
                        Stepper("\(option.capitalized): \(choiceCounts[option] ?? 1)/week",
                                value: bindingCount(option), in: 0...21)
                    }
                }
            }
        }
    }

    private func fieldPicker(kinds: [FieldKind]) -> some View {
        Picker("Field", selection: $targetFieldId) {
            Text("—").tag("")
            ForEach(fields.filter { kinds.contains($0.kind) }) { f in
                Text(f.label).tag(f.id)
            }
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
    }

    // MARK: Mutations

    private func addField() {
        var n = fields.count + 1
        var id = "field\(n)"
        while fields.contains(where: { $0.id == id }) { n += 1; id = "field\(n)" }
        fields.append(HabitField(id: id, label: "New field", kind: .toggle))
    }

    private func removeField(_ field: HabitField) {
        fields.removeAll { $0.id == field.id }
    }

    private func bindingCount(_ option: String) -> Binding<Int> {
        Binding(get: { choiceCounts[option] ?? 1 },
                set: { choiceCounts[option] = $0 })
    }

    private func save() {
        let id = editing?.id ?? Self.slug(name)
        var targets: [Target] = []
        switch targetMode {
        case .none: break
        case .dailyAll: targets = [Target(kind: .dailyAllToggles)]
        case .weeklyCount where !targetFieldId.isEmpty:
            targets = [Target(kind: .weeklyCount, field: targetFieldId, n: targetN)]
        case .trendUp where !targetFieldId.isEmpty:
            targets = [Target(kind: .counterTrendUp, field: targetFieldId)]
        case .weeklyChoice where !targetFieldId.isEmpty:
            let opts = fields.first { $0.id == targetFieldId }?.choices ?? []
            var counts: [String: Int] = [:]
            for o in opts { counts[o] = choiceCounts[o] ?? 1 }
            targets = [Target(kind: .weeklyChoiceCounts, field: targetFieldId, counts: counts)]
        default: break
        }

        let habit = Habit(id: id, name: name.trimmingCharacters(in: .whitespaces),
                          icon: icon, color: color, cadence: cadence, goal: goal,
                          fields: fields, targets: targets, details: details)

        if editing == nil { state.addHabit(habit) } else { state.updateHabit(habit) }
        dismiss()
    }

    private static func slug(_ s: String) -> String {
        let base = s.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let joined = String(base)
        let trimmed = joined.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "habit-\(abs(s.hashValue % 10000))" : trimmed
    }
}

/// One editable field row in the habit form.
private struct FieldRow: View {
    @Binding var field: HabitField
    let onDelete: () -> Void

    private var choicesText: Binding<String> {
        Binding(get: { (field.choices ?? []).joined(separator: ", ") },
                set: { field.choices = $0.split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty } })
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                TextField("Label", text: $field.label).textFieldStyle(.roundedBorder)
                Picker("", selection: $field.kind) {
                    ForEach(FieldKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                .labelsHidden().frame(width: 110)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            if field.kind == .choice {
                TextField("Options (comma separated)", text: choicesText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}
