import Foundation

// Widget panelda qanday ko'rinishi: tayyor, vaqtincha bo'sh (yashiriladi) yoki sozlash kerak.
enum WidgetState: Equatable {
    case ready
    case hidden(reason: String)
    case needsSetup(reason: String, action: SetupAction)

    var isVisible: Bool {
        if case .hidden = self { return false }
        return true
    }

    var reason: String? {
        switch self {
        case .ready: nil
        case .hidden(let reason), .needsSetup(let reason, _): reason
        }
    }
}

enum SetupAction: Equatable {
    case openSettings(SettingsPage)
    case requestCalendarAccess
    case openCalendarPrivacy
    case openAutomationPrivacy

    var title: String {
        switch self {
        case .openSettings: L10n.tr("Sozlash")
        case .requestCalendarAccess: L10n.tr("Ruxsat berish")
        case .openCalendarPrivacy, .openAutomationPrivacy: L10n.tr("Tizim sozlamalari")
        }
    }
}

enum CalendarAccess: Equatable {
    case notDetermined, denied, granted
}

// Widget holatini aniqlash uchun kerakli barcha ma'lumot: UI va servislardan mustaqil, test qilinadi.
struct WidgetContext: Equatable {
    var musicEnabled = false
    var musicPermissionDenied = false
    var calendarAccess: CalendarAccess = .notDetermined
    var hasUpcomingEvents = false
    var weatherCityConfigured = false
    var hasWeather = false
    var weatherError: String?
    var clipboardEnabled = false
    var hasClips = false
    var codexEnabled = true
    var codexInstalled = true
    var hasCodexUsage = false
    var codexError: String?
    var claudeInstalled = false
    var hasClaudeUsage = false
}

enum WidgetRules {
    static func state(for widget: WidgetConfig, in context: WidgetContext) -> WidgetState {
        switch widget.kind {
        case .music:
            // Musiqa roziligisiz yoqilmaydi: tugma tushuntirishi bor sozlamani ochadi.
            if !context.musicEnabled {
                return .needsSetup(reason: L10n.tr("Musiqa kuzatuvi o‘chiq"), action: .openSettings(.music))
            }
            if context.musicPermissionDenied {
                return .needsSetup(reason: L10n.tr("Automation ruxsati yo‘q"), action: .openAutomationPrivacy)
            }
            // Trek yo'q holati widgetning o'zida ko'rsatiladi: karta joyi sakramaydi.
            return .ready
        case .calendar:
            switch context.calendarAccess {
            case .notDetermined: return .needsSetup(reason: L10n.tr("Kalendarga ruxsat kerak"), action: .requestCalendarAccess)
            case .denied: return .needsSetup(reason: L10n.tr("Kalendar ruxsati rad etilgan"), action: .openCalendarPrivacy)
            case .granted: return context.hasUpcomingEvents ? .ready : .hidden(reason: L10n.tr("Yaqin 2 kunda uchrashuv yo‘q"))
            }
        case .weather:
            if !context.weatherCityConfigured {
                return .needsSetup(reason: L10n.tr("Shahar tanlanmagan"), action: .openSettings(.weather))
            }
            if context.hasWeather { return .ready }
            return .hidden(reason: context.weatherError.map { L10n.format("Ob-havo yuklanmadi: %@", $0) } ?? L10n.tr("Ob-havo yuklanmoqda"))
        case .clipboard:
            if !context.clipboardEnabled {
                return .needsSetup(reason: L10n.tr("Clipboard tarixi o‘chiq"), action: .openSettings(.clipboard))
            }
            return context.hasClips ? .ready : .hidden(reason: L10n.tr("Hali nusxalangan matn yo‘q"))
        case .codexLimits:
            if !context.codexEnabled { return .hidden(reason: L10n.tr("Sozlamalarda o‘chirilgan")) }
            if !context.codexInstalled { return .hidden(reason: L10n.tr("Codex CLI topilmadi")) }
            if context.hasCodexUsage { return .ready }
            return .hidden(reason: context.codexError ?? L10n.tr("Limitlar yuklanmoqda"))
        case .claudeLimits:
            if !context.claudeInstalled {
                return .needsSetup(reason: L10n.tr("Claude Code ulanmagan"), action: .openSettings(.integrations))
            }
            return context.hasClaudeUsage ? .ready : .hidden(reason: L10n.tr("Claude Code ishlatilgach limitlar paydo bo‘ladi"))
        case .cpu, .memory, .gpu, .network:
            return .ready
        case .custom:
            return widget.custom == nil ? .hidden(reason: L10n.tr("Widget ta’rifi yo‘q")) : .ready
        }
    }
}
