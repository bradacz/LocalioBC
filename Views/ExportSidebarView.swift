import SwiftUI

struct ExportSidebarView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(AppPreferences.self) private var preferences

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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    formatSection
                    Divider()
                    compressionSection
                    Divider()
                    summarySection
                }
                .padding(12)
            }
            Divider()
            exportActionSection
                .padding(12)
                .background(.regularMaterial)
        }
        .frame(width: 310)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }

    // MARK: - Format & Resolution

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(tr("Výstup"), systemImage: "film.stack")
            Picker(tr("Režim exportu"), selection: $viewModel.exportMode) {
                ForEach(ExportMode.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .onChange(of: viewModel.exportMode) {
                viewModel.enforcePassthroughEligibility()
                viewModel.lastExportResult = nil
            }
            if viewModel.exportMode == .separate {
                Text(tr("Každý klip se uloží zvlášť do nové podsložky. Cílová velikost platí pro jeden klip."))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            LabeledContent(tr("Kontejner")) {
                Picker(tr("Kontejner"), selection: $viewModel.settings.container) {
                    ForEach(OutputContainer.allCases) { container in
                        Text(tr(container.rawValue)).tag(container)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
            }
            LabeledContent(tr("Kodek")) {
                Picker(tr("Kodek"), selection: $viewModel.settings.codec) {
                    ForEach(VideoCodecOption.allCases) { codec in
                        Text(codec == .h264 ? "H.264" : "HEVC").tag(codec)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
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
                .frame(width: 190)
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
            sectionTitle(tr("Komprese"), systemImage: "arrow.down.right.and.arrow.up.left")

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
            .frame(maxWidth: .infinity)
            Text(modeSubtitle(viewModel.settings.compressionMode))
                .font(.caption2)
                .foregroundStyle(.secondary)

            if viewModel.settings.compressionMode == .preset {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Úroveň kvality"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(QualityPreset.allCases) { preset in
                            let selected = viewModel.settings.qualityPreset == preset
                            Button {
                                viewModel.settings.qualityPreset = preset
                                viewModel.lastExportResult = nil
                            } label: {
                                Text(tr(preset.rawValue))
                                    .font(.caption.weight(selected ? .semibold : .regular))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                            .tint(selected ? .accentColor : .secondary)
                        }
                    }
                }
            } else if viewModel.settings.compressionMode == .targetSize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(tr("Cílová velikost"))
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
                            Button("\(Int(sizeMB)) MB") {
                                viewModel.settings.targetSizeMB = sizeMB
                                viewModel.lastExportResult = nil
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(selected ? .accentColor : .secondary)
                        }
                    }

                    if estimatedBitrateBps < 300_000 {
                        Label(tr("Nízký bitrate pro tuto délku — obraz může být výrazně komprimován."), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if let warning = targetSizeWarning {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
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
        let sourceBytes = viewModel.totalSourceSizeBytes
        let estimatedBytes = viewModel.estimatedOutputBytes

        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle(tr("Souhrn výsledku"), systemImage: "info.circle")

            VStack(spacing: 6) {
                summaryRow(tr("Výsledná délka"), EditorViewModel.formatTime(viewModel.totalTrimmedDuration))
                summaryRow(tr("Rozměry"), viewModel.exportMode == .separate ? tr("Podle klipu") : "\(Int(res.width)) × \(Int(res.height)) px")
                summaryRow(tr("Původní velikost"), EditorViewModel.formatBytes(sourceBytes))
                summaryRow(
                    tr("Odhad po exportu"),
                    estimatedSizeLabel(sourceBytes: sourceBytes, estimatedBytes: estimatedBytes),
                    highlight: true
                )
            }
            .padding(10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func summaryRow(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit().weight(highlight ? .semibold : .medium))
                .foregroundStyle(highlight ? Color.accentColor : Color.primary)
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
            totalDuration: viewModel.totalTrimmedDuration,
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
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Button {
                    viewModel.startExport()
                } label: {
                    Label(viewModel.exportMode == .merged ? tr("Exportovat video…") : tr("Exportovat klipy…"), systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
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
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Button(tr("Zobrazit ve Finderu")) {
                            viewModel.revealLastExportInFinder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(viewModel.lastExportDirectory == nil ? tr("Přehrát") : tr("Otevřít složku")) {
                            viewModel.openLastExport()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
    }
}
