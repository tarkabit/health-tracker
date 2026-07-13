import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {

    @Published var habits: [Habit] = []
    @Published var entriesByHabit: [String: [LogEntry]] = [:]
    @Published var selection: String? = nil          // selected habit id; nil = Today
    @Published var errorMessage: String?

    let store: VaultStore

    /// The conversational assistant, kept here so chat history survives navigation.
    lazy var chat = ChatViewModel(state: self)

    init(store: VaultStore = VaultStore()) {
        self.store = store
        load()
    }

    var vaultPath: String { store.vaultURL.path }

    // MARK: Load

    func load() {
        do {
            habits = try store.bootstrap()
        } catch {
            errorMessage = "Could not open vault: \(error.localizedDescription)"
            habits = []
        }
        var map: [String: [LogEntry]] = [:]
        for habit in habits { map[habit.id] = store.loadEntries(for: habit) }
        entriesByHabit = map
    }

    func reload() { load() }

    // MARK: Reads

    func entries(for habit: Habit) -> [LogEntry] { entriesByHabit[habit.id] ?? [] }

    func dailyEntry(for habit: Habit, on date: Date = Date()) -> LogEntry {
        entries(for: habit).first { DayMath.sameDay($0.date, date) } ?? LogEntry(date: date)
    }

    func todayEntries(for habit: Habit) -> [LogEntry] {
        entries(for: habit).filter { DayMath.sameDay($0.date, Date()) }
    }

    func progress(for habit: Habit) -> WeekProgress {
        WeekProgressCalculator.compute(habit: habit, entries: entries(for: habit))
    }

    func sessionCount(_ habit: Habit, choice: String, on date: Date = Date()) -> Int {
        guard let f = habit.choiceField else { return 0 }
        return entries(for: habit).filter { DayMath.sameDay($0.date, date) && $0.string(f.id) == choice }.count
    }

    // MARK: Entry mutations (each persists immediately)

    /// Set a single field on the one entry representing `date`, creating that entry if needed.
    func setDaily(_ habit: Habit, field: String, value: String?, on date: Date = Date()) {
        mutate(habit) { arr in
            let clean = value?.trimmingCharacters(in: .whitespaces)
            if let idx = arr.firstIndex(where: { DayMath.sameDay($0.date, date) }) {
                if let clean, !clean.isEmpty { arr[idx].values[field] = clean }
                else { arr[idx].values.removeValue(forKey: field) }
                if arr[idx].values.isEmpty { arr.remove(at: idx) }
            } else if let clean, !clean.isEmpty {
                var e = LogEntry(date: date)
                e.values[field] = clean
                arr.append(e)
            }
        }
    }

    func toggleDaily(_ habit: Habit, field: String, on date: Date = Date()) {
        let isOn = dailyEntry(for: habit, on: date).bool(field)
        setDaily(habit, field: field, value: isOn ? nil : "true", on: date)
    }

    func setCounter(_ habit: Habit, field: String, value: Int, on date: Date = Date()) {
        setDaily(habit, field: field, value: value > 0 ? String(value) : nil, on: date)
    }

    func addSession(_ habit: Habit, choice: String, on date: Date = Date()) {
        guard let f = habit.choiceField else { return }
        mutate(habit) { arr in
            var e = LogEntry(date: date)
            e.values[f.id] = choice
            arr.append(e)
        }
    }

    func removeSession(_ habit: Habit, choice: String, on date: Date = Date()) {
        guard let f = habit.choiceField else { return }
        mutate(habit) { arr in
            if let idx = arr.lastIndex(where: { DayMath.sameDay($0.date, date) && $0.string(f.id) == choice }) {
                arr.remove(at: idx)
            }
        }
    }

    func addEntry(_ entry: LogEntry, to habit: Habit) {
        mutate(habit) { $0.append(entry) }
    }

    // MARK: Undo support (used by the chat assistant)

    /// Snapshot the current entries for a set of habits, so a batch of writes can be reverted.
    func entriesSnapshot(forHabitIds ids: Set<String>) -> [String: [LogEntry]] {
        var snap: [String: [LogEntry]] = [:]
        for id in ids { snap[id] = entriesByHabit[id] ?? [] }
        return snap
    }

    /// Restore a previously captured snapshot, persisting each affected habit.
    func restoreEntries(_ snapshot: [String: [LogEntry]]) {
        for (id, arr) in snapshot {
            guard let habit = habits.first(where: { $0.id == id }) else { continue }
            entriesByHabit[id] = arr
            do { try store.saveEntries(arr, for: habit) }
            catch { errorMessage = "Undo failed: \(error.localizedDescription)" }
        }
    }

    func updateEntry(_ entry: LogEntry, in habit: Habit) {
        mutate(habit) { arr in
            if let i = arr.firstIndex(where: { $0.id == entry.id }) { arr[i] = entry }
        }
    }

    func deleteEntry(_ entry: LogEntry, in habit: Habit) {
        mutate(habit) { arr in arr.removeAll { $0.id == entry.id } }
    }

    // MARK: Habit CRUD

    func addHabit(_ habit: Habit) {
        do {
            try store.createHabit(habit)
            habits = store.loadHabits()
            entriesByHabit[habit.id] = store.loadEntries(for: habit)
            if store.hasCustomOrder { store.saveOrder(habits.map { $0.id }) }
        } catch { errorMessage = "Could not create habit: \(error.localizedDescription)" }
    }

    /// Reorder habits (from the sidebar). Persists the new order; Today follows the same array.
    func moveHabits(fromOffsets: IndexSet, toOffset: Int) {
        habits.move(fromOffsets: fromOffsets, toOffset: toOffset)
        store.saveOrder(habits.map { $0.id })
    }

    func updateHabit(_ habit: Habit) {
        do {
            try store.saveHabit(habit)
            if let i = habits.firstIndex(where: { $0.id == habit.id }) { habits[i] = habit }
        } catch { errorMessage = "Could not save habit: \(error.localizedDescription)" }
    }

    func deleteHabit(_ habit: Habit) {
        do {
            try store.deleteHabit(habit)
            habits.removeAll { $0.id == habit.id }
            entriesByHabit[habit.id] = nil
            if store.hasCustomOrder { store.saveOrder(habits.map { $0.id }) }
            if selection == habit.id { selection = nil }
        } catch { errorMessage = "Could not delete habit: \(error.localizedDescription)" }
    }

    // MARK: Private

    private func mutate(_ habit: Habit, _ block: (inout [LogEntry]) -> Void) {
        var arr = entries(for: habit)
        block(&arr)
        arr.sort { $0.date < $1.date }
        entriesByHabit[habit.id] = arr
        do { try store.saveEntries(arr, for: habit) }
        catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }
}
