import Foundation
import SwiftUI

enum WidgetSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large

    var id: Self { self }

    var title: String {
        switch self {
        case .small: "Kichik"
        case .medium: "O‘rta"
        case .large: "Katta"
        }
    }

    // Grid katakchalari: kichik 1×1, o'rta 2×1, katta 2×2.
    var columns: Int { self == .small ? 1 : 2 }
    var rows: Int { self == .large ? 2 : 1 }
}

enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case music, calendar, weather, clipboard, codexLimits, claudeLimits
    case cpu, memory, gpu, network
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .music: "Hozir ijroda"
        case .calendar: "Kalendar"
        case .weather: "Ob-havo"
        case .clipboard: "Clipboard"
        case .codexLimits: "Codex limiti"
        case .claudeLimits: "Claude limiti"
        case .cpu: "Protsessor (CPU)"
        case .memory: "Xotira (RAM)"
        case .gpu: "Grafika (GPU)"
        case .network: "Tarmoq"
        case .custom: "Maxsus widget"
        }
    }

    var icon: String {
        switch self {
        case .music: "music.note"
        case .calendar: "calendar"
        case .weather: "cloud.sun.fill"
        case .clipboard: "doc.on.clipboard"
        case .codexLimits, .claudeLimits: "sparkle"
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .gpu: "rectangle.3.group"
        case .network: "arrow.up.arrow.down"
        case .custom: "puzzlepiece.extension"
        }
    }

    var defaultSize: WidgetSize {
        switch self {
        case .music: .large
        case .calendar, .clipboard, .network: .medium
        default: .small
        }
    }

    var isStat: Bool { [.cpu, .memory, .gpu, .network].contains(self) }

    // Galereyada qo'shiladigan turlar (maxsus widget alohida forma orqali).
    static var builtIn: [WidgetKind] { allCases.filter { $0 != .custom && !$0.isStat } }
}

enum StatStyle: String, Codable, CaseIterable, Identifiable {
    case number, ring, graph

    var id: Self { self }

    var title: String {
        switch self {
        case .number: "Raqam"
        case .ring: "Halqa"
        case .graph: "Grafik"
        }
    }
}

struct WidgetConfig: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: WidgetKind
    var size: WidgetSize
    var statStyle: StatStyle = .ring
    var custom: CustomWidgetSpec?

    init(kind: WidgetKind, size: WidgetSize? = nil, custom: CustomWidgetSpec? = nil) {
        self.kind = kind
        self.size = size ?? kind.defaultSize
        self.custom = custom
    }

    // Kelajakda yangi maydon qo'shilsa ham eski saqlangan widgetlar o'qiladi.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decode(WidgetKind.self, forKey: .kind)
        size = (try? c.decodeIfPresent(WidgetSize.self, forKey: .size)) ?? kind.defaultSize
        statStyle = (try? c.decodeIfPresent(StatStyle.self, forKey: .statStyle)) ?? .ring
        custom = try c.decodeIfPresent(CustomWidgetSpec.self, forKey: .custom)
    }

    var title: String { custom?.title ?? kind.title }
    var icon: String { custom?.icon ?? kind.icon }
}

@MainActor
final class WidgetStore: ObservableObject {
    @Published private(set) var widgets: [WidgetConfig]

    static let defaults: [WidgetConfig] = [
        WidgetConfig(kind: .music),
        WidgetConfig(kind: .calendar),
        WidgetConfig(kind: .weather),
        WidgetConfig(kind: .claudeLimits),
        WidgetConfig(kind: .codexLimits),
        WidgetConfig(kind: .clipboard)
    ]

    init() {
        if let data = UserDefaults.standard.data(forKey: "widgets") {
            // Har element alohida o'qiladi: noma'lum tur (boshqa versiyadan) butun ro'yxatni buzmaydi.
            let items = (try? JSONSerialization.jsonObject(with: data)) as? [Any] ?? []
            let decoded = items.compactMap { item -> WidgetConfig? in
                guard let itemData = try? JSONSerialization.data(withJSONObject: item) else { return nil }
                return try? JSONDecoder().decode(WidgetConfig.self, from: itemData)
            }
            if decoded.count != items.count { UserDefaults.standard.set(data, forKey: "widgets.backup") }
            widgets = decoded
        } else {
            // 0.4 dagi yashirilgan kartalar yangi widget ro'yxatiga o'tkaziladi.
            let hidden = Set(UserDefaults.standard.stringArray(forKey: "hiddenCards") ?? [])
            let legacy: [WidgetKind: String] = [.music: "music", .calendar: "calendar", .weather: "weather", .clipboard: "clipboard", .codexLimits: "limits", .claudeLimits: "limits"]
            widgets = Self.defaults.filter { !hidden.contains(legacy[$0.kind] ?? "") }
        }
    }

    func add(_ widget: WidgetConfig) {
        widgets.append(widget)
        save()
    }

    func remove(_ id: UUID) {
        widgets.removeAll { $0.id == id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        widgets.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func update(_ widget: WidgetConfig) {
        guard let index = widgets.firstIndex(where: { $0.id == widget.id }) else { return }
        widgets[index] = widget
        save()
    }

    func resetToDefaults() {
        widgets = Self.defaults.map { WidgetConfig(kind: $0.kind, size: $0.size) }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(widgets) {
            UserDefaults.standard.set(data, forKey: "widgets")
        }
    }
}

// Widgetlarni sahifalarga joylashtiradi: har sahifa columns × rows katak. Har widget birinchi bo'sh
// joyga qo'yiladi (oldingi sahifadagi bo'shliq keyingi kichik widget bilan to'ladi), vertikal scroll yo'q.
struct WidgetPlacement: Identifiable {
    let widget: WidgetConfig
    let page: Int
    let column: Int
    let row: Int
    var id: UUID { widget.id }
}

enum WidgetLayout {
    static func place(_ widgets: [WidgetConfig], columns: Int, rows: Int) -> [WidgetPlacement] {
        var pages: [[[Bool]]] = []
        var result: [WidgetPlacement] = []
        for widget in widgets {
            let width = min(widget.size.columns, columns), height = min(widget.size.rows, rows)
            var placed = false
            var page = 0
            while !placed {
                if page == pages.count { pages.append(Array(repeating: Array(repeating: false, count: columns), count: rows)) }
                search: for row in 0...(rows - height) {
                    for column in 0...(columns - width) where fits(pages[page], column, row, width, height) {
                        for r in row..<(row + height) { for c in column..<(column + width) { pages[page][r][c] = true } }
                        result.append(WidgetPlacement(widget: widget, page: page, column: column, row: row))
                        placed = true
                        break search
                    }
                }
                page += 1
            }
        }
        return result
    }

    private static func fits(_ grid: [[Bool]], _ column: Int, _ row: Int, _ width: Int, _ height: Int) -> Bool {
        for r in row..<(row + height) { for c in column..<(column + width) where grid[r][c] { return false } }
        return true
    }
}
