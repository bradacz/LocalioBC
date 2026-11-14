import AppKit
import Combine
import Sparkle

/// Direct-download edition only. The Store target does not compile or link this service.
@MainActor
final class AppUpdateController: NSObject, ObservableObject, NSApplicationDelegate, SPUUpdaterDelegate {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    @Published private(set) var lastCheckDate: Date?
    @Published private(set) var hasPendingInstallation = false

    private var controller: SPUStandardUpdaterController?
    private var editor: EditorViewModel?
    private var installHandler: (() -> Void)?
    private var approvedTermination = false
    private var discardConfirmation: (@MainActor (Bool) -> Bool)?

    override init() { super.init() }

    init(discardConfirmation: @escaping @MainActor (Bool) -> Bool) {
        self.discardConfirmation = discardConfirmation
        super.init()
    }

    var isBusy: Bool {
        guard let editor else { return false }
        return editor.isExporting || editor.isLoadingClips || editor.isBuildingPreview
    }

    var canInstallUpdate: Bool { hasPendingInstallation && installHandler != nil && !isBusy }

    func configure(editor: EditorViewModel, startUpdater: Bool = true) {
        guard controller == nil else { return }
        self.editor = editor
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
}
