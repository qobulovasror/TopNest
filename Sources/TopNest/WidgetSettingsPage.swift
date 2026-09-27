import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WidgetSettingsPage: View {
    @ObservedObject var store: WidgetStore
    @State private var editing: EditorTarget?
    @State private var message: String?

    struct EditorTarget: Identifiable {
        let id = UUID()
        var widgetID: UUID?
        var spec: CustomWidgetSpec
    }

    var body: some View {
        Form {
            Section {
                // Ichki List o'zi scroll qilmaydi: g'ildirak tashqi sahifani aylantiradi.
                List {
                    ForEach(store.widgets) { widget in
                        row(widget).frame(height: 32)
                    }
                    .onMove { store.move(from: $0, to: $1) }
                }
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(max(store.widgets.count, 1)) * 44 + 8)
            } header: {
                Text("Asosiy ekrandagi widgetlar")
            } footer: {
                Text("Tartibni sudrab o‘zgartiring. Widgetlar 4 × 2 katakli sahifalarga joylashadi: kichik — 1 katak, o‘rta — 2, katta — 4. Joy yetmasa keyingi sahifaga o‘tadi. Ma’lumoti yo‘q widget (masalan, ruxsatsiz kalendar) yashiriladi.")
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
                    Text(message).font(.footnote).foregroundStyle(.orange)
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

    private func row(_ widget: WidgetConfig) -> some View {
        HStack(spacing: 10) {
            Image(systemName: widget.icon).frame(width: 18).foregroundStyle(.secondary)
            Text(widget.title).lineLimit(1)
            Spacer()
            if widget.kind.isStat {
                Picker("Uslub", selection: binding(widget, \.statStyle)) {
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
            Button(role: .destructive) { store.remove(widget.id) } label: { Image(systemName: "trash") }
                .help("Olib tashlash").accessibilityLabel("\(widget.title): olib tashlash")
        }
        .buttonStyle(.borderless)
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
        alert.messageText = "“\(spec.title)” widgeti buyruq bajaradi"
        alert.informativeText = "Quyidagi buyruq sizning hisobingiz nomidan har \(spec.refreshSeconds) soniyada ishga tushadi. Faqat ishonchli manbadan olingan bo‘lsa qo‘shing."
        let scroll = NSTextView.scrollableTextView()
        scroll.frame = NSRect(x: 0, y: 0, width: 380, height: 110)
        scroll.hasVerticalScroller = true
        if let text = scroll.documentView as? NSTextView {
            text.string = spec.target
            text.isEditable = false
            text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        }
        alert.accessoryView = scroll
        alert.addButton(withTitle: "Bekor qilish")
        alert.addButton(withTitle: "Qo‘shish")
        return alert.runModal() == .alertSecondButtonReturn
    }

    // Maxsus widgetlar ham o'chadi, shuning uchun avval tasdiq so'raladi.
    private func confirmReset() {
        let alert = NSAlert()
        alert.messageText = "Widgetlarni standart holatga qaytarasizmi?"
        alert.informativeText = "Barcha qo‘shilgan va maxsus widgetlar o‘chiriladi. Maxsus widgetlarni avval faylga eksport qilib qo‘yishingiz mumkin."
        alert.addButton(withTitle: "Bekor qilish")
        alert.addButton(withTitle: "Qaytarish")
        if alert.runModal() == .alertSecondButtonReturn { store.resetToDefaults() }
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
            message = "Faylni saqlab bo‘lmadi: \(error.localizedDescription)"
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
                            Text(error).foregroundStyle(.orange)
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
