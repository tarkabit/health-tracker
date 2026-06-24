import Foundation
import Yams

/// Reads & writes `habit.md` — YAML frontmatter (the config) + Markdown body (`details`).
enum HabitFile {

    static let filename = "habit.md"

    static func read(from folder: URL) throws -> Habit {
        let url = folder.appendingPathComponent(filename)
        let raw = try String(contentsOf: url, encoding: .utf8)
        let (frontmatter, body) = splitFrontmatter(raw)

        var habit = try YAMLDecoder().decode(Habit.self, from: frontmatter)
        habit.details = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return habit
    }

    static func write(_ habit: Habit, to folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = false
        let yaml = try encoder.encode(habit)

        var out = "---\n"
        out += yaml.hasSuffix("\n") ? yaml : yaml + "\n"
        out += "---\n\n"
        let body = habit.details.trimmingCharacters(in: .whitespacesAndNewlines)
        out += body.isEmpty ? "# \(habit.name)\n" : body + "\n"

        let url = folder.appendingPathComponent(filename)
        try out.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Splits a file into (frontmatterYAML, body). Tolerates a missing frontmatter block.
    static func splitFrontmatter(_ raw: String) -> (String, String) {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else { return ("", normalized) }

        let afterOpen = normalized.dropFirst(4) // drop leading "---\n"
        guard let range = afterOpen.range(of: "\n---") else { return ("", normalized) }

        let frontmatter = String(afterOpen[..<range.lowerBound])
        var body = String(afterOpen[range.upperBound...])
        if body.hasPrefix("\n") { body.removeFirst() }
        return (frontmatter, body)
    }
}
