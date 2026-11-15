import AppKit
import Combine
import Observation
import Sparkle

/// Direct-download edition only. The Store target does not compile or link this service.
@MainActor
final class AppUpdateController: NSObject, ObservableObject, NSApplicationDelegate, SPUUpdaterDelegate {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    @Published private(set) var lastCheckDate: Date?
    @Published private(set) var hasPendingInstallation = false
    @Published private(set) var hasUploadActivity = false

    private var controller: SPUStandardUpdaterController?
    private var editor: EditorViewModel?
    private var installHandler: (() -> Void)?
    private var approvedTermination = false
    private var discardConfirmation: (@MainActor (Bool) -> Bool)?
    private var uploadActivity: @MainActor () -> Bool = { false }

    override init() { super.init() }

    init(discardConfirmation: @escaping @MainActor (Bool) -> Bool,
         uploadActivity: @escaping @MainActor () -> Bool = { false }) {
        self.discardConfirmation = discardConfirmation
        self.uploadActivity = uploadActivity
        super.init()
    }

    var isBusy: Bool {
        uploadActivity() || (editor.map { $0.isExporting || $0.isLoadingClips || $0.isBuildingPreview } ?? false)
    }

    var canInstallUpdate: Bool { hasPendingInstallation && installHandler != nil && !isBusy }

    func configure(editor: EditorViewModel, startUpdater: Bool = true, uploads: BunnyUploadCoordinator? = nil) {
        guard controller == nil else { return }
        self.editor = editor
        if let uploads {
            uploadActivity = { [weak uploads] in uploads?.isUploading ?? false }
            observeUploads(uploads)
        }
        let controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil
        )
        self.controller = controller
        let updater = controller.updater
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        updater.publisher(for: \.automaticallyChecksForUpdates)
            .assign(to: &$automaticallyChecksForUpdates)
        updater.publisher(for: \.automaticallyDownloadsUpdates)
            .assign(to: &$automaticallyDownloadsUpdates)
        updater.publisher(for: \.lastUpdateCheckDate)
            .assign(to: &$lastCheckDate)
        if startUpdater { controller.startUpdater() }
    }

    func checkForUpdates() {
        guard canCheckForUpdates, !isBusy else { return }
        controller?.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
    }

    func setAutomaticDownloads(_ enabled: Bool) {
        controller?.updater.automaticallyDownloadsUpdates = enabled
    }

    func installPendingUpdate() {
        guard canInstallUpdate, let installHandler else { return }
        guard confirmDiscardIfNeeded(isUpdate: true) else { return }
        approvedTermination = true
        // Retain the callback: Sparkle permits retrying if termination is cancelled.
        installHandler()
    }

    // Both explicit installation and install-on-quit pass this ordinary AppKit gate.
    // A relaunch hook alone cannot protect every Sparkle installation path.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if uploadActivity() {
            approvedTermination = false
            UploadTerminationGuard.showActiveUploadAlert()
            return .terminateCancel
        }
        if isBusy {
            approvedTermination = false
            let alert = NSAlert()
            alert.messageText = tr("Probíhá zpracování videa")
            alert.informativeText = tr("Před ukončením nebo instalací aktualizace dokončete či zrušte export a vyčkejte na dokončení přípravy videa.")
            alert.addButton(withTitle: tr("Pokračovat v práci"))
            alert.runModal()
            return .terminateCancel
        }
        if approvedTermination { return .terminateNow }
        return confirmDiscardIfNeeded(isUpdate: hasPendingInstallation) ? .terminateNow : .terminateCancel
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard !isBusy else {
            throw NSError(domain: "LocalioBC.Updates", code: 1, userInfo: [
                NSLocalizedDescriptionKey: tr("Aktualizace budou dostupné po dokončení zpracování videa.")
            ])
        }
    }

    func allowedSystemProfileKeys(for updater: SPUUpdater) -> [String]? { [] }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        if approvedTermination && !isBusy { return false }
        approvedTermination = false
        guard isBusy || !(editor?.clips.isEmpty ?? true) else { return false }
        self.installHandler = installHandler
        hasPendingInstallation = true
        return true
    }

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        installHandler = immediateInstallHandler
        hasPendingInstallation = true
        // Let the user finish the session, or install explicitly from Settings.
        // Sparkle still installs on ordinary quit, protected by applicationShouldTerminate.
        return true
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        approvedTermination = false
        installHandler = nil
        hasPendingInstallation = false
    }

    private func confirmDiscardIfNeeded(isUpdate: Bool) -> Bool {
        guard !(editor?.clips.isEmpty ?? true) else { return true }
        if let discardConfirmation { return discardConfirmation(isUpdate) }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = tr("Máte rozpracované úpravy")
        alert.informativeText = tr("Nastavení střihu se ukládá jen do paměti. Před ukončením exportujte výsledek, pokud jej chcete zachovat. Zdrojové soubory zůstanou beze změny.")
        alert.addButton(withTitle: tr("Pokračovat v práci"))
        alert.addButton(withTitle: isUpdate ? tr("Restartovat a aktualizovat") : tr("Ukončit a zahodit úpravy"))
        return alert.runModal() == .alertSecondButtonReturn
    }

    private func observeUploads(_ uploads: BunnyUploadCoordinator) {
        withObservationTracking {
            hasUploadActivity = uploads.isUploading
        } onChange: { [weak self, weak uploads] in
            Task { @MainActor in
                guard let self, let uploads else { return }
                self.observeUploads(uploads)
            }
        }
    }
}
