import SwiftUI
#if canImport(Translation)
import Translation
#endif

// Tarjima paneli: tillar, matn, natija. Apple tarjimasi translationTask orqali (macOS 15+).
struct TranslatorPanel: View {
    @ObservedObject var translator: TranslatorStore
    var compact = false
    var clipboardText: String?
    let onCopy: (String) -> Void
    let onSetup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            if !translator.canTranslate {
                unavailable
            } else {
                if !compact { languageBar }
                HStack(spacing: 6) {
                    Image(systemName: "character.bubble").foregroundStyle(Palette.accent).accessibilityHidden(true)
                    TextField(L10n.tr("Tarjima uchun matn · Enter"), text: $translator.input, axis: .vertical)
                        .textFieldStyle(.plain).font(.system(size: compact ? 12 : 13))
                        .lineLimit(compact ? 1 : 2)
                        .onSubmit { translator.translate() }
                        .accessibilityLabel(L10n.tr("Tarjima qilinadigan matn"))
                    if translator.translating { ProgressView().controlSize(.small) }
                    // Ixcham ko'rinishda til tanlovi yo'q: maqsad til qisqa belgisi ko'rsatiladi.
                    if compact {
                        Text("→ " + translator.target.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.muted)
                            .help(TranslationLanguage(id: translator.target).name)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, compact ? 5 : 7)
                .background(Palette.softFill, in: RoundedRectangle(cornerRadius: 8))
                if let suggestion = clipboardSuggestion {
                    Button {
                        translator.input = suggestion
                        translator.translate()
                    } label: {
                        Label(L10n.format("Clipboard: “%@”", String(suggestion.prefix(40))), systemImage: "doc.on.clipboard")
                            .font(.system(size: 11)).lineLimit(1).foregroundStyle(Palette.accent)
                    }
                    .buttonStyle(.plain)
                }
                result
            }
        }
        .modifier(AppleTranslationHost(translator: translator))
        .task(id: translator.provider) { await loadLanguages() }
    }

    private var clipboardSuggestion: String? {
        guard translator.input.isEmpty, translator.output.isEmpty, let text = clipboardText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, !Calculator.looksLikeExpression(text) else { return nil }
        return text
    }

    private var languageBar: some View {
        HStack(spacing: 6) {
            Picker("Manba tili", selection: $translator.source) {
                Text("Avtomatik").tag("")
                ForEach(translator.languages) { Text($0.name).tag($0.id) }
                if !translator.source.isEmpty, !translator.languages.contains(where: { $0.id == translator.source }) {
                    Text(TranslationLanguage(id: translator.source).name).tag(translator.source)
                }
            }
            .labelsHidden()
            Button { translator.swapLanguages() } label: { Image(systemName: "arrow.left.arrow.right") }
                .buttonStyle(.plain).foregroundStyle(Palette.muted)
                .help(L10n.tr("Tillarni almashtirish"))
                .accessibilityLabel(L10n.tr("Tillarni almashtirish"))
            Picker("Tarjima tili", selection: $translator.target) {
                ForEach(translator.languages) { Text($0.name).tag($0.id) }
                if !translator.languages.contains(where: { $0.id == translator.target }) {
                    Text(TranslationLanguage(id: translator.target).name).tag(translator.target)
                }
            }
            .labelsHidden()
        }
        .font(.system(size: 11))
    }

    @ViewBuilder
    private var result: some View {
        if let error = translator.errorMessage {
            Text(error).font(.system(size: 11)).foregroundStyle(Palette.warning).lineLimit(compact ? 2 : 3)
        } else if !translator.output.isEmpty {
            Button { onCopy(translator.output) } label: {
                HStack(alignment: .top, spacing: 5) {
                    Text(translator.output)
                        .font(.system(size: compact ? 12 : 14, weight: .medium))
                        .lineLimit(compact ? 2 : 4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "doc.on.doc").font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Tarjimani nusxalash"))
            .accessibilityLabel(L10n.format("Tarjima: %@. Nusxalash", translator.output))
        }
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(translator.provider == .apple ? L10n.tr("Apple tarjimasi macOS 15 va undan yangisida ishlaydi.") : L10n.tr("Google Cloud uchun API kaliti kiritilmagan."))
                .font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            SmallAction("Sozlash", action: onSetup)
        }
    }

    private func loadLanguages() async {
        switch translator.provider {
        case .google:
            translator.adoptLanguages(TranslationLanguage.googleDefaults)
        case .apple:
            #if canImport(Translation)
            if #available(macOS 15, *) {
                let supported = await LanguageAvailability().supportedLanguages
                translator.adoptLanguages(Set(supported.map { $0.minimalIdentifier }).map(TranslationLanguage.init)
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
            }
            #endif
        }
    }
}

// Apple tarjimasi faqat view hayotida ishlaydigan sessiya orqali bajariladi.
private struct AppleTranslationHost: ViewModifier {
    @ObservedObject var translator: TranslatorStore

    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(macOS 15, *) {
            content.modifier(AppleTranslationTask(translator: translator))
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#if canImport(Translation)
@available(macOS 15, *)
private struct AppleTranslationTask: ViewModifier {
    @ObservedObject var translator: TranslatorStore
    @State private var configuration: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        content
            .translationTask(configuration) { session in
                guard let request = translator.appleRequest else { return }
                do {
                    // Til paketi yo'q bo'lsa yuklab olish oynasi notch panelida ishonchsiz: foydalanuvchiga yo'l ko'rsatiladi.
                    let target = Locale.Language(identifier: translator.target)
                    let availability = LanguageAvailability()
                    let status = if translator.source.isEmpty {
                        try await availability.status(for: request.text, to: target)
                    } else {
                        await availability.status(from: Locale.Language(identifier: translator.source), to: target)
                    }
                    switch status {
                    case .unsupported:
                        translator.fail(id: request.id, L10n.tr("Bu til juftligi Apple tarjimasida yo‘q."))
                        return
                    case .supported:
                        translator.fail(id: request.id, L10n.tr("Til paketi o‘rnatilmagan: Tizim sozlamalari → Umumiy → Til va mintaqa → Tarjima tillari."))
                        return
                    default:
                        break
                    }
                    let response = try await session.translate(request.text)
                    translator.finish(id: request.id, text: response.targetText, detected: response.sourceLanguage.minimalIdentifier)
                } catch {
                    translator.fail(id: request.id, error.localizedDescription)
                }
            }
            .onAppear { start(translator.appleRequest) }
            .onDisappear { translator.cancelPending() }
            .onChange(of: translator.appleRequest) { _, request in start(request) }
    }

    private func start(_ request: TranslatorStore.AppleRequest?) {
        guard let request, translator.provider == .apple, translator.claim(request.id) else { return }
        let source = translator.source.isEmpty ? nil : Locale.Language(identifier: translator.source)
        let target = Locale.Language(identifier: translator.target)
        // Bir xil tillar bilan qayta so'rov: konfiguratsiya bekor qilinib, vazifa qayta ishga tushadi.
        if configuration?.source == source, configuration?.target == target {
            configuration?.invalidate()
        } else {
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }
}
#endif

struct TranslateWidget: View {
    @ObservedObject var translator: TranslatorStore
    let size: WidgetSize
    let clipboardText: String?
    let onCopy: (String) -> Void
    let onSetup: () -> Void

    var body: some View {
        WidgetCard(title: "Tarjima", icon: "character.bubble", accent: Palette.accent, showHeader: size == .large) {
            TranslatorPanel(translator: translator, compact: size != .large, clipboardText: size == .large ? clipboardText : nil,
                            onCopy: onCopy, onSetup: onSetup)
        }
    }
}
