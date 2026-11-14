import SwiftUI

@main
struct LocalioBCApp: App {
    @State private var viewModel = EditorViewModel()
    @State private var preferences = AppPreferences()
    #if !APP_STORE
    @NSApplicationDelegateAdaptor(AppUpdateController.self) private var updates
    #endif

    init() {
        NativeAppLanguage.prepareForLaunch()
    }

    var body: some Scene {
        let _ = preferences.language
        WindowGroup("LocalioBC") {
            #if APP_STORE
            EditorRootView(viewModel: viewModel, preferences: preferences)
            #else
            EditorRootView(viewModel: viewModel, preferences: preferences)
                .environmentObject(updates)
                .onAppear { updates.configure(editor: viewModel) }
            #endif
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(tr("Přidat video…")) { viewModel.openFilePicker() }
                    .keyboardShortcut("o", modifiers: .command)
                    .disabled(viewModel.isExporting)
                Divider()
                Button(tr("Exportovat video…")) { viewModel.startExport() }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(viewModel.clips.isEmpty || viewModel.isExporting || viewModel.isEditingCrop)
            }
            CommandGroup(replacing: .appInfo) {
                Button(tr("O aplikaci LocalioBC")) {
                    NotificationCenter.default.post(name: .showLocalioSettings, object: nil)
                }
            }
            #if !APP_STORE
            CommandGroup(after: .appInfo) {
                CheckForUpdatesCommand(updates: updates)
            }
            #endif
        }
        Settings {
            #if APP_STORE
            SettingsView(preferences: preferences)
            #else
            SettingsView(preferences: preferences).environmentObject(updates)
            #endif
        }
    }
}

#if !APP_STORE
/// Command content needs its own observation; an App delegate adaptor alone does
/// not invalidate the native menu when Sparkle finishes starting asynchronously.
private struct CheckForUpdatesCommand: View {
    @ObservedObject var updates: AppUpdateController

    var body: some View {
        Button(tr("Zkontrolovat aktualizace…")) { updates.checkForUpdates() }
            .disabled(!updates.canCheckForUpdates || updates.isBusy)
    }
}
#endif

extension Notification.Name {
    static let showLocalioSettings = Notification.Name("showLocalioSettings")
}

private struct EditorRootView: View {
    let viewModel: EditorViewModel
    @Bindable var preferences: AppPreferences
    @State private var showSettings = false
    @State private var showAbout = false

    var body: some View {
        ContentView(viewModel: viewModel, onOpenSettings: { showAbout = false; showSettings = true })
            .id(preferences.language)
            .environment(preferences)
            .environment(\.locale, Locale(identifier: preferences.language.resolvedCode))
            .tint(AppDesign.accent)
            .preferredColorScheme(preferences.appearance.colorScheme)
            .sheet(isPresented: $showSettings) { SettingsView(preferences: preferences, initialTab: showAbout ? 1 : 0) }
            .onReceive(NotificationCenter.default.publisher(for: .showLocalioSettings)) { _ in showAbout = true; showSettings = true }
            .onChange(of: preferences.appearance, initial: true) {
                switch preferences.appearance {
                case .system: NSApp.appearance = nil
                case .light: NSApp.appearance = NSAppearance(named: .aqua)
                case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
                }
            }
    }
}
