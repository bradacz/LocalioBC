import SwiftUI

@main
struct LocalioBCApp: App {
    @State private var viewModel = EditorViewModel()
    @State private var preferences = AppPreferences()

    var body: some Scene {
        let _ = preferences.language
        WindowGroup("LocalioBC") {
            EditorRootView(viewModel: viewModel, preferences: preferences)
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
        }
        Settings {
            SettingsView(preferences: preferences)
        }
    }
}

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
