import Foundation

/// The six habits the app ships with on first launch.
enum SeedHabits {

    static let all: [Habit] = [running, food, meditation, lifting, pullups, headache]

    static let running = Habit(
        id: "running",
        name: "Running",
        icon: "figure.run",
        color: "#FF6B35",
        cadence: .weekly,
        goal: .completion,
        fields: [
            HabitField(id: "type", label: "Run type", kind: .choice, choices: ["easy", "fast", "long"]),
            HabitField(id: "distance", label: "Distance (km)", kind: .note),
            HabitField(id: "note", label: "Notes", kind: .note)
        ],
        targets: [
            Target(kind: .weeklyChoiceCounts, field: "type", counts: ["easy": 2, "fast": 2, "long": 1])
        ],
        details: "Target 2 easy runs, 2 fast runs and 1 long run in a week."
    )

    static let food = Habit(
        id: "food",
        name: "Food",
        icon: "fork.knife",
        color: "#34C759",
        cadence: .daily,
        goal: .completion,
        fields: [
            HabitField(id: "breakfast", label: "Clean breakfast", kind: .toggle),
            HabitField(id: "lunch", label: "Clean lunch", kind: .toggle),
            HabitField(id: "dinner", label: "Clean dinner", kind: .toggle),
            HabitField(id: "protein", label: "Protein taken", kind: .toggle),
            HabitField(id: "water", label: "Water taken", kind: .toggle),
            HabitField(id: "no_deviation", label: "No deviation", kind: .toggle),
            HabitField(id: "note", label: "Notes", kind: .note)
        ],
        targets: [
            Target(kind: .dailyAllToggles)
        ],
        details: "Clean breakfast, lunch and dinner. Protein taken, water taken and no deviation."
    )

    static let meditation = Habit(
        id: "meditation",
        name: "Meditation",
        icon: "figure.mind.and.body",
        color: "#5E5CE6",
        cadence: .everyOtherDay,
        goal: .completion,
        fields: [
            HabitField(id: "done", label: "Meditated", kind: .toggle),
            HabitField(id: "minutes", label: "Minutes", kind: .counter),
            HabitField(id: "note", label: "Notes", kind: .note)
        ],
        targets: [
            Target(kind: .weeklyCount, field: "done", n: 3)
        ],
        details: "3 sessions in a week, ideally every other day."
    )

    static let lifting = Habit(
        id: "lifting",
        name: "Weight Lifting",
        icon: "dumbbell",
        color: "#FF9500",
        cadence: .weekly,
        goal: .completion,
        fields: [
            HabitField(id: "type", label: "Session", kind: .choice, choices: ["push", "pull", "lower"]),
            HabitField(id: "note", label: "Notes", kind: .note)
        ],
        targets: [
            Target(kind: .weeklyChoiceCounts, field: "type", counts: ["push": 1, "pull": 1, "lower": 1])
        ],
        details: "1 push, 1 pull and 1 lower body session each week."
    )

    static let pullups = Habit(
        id: "pullups",
        name: "Pull-ups",
        icon: "figure.strengthtraining.traditional",
        color: "#00C7BE",
        cadence: .everyOtherDay,
        goal: .higherIsBetter,
        fields: [
            HabitField(id: "reps", label: "Reps", kind: .counter),
            HabitField(id: "note", label: "Notes", kind: .note)
        ],
        targets: [
            Target(kind: .counterTrendUp, field: "reps")
        ],
        details: "Keep the count increasing — every other day."
    )

    static let headache = Habit(
        id: "headache",
        name: "Headache & Tablets",
        icon: "brain.head.profile",
        color: "#FF3B30",
        cadence: .daily,
        goal: .lowerIsBetter,
        fields: [
            HabitField(id: "headache", label: "Headache occurred", kind: .toggle),
            HabitField(id: "tablets", label: "Tablets taken", kind: .counter),
            HabitField(id: "note", label: "Trigger / severity", kind: .note)
        ],
        targets: [],
        details: "Record headache occurrence and tablet intake. Fewer is better."
    )
}
