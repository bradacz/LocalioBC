import AppKit
import Observation
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return tr("Podle systému")
        case .light: return tr("Světlý")
        case .dark: return tr("Tmavý")
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, czech = "cs", english = "en"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return tr("Podle systému")
        case .czech: return "Čeština"
        case .english: return "English"
        }
    }
    var resolvedCode: String {
        if self != .system { return rawValue }
        return Locale.preferredLanguages.first?.hasPrefix("cs") == true ? "cs" : "en"
    }
}

@Observable
@MainActor
final class AppPreferences {
    @ObservationIgnored private let defaults: UserDefaults
    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: "appAppearance") }
    }
    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "appLanguage") }
    }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = AppAppearance(rawValue: defaults.string(forKey: "appAppearance") ?? "") ?? .system
        language = AppLanguage(rawValue: defaults.string(forKey: "appLanguage") ?? "") ?? .system
    }
}

func localized(_ key: String, language: AppLanguage) -> String {
    guard let path = Bundle.main.path(forResource: language.resolvedCode, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return key }
    return bundle.localizedString(forKey: key, value: key, table: nil)
}

func tr(_ key: String, _ arguments: CVarArg...) -> String {
    let language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system
    let value = localized(key, language: language)
    return arguments.isEmpty ? value : String(format: value, locale: Locale(identifier: language.resolvedCode), arguments: arguments)
}
