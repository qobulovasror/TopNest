import SwiftUI

// Bitta ifoda maydoni: natija yozish davomida, Enter — nusxalash va tarixga yozish.
struct CalculatorField: View {
    @ObservedObject var calculator: CalculatorStore
    var compact = false
    var autoFocus = false
    let onCopy: (String) -> Void
    @State private var copied = false
    @State private var copiedReset: Task<Void, Never>?
    @FocusState private var focused: Bool
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 6) {
            HStack(spacing: 6) {
                Image(systemName: "equal.circle.fill").foregroundStyle(Palette.accent).accessibilityHidden(true)
                TextField(compact ? "12 × 3 + 5%" : L10n.tr("Ifoda yozing: 12 × (3 + 4) − 10% · Enter — nusxalash"), text: $calculator.input)
                    .textFieldStyle(.plain)
                    .font(.system(size: compact ? 12 : 14, design: .monospaced))
                    .focused($focused)
                    .onSubmit(commit)
                    .accessibilityLabel(L10n.tr("Kalkulyator ifodasi"))
            }
            .padding(.horizontal, 8).padding(.vertical, compact ? 5 : 8)
            .background(Palette.softFill, in: RoundedRectangle(cornerRadius: 8))
            resultLine
        }
        .onAppear {
            guard autoFocus else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true }
        }
    }

    @ViewBuilder
    private var resultLine: some View {
        switch calculator.result {
        case .success(let value):
            Button(action: commit) {
                HStack(spacing: 5) {
                    Text(verbatim: "= " + Calculator.format(value, locale: locale))
                        .font(.system(size: compact ? 15 : 22, weight: .semibold).monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .textSelection(.enabled)
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10)).foregroundStyle(copied ? Palette.accent : Palette.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Natijani nusxalash"))
            .accessibilityLabel(L10n.format("Natija: %@. Nusxalash", Calculator.format(value, locale: locale)))
        case .failure(.empty):
            Text(compact ? "" : L10n.tr("+ − × ÷ ^ %, qavslar va pi qo‘llanadi"))
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
        case .failure(let failure):
            Text(Self.message(failure)).font(.system(size: 11)).foregroundStyle(Palette.warning).lineLimit(1)
        }
    }

    static func message(_ failure: Calculator.Failure) -> String {
        switch failure {
        case .empty: ""
        case .invalid: L10n.tr("Ifoda to‘liq emas")
        case .divisionByZero: L10n.tr("Nolga bo‘lib bo‘lmaydi")
        case .overflow: L10n.tr("Natija juda katta")
        case .undefined: L10n.tr("Natija aniqlanmagan")
        }
    }

    private func commit() {
        guard let text = calculator.commit() else { return }
        onCopy(text)
        copied = true
        copiedReset?.cancel()
        copiedReset = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }
}

struct CalculatorWidget: View {
    @ObservedObject var calculator: CalculatorStore
    let size: WidgetSize
    let onCopy: (String) -> Void

    var body: some View {
        WidgetCard(title: "Kalkulyator", icon: "plus.forwardslash.minus", accent: Palette.accent, showHeader: size != .small) {
            VStack(alignment: .leading, spacing: 6) {
                CalculatorField(calculator: calculator, compact: true, onCopy: onCopy)
                if size == .large { CalculatorHistory(calculator: calculator) }
                Spacer(minLength: 0)
            }
        }
    }
}

struct CalculatorHistory: View {
    @ObservedObject var calculator: CalculatorStore
    @Environment(\.locale) private var locale

    var body: some View {
        if !calculator.history.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(calculator.history) { entry in
                    // Bosilsa ifoda maydonga qaytadi.
                    Button { calculator.input = entry.expression } label: {
                        HStack {
                            Text(entry.expression).foregroundStyle(Palette.muted).lineLimit(1)
                            Spacer(minLength: 6)
                            Text(Calculator.format(entry.result, locale: locale)).fontWeight(.medium).lineLimit(1)
                        }
                        .font(.system(size: 11).monospacedDigit())
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.format("%@ = %@. Qayta ishlatish", entry.expression, Calculator.format(entry.result, locale: locale)))
                }
            }
        }
    }
}

// "Asboblar" tabi: chapda kalkulyator va oxirgi hisoblar, o'ngda tarjima.
struct ToolsContent: View {
    @ObservedObject var state: AppState
    @ObservedObject var calculator: CalculatorStore
    @ObservedObject var translator: TranslatorStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            calculatorColumn.frame(maxWidth: .infinity)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Label("Tarjima", systemImage: "character.bubble").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted)
                TranslatorPanel(translator: translator, clipboardText: state.clipboard.items.first?.text,
                                onCopy: { state.clipboard.copyText($0) }, onSetup: { state.showSettings(.translate) })
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
    }

    private var calculatorColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            CalculatorField(calculator: calculator, autoFocus: true, onCopy: { state.clipboard.copyText($0) })
            HStack {
                Text("Oxirgi hisoblar").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted)
                Spacer()
                if !calculator.history.isEmpty {
                    Button("Tozalash") { calculator.clearHistory() }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.danger)
                }
            }
            if calculator.history.isEmpty {
                EmptyHint("Enter bosilgan hisoblar shu yerda turadi. Bosilsa, ifoda qayta maydonga qo‘yiladi.")
            } else {
                CalculatorHistory(calculator: calculator)
            }
            Spacer(minLength: 0)
        }
    }
}
