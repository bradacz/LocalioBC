import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var viewModel: EditorViewModel
    var onOpenSettings: () -> Void = {}
    @Environment(AppPreferences.self) private var preferences

    @State private var isDropTargeted = false
    @State private var draggedClipID: UUID?

    var body: some View {
        let _ = preferences.language
        Group {
            if viewModel.clips.isEmpty {
                emptyDropZoneView
            } else {
                editorWorkspaceView
            }
        }
        .frame(minWidth: 1040, minHeight: 680)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            viewModel.handleDroppedProviders(providers)
        }
        .overlay {
            if isDropTargeted && !viewModel.clips.isEmpty {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        Label(tr("Pusťte videa pro přidání do fronty"), systemImage: "plus.circle.fill")
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(.ultraThickMaterial, in: Capsule())
                    }
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .alert(
            tr("Upozornění"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Empty Dropzone

    private var emptyDropZoneView: some View {
        VStack(spacing: 26) {
            HStack { Spacer(); settingsButton }
            Spacer()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(isDropTargeted ? 0.24 : 0.12))
                        .frame(width: 84, height: 84)

                    Image(systemName: "film.stack")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 6) {
                    Text("LocalioBC")
                        .font(.largeTitle.weight(.bold))
                    Text(tr("Přetáhněte sem jedno nebo více videí (.mp4, .mov, .m4v)"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.openFilePicker()
                } label: {
                    Label(tr("Vybrat videa z disku…"), systemImage: "folder.badge.plus")
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isLoadingClips)

                if viewModel.isLoadingClips {
                    ProgressView(tr("Načítám video…"))
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: 580)
            .padding(44)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor : Color.primary.opacity(0.16),
                        style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.5, dash: [10, 7])
                    )
            )

            HStack(spacing: 14) {
                featureBadge(icon: "scissors", title: tr("Časové zkrácení"), detail: tr("Rychlý střih začátku a konce"))
                featureBadge(icon: "aspectratio", title: tr("Ořez obrazu"), detail: tr("16:9, 9:16, 1:1, 4:5 i vlastní"))
                featureBadge(icon: "rectangle.stack.badge.plus", title: tr("Spojení & komprese"), detail: tr("Sloučení klipů a limit v MB"))
            }
            .frame(maxWidth: 680)

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureBadge(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Main Editor Layout

    private var editorWorkspaceView: some View {
        HSplitView {
            VStack(spacing: 8) {
                topBar
                clipStripView
                cropControls
                previewStage
                TimelineTrimView(
                    clip: viewModel.selectedClip,
                    allClips: viewModel.clips,
                    currentTime: viewModel.currentTime,
                    isPlaying: viewModel.isPlaying,
                    isPreviewingComposed: viewModel.isPreviewingComposedResult,
                    totalTrimmedDuration: viewModel.totalTrimmedDuration,
                    onTogglePlayPause: { viewModel.togglePlayPause() },
                    onSeek: { viewModel.seek(to: $0) },
                    onTrimChange: { start, end, seekTarget in
                        viewModel.updateTrim(start: start, end: end, seekTo: seekTarget)
                    }
                )
            }
            .padding(12)
            .frame(minWidth: 680, maxWidth: .infinity, maxHeight: .infinity)

            ExportSidebarView(viewModel: viewModel)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.openFilePicker()
            } label: {
                Label(tr("Přidat video"), systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoadingClips || viewModel.isExporting)

            if viewModel.isLoadingClips {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()

            Picker(
                tr("Režim náhledu"),
                selection: Binding(
                    get: { viewModel.isPreviewingComposedResult },
                    set: { viewModel.setComposedPreviewEnabled($0) }
                )
            ) {
                Text(tr("Klip")).tag(false)
                Text(tr("Výsledek")).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .help(tr("Klip: původní video pro střih. Výsledek: náhled všech úprav před exportem."))
            .disabled(viewModel.clips.isEmpty || viewModel.isBuildingPreview || viewModel.isEditingCrop)

            Spacer()

            Button(role: .destructive) {
                viewModel.clearAll()
            } label: {
                Label(tr("Vymazat vše"), systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isExporting)
            settingsButton
        }
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
        .controlSize(.small)
    }

    private var settingsButton: some View {
        Button(action: onOpenSettings) { Image(systemName: "gearshape") }
            .help(tr("Nastavení"))
            .accessibilityLabel(tr("Nastavení"))
            .buttonStyle(.bordered)
    }

    // MARK: - Clip Strip (Merge Queue)

    private var clipStripView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(viewModel.clips.enumerated()), id: \.element.id) { index, clip in
                    clipCard(clip: clip, index: index)
                }

                Button {
                    viewModel.openFilePicker()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                        Text(tr("Přidat"))
                            .font(.caption2)
                    }
                    .frame(width: 68, height: 58)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoadingClips || viewModel.isExporting)
            }
            .padding(.vertical, 2)
        }
        .frame(height: 64)
    }

    private func clipCard(clip: VideoClip, index: Int) -> some View {
        let isSelected = !viewModel.isPreviewingComposedResult && viewModel.selectedClipID == clip.id

        return HStack(spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                if let thumb = clip.thumbnails.first {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 58, height: 44)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: 58, height: 44)
                }

                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.75), in: Capsule())
                    .padding(3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.fileName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 115, alignment: .leading)

                HStack(spacing: 6) {
                    Text(EditorViewModel.formatTime(clip.trimmedDuration))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)

                    if clip.isCropped {
                        Image(systemName: "crop")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accentColor)
                    }
                    if clip.isTrimmed {
                        Image(systemName: "scissors")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            VStack(spacing: 2) {
                Button {
                    viewModel.removeClip(clip.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(tr("Odebrat klip"))

                if viewModel.clips.count > 1 {
                    HStack(spacing: 2) {
                        Button {
                            viewModel.moveClip(from: index, direction: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .disabled(index == 0)

                        Button {
                            viewModel.moveClip(from: index, direction: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .disabled(index >= viewModel.clips.count - 1)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor).opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectClip(clip.id)
        }
        .onDrag {
            draggedClipID = clip.id
            return NSItemProvider(object: clip.id.uuidString as NSString)
        }
        .onDrop(of: [.plainText], isTargeted: nil) { _ in
            guard let sourceID = draggedClipID else { return false }
            viewModel.moveClip(id: sourceID, before: clip.id)
            draggedClipID = nil
            return true
        }
    }

    // MARK: - Crop Controls

    private var cropControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Label(tr("Ořez"), systemImage: "crop")
                    .font(.caption.weight(.semibold))
                Text(viewModel.selectedClip?.fileName ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(tr("Upravit")) { viewModel.beginCropEditing() }
                    .disabled(viewModel.isEditingCrop)
                Button(tr("Zrušit")) { viewModel.cancelCropEditing() }
                    .disabled(!viewModel.isEditingCrop)
                Button(tr("Použít na klip")) { viewModel.applyCrop() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.isEditingCrop)
                Button(tr("Na všechny klipy")) { viewModel.applyCrop(toAllClips: true) }
                    .disabled(viewModel.clips.count < 2)
                    .help(tr("Použít ořez na všechny klipy. U předvoleb se zachová poměr stran, přiblížení a poloha; vlastní výřez se přenese relativně k rozměrům videa."))
            }
            .lineLimit(1)
            .frame(height: 24)
            HStack(spacing: 6) {
                Picker(tr("Poměr stran"), selection: Binding(
                    get: { viewModel.isEditingCrop ? viewModel.cropDraftAspectRatio : (viewModel.selectedClip?.cropAspectRatio ?? .original) },
                    set: { viewModel.setAspectRatio($0) }
                )) {
                    ForEach(AspectRatioPreset.allCases) { preset in
                        Text(tr(preset.rawValue)).tag(preset)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                Button { viewModel.resetSelectedCrop() } label: {
                    Image(systemName: "viewfinder")
                }
                .help(tr("Vycentrovat výřez"))
                Button(tr("Bez ořezu")) { viewModel.removeSelectedCrop() }
                    .disabled(!viewModel.isEditingCrop && viewModel.selectedClip?.isCropped != true)
            }
            .frame(height: 24)
            Text(viewModel.isEditingCrop
                 ? tr("Posuňte rámeček a použijte výřez na vybraný klip nebo na všechny klipy.")
                 : tr("Vyberte poměr stran nebo zvolte Upravit. Ořez můžete použít i na všechny klipy."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(height: 16)
        }
        .frame(height: 76, alignment: .top)
        .controlSize(.small)
        .padding(8)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        .disabled(viewModel.isExporting || viewModel.isBuildingPreview)
    }

    // MARK: - Video Preview Stage

    private var previewStage: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let activeContentSize: CGSize = {
                if viewModel.isPreviewingComposedResult {
                    return viewModel.outputResolution
                }
                return viewModel.selectedClip?.displaySize ?? CGSize(width: 1920, height: 1080)
            }()
            let videoRect = PlayerLayerView.aspectFitRect(for: activeContentSize, in: containerSize)

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black)

                PlayerLayerView(player: viewModel.player)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.togglePlayPause()
                    }

                if !viewModel.isPreviewingComposedResult,
                   let clip = viewModel.selectedClip,
                   let draft = viewModel.cropDraft,
                   viewModel.cropDraftAspectRatio.isInteractiveCrop {
                    CropOverlayView(
                        cropRect: draft,
                        displaySize: clip.displaySize,
                        lockedAspectRatio: viewModel.cropDraftAspectRatio.aspectRatio
                    ) { updatedRect in
                        viewModel.updateSelectedCropRect(updatedRect)
                    }
                    .frame(width: videoRect.width, height: videoRect.height)
                    .position(x: videoRect.midX, y: videoRect.midY)
                }

                if viewModel.isBuildingPreview {
                    ProgressView(tr("Připravuji výsledek…"))
                        .padding(14)
                        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
