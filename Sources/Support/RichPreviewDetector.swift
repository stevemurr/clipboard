import Foundation

enum RichTextPreviewKind: Equatable {
    case markdown
    case youtube(YouTubeLink)
    case link(URL)

    var displayName: String {
        switch self {
        case .markdown:
            "Markdown"
        case .youtube:
            "YouTube"
        case .link:
            "Link"
        }
    }

    var systemImageName: String {
        switch self {
        case .markdown:
            "text.document"
        case .youtube:
            "play.rectangle.fill"
        case .link:
            "link"
        }
    }

    /// Classifies only presentation-rich text. Call this before the ordinary-text
    /// fallback and before code detection when Markdown documents should win over
    /// fenced-code detection.
    static func detect(_ text: String) -> RichTextPreviewKind? {
        if let url = WebLinkDetector.detect(text) {
            if let youtube = YouTubeLink(url: url) {
                return .youtube(youtube)
            }
            return .link(url)
        }

        return MarkdownDetector.isMarkdown(text) ? .markdown : nil
    }
}

enum WebLinkDetector {
    private static let maximumURLCharacters = 4_096

    /// Returns a URL only when the complete clipboard value is one ordinary
    /// HTTP(S) URL. Prose containing a URL remains prose.
    static func detect(_ text: String) -> URL? {
        let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty,
              candidate.count <= maximumURLCharacters,
              candidate.unicodeScalars.allSatisfy({ !CharacterSet.whitespacesAndNewlines.contains($0) }),
              let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host?.isEmpty == false,
              let url = components.url
        else {
            return nil
        }
        return url
    }
}

struct YouTubeLink: Equatable, Hashable {
    let originalURL: URL
    let videoID: String

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let rawHost = components.host?.lowercased()
        else {
            return nil
        }

        let host = rawHost.hasSuffix(".") ? String(rawHost.dropLast()) : rawHost
        let pathComponents = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        let candidate: String?
        switch host {
        case "youtu.be", "www.youtu.be":
            candidate = pathComponents.first

        case "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com":
            if pathComponents.first?.lowercased() == "watch" || pathComponents.isEmpty {
                candidate = components.queryItems?
                    .first(where: { $0.name.lowercased() == "v" })?
                    .value
            } else if let route = pathComponents.first?.lowercased(),
                      ["shorts", "live", "embed"].contains(route),
                      pathComponents.count >= 2
            {
                candidate = pathComponents[1]
            } else {
                candidate = nil
            }

        default:
            candidate = nil
        }

        guard let candidate,
              Self.isValidVideoID(candidate)
        else {
            return nil
        }

        originalURL = url
        videoID = candidate
    }

    var canonicalURL: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube.com"
        components.path = "/watch"
        components.queryItems = [URLQueryItem(name: "v", value: videoID)]
        return components.url ?? originalURL
    }

    private static func isValidVideoID(_ value: String) -> Bool {
        guard (6...32).contains(value.count) else { return false }
        return value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "_" || $0 == "-"
        }
    }
}

enum MarkdownDetector {
    private static let maximumScannedCharacters = 32_768

    static func isMarkdownFileExtension(_ value: String) -> Bool {
        ["md", "markdown", "mdown", "mkd", "mkdn"].contains(value.lowercased())
    }

    /// Intentionally requires more than isolated emphasis or a single link, so
    /// everyday prose does not unexpectedly switch to the Markdown renderer.
    static func isMarkdown(_ source: String) -> Bool {
        let text = String(source.prefix(maximumScannedCharacters))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.contains("\n") else { return false }
        guard !isPureFencedCodeBlock(text) else { return false }

        let headingCount = matchCount(#"(?m)^\s{0,3}#{1,6}\s+\S"#, in: text)
        let listCount = matchCount(#"(?m)^\s{0,6}(?:[-+*]|\d+[.)])\s+\S"#, in: text)
        let quoteCount = matchCount(#"(?m)^\s{0,3}>\s?\S"#, in: text)
        let fenceCount = matchCount(#"(?m)^\s{0,3}(?:```|~~~)"#, in: text)
        let linkCount = matchCount(#"\[[^\]\n]+\]\((?:https?://|mailto:)[^)\s]+\)"#, in: text)
        let emphasisCount = matchCount(#"(?<!\*)\*\*[^*\n]+\*\*(?!\*)|(?<!_)__[^_\n]+__(?!_)"#, in: text)
        let thematicRuleCount = matchCount(#"(?m)^\s{0,3}(?:(?:\*\s*){3,}|(?:-\s*){3,}|(?:_\s*){3,})$"#, in: text)

        var score = 0
        var signals = 0

        if headingCount > 0 {
            score += 4
            signals += 1
        }
        if listCount >= 2 {
            score += 3
            signals += 1
        }
        if quoteCount >= 2 {
            score += 3
            signals += 1
        }
        if fenceCount >= 2 {
            score += 4
            signals += 1
        }
        if linkCount > 0 {
            score += 2
            signals += 1
        }
        if emphasisCount > 0 {
            score += 1
            signals += 1
        }
        if thematicRuleCount > 0 {
            score += 1
            signals += 1
        }
        if hasProseContinuation(in: text, excludingStructuralLines: true) {
            score += 1
            signals += 1
        }

        let repeatedStructuralBlock = listCount >= 2 || quoteCount >= 2
        return repeatedStructuralBlock || (score >= 5 && signals >= 2)
    }

    private static func hasProseContinuation(
        in text: String,
        excludingStructuralLines: Bool
    ) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        var openFence: String?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                let marker = String(line.prefix(3))
                openFence = openFence == nil ? marker : nil
                continue
            }
            if openFence != nil || line.count < 6 {
                continue
            }
            if excludingStructuralLines {
                let structuralPrefixes = ["#", "-", "*", "+", ">", "`", "~"]
                if structuralPrefixes.contains(where: { line.hasPrefix($0) }) {
                    continue
                }
                if line.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) != nil {
                    continue
                }
            }
            if line.rangeOfCharacter(from: .letters) != nil {
                return true
            }
        }
        return false
    }

    private static func isPureFencedCodeBlock(_ text: String) -> Bool {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        guard let firstIndex = lines.firstIndex(where: { !$0.isEmpty }),
              let lastIndex = lines.lastIndex(where: { !$0.isEmpty }),
              firstIndex < lastIndex
        else {
            return false
        }

        let first = lines[firstIndex]
        let marker: String
        if first.hasPrefix("```") {
            marker = "```"
        } else if first.hasPrefix("~~~") {
            marker = "~~~"
        } else {
            return false
        }

        return lines[lastIndex].hasPrefix(marker)
    }

    private static func matchCount(_ pattern: String, in text: String) -> Int {
        guard let expression = PreviewRegexCache.expression(pattern: pattern) else {
            return 0
        }
        return expression.numberOfMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
    }
}
