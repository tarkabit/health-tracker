import Foundation

/// Turns a free-text message + the user's habit schemas and data into a structured result.
///
/// The conversation surface has two intents:
///  - **record**: the user described something that happened → extract log entries.
///  - **answer**: the user asked a question → answer from the supplied data.
///
/// The LLM returns one JSON object; `parse` is tolerant of stray fences/whitespace.
enum Assistant {

    // MARK: Result types

    struct ProposedEntry {
        let habitId: String
        let date: String?            // ISO "yyyy-MM-dd"; nil → today
        let values: [String: String] // fieldId -> raw value
    }

    struct Result {
        enum Kind: String { case record, answer }
        let kind: Kind
        let reply: String
        let entries: [ProposedEntry]
    }

    // MARK: System prompt (static → good for prompt caching)

    static let systemPrompt = """
    You are the assistant inside a personal habit-tracker app. The user logs habits by \
    talking naturally instead of filling forms. You do exactly one of two things per message:

    1) RECORD — the user describes something that happened (a run, a headache, a meal, a \
       meditation, a lifting session, pull-ups, tablets taken, etc.). Extract it into \
       structured log entries.
    2) ANSWER — the user asks a question (trends, comparisons, summaries, "how am I doing"). \
       Answer ONLY from the DATA provided. Never invent numbers.

    You are given: today's date, the HABITS schema (each habit's id, goal, style, and fields \
    with their ids/kinds/allowed choices), the user's existing DATA, the recent CONVERSATION, \
    and the NEW MESSAGE.

    Respond with EXACTLY ONE JSON object and nothing else — no markdown, no code fences, no \
    commentary before or after:

    {
      "type": "record" | "answer",
      "reply": "<one short, friendly sentence shown to the user>",
      "entries": [
        { "habitId": "<id>", "date": "YYYY-MM-DD", "values": { "<fieldId>": "<value>" } }
      ]
    }

    Rules for values:
    - Keys MUST be field ids that exist in the schema. Never invent field ids or habit ids.
    - toggle field  → value is the string "true". Only include a toggle when it actually happened.
    - counter field → a non-negative integer as a string, e.g. "12".
    - choice field  → exactly one of that field's allowed choices.
    - note field    → short free text. Never include the "|" character.
    - Respect each field's kind. Decimal numbers (e.g. running distance in km) go in a NOTE \
      field, never a counter.
    - Resolve relative dates ("this morning", "yesterday", "last Tuesday") against TODAY to \
      "YYYY-MM-DD". If unspecified, use today.
    - Emit one entry per distinct session/occurrence. A single run is ONE entry carrying its \
      choice + distance + notes together. Two sessions → two entries.
    - For a "session-style" habit, all values for one occurrence go in the SAME entry.
    - Only record what the user actually reported. If nothing is recordable, use type "answer".
    - For type "answer", set "entries" to [] and put the full answer in "reply".

    If IMAGES are provided (e.g. a screenshot of a run from a watch or fitness app), read each \
    image and extract the metrics into a "record" for the matching habit (a run screenshot → the \
    Running habit). Map only the fields that exist in that habit's schema, e.g. for Running:
    - distance → "distance": a number in km only, no unit (e.g. "7.24").
    - total time / duration → "duration": "mm:ss" (or "h:mm:ss").
    - average pace → "pace": like "8'11\\"/km".
    - average heart rate → "hr": an integer (bpm).
    - calories → "calories": an integer.
    - Set "type" (easy/fast/long) ONLY if the user's text says which. If the user didn't say, omit \
      "type" and mention in "reply" that the run type still needs to be set.
    Extract only metrics actually shown in the image; skip anything with no matching field.

    Keep "reply" to one sentence for records. For answers, be concrete and cite numbers from \
    DATA, and format the reply with Markdown so it reads well: use short paragraphs, "##" \
    subheadings, "-" bullet lists, and Markdown tables for week-over-week or per-category \
    comparisons. Put newlines in the "reply" string (as \\n) so the structure is preserved. \
    Don't over-format a one-line answer — match the structure to the amount of information.
    """

    // MARK: User prompt builder

    private static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE"
        return f
    }()

    /// Build the one-shot prompt: today + schema + data + recent transcript + new message.
    static func userPrompt(message: String,
                           habits: [Habit],
                           entriesByHabit: [String: [LogEntry]],
                           today: Date,
                           history: [(role: String, text: String)],
                           maxRowsPerHabit: Int = 60) -> String {
        var s = "TODAY: \(DayMath.iso.string(from: today)) (\(weekday.string(from: today)))\n\n"

        s += "HABITS:\n"
        for h in habits {
            let style = h.choiceField != nil ? "session-style" : "daily"
            s += "### \(h.name) (id: \(h.id), goal: \(h.goal.rawValue), \(style))\n"
            for f in h.fields {
                var line = "- \(f.id): \(f.kind.rawValue)"
                if f.kind == .choice, let c = f.choices, !c.isEmpty {
                    line += " [\(c.joined(separator: "|"))]"
                }
                line += " — \(f.label)"
                s += line + "\n"
            }
            s += "\n"
        }

        s += "DATA (most recent first, up to \(maxRowsPerHabit) rows each):\n"
        for h in habits {
            let rows = (entriesByHabit[h.id] ?? []).sorted { $0.date > $1.date }.prefix(maxRowsPerHabit)
            s += "## \(h.id)\n"
            if rows.isEmpty {
                s += "(no entries)\n"
            } else {
                for e in rows {
                    let vals = h.fields.compactMap { f -> String? in
                        guard let v = e.string(f.id) else { return nil }
                        return "\(f.id)=\(v)"
                    }
                    s += "\(e.dateString) | \(vals.joined(separator: ", "))\n"
                }
            }
            s += "\n"
        }

        if !history.isEmpty {
            s += "CONVERSATION (recent):\n"
            for turn in history {
                s += "\(turn.role == "user" ? "User" : "Assistant"): \(turn.text)\n"
            }
            s += "\n"
        }

        s += "NEW MESSAGE:\n\(message)\n"
        return s
    }

    // MARK: Response parsing

    /// Tolerant parse: strips optional code fences, then reads the first balanced {...}.
    static func parse(_ raw: String) -> Result? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let nl = s.range(of: "\n") { s = String(s[nl.upperBound...]) }
            if let fence = s.range(of: "```", options: .backwards) { s = String(s[..<fence.lowerBound]) }
        }
        guard let start = s.firstIndex(of: "{"),
              let end = s.lastIndex(of: "}"),
              start < end else { return nil }

        let jsonStr = String(s[start...end])
        guard let data = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let kind = Result.Kind(rawValue: (obj["type"] as? String) ?? "answer") ?? .answer
        let reply = (obj["reply"] as? String) ?? ""

        var entries: [ProposedEntry] = []
        if let arr = obj["entries"] as? [[String: Any]] {
            for e in arr {
                guard let hid = e["habitId"] as? String else { continue }
                let date = e["date"] as? String
                var vals: [String: String] = [:]
                if let v = e["values"] as? [String: Any] {
                    for (k, raw) in v { vals[k] = stringify(raw) }
                }
                entries.append(ProposedEntry(habitId: hid, date: date, values: vals))
            }
        }
        return Result(kind: kind, reply: reply, entries: entries)
    }

    /// Coerce a JSON scalar to a string, distinguishing bool from int via the NSNumber type.
    private static func stringify(_ v: Any) -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber {
            let t = String(cString: n.objCType)
            if t == "c" || t == "B" { return n.boolValue ? "true" : "false" } // bool
            if t == "d" || t == "f" {                                          // floating point
                let d = n.doubleValue
                return d == d.rounded() ? String(Int(d)) : String(d)
            }
            return n.stringValue                                               // integer
        }
        if let b = v as? Bool { return b ? "true" : "false" }
        return String(describing: v)
    }
}
