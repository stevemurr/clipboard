import AppKit
import Foundation
import SwiftUI

struct RichLinkPreviewView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 15) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.19),
                                        Color.accentColor.opacity(0.07),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Image(systemName: "globe")
                            .font(.system(size: 25, weight: .medium))
                            .foregroundStyle(Color.accentColor.opacity(0.82))
                    }
                    .frame(width: 70, height: 70)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(hostLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(2)
                            .accessibilityIdentifier("preview-rich-link-title")

                        Text(displayURL)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.secondary.opacity(0.78))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)

                Divider().opacity(0.55)

                Link(destination: url) {
                    HStack(spacing: 6) {
                        Text("Open in browser")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                }
                .buttonStyle(.plain)
            }
            .background(Color.primary.opacity(0.028))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.clipboardSeparator.opacity(0.72), lineWidth: 0.75)
            }
            .padding(16)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("preview-rich-link")
    }

    private var hostLabel: String {
        Self.displayHost(for: url)
    }

    private var displayURL: String {
        url.absoluteString.removingPercentEncoding ?? url.absoluteString
    }

    private static func displayHost(for url: URL) -> String {
        let host = url.host(percentEncoded: false) ?? "Web link"
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

struct YouTubePreviewView: View {
    let link: YouTubeLink

    @State private var phase: MetadataPhase<YouTubePreviewPayload> = .loading

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Link(destination: link.originalURL) {
                    ZStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.96),
                                        Color.black.opacity(0.80),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        if let image {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fill)
                                .transition(.opacity)
                        } else {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.32))
                        }

                        Circle()
                            .fill(Color.black.opacity(0.68))
                            .frame(width: 54, height: 54)
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .offset(x: 2)
                            }
                            .shadow(color: .black.opacity(0.28), radius: 9, y: 3)

                        if case .loading = phase {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .padding(12)
                                .accessibilityIdentifier("preview-youtube-loading")
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open YouTube video")
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    Text(payload?.title ?? "YouTube video")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)
                        .accessibilityIdentifier("preview-youtube-title")

                    HStack {
                        Text(payload?.authorName ?? "youtube.com")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)

                        Spacer()

                        Link(destination: link.originalURL) {
                            HStack(spacing: 5) {
                                Text("Open")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(Color.primary.opacity(0.028))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.clipboardSeparator.opacity(0.72), lineWidth: 0.75)
            }
            .padding(14)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("preview-youtube")
        .task(id: link) {
            phase = .loading
            if let payload = await WebPreviewMetadataStore.shared.youtube(for: link) {
                guard !Task.isCancelled else { return }
                phase = .loaded(payload)
            } else {
                guard !Task.isCancelled else { return }
                phase = .unavailable
            }
        }
    }

    private var payload: YouTubePreviewPayload? {
        guard case .loaded(let payload) = phase else { return nil }
        return payload
    }

    private var image: NSImage? {
        payload?.thumbnailData.flatMap(NSImage.init(data:))
    }
}

private enum MetadataPhase<Payload> {
    case loading
    case loaded(Payload)
    case unavailable
}

private struct YouTubePreviewPayload: Sendable {
    let title: String
    let authorName: String?
    let thumbnailData: Data?
}

private actor WebPreviewMetadataStore {
    static let shared = WebPreviewMetadataStore()

    private struct Entry<Value> {
        let value: Value
        let expiresAt: Date
    }

    private var youtubeVideos: [String: Entry<YouTubePreviewPayload>] = [:]
    private var failedRequests: [String: Date] = [:]

    private let successLifetime: TimeInterval = 12 * 60 * 60
    private let failureLifetime: TimeInterval = 5 * 60
    private let maximumYouTubeEntries = 16
    private let maximumFailureEntries = 64

    func youtube(for link: YouTubeLink) async -> YouTubePreviewPayload? {
        pruneExpiredEntries()
        let key = "youtube:\(link.videoID)"
        if let cached = youtubeVideos[key], cached.expiresAt > .now {
            return cached.value
        }
        guard !recentlyFailed(key) else { return nil }

        do {
            let payload = try await YouTubeMetadataLoader.load(link: link)
            try Task.checkCancellation()
            youtubeVideos[key] = Entry(
                value: payload,
                expiresAt: .now.addingTimeInterval(successLifetime)
            )
            trimCaches()
            failedRequests.removeValue(forKey: key)
            return payload
        } catch {
            guard !Task.isCancelled else { return nil }
            failedRequests[key] = .now
            trimCaches()
            return nil
        }
    }

    private func recentlyFailed(_ key: String) -> Bool {
        guard let failureDate = failedRequests[key] else { return false }
        if Date.now.timeIntervalSince(failureDate) < failureLifetime {
            return true
        }
        failedRequests.removeValue(forKey: key)
        return false
    }

    private func pruneExpiredEntries() {
        let now = Date.now
        youtubeVideos = youtubeVideos.filter { $0.value.expiresAt > now }
        failedRequests = failedRequests.filter {
            now.timeIntervalSince($0.value) < failureLifetime
        }
    }

    private func trimCaches() {
        while youtubeVideos.count > maximumYouTubeEntries,
              let oldestKey = youtubeVideos.min(by: {
                  $0.value.expiresAt < $1.value.expiresAt
              })?.key
        {
            youtubeVideos.removeValue(forKey: oldestKey)
        }
        while failedRequests.count > maximumFailureEntries,
              let oldestKey = failedRequests.min(by: { $0.value < $1.value })?.key
        {
            failedRequests.removeValue(forKey: oldestKey)
        }
    }
}

private enum YouTubeMetadataLoader {
    private struct Response: Decodable {
        let title: String
        let authorName: String?
        let thumbnailURL: URL?

        enum CodingKeys: String, CodingKey {
            case title
            case authorName = "author_name"
            case thumbnailURL = "thumbnail_url"
        }
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 8
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpCookieAcceptPolicy = .never
        return URLSession(configuration: configuration)
    }()

    static func load(link: YouTubeLink) async throws -> YouTubePreviewPayload {
        guard let endpoint = endpoint(for: link) else {
            throw PreviewMetadataError.invalidEndpoint
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 6
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, maximumBytes: 128_000)
        let metadata = try JSONDecoder().decode(Response.self, from: data)

        let thumbnailData: Data?
        if let thumbnailURL = metadata.thumbnailURL,
           allowsYouTubeThumbnail(thumbnailURL)
        {
            thumbnailData = try? await loadThumbnail(from: thumbnailURL)
        } else {
            thumbnailData = nil
        }

        try Task.checkCancellation()
        return YouTubePreviewPayload(
            title: String(
                metadata.title
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .prefix(240)
            ),
            authorName: metadata.authorName.map {
                String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
            },
            thumbnailData: thumbnailData
        )
    }

    private static func endpoint(for link: YouTubeLink) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube.com"
        components.path = "/oembed"
        components.queryItems = [
            URLQueryItem(name: "url", value: link.canonicalURL.absoluteString),
            URLQueryItem(name: "format", value: "json"),
        ]
        return components.url
    }

    private static func loadThumbnail(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, maximumBytes: 4_000_000)
        guard let mimeType = response.mimeType,
              mimeType.lowercased().hasPrefix("image/")
        else {
            throw PreviewMetadataError.unexpectedContent
        }
        return data
    }

    private static func validate(
        response: URLResponse,
        data: Data,
        maximumBytes: Int
    ) throws {
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              data.count <= maximumBytes
        else {
            throw PreviewMetadataError.badResponse
        }
    }

    private static func allowsYouTubeThumbnail(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased()
        else {
            return false
        }
        return host == "i.ytimg.com"
            || host == "img.youtube.com"
            || host.hasSuffix(".ytimg.com")
    }
}

private enum PreviewMetadataError: Error {
    case invalidEndpoint
    case badResponse
    case unexpectedContent
}
