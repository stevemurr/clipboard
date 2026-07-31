import Foundation

enum CodeLanguage: String, CaseIterable {
    case swift
    case json
    case typescript
    case javascript
    case python
    case shell
    case html
    case css
    case sql
    case go
    case rust
    case c
    case cpp
    case java
    case yaml
    case generic

    var displayName: String {
        switch self {
        case .swift: "Swift"
        case .json: "JSON"
        case .typescript: "TypeScript"
        case .javascript: "JavaScript"
        case .python: "Python"
        case .shell: "Shell"
        case .html: "HTML"
        case .css: "CSS"
        case .sql: "SQL"
        case .go: "Go"
        case .rust: "Rust"
        case .c: "C"
        case .cpp: "C++"
        case .java: "Java"
        case .yaml: "YAML"
        case .generic: "Code"
        }
    }

    var keywords: [String] {
        switch self {
        case .swift:
            [
                "actor", "associatedtype", "async", "await", "break", "case", "catch",
                "class", "continue", "default", "defer", "deinit", "do", "else", "enum",
                "extension", "false", "fileprivate", "for", "func", "guard", "if", "import",
                "in", "init", "inout", "internal", "is", "let", "nil", "nonisolated", "open",
                "private", "protocol", "public", "repeat", "return", "self", "some", "static",
                "struct", "subscript", "super", "switch", "throw", "throws", "true", "try",
                "typealias", "var", "where", "while",
            ]
        case .json:
            ["false", "null", "true"]
        case .typescript:
            [
                "abstract", "any", "as", "async", "await", "boolean", "break", "case",
                "class", "const", "continue", "declare", "default", "delete", "do", "else",
                "enum", "export", "extends", "false", "finally", "for", "from", "function",
                "if", "implements", "import", "in", "instanceof", "interface", "keyof", "let",
                "namespace", "never", "new", "null", "number", "of", "private", "protected",
                "public", "readonly", "return", "static", "string", "super", "switch", "this",
                "throw", "true", "try", "type", "typeof", "undefined", "unknown", "var", "void",
                "while", "yield",
            ]
        case .javascript:
            [
                "async", "await", "break", "case", "catch", "class", "const", "continue",
                "debugger", "default", "delete", "do", "else", "export", "extends", "false",
                "finally", "for", "from", "function", "if", "import", "in", "instanceof", "let",
                "new", "null", "of", "return", "static", "super", "switch", "this", "throw",
                "true", "try", "typeof", "undefined", "var", "void", "while", "yield",
            ]
        case .python:
            [
                "and", "as", "assert", "async", "await", "break", "case", "class", "continue",
                "def", "del", "elif", "else", "except", "False", "finally", "for", "from",
                "global", "if", "import", "in", "is", "lambda", "match", "None", "nonlocal",
                "not", "or", "pass", "raise", "return", "True", "try", "while", "with", "yield",
            ]
        case .shell:
            [
                "case", "cd", "do", "done", "echo", "elif", "else", "esac", "exit", "export",
                "fi", "for", "function", "if", "in", "local", "printf", "read", "return", "set",
                "shift", "then", "unset", "while",
            ]
        case .html:
            ["DOCTYPE"]
        case .css:
            [
                "important", "inherit", "initial", "none", "revert", "transparent", "unset",
            ]
        case .sql:
            [
                "ALTER", "AND", "AS", "ASC", "BEGIN", "BY", "CASE", "CREATE", "DELETE",
                "DESC", "DISTINCT", "DROP", "ELSE", "END", "EXISTS", "FROM", "FULL", "GROUP",
                "HAVING", "INNER", "INSERT", "INTO", "JOIN", "LEFT", "LIMIT", "NOT", "NULL",
                "ON", "OR", "ORDER", "OUTER", "RETURNING", "RIGHT", "SELECT", "SET", "TABLE",
                "THEN", "UNION", "UPDATE", "VALUES", "WHEN", "WHERE", "WITH",
            ]
        case .go:
            [
                "break", "case", "chan", "const", "continue", "default", "defer", "else",
                "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map",
                "package", "range", "return", "select", "struct", "switch", "type", "var",
            ]
        case .rust:
            [
                "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else",
                "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop",
                "match", "mod", "move", "mut", "pub", "ref", "return", "self", "Self", "static",
                "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while",
            ]
        case .c, .cpp:
            [
                "auto", "bool", "break", "case", "char", "class", "const", "constexpr",
                "continue", "default", "delete", "do", "double", "else", "enum", "explicit",
                "extern", "false", "float", "for", "friend", "if", "inline", "int", "long",
                "namespace", "new", "nullptr", "private", "protected", "public", "return",
                "short", "signed", "sizeof", "static", "struct", "switch", "template", "this",
                "throw", "true", "try", "typedef", "typename", "union", "unsigned", "using",
                "virtual", "void", "volatile", "while",
            ]
        case .java:
            [
                "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
                "class", "const", "continue", "default", "do", "double", "else", "enum",
                "extends", "false", "final", "finally", "float", "for", "if", "implements",
                "import", "instanceof", "int", "interface", "long", "native", "new", "null",
                "package", "private", "protected", "public", "return", "short", "static",
                "strictfp", "super", "switch", "synchronized", "this", "throw", "throws",
                "transient", "true", "try", "void", "volatile", "while",
            ]
        case .yaml:
            ["false", "null", "true", "yes", "no"]
        case .generic:
            []
        }
    }

    static func from(fileExtension value: String) -> CodeLanguage? {
        switch value.lowercased() {
        case "swift": .swift
        case "json", "jsonc", "geojson": .json
        case "ts", "tsx": .typescript
        case "js", "jsx", "mjs", "cjs": .javascript
        case "py", "pyw": .python
        case "sh", "bash", "zsh", "fish": .shell
        case "html", "htm", "xml", "svg": .html
        case "css", "scss", "sass", "less": .css
        case "sql": .sql
        case "go": .go
        case "rs": .rust
        case "c", "h": .c
        case "cc", "cpp", "cxx", "hh", "hpp", "hxx": .cpp
        case "java": .java
        case "yaml", "yml": .yaml
        case "kt", "kts", "m", "mm", "php", "rb", "r", "lua", "pl", "toml":
            .generic
        default:
            nil
        }
    }

    static func from(fenceLabel value: String) -> CodeLanguage? {
        switch value.lowercased() {
        case "sh", "bash", "zsh", "shell": .shell
        case "js", "jsx", "javascript": .javascript
        case "ts", "tsx", "typescript": .typescript
        case "py", "python": .python
        case "rs", "rust": .rust
        case "golang": .go
        case "html", "xml": .html
        case "yml", "yaml": .yaml
        case "c++": .cpp
        default:
            CodeLanguage(rawValue: value.lowercased())
        }
    }
}

enum PreviewRegexCache {
    private static let expressions: NSCache<NSString, NSRegularExpression> = {
        let cache = NSCache<NSString, NSRegularExpression>()
        cache.countLimit = 128
        return cache
    }()

    static func expression(
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression? {
        let key = "\(options.rawValue):\(pattern)" as NSString
        if let cached = expressions.object(forKey: key) {
            return cached
        }
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: options
        ) else {
            return nil
        }
        expressions.setObject(expression, forKey: key)
        return expression
    }
}

enum CodeSnippetDetector {
    private static let maximumScannedCharacters = 32_768

    static func detect(_ source: String) -> CodeLanguage? {
        let sample = String(source.prefix(maximumScannedCharacters))
        let trimmed = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let fenced = fencedLanguage(in: trimmed) {
            return fenced
        }
        if isJSONObjectOrArray(trimmed) {
            return .json
        }

        let scores: [(CodeLanguage, Int)] = [
            (.html, htmlScore(trimmed)),
            (.css, cssScore(trimmed)),
            (.sql, sqlScore(trimmed)),
            (.swift, swiftScore(trimmed)),
            (.typescript, typeScriptScore(trimmed)),
            (.javascript, javaScriptScore(trimmed)),
            (.python, pythonScore(trimmed)),
            (.shell, shellScore(trimmed)),
            (.go, goScore(trimmed)),
            (.rust, rustScore(trimmed)),
            (.java, javaScore(trimmed)),
            (.cpp, cFamilyScore(trimmed)),
            (.yaml, yamlScore(trimmed)),
        ]

        if let strongest = scores.max(by: { $0.1 < $1.1 }), strongest.1 >= 5 {
            return strongest.0
        }
        return genericScore(trimmed) >= 6 ? .generic : nil
    }

    private static func fencedLanguage(in text: String) -> CodeLanguage? {
        guard let match = firstMatch(#"(?m)^\s*```([A-Za-z0-9+#-]*)\s*$"#, in: text) else {
            return nil
        }
        let labelRange = match.range(at: 1)
        guard labelRange.location != NSNotFound,
              let range = Range(labelRange, in: text)
        else { return .generic }
        let label = String(text[range])
        return label.isEmpty ? .generic : CodeLanguage.from(fenceLabel: label) ?? .generic
    }

    private static func isJSONObjectOrArray(_ text: String) -> Bool {
        guard text.first == "{" || text.first == "[",
              let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              object is NSDictionary || object is NSArray
        else { return false }
        return true
    }

    private static func swiftScore(_ text: String) -> Int {
        var score = 0
        score += contains(#"(?m)^\s*import\s+(SwiftUI|Foundation|AppKit|UIKit|Combine)\b"#, in: text) ? 5 : 0
        score += min(matchCount(#"\b(func|struct|class|enum|protocol|extension|actor)\b"#, in: text), 2) * 2
        score += contains(#"\b(let|var)\s+\w+\s*(?::[^=]+)?="#, in: text) ? 2 : 0
        score += contains(#"@(MainActor|Observable|State|Binding|Published)\b"#, in: text) ? 3 : 0
        score += contains(#"\bguard\b.+\belse\b"#, in: text) ? 2 : 0
        return score
    }

    private static func typeScriptScore(_ text: String) -> Int {
        var score = javaScriptScore(text)
        score += contains(#"\b(interface|namespace|declare)\s+[A-Za-z_$]"#, in: text) ? 4 : 0
        score += contains(#"\btype\s+[A-Za-z_$]\w*\s*="#, in: text) ? 4 : 0
        score += contains(#":\s*(string|number|boolean|unknown|never)(?:\[\])?\b"#, in: text) ? 3 : 0
        return score
    }

    private static func javaScriptScore(_ text: String) -> Int {
        var score = 0
        score += contains(#"\b(const|let|var)\s+[A-Za-z_$]\w*\s*="#, in: text) ? 2 : 0
        score += contains(#"=>|\bfunction\s+[A-Za-z_$]\w*\s*\("#, in: text) ? 3 : 0
        score += contains(#"\b(import|export)\b.+\b(from|default)\b"#, in: text) ? 3 : 0
        score += contains(#"\b(console|document|window)\."#, in: text) ? 3 : 0
        score += contains(#"[{};]"#, in: text) ? 1 : 0
        return score
    }

    private static func pythonScore(_ text: String) -> Int {
        var score = 0
        score += contains(#"(?m)^\s*(async\s+)?(def|class)\s+\w+.*:\s*$"#, in: text) ? 4 : 0
        score += contains(#"(?m)^\s*(from\s+\S+\s+import|import\s+\S+)"#, in: text) ? 3 : 0
        score += contains(#"(?m)^\s*(if|elif|else|for|while|with|try|except).+:\s*$"#, in: text) ? 2 : 0
        score += contains(#"\b(__name__|self\.|print\()"#, in: text) ? 3 : 0
        return score
    }

    private static func shellScore(_ text: String) -> Int {
        var score = 0
        score += contains(#"^#!\s*/.*\b(bash|zsh|sh|fish)\b"#, in: text) ? 10 : 0
        score += contains(#"(?m)^\s*(export|echo|printf|source|cd|set)\b"#, in: text) ? 2 : 0
        score += contains(#"(?m)^\s*(if|for|while|case)\b.+(then|do|in)\b"#, in: text) ? 3 : 0
        score += contains(#"\$\([^)]+\)|\$\{[^}]+\}"#, in: text) ? 3 : 0
        return score
    }

    private static func htmlScore(_ text: String) -> Int {
        var score = 0
        score += contains(#"(?i)<!doctype\s+html"#, in: text) ? 8 : 0
        score += min(matchCount(#"(?i)</?[a-z][a-z0-9:-]*(?:\s[^>]*)?>"#, in: text), 3) * 2
        score += contains(#"(?i)</[a-z][a-z0-9:-]*\s*>"#, in: text) ? 2 : 0
        return score
    }

    private static func cssScore(_ text: String) -> Int {
        var score = 0
        score += contains(#"(?m)^\s*([.#]?[A-Za-z][^{,\n]*)(,\s*[^{\n]+)*\s*\{"#, in: text) ? 3 : 0
        score += min(matchCount(#"(?m)^\s*[A-Za-z-]+\s*:\s*[^;\n]+;"#, in: text), 2) * 2
        score += contains(#"@(media|supports|keyframes|font-face)\b"#, in: text) ? 3 : 0
        return score
    }

    private static func sqlScore(_ text: String) -> Int {
        var score = 0
        score += contains(
            #"(?im)^\s*(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|WITH)\b"#,
            in: text
        ) ? 4 : 0
        score += contains(
            #"\b(FROM|INTO|TABLE|SET|VALUES|JOIN|WHERE|GROUP\s+BY|ORDER\s+BY)\b"#,
            in: text,
            options: [.caseInsensitive]
        ) ? 3 : 0
        score += text.contains(";") ? 1 : 0
        return score
    }

    private static func goScore(_ text: String) -> Int {
        var score = 0
        score += contains(#"(?m)^\s*package\s+\w+\s*$"#, in: text) ? 5 : 0
        score += contains(#"\bfunc\s+(?:\([^)]*\)\s*)?\w+\s*\("#, in: text) ? 3 : 0
        score += contains(#":=|(?m)^\s*import\s*\("#, in: text) ? 2 : 0
        return score
    }

    private static func rustScore(_ text: String) -> Int {
        var score = 0
        score += contains(#"\bfn\s+\w+\s*\("#, in: text) ? 4 : 0
        score += contains(#"\b(let\s+mut|impl|trait|enum)\b"#, in: text) ? 3 : 0
        score += contains(#"(?m)^\s*use\s+[\w:]+;"#, in: text) ? 3 : 0
        score += contains(#"\b(Result|Option)<"#, in: text) ? 2 : 0
        return score
    }

    private static func javaScore(_ text: String) -> Int {
        var score = 0
        score += contains(#"(?m)^\s*(package|import)\s+[\w.]+;"#, in: text) ? 3 : 0
        score += contains(#"\b(public|private|protected)\s+(class|interface|enum)\s+\w+"#, in: text) ? 4 : 0
        score += contains(#"\b(public|private|protected|static)\s+[\w<>\[\]]+\s+\w+\s*\("#, in: text) ? 3 : 0
        return score
    }

    private static func cFamilyScore(_ text: String) -> Int {
        var score = 0
        score += contains(#"(?m)^\s*#\s*(include|define|ifn?def)\b"#, in: text) ? 4 : 0
        score += contains(#"\b(int|void|char|float|double|bool)\s+\w+\s*\([^)]*\)\s*\{"#, in: text) ? 3 : 0
        score += contains(#"\b(std::|namespace|template\s*<)"#, in: text) ? 3 : 0
        return score
    }

    private static func yamlScore(_ text: String) -> Int {
        var score = 0
        score += min(matchCount(#"(?m)^\s*[A-Za-z_][\w.-]*\s*:\s*(?:[^{}\n].*)?$"#, in: text), 3) * 2
        score += contains(#"(?m)^\s*-\s+[\w\"']"#, in: text) ? 2 : 0
        return score
    }

    private static func genericScore(_ text: String) -> Int {
        var score = 0
        let lineCount = text.reduce(into: 1) { if $1 == "\n" { $0 += 1 } }
        score += lineCount >= 3 ? 1 : 0
        score += text.contains("{") && text.contains("}") ? 2 : 0
        score += matchCount(#";\s*(?:\n|$)"#, in: text) >= 2 ? 2 : 0
        score += matchCount(#"(?m)^(?: {2,}|\t)\S"#, in: text) >= 2 ? 2 : 0
        score += contains(#"(==|!=|=>|->|:=|\+=|-=)"#, in: text) ? 2 : 0
        return score
    }

    private static func contains(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> Bool {
        firstMatch(pattern, in: text, options: options) != nil
    }

    private static func matchCount(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> Int {
        guard let expression = PreviewRegexCache.expression(
            pattern: pattern,
            options: options
        ) else {
            return 0
        }
        return expression.numberOfMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
    }

    private static func firstMatch(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> NSTextCheckingResult? {
        guard let expression = PreviewRegexCache.expression(
            pattern: pattern,
            options: options
        ) else {
            return nil
        }
        return expression.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
    }
}
