import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english, uzbek, uzbekCyrillic, russian

    var id: Self { self }

    var title: String {
        switch self {
        case .system: L10n.tr("Tizim tili")
        case .english: "English"
        case .uzbek: "O‘zbekcha"
        case .uzbekCyrillic: "Ўзбекча (Кирилл)"
        case .russian: "Русский"
        }
    }

    var code: String {
        switch self {
        case .system: Self.systemCode
        case .english: "en"
        case .uzbek: "uz"
        case .uzbekCyrillic: "uz-Cyrl"
        case .russian: "ru"
        }
    }

    var locale: Locale { Locale(identifier: code) }

    private static var systemCode: String {
        for language in Locale.preferredLanguages {
            let value = language.lowercased()
            if value.hasPrefix("uz-cyrl") { return "uz-Cyrl" }
            if value.hasPrefix("uz") { return "uz" }
            if value.hasPrefix("ru") { return "ru" }
            if value.hasPrefix("en") { return "en" }
        }
        return "en"
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: L10n.tr("Tizim ko‘rinishi")
        case .light: L10n.tr("Yorug‘")
        case .dark: L10n.tr("Qorong‘i")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum L10n {
    static func tr(_ key: String) -> String {
        let selection = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system
        guard let path = Bundle.main.path(forResource: selection.code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: Locale(identifier: (AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system).code), arguments: arguments)
    }
}
