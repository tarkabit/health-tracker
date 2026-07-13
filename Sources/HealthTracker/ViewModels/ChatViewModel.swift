import Foundation
import AppKit

/// Drives the conversational logging surface: sends the user's message to `claude`
/// (via the subscription), applies any recorded entries through `AppState`, and keeps
/// an undo snapshot so a write can be reverted.
@MainActor
final class ChatViewModel: ObservableObject {

    enum Role { case user, assistant }

    struct Change: Identifiable, Hashable {
        let id = UUID()
        let habitName: String
        let summary: String
    }

    struct Message: Identifiable {
        let id = UUID()
        let role: Role
        var text: String
        var images: [URL] = []
        var changes: [Change] = []
        var undoSnapshot: [String: [LogEntry]]? = nil   // present → undo available
        var isError = false
    }

    @Published var messages: [Message] = []
    @Published var input: String = ""
    @Published var pendingImages: [URL] = []   // attached, staged, not yet sent
    @Published var isWorking = false

    /// Where attached/pasted screenshots are staged so the CLI can read them by path.
    private static let imageDir: URL = {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("HealthTrackerChat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private unowned let state: AppState
    private let cli = ClaudeCLI()

    init(state: AppState) { self.state = state }

    var isAvailable: Bool { cli.isAvailable }

    // MARK: Attachments

    /// Stage raw image data (from a paste or a data-drop) for the next message.
    @discardableResult
    func attach(data: Data, ext: String = "png") -> Bool {
        let url = Self.imageDir.appendingPathComponent(UUID().uuidString + "." + ext)
        do { try data.write(to: url); pendingImages.append(url); return true }
        catch { state.errorMessage = "Couldn't attach image: \(error.localizedDescription)"; return false }
    }

    /// Stage an image file (from the file picker or a file-URL drop) by copying it into the temp dir.
    @discardableResult
    func attach(contentsOf source: URL) -> Bool {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: source) else { return false }
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension
        return attach(data: data, ext: ext)
    }

    /// Pull an image off the clipboard (common after a screenshot). Returns false if none.
    @discardableResult
    func attachFromClipboard() -> Bool {
        let pb = NSPasteboard.general
        if let png = pb.data(forType: .png) { return attach(data: png, ext: "png") }
        if let tiff = pb.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return attach(data: png, ext: "png")
        }
        return false
    }

    func removePending(_ url: URL) {
        pendingImages.removeAll { $0 == url }
    }

    // MARK: Sending

    func send() async {
        let typed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = pendingImages
        guard (!typed.isEmpty || !images.isEmpty), !isWorking else { return }

        input = ""
        pendingImages = []
        let display = typed.isEmpty ? "📷 Screenshot" : typed
        messages.append(Message(role: .user, text: display, images: images))

        guard cli.isAvailable else {
            messages.append(Message(
                role: .assistant,
                text: "I can't reach Claude. Install Claude Code and sign in with your subscription (run `claude` once in Terminal), then try again.",
                isError: true))
            return
        }

        isWorking = true
        defer { isWorking = false }

        let promptText = typed.isEmpty
            ? "Extract and log the metrics from the attached screenshot."
            : typed
        let prompt = Assistant.userPrompt(
            message: promptText,
            habits: state.habits,
            entriesByHabit: state.entriesByHabit,
            today: Date(),
            history: recentHistory())

        do {
            let raw = try await cli.run(prompt: prompt,
                                        system: Assistant.systemPrompt,
                                        imagePaths: images.map(\.path))
            guard let result = Assistant.parse(raw) else {
                messages.append(Message(role: .assistant,
                                        text: "I got a response I couldn't read. Please try rephrasing.",
                                        isError: true))
                return
            }

            switch result.kind {
            case .answer:
                messages.append(Message(role: .assistant, text: result.reply))

            case .record:
                let ids = Set(result.entries.map { $0.habitId })
                let snapshot = state.entriesSnapshot(forHabitIds: ids)
                let changes = apply(result.entries)
                if changes.isEmpty {
                    let fallback = result.reply.isEmpty
                        ? "I couldn't match that to any habit — try naming the activity."
                        : result.reply
                    messages.append(Message(role: .assistant, text: fallback))
                } else {
                    messages.append(Message(
                        role: .assistant,
                        text: result.reply.isEmpty ? "Recorded." : result.reply,
                        changes: changes,
                        undoSnapshot: snapshot))
                }
            }
        } catch {
            messages.append(Message(role: .assistant,
                                    text: error.localizedDescription,
                                    isError: true))
        }
    }

    func undo(_ message: Message) {
        guard let snapshot = message.undoSnapshot else { return }
        state.restoreEntries(snapshot)
        if let i = messages.firstIndex(where: { $0.id == message.id }) {
            messages[i].changes = []
            messages[i].undoSnapshot = nil
            messages[i].text += "  (undone)"
        }
    }

    // MARK: Applying records

    /// Write each proposed entry through `AppState`, returning a human summary of what changed.
    private func apply(_ entries: [Assistant.ProposedEntry]) -> [Change] {
        var changes: [Change] = []

        for entry in entries {
            guard let habit = state.habits.first(where: { $0.id == entry.habitId }) else { continue }
            let date = entry.date.flatMap(DayMath.parse) ?? Date()
            var parts: [String] = []

            if habit.choiceField != nil {
                // Session-style (e.g. Running, Lifting): one new row carrying all values.
                var e = LogEntry(date: date)
                for (key, raw) in entry.values {
                    guard let field = habit.field(key), let val = normalize(raw, field: field) else { continue }
                    e.values[key] = val
                    parts.append(describe(field, val))
                }
                guard !e.values.isEmpty else { continue }
                state.addEntry(e, to: habit)
            } else {
                // Daily aggregate (e.g. Food, Headache): merge fields into the day's row.
                for (key, raw) in entry.values {
                    guard let field = habit.field(key), let val = normalize(raw, field: field) else { continue }
                    state.setDaily(habit, field: key, value: val, on: date)
                    parts.append(describe(field, val))
                }
                guard !parts.isEmpty else { continue }
            }

            let when = DayMath.sameDay(date, Date()) ? "today" : DayMath.iso.string(from: date)
            changes.append(Change(habitName: habit.name,
                                  summary: parts.joined(separator: ", ") + " · " + when))
        }
        return changes
    }

    /// Coerce/validate a raw value against the field's kind. Returns nil to skip.
    private func normalize(_ raw: String, field: HabitField) -> String? {
        let v = raw.trimmingCharacters(in: .whitespaces)
        switch field.kind {
        case .toggle:
            let truthy = ["true", "yes", "x", "1", "✓", "done"].contains(v.lowercased())
            return truthy ? "true" : nil          // don't record a toggle that didn't happen
        case .counter:
            if let i = Int(v) { return i > 0 ? String(i) : nil }
            let digits = v.filter(\.isNumber)
            return Int(digits).flatMap { $0 > 0 ? String($0) : nil }
        case .choice:
            return field.choices?.first { $0.caseInsensitiveCompare(v) == .orderedSame }
        case .note:
            let clean = v.replacingOccurrences(of: "|", with: "/")
            return clean.isEmpty ? nil : clean
        }
    }

    private func describe(_ field: HabitField, _ value: String) -> String {
        switch field.kind {
        case .toggle:  return field.label
        case .counter: return "\(value) \(field.label.lowercased())"
        case .choice:  return value
        case .note:    return value
        }
    }

    // MARK: Helpers

    private func recentHistory(limit: Int = 12) -> [(role: String, text: String)] {
        messages.suffix(limit).map { ($0.role == .user ? "user" : "assistant", $0.text) }
    }
}
