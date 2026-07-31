import Foundation
import LocalMCPContracts
import LocalMCPProducer

/// The stable kind vocabulary exposed on the wire, decoupled from the UI's
/// TypeFilter raw values ("All Types", …).
enum ClipboardMCPKindFilter: String, Codable, CaseIterable, Sendable {
    case text
    case image
    case file
    case link

    var typeFilter: TypeFilter {
        switch self {
        case .text: .text
        case .image: .images
        case .file: .files
        case .link: .links
        }
    }
}

enum ClipboardMCPLimits {
    static let defaultLimit = 25
    static let maximumLimit = 100
    static let maximumQueryLength = 512     // unicode scalars
    static let maximumIDLength = 128        // contentHash is 64 hex characters
    static let maximumTitleLength = 200     // UTF-8 bytes
    static let maximumPreviewLength = 300   // UTF-8 bytes
    // Well under the transport's 1 MiB response cap.
    static let maximumFullTextBytes = 262_144
}

private func clipboardMCPISO8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

/// Truncates on character boundaries so the result never exceeds the byte cap.
private func clipboardMCPTruncate(_ text: String, maxUTF8Bytes: Int) -> (text: String, truncated: Bool) {
    guard text.utf8.count > maxUTF8Bytes else { return (text, false) }
    var end = text.startIndex
    var bytes = 0
    while end < text.endIndex {
        let next = text.index(after: end)
        bytes += text[end..<next].utf8.count
        if bytes > maxUTF8Bytes { break }
        end = next
    }
    return (String(text[..<end]), true)
}

/// Metadata-only wire summary of one history item. Full content is
/// deliberately reachable only through clipboard.get.
struct ClipboardMCPItemSummary: Codable, Equatable, Sendable {
    var id: String
    var kind: String
    var subtype: String?
    var title: String
    var preview: String?
    var sourceAppName: String?
    var sourceAppBundleID: String?
    var firstCopiedAt: String
    var lastCopiedAt: String
    var timesCopied: Int
    var byteSize: Int
    var pixelWidth: Int?
    var pixelHeight: Int?
    var fileCount: Int?

    @MainActor
    init(item: ClipboardItem) {
        id = item.contentHash
        kind = item.itemKind.rawValue
        subtype = item.subtype?.rawValue
        title = clipboardMCPTruncate(
            item.displayTitle,
            maxUTF8Bytes: ClipboardMCPLimits.maximumTitleLength
        ).text
        if item.itemKind == .text, let text = item.textContent {
            preview = clipboardMCPTruncate(
                text,
                maxUTF8Bytes: ClipboardMCPLimits.maximumPreviewLength
            ).text
        }
        sourceAppName = item.sourceAppName
        sourceAppBundleID = item.sourceAppBundleID
        firstCopiedAt = clipboardMCPISO8601(item.firstCopiedAt)
        lastCopiedAt = clipboardMCPISO8601(item.lastCopiedAt)
        timesCopied = item.timesCopied
        byteSize = item.byteSize
        pixelWidth = item.pixelWidth
        pixelHeight = item.pixelHeight
        if item.itemKind == .file { fileCount = item.fileURLPaths.count }
    }
}

struct ClipboardMCPSearchInput: Codable, Equatable, Sendable {
    var query: String
    var kind: ClipboardMCPKindFilter?
    var limit: Int?

    init(query: String, kind: ClipboardMCPKindFilter? = nil, limit: Int? = nil) {
        self.query = query
        self.kind = kind
        self.limit = limit
    }
}

struct ClipboardMCPSearchOutput: Codable, Equatable, Sendable {
    var items: [ClipboardMCPItemSummary]
}

struct ClipboardMCPGetInput: Codable, Equatable, Sendable {
    var id: String
}

/// Full content of one history item: summary fields plus the payload.
struct ClipboardMCPItemContent: Codable, Equatable, Sendable {
    var id: String
    var kind: String
    var subtype: String?
    var title: String
    var sourceAppName: String?
    var sourceAppBundleID: String?
    var firstCopiedAt: String
    var lastCopiedAt: String
    var timesCopied: Int
    var byteSize: Int
    var pixelWidth: Int?
    var pixelHeight: Int?
    var text: String?
    var textTruncated: Bool?
    var imageFileURI: String?
    var filePaths: [String]?

    @MainActor
    init(item: ClipboardItem, imageStore: ImageStore) {
        let summary = ClipboardMCPItemSummary(item: item)
        id = summary.id
        kind = summary.kind
        subtype = summary.subtype
        title = summary.title
        sourceAppName = summary.sourceAppName
        sourceAppBundleID = summary.sourceAppBundleID
        firstCopiedAt = summary.firstCopiedAt
        lastCopiedAt = summary.lastCopiedAt
        timesCopied = summary.timesCopied
        byteSize = summary.byteSize
        pixelWidth = summary.pixelWidth
        pixelHeight = summary.pixelHeight
        switch item.itemKind {
        case .text:
            if let fullText = item.textContent {
                let (capped, truncated) = clipboardMCPTruncate(
                    fullText,
                    maxUTF8Bytes: ClipboardMCPLimits.maximumFullTextBytes
                )
                text = capped
                if truncated { textTruncated = true }
            }
        case .image:
            if let filename = item.imagePath {
                imageFileURI = imageStore.url(forFilename: filename)
                    .standardizedFileURL.absoluteString
            }
        case .file:
            filePaths = item.fileURLPaths
        }
    }
}

struct ClipboardMCPCopyInput: Codable, Equatable, Sendable {
    var id: String
}

struct ClipboardMCPCopyReceipt: Codable, Equatable, Sendable {
    var copied: Bool
    var id: String
    var title: String
}

/// Sendable boundary between the producer actor and the MainActor-bound
/// HistoryStore. All ClipboardItem access — including DTO construction —
/// stays on the MainActor; only Sendable DTOs cross.
protocol ClipboardHistoryProviding: Sendable {
    func search(query: String, kind: ClipboardMCPKindFilter?, limit: Int) async -> [ClipboardMCPItemSummary]
    func item(id: String) async -> ClipboardMCPItemContent?
    func copyItem(id: String) async -> ClipboardMCPCopyReceipt?
}

struct HistoryStoreMCPBridge: ClipboardHistoryProviding {
    let store: HistoryStore

    @MainActor
    func search(query: String, kind: ClipboardMCPKindFilter?, limit: Int) async -> [ClipboardMCPItemSummary] {
        store.search(query: query, filter: kind?.typeFilter ?? .all, limit: limit)
            .map(ClipboardMCPItemSummary.init(item:))
    }

    @MainActor
    func item(id: String) async -> ClipboardMCPItemContent? {
        guard let item = store.item(withContentHash: id) else { return nil }
        return ClipboardMCPItemContent(item: item, imageStore: store.imageStore)
    }

    @MainActor
    func copyItem(id: String) async -> ClipboardMCPCopyReceipt? {
        guard let item = store.item(withContentHash: id) else { return nil }
        let title = clipboardMCPTruncate(
            item.displayTitle,
            maxUTF8Bytes: ClipboardMCPLimits.maximumTitleLength
        ).text
        let copied = store.copyToPasteboard(item)
        return ClipboardMCPCopyReceipt(copied: copied, id: id, title: title)
    }
}

private let clipboardMCPUnknownIDMessage =
    "No clipboard item has this id. Ids come from clipboard.search results and can expire when history is pruned or cleared."

private func clipboardMCPValidateID(_ id: String) throws {
    guard !id.isEmpty, id.unicodeScalars.count <= ClipboardMCPLimits.maximumIDLength else {
        throw LocalMCPError.invalidCommandInput
    }
}

struct ClipboardSearchCommandHandler: Sendable {
    let history: any ClipboardHistoryProviding

    func call(
        input: ClipboardMCPSearchInput,
        context: CommandContext
    ) async throws -> CommandResult {
        try context.checkCancellation()
        guard input.query.unicodeScalars.count <= ClipboardMCPLimits.maximumQueryLength else {
            throw LocalMCPError.invalidCommandInput
        }
        let limit = input.limit ?? ClipboardMCPLimits.defaultLimit
        guard (1...ClipboardMCPLimits.maximumLimit).contains(limit) else {
            throw LocalMCPError.invalidCommandInput
        }
        // The panel UI trims the query the same way before matching.
        let query = input.query.trimmingCharacters(in: .whitespaces)
        let items = await history.search(query: query, kind: input.kind, limit: limit)
        try context.checkCancellation()
        let output = ClipboardMCPSearchOutput(items: items)
        let noun = output.items.count == 1 ? "item" : "items"
        return try CommandResult.structured(
            output,
            text: "Found \(output.items.count) clipboard history \(noun)."
        )
    }

    static let definition = CommandDefinition(
        name: "clipboard.search",
        title: "Search clipboard history",
        description: "Search the user's clipboard history, newest first. This is personal data and may contain sensitive text. The query matches item text, copied file names, and the source app name; an empty query returns the most recent items. Results are summaries — pass a result's id to clipboard.get for full content.",
        inputSchema: .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array([.string("query")]),
            "properties": .object([
                "query": .object([
                    "type": .string("string"),
                    "maxLength": .integer(Int64(ClipboardMCPLimits.maximumQueryLength)),
                    "description": .string("Text to match. Pass an empty string to return the most recent items."),
                ]),
                "kind": .object([
                    "type": .string("string"),
                    "enum": .array(ClipboardMCPKindFilter.allCases.map { .string($0.rawValue) }),
                    "description": .string("Optional filter: text, image, file, or link (a text item that is a URL)."),
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "minimum": .integer(1),
                    "maximum": .integer(Int64(ClipboardMCPLimits.maximumLimit)),
                    "description": .string("Maximum results. Defaults to 25."),
                ]),
            ]),
        ]),
        outputSchema: .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array([.string("items")]),
            "properties": .object([
                "items": .object([
                    "type": .string("array"),
                    "maxItems": .integer(Int64(ClipboardMCPLimits.maximumLimit)),
                    "items": .object([
                        "type": .string("object"),
                        "additionalProperties": .bool(false),
                        "required": .array([
                            .string("id"),
                            .string("kind"),
                            .string("title"),
                            .string("firstCopiedAt"),
                            .string("lastCopiedAt"),
                            .string("timesCopied"),
                            .string("byteSize"),
                        ]),
                        "properties": .object([
                            "id": .object(["type": .string("string")]),
                            "kind": .object([
                                "type": .string("string"),
                                "enum": .array([.string("text"), .string("image"), .string("file")]),
                            ]),
                            "subtype": .object([
                                "type": .string("string"),
                                "enum": .array([.string("link"), .string("color")]),
                            ]),
                            "title": .object(["type": .string("string")]),
                            "preview": .object(["type": .string("string")]),
                            "sourceAppName": .object(["type": .string("string")]),
                            "sourceAppBundleID": .object(["type": .string("string")]),
                            "firstCopiedAt": .object(["type": .string("string")]),
                            "lastCopiedAt": .object(["type": .string("string")]),
                            "timesCopied": .object(["type": .string("integer"), "minimum": .integer(1)]),
                            "byteSize": .object(["type": .string("integer"), "minimum": .integer(0)]),
                            "pixelWidth": .object(["type": .string("integer")]),
                            "pixelHeight": .object(["type": .string("integer")]),
                            "fileCount": .object(["type": .string("integer")]),
                        ]),
                    ]),
                ]),
            ]),
        ]),
        annotations: CommandAnnotations(
            readOnly: true,
            idempotent: true,
            destructive: false,
            openWorld: false
        )
    )
}

struct ClipboardGetCommandHandler: Sendable {
    let history: any ClipboardHistoryProviding

    func call(
        input: ClipboardMCPGetInput,
        context: CommandContext
    ) async throws -> CommandResult {
        try context.checkCancellation()
        try clipboardMCPValidateID(input.id)
        guard let content = await history.item(id: input.id) else {
            return CommandResult.failure(text: clipboardMCPUnknownIDMessage)
        }
        try context.checkCancellation()
        return try CommandResult.structured(
            content,
            text: "Retrieved one \(content.kind) item from clipboard history."
        )
    }

    static let definition = CommandDefinition(
        name: "clipboard.get",
        title: "Get a clipboard history item",
        description: "Return the full content of one clipboard history item by id (from clipboard.search). This is personal data and may contain sensitive text. Text items include the full text (capped at 256 KiB); image items include a local file URI to the stored PNG; file items include the copied file paths.",
        inputSchema: .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array([.string("id")]),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "minLength": .integer(1),
                    "maxLength": .integer(Int64(ClipboardMCPLimits.maximumIDLength)),
                    "description": .string("Item id taken verbatim from a clipboard.search result."),
                ]),
            ]),
        ]),
        outputSchema: .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array([
                .string("id"),
                .string("kind"),
                .string("title"),
                .string("firstCopiedAt"),
                .string("lastCopiedAt"),
                .string("timesCopied"),
                .string("byteSize"),
            ]),
            "properties": .object([
                "id": .object(["type": .string("string")]),
                "kind": .object([
                    "type": .string("string"),
                    "enum": .array([.string("text"), .string("image"), .string("file")]),
                ]),
                "subtype": .object([
                    "type": .string("string"),
                    "enum": .array([.string("link"), .string("color")]),
                ]),
                "title": .object(["type": .string("string")]),
                "sourceAppName": .object(["type": .string("string")]),
                "sourceAppBundleID": .object(["type": .string("string")]),
                "firstCopiedAt": .object(["type": .string("string")]),
                "lastCopiedAt": .object(["type": .string("string")]),
                "timesCopied": .object(["type": .string("integer"), "minimum": .integer(1)]),
                "byteSize": .object(["type": .string("integer"), "minimum": .integer(0)]),
                "pixelWidth": .object(["type": .string("integer")]),
                "pixelHeight": .object(["type": .string("integer")]),
                "text": .object(["type": .string("string")]),
                "textTruncated": .object(["type": .string("boolean")]),
                "imageFileURI": .object(["type": .string("string")]),
                "filePaths": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                ]),
            ]),
        ]),
        annotations: CommandAnnotations(
            readOnly: true,
            idempotent: true,
            destructive: false,
            openWorld: false
        )
    )
}

struct ClipboardCopyCommandHandler: Sendable {
    let history: any ClipboardHistoryProviding

    func call(
        input: ClipboardMCPCopyInput,
        context: CommandContext
    ) async throws -> CommandResult {
        try context.checkCancellation()
        try clipboardMCPValidateID(input.id)
        guard let receipt = await history.copyItem(id: input.id) else {
            return CommandResult.failure(text: clipboardMCPUnknownIDMessage)
        }
        guard receipt.copied else {
            return CommandResult.failure(
                text: "The clipboard item could not be copied because its stored content is unavailable."
            )
        }
        try context.checkCancellation()
        return try CommandResult.structured(
            receipt,
            text: "Copied the item to the system clipboard, replacing its previous contents."
        )
    }

    static let definition = CommandDefinition(
        name: "clipboard.copy",
        title: "Copy a history item to the clipboard",
        description: "Put one clipboard history item (by id, from clipboard.search) back onto the system clipboard so the user can paste it. This REPLACES whatever is currently on the user's clipboard, so only call it when the user asked for it.",
        inputSchema: .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array([.string("id")]),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "minLength": .integer(1),
                    "maxLength": .integer(Int64(ClipboardMCPLimits.maximumIDLength)),
                    "description": .string("Item id taken verbatim from a clipboard.search result."),
                ]),
            ]),
        ]),
        outputSchema: .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array([.string("copied"), .string("id"), .string("title")]),
            "properties": .object([
                "copied": .object(["type": .string("boolean")]),
                "id": .object(["type": .string("string")]),
                "title": .object(["type": .string("string")]),
            ]),
        ]),
        annotations: CommandAnnotations(
            readOnly: false,
            idempotent: false,
            destructive: true,
            openWorld: false
        )
    )
}

extension LocalMCPProducer {
    func registerClipboardCommands(history: any ClipboardHistoryProviding) async throws {
        let search = ClipboardSearchCommandHandler(history: history)
        try await register(ClipboardSearchCommandHandler.definition) {
            (input: ClipboardMCPSearchInput, context: CommandContext) in
            try await search.call(input: input, context: context)
        }
        let get = ClipboardGetCommandHandler(history: history)
        try await register(ClipboardGetCommandHandler.definition) {
            (input: ClipboardMCPGetInput, context: CommandContext) in
            try await get.call(input: input, context: context)
        }
        let copy = ClipboardCopyCommandHandler(history: history)
        try await register(ClipboardCopyCommandHandler.definition) {
            (input: ClipboardMCPCopyInput, context: CommandContext) in
            try await copy.call(input: input, context: context)
        }
    }
}
