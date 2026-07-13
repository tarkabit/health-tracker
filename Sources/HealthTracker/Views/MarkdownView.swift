import SwiftUI

/// A lightweight Markdown renderer for assistant replies — enough of CommonMark to make
/// answers readable: headings, bullet/numbered lists, fenced code, tables, and inline
/// **bold** / *italic* / `code`. Self-contained (no external dependency).
struct MarkdownView: View {
    let text: String

    var body: some View {
        let blocks = MarkdownParser.parse(text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func view(for block: MarkdownParser.Block) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(headingFont(level))
                .fontWeight(.semibold)
                .padding(.top, level <= 2 ? 2 : 0)

        case .paragraph(let text):
            Text(inline(text))
                .fixedSize(horizontal: false, vertical: true)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(inline(item)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .ordered(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(i + 1).").foregroundStyle(.secondary).monospacedDigit()
                        Text(inline(item)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .code(let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
            .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

        case .table(let header, let rows):
            tableView(header: header, rows: rows)
        }
    }

    private func tableView(header: [String], rows: [[String]]) -> some View {
        let columns = header.count
        return ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    ForEach(0..<columns, id: \.self) { c in
                        Text(inline(header[safe: c] ?? "")).fontWeight(.semibold)
                    }
                }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { c in
                            Text(inline(row[safe: c] ?? ""))
                        }
                    }
                }
            }
            .padding(10)
        }
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title3
        case 2: return .headline
        default: return .subheadline
        }
    }

    /// Inline markdown (**bold**, *italic*, `code`, links) with whitespace preserved.
    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(s)
    }
}

// MARK: - Parser

enum MarkdownParser {
    enum Block {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullets([String])
        case ordered([String])
        case code(String)
        case table(header: [String], rows: [[String]])
    }

    static func parse(_ raw: String) -> [Block] {
        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [Block] = []
        var paragraph: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph.removeAll()
            }
        }

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block
            if trimmed.hasPrefix("```") {
                flushParagraph()
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i]); i += 1
                }
                i += 1 // skip closing fence
                blocks.append(.code(code.joined(separator: "\n")))
                continue
            }

            // Table: a `|` row followed by a |---|---| separator
            if trimmed.hasPrefix("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                flushParagraph()
                let header = tableCells(trimmed)
                var rows: [[String]] = []
                i += 2 // header + separator
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    rows.append(tableCells(lines[i])); i += 1
                }
                blocks.append(.table(header: header, rows: rows))
                continue
            }

            // Blank line ends a paragraph
            if trimmed.isEmpty { flushParagraph(); i += 1; continue }

            // Heading
            if let h = heading(trimmed) { flushParagraph(); blocks.append(h); i += 1; continue }

            // Bullet list (consecutive)
            if isBullet(trimmed) {
                flushParagraph()
                var items: [String] = []
                while i < lines.count, isBullet(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(bulletText(lines[i].trimmingCharacters(in: .whitespaces))); i += 1
                }
                blocks.append(.bullets(items)); continue
            }

            // Ordered list (consecutive)
            if isOrdered(trimmed) {
                flushParagraph()
                var items: [String] = []
                while i < lines.count, isOrdered(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(orderedText(lines[i].trimmingCharacters(in: .whitespaces))); i += 1
                }
                blocks.append(.ordered(items)); continue
            }

            // Otherwise: paragraph text
            paragraph.append(trimmed)
            i += 1
        }
        flushParagraph()
        return blocks
    }

    // MARK: line classifiers

    private static func heading(_ s: String) -> Block? {
        guard s.hasPrefix("#") else { return nil }
        let hashes = s.prefix { $0 == "#" }
        let level = hashes.count
        guard level >= 1, level <= 6 else { return nil }
        let rest = s.dropFirst(level)
        guard rest.first == " " else { return nil }
        return .heading(level: level, text: rest.trimmingCharacters(in: .whitespaces))
    }

    private static func isBullet(_ s: String) -> Bool {
        (s.hasPrefix("- ") || s.hasPrefix("* ") || s.hasPrefix("+ "))
    }
    private static func bulletText(_ s: String) -> String { String(s.dropFirst(2)) }

    private static func isOrdered(_ s: String) -> Bool {
        guard let dot = s.firstIndex(where: { $0 == "." || $0 == ")" }) else { return false }
        let num = s[s.startIndex..<dot]
        return !num.isEmpty && num.allSatisfy(\.isNumber) && s.index(after: dot) < s.endIndex && s[s.index(after: dot)] == " "
    }
    private static func orderedText(_ s: String) -> String {
        guard let dot = s.firstIndex(where: { $0 == "." || $0 == ")" }) else { return s }
        return String(s[s.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
    }

    private static func isTableSeparator(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("|") else { return false }
        return t.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " } && t.contains("-")
    }
    private static func tableCells(_ s: String) -> [String] {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
