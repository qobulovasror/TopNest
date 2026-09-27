import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, music, clipboard, calendar, weather, integrations, about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "Umumiy"
        case .music: "Musiqa"
        case .clipboard: "Clipboard"
        case .calendar: "Kalendar"
        case .weather: "Ob-havo"
        case .integrations: "Integratsiyalar"
        case .about: "Dastur haqida"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.4.0"
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
    }

    @ViewBuilder
    private func pageContent(_ page: SettingsPage) -> some View {
        switch page {
        case .general: generalPage
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
                ScreenPicker(selection: $state.displayUUID)
                Toggle("Faqat notchli ekranda ko‘rsatish", isOn: $state.onlyNotchScreen)
                Text("Tanlangan ekran uzilsa (masalan, qopqoq yopilganda) avtomatik tanlovga qaytiladi. Notchsiz ekranda panel 220 × 32 kapsula ko‘rinishida bo‘ladi; “Faqat notchli ekran” yoqilsa, u yerda yashiriladi va faqat yorliq yoki menu bar orqali ochiladi.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Klaviatura yorliqlari") {
                Toggle("Global yorliqlar", isOn: $state.hotKeysEnabled)
                LabeledContent("Panelni ochish/yopish", value: "⌃⌥⌘N")
                LabeledContent("Clipboard qidiruvi", value: "⌃⌥⌘V")
                if let message = state.hotKeyMessage {
                    Text(message).font(.footnote).foregroundStyle(.orange)
                }
            }
            Section("Live activity") {
                Toggle("Zaryadga ulanganda notch yonida ko‘rsatish", isOn: $state.chargingAlertEnabled)
            }
            Section("Asosiy panel kartalari") {
                ForEach(HomeCard.allCases) { card in
                    Toggle(card.title, isOn: Binding(
                        get: { state.isCardVisible(card) },
                        set: { state.setCard(card, visible: $0) }
                    ))
                }
            }
            Section("Ishga tushish") {
                Toggle("Tizimga kirganda TopNest’ni ochish", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
                if let message = state.launchAtLoginMessage {
                    Text(message).font(.footnote).foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var musicPage: some View {
        Form {
            Section("Ijrodagi musiqa") {
                Toggle("Musiqa kuzatuvi", isOn: $state.musicEnabled)
                Text("Spotify va Apple Music treklarini ko‘rsatadi va boshqaradi. Birinchi ulanishda macOS Automation ruxsatini so‘rashi mumkin.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Hozir yangilash") { state.refreshMusic() }
                    .disabled(!state.musicEnabled)
            }
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
                    Text(error).font(.footnote).foregroundStyle(.orange)
                }
            }
            Section("Bildirishnomalar") {
                Toggle("Limit \(AppState.lowLimitThreshold)% yoki kam qolganda xabar berish", isOn: $state.limitAlertsEnabled)
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
                    Text(message).font(.footnote).foregroundStyle(.orange)
                }
            }
            Section("Claude Code ruxsatlari") {
                Toggle("Ruxsat so‘rovlarini notchda ko‘rsatish", isOn: Binding(
                    get: { state.permissionHookInstalled },
                    set: { state.setPermissionHook($0) }
                ))
                Text("Claude Code amal uchun ruxsat so‘raganda panel ochiladi va “Ruxsat berish” yoki “Rad etish” mumkin. TopNest yopiq bo‘lsa yoki \(ClaudePermissionBridge.waitSeconds) soniyada javob berilmasa, Claude o‘z oynasida odatdagidek so‘raydi.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("“Ruxsat berish” Claude’ga shu amalni bajarishga imkon beradi. Buyruq matnini diqqat bilan o‘qing.")
                    .font(.footnote).foregroundStyle(.orange)
                if let message = state.permissionMessage {
                    Text(message).font(.footnote).foregroundStyle(.orange)
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
                        Text(error).font(.footnote).foregroundStyle(.orange)
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
                    Text(error).font(.footnote).foregroundStyle(.orange)
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
