import AppKit
import Observation
import SwiftUI

enum AppDistribution {
    static let website = URL(string: "https://localiobc.mylocalio.com")!
    static let privacyURL = website.appendingPathComponent("privacy/")

    static var aboutTitle: String {
        #if APP_STORE
        tr("Jednorázový nákup · Open source")
        #else
        tr("Zdarma a open source")
        #endif
    }

    static var aboutDescription: String {
        #if APP_STORE
        tr("LocalioBC je open source editor videa. Jednorázový nákup v Mac App Storu, bez předplatného, reklam a vodoznaků.")
        #else
        tr("LocalioBC je open source a zcela zdarma. Bez předplatného, reklam a vodoznaků.")
        #endif
    }

    static var footer: String {
        #if APP_STORE
        tr("Lokální zpracování · Bez předplatného · Open source")
        #else
        tr("Lokální zpracování · Zdarma · Open source")
        #endif
    }
}

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
        resolvedCode(preferredLanguages: Locale.preferredLanguages)
    }

    func resolvedCode(preferredLanguages: [String]) -> String {
        if self != .system { return rawValue }
        guard let primaryLanguage = preferredLanguages.first else { return "en" }
        return Locale.Language(identifier: primaryLanguage).languageCode?.identifier == "cs" ? "cs" : "en"
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
