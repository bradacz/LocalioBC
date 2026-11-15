import SwiftUI

@main
struct LocalioBCApp: App {
    @State private var viewModel = EditorViewModel()
    @State private var preferences = AppPreferences()
    @State private var uploads = BunnyUploadCoordinator.shared
    #if APP_STORE
    @NSApplicationDelegateAdaptor(StoreApplicationDelegate.self) private var lifecycle
    #endif
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
                .environment(uploads)
                .onAppear { lifecycle.configure(editor: viewModel, uploads: uploads) }
            #else
            EditorRootView(viewModel: viewModel, preferences: preferences)
                .environment(uploads)
                .environmentObject(updates)
                .onAppear { updates.configure(editor: viewModel, uploads: uploads) }
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
                .environment(uploads)
            #else
            SettingsView(preferences: preferences).environmentObject(updates)
                .environment(uploads)
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
    static let showLocalioBunnyStorageSettings = Notification.Name("showLocalioBunnyStorageSettings")
}

private struct EditorRootView: View {
    private enum SettingsDestination: Int, Identifiable {
        case general = 0, about = 1, bunny = 2
        var id: Int { rawValue }
    }
    let viewModel: EditorViewModel
    @Bindable var preferences: AppPreferences
    @State private var settingsDestination: SettingsDestination?
    @State private var pendingUpdateAction: (@MainActor () -> Void)?

    var body: some View {
        ContentView(viewModel: viewModel, onOpenSettings: { settingsDestination = .general })
            .id(preferences.language)
            .environment(preferences)
            .environment(\.locale, Locale(identifier: preferences.language.resolvedCode))
            .tint(AppDesign.accent)
            .preferredColorScheme(preferences.appearance.colorScheme)
            .sheet(item: $settingsDestination, onDismiss: {
                let action = pendingUpdateAction
                pendingUpdateAction = nil
                action?()
            }) { destination in
                SettingsView(preferences: preferences, initialTab: destination.rawValue,
                    performUpdateAction: { action in
                        pendingUpdateAction = action
                        settingsDestination = nil
                    })
            }
            .onReceive(NotificationCenter.default.publisher(for: .showLocalioSettings)) { _ in settingsDestination = .about }
            .onReceive(NotificationCenter.default.publisher(for: .showLocalioBunnyStorageSettings)) { _ in settingsDestination = .bunny }
            .onChange(of: preferences.appearance, initial: true) {
                switch preferences.appearance {
                case .system: NSApp.appearance = nil
                case .light: NSApp.appearance = NSAppearance(named: .aqua)
                case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
                }
            }
    }
}
