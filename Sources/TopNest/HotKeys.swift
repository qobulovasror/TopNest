import Carbon.HIToolbox
import Foundation

// Carbon hot key Accessibility ruxsatisiz ishlaydi.
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handler: EventHandlerRef?
    private let signature: OSType = 0x544E_5354 // "TNST"

    func register(id: UInt32, keyCode: Int, modifiers: Int, action: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs.append(ref)
        actions[id] = action
        return true
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actions.removeAll()
    }

    fileprivate func fire(_ id: UInt32) { actions[id]?() }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let id = hotKeyID.id
            MainActor.assumeIsolated { HotKeyCenter.shared.fire(id) }
            return noErr
        }, 1, &spec, nil, &handler)
    }
}

// Barcha global yorliqlar bitta jadvalda: ro'yxatdan o'tkazish va sozlamadagi ro'yxat shundan olinadi.
enum HotKeyAction: UInt32, CaseIterable, Identifiable {
    case togglePanel = 1, clipboardSearch = 2, focusTimer = 3

    var id: Self { self }

    var keyCode: Int {
        switch self {
        case .togglePanel: kVK_ANSI_N
        case .clipboardSearch: kVK_ANSI_V
        case .focusTimer: kVK_ANSI_T
        }
    }

    static let modifiers = controlKey | optionKey | cmdKey

    var title: String {
        switch self {
        case .togglePanel: L10n.tr("Panelni ochish/yopish")
        case .clipboardSearch: L10n.tr("Clipboard qidiruvi")
        case .focusTimer: L10n.tr("Taymer: boshlash/pauza")
        }
    }

    var shortcut: String {
        switch self {
        case .togglePanel: "⌃⌥⌘N"
        case .clipboardSearch: "⌃⌥⌘V"
        case .focusTimer: "⌃⌥⌘T"
        }
    }
}
