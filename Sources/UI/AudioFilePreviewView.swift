import AVFoundation
import SwiftUI

struct AudioFilePreviewView: View {
    let url: URL

    @StateObject private var player = AudioPreviewPlayer()

    var body: some View {
        Group {
            switch player.phase {
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .accessibilityIdentifier("preview-audio-loading")

            case .ready(let metadata):
                audioCard(metadata: metadata)

            case .unavailable:
                PreviewUnavailableView(
                    symbol: "waveform.badge.exclamationmark",
                    title: "Preview unavailable",
                    message: "The audio file is missing or could not be played."
                )
                .accessibilityIdentifier("preview-audio-unavailable")
            }
        }
        .task(id: url) {
            await player.prepare(url: url)
        }
        .onDisappear {
            player.stop()
        }
    }

    private func audioCard(metadata: AudioPreviewMetadata) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .bold))

                VStack(alignment: .leading, spacing: 1) {
                    Text(metadata.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let artist = metadata.artist {
                        Text(artist)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color.secondary.opacity(0.78))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Text(metadata.formatLabel)
                    .font(.system(size: 10.5, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 12)
            .frame(height: metadata.artist == nil ? 34 : 42)

            Divider().overlay(Color.clipboardSeparator.opacity(0.72))

            VStack(spacing: 14) {
                AudioProgressTrack(
                    progress: progress,
                    onSeek: { player.seek(toFraction: $0) }
                )
                .frame(height: 28)

                HStack(spacing: 12) {
                    Button {
                        player.togglePlayback()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(Color.white)
                            .background(Color.accentColor.opacity(0.88), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(player.isPlaying ? "Pause audio" : "Play audio")
                    .accessibilityIdentifier("preview-audio-playback")

                    VStack(spacing: 5) {
                        HStack {
                            Text(Self.timeString(player.currentTime))
                                .monospacedDigit()

                            Spacer()

                            Text(Self.timeString(metadata.duration))
                                .monospacedDigit()
                        }

                        HStack {
                            Text(metadata.filename)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Text(Self.byteString(metadata.fileSize))
                        }
                        .foregroundStyle(Color.secondary.opacity(0.74))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
        .background(Color.primary.opacity(0.028))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.clipboardSeparator.opacity(0.80), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("preview-audio")
        .padding(12)
    }

    private var progress: Double {
        guard case .ready(let metadata) = player.phase,
              metadata.duration > 0
        else {
            return 0
        }
        return min(max(player.currentTime / metadata.duration, 0), 1)
    }

    private static func timeString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds.rounded(.down))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let remainingSeconds = totalSeconds % 60

        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
                hours,
                minutes,
                remainingSeconds
            )
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private static func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct AudioProgressTrack: View {
    let progress: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))
                    .frame(height: 4)

                Capsule()
                    .fill(Color.accentColor.opacity(0.72))
                    .frame(width: width * progress, height: 4)

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 9, height: 9)
                    .offset(x: max(0, min(width - 9, width * progress - 4.5)))
                    .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onSeek(min(max(value.location.x / width, 0), 1))
                    }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Audio position")
        .accessibilityValue("\(Int(progress * 100)) percent")
        .accessibilityIdentifier("preview-audio-progress")
    }
}

struct AudioPreviewMetadata: Equatable {
    let filename: String
    let title: String
    let artist: String?
    let formatLabel: String
    let duration: TimeInterval
    let fileSize: Int64
}

@MainActor
private final class AudioPreviewPlayer: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready(AudioPreviewMetadata)
        case unavailable
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var isPlaying = false

    private let avPlayer = AVPlayer()
    private var periodicTimeObserver: Any?
    private var completionObserver: NSObjectProtocol?
    private var representedURL: URL?
    private var loadGeneration = UUID()

    init() {
        periodicTimeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            let seconds = Self.safeSeconds(time)
            Task { @MainActor [weak self] in
                self?.currentTime = seconds
            }
        }
    }

    deinit {
        if let periodicTimeObserver {
            avPlayer.removeTimeObserver(periodicTimeObserver)
        }
        if let completionObserver {
            NotificationCenter.default.removeObserver(completionObserver)
        }
    }

    func prepare(url: URL) async {
        stop()
        avPlayer.replaceCurrentItem(with: nil)
        representedURL = url
        phase = .loading

        let generation = UUID()
        loadGeneration = generation

        guard let payload = await AudioPreviewLoader.load(url: url),
              !Task.isCancelled,
              generation == loadGeneration,
              representedURL == url
        else {
            if !Task.isCancelled, generation == loadGeneration {
                phase = .unavailable
            }
            return
        }

        let item = AVPlayerItem(asset: payload.asset)
        avPlayer.replaceCurrentItem(with: item)
        observeCompletion(of: item)
        currentTime = 0
        isPlaying = false
        phase = .ready(payload.metadata)
    }

    func togglePlayback() {
        guard case .ready(let metadata) = phase else { return }

        if isPlaying {
            avPlayer.pause()
            isPlaying = false
        } else {
            if metadata.duration > 0,
               currentTime >= metadata.duration - 0.05
            {
                seek(toFraction: 0)
            }
            avPlayer.play()
            isPlaying = true
        }
    }

    func seek(toFraction fraction: Double) {
        guard case .ready(let metadata) = phase, metadata.duration > 0 else {
            return
        }

        let seconds = min(max(fraction, 0), 1) * metadata.duration
        currentTime = seconds
        avPlayer.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    /// Pauses and rewinds so changing selection or closing the drawer cannot
    /// leave an invisible player running.
    func stop() {
        avPlayer.pause()
        avPlayer.seek(to: .zero)
        currentTime = 0
        isPlaying = false
    }

    private func observeCompletion(of item: AVPlayerItem) {
        if let completionObserver {
            NotificationCenter.default.removeObserver(completionObserver)
        }
        completionObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = false
                if case .ready(let metadata) = self.phase {
                    self.currentTime = metadata.duration
                }
            }
        }
    }

    nonisolated private static func safeSeconds(_ time: CMTime) -> TimeInterval {
        let seconds = time.seconds
        return seconds.isFinite && seconds >= 0 ? seconds : 0
    }
}

private struct AudioPreviewPayload: @unchecked Sendable {
    let asset: AVURLAsset
    let metadata: AudioPreviewMetadata
}

private enum AudioPreviewLoader {
    static func load(url: URL) async -> AudioPreviewPayload? {
        guard url.isFileURL else { return nil }

        do {
            let resourceValues = try url.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey]
            )
            guard resourceValues.isRegularFile == true else { return nil }

            let asset = AVURLAsset(url: url)
            let isPlayable = try await asset.load(.isPlayable)
            let duration = try await asset.load(.duration)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            guard isPlayable, !audioTracks.isEmpty else { return nil }

            let commonMetadata = (try? await asset.load(.commonMetadata)) ?? []
            let title = await metadataString(
                identifier: .commonIdentifierTitle,
                in: commonMetadata
            )
            let artist = await metadataString(
                identifier: .commonIdentifierArtist,
                in: commonMetadata
            )
            let filename = url.lastPathComponent

            return AudioPreviewPayload(
                asset: asset,
                metadata: AudioPreviewMetadata(
                    filename: filename,
                    title: title ?? url.deletingPathExtension().lastPathComponent,
                    artist: artist,
                    formatLabel: url.pathExtension.uppercased(),
                    duration: sanitizedDuration(duration),
                    fileSize: Int64(resourceValues.fileSize ?? 0)
                )
            )
        } catch {
            return nil
        }
    }

    private static func metadataString(
        identifier: AVMetadataIdentifier,
        in metadata: [AVMetadataItem]
    ) async -> String? {
        guard let item = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: identifier
        ).first else {
            return nil
        }

        guard let value = try? await item.load(.stringValue) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func sanitizedDuration(_ duration: CMTime) -> TimeInterval {
        let seconds = duration.seconds
        return seconds.isFinite && seconds >= 0 ? seconds : 0
    }
}
