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

    var body: some View {
        NavigationSplitView {
            List(selection: $state.settingsPage) {
                ForEach(SettingsPage.allCases) { page in
                    Label(page.title, systemImage: page.symbol)
                        .tag(page)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 240)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                Text((state.settingsPage ?? .general).title)
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 25)
                    .padding(.top, 23)
                    .padding(.bottom, 17)
                Divider()
                pageContent(state.settingsPage ?? .general)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 700, minHeight: 500)
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
                Text("Tarix faqat ilova xotirasida turadi va TopNest yopilganda o‘chadi. Parol menejerlarining ayrimlari istisno qilinadi; barcha maxfiy matnlarni avtomatik aniqlash mumkin emas.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Tarixni tozalash") { state.clipboard.clear() }
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
                Text("Claude Code status line orqali limitlar olinadi. Mavjud status line sozlamasi bo‘lsa, TopNest uni almashtirmaydi.")
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
        }
        .formStyle(.grouped)
    }

    private var aboutPage: some View {
        Form {
            Section("TopNest") {
                LabeledContent("Versiya", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0")
                Text("macOS notch uchun native dastur prototipi.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Button("TopNest’dan chiqish") { NSApp.terminate(nil) }
            }
        }
        .formStyle(.grouped)
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
