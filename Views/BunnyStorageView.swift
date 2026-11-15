import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Optional storage connection. The editor and its local exports do not depend on it.
struct BunnyStorageView: View {
    @Environment(BunnyUploadCoordinator.self) private var uploads
    @Environment(AppPreferences.self) private var preferences
    var showsQueue = true

    @State private var profileID = UUID()
    @State private var zoneName = ""
    @State private var region: BunnyStorageRegion = .frankfurt
    @State private var remoteFolder = ""
    @State private var cdnURL = ""
    @State private var password = ""
    @State private var feedback: String?
    @State private var feedbackIsError = false
    @State private var confirmDisconnect = false

    var body: some View {
        let _ = preferences.language
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Bunny Storage").font(.system(size: 26, weight: .bold))
                Text(tr("Hotové video nahrajete na vlastní úložiště až po potvrzení. Úpravy a export zůstávají lokální."))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            connectionForm
            affiliateInformation
            if showsQueue, !uploads.jobs.isEmpty {
                BunnyUploadQueueView()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: loadProfile)
        .onDisappear { password = "" }
        .confirmationDialog(tr("Odpojit Bunny Storage?"), isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button(tr("Odpojit úložiště"), role: .destructive, action: disconnect)
            Button(tr("Zrušit"), role: .cancel) {}
        } message: {
            Text(tr("Uložené připojení a heslo budou odebrány. Soubory na Bunny.net se nesmažou."))
        }
    }

    private var connectionForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Připojení úložiště")).font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: 12) {
                field(tr("Název Storage Zone")) {
                    TextField(tr("moje-storage-zona"), text: $zoneName)
                        .accessibilityIdentifier("bunnyZoneName")
                }
                field(tr("Primární oblast")) {
                    Picker(tr("Primární oblast"), selection: $region) {
                        ForEach(BunnyStorageRegion.allCases) { item in
                            Text(tr(item.title)).tag(item)
                        }
                    }
                    .labelsHidden()
                    .accessibilityIdentifier("bunnyPrimaryRegion")
                }
                field(tr("Složka v úložišti")) {
                    TextField(tr("Volitelné, například videos"), text: $remoteFolder)
                        .accessibilityIdentifier("bunnyRemoteFolder")
                }
                field(tr("Veřejná CDN adresa")) {
                    TextField(tr("https://vase-zona.b-cdn.net"), text: $cdnURL)
                        .accessibilityIdentifier("bunnyCDNURL")
                }
                Text(tr("Použijte HTTPS adresu připojené Pull Zone nebo vlastní CDN domény. Úložiště musí být propojené s touto CDN adresou."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                field(tr("Heslo Storage Zone")) {
                    SecureField(canKeepSavedPassword ? tr("Prázdné ponechá uložené heslo") : tr("Heslo pro zápis do úložiště"), text: $password)
                        .textContentType(.password)
                        .privacySensitive()
                        .accessibilityIdentifier("bunnyStoragePassword")
                }
                Text(tr("Použijte heslo Storage Zone pro zápis, nikoli globální API klíč účtu. Heslo se ukládá pouze do Klíčenky macOS a nezobrazuje se zpětně."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .textFieldStyle(.roundedBorder)
            .disabled(uploads.isUploading)

            HStack(spacing: 14) {
                Button(tr("Uložit připojení"), action: saveProfile)
                    .disabled(uploads.isUploading || zoneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cdnURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("bunnySaveConnection")
                if uploads.profile != nil {
                    Button(tr("Odpojit úložiště")) { confirmDisconnect = true }
                        .buttonStyle(.borderless)
                        .disabled(uploads.isUploading)
                        .accessibilityIdentifier("bunnyDeleteConnection")
                }
            }
            if let feedback {
                Label(feedback, systemImage: feedbackIsError ? "exclamationmark.triangle" : "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(feedbackIsError ? Color.orange : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("bunnyConnectionFeedback")
            }
            if uploads.isUploading {
                Text(tr("Připojení lze změnit po dokončení nebo zrušení probíhajícího nahrávání."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 12, weight: .medium))
            content().accessibilityLabel(title)
        }
    }

    private var affiliateInformation: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = AppDistribution.bunnyAffiliateURL {
                Link(destination: url) { bunnyBrand }
                    .accessibilityLabel(tr("Bunny.net — affiliate"))
                    .accessibilityIdentifier("bunnyAffiliateLogo")
                Link(destination: url) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(tr("Založit účet Bunny.net"))
                            .font(.system(size: 12, weight: .medium))
                        Text("affiliate").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(tr("Založit účet Bunny.net — affiliate"))
                .accessibilityIdentifier("bunnyAffiliateSignup")
            } else {
                bunnyBrand
                Text(tr("Doporučovací odkaz momentálně není k dispozici."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(AppDistribution.bunnyServiceNotice)
                .font(.caption).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var bunnyBrand: some View {
        HStack(spacing: 9) {
            Image("BunnyLogo").resizable().scaledToFit().frame(width: 28, height: 31)
                .accessibilityHidden(true)
            Text("bunny.net").font(.system(size: 20, weight: .semibold)).foregroundStyle(.primary)
        }
    }

    private var canKeepSavedPassword: Bool {
        guard let profile = uploads.profile else { return false }
        return uploads.hasStoredCredential && profile.id == profileID
            && profile.zoneName == zoneName.trimmingCharacters(in: .whitespacesAndNewlines)
            && profile.region == region
    }

    private func loadProfile() {
        guard let profile = uploads.profile else { return }
        profileID = profile.id
        zoneName = profile.zoneName
        region = profile.region
        remoteFolder = profile.remoteFolder
        cdnURL = profile.cdnBaseURL.absoluteString
    }

    private func saveProfile() {
        guard let url = URL(string: cdnURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            feedback = tr("Zadejte platnou HTTPS adresu CDN.")
            feedbackIsError = true
            return
        }
        let profile = BunnyStorageProfile(id: profileID, zoneName: zoneName,
            region: region, remoteFolder: remoteFolder, cdnBaseURL: url)
        do {
            try uploads.saveConfiguration(profile, password: password)
            password = ""
            feedback = tr("Připojení je uložené. Nahrávání spustíte až u hotového exportu.")
            feedbackIsError = false
            loadProfile()
        } catch {
            feedback = error.localizedDescription
            feedbackIsError = true
        }
    }

    private func disconnect() {
        do {
            try uploads.deleteConfiguration()
            profileID = UUID()
            zoneName = ""; region = .frankfurt; remoteFolder = ""; cdnURL = ""; password = ""
            feedback = tr("Úložiště je odpojené.")
            feedbackIsError = false
        } catch {
            feedback = error.localizedDescription
            feedbackIsError = true
        }
    }
}

/// A separate confirmation sheet prevents an export from silently becoming a network upload.
struct BunnyUploadSheet: View {
    let sources: [BunnyUploadSource]
    var preparationError: String?
    var onOpenSettings: () -> Void = {}
    @Environment(BunnyUploadCoordinator.self) private var uploads
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var started = false
    @State private var submittedIDs: Set<UUID> = []
    @State private var errorMessage: String?

    var body: some View {
        let _ = preferences.language
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("Nahrát na Bunny.net")).font(.title2.bold())
                Spacer(minLength: 12)
                Button(tr("Zavřít")) { dismiss() }.keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("bunnyUploadClose")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if started {
                        Text(tr("Přenosy pokračují nezávisle na výsledku exportu. Najdete je také v Nastavení → Bunny Storage."))
                            .font(.callout).foregroundStyle(.secondary)
                        BunnyUploadQueueView(jobIDs: submittedIDs)
                    } else {
                        confirmation
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !started {
                HStack {
                    Button(uploads.isConfigured ? tr("Upravit připojení…") : tr("Nastavit Bunny Storage…")) {
                        onOpenSettings()
                        dismiss()
                    }
                        .accessibilityIdentifier("bunnyConfigureFromUpload")
                    Spacer(minLength: 12)
                    Button(tr("Spustit nahrávání"), action: startUpload)
                        .buttonStyle(AppButtonStyle(primary: true))
                        .disabled(!uploads.isConfigured || uploads.isUploading || sources.isEmpty || preparationError != nil)
                        .accessibilityIdentifier("bunnyConfirmUpload")
                }
            }
        }
        .padding(24)
        .frame(width: 640, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Odešlou se pouze níže uvedené hotové soubory. Původní klipy ani rozpracované úpravy se neposílají."))
                .font(.callout).foregroundStyle(.secondary)
            Text(tr("Soubory: %d · %@", sources.count, EditorViewModel.formatBytes(sources.reduce(0) { $0 + $1.fileSizeBytes })))
                .font(.callout.weight(.semibold))
            if let profile = uploads.profile {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Cíl: %@ · %@", profile.zoneName, tr(profile.region.title)))
                        .font(.callout.weight(.medium))
                    Text(profile.cdnBaseURL.absoluteString).font(.caption).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Label(tr("Nejprve nastavte připojení k vlastnímu úložišti Bunny Storage."), systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(sources) { source in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(source.fileName).font(.system(size: 13, weight: .medium)).textSelection(.enabled)
                        Spacer(minLength: 12)
                        Text(EditorViewModel.formatBytes(source.fileSizeBytes)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    if let profile = uploads.profile {
                        Text(profile.publicURL(for: source).absoluteString)
                            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            Text(tr("Nahrané soubory mohou být veřejně dostupné přes uvedené CDN odkazy podle nastavení vašeho účtu. Ukládání a přenos dat platíte Bunny.net ze svého účtu."))
                .font(.caption).foregroundStyle(.secondary)
            if uploads.isUploading {
                Text(tr("Probíhá jiný přenos. Nové nahrávání spusťte po jeho dokončení nebo zrušení."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error = preparationError ?? errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("bunnyUploadPreparationError")
            }
        }
    }

    private func startUpload() {
        do {
            try uploads.enqueue(sources)
            let sourceIDs = Set(sources.map(\.id))
            submittedIDs = Set(uploads.jobs.filter { sourceIDs.contains($0.source.id) }.map(\.id))
            started = true
            uploads.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct BunnyUploadQueueView: View {
    @Environment(BunnyUploadCoordinator.self) private var uploads
    @Environment(AppPreferences.self) private var preferences
    var jobIDs: Set<UUID>?
    @State private var copiedJobID: UUID?

    private var jobs: [BunnyUploadJob] {
        uploads.jobs.filter { jobIDs?.contains($0.id) ?? true }
    }

    var body: some View {
        let _ = preferences.language
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(tr("Přenosy")).font(.system(size: 15, weight: .semibold))
                Spacer(minLength: 12)
                if jobs.contains(where: { $0.state == .queued }) {
                    Button(tr("Spustit čekající")) { uploads.start() }
                        .disabled(uploads.isUploading || !uploads.isConfigured)
                        .accessibilityIdentifier("bunnyStartQueuedUploads")
                }
            }
            if let error = uploads.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(jobs) { job in jobRow(job) }
        }
    }

    private func jobRow(_ job: BunnyUploadJob) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(job.source.fileName).font(.system(size: 13, weight: .medium)).textSelection(.enabled)
                Spacer(minLength: 12)
                Text(EditorViewModel.formatBytes(job.totalBytes)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if job.state == .hashing || job.state == .verifying {
                    ProgressView().controlSize(.small)
                }
                Text(statusTitle(job.state)).font(.caption)
                Spacer(minLength: 8)
                if job.state == .uploading {
                    Text("\(Int((job.progress * 100).rounded())) %").font(.caption.monospacedDigit())
                }
            }
            if job.state == .uploading {
                ProgressView(value: min(1, max(0, job.progress)))
                    .accessibilityLabel(tr("Průběh nahrávání"))
                    .accessibilityIdentifier("bunnyUploadProgress")
            }
            Text(job.publicURL.absoluteString)
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            if let error = job.errorMessage {
                Text(error).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 14) {
                if job.state == .completed {
                    Button(copiedJobID == job.id ? tr("Zkopírováno") : tr("Kopírovat CDN odkaz")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(job.publicURL.absoluteString, forType: .string)
                        copiedJobID = job.id
                    }
                    .accessibilityIdentifier("bunnyCopyCDNURL")
                    Button(tr("Otevřít CDN odkaz")) { NSWorkspace.shared.open(job.publicURL) }
                        .accessibilityIdentifier("bunnyOpenCDNURL")
                } else if job.state == .needsFile {
                    Button(tr("Vybrat soubor znovu…")) { reselect(job) }
                        .accessibilityIdentifier("bunnyReselectUploadFile")
                } else if job.state.canRetry {
                    Button(tr("Zkusit znovu")) { uploads.retry(job.id) }
                        .accessibilityIdentifier("bunnyRetryUpload")
                }
                if job.state.isActive || job.state == .queued {
                    Button(tr("Zrušit nahrávání")) { uploads.cancel(job.id) }
                        .accessibilityIdentifier("bunnyCancelUpload")
                } else {
                    Spacer(minLength: 0)
                    Button { uploads.remove(job.id) } label: { Image(systemName: "xmark") }
                        .help(tr("Odebrat z přenosů"))
                        .accessibilityLabel(tr("Odebrat z přenosů"))
                        .accessibilityIdentifier("bunnyRemoveUpload")
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bunnyUploadJob-\(job.id.uuidString)")
    }

    private func statusTitle(_ state: BunnyUploadState) -> String {
        switch state {
        case .queued: tr("Čeká na spuštění")
        case .hashing: tr("Připravuji kontrolní součet…")
        case .uploading: tr("Nahrávám na Bunny Storage…")
        case .verifying: tr("Ověřuji nahraný soubor…")
        case .waitingToRetry: tr("Čekám před opakováním přenosu…")
        case .completed: tr("Nahráno a ověřeno")
        case .failed: tr("Nahrávání selhalo")
        case .cancelled: tr("Nahrávání zrušeno")
        case .interrupted: tr("Přenos byl přerušen")
        case .needsFile: tr("Je potřeba znovu vybrat soubor")
        }
    }

    private func reselect(_ job: BunnyUploadJob) {
        let panel = NSOpenPanel()
        panel.title = tr("Vyberte znovu exportovaný soubor")
        panel.prompt = tr("Vybrat soubor")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .movie]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try uploads.reselect(job.id, fileURL: url) }
        catch { uploads.errorMessage = error.localizedDescription }
    }
}
