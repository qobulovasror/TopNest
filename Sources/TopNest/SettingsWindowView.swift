import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, widgets, extensions, music, clipboard, calendar, weather, integrations, about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: L10n.tr("Umumiy")
        case .widgets: L10n.tr("Widgetlar")
        case .extensions: L10n.tr("Extensions")
        case .music: L10n.tr("Musiqa")
        case .clipboard: L10n.tr("Clipboard")
        case .calendar: L10n.tr("Kalendar")
        case .weather: L10n.tr("Ob-havo")
        case .integrations: L10n.tr("Integratsiyalar")
        case .about: L10n.tr("Dastur haqida")
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .widgets: "square.grid.2x2"
        case .extensions: "puzzlepiece.extension"
        case .music: "music.note"
        case .clipboard: "doc.on.clipboard"
        case .calendar: "calendar"
        case .weather: "cloud.sun"
        case .integrations: "square.stack.3d.up"
        case .about: "info.circle"
        }
    }
}

struct SettingsWindowView: View {
    @ObservedObject var state: AppState
    @State private var columns: NavigationSplitViewVisibility = .all

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.5.0"
    }

    var body: some View {
        // Sidebar doim ochiq: yopish tugmasi yo'q, sudrab yopilsa ham darhol qaytariladi.
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $state.settingsPage) {
                Section {
                    ForEach(SettingsPage.allCases) { page in
                        Label(page.title, systemImage: page.symbol)
                            .tag(page)
                    }
                } header: {
                    SidebarHeader()
                }
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 250)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                Text((state.settingsPage ?? .general).title)
                    .font(.largeTitle.weight(.bold))
                    .padding(.horizontal, 28)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                pageContent(state.settingsPage ?? .general)
                    .glassButtonStyle()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: columns) { _, _ in if columns != .all { columns = .all } }
        .frame(minWidth: 720, minHeight: 520)
        .environment(\.locale, state.language.locale)
        .preferredColorScheme(state.appearance.colorScheme)
    }

    @ViewBuilder
    private func pageContent(_ page: SettingsPage) -> some View {
        switch page {
        case .general: generalPage
        case .widgets: WidgetSettingsPage(store: state.widgets, state: state)
        case .extensions: ExtensionSettingsPage(state: state, widgets: state.widgets)
        case .music: musicPage
        case .clipboard: clipboardPage
        case .calendar: CalendarSettingsPage(calendar: state.calendar)
        case .weather: WeatherSettingsPage(weather: state.weather)
        case .integrations: integrationsPage
        case .about: aboutPage
        }
    }

    private var generalPage: some View {
        Form {
            Section("Til va mavzu") {
                Picker("Til", selection: $state.language) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                }
                Picker("Mavzu", selection: $state.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                Text("Tizim ko‘rinishi tanlansa, yorug‘ va qorong‘i rejim macOS bilan birga almashadi.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Notch paneli") {
                Toggle("Kursorni kapsulaga olib borganda ochish", isOn: $state.hoverEnabled)
                Text("Hover bilan ochilgan panel kursor chiqqach yopiladi. Panelni bosib ham ochish mumkin; Esc yoki tashqariga bosish uni yopadi.")
                    .font(.footnote).foregroundStyle(.secondary)
                Toggle("Fullscreen ilovalar ustida yashirish", isOn: $state.hideInFullscreen)
                Toggle("Harakatni kamaytirish", isOn: $state.reduceMotion)
                Text("Panel animatsiyalarini o‘chiradi. macOS’dagi “Reduce motion” yoqilgan bo‘lsa, bu avtomatik qo‘llanadi.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Ko‘rinish") {
                Picker("Yopiq holat shakli", selection: $state.compactStyle) {
                    ForEach(CompactStyle.allCases) { Text($0.title).tag($0) }
                }
                Picker("Ochiq panel uslubi", selection: $state.expandedStyle) {
                    ForEach(ExpandedStyle.allCases) { Text($0.title).tag($0) }
                }
                Picker("Panel o‘lchami", selection: $state.panelSize) {
                    ForEach(PanelSize.allCases) { Text($0.title).tag($0) }
                }
                Text("“Birlashgan” uslubda panel ekran tepasiga botiq burchaklar bilan qo‘shilib ketadi; “Suzuvchi” uslubda ekran chetidan ajralib turadi. Birlashgan va yopishgan uslublar faqat notchli ekranda qo‘llanadi.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Tablar") {
                Picker("Joylashuv", selection: $state.tabPlacement) {
                    ForEach(TabPlacement.allCases) { Text($0.title).tag($0) }
                }
                Picker("Yorliq ko‘rinishi", selection: $state.tabLabelStyle) {
                    ForEach(TabLabelStyle.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Ekran") {
                Toggle("Barcha ekranlarda ko‘rsatish", isOn: $state.showOnAllScreens)
                ScreenPicker(selection: $state.displayUUID)
                    .disabled(state.showOnAllScreens)
                Toggle("Faqat notchli ekranda ko‘rsatish", isOn: $state.onlyNotchScreen)
                Text("Barcha ekranlar yoqilsa, har bir mos ekranda kapsula chiqadi. Bosilgan ekranda panel ochiladi. “Faqat notchli ekranda” tanlovi ham amal qiladi.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Tanlangan ekran uzilsa (masalan, qopqoq yopilganda) avtomatik tanlovga qaytiladi. Notchsiz ekranda panel 220 × 32 kapsula ko‘rinishida bo‘ladi; “Faqat notchli ekran” yoqilsa, u yerda yashiriladi va faqat yorliq yoki menu bar orqali ochiladi.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Klaviatura yorliqlari") {
                Toggle("Global yorliqlar", isOn: $state.hotKeysEnabled)
                LabeledContent("Panelni ochish/yopish", value: "⌃⌥⌘N")
                LabeledContent("Clipboard qidiruvi", value: "⌃⌥⌘V")
                if let message = state.hotKeyMessage {
                    Text(L10n.tr(message)).font(.footnote).foregroundStyle(.orange)
                }
            }
            Section("Live activity") {
                Toggle("Zaryadga ulanganda notch yonida ko‘rsatish", isOn: $state.chargingAlertEnabled)
            }
            Section("Ishga tushish") {
                Toggle("Tizimga kirganda TopNest’ni ochish", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
                if let message = state.launchAtLoginMessage {
                    Text(L10n.tr(message)).font(.footnote).foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var musicPage: some View {
        Form {
            Section("Ijrodagi musiqa") {
                Toggle("Musiqa kuzatuvi", isOn: $state.musicEnabled)
                Text("Standart rejim: Spotify va Apple Music treklari rasmiy AppleScript orqali ko‘rsatiladi va boshqariladi. Birinchi ulanishda macOS Automation ruxsatini so‘rashi mumkin.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Hozir yangilash") { state.refreshMusic() }
                    .disabled(!state.musicEnabled)
            }
            ExtendedMediaSection(state: state, media: state.media)
        }
        .formStyle(.grouped)
    }

    private var clipboardPage: some View {
        Form {
            Section("Matn tarixi") {
                Toggle("Clipboard tarixini saqlash", isOn: $state.clipboardEnabled)
                Text("Tarix faqat ilova xotirasida turadi va TopNest yopilganda o‘chadi. Parol menejerlari belgilagan maxfiy yozuvlar tarixga tushmaydi; barcha maxfiy matnlarni avtomatik aniqlash mumkin emas.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Mahkamlangan yozuvlar (\(state.clipboard.pinned.count)) qayta ishga tushirishda saqlanishi uchun faqat sizning hisobingizda o‘qiladigan faylga yoziladi.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Tarixni tozalash") { state.clipboard.clear() }
                Button("Mahkamlanganlarni o‘chirish") { state.clipboard.clearPinned() }
                    .disabled(state.clipboard.pinned.isEmpty)
            }
        }
        .formStyle(.grouped)
    }

    private var integrationsPage: some View {
        Form {
            Section("Codex") {
                Toggle("Codex limitlarini ko‘rsatish", isOn: $state.codexEnabled)
                Text("O‘rnatilgan Codex CLI orqali limitlarni o‘qiydi. Hisob ma’lumotlari TopNest’da saqlanmaydi.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Limitlarni yangilash") { state.refreshCodex() }
                    .disabled(!state.codexEnabled)
                if let error = state.codexError, state.codexEnabled {
                    Text(L10n.tr(error)).font(.footnote).foregroundStyle(.orange)
                }
            }
            Section("Bildirishnomalar") {
                Toggle(L10n.format("Limit %d%% yoki kam qolganda xabar berish", AppState.lowLimitThreshold), isOn: $state.limitAlertsEnabled)
                Text("Har bir limit davrida bir marta xabar beriladi. Kam qolgan limit bu sozlamadan qat’i nazar notch yonida ko‘rinadi.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Claude Code") {
                Text("Claude Code status line orqali limitlar olinadi. Mavjud status line bo‘lsa, u saqlanadi: TopNest limitlarni o‘qiydi va uning chiqishini o‘zgarishsiz ko‘rsatadi. Uzilganda asl sozlama qaytariladi.")
                    .font(.footnote).foregroundStyle(.secondary)
                HStack {
                    if state.claudeInstalled {
                        Button("Ulanishni uzish") { state.uninstallClaude() }
                        Text("Ulangan").foregroundStyle(.green)
                    } else {
                        Button("Claude Code’ni ulash") { state.installClaude() }
                    }
                }
                if let message = state.claudeMessage {
                    Text(L10n.tr(message)).font(.footnote).foregroundStyle(.orange)
                }
            }
            Section("AI savollari va ruxsat xabarlari") {
                Toggle("Claude Code xabarlarini ko‘rsatish", isOn: Binding(
                    get: { state.permissionHookInstalled },
                    set: { state.setPermissionHook($0) }
                ))
                Toggle("Codex ruxsat xabarlarini ko‘rsatish", isOn: Binding(
                    get: { state.codexHookInstalled },
                    set: { state.setCodexHook($0) }
                ))
                Text("TopNest faqat macOS bildirishnomasini ko‘rsatadi. Savolga javob va ruxsat qarori Claude Code yoki Codex oynasida qabul qilinadi; TopNest ularning ishini to‘xtatmaydi.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Codex hook’ini yoqqach, Codex’da /hooks orqali TopNest hook’ini ko‘rib, ishonchli deb belgilang.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let message = state.permissionMessage {
                    Text(L10n.tr(message)).font(.footnote).foregroundStyle(.orange)
                }
                if let message = state.codexHookMessage {
                    Text(L10n.tr(message)).font(.footnote).foregroundStyle(.orange)
                }
            }
            Section("Boshqa AI vositalari") {
                Text("Hook orqali JSON yubora oladigan lokal AI dasturlari shu buyruqqa ulanishi mumkin. TopNest ularning nomidan javob bermaydi.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let executable = Bundle.main.executableURL?.path {
                    Text("\"\(executable)\" \(ClaudePermissionBridge.genericFlag) \"AI nomi\"")
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var aboutPage: some View {
        Form {
            Section("TopNest") {
                LabeledContent("Versiya", value: Self.appVersion)
                Text("macOS notch uchun native dastur prototipi.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Button("TopNest’dan chiqish", role: .destructive) { NSApp.terminate(nil) }
            }
        }
        .formStyle(.grouped)
    }
}

// Kengaytirilgan musiqa rejimi: nima o'zgarishi va xavfi ochiq tushuntiriladi, yoqish rozilik bilan.
private struct ExtendedMediaSection: View {
    @ObservedObject var state: AppState
    @ObservedObject var media: MediaRemoteService

    var body: some View {
        Section {
            Toggle("Barcha playerlarni ko‘rsatish (kengaytirilgan rejim)", isOn: Binding(
                get: { state.extendedMediaEnabled },
                set: { enabled in
                    if enabled { if confirm() { state.setExtendedMedia(true) } }
                    else { state.setExtendedMedia(false) }
                }
            ))
            .disabled(!state.musicEnabled)
            if state.extendedMediaEnabled { statusRow }
            VStack(alignment: .leading, spacing: 6) {
                Text("Yoqilsa nima o‘zgaradi")
                    .font(.footnote.weight(.semibold))
                Text("• Brauzer (YouTube va boshqalar), Yandex Music, VLC va boshqa istalgan player treki ko‘rinadi.\n• Albom rasmi, aniq progress va progressni bosib o‘tkazish ishlaydi.\n• AppleScript va Automation ruxsati kerak bo‘lmaydi.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Nimani bilishingiz kerak")
                    .font(.footnote.weight(.semibold)).padding(.top, 4)
                Text("• Apple macOS 15.4 dan boshlab “Hozir ijroda” ma’lumotini (MediaRemote) uchinchi tomon ilovalariga yopgan. Bu rejim cheklovni chetlab o‘tadi: TopNest’ning kichik yordamchisi tizimdagi /usr/bin/perl ichida ishga tushadi va ma’lumotni shu yo‘l bilan oladi.\n• Bu Apple’ning rasmiy yo‘li emas: macOS yangilanganda ishlamay qolishi mumkin. Unda TopNest avtomatik ravishda standart rejimga qaytadi.\n• Ma’lumot faqat kompyuteringizda qoladi, hech qayerga yuborilmaydi. Rejimni istalgan vaqtda shu yerda o‘chirishingiz mumkin.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("Kengaytirilgan rejim")
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch media.status {
        case .active:
            Label("Ishlayapti" + (state.track.map { " · \($0.source)" } ?? ""), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .starting:
            Label("Ishga tushmoqda…", systemImage: "hourglass").foregroundStyle(.secondary)
        case .failed:
            Label("Bu macOS versiyasida ishlamadi — standart rejim ishlatilmoqda", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .off:
            EmptyView()
        }
    }

    private func confirm() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.tr("Kengaytirilgan musiqa rejimini yoqasizmi?")
        alert.informativeText = L10n.tr("Bu rejim Apple macOS 15.4 dan beri uchinchi tomon ilovalariga yopgan “Hozir ijroda” ma’lumotini tizimdagi /usr/bin/perl orqali oladi. Bu Apple’ning rasmiy yo‘li emas va macOS yangilanganda ishlamay qolishi mumkin (unda TopNest standart rejimga qaytadi). Ma’lumot kompyuteringizdan chiqmaydi. Rejimni istalgan vaqtda sozlamalarda o‘chirish mumkin.")
        alert.addButton(withTitle: L10n.tr("Bekor qilish"))
        alert.addButton(withTitle: L10n.tr("Roziman, yoqish"))
        return alert.runModal() == .alertSecondButtonReturn
    }
}

private struct SidebarHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("TopNest").font(.headline).foregroundStyle(.primary)
                Text("v\(SettingsWindowView.appVersion)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .textCase(nil)
    }
}

private struct ScreenPicker: View {
    @Binding var selection: String
    @State private var screens: [(uuid: String, name: String)] = []

    var body: some View {
        Picker("Panel ko‘rinadigan ekran", selection: $selection) {
            Text("Avtomatik (notchli ekran)").tag("")
            ForEach(screens, id: \.uuid) { screen in
                Text(screen.name).tag(screen.uuid)
            }
            if !selection.isEmpty && !screens.contains(where: { $0.uuid == selection }) {
                Text("Tanlangan ekran (ulanmagan)").tag(selection)
            }
        }
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in reload() }
    }

    private func reload() {
        screens = NSScreen.screens.compactMap { screen in screen.displayUUID.map { ($0, screen.localizedName) } }
    }
}

private struct CalendarSettingsPage: View {
    @ObservedObject var calendar: CalendarService

    var body: some View {
        Form {
            if calendar.accessGranted {
                Section("Ko‘rsatiladigan kalendarlar") {
                    if calendar.sources.isEmpty {
                        Text("Kalendar topilmadi.").foregroundStyle(.secondary)
                    }
                    ForEach(calendar.sources) { source in
                        Toggle(isOn: Binding(
                            get: { !calendar.excludedIDs.contains(source.id) },
                            set: { calendar.setIncluded($0, calendarID: source.id) }
                        )) {
                            Label {
                                Text(source.title)
                            } icon: {
                                Circle().fill(Color(nsColor: source.color)).frame(width: 9, height: 9)
                            }
                        }
                    }
                }
                Section {
                    Text("Uchrashuvdan 5 daqiqa oldin notch yonida ogohlantirish chiqadi. Zoom, Google Meet, Teams, Webex havolalari tadbir izohi yoki joyidan topilib, “Qo‘shilish” tugmasi ko‘rsatiladi.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Section("Ruxsat") {
                    Text("Yaqinlashayotgan uchrashuvlarni ko‘rsatish uchun kalendarga ruxsat kerak.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Ruxsat berish") { calendar.requestAccess() }
                    if let error = calendar.errorMessage {
                        Text(L10n.tr(error)).font(.footnote).foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { calendar.refresh() }
    }
}

private struct WeatherSettingsPage: View {
    @ObservedObject var weather: WeatherService

    var body: some View {
        Form {
            Section("Shahar") {
                HStack {
                    TextField("Masalan: Toshkent", text: $weather.city)
                        .onSubmit { save() }
                    Button("Saqlash") { save() }
                }
                if let error = weather.errorMessage {
                    Text(L10n.tr(error)).font(.footnote).foregroundStyle(.orange)
                }
                Text("Shahar nomi ob-havo ma’lumoti uchun Open-Meteo xizmatiga yuboriladi.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func save() {
        Task { await weather.refresh(saveCity: true) }
    }
}
