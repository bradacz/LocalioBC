import SwiftUI

struct TimelineTrimView: View {
    @Environment(AppPreferences.self) private var preferences
    let clip: VideoClip?
    let allClips: [VideoClip]
    let currentTime: Double
    let isPlaying: Bool
    let isPreviewingComposed: Bool
    let totalTrimmedDuration: Double
    let onTogglePlayPause: () -> Void
    let onSeek: (Double) -> Void
    let onTrimChange: (Double, Double, Double?) -> Void

    @State private var dragStartInitialTrim: (start: Double, end: Double)?

    private let trackHeight: CGFloat = 54
    private let handleWidth: CGFloat = 13

    var body: some View {
        let _ = preferences.language
        VStack(spacing: 10) {
            controlsHeader
            if isPreviewingComposed {
                composedScrubBar
            } else if let clip {
                clipTrimBar(for: clip)
            }
        }
        .padding(14)
        .appPanel()
    }

    private var controlsHeader: some View {
        HStack(spacing: 12) {
            Button(action: onTogglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(AppButtonStyle(primary: true, compact: true))
            .help(isPlaying ? tr("Pozastavit") : tr("Přehrát"))

            if isPreviewingComposed {
                Text("\(EditorViewModel.formatTime(currentTime)) / \(EditorViewModel.formatTime(totalTrimmedDuration))")
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Text(tr("Náhled výsledku (%d klipů)", allClips.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let clip {
                Text("\(EditorViewModel.formatTime(currentTime)) / \(EditorViewModel.formatTime(clip.durationSeconds))")
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 12) {
                    timeTag(title: tr("Od"), value: EditorViewModel.formatTime(clip.trimStart))
                    timeTag(title: tr("Do"), value: EditorViewModel.formatTime(clip.trimEnd))
                    timeTag(title: tr("Výběr"), value: EditorViewModel.formatTime(clip.trimmedDuration), highlight: true)

                    if clip.isTrimmed {
                        Button(tr("Celý klip")) {
                            onTrimChange(0, clip.durationSeconds, 0)
                        }
                        .buttonStyle(AppButtonStyle(compact: true))
                        .controlSize(.small)
                    }
                }
            }
        }
        .lineLimit(1)
        .frame(height: 32)
    }

    private func timeTag(title: String, value: String, highlight: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(highlight ? AppDesign.accent : Color.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private func clipTrimBar(for clip: VideoClip) -> some View {
        GeometryReader { geometry in
            let totalWidth = max(40, geometry.size.width)
            let usableWidth = max(20, totalWidth - handleWidth * 2)
            let duration = clip.durationSeconds

            let startRatio = CGFloat(clip.trimStart / duration)
            let endRatio = CGFloat(clip.trimEnd / duration)

            let startX = handleWidth + startRatio * usableWidth
            let endX = handleWidth + endRatio * usableWidth
            let playheadRatio = CGFloat(max(0, min(1, currentTime / duration)))
            let playheadX = handleWidth + playheadRatio * usableWidth

            ZStack(alignment: .leading) {
                // Filmový pás miniatur
                filmstrip(thumbnails: clip.thumbnails)
                    .frame(width: usableWidth, height: trackHeight)
                    .offset(x: handleWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let rel = (value.location.x - handleWidth) / usableWidth
                                let clamped = max(0, min(1, rel))
                                onSeek(Double(clamped) * duration)
                            }
                    )

                // Ztmavená oříznutá část vlevo
                if startX > handleWidth {
                    Rectangle()
                        .fill(Color.black.opacity(0.62))
                        .frame(width: max(0, startX - handleWidth), height: trackHeight)
                        .offset(x: handleWidth)
                        .allowsHitTesting(false)
                }

                // Ztmavená oříznutá část vpravo
                if endX < handleWidth + usableWidth {
                    Rectangle()
                        .fill(Color.black.opacity(0.62))
                        .frame(width: max(0, handleWidth + usableWidth - endX), height: trackHeight)
                        .offset(x: endX)
                        .allowsHitTesting(false)
                }

                // Horní a dolní linka aktivního rozsahu
                VStack {
                    Rectangle().fill(AppDesign.accent).frame(height: 3)
                    Spacer()
                    Rectangle().fill(AppDesign.accent).frame(height: 3)
                }
                .frame(width: max(2, endX - startX), height: trackHeight)
                .offset(x: startX)
                .allowsHitTesting(false)

                // Přehrávací hlava (playhead)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: 2.5, height: trackHeight + 8)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .offset(x: playheadX - 1.25)
                    .allowsHitTesting(false)

                // Levý jezdec (trimStart)
                trimHandle(isLeft: true)
                    .frame(width: handleWidth, height: trackHeight)
                    .offset(x: startX - handleWidth)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if dragStartInitialTrim == nil {
                                    dragStartInitialTrim = (clip.trimStart, clip.trimEnd)
                                }
                                guard let initial = dragStartInitialTrim else { return }
                                let deltaSec = Double(value.translation.width / usableWidth) * duration
                                let minLen = min(0.2, duration)
                                let newStart = max(0, min(initial.end - minLen, initial.start + deltaSec))
                                onTrimChange(newStart, initial.end, newStart)
                            }
                            .onEnded { _ in
                                dragStartInitialTrim = nil
                            }
                    )

                // Pravý jezdec (trimEnd)
                trimHandle(isLeft: false)
                    .frame(width: handleWidth, height: trackHeight)
                    .offset(x: endX)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if dragStartInitialTrim == nil {
                                    dragStartInitialTrim = (clip.trimStart, clip.trimEnd)
                                }
                                guard let initial = dragStartInitialTrim else { return }
                                let deltaSec = Double(value.translation.width / usableWidth) * duration
                                let minLen = min(0.2, duration)
                                let newEnd = min(duration, max(initial.start + minLen, initial.end + deltaSec))
                                onTrimChange(initial.start, newEnd, newEnd)
                            }
                            .onEnded { _ in
                                dragStartInitialTrim = nil
                            }
                    )
            }
        }
        .frame(height: trackHeight)
    }

    private func trimHandle(isLeft: Bool) -> some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: isLeft ? 7 : 0,
                bottomLeadingRadius: isLeft ? 7 : 0,
                bottomTrailingRadius: isLeft ? 0 : 7,
                topTrailingRadius: isLeft ? 0 : 7
            )
            .fill(AppDesign.accent)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.92))
                .frame(width: 2.5, height: 22)
        }
        .contentShape(Rectangle())
    }

    private func filmstrip(thumbnails: [NSImage]) -> some View {
        GeometryReader { geo in
            if thumbnails.isEmpty {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
            } else {
                HStack(spacing: 0) {
                    let tileWidth = geo.size.width / CGFloat(thumbnails.count)
                    ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, image in
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: tileWidth, height: geo.size.height)
                            .clipped()
                    }
                }
            }
        }
    }

    private var composedScrubBar: some View {
        GeometryReader { geometry in
            let width = max(40, geometry.size.width)
            let total = max(0.1, totalTrimmedDuration)
            let ratio = CGFloat(max(0, min(1, currentTime / total)))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.28))

                // Jednotlivé úseky klipů ve spojeném videu
                HStack(spacing: 2) {
                    ForEach(allClips) { item in
                        let proportion = CGFloat(item.trimmedDuration / total)
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppDesign.accent.opacity(0.24))
                            Text(item.fileName)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(.horizontal, 6)
                                .foregroundStyle(.primary.opacity(0.85))
                        }
                        .frame(width: max(8, width * proportion - 2))
                    }
                }
                .padding(.vertical, 4)

                // Playhead
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: 3, height: 42)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .offset(x: max(0, min(width - 3, ratio * width - 1.5)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clamped = max(0, min(1, value.location.x / width))
                        onSeek(Double(clamped) * total)
                    }
            )
        }
        .frame(height: trackHeight)
    }
}
