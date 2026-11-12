import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: AppPreferences
    var initialTab = 0
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = preferences.language
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                Form {
                    Picker(tr("Vzhled"), selection: $preferences.appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    Picker(tr("Jazyk"), selection: $preferences.language) {
                        ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                    }
                    Text(tr("Změny se použijí ihned a uloží se pro příští spuštění."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .formStyle(.grouped)
                .tabItem { Label(tr("Obecné"), systemImage: "gearshape") }.tag(0)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(nsImage: NSApp.applicationIconImage)
                                .resizable().frame(width: 64, height: 64)
                            Text("LocalioBC").font(.largeTitle.bold())
                        }
                        Text(tr("Verze %@", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(tr("LocalioBC je open source a zcela zdarma. Bez předplatného, reklam a vodoznaků."))
                        Text(tr("Videa se zpracovávají lokálně na vašem Macu. Pro úpravy ani export není potřeba účet nebo internet."))
                        Text(tr("Co aplikace umí")).font(.headline)
                        ForEach(Self.features, id: \.self) { feature in
                            Label(tr(feature), systemImage: "checkmark.circle")
                                .font(.callout).fixedSize(horizontal: false, vertical: true)
                        }
                        Divider()
                        Text(tr("Odkazy a kontakt")).font(.headline)
                        Link("www.localiobuzz.com", destination: URL(string: "https://www.localiobuzz.com")!)
                        Link("mylocalio.com", destination: URL(string: "https://mylocalio.com")!)
                        Link("info@mylocalio.com", destination: URL(string: "mailto:info@mylocalio.com")!)
                        Link(tr("Zdrojový kód na GitHubu"), destination: URL(string: "https://github.com/bradacz/LocalioBC")!)
                        Text(tr("Licence MIT • © 2026 LocalioBC contributors"))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                }
                .tabItem { Label(tr("O aplikaci"), systemImage: "info.circle") }.tag(1)
            }
            .id(preferences.language)
            Divider()
            HStack { Spacer(); Button(tr("Zavřít")) { dismiss() }.keyboardShortcut(.cancelAction) }
                .padding(12)
        }
        .frame(width: 560, height: 520)
        .onAppear { selectedTab = initialTab }
        .preferredColorScheme(preferences.appearance.colorScheme)
        .environment(\.locale, Locale(identifier: preferences.language.resolvedCode))
    }

    static let features = [
        "Import MP4, MOV a M4V z disku nebo přetažením.",
        "Střih začátku a konce klipů s časovou osou a náhledy.",
        "Ořez 16:9, 9:16, 1:1, 4:5, 4:3 nebo vlastní výřez.",
        "Stejný ořez na jeden klip nebo na všechny klipy najednou.",
        "Změna pořadí a spojení klipů, i s různými rozměry a orientací.",
        "Export do jednoho videa nebo každý klip do samostatného souboru.",
        "MP4 a MOV, kodeky H.264 a HEVC, volitelné omezení rozlišení.",
        "Bezeztrátový export kompatibilního klipu bez změny obrazu.",
        "Předvolby kvality, cílová velikost v MB a odhad výstupní velikosti.",
        "Odstranění zvukových stop, průběh exportu a možnost zrušení.",
        "České a anglické rozhraní; světlý, tmavý nebo systémový vzhled."
    ]
}
