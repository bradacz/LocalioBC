import AppKit
import AVFoundation
import Sparkle
import XCTest
@testable import LocalioBC

final class AppUpdateTests: XCTestCase {
    @MainActor
    func testChecksWaitForExportImportAndPreviewPreparation() throws {
        let context = makeContext()
        let checks: [SPUUpdateCheck] = [.updates, .updatesInBackground, .updateInformation]
        for state in 0..<3 {
            context.editor.isExporting = state == 0
            context.editor.isLoadingClips = state == 1
            context.editor.isBuildingPreview = state == 2
            XCTAssertTrue(context.subject.isBusy)
            for check in checks {
                XCTAssertThrowsError(try context.subject.updater(context.updater, mayPerform: check)) { error in
                    XCTAssertEqual((error as NSError).domain, "LocalioBC.Updates")
                }
            }
        }
        context.editor.isExporting = false
        context.editor.isLoadingClips = false
        context.editor.isBuildingPreview = false
        for check in checks {
            XCTAssertNoThrow(try context.subject.updater(context.updater, mayPerform: check))
        }
        XCTAssertEqual(context.subject.allowedSystemProfileKeys(for: context.updater), [])
    }

    @MainActor
    func testIdleEmptyEditorDoesNotDelayInstallationOrAskToDiscard() {
        var confirmations = 0
        let context = makeContext { _ in confirmations += 1; return false }
        var callbacks = 0
        XCTAssertFalse(context.subject.updater(context.updater,
            shouldPostponeRelaunchForUpdate: SUAppcastItem.empty(), untilInvokingBlock: { callbacks += 1 }))
        XCTAssertFalse(context.subject.hasPendingInstallation)
        XCTAssertFalse(context.subject.canInstallUpdate)
        XCTAssertEqual(callbacks, 0)
        XCTAssertEqual(context.subject.applicationShouldTerminate(NSApplication.shared), .terminateNow)
        XCTAssertEqual(confirmations, 0)
    }

    @MainActor
    func testBusyInstallationStaysQueuedUntilProcessingFinishes() {
        for state in 0..<3 {
            let context = makeContext()
            context.editor.isExporting = state == 0
            context.editor.isLoadingClips = state == 1
            context.editor.isBuildingPreview = state == 2
            var callbacks = 0
            XCTAssertTrue(context.subject.updater(context.updater,
                shouldPostponeRelaunchForUpdate: SUAppcastItem.empty(), untilInvokingBlock: { callbacks += 1 }))
            XCTAssertTrue(context.subject.hasPendingInstallation)
            XCTAssertFalse(context.subject.canInstallUpdate)
            context.subject.installPendingUpdate()
            XCTAssertEqual(callbacks, 0)

            context.editor.isExporting = false
            context.editor.isLoadingClips = false
            context.editor.isBuildingPreview = false
            XCTAssertTrue(context.subject.canInstallUpdate)
            context.subject.installPendingUpdate()
            XCTAssertEqual(callbacks, 1)
            XCTAssertEqual(context.subject.applicationShouldTerminate(NSApplication.shared), .terminateNow)
        }
    }

    @MainActor
    func testDecliningInstallationAndQuitKeepsTheEditingSession() {
        var confirmations: [Bool] = []
        let context = makeContext { isUpdate in confirmations.append(isUpdate); return false }
        context.editor.clips = [makeClip()]
        let originalID = context.editor.clips[0].id
        var callbacks = 0
        XCTAssertTrue(context.subject.updater(context.updater,
            shouldPostponeRelaunchForUpdate: SUAppcastItem.empty(), untilInvokingBlock: { callbacks += 1 }))
        context.subject.installPendingUpdate()
        XCTAssertEqual(callbacks, 0)
        XCTAssertTrue(context.subject.hasPendingInstallation)
        XCTAssertTrue(context.subject.canInstallUpdate)
        XCTAssertEqual(context.subject.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        XCTAssertEqual(confirmations, [true, true])
        XCTAssertEqual(context.editor.clips.map(\.id), [originalID])
    }

    @MainActor
    func testOrdinaryQuitCanBeCancelledWithoutAnUpdate() {
        var confirmations: [Bool] = []
        let context = makeContext { isUpdate in confirmations.append(isUpdate); return false }
        context.editor.clips = [makeClip()]
        XCTAssertEqual(context.subject.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        XCTAssertEqual(confirmations, [false])
        XCTAssertEqual(context.editor.clips.count, 1)
    }

    @MainActor
    func testConfirmedManualInstallationDoesNotAskAgainDuringTermination() {
        var confirmations: [Bool] = []
        let context = makeContext { isUpdate in confirmations.append(isUpdate); return true }
        context.editor.clips = [makeClip()]
        var callbacks = 0
        XCTAssertTrue(context.subject.updater(context.updater,
            shouldPostponeRelaunchForUpdate: SUAppcastItem.empty(), untilInvokingBlock: { callbacks += 1 }))
        XCTAssertEqual(callbacks, 0)
        context.subject.installPendingUpdate()
        XCTAssertEqual(callbacks, 1)
        XCTAssertEqual(context.subject.applicationShouldTerminate(NSApplication.shared), .terminateNow)
        XCTAssertEqual(confirmations, [true])
    }

    @MainActor
    func testApprovedAutomaticInstallationDoesNotPostponeASecondTime() {
        var confirmations: [Bool] = []
        let context = makeContext { isUpdate in confirmations.append(isUpdate); return true }
        context.editor.clips = [makeClip()]
        let item = SUAppcastItem.empty()
        let updater = context.updater
        var immediateCallbacks = 0
        var secondPostponement: Bool?
        // Sparkle invokes its postponement hook after the automatic install callback.
        // This order previously postponed an already-approved install a second time.
        XCTAssertTrue(context.subject.updater(context.updater, willInstallUpdateOnQuit: item,
            immediateInstallationBlock: { [weak subject = context.subject] in
                immediateCallbacks += 1
                secondPostponement = subject?.updater(updater,
                    shouldPostponeRelaunchForUpdate: item, untilInvokingBlock: {
                        XCTFail("An approved automatic installation must not need another callback")
                    })
            }))
        XCTAssertEqual(immediateCallbacks, 0)
        XCTAssertTrue(context.subject.canInstallUpdate)
        context.subject.installPendingUpdate()
        XCTAssertEqual(immediateCallbacks, 1)
        XCTAssertEqual(secondPostponement, false)
        XCTAssertEqual(context.subject.applicationShouldTerminate(NSApplication.shared), .terminateNow)
        XCTAssertEqual(confirmations, [true])
    }

    @MainActor
    func testProcessingThatStartsAfterApprovalDefersAndRequiresFreshApproval() {
        var confirmations = 0
        let context = makeContext { _ in confirmations += 1; return true }
        context.editor.clips = [makeClip()]
        let item = SUAppcastItem.empty()
        let updater = context.updater
        let editor = context.editor
        var postponedAfterProcessingStarted: Bool?
        var resumedCallbacks = 0
        XCTAssertTrue(context.subject.updater(context.updater, willInstallUpdateOnQuit: item,
            immediateInstallationBlock: { [weak subject = context.subject] in
                editor.isExporting = true
                postponedAfterProcessingStarted = subject?.updater(updater,
                    shouldPostponeRelaunchForUpdate: item, untilInvokingBlock: { resumedCallbacks += 1 })
            }))
        context.subject.installPendingUpdate()
        XCTAssertEqual(postponedAfterProcessingStarted, true)
        XCTAssertFalse(context.subject.canInstallUpdate)
        XCTAssertEqual(confirmations, 1)
        context.subject.installPendingUpdate()
        XCTAssertEqual(resumedCallbacks, 0)
        XCTAssertEqual(confirmations, 1)

        context.editor.isExporting = false
        context.subject.installPendingUpdate()
        XCTAssertEqual(resumedCallbacks, 1)
        XCTAssertEqual(confirmations, 2)
        XCTAssertEqual(context.subject.applicationShouldTerminate(NSApplication.shared), .terminateNow)
        XCTAssertEqual(confirmations, 2)
    }

    @MainActor
    private func makeContext(confirmation: @escaping @MainActor (Bool) -> Bool = { _ in true }) -> Context {
        let editor = EditorViewModel()
        let subject = AppUpdateController(discardConfirmation: confirmation)
        subject.configure(editor: editor, startUpdater: false)
        // Both actual Sparkle controllers remain stopped: tests exercise the delegate
        // contracts without fetching a feed or showing framework UI.
        let driver = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        return Context(subject: subject, editor: editor, driver: driver)
    }

    private func makeClip() -> VideoClip {
        VideoClip(url: URL(fileURLWithPath: "/private/tmp/localiobc-updater-fixture.mov"),
                  fileName: "updater-fixture.mov", fileSizeBytes: 1_000,
                  duration: CMTime(seconds: 2, preferredTimescale: 600),
                  naturalSize: CGSize(width: 320, height: 180), preferredTransform: .identity,
                  displaySize: CGSize(width: 320, height: 180), nominalFrameRate: 30,
                  hasAudio: false, estimatedDataRate: 4_000)
    }

    @MainActor
    private struct Context {
        let subject: AppUpdateController
        let editor: EditorViewModel
        let driver: SPUStandardUpdaterController
        var updater: SPUUpdater { driver.updater }
    }
}
