import AppKit

/// Both distribution channels must finish or cancel transfers before terminating.
@MainActor
enum UploadTerminationGuard {
    static func showActiveUploadAlert() {
        let alert = NSAlert()
        alert.messageText = tr("Probíhá nahrávání na Bunny Storage")
        alert.informativeText = tr("Před ukončením aplikace nebo instalací aktualizace dokončete či zrušte nahrávání. Přerušené přenosy lze po příštím spuštění zopakovat.")
        alert.addButton(withTitle: tr("Pokračovat v práci"))
        alert.runModal()
    }
}

#if APP_STORE
@MainActor
final class StoreApplicationDelegate: NSObject, NSApplicationDelegate {
    private var editor: EditorViewModel?
    private var uploads: BunnyUploadCoordinator?

    func configure(editor: EditorViewModel, uploads: BunnyUploadCoordinator) {
        self.editor = editor
        self.uploads = uploads
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if uploads?.isUploading == true {
            UploadTerminationGuard.showActiveUploadAlert()
            return .terminateCancel
        }
        if let editor, editor.isExporting || editor.isLoadingClips || editor.isBuildingPreview {
            let alert = NSAlert()
            alert.messageText = tr("Probíhá zpracování videa")
            alert.informativeText = tr("Před ukončením nebo instalací aktualizace dokončete či zrušte export a vyčkejte na dokončení přípravy videa.")
            alert.addButton(withTitle: tr("Pokračovat v práci"))
            alert.runModal()
            return .terminateCancel
        }
        return .terminateNow
    }
}
#endif
