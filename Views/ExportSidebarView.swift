import SwiftUI

struct ExportSidebarView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(AppPreferences.self) private var preferences
    @State private var showBunnyUpload = false
    @State private var openBunnySettingsAfterUpload = false

    private let quickTargetSizesMB: [Double] = [5, 10, 25, 50, 100]

    private var targetSizeFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 1
        formatter.maximum = 2000
        formatter.maximumFractionDigits = 1
        return formatter
    }

    var body: some View {
        let _ = preferences.language
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                formatSection
                compressionSection
                summarySection
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 22)
            exportActionSection
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 320)
        .frame(maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showBunnyUpload, onDismiss: {
            if openBunnySettingsAfterUpload {
                openBunnySettingsAfterUpload = false
                NotificationCenter.default.post(name: .showLocalioBunnyStorageSettings, object: nil)
            }
        }) {
            BunnyUploadSheet(sources: viewModel.lastExportUploadSources,
                preparationError: viewModel.lastExportUploadError,
                onOpenSettings: { openBunnySettingsAfterUpload = true })
        }
    }

    // MARK: - Format & Resolution

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(tr("Export"))
                    .font(.system(size: 15, weight: .semibold))
                Spacer(minLength: 8)
                Picker(tr("Režim exportu"), selection: $viewModel.exportMode) {
                    ForEach(ExportMode.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .help(viewModel.exportMode == .separate
                      ? tr("Každý klip se uloží zvlášť do nové podsložky. Cílová velikost platí pro jeden klip.")
                      : viewModel.exportMode.title)
                .onChange(of: viewModel.exportMode) {
                    viewModel.enforcePassthroughEligibility()
                    viewModel.lastExportResult = nil
                }
            }
            LabeledContent(tr("Kontejner")) {
                Picker(tr("Kontejner"), selection: $viewModel.settings.container) {
                    ForEach(OutputContainer.allCases) { container in
                        Text(tr(container.rawValue)).tag(container)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)
            }
            LabeledContent(tr("Kodek")) {
                Picker(tr("Kodek"), selection: $viewModel.settings.codec) {
                    ForEach(VideoCodecOption.allCases) { codec in
                        Text(codec == .h264 ? "H.264" : "HEVC").tag(codec)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)
                .disabled(viewModel.settings.compressionMode == .passthrough && viewModel.isPassthroughEligible)
                .help(viewModel.settings.codec.shortHint)
            }
            LabeledContent(tr("Rozlišení")) {
                Picker(tr("Maximální rozlišení"), selection: Binding(
                    get: { viewModel.settings.resolutionLimit },
                    set: { viewModel.setResolutionLimit($0) }
                )) {
                    ForEach(OutputResolutionLimit.allCases) { limit in
                        Text(tr(limit.rawValue)).tag(limit)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            Toggle(isOn: Binding(
                get: { viewModel.settings.removeAudio },
                set: { viewModel.setRemoveAudio($0) }
            )) {
                Label(tr("Odebrat zvuk"), systemImage: "speaker.slash")
            }
            .toggleStyle(.switch)
            .help(tr("Odstraní zvukové stopy ze všech klipů při exportu a ztlumí náhled."))
        }
        .font(.caption)
        .controlSize(.small)
        .disabled(viewModel.isExporting)
    }

    // MARK: - Compression & File Size

    private var compressionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle(tr("Komprese"))
                Spacer(minLength: 8)
                Picker(tr("Komprese"), selection: Binding(
                    get: { viewModel.settings.compressionMode },
                    set: {
                        viewModel.settings.compressionMode = $0
                        viewModel.enforcePassthroughEligibility()
                        viewModel.lastExportResult = nil
                    }
                )) {
                    ForEach(CompressionMode.allCases) { mode in
                        Text(tr(mode.rawValue)).tag(mode)
                            .disabled(mode == .passthrough && !viewModel.isPassthroughEligible)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 170)
                .help(modeSubtitle(viewModel.settings.compressionMode))
            }

            if viewModel.settings.compressionMode == .preset {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(QualityPreset.allCases) { preset in
                        let selected = viewModel.settings.qualityPreset == preset
                        Button {
                            viewModel.settings.qualityPreset = preset
                            viewModel.lastExportResult = nil
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected ? AppDesign.accent : Color.secondary)
                                Text(tr(preset.rawValue))
                                    .foregroundStyle(.primary)
                            }
                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            } else if viewModel.settings.compressionMode == .targetSize {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(tr(viewModel.exportMode == .separate ? "Cílová velikost / klip" : "Cílová velikost"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField(
                                "MB",
                                value: $viewModel.settings.targetSizeMB,
                                formatter: targetSizeFormatter
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 66)
                            .multilineTextAlignment(.trailing)
                            Text("MB")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Slider(value: $viewModel.settings.targetSizeMB, in: 1...300, step: 1)

                    HStack(spacing: 6) {
                        ForEach(quickTargetSizesMB, id: \.self) { sizeMB in
                            let selected = abs(viewModel.settings.targetSizeMB - sizeMB) < 0.5
                            Button {
                                viewModel.settings.targetSizeMB = sizeMB
                                viewModel.lastExportResult = nil
                            } label: {
                                Text("\(Int(sizeMB)) MB")
                                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? AppDesign.accent : Color.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }

                    if let warning = targetSizeWarning {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else if estimatedBitrateBps < 300_000 {
                        Label(tr("Nízký bitrate pro tuto délku — obraz může být výrazně komprimován."), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .disabled(viewModel.isExporting)
    }

    private func modeSubtitle(_ mode: CompressionMode) -> String {
        switch mode {
        case .passthrough:
            return tr("Okamžité zkrácení bez překódování")
        case .preset:
            return tr("Vyvážený poměr kvality a velikosti")
        case .targetSize:
            return tr("Dopočítá bitrate na zadaný limit v MB")
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        let res = viewModel.outputResolution
        return VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    estimateTitle
                    Spacer(minLength: 0)
                    estimateValue
                }
                VStack(alignment: .leading, spacing: 4) {
                    estimateTitle
                    estimateValue
                }
            }
            VStack(spacing: 6) {
                summaryRow(tr("Výsledná délka"), EditorViewModel.formatTime(viewModel.totalOutputDuration))
                summaryRow(tr("Rozměry"), viewModel.exportMode == .separate ? tr("Podle klipu") : "\(Int(res.width)) × \(Int(res.height)) px")
                summaryRow(tr("Původní velikost"), EditorViewModel.formatBytes(viewModel.totalSourceSizeBytes))
            }
        }
    }

    private var estimateTitle: some View {
        Text(tr("Odhad po exportu"))
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    private var estimateValue: some View {
        Text(estimatedSizeLabel(sourceBytes: viewModel.totalSourceSizeBytes, estimatedBytes: viewModel.estimatedOutputBytes))
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundStyle(AppDesign.accent)
            .fixedSize()
    }

    private func summaryRow(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit().weight(highlight ? .semibold : .medium))
                .foregroundStyle(highlight ? AppDesign.accent : Color.primary)
        }
    }

    private func estimatedSizeLabel(sourceBytes: Int64, estimatedBytes: Int64) -> String {
        let formatted = "~\(EditorViewModel.formatBytes(estimatedBytes))"
        guard sourceBytes > 0, estimatedBytes < sourceBytes else { return formatted }
        let savings = Int(((Double(sourceBytes - estimatedBytes) / Double(sourceBytes)) * 100.0).rounded())
        if savings >= 2 {
            return "\(formatted) (-\(savings) %)"
        }
        return formatted
    }

    private var estimatedBitrateBps: Int {
        let res = viewModel.outputResolution
        let fps = viewModel.clips.map(\.nominalFrameRate).max() ?? 30
        let hasAudio = viewModel.settings.includesAudio(for: viewModel.clips)
        return viewModel.settings.resolvedVideoBitrate(
            outputSize: res,
            fps: fps,
            totalDuration: viewModel.totalOutputDuration,
            hasAudio: hasAudio
        )
    }

    private var targetSizeWarning: String? {
        do {
            try viewModel.validateCurrentExportSettings()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Export Action

    private var exportActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isExporting {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(viewModel.exportStatus)
                            .font(.callout.weight(.medium))
                        Spacer()
                        Text("\(Int((viewModel.exportProgress * 100).rounded())) %")
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    ProgressView(value: viewModel.exportProgress, total: 1.0)
                    Button(tr("Zrušit export")) {
                        viewModel.cancelExport()
                    }
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity)
                }
            } else {
                Button {
                    viewModel.startExport()
                } label: {
                    Label(viewModel.exportMode == .merged ? tr("Exportovat video…") : tr("Exportovat klipy…"), systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(AppButtonStyle(primary: true))
                .id("\(preferences.language.rawValue)-\(viewModel.exportMode.rawValue)")
                .controlSize(.large)
                .disabled(viewModel.clips.isEmpty || viewModel.isLoadingClips || viewModel.isEditingCrop || targetSizeWarning != nil)
            }

            if viewModel.isEditingCrop {
                Text(tr("Nejprve potvrďte nebo zrušte rozpracovaný ořez."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let result = viewModel.lastExportResult {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(viewModel.lastExportDirectory == nil ? tr("Export dokončen") : tr("Exportováno klipů: %d", viewModel.lastExportResults.count))
                            .font(.callout.weight(.semibold))
                    }

                    Text("\(viewModel.lastExportDirectory?.lastPathComponent ?? result.outputURL.lastPathComponent) • \(EditorViewModel.formatBytes(viewModel.lastExportResults.reduce(0) { $0 + $1.fileSizeBytes }))\(result.usedPassthrough ? " (\(tr("Beze ztráty")))" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(viewModel.lastExportDirectory?.lastPathComponent ?? result.outputURL.lastPathComponent)

                    HStack(spacing: 8) {
                        Button(tr("Zobrazit ve Finderu")) {
                            viewModel.revealLastExportInFinder()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)

                        Button(viewModel.lastExportDirectory == nil ? tr("Přehrát") : tr("Otevřít složku")) {
                            viewModel.openLastExport()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                    Button { showBunnyUpload = true } label: {
                        Label(tr("Nahrát na Bunny.net…"), systemImage: "icloud.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(viewModel.isExporting)
                    .accessibilityIdentifier("bunnyUploadExport")
                }
                .padding(.top, 4)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.primary)
            .font(.system(size: 12, weight: .semibold))
    }
}
