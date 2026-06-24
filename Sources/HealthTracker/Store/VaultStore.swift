import Foundation

/// Owns the on-disk vault: locates it, seeds it on first run, and performs habit/entry CRUD.
/// All persistence funnels through here so the Markdown files stay the single source of truth.
final class VaultStore {

    let vaultURL: URL
    private var folders: [String: URL] = [:]   // habit.id -> folder URL

    init(vaultURL: URL? = nil) {
        self.vaultURL = vaultURL ?? Self.defaultVaultURL()
    }

    // MARK: Location

    /// Resolution order:
    ///   1. `HEALTH_TRACKER_VAULT` environment variable (custom location / tests)
    ///   2. the location chosen on a previous launch (persisted in UserDefaults)
    ///   3. default: `~/Documents/Health Tracker/HabitData`
    ///
    /// To keep your vault in iCloud Drive, point `HEALTH_TRACKER_VAULT` (or the saved path)
    /// at e.g. `~/Library/Mobile Documents/com~apple~CloudDocs/Health Tracker/HabitData`.
    static func defaultVaultURL() -> URL {
        let env = ProcessInfo.processInfo.environment["HEALTH_TRACKER_VAULT"]
        if let env, !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath, isDirectory: true)
        }
        if let saved = UserDefaults.standard.string(forKey: "vaultPath"), !saved.isEmpty {
            return URL(fileURLWithPath: saved, isDirectory: true)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/Health Tracker/HabitData", isDirectory: true)
    }

    // MARK: Bootstrap

    /// Creates the vault if needed, seeds the six default habits on first launch, returns all habits.
    @discardableResult
    func bootstrap() throws -> [Habit] {
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        UserDefaults.standard.set(vaultURL.path, forKey: "vaultPath")

        var habits = loadHabits()
        if habits.isEmpty {
            for habit in SeedHabits.all { try createHabit(habit) }
            habits = loadHabits()
        }
        return habits
    }

    // MARK: Habits

    func loadHabits() -> [Habit] {
        let fm = FileManager.default
        folders.removeAll()
        guard let subs = try? fm.contentsOfDirectory(
            at: vaultURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]) else { return [] }

        var result: [Habit] = []
        for dir in subs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            guard fm.fileExists(atPath: dir.appendingPathComponent(HabitFile.filename).path) else { continue }
            if let habit = try? HabitFile.read(from: dir) {
                folders[habit.id] = dir
                result.append(habit)
            }
        }

        // Apply the user's custom order if present; unlisted habits fall back to seed/name order.
        let order = readOrder()
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return result.sorted { a, b in
            switch (rank[a.id], rank[b.id]) {
            case let (.some(x), .some(y)): return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return Self.seedThenName(a, b)
            }
        }
    }

    // MARK: Custom ordering (persisted in `<vault>/.order`, one habit id per line)

    private var orderFileURL: URL { vaultURL.appendingPathComponent(".order") }

    var hasCustomOrder: Bool { FileManager.default.fileExists(atPath: orderFileURL.path) }

    func readOrder() -> [String] {
        guard let s = try? String(contentsOf: orderFileURL, encoding: .utf8) else { return [] }
        return s.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func saveOrder(_ ids: [String]) {
        let text = ids.joined(separator: "\n") + "\n"
        try? text.write(to: orderFileURL, atomically: true, encoding: .utf8)
    }

    func createHabit(_ habit: Habit) throws {
        let folder = vaultURL.appendingPathComponent(Self.sanitize(habit.name), isDirectory: true)
        folders[habit.id] = folder
        try HabitFile.write(habit, to: folder)
        let log = folder.appendingPathComponent(LogFile.filename)
        if !FileManager.default.fileExists(atPath: log.path) {
            try LogFile.write([], for: habit, to: folder)
        }
    }

    func saveHabit(_ habit: Habit) throws {
        try HabitFile.write(habit, to: folderURL(for: habit))
    }

    func deleteHabit(_ habit: Habit) throws {
        let url = folderURL(for: habit)
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        folders[habit.id] = nil
    }

    // MARK: Entries

    func loadEntries(for habit: Habit) -> [LogEntry] {
        LogFile.read(from: folderURL(for: habit), habit: habit)
    }

    func saveEntries(_ entries: [LogEntry], for habit: Habit) throws {
        try LogFile.write(entries, for: habit, to: folderURL(for: habit))
    }

    // MARK: Helpers

    func folderURL(for habit: Habit) -> URL {
        if let url = folders[habit.id] { return url }
        let url = vaultURL.appendingPathComponent(Self.sanitize(habit.name), isDirectory: true)
        folders[habit.id] = url
        return url
    }

    private static func sanitize(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespaces)
    }

    private static let seedOrder = SeedHabits.all.map { $0.id }

    private static func seedThenName(_ a: Habit, _ b: Habit) -> Bool {
        let ia = seedOrder.firstIndex(of: a.id) ?? Int.max
        let ib = seedOrder.firstIndex(of: b.id) ?? Int.max
        if ia != ib { return ia < ib }
        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
}
