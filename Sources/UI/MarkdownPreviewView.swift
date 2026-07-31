import Foundation
import SwiftUI

struct MarkdownPreviewView: View {
    let markdown: String

    private var document: NativeMarkdownDocument {
        NativeMarkdownDocument(markdown: markdown)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 11) {
                ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                    MarkdownBlockView(block: block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.primary.opacity(0.022))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.clipboardSeparator.opacity(0.72), lineWidth: 0.75)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("preview-markdown")
        .padding(12)
    }
}

struct MarkdownFilePreviewView: View {
    let url: URL

    @State private var phase: MarkdownFilePhase = .loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .accessibilityIdentifier("preview-markdown-loading")

            case .loaded(let markdown):
                MarkdownPreviewView(markdown: markdown)

            case .unavailable:
                PreviewUnavailableView(
                    symbol: "doc.text.magnifyingglass",
                    title: "Preview unavailable",
                    message: "The Markdown file could not be read."
                )
                .accessibilityIdentifier("preview-markdown-unavailable")
            }
        }
        .task(id: url) {
            phase = .loading
            if let markdown = await MarkdownFilePreviewLoader.load(url: url) {
                guard !Task.isCancelled else { return }
                phase = .loaded(markdown)
            } else {
                guard !Task.isCancelled else { return }
                phase = .unavailable
            }
        }
    }
}

private enum MarkdownFilePhase {
    case loading
    case loaded(String)
    case unavailable
}

private enum MarkdownFilePreviewLoader {
    private static let maximumBytes = 262_144

    static func load(url: URL) async -> String? {
        let task = Task.detached(priority: .userInitiated) { () -> String? in
            do {
                try Task.checkCancellation()
                let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { return nil }

                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: maximumBytes) ?? Data()
                try Task.checkCancellation()
                guard !data.isEmpty else { return nil }

                for encoding in [
                    String.Encoding.utf8,
                    .utf16,
                    .utf16LittleEndian,
                    .utf16BigEndian,
                    .isoLatin1,
                ] {
                    if let markdown = String(data: data, encoding: encoding) {
                        return markdown
                    }
                }
                return nil
            } catch {
                return nil
            }
        }

        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

private struct MarkdownBlockView: View {
    let block: NativeMarkdownDocument.Block

    var body: some View {
        switch block {
        case .heading(let level, let text):
            MarkdownInlineText(
                source: text,
                font: headingFont(for: level),
                weight: level <= 2 ? .bold : .semibold
            )
            .padding(.top, level == 1 ? 3 : 0)

        case .paragraph(let text):
            MarkdownInlineText(
                source: text,
                font: .system(size: 13.5),
                weight: .regular
            )
            .lineSpacing(3)

        case .unorderedItem(let depth, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(Color.secondary)
                    .frame(width: depth == 0 ? 5 : 4, height: depth == 0 ? 5 : 4)
                    .padding(.leading, CGFloat(depth) * 15)

                MarkdownInlineText(
                    source: text,
                    font: .system(size: 13.5),
                    weight: .regular
                )
            }

        case .orderedItem(let depth, let ordinal, let text):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(ordinal).")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondary)
                    .frame(minWidth: 20, alignment: .trailing)
                    .padding(.leading, CGFloat(depth) * 15)

                MarkdownInlineText(
                    source: text,
                    font: .system(size: 13.5),
                    weight: .regular
                )
            }

        case .quote(let text):
            HStack(alignment: .top, spacing: 10) {
                Capsule()
                    .fill(Color.accentColor.opacity(0.48))
                    .frame(width: 3)

                MarkdownInlineText(
                    source: text,
                    font: .system(size: 13.5),
                    weight: .regular
                )
                .foregroundStyle(Color.secondary)
                .lineSpacing(3)
            }
            .padding(.vertical, 2)

        case .code(let language, let source):
            VStack(alignment: .leading, spacing: 0) {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .padding(.horizontal, 11)
                        .frame(height: 27)
                }

                ScrollView(.horizontal) {
                    Text(source)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.75)
            }

        case .rule:
            Divider()
                .padding(.vertical, 4)
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            .system(size: 21)
        case 2:
            .system(size: 18)
        case 3:
            .system(size: 15.5)
        default:
            .system(size: 13.5)
        }
    }
}

private struct MarkdownInlineText: View {
    let source: String
    let font: Font
    let weight: Font.Weight

    private var attributedText: AttributedString {
        MarkdownSanitizer.inlineAttributedString(from: source)
    }

    var body: some View {
        Text(attributedText)
            .font(font.weight(weight))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NativeMarkdownDocument {
    enum Block {
        case heading(level: Int, text: String)
        case paragraph(String)
        case unorderedItem(depth: Int, text: String)
        case orderedItem(depth: Int, ordinal: Int, text: String)
        case quote(String)
        case code(language: String?, source: String)
        case rule
    }

    let blocks: [Block]

    init(markdown: String) {
        let sanitized = MarkdownSanitizer.sanitizeDocument(markdown)
        blocks = Self.parse(sanitized)
    }

    private static func parse(_ source: String) -> [Block] {
        let lines = source.components(separatedBy: .newlines)
        var blocks: [Block] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if let fence = fenceStart(in: line) {
                var codeLines: [String] = []
                index += 1
                while index < lines.count, !isClosingFence(lines[index], marker: fence.marker) {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count {
                    index += 1
                }
                blocks.append(
                    .code(
                        language: fence.language,
                        source: codeLines.joined(separator: "\n")
                    )
                )
                continue
            }

            if let heading = heading(in: line) {
                blocks.append(.heading(level: heading.level, text: heading.text))
                index += 1
                continue
            }

            if isThematicRule(line) {
                blocks.append(.rule)
                index += 1
                continue
            }

            if let item = unorderedItem(in: line) {
                blocks.append(.unorderedItem(depth: item.depth, text: item.text))
                index += 1
                continue
            }

            if let item = orderedItem(in: line) {
                blocks.append(
                    .orderedItem(
                        depth: item.depth,
                        ordinal: item.ordinal,
                        text: item.text
                    )
                )
                index += 1
                continue
            }

            if quoteText(in: line) != nil {
                var quotedLines: [String] = []
                while index < lines.count, let quote = quoteText(in: lines[index]) {
                    quotedLines.append(quote)
                    index += 1
                }
                blocks.append(.quote(quotedLines.joined(separator: "\n")))
                continue
            }

            var paragraphLines = [trimmed]
            index += 1
            while index < lines.count {
                let next = lines[index]
                let nextTrimmed = next.trimmingCharacters(in: .whitespaces)
                guard !nextTrimmed.isEmpty, !isStructuralStart(next) else { break }
                paragraphLines.append(nextTrimmed)
                index += 1
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
        }

        return blocks
    }

    private static func fenceStart(in line: String) -> (marker: String, language: String?)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let marker: String
        if trimmed.hasPrefix("```") {
            marker = "```"
        } else if trimmed.hasPrefix("~~~") {
            marker = "~~~"
        } else {
            return nil
        }

        let suffix = String(trimmed.dropFirst(marker.count))
            .trimmingCharacters(in: .whitespaces)
        let language = suffix
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)
        return (marker, language)
    }

    private static func isClosingFence(_ line: String, marker: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(marker)
    }

    private static func heading(in line: String) -> (level: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let hashes = trimmed.prefix(while: { $0 == "#" })
        guard (1...6).contains(hashes.count),
              trimmed.dropFirst(hashes.count).first?.isWhitespace == true
        else {
            return nil
        }

        var text = String(trimmed.dropFirst(hashes.count))
            .trimmingCharacters(in: .whitespaces)
        text = text.replacingOccurrences(
            of: #"\s+#+\s*$"#,
            with: "",
            options: .regularExpression
        )
        return (hashes.count, text)
    }

    private static func unorderedItem(in line: String) -> (depth: Int, text: String)? {
        guard let match = regularExpression(
            #"^(\s{0,6})[-+*]\s+(.+)$"#,
            in: line
        ) else {
            return nil
        }
        return (
            min(match.string(at: 1).count / 2, 3),
            match.string(at: 2)
        )
    }

    private static func orderedItem(
        in line: String
    ) -> (depth: Int, ordinal: Int, text: String)? {
        guard let match = regularExpression(
            #"^(\s{0,6})(\d+)[.)]\s+(.+)$"#,
            in: line
        ), let ordinal = Int(match.string(at: 2))
        else {
            return nil
        }
        return (
            min(match.string(at: 1).count / 2, 3),
            ordinal,
            match.string(at: 3)
        )
    }

    private static func quoteText(in line: String) -> String? {
        guard let match = regularExpression(
            #"^\s{0,3}>\s?(.*)$"#,
            in: line
        ) else {
            return nil
        }
        return match.string(at: 1)
    }

    private static func isThematicRule(_ line: String) -> Bool {
        line.range(
            of: #"^\s{0,3}(?:(?:\*\s*){3,}|(?:-\s*){3,}|(?:_\s*){3,})$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isStructuralStart(_ line: String) -> Bool {
        fenceStart(in: line) != nil
            || heading(in: line) != nil
            || unorderedItem(in: line) != nil
            || orderedItem(in: line) != nil
            || quoteText(in: line) != nil
            || isThematicRule(line)
    }

    private static func regularExpression(
        _ pattern: String,
        in source: String
    ) -> MarkdownRegexMatch? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: source,
                  range: NSRange(source.startIndex..., in: source)
              )
        else {
            return nil
        }
        return MarkdownRegexMatch(source: source, result: match)
    }
}

private struct MarkdownRegexMatch {
    let source: String
    let result: NSTextCheckingResult

    func string(at index: Int) -> String {
        let range = result.range(at: index)
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: source)
        else {
            return ""
        }
        return String(source[swiftRange])
    }
}

enum MarkdownSanitizer {
    private static let maximumPreviewCharacters = 200_000

    static func sanitizeDocument(_ markdown: String) -> String {
        var result = String(markdown.prefix(maximumPreviewCharacters))

        result = replacing(
            #"(?is)<(script|style)\b[^>]*>.*?</\1\s*>"#,
            in: result,
            with: ""
        )
        result = replacing(
            #"!\[([^\]\n]*)\]\([^)]+\)"#,
            in: result,
            with: "[Image: $1]"
        )
        result = replacing(
            #"!\[([^\]\n]*)\]\[[^\]\n]*\]"#,
            in: result,
            with: "[Image: $1]"
        )
        // A malformed image declaration is still rendered as plain text. This
        // renderer never creates an image request from Markdown content.
        result = result.replacingOccurrences(of: "![", with: "[Image: ")
        result = replacing(
            #"<(https?://[^>\s]+)>"#,
            in: result,
            with: "[$1]($1)"
        )
        result = replacing(
            #"(?is)</?[A-Za-z][^>]*>"#,
            in: result,
            with: ""
        )

        return result
    }

    static func inlineAttributedString(from markdown: String) -> AttributedString {
        let sanitized = sanitizeDocument(markdown)
        var attributed = (try? AttributedString(
            markdown: sanitized,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(sanitized)

        let unsafeLinkRanges = attributed.runs.compactMap { run -> Range<AttributedString.Index>? in
            guard let link = run.link else { return nil }
            let scheme = link.scheme?.lowercased()
            return ["http", "https", "mailto"].contains(scheme) ? nil : run.range
        }
        for range in unsafeLinkRanges {
            attributed[range].link = nil
        }

        return attributed
    }

    private static func replacing(
        _ pattern: String,
        in source: String,
        with replacement: String
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return source
        }
        return expression.stringByReplacingMatches(
            in: source,
            range: NSRange(source.startIndex..., in: source),
            withTemplate: replacement
        )
    }
}
