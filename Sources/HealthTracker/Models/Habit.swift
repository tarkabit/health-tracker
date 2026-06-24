import Foundation

// MARK: - Enums

enum Cadence: String, Codable, CaseIterable, Hashable {
    case daily
    case everyOtherDay
    case weekly

    var label: String {
        switch self {
        case .daily: return "Daily"
        case .everyOtherDay: return "Every other day"
        case .weekly: return "Weekly"
        }
    }
}

enum Goal: String, Codable, CaseIterable, Hashable {
    case completion      // hit the checklist / target
    case higherIsBetter  // counter trending up (pull-ups)
    case lowerIsBetter   // fewer is better (headaches)
}

enum FieldKind: String, Codable, CaseIterable, Hashable {
    case toggle   // boolean
    case counter  // integer
    case choice   // pick one of `choices`
    case note     // free text
}

enum TargetKind: String, Codable, Hashable {
    case dailyAllToggles      // every toggle field checked = a complete day
    case weeklyCount          // do `field` (toggle/any entry) `n` times this week
    case weeklyChoiceCounts   // per-option weekly counts for a choice `field`
    case counterTrendUp       // each session should meet/beat the prior one
}

// MARK: - Field

struct HabitField: Codable, Identifiable, Hashable {
    var id: String
    var label: String
    var kind: FieldKind
    var choices: [String]?   // populated only for `.choice`

    init(id: String, label: String, kind: FieldKind, choices: [String]? = nil) {
        self.id = id
        self.label = label
        self.kind = kind
        self.choices = choices
    }
}

// MARK: - Target

struct Target: Codable, Hashable {
    var kind: TargetKind
    var field: String?            // weeklyCount / weeklyChoiceCounts
    var n: Int?                   // weeklyCount
    var counts: [String: Int]?    // weeklyChoiceCounts

    init(kind: TargetKind, field: String? = nil, n: Int? = nil, counts: [String: Int]? = nil) {
        self.kind = kind
        self.field = field
        self.n = n
        self.counts = counts
    }
}

// MARK: - Habit

/// A habit's configuration. Persisted as YAML frontmatter in `habit.md`.
/// `details` is the human-readable Markdown body (not part of the frontmatter).
struct Habit: Codable, Identifiable, Hashable {
    var id: String              // slug, also the folder name basis
    var name: String
    var icon: String            // SF Symbol
    var color: String           // hex, e.g. "#FF6B35"
    var cadence: Cadence
    var goal: Goal
    var fields: [HabitField]
    var targets: [Target]

    /// Markdown body of habit.md — not encoded into frontmatter.
    var details: String = ""

    enum CodingKeys: String, CodingKey {
        case id, name, icon, color, cadence, goal, fields, targets
    }

    init(id: String,
         name: String,
         icon: String,
         color: String,
         cadence: Cadence,
         goal: Goal,
         fields: [HabitField],
         targets: [Target],
         details: String = "") {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.cadence = cadence
        self.goal = goal
        self.fields = fields
        self.targets = targets
        self.details = details
    }

    // MARK: Convenience

    var choiceField: HabitField? {
        fields.first { $0.kind == .choice }
    }

    var counterFields: [HabitField] {
        fields.filter { $0.kind == .counter }
    }

    var toggleFields: [HabitField] {
        fields.filter { $0.kind == .toggle }
    }

    func field(_ id: String) -> HabitField? {
        fields.first { $0.id == id }
    }

    /// The ordered set of column ids used in the log.md table (always date first).
    var logColumns: [String] {
        ["date"] + fields.map { $0.id }
    }
}
