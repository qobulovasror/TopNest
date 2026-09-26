import AppKit
import SwiftUI

private enum Palette {
    static let background = Color(red: 0.055, green: 0.069, blue: 0.095)
    static let card = Color(red: 0.105, green: 0.125, blue: 0.165)
    static let accent = Color(red: 0.43, green: 0.91, blue: 0.78)
    static let muted = Color(red: 0.62, green: 0.67, blue: 0.75)
    static let warning = Color(red: 0.98, green: 0.78, blue: 0.3)
    static let danger = Color(red: 1.0, green: 0.42, blue: 0.4)

    static func level(_ remaining: Int) -> Color {
        remaining > 50 ? accent : (remaining > AppState.lowLimitThreshold ? warning : danger)
    }
}

struct RootView: View {
    @ObservedObject var state: AppState
    @State private var dropTargeted = false

    var body: some View {
        Group {
            if state.expanded { expandedBody.transition(.opacity) }
            else { compactBody.transition(.opacity) }
        }
        .animation(state.motionReduced ? nil : .easeOut(duration: 0.18), value: state.expanded)
        .background(state.expanded ? Palette.background : .black)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: state.expanded ? 24 : 0,
            bottomLeadingRadius: state.expanded ? 24 : 10,
            bottomTrailingRadius: state.expanded ? 24 : 10,
            topTrailingRadius: state.expanded ? 24 : 0
        ))
        .overlay {
            if state.expanded {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.13), lineWidth: 1)
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var compactBody: some View {
        Button { state.requestExpand() } label: {
            Group {
                if let notch = state.notchWidth { notchCompact(notch) }
                else { pillCompact }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { state.handleCompactHover($0) }
        // Fayl notchga sudralganda tokcha ochiladi.
        .onDrop(of: [.fileURL], isTargeted: Binding(get: { false }, set: { if $0 { state.openShelfForDrop() } })) { providers in
            state.shelf.accept(providers)
        }
        .accessibilityLabel("TopNest panelini ochish")
        .accessibilityValue(activityDescription)
    }

    private var activityDescription: String {
        switch state.displayedActivity {
        case .charging(let percent): "Zaryadlanmoqda: \(percent)%"
        case .meeting(let minutes): minutes == 0 ? "Uchrashuv boshlanmoqda" : "Uchrashuv \(minutes) daqiqadan keyin"
        case .music: state.track.map { "Ijroda: \($0.title)" } ?? ""
        case .limit(let remaining): "AI limiti: \(remaining)% qoldi"
        case .idle: ""
        }
    }

    // Notch markazida piksel yo'q, shuning uchun kontent faqat yon qanotlarda.
    private func notchCompact(_ notch: CGFloat) -> some View {
        HStack(spacing: 0) {
            if state.displayedActivity != .idle {
                leftWing.frame(width: AppState.wingWidth)
            }
            Color.clear.frame(width: notch)
            if state.displayedActivity != .idle {
                rightWing.frame(width: AppState.wingWidth)
            }
        }
    }

    @ViewBuilder
    private var leftWing: some View {
        switch state.displayedActivity {
        case .charging:
            Image(systemName: "bolt.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(.green)
        case .meeting:
            Image(systemName: "calendar").font(.system(size: 13, weight: .semibold)).foregroundStyle(.orange)
        case .music:
            ArtworkView(url: state.track?.artworkURL, cornerRadius: 5)
                .frame(width: 20, height: 20)
        case .limit:
            Image(systemName: "sparkle").font(.system(size: 13, weight: .semibold)).foregroundStyle(.purple)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var rightWing: some View {
        switch state.displayedActivity {
        case .charging(let percent):
            Text("\(percent)%").font(.system(size: 11, weight: .bold)).foregroundStyle(.green)
        case .meeting(let minutes):
            Text(minutes == 0 ? "hozir" : "\(minutes) daq")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
                .lineLimit(1).minimumScaleFactor(0.8)
        case .music:
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .symbolEffect(.variableColor.iterative, isActive: state.track?.playing == true && !state.motionReduced)
        case .limit(let remaining):
            Text("\(remaining)%")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.level(remaining))
        case .idle:
            EmptyView()
        }
    }

    private var pillCompact: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(Palette.accent).frame(width: 5, height: 5)
                if let track = state.track {
                    Text(track.title).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 0)
                    Image(systemName: track.playing ? "waveform" : "play.fill")
                        .foregroundStyle(Palette.accent)
                } else {
                    Text("TopNest").fontWeight(.semibold)
                    Spacer()
                    TimelineView(.everyMinute) { context in
                        Text(context.date, format: .dateTime.hour().minute()).foregroundStyle(Palette.muted)
                    }
                }
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 12).frame(maxWidth: .infinity, maxHeight: .infinity)
            if let track = state.track, track.playing, track.duration > 0 {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    GeometryReader { geo in
                        Rectangle().fill(Palette.accent.opacity(0.75))
                            .frame(width: geo.size.width * track.progress)
                    }.frame(height: 2)
                }
            }
        }
    }

    private var expandedBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7).fill(Palette.accent)
                        Image(systemName: "square.stack.3d.up.fill").font(.system(size: 12)).foregroundStyle(Palette.background)
                    }.frame(width: 24, height: 24)
                    Text("TopNest").font(.system(size: 15, weight: .bold))
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Spacer()
                TimelineView(.everyMinute) { context in
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                HeaderButton(icon: "gearshape.fill", label: "Sozlamalarni ochish") { state.showSettings() }
                HeaderButton(icon: "xmark", label: "Yopish") { state.onCollapse?() }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)

            HStack(spacing: 4) {
                ForEach(AppState.Tab.allCases, id: \.self) { tab in
                    Button { state.selectedTab = tab } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: state.selectedTab == tab ? .semibold : .medium))
                            .foregroundStyle(state.selectedTab == tab ? Palette.background : Palette.muted)
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(state.selectedTab == tab ? Palette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(state.selectedTab == tab ? .isSelected : [])
                }
            }
            .padding(3).background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 11))
            .padding(.horizontal, 16).padding(.bottom, 12)

            Group {
                switch state.selectedTab {
                case .home: HomeContent(state: state, clipboard: state.clipboard, calendar: state.calendar, weather: state.weather)
                case .clips: ClipboardContent(state: state, clipboard: state.clipboard)
                case .shelf: ShelfContent(shelf: state.shelf, dropTargeted: dropTargeted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            state.selectedTab = .shelf
            return state.shelf.accept(providers)
        }
    }
}

private struct HeaderButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
                .frame(width: 26, height: 26).background(.white.opacity(0.08), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct HomeContent: View {
    @ObservedObject var state: AppState
    @ObservedObject var clipboard: ClipboardService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var weather: WeatherService

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if state.isCardVisible(.music) { musicCard }
                let showCalendar = state.isCardVisible(.calendar)
                let showWeather = state.isCardVisible(.weather)
                if showCalendar || showWeather {
                    HStack(alignment: .top, spacing: 8) {
                        if showCalendar { calendarCard }
                        if showWeather { weatherCard.frame(maxWidth: showCalendar ? 150 : .infinity) }
                    }
                }
                if state.isCardVisible(.clipboard) { clipboardCard }
                if state.isCardVisible(.limits) { limitsCard }
                if HomeCard.allCases.allSatisfy({ !state.isCardVisible($0) }) {
                    VStack(spacing: 8) {
                        EmptyHint("Barcha kartalar yashirilgan.")
                        SmallAction("Kartalarni tanlash") { state.showSettings(.general) }
                    }.padding(.top, 40)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    private var musicCard: some View {
        PanelCard(title: "Hozir ijroda", icon: "music.note", accent: .pink) {
            if !state.musicEnabled {
                HStack {
                    EmptyHint("Musiqa kuzatuvi o‘chiq.")
                    Spacer()
                    SmallAction("Yoqish") { state.musicEnabled = true }
                }
            } else if let track = state.track {
                VStack(spacing: 9) {
                    HStack(spacing: 11) {
                        ArtworkView(url: track.artworkURL)
                            .frame(width: 48, height: 48)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                            Text(track.artist).font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(1)
                            Text("\(track.source) · \(track.playing ? "Ijroda" : "Pauza")")
                                .font(.system(size: 11)).foregroundStyle(Palette.accent)
                        }
                        .accessibilityElement(children: .combine)
                        Spacer(minLength: 0)
                        HStack(spacing: 10) {
                            control("backward.end.fill", "previous track", label: "Oldingi trek")
                            control(track.playing ? "pause.fill" : "play.fill", "playpause", label: track.playing ? "Pauza" : "Ijro etish", primary: true)
                            control("forward.end.fill", "next track", label: "Keyingi trek")
                        }
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let elapsed = track.position + (track.playing ? Date().timeIntervalSince(track.observedAt) : 0)
                        VStack(spacing: 4) {
                            ProgressBar(value: track.progress, color: Palette.accent, height: 4)
                            HStack {
                                Text(musicTime(elapsed))
                                Spacer()
                                Text(musicTime(track.duration))
                            }.font(.system(size: 11).monospacedDigit()).foregroundStyle(Palette.muted)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Ijro holati")
                        .accessibilityValue("\(musicTime(elapsed)) / \(musicTime(track.duration))")
                    }
                }
            } else {
                EmptyHint("Spotify yoki Music’da trek ijro etilganda shu yerda chiqadi.")
            }
        }
    }

    private var calendarCard: some View {
        PanelCard(title: "Kalendar", icon: "calendar", accent: .orange) {
            if !calendar.events.isEmpty {
                TimelineView(.everyMinute) { context in
                    let current = calendar.events.filter { $0.end > context.date }
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(current.prefix(3)) { event in
                            eventRow(event, now: context.date)
                        }
                        if current.isEmpty { EmptyHint("Yaqinlashayotgan uchrashuv yo‘q.") }
                    }
                }
            } else if calendar.accessGranted {
                EmptyHint("Yaqinlashayotgan uchrashuv yo‘q.")
            } else {
                SmallAction("Ruxsat berish") { calendar.requestAccess() }
                if let error = calendar.errorMessage { EmptyHint(error) }
            }
        }
    }

    private func eventRow(_ event: CalendarItem, now: Date) -> some View {
        let minutes = event.minutesUntilStart(from: now)
        let soon = minutes <= 15 && event.end > now
        return VStack(alignment: .leading, spacing: 2) {
            Text(event.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            HStack(spacing: 6) {
                Group {
                    if event.start <= now { Text("Hozir davom etmoqda") }
                    else if soon { Text("\(minutes) daqiqadan keyin") }
                    else { Text(event.start, format: .dateTime.weekday(.abbreviated).hour().minute()) }
                }
                .font(.system(size: 11)).foregroundStyle(soon || event.start <= now ? .orange : Palette.muted)
                .lineLimit(1).minimumScaleFactor(0.85)
                if let link = event.link {
                    SmallAction(event.meetingURL != nil ? "Qo‘shilish" : "Havola") { NSWorkspace.shared.open(link) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weatherCard: some View {
        PanelCard(title: "Ob-havo", icon: "cloud.sun.fill", accent: .cyan) {
            if let info = weather.weather {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: info.symbol).foregroundStyle(.cyan).accessibilityHidden(true)
                    Text("\(Int(info.temperature.rounded()))°").font(.system(size: 20, weight: .semibold))
                }
                Text(info.city).font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(1)
                if Date().timeIntervalSince(info.updatedAt) > 3600 {
                    Text("Ma’lumot eskirgan").font(.system(size: 11)).foregroundStyle(.orange)
                }
            } else {
                SmallAction("Shahar tanlash") { state.showSettings(.weather) }
            }
        }
    }

    private var clipboardCard: some View {
        PanelCard(title: "Clipboard", icon: "doc.on.clipboard", accent: Palette.accent) {
            if !state.clipboardEnabled {
                HStack {
                    EmptyHint("Tarix hozir o‘chiq.")
                    Spacer()
                    SmallAction("Yoqish") { state.clipboardEnabled = true }
                }
            } else if let item = clipboard.items.first {
                HStack(spacing: 8) {
                    Text(item.text.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 12)).lineLimit(1).foregroundStyle(Palette.muted)
                    Spacer()
                    SmallAction("Ko‘rish") { state.selectedTab = .clips }
                }
            } else { EmptyHint("Nusxalangan matn shu yerda paydo bo‘ladi.") }
        }
    }

    private var limitsCard: some View {
        PanelCard(title: "AI limitlari", icon: "sparkle", accent: .purple) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(spacing: 10) {
                    UsageRow(name: "Codex", snapshot: state.codexUsage, now: context.date, primaryLabel: "Asosiy", secondaryLabel: "Qo‘shimcha", fallback: state.codexEnabled ? (state.codexError ?? "Yuklanmoqda…") : "Sozlamalarda o‘chirilgan")
                    Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                    UsageRow(name: "Claude", snapshot: state.claudeUsage, now: context.date, primaryLabel: "5 soat", secondaryLabel: "7 kun", fallback: state.claudeInstalled ? "Claude Code ishlatilgach yangilanadi" : "Sozlamalardan ulash mumkin")
                }
            }
        }
    }

    private func control(_ icon: String, _ action: String, label: String, primary: Bool = false) -> some View {
        Button { state.controlMusic(action) } label: {
            Image(systemName: icon).font(.system(size: primary ? 13 : 11, weight: .semibold))
                .frame(width: primary ? 32 : 26, height: primary ? 32 : 26)
                .background(primary ? Palette.accent : .white.opacity(0.08), in: Circle())
                .foregroundStyle(primary ? Palette.background : .white)
                .contentShape(Circle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }

    private func musicTime(_ seconds: Double) -> String {
        let value = max(0, Int(seconds))
        return "\(value / 60):\(String(format: "%02d", value % 60))"
    }
}

private struct ArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = 10

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            RoundedRectangle(cornerRadius: cornerRadius).fill(.pink.opacity(0.18))
                .overlay(Image(systemName: "music.note").foregroundStyle(.pink))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

private struct ShelfContent: View {
    @ObservedObject var shelf: ShelfService
    let dropTargeted: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Tokcha · \(shelf.items.count)/\(ShelfService.limit)")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                Spacer()
                if !shelf.items.isEmpty {
                    Button("AirDrop") { shelf.airDrop(shelf.items) }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.accent)
                    Button("Tozalash") { shelf.clear() }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.danger)
                }
            }
            if shelf.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 26)).foregroundStyle(dropTargeted ? Palette.accent : Palette.muted)
                    Text("Fayllarni shu yerga yoki notchga sudrab tashlang").font(.system(size: 13, weight: .semibold))
                    Text("Fayllar ko‘chirilmaydi — tokcha ularga havolani eslab qoladi. Keyin ularni istalgan ilovaga sudrab olib o‘tish yoki AirDrop qilish mumkin.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])).foregroundStyle(dropTargeted ? Palette.accent : .white.opacity(0.2)))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                        ForEach(shelf.items) { item in
                            VStack(spacing: 5) {
                                Image(nsImage: shelf.icon(for: item)).resizable().scaledToFit().frame(width: 40, height: 40)
                                Text(item.name).font(.system(size: 11)).lineLimit(2).multilineTextAlignment(.center)
                            }
                            .padding(8).frame(maxWidth: .infinity, minHeight: 92)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                            .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
                            .onTapGesture(count: 2) { shelf.open(item) }
                            .contextMenu {
                                Button("Ochish") { shelf.open(item) }
                                Button("Finder’da ko‘rsatish") { shelf.reveal([item]) }
                                Button("AirDrop") { shelf.airDrop([item]) }
                                Divider()
                                Button("Tokchadan olib tashlash") { shelf.remove(item) }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityHint("Ikki marta bosib oching, sudrab boshqa ilovaga olib o‘ting")
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.accent, lineWidth: dropTargeted ? 1.5 : 0))
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 16)
    }
}

private struct ClipboardContent: View {
    @ObservedObject var state: AppState
    @ObservedObject var clipboard: ClipboardService
    @State private var query = ""
    @State private var handledSearchRequest = 0
    @FocusState private var searchFocused: Bool

    private func matches(_ list: [ClipItem]) -> [ClipItem] {
        query.isEmpty ? list : list.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    private var filtered: [ClipItem] { matches(clipboard.pinned) + matches(clipboard.items) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted).accessibilityHidden(true)
                TextField("Matndan qidirish · Enter — birinchisini nusxalash", text: $query)
                    .textFieldStyle(.plain).font(.system(size: 13))
                    .focused($searchFocused)
                    .onSubmit {
                        guard state.clipboardEnabled, let first = filtered.first else { return }
                        clipboard.copy(first)
                        state.onCollapse?()
                    }
            }
            .padding(10).background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Text("Xotirada \(clipboard.items.count)/\(ClipboardService.limit)" + (clipboard.pinned.isEmpty ? "" : " · \(clipboard.pinned.count) mahkamlangan (diskda)"))
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                Spacer()
                Button("Tozalash") { clipboard.clear() }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.danger)
                    .disabled(clipboard.items.isEmpty)
            }
            if !state.clipboardEnabled {
                Spacer()
                Text("Clipboard tarixi o‘chiq").font(.system(size: 14, weight: .semibold))
                Text("Yoqilgach, yangi nusxalangan matnlar faqat ilova xotirasida saqlanadi.")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                Button("Tarixni yoqish") { state.clipboardEnabled = true }
                    .buttonStyle(.borderedProminent).tint(Palette.accent)
                Spacer()
            } else if filtered.isEmpty {
                Spacer()
                EmptyHint(query.isEmpty ? "Nusxalangan matn shu yerda paydo bo‘ladi." : "Hech narsa topilmadi.")
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filtered) { item in
                            HStack(spacing: 6) {
                                Button { clipboard.copy(item) } label: {
                                    HStack {
                                        if clipboard.isPinned(item) {
                                            Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(.orange)
                                                .accessibilityLabel("Mahkamlangan")
                                        }
                                        Text(item.text).lineLimit(3).multilineTextAlignment(.leading)
                                            .font(.system(size: 12))
                                        Spacer()
                                        Image(systemName: "doc.on.doc").foregroundStyle(Palette.accent)
                                    }
                                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Nusxalash: \(item.text.prefix(80))")
                                Button { clipboard.togglePin(item) } label: {
                                    Image(systemName: clipboard.isPinned(item) ? "pin.slash" : "pin").font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Palette.muted).frame(width: 22, height: 26)
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel(clipboard.isPinned(item) ? "Mahkamlashni bekor qilish" : "Mahkamlash")
                                Button { clipboard.remove(item) } label: {
                                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Palette.muted).frame(width: 26, height: 26)
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel("Yozuvni o‘chirish")
                            }
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }.scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 16)
        .onAppear { focusSearchIfRequested() }
        .onChange(of: state.clipboardSearchRequest) { focusSearchIfRequested() }
    }

    // Har bir hotkey so'rovi faqat bir marta fokus beradi.
    private func focusSearchIfRequested() {
        guard state.clipboardSearchRequest != handledSearchRequest else { return }
        handledSearchRequest = state.clipboardSearchRequest
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { searchFocused = true }
    }
}

private struct PanelCard<Content: View>: View {
    let title: String
    let icon: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(accent).accessibilityHidden(true)
                Text(title).foregroundStyle(.white.opacity(0.9))
            }
            .font(.system(size: 12, weight: .semibold))
            .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProgressBar: View {
    let value: Double
    let color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1))
                Capsule().fill(color).frame(width: geo.size.width * min(1, max(0, value)))
            }
        }.frame(height: height)
    }
}

private struct EmptyHint: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true) }
}

private struct SmallAction: View {
    let text: String
    let action: () -> Void
    init(_ text: String, action: @escaping () -> Void) { self.text = text; self.action = action }
    var body: some View {
        Button(action: action) { Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.accent) }
            .buttonStyle(.plain)
    }
}

private struct UsageRow: View {
    let name: String
    let snapshot: UsageSnapshot?
    let now: Date
    let primaryLabel: String
    let secondaryLabel: String
    let fallback: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.system(size: 12, weight: .semibold))
                Spacer()
                if let snapshot {
                    Text("yangilangan \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundStyle(snapshot.isStale(at: now) ? .orange : Palette.muted)
                }
            }
            if let snapshot {
                if let primary = snapshot.primary { meter(primaryLabel, window: primary, stale: snapshot.isStale(at: now)) }
                if let secondary = snapshot.secondary { meter(secondaryLabel, window: secondary, stale: snapshot.isStale(at: now)) }
                if snapshot.primary == nil && snapshot.secondary == nil { EmptyHint("Limit ma’lumoti mavjud emas") }
            } else { EmptyHint(fallback) }
        }
    }

    private func meter(_ label: String, window: UsageWindow, stale: Bool) -> some View {
        let reset = window.hasReset(at: now)
        let remaining = window.remainingPercent
        let color = reset ? Palette.muted : Palette.level(remaining)
        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(label).foregroundStyle(Palette.muted)
                Spacer()
                if reset {
                    Text("Tiklangan").foregroundStyle(Palette.muted)
                } else {
                    Text("\(remaining)% qoldi").fontWeight(.semibold).foregroundStyle(color)
                    if let resetAt = window.resetAt {
                        Text("· \(countdown(to: resetAt))").foregroundStyle(Palette.muted)
                    }
                }
            }
            .font(.system(size: 11).monospacedDigit())
            ProgressBar(value: reset ? 1 : Double(remaining) / 100, color: color.opacity(stale && !reset ? 0.55 : 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(label)")
        .accessibilityValue(reset ? "Tiklangan" : "\(remaining)% qoldi" + (window.resetAt.map { ", \(countdown(to: $0)) keyin tiklanadi" } ?? ""))
    }

    private func countdown(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let days = seconds / 86_400, hours = (seconds % 86_400) / 3600, minutes = (seconds % 3600) / 60
        if days > 0 { return "\(days) kun \(hours) soat" }
        if hours > 0 { return "\(hours) soat \(minutes) daq" }
        return "\(max(1, minutes)) daq"
    }
}
