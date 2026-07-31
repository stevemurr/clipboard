import AppKit
import SwiftUI

struct CodePreviewView: View {
    private static let maximumPreviewCharacters = 200_000

    let source: String
    let language: CodeLanguage
    var isTruncated = false

    private var previewSource: String {
        String(source.prefix(Self.maximumPreviewCharacters))
    }

    private var previewIsTruncated: Bool {
        isTruncated || source.count > Self.maximumPreviewCharacters
    }

    private var lineCount: Int {
        previewSource.reduce(into: 1) { count, character in
            if character == "\n" { count += 1 }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 11, weight: .bold))

                Text(language.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityIdentifier("preview-language")

                Spacer()

                Text("\(lineCount) \(lineCount == 1 ? "line" : "lines")")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.10), in: Capsule())

                if previewIsTruncated {
                    Text("Partial")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.22), in: Capsule())
                }
            }
            .foregroundStyle(Color.white.opacity(0.76))
            .padding(.horizontal, 12)
            .frame(height: 34)

            Divider().overlay(Color.white.opacity(0.14))

            CodeTextView(
                source: previewSource,
                language: language
            )
        }
        .background(Color.black.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.clipboardSeparator.opacity(0.80), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("preview-code")
        .padding(12)
    }
}

struct CodeFilePreviewView: View {
    let url: URL
    let language: CodeLanguage

    @State private var phase: Phase = .loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .accessibilityIdentifier("preview-code-loading")

            case .loaded(let payload):
                CodePreviewView(
                    source: payload.source,
                    language: language,
                    isTruncated: payload.isTruncated
                )

            case .unavailable:
                PreviewUnavailableView(
                    symbol: "doc.text.magnifyingglass",
                    title: "Preview unavailable",
                    message: "The source file could not be read."
                )
                .accessibilityIdentifier("preview-code-unavailable")
            }
        }
        .task(id: url) {
            phase = .loading
            if let payload = await CodeFilePreviewLoader.load(url: url) {
                guard !Task.isCancelled else { return }
                phase = .loaded(payload)
            } else {
                guard !Task.isCancelled else { return }
                phase = .unavailable
            }
        }
    }

    private enum Phase {
        case loading
        case loaded(CodeFilePreviewPayload)
        case unavailable
    }
}

struct PreviewUnavailableView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.70))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CodeFilePreviewPayload: Sendable {
    let source: String
    let isTruncated: Bool
}

private enum CodeFilePreviewLoader {
    static let maximumBytes = 262_144

    static func load(url: URL) async -> CodeFilePreviewPayload? {
        await Task.detached(priority: .userInitiated) {
            do {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { return nil }

                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
                let isTruncated = data.count > maximumBytes
                let previewData = isTruncated ? data.prefix(maximumBytes) : data[...]

                let source = decode(Data(previewData))
                guard let source, !source.isEmpty else { return nil }
                return CodeFilePreviewPayload(source: source, isTruncated: isTruncated)
            } catch {
                return nil
            }
        }.value
    }

    private static func decode(_ data: Data) -> String? {
        for encoding in [
            String.Encoding.utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .isoLatin1,
        ] {
            if let source = String(data: data, encoding: encoding) {
                return source
            }
        }
        return nil
    }
}

private struct CodeTextView: NSViewRepresentable {
    let source: String
    let language: CodeLanguage

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 13, height: 11)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.usesFindBar = true
        textView.setAccessibilityIdentifier("preview-code-text")

        scrollView.documentView = textView
        update(textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        guard textView.string != source else { return }
        update(textView)
        textView.scrollToBeginningOfDocument(nil)
    }

    private func update(_ textView: NSTextView) {
        textView.textStorage?.setAttributedString(
            CodeSyntaxHighlighter.highlight(source, language: language)
        )
    }
}

private enum CodeSyntaxHighlighter {
    private struct Candidate {
        let range: NSRange
        let color: NSColor
    }

    private struct Rule {
        let pattern: String
        let color: NSColor
        var options: NSRegularExpression.Options = []
    }

    private static let base = NSColor(
        calibratedRed: 0.90,
        green: 0.91,
        blue: 0.94,
        alpha: 1
    )
    private static let keyword = NSColor(
        calibratedRed: 0.82,
        green: 0.62,
        blue: 0.98,
        alpha: 1
    )
    private static let string = NSColor(
        calibratedRed: 0.55,
        green: 0.84,
        blue: 0.70,
        alpha: 1
    )
    private static let number = NSColor(
        calibratedRed: 0.96,
        green: 0.68,
        blue: 0.40,
        alpha: 1
    )
    private static let comment = NSColor(
        calibratedWhite: 0.64,
        alpha: 0.74
    )
    private static let member = NSColor(
        calibratedRed: 0.48,
        green: 0.74,
        blue: 0.96,
        alpha: 1
    )

    static func highlight(_ source: String, language: CodeLanguage) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.defaultTabInterval = 28
        paragraph.tabStops = []

        let result = NSMutableAttributedString(
            string: source,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular),
                .foregroundColor: base,
                .paragraphStyle: paragraph,
            ]
        )
        let fullRange = NSRange(source.startIndex..., in: source)
        var protectedIndexes = IndexSet()

        var protectedCandidates: [Candidate] = []
        for rule in protectedRules(for: language) {
            protectedCandidates.append(contentsOf: candidates(for: rule, in: source))
        }
        protectedCandidates.sort {
            if $0.range.location == $1.range.location {
                return $0.range.length > $1.range.length
            }
            return $0.range.location < $1.range.location
        }

        for candidate in protectedCandidates {
            let indexes = IndexSet(
                integersIn: candidate.range.location..<NSMaxRange(candidate.range)
            )
            guard protectedIndexes.intersection(indexes).isEmpty else { continue }
            result.addAttribute(
                .foregroundColor,
                value: candidate.color,
                range: candidate.range
            )
            protectedIndexes.formUnion(indexes)
        }

        var rules = semanticRules(for: language)
        if !language.keywords.isEmpty {
            let escaped = language.keywords
                .map(NSRegularExpression.escapedPattern(for:))
                .joined(separator: "|")
            rules.append(
                Rule(
                    pattern: #"\b(?:"# + escaped + #")\b"#,
                    color: keyword,
                    options: language == .sql ? [.caseInsensitive] : []
                )
            )
        }
        rules.append(
            Rule(
                pattern: #"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\b"#,
                color: number
            )
        )

        for rule in rules {
            for candidate in candidates(for: rule, in: source) {
                let indexes = IndexSet(
                    integersIn: candidate.range.location..<NSMaxRange(candidate.range)
                )
                guard protectedIndexes.intersection(indexes).isEmpty else { continue }
                result.addAttribute(
                    .foregroundColor,
                    value: candidate.color,
                    range: candidate.range
                )
            }
        }

        if fullRange.length == 0 {
            result.addAttribute(.foregroundColor, value: base, range: fullRange)
        }
        return result
    }

    private static func protectedRules(for language: CodeLanguage) -> [Rule] {
        let cComments = Rule(
            pattern: #"(?s:/\*.*?\*/)|(?m://[^\n]*)"#,
            color: comment
        )
        let hashComments = Rule(pattern: #"(?m)#[^\n]*"#, color: comment)
        let sqlComments = Rule(
            pattern: #"(?s:/\*.*?\*/)|(?m:--[^\n]*)"#,
            color: comment
        )
        let htmlComments = Rule(pattern: #"(?s:<!--.*?-->)"#, color: comment)
        let quoted = Rule(
            pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#,
            color: string
        )
        let quotedWithBackticks = Rule(
            pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#,
            color: string
        )
        let tripleQuoted = Rule(
            pattern: #"(?s:""".*?"""|'''.*?''')|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#,
            color: string
        )
        let sqlQuoted = Rule(pattern: #"'(?:''|[^'])*'"#, color: string)

        switch language {
        case .python:
            return [hashComments, tripleQuoted]
        case .shell, .yaml:
            return [hashComments, quoted]
        case .html:
            return [htmlComments, quoted]
        case .sql:
            return [sqlComments, sqlQuoted]
        case .javascript, .typescript:
            return [cComments, quotedWithBackticks]
        case .swift:
            return [
                cComments,
                Rule(
                    pattern: #"(?s:""".*?""")|"(?:\\.|[^"\\])*""#,
                    color: string
                ),
            ]
        case .json:
            return [Rule(pattern: #""(?:\\.|[^"\\])*""#, color: string)]
        case .css, .go, .rust, .c, .cpp, .java, .generic:
            return [cComments, quoted]
        }
    }

    private static func semanticRules(for language: CodeLanguage) -> [Rule] {
        switch language {
        case .html:
            return [
                Rule(pattern: #"</?[A-Za-z][A-Za-z0-9:-]*"#, color: keyword),
                Rule(pattern: #"\b[A-Za-z_:][-A-Za-z0-9_:.]*(?=\s*=)"#, color: member),
            ]
        case .css:
            return [
                Rule(pattern: #"\b[-A-Za-z]+(?=\s*:)"#, color: member),
                Rule(pattern: #"(?m)^\s*[.#][-_A-Za-z0-9]+"#, color: keyword),
            ]
        case .json, .yaml:
            return [
                Rule(pattern: #""(?:\\.|[^"\\])*"(?=\s*:)"#, color: member),
                Rule(pattern: #"(?m)^\s*[A-Za-z_][\w.-]*(?=\s*:)"#, color: member),
            ]
        case .swift:
            return [
                Rule(pattern: #"@[A-Za-z_]\w*"#, color: member),
                Rule(pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#, color: member),
            ]
        case .c, .cpp:
            return [Rule(pattern: #"(?m)^\s*#[A-Za-z]+\b"#, color: member)]
        default:
            return []
        }
    }

    private static func candidates(for rule: Rule, in source: String) -> [Candidate] {
        guard let expression = try? NSRegularExpression(
            pattern: rule.pattern,
            options: rule.options
        ) else { return [] }
        return expression.matches(
            in: source,
            range: NSRange(source.startIndex..., in: source)
        ).map {
            Candidate(range: $0.range, color: rule.color)
        }
    }
}
