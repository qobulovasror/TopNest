import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WidgetSettingsPage: View {
    @ObservedObject var store: WidgetStore
    @ObservedObject var state: AppState
    @State private var editing: EditorTarget?
    @State private var message: String?
    @State private var removed: (widget: WidgetConfig, after: UUID?)?

    struct EditorTarget: Identifiable {
        let id = UUID()
        var widgetID: UUID?
        var spec: CustomWidgetSpec
    }

    private static let rowHeight: CGFloat = 40

    var body: some View {
        let context = state.widgetContext()
        Form {
            Section {
                WidgetLayoutPreview(widgets: store.widgets, context: context, showsWelcome: !state.hasSeenWelcome,
                                    onSwap: { store.swap($0, with: $1) })
                    .frame(height: 150)
            } header: {
                Text("Ko‘rinish")
            } footer: {
                Text("Widgetlar joyini almashtirish uchun sxemada bir kartani boshqasiga sudrang. Kulrang ramka panel ochilganda ko‘rinadigan 4 ustunni bildiradi; o‘ngdagi widgetlarga gorizontal siljitib o‘tiladi. Uzuq chiziqli katak sozlash kutmoqda.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                // Ichki List o'zi scroll qilmaydi: g'ildirak tashqi sahifani aylantiradi.
                List {
                    ForEach(Array(store.widgets.enumerated()), id: \.element.id) { index, widget in
                        row(widget, index: index, state: WidgetRules.state(for: widget, in: context))
                            .frame(height: Self.rowHeight)
                    }
                    .onMove { store.move(from: $0, to: $1) }
                }
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(max(store.widgets.count, 1)) * (Self.rowHeight + 10) + 8)
                if let removed {
                    HStack {
                        Image(systemName: "trash").foregroundStyle(.secondary)
                        Text(L10n.format("“%@” olib tashlandi", removed.widget.title))
                        Spacer()
                        Button("Qaytarish") {
                            store.restore(removed.widget, after: removed.after)
                            self.removed = nil
                        }
                        .keyboardShortcut("z", modifiers: .command)
                        .disabled(editing != nil)
                        Button { self.removed = nil } label: { Image(systemName: "xmark") }
                            .buttonStyle(.borderless).accessibilityLabel("Yopish")
                    }
                    .font(.callout)
                    // Qaytarish faqat yaqinda qilingan amal uchun: oyna qayta ochilganda eski o'chirish tiklanmasin.
                    .task(id: removed.widget.id) {
                        try? await Task.sleep(for: .seconds(10))
                        if !Task.isCancelled { self.removed = nil }
                    }
                }
            } header: {
                Text("Asosiy ekrandagi widgetlar")
            } footer: {
                Text("Tartibni sudrab, ↑ ↓ tugmalari yoki qatorning kontekst menyusi orqali o‘zgartiring. Kichik — 1 katak, o‘rta — 2, katta — 4. Ma’lumoti yo‘q widget panelda yashiriladi; sababi qator ostida yozilgan.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Menu("Widget qo‘shish") {
                        ForEach(WidgetKind.builtIn) { kind in
                            Button { store.add(WidgetConfig(kind: kind)) } label: { Label(kind.title, systemImage: kind.icon) }
                        }
                        Divider()
                        Button { editing = EditorTarget(spec: CustomWidgetSpec(title: "Yangi widget")) } label: {
                            Label("Maxsus widget…", systemImage: WidgetKind.custom.icon)
                        }
                    }
                    .fixedSize()
                    Button("Fayldan import…", action: importWidget)
                    Spacer()
                    Button("Standartga qaytarish", action: confirmReset)
                }
                if let message {
                    Text(L10n.tr(message)).font(.footnote).foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { target in
            CustomWidgetEditor(spec: target.spec) { spec in
                if let id = target.widgetID, var widget = store.widgets.first(where: { $0.id == id }) {
                    widget.custom = spec
                    store.update(widget)
                } else {
                    store.add(WidgetConfig(kind: .custom, size: .small, custom: spec))
                }
            }
        }
    }

    private func remove(_ widget: WidgetConfig) {
        removed = store.remove(widget.id)
    }

    private func row(_ widget: WidgetConfig, index: Int, state widgetState: WidgetState) -> some View {
        HStack(spacing: 10) {
            Image(systemName: widget.icon).frame(width: 18).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(widget.title).lineLimit(1)
                statusLine(widgetState)
            }
            Spacer()
            if widget.kind.isStat {
                Picker("\(widget.title) uslubi", selection: binding(widget, \.statStyle)) {
                    ForEach(StatStyle.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden().fixedSize()
            }
            Picker("\(widget.title) o‘lchami", selection: binding(widget, \.size)) {
                ForEach(WidgetSize.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden().fixedSize()
            if let spec = widget.custom {
                Button { editing = EditorTarget(widgetID: widget.id, spec: spec) } label: { Image(systemName: "pencil") }
                    .help("Tahrirlash").accessibilityLabel("\(widget.title): tahrirlash")
                Button { export(spec) } label: { Image(systemName: "square.and.arrow.up") }
                    .help("Faylga eksport").accessibilityLabel("\(widget.title): faylga eksport")
            }
            Button { store.move(widget.id, by: -1) } label: { Image(systemName: "chevron.up") }
                .disabled(index == 0)
                .help("Yuqoriga").accessibilityLabel("\(widget.title): yuqoriga")
            Button { store.move(widget.id, by: 1) } label: { Image(systemName: "chevron.down") }
                .disabled(index == store.widgets.count - 1)
                .help("Pastga").accessibilityLabel("\(widget.title): pastga")
            Button(role: .destructive) { remove(widget) } label: { Image(systemName: "trash") }
                .help("Olib tashlash").accessibilityLabel("\(widget.title): olib tashlash")
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .contain)
        .contextMenu {
            Button("Yuqoriga") { store.move(widget.id, by: -1) }.disabled(index == 0)
            Button("Pastga") { store.move(widget.id, by: 1) }.disabled(index == store.widgets.count - 1)
            Divider()
            Button("Olib tashlash", role: .destructive) { remove(widget) }
        }
        .accessibilityAction(named: "Yuqoriga") { store.move(widget.id, by: -1) }
        .accessibilityAction(named: "Pastga") { store.move(widget.id, by: 1) }
    }

    @ViewBuilder
    private func statusLine(_ widgetState: WidgetState) -> some View {
        switch widgetState {
        case .ready:
            Text("Panelda ko‘rinadi").font(.caption).foregroundStyle(.secondary)
        case .hidden(let reason):
            Label(L10n.format("Yashirin: %@", reason), systemImage: "eye.slash").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        case .needsSetup(let reason, _):
            Label(L10n.format("Sozlash kerak: %@", reason), systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange).lineLimit(1)
        }
    }

    private func binding<Value>(_ widget: WidgetConfig, _ keyPath: WritableKeyPath<WidgetConfig, Value>) -> Binding<Value> {
        Binding(
            get: { store.widgets.first(where: { $0.id == widget.id })?[keyPath: keyPath] ?? widget[keyPath: keyPath] },
            set: { value in
                guard var current = store.widgets.first(where: { $0.id == widget.id }) else { return }
                current[keyPath: keyPath] = value
                store.update(current)
            }
        )
    }

    private func importWidget() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        var imported = 0
        for url in panel.urls {
            guard let data = try? Data(contentsOf: url),
                  let spec = (try? JSONDecoder().decode(CustomWidgetSpec.self, from: data))?.normalized() else { continue }
            guard spec.source != .command || confirmCommand(spec) else { continue }
            store.add(WidgetConfig(kind: .custom, size: .small, custom: spec))
            imported += 1
        }
        message = imported == panel.urls.count ? nil : "Ba’zi fayllar qo‘shilmadi (format noto‘g‘ri yoki rad etildi)."
    }

    // Begona fayldagi buyruq panel ochilganda avtomatik bajariladi, shuning uchun avval ko'rsatiladi.
    private func confirmCommand(_ spec: CustomWidgetSpec) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.format("“%@” widgeti buyruq bajaradi", spec.title)
        alert.informativeText = L10n.format("Quyidagi buyruq sizning hisobingiz nomidan har %d soniyada ishga tushadi. Faqat ishonchli manbadan olingan bo‘lsa qo‘shing.", spec.refreshSeconds)
        let scroll = NSTextView.scrollableTextView()
        scroll.frame = NSRect(x: 0, y: 0, width: 380, height: 110)
        scroll.hasVerticalScroller = true
        if let text = scroll.documentView as? NSTextView {
            text.string = spec.target
            text.isEditable = false
            text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        }
        alert.accessoryView = scroll
        alert.addButton(withTitle: L10n.tr("Bekor qilish"))
        alert.addButton(withTitle: L10n.tr("Qo‘shish"))
        return alert.runModal() == .alertSecondButtonReturn
    }

    // Maxsus widgetlar ham o'chadi, shuning uchun avval tasdiq so'raladi.
    private func confirmReset() {
        let alert = NSAlert()
        alert.messageText = L10n.tr("Widgetlarni standart holatga qaytarasizmi?")
        alert.informativeText = L10n.tr("Barcha qo‘shilgan va maxsus widgetlar o‘chiriladi. Maxsus widgetlarni avval faylga eksport qilib qo‘yishingiz mumkin.")
        alert.addButton(withTitle: L10n.tr("Bekor qilish"))
        alert.addButton(withTitle: L10n.tr("Qaytarish"))
        if alert.runModal() == .alertSecondButtonReturn {
            store.resetToDefaults()
            removed = nil
        }
    }

    private func export(_ spec: CustomWidgetSpec) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        let safeName = spec.title.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
        panel.nameFieldStringValue = "\(safeName).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            try encoder.encode(spec).write(to: url, options: .atomic)
            message = nil
        } catch {
            message = L10n.format("Faylni saqlab bo‘lmadi: %@", error.localizedDescription)
        }
    }
}

struct CustomWidgetEditor: View {
    @State var spec: CustomWidgetSpec
    @StateObject private var runner = CustomWidgetRunner()
    let onSave: (CustomWidgetSpec) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Ko‘rinish") {
                    TextField("Nomi", text: $spec.title)
                    TextField("SF Symbol ikonka nomi", text: $spec.icon)
                    Picker("Ko‘rsatish", selection: $spec.display) {
                        ForEach(CustomWidgetSpec.Display.allCases) { Text($0.title).tag($0) }
                    }
                    if spec.display == .gauge {
                        TextField("Maksimum qiymat", value: $spec.gaugeMax, format: .number)
                    }
                    TextField("Oldidan (masalan, $)", text: $spec.prefix)
                    TextField("Keyidan (masalan, °C)", text: $spec.suffix)
                }
                Section("Ma’lumot manbasi") {
                    Picker("Manba", selection: $spec.source) {
                        ForEach(CustomWidgetSpec.Source.allCases) { Text($0.title).tag($0) }
                    }
                    TextField(spec.source == .url ? "https://api.example.com/data (faqat https)" : "masalan: uptime | awk '{print $3}'", text: $spec.target)
                        .font(.system(.body, design: .monospaced))
                    TextField("JSON yo‘li (ixtiyoriy, masalan data.items[0].price)", text: $spec.jsonPath)
                        .font(.system(.body, design: .monospaced))
                    Stepper("Yangilash: har \(spec.refreshSeconds) soniyada", value: $spec.refreshSeconds, in: 10...86_400, step: spec.refreshSeconds < 60 ? 10 : 60)
                    if spec.source == .command {
                        Text("Buyruq sizning hisobingiz nomidan bajariladi. Faqat o‘zingiz ishonadigan buyruqlarni yozing.")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
                Section("Sinov") {
                    HStack {
                        Button("Sinab ko‘rish") { runner.refresh(spec) }
                        Spacer()
                        if let value = runner.value {
                            Text(spec.prefix + value + spec.suffix).lineLimit(1).foregroundStyle(.green)
                        } else if let error = runner.error {
                            Text(L10n.tr(error)).foregroundStyle(.orange)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Bekor qilish") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Saqlash") {
                    onSave(spec)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(spec.title.trimmingCharacters(in: .whitespaces).isEmpty || spec.target.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 520, height: 560)
    }
}

// Sozlamalardagi sxema: haqiqiy joylashuv algoritmi bilan widgetlar tartibi, o'lchami va holati.
struct WidgetLayoutPreview: View {
    let widgets: [WidgetConfig]
    let context: WidgetContext
    var showsWelcome = false
    var onSwap: ((UUID, UUID) -> Void)? = nil
    @State private var dropTarget: UUID?

    var body: some View {
        let entries = widgets.compactMap { widget -> (WidgetConfig, WidgetState)? in
            let state = WidgetRules.state(for: widget, in: context)
            return state.isVisible ? (widget, state) : nil
        }
        // Asosiy ekran bilan bir xil: birinchi ishga tushirishda "Xush kelibsiz" kartasi birinchi turadi.
        let items = (showsWelcome ? [WidgetGridItem(id: HomeContent.welcomeID, size: .large)] : []) + entries.map { entry in
            let size: WidgetSize = if case .needsSetup = entry.1 { .small } else { entry.0.size }
            return WidgetGridItem(id: entry.0.id, size: size)
        }
        let layout = WidgetLayout.pack(items, rows: HomeContent.rows)
        GeometryReader { geo in
            let visible = WidgetLayout.displayColumns(for: layout.columnCount, visible: HomeContent.visibleColumns)
            let columns = max(layout.columnCount, visible)
            let spacing: CGFloat = 4
            let cell = (geo.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let rowHeight = (geo.size.height - spacing * CGFloat(HomeContent.rows - 1)) / CGFloat(HomeContent.rows)
            ZStack(alignment: .topLeading) {
                // Panelda birdaniga ko'rinadigan qism.
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.secondary.opacity(0.6), lineWidth: 1.5)
                    .frame(width: cell * CGFloat(visible) + spacing * CGFloat(visible - 1) + 6, height: geo.size.height + 6)
                    .offset(x: -3, y: -3)
                ForEach(layout.placements) { placement in
                    if placement.id == HomeContent.welcomeID {
                        welcomeTile
                            .frame(width: cell * CGFloat(placement.columns) + spacing * CGFloat(placement.columns - 1),
                                   height: rowHeight * CGFloat(placement.rows) + spacing * CGFloat(placement.rows - 1))
                            .offset(x: CGFloat(placement.column) * (cell + spacing), y: CGFloat(placement.row) * (rowHeight + spacing))
                    } else if let entry = entries.first(where: { $0.0.id == placement.id }) {
                        previewTile(entry.0, state: entry.1)
                            .frame(width: cell * CGFloat(placement.columns) + spacing * CGFloat(placement.columns - 1),
                                   height: rowHeight * CGFloat(placement.rows) + spacing * CGFloat(placement.rows - 1))
                            .offset(x: CGFloat(placement.column) * (cell + spacing), y: CGFloat(placement.row) * (rowHeight + spacing))
                    }
                }
                if entries.isEmpty {
                    Text("Panelda hozir hech qaysi widget ko‘rinmaydi").font(.callout).foregroundStyle(.secondary)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .padding(4)
        .accessibilityElement(children: onSwap == nil ? .ignore : .contain)
        .accessibilityLabel(L10n.format("Widgetlar joylashuvi sxemasi: %d ta widget panelda ko‘rinadi", entries.count))
    }

    @ViewBuilder
    private func previewTile(_ widget: WidgetConfig, state: WidgetState) -> some View {
        if let onSwap {
            tile(widget, state: state)
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, lineWidth: dropTarget == widget.id ? 2 : 0))
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .draggable(widget.id.uuidString) {
                    tile(widget, state: state).frame(width: 120, height: 56)
                }
                .dropDestination(for: String.self) { values, _ in
                    guard let value = values.first, let source = UUID(uuidString: value),
                          widgets.contains(where: { $0.id == source }), source != widget.id else { return false }
                    onSwap(source, widget.id)
                    return true
                } isTargeted: { targeted in
                    if targeted { dropTarget = widget.id }
                    else if dropTarget == widget.id { dropTarget = nil }
                }
                .help(L10n.tr("Joyini almashtirish uchun boshqa widget ustiga sudrang"))
        } else {
            tile(widget, state: state)
        }
    }

    private var welcomeTile: some View {
        VStack(spacing: 3) {
            Image(systemName: "hand.wave").font(.system(size: 12))
            Text("Xush kelibsiz").font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.secondary.opacity(0.5)))
    }

    @ViewBuilder
    private func tile(_ widget: WidgetConfig, state: WidgetState) -> some View {
        let setup: Bool = if case .needsSetup = state { true } else { false }
        VStack(spacing: 3) {
            Image(systemName: widget.icon).font(.system(size: 12))
            Text(widget.title).font(.system(size: 9, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(setup ? Color.secondary : Color.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(setup ? Color.clear : Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: setup ? [3, 2] : [])).foregroundStyle(.secondary.opacity(0.5)))
    }
}
