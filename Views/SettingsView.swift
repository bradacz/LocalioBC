import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: AppPreferences
    var initialTab = 0
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss

    private let accent = Color(red: 0.19, green: 0.34, blue: 0.78)
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }

    var body: some View {
        let _ = preferences.language
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        if selectedTab == 0 { generalContent } else { aboutContent }
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(preferences.language)
                Divider()
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.secondary)
                    Text(tr("Změny se ukládají automaticky."))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(tr("Zavřít")) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .controlSize(.regular)
                }
                .font(.caption)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
        }
        .frame(width: 760, height: 610)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .onAppear { selectedTab = initialTab }
        .preferredColorScheme(preferences.appearance.colorScheme)
        .environment(\.locale, Locale(identifier: preferences.language.resolvedCode))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 38, height: 38)
                Text("LocalioBC").font(.system(size: 15, weight: .semibold))
            }
            .padding(.bottom, 28)
            navigationItem(tr("Obecné"), icon: "slider.horizontal.3", tab: 0)
            navigationItem(tr("O aplikaci"), icon: "info.circle", tab: 1)
            Spacer()
            VStack(alignment: .leading, spacing: 5) {
                Text(tr("Verze %@", version))
                Text("LocalioBuzz").fontWeight(.medium)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 24)
        .frame(width: 184)
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.025))
    }

    private func navigationItem(_ title: String, icon: String, tab: Int) -> some View {
        Button { selectedTab = tab } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundStyle(selectedTab == tab ? Color.white : Color.primary)
                .background(selectedTab == tab ? accent : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }

    private var generalContent: some View {
        Group {
            heading(tr("Nastavení"), subtitle: tr("Přizpůsobte si své pracovní prostředí."))
            VStack(alignment: .leading, spacing: 14) {
                sectionHeading(tr("Vzhled"), subtitle: tr("Vyberte vzhled aplikace nebo jej slaďte se systémem."))
                HStack(spacing: 12) {
                    ForEach(AppAppearance.allCases) { appearance in
                        AppearanceOption(appearance: appearance, selected: preferences.appearance == appearance, accent: accent) {
                            preferences.appearance = appearance
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                sectionHeading(tr("Jazyk"), subtitle: tr("Jazyk rozhraní můžete kdykoli změnit."))
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 19))
                        .foregroundStyle(.secondary)
                        .frame(width: 30)
                    Text(tr("Jazyk aplikace")).font(.system(size: 13, weight: .medium))
                    Spacer(minLength: 8)
                    Picker(tr("Jazyk"), selection: $preferences.language) {
                        ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08)))
            }
            Label(tr("Změny se projeví ihned. Aplikaci není potřeba restartovat."), systemImage: "bolt")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var aboutContent: some View {
        Group {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 6) {
                    Text("LocalioBC").font(.system(size: 28, weight: .bold))
                    Text(tr("Verze %@", version)).font(.callout).foregroundStyle(.secondary)
                    Text(tr("Zdarma a open source"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(tr("LocalioBC je open source a zcela zdarma. Bez předplatného, reklam a vodoznaků."))
                Text(tr("Videa se zpracovávají lokálně na vašem Macu. Pro úpravy ani export není potřeba účet nebo internet."))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 13))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 14) {
                Text(tr("Co aplikace umí")).font(.system(size: 15, weight: .semibold))
                VStack(spacing: 0) {
                    ForEach(Array(Self.features.enumerated()), id: \.offset) { index, feature in
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(accent)
                                .frame(width: 16, height: 18)
                            Text(tr(feature)).font(.system(size: 12))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        if index < Self.features.count - 1 { Divider().padding(.leading, 41) }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08)))
            }
            VStack(alignment: .leading, spacing: 14) {
                Text(tr("Odkazy a kontakt")).font(.system(size: 15, weight: .semibold))
                VStack(spacing: 8) {
                    contactLink("LocalioBuzz", detail: "www.localiobuzz.com", icon: "globe", url: "https://www.localiobuzz.com")
                    contactLink("MyLocalio", detail: "mylocalio.com", icon: "globe", url: "https://mylocalio.com")
                    contactLink(tr("Zdrojový kód na GitHubu"), detail: "bradacz/LocalioBC", icon: "chevron.left.forwardslash.chevron.right", url: "https://github.com/bradacz/LocalioBC")
                    contactLink(tr("Kontakt"), detail: "info@mylocalio.com", icon: "envelope", url: "mailto:info@mylocalio.com")
                }
            }
            Text(tr("Licence MIT • © 2026 LocalioBC contributors"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 26, weight: .bold))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func contactLink(_ title: String, detail: String, icon: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(accent).frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.primary)
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
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

private struct AppearanceOption: View {
    let appearance: AppAppearance
    let selected: Bool
    let accent: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 11) {
                ZStack {
                    miniature(dark: appearance == .dark)
                    if appearance == .system {
                        miniature(dark: true)
                            .mask(HStack(spacing: 0) { Color.clear; Color.black })
                    }
                }
                .frame(height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.primary.opacity(0.12)))
                HStack(spacing: 6) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? accent : Color.secondary)
                    Text(appearance.title)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(selected ? accent.opacity(0.07) : Color.primary.opacity(hovering ? 0.035 : 0), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? accent : Color.primary.opacity(0.1), lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(appearance.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func miniature(dark: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(0..<3) { _ in Circle().fill(dark ? Color.white.opacity(0.25) : Color.black.opacity(0.18)).frame(width: 4, height: 4) }
                Spacer()
            }
            .padding(6)
            .background(dark ? Color(white: 0.20) : Color(white: 0.93))
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.65)).frame(width: 18)
                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(dark ? Color(white: 0.65) : Color(white: 0.5)).frame(width: 36, height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(dark ? Color(white: 0.3) : Color(white: 0.86)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(dark ? Color(white: 0.3) : Color(white: 0.86)).frame(height: 4)
                }
            }
            .padding(8)
            .frame(maxHeight: .infinity)
            .background(dark ? Color(white: 0.13) : Color.white)
        }
        .accessibilityHidden(true)
    }
}
