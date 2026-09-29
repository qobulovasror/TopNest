import AppKit
import SwiftUI

// Asosiy ekran: widgetlar 2 qatorli gridga ustunma-ustun joylashadi, vertikal scroll yo'q.
// 4 ustundan ko'pi gorizontal siljiydi (ustunga yopishadi). Yashirin widget joy egallamaydi,
// sozlash kerak bo'lgani esa kichik karta sifatida tushuntirish va tugma bilan ko'rinadi.
struct HomeContent: View {
    @ObservedObject var state: AppState
    @ObservedObject var widgets: WidgetStore
    @ObservedObject var clipboard: ClipboardService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var weather: WeatherService
    @State private var firstColumn: Int? = 0

    static let rows = 2
    static let visibleColumns = 4
    static let spacing: CGFloat = 8
    static let welcomeID = UUID(uuidString: "00000000-0000-0000-0000-00000000E1C0")!

    var body: some View {
        // Har daqiqa qayta hisoblanadi: tugagan uchrashuv widgeti o'z-o'zidan yashiriladi.
        TimelineView(.everyMinute) { context in
            content(now: context.date).padding(.horizontal, 16)
        }
        .onChange(of: widgets.widgets.map(\.id)) { _, ids in state.customRunners.prune(keeping: Set(ids)) }
    }

    private struct Entry {
        let widget: WidgetConfig
        let state: WidgetState
        let size: WidgetSize
    }

    private func entries(now: Date) -> [UUID: Entry] {
        let context = state.widgetContext(now: now)
        var result: [UUID: Entry] = [:]
        for widget in widgets.widgets {
            let widgetState = WidgetRules.state(for: widget, in: context)
            guard widgetState.isVisible else { continue }
            // Sozlash kartasi doim kichik: asosiy ekran ixcham qoladi.
            let size: WidgetSize = if case .needsSetup = widgetState { .small } else { widget.size }
            result[widget.id] = Entry(widget: widget, state: widgetState, size: size)
        }
        return result
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let visible = entries(now: now)
        let order = widgets.widgets.map(\.id).filter { visible[$0] != nil }
        let showWelcome = !state.hasSeenWelcome
        let items: [WidgetGridItem] = (showWelcome ? [WidgetGridItem(id: Self.welcomeID, size: .large)] : [])
            + order.compactMap { id in visible[id].map { WidgetGridItem(id: id, size: $0.size) } }
        if items.isEmpty {
            emptyState
        } else {
            WidgetGrid(layout: WidgetLayout.pack(items, rows: Self.rows), firstColumn: $firstColumn,
                       motionReduced: state.motionReduced) { id in
                item(id, entries: visible)
            }
        }
    }

    @ViewBuilder
    private func item(_ id: UUID, entries: [UUID: Entry]) -> some View {
        if id == Self.welcomeID {
            WelcomeCard(onSettings: { state.showSettings(.widgets) }, onDismiss: { state.dismissWelcome() })
        } else if let entry = entries[id] {
            let widget = entry.widget
            switch entry.state {
            case .needsSetup(let reason, let action):
                SetupCard(title: widget.title, icon: widget.icon, reason: reason, actionTitle: action.title,
                          onAction: { state.perform(action) })
            default:
                WidgetView(state: state, widget: widget, clipboard: clipboard, calendar: calendar, weather: weather)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2").font(.system(size: 22)).foregroundStyle(Palette.muted)
            Text("Hozircha ko‘rsatiladigan ma’lumot yo‘q").font(.system(size: 13, weight: .semibold))
            Text("Widgetlar ma’lumot paydo bo‘lganda chiqadi. Qaysi widget nega yashirinligini sozlamalarda ko‘rish mumkin.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            SmallAction("Widgetlarni sozlash") { state.showSettings(.widgets) }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Grid chizish: asosiy ekran, sozlamalardagi preview va rasm testlari bir xil kodni ishlatadi.
struct WidgetGrid<Cell: View>: View {
    let layout: GridLayoutResult
    @Binding var firstColumn: Int?
    var motionReduced = false
    var rows = HomeContent.rows
    var visibleColumns = HomeContent.visibleColumns
    var spacing = HomeContent.spacing
    // Rasm testlarida ImageRenderer ScrollView'ni chizmaydi: birinchi ustunlar statik ko'rsatiladi.
    var allowsScrolling = true
    @ViewBuilder let cell: (UUID) -> Cell

    var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
        }
    }

    private func content(size: CGSize) -> some View {
        let displayColumns = WidgetLayout.displayColumns(for: layout.columnCount, visible: visibleColumns)
        let cellWidth = (size.width - spacing * CGFloat(displayColumns - 1)) / CGFloat(displayColumns)
        let cellHeight = (size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
        let contentWidth = CGFloat(layout.columnCount) * cellWidth + spacing * CGFloat(max(0, layout.columnCount - 1))
        let scrollable = layout.columnCount > displayColumns
        let maxFirst = max(0, layout.columnCount - displayColumns)
        let cells = ZStack(alignment: .topLeading) {
            // Ko'rinmas ustunlar siljishni ustunga "yopishtiradi".
            HStack(spacing: spacing) {
                ForEach(0..<layout.columnCount, id: \.self) { column in
                    Color.clear.frame(width: cellWidth, height: 1).id(column)
                }
            }
            .scrollTargetLayout()
            ForEach(layout.placements) { placement in
                cell(placement.id)
                    .frame(width: cellWidth * CGFloat(placement.columns) + spacing * CGFloat(placement.columns - 1),
                           height: cellHeight * CGFloat(placement.rows) + spacing * CGFloat(placement.rows - 1))
                    .offset(x: CGFloat(placement.column) * (cellWidth + spacing),
                            y: CGFloat(placement.row) * (cellHeight + spacing))
            }
        }
        .frame(width: contentWidth, height: size.height, alignment: .topLeading)

        return Group {
            if scrollable && allowsScrolling {
                ScrollView(.horizontal) { cells }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $firstColumn, anchor: .leading)
                    .scrollIndicators(.never)
                    .overlay(alignment: .leading) { scrollButton(left: true, maxFirst: maxFirst, step: displayColumns) }
                    .overlay(alignment: .trailing) { scrollButton(left: false, maxFirst: maxFirst, step: displayColumns) }
                    .onChange(of: layout.columnCount) { _, _ in
                        if (firstColumn ?? 0) > maxFirst { firstColumn = maxFirst }
                    }
            } else if scrollable {
                cells.frame(width: size.width, height: size.height, alignment: .leading).clipped()
            } else {
                // Ustun kam bo'lsa kartalar markazda turadi.
                cells.frame(width: size.width, height: size.height)
                    .onAppear { firstColumn = 0 }
            }
        }
    }

    @ViewBuilder
    private func scrollButton(left: Bool, maxFirst: Int, step: Int) -> some View {
        let current = firstColumn ?? 0
        if left ? current > 0 : current < maxFirst {
            Button {
                let target = left ? max(0, current - step) : min(maxFirst, current + step)
                withAnimation(motionReduced ? nil : .easeOut(duration: 0.3)) { firstColumn = target }
            } label: {
                Image(systemName: left ? "chevron.left" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 20, height: 20)
                    .background(.black.opacity(0.75), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.15)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            // Tugma grid chetidagi 16 pt bo'shliqda turadi: kartalarni to'smaydi.
            .padding(.horizontal, -18)
            .accessibilityLabel(left ? "Oldingi widgetlar" : "Keyingi widgetlar")
        }
    }
}

// Birinchi ishga tushirishda: nimani qanday yoqish mumkinligi. Hech narsa avtomatik yoqilmaydi.
struct WelcomeCard: View {
    let onSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "hand.wave.fill").foregroundStyle(Palette.accent).accessibilityHidden(true)
                Text("TopNest’ga xush kelibsiz").font(.system(size: 13, weight: .semibold))
            }
            .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 4) {
                line("switch.2", "Yondagi kartalarda “Sozlash” bilan kerakli imkoniyatni yoqing.")
                line("lock.shield", "Musiqa va clipboard faqat siz yoqsangiz kuzatiladi.")
                line("square.grid.2x2", "Widgetlar tartibi va o‘lchami — Sozlamalar → Widgetlar.")
            }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                SmallAction("Widgetlarni sozlash", action: onSettings)
                Spacer()
                Button("Tushunarli", action: onDismiss)
                    .buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Palette.accent, in: Capsule()).foregroundStyle(Palette.background)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.accent.opacity(0.35)))
    }

    private func line(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(Palette.muted).frame(width: 14).accessibilityHidden(true)
            Text(text).font(.system(size: 11)).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// Ma'lumot yoki ruxsat yetishmayotgan widget: sabab va tegishli joyni ochadigan bitta aniq tugma.
struct SetupCard: View {
    let title: String
    let icon: String
    let reason: String
    let actionTitle: String
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon).foregroundStyle(Palette.muted).accessibilityHidden(true)
                Text(title).lineLimit(1)
            }
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
            // Matn joy yetguncha qisqaradi, tugma esa doim karta ichida qoladi (ixcham panelda ham).
            Text(reason).font(.system(size: 11)).foregroundStyle(Palette.muted)
                .lineLimit(1...3).minimumScaleFactor(0.85)
                .layoutPriority(-1)
            Spacer(minLength: 0)
            Button(action: onAction) {
                Text(actionTitle).font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(.white.opacity(0.1), in: Capsule())
                    .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(.white.opacity(0.15)))
        .help(reason)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: actionTitle, onAction)
    }
}

// MARK: Widget konteyneri

struct WidgetCard<Content: View>: View {
    let title: String
    let icon: String
    let accent: Color
    var showHeader = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showHeader {
                HStack(spacing: 5) {
                    Image(systemName: icon).foregroundStyle(accent).accessibilityHidden(true)
                    Text(title).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                }
                .font(.system(size: 11, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            }
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct WidgetView: View {
    @ObservedObject var state: AppState
    let widget: WidgetConfig
    @ObservedObject var clipboard: ClipboardService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var weather: WeatherService

    var body: some View {
        switch widget.kind {
        case .music:
            if let track = state.track {
                MusicWidget(track: track, size: widget.size, canSeek: state.canSeekMusic,
                            onControl: { state.controlMusic($0) }, onSeek: { state.seekMusic(to: $0) })
            }
            else { MusicIdleWidget(size: widget.size, status: state.media.status, extended: state.extendedMediaEnabled) }
        case .calendar:
            CalendarWidget(calendar: calendar, size: widget.size)
        case .weather:
            if let info = weather.weather { WeatherWidget(info: info, size: widget.size) }
        case .clipboard:
            ClipboardWidget(state: state, clipboard: clipboard, size: widget.size)
        case .codexLimits:
            LimitWidget(name: "Codex", snapshot: state.codexUsage, labels: ("Asosiy", "Qo‘shimcha"), size: widget.size)
        case .claudeLimits:
            LimitWidget(name: "Claude", snapshot: state.claudeUsage, labels: ("5 soat", "7 kun"), size: widget.size)
        case .cpu, .memory, .gpu, .network:
            StatWidget(id: widget.id, stats: state.stats, kind: widget.kind, style: widget.statStyle, size: widget.size)
        case .custom:
            if let spec = widget.custom {
                CustomWidgetView(spec: spec, size: widget.size, runner: state.customRunners.runner(for: widget.id))
            }
        }
    }
}

// MARK: Musiqa

// AppState'ga bog'liq emas (amallar closure orqali): alohida chizib tekshirish mumkin.
struct MusicWidget: View {
    let track: TrackInfo
    let size: WidgetSize
    let canSeek: Bool
    let onControl: (String) -> Void
    let onSeek: (Double) -> Void
    @State private var hoveringProgress = false

    private var appIcon: NSImage? { ArtworkCache.appIcon(for: track.bundleID) }

    var body: some View {
        ZStack {
            // Albom rasmi xira fon: karta rangi trekka moslashadi.
            if size != .small {
                ArtworkView(url: track.artworkURL, data: track.artworkData, cornerRadius: 14)
                    .blur(radius: 30).opacity(0.45)
                    .overlay(Color.black.opacity(0.35))
                    .accessibilityHidden(true)
            }
            content.padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    ArtworkView(url: track.artworkURL, data: track.artworkData, cornerRadius: 8).frame(width: 38, height: 38)
                    Spacer()
                    control(track.playing ? "pause.fill" : "play.fill", "playpause", label: track.playing ? "Pauza" : "Ijro etish", primary: true)
                }
                Spacer(minLength: 0)
                titles
            }
        case .medium:
            HStack(spacing: 10) {
                ArtworkView(url: track.artworkURL, data: track.artworkData, cornerRadius: 10)
                    .aspectRatio(1, contentMode: .fit).frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    titles
                    Spacer(minLength: 0)
                    controls
                }
                Spacer(minLength: 0)
            }
        case .large:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ArtworkView(url: track.artworkURL, data: track.artworkData, cornerRadius: 12)
                        .frame(width: 68, height: 68)
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                    titles
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                progress
                HStack { Spacer(); controls; Spacer() }
            }
        }
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.title).font(.system(size: size == .large ? 14 : 13, weight: .semibold)).lineLimit(size == .large ? 2 : 1)
            Text(track.artist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            if size != .small {
                HStack(spacing: 4) {
                    if let appIcon { Image(nsImage: appIcon).resizable().frame(width: 12, height: 12) }
                    Text(track.source).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            control("backward.fill", "previous track", label: "Oldingi trek")
            control(track.playing ? "pause.fill" : "play.fill", "playpause", label: track.playing ? "Pauza" : "Ijro etish", primary: true)
            control("forward.fill", "next track", label: "Keyingi trek")
        }
    }

    // Standart rejimda progress faqat ko'rsatkich (ingichka, tutqichsiz). Kengaytirilgan rejimda
    // kursor olib borilganda qalinlashadi, tutqich chiqadi va bosib/sudrab o'tkazish mumkin.
    private var progress: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(spacing: 3) {
                GeometryReader { geo in
                    let active = canSeek && hoveringProgress
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(canSeek ? 0.2 : 0.14))
                        Capsule().fill(.white.opacity(canSeek ? 1 : 0.75)).frame(width: geo.size.width * track.progress)
                        if active {
                            Circle().fill(.white).frame(width: 10, height: 10)
                                .offset(x: geo.size.width * track.progress - 5)
                        }
                    }
                    .frame(height: active ? 6 : (canSeek ? 4 : 3))
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { inside in setHover(inside && canSeek) }
                    .onDisappear { setHover(false) }
                    .onChange(of: canSeek) { _, seekable in if !seekable { setHover(false) } }
                    .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                        onSeek(value.location.x / max(1, geo.size.width))
                    }, including: canSeek ? .all : .none)
                }
                .frame(height: 12)
                HStack {
                    Text(musicTime(track.elapsed))
                    Spacer()
                    Text(track.duration > 0 ? "-" + musicTime(track.duration - track.elapsed) : "")
                }.font(.system(size: 10).monospacedDigit()).foregroundStyle(.white.opacity(0.6))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Ijro holati")
            .accessibilityValue("\(musicTime(track.elapsed)) / \(musicTime(track.duration))")
            .modifier(SeekAccessibility(enabled: canSeek && track.duration > 0) { direction in
                let step = 10 / track.duration
                onSeek(track.progress + (direction == .increment ? step : -step))
            })
        }
    }

    // Kursor stek'i muvozanatda qolishi uchun faqat holat o'zgarganda push/pop qilinadi.
    private func setHover(_ inside: Bool) {
        guard inside != hoveringProgress else { return }
        hoveringProgress = inside
        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
    }

    private func control(_ icon: String, _ action: String, label: String, primary: Bool = false) -> some View {
        Button { onControl(action) } label: {
            Image(systemName: icon).font(.system(size: primary ? 13 : 11, weight: .semibold))
                .frame(width: primary ? 32 : 26, height: primary ? 32 : 26)
                .background(primary ? Color.white : .white.opacity(0.12), in: Circle())
                .foregroundStyle(primary ? Color.black : .white)
                .contentShape(Circle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }

    private func musicTime(_ seconds: Double) -> String {
        let value = max(0, Int(seconds))
        return "\(value / 60):\(String(format: "%02d", value % 60))"
    }
}

// Trek yo'q yoki kengaytirilgan rejim ulanmagan holat: karta joyi saqlanadi, sabab aniq yoziladi.
struct MusicIdleWidget: View {
    let size: WidgetSize
    let status: MediaRemoteService.Status
    let extended: Bool

    private var message: (title: String, detail: String, icon: String) {
        if extended && status == .failed {
            return ("Kengaytirilgan rejim ishlamadi", "Spotify va Music standart rejimda ko‘rsatiladi.", "exclamationmark.triangle")
        }
        if extended && status == .starting {
            return ("Ulanmoqda…", "Playerlar bilan aloqa o‘rnatilmoqda.", "hourglass")
        }
        return ("Hech narsa ijro etilmayapti",
                extended ? "Istalgan playerda trek qo‘ying." : "Spotify yoki Music’da trek qo‘ying.",
                "music.note")
    }

    var body: some View {
        let info = message
        WidgetCard(title: "Musiqa", icon: "music.note", accent: .pink) {
            VStack(alignment: .leading, spacing: 4) {
                if size != .small { Spacer(minLength: 0) }
                Image(systemName: info.icon).font(.system(size: size == .small ? 16 : 22)).foregroundStyle(Palette.muted)
                    .accessibilityHidden(true)
                Text(info.title).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                Text(info.detail).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(size == .small ? 2 : 3)
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Kalendar

struct CalendarWidget: View {
    @ObservedObject var calendar: CalendarService
    let size: WidgetSize

    var body: some View {
        WidgetCard(title: "Kalendar", icon: "calendar", accent: .orange) {
            TimelineView(.everyMinute) { context in
                let current = calendar.events.filter { $0.end > context.date }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(current.prefix(size == .large ? 4 : (size == .medium ? 2 : 1))) { event in
                        eventRow(event, now: context.date)
                    }
                }
            }
        }
    }

    private func eventRow(_ event: CalendarItem, now: Date) -> some View {
        let minutes = event.minutesUntilStart(from: now)
        let soon = minutes <= 15 && event.end > now
        return VStack(alignment: .leading, spacing: 1) {
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
}

// MARK: Ob-havo

struct WeatherWidget: View {
    let info: WeatherInfo
    let size: WidgetSize

    var body: some View {
        WidgetCard(title: info.city, icon: "location.fill", accent: .cyan) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Image(systemName: info.symbol).foregroundStyle(.cyan).accessibilityHidden(true)
                        Text("\(Int(info.temperature.rounded()))°").font(.system(size: 24, weight: .semibold))
                    }
                    if Date().timeIntervalSince(info.updatedAt) > 3600 {
                        Text("Ma’lumot eskirgan").font(.system(size: 10)).foregroundStyle(.orange)
                    }
                }
                if size != .small && !info.hourly.isEmpty && Date().timeIntervalSince(info.updatedAt) < 3600 {
                    Spacer(minLength: 0)
                    ForEach(info.hourly) { hour in
                        VStack(spacing: 2) {
                            Text(hour.label).font(.system(size: 10).monospacedDigit()).foregroundStyle(Palette.muted)
                            Image(systemName: hour.symbol).font(.system(size: 11)).foregroundStyle(.cyan)
                            Text("\(Int(hour.temperature.rounded()))°").font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(hour.label): \(Int(hour.temperature.rounded())) daraja")
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: Clipboard

struct ClipboardWidget: View {
    @ObservedObject var state: AppState
    @ObservedObject var clipboard: ClipboardService
    let size: WidgetSize

    var body: some View {
        WidgetCard(title: "Clipboard", icon: "doc.on.clipboard", accent: Palette.accent) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach((clipboard.pinned + clipboard.items).prefix(size == .large ? 5 : 2)) { item in
                    Button { clipboard.copy(item) } label: {
                        HStack(spacing: 6) {
                            if clipboard.isPinned(item) {
                                Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.orange)
                            }
                            Text(item.text.replacingOccurrences(of: "\n", with: " "))
                                .font(.system(size: 11)).lineLimit(1).foregroundStyle(.white.opacity(0.85))
                            Spacer(minLength: 0)
                            Image(systemName: "doc.on.doc").font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Nusxalash: \(item.text.prefix(80))")
                }
                Spacer(minLength: 0)
                SmallAction("Hammasi") { state.selectedTab = .clips }
            }
        }
    }
}

// MARK: AI limitlari

struct LimitWidget: View {
    let name: String
    let snapshot: UsageSnapshot?
    let labels: (String, String)
    let size: WidgetSize

    var body: some View {
        WidgetCard(title: name, icon: "sparkle", accent: .purple) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                if let snapshot {
                    VStack(alignment: .leading, spacing: size == .small ? 5 : 7) {
                        if let primary = snapshot.primary { meter(labels.0, window: primary, stale: snapshot.isStale(at: context.date), now: context.date) }
                        if let secondary = snapshot.secondary { meter(labels.1, window: secondary, stale: snapshot.isStale(at: context.date), now: context.date) }
                        if size != .small {
                            Spacer(minLength: 0)
                            Text("\(snapshot.isStale(at: context.date) ? "oxirgi ma’lumot" : "yangilangan") \(stamp(snapshot.updatedAt))")
                                .font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }
                    }
                }
            }
        }
    }

    private func stamp(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    private func meter(_ label: String, window: UsageWindow, stale: Bool, now: Date) -> some View {
        let reset = window.hasReset(at: now)
        let remaining = window.remainingPercent
        let color = reset ? Palette.muted : Palette.level(remaining)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(label).foregroundStyle(Palette.muted)
                Spacer(minLength: 2)
                Text(reset ? "Tiklangan" : "\(remaining)%").fontWeight(.semibold).foregroundStyle(color)
            }
            .font(.system(size: 11).monospacedDigit())
            ProgressBar(value: reset ? 1 : Double(remaining) / 100, color: color.opacity(stale && !reset ? 0.55 : 1))
            if size != .small, !reset, let resetAt = window.resetAt {
                Text("\(usageCountdown(to: resetAt, now: now)) keyin tiklanadi").font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(label)")
        .accessibilityValue(reset ? "Tiklangan" : "\(remaining)% qoldi" + (window.resetAt.map { ", \(usageCountdown(to: $0, now: now)) keyin tiklanadi" } ?? ""))
    }
}

func usageCountdown(to date: Date, now: Date) -> String {
    let seconds = max(0, Int(date.timeIntervalSince(now)))
    let days = seconds / 86_400, hours = (seconds % 86_400) / 3600, minutes = (seconds % 3600) / 60
    if days > 0 { return "\(days) kun \(hours) soat" }
    if hours > 0 { return "\(hours) soat \(minutes) daq" }
    return "\(max(1, minutes)) daq"
}

// MARK: Halqa

struct RingGauge: View {
    let value: Double
    let color: Color
    var lineWidth: CGFloat = 6
    var label: String? = nil

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.1), lineWidth: lineWidth)
            Circle().trim(from: 0, to: min(1, max(0, value)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let label {
                Text(label).font(.system(size: 12, weight: .semibold).monospacedDigit()).minimumScaleFactor(0.6).lineLimit(1)
                    .padding(lineWidth)
            }
        }
    }
}

// MARK: Maxsus widget

struct CustomWidgetView: View {
    let spec: CustomWidgetSpec
    let size: WidgetSize
    @ObservedObject var runner: CustomWidgetRunner

    var body: some View {
        WidgetCard(title: spec.title, icon: spec.icon, accent: .teal) {
            Group {
                if let value = runner.value {
                    let text = spec.prefix + value + spec.suffix
                    switch spec.display {
                    case .text:
                        Text(text).font(.system(size: 12)).lineLimit(size == .small ? 3 : 5)
                    case .number:
                        Text(text).font(.system(size: size == .small ? 22 : 30, weight: .semibold).monospacedDigit())
                            .minimumScaleFactor(0.4).lineLimit(1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    case .gauge:
                        HStack {
                            RingGauge(value: (runner.numericValue ?? 0) / max(spec.gaugeMax, 0.0001), color: .teal, label: text)
                                .frame(maxHeight: .infinity)
                            Spacer(minLength: 0)
                        }
                    }
                } else if let error = runner.error {
                    Text(error).font(.system(size: 11)).foregroundStyle(.orange)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .help(runner.error ?? "")
            .overlay(alignment: .topTrailing) {
                // Oxirgi urinish xato bo'lsa, ko'rsatilayotgan qiymat eskirganini bildiradi.
                if runner.value != nil, runner.error != nil {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10)).foregroundStyle(.orange)
                        .accessibilityLabel("Ma’lumot eskirgan")
                }
            }
        }
        // Panel ochiq turgan paytda belgilangan oraliqda yangilanadi, yopilganda to'xtaydi.
        .task(id: spec) {
            while !Task.isCancelled {
                runner.refreshIfNeeded(spec)
                try? await Task.sleep(for: .seconds(max(10, spec.refreshSeconds)))
            }
        }
    }
}

// MARK: Tizim statistikasi

struct StatWidget: View {
    let id: UUID
    @ObservedObject var stats: SystemStatsService
    let kind: WidgetKind
    let style: StatStyle
    let size: WidgetSize

    private var fraction: Double? {
        switch kind {
        case .cpu: stats.cpu
        case .memory: stats.memoryFraction
        case .gpu: stats.gpu
        default: nil
        }
    }

    private var title: String {
        switch kind {
        case .cpu: "CPU"
        case .memory: "RAM"
        case .gpu: "GPU"
        default: "Tarmoq"
        }
    }

    private var detail: String? {
        switch kind {
        case .memory:
            let used = ByteCountFormatter.string(fromByteCount: Int64(stats.memoryUsed), countStyle: .memory)
            let total = ByteCountFormatter.string(fromByteCount: Int64(stats.memoryTotal), countStyle: .memory)
            return size == .small ? used : "\(used) / \(total)"
        case .gpu where stats.gpu == nil: return "Ma’lumot yo‘q"
        default: return nil
        }
    }

    private func color(_ value: Double) -> Color {
        value > 0.85 ? Palette.danger : (value > 0.6 ? Palette.warning : Palette.accent)
    }

    var body: some View {
        WidgetCard(title: title, icon: kind.icon, accent: Palette.accent) {
            Group {
                if kind == .network { network } else { gauge }
            }
        }
        // Faqat widget ko'rinib turganda o'lchanadi.
        .onAppear { stats.retain(id, kind: kind) }
        .onDisappear { stats.release(id) }
    }

    @ViewBuilder
    private var gauge: some View {
        let value = fraction ?? 0
        let percent = fraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
        switch style {
        case .ring:
            HStack(spacing: 10) {
                RingGauge(value: value, color: color(value), lineWidth: size == .small ? 5 : 7, label: percent)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxHeight: .infinity)
                if size != .small, let detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
            }
        case .number:
            VStack(alignment: .leading, spacing: 2) {
                Spacer(minLength: 0)
                Text(percent).font(.system(size: size == .small ? 26 : 32, weight: .semibold).monospacedDigit())
                    .foregroundStyle(color(value)).minimumScaleFactor(0.5).lineLimit(1)
                if let detail { Text(detail).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.7) }
            }
        case .graph:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(percent).font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(color(value))
                    if size != .small, let detail { Text(detail).font(.system(size: 10)).foregroundStyle(Palette.muted) }
                }
                Sparkline(values: stats.history[kind] ?? [], maximum: 1, color: color(value))
            }
        }
    }

    @ViewBuilder
    private var network: some View {
        let rates = VStack(alignment: .leading, spacing: 3) {
            Label(stats.download?.byteRate ?? "—", systemImage: "arrow.down").foregroundStyle(Palette.accent)
            Label(stats.upload?.byteRate ?? "—", systemImage: "arrow.up").foregroundStyle(Palette.warning)
        }
        .font(.system(size: size == .small ? 11 : 13, weight: .semibold).monospacedDigit())
        .lineLimit(1).minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
        if style == .graph {
            VStack(alignment: .leading, spacing: 4) {
                rates
                let values = stats.history[.network] ?? []
                // 10 KB/s dan past fon trafigi grafikni to'liq balandlikka ko'tarmasin.
                Sparkline(values: values, maximum: max(values.max() ?? 0, 10_000), color: Palette.accent)
            }
        } else {
            VStack(alignment: .leading) {
                Spacer(minLength: 0)
                rates
            }
        }
    }
}

struct Sparkline: View {
    let values: [Double]
    let maximum: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let points = values.enumerated().map { index, value in
                CGPoint(x: values.count > 1 ? geo.size.width * CGFloat(index) / CGFloat(values.count - 1) : 0,
                        y: geo.size.height * (1 - CGFloat(min(1, max(0, value / maximum)))))
            }
            ZStack {
                if points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        points.forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.18))
                    Path { path in
                        path.move(to: points[0])
                        points.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// Progressni VoiceOver bilan sozlash faqat haqiqatan o'tkazish mumkin bo'lganda e'lon qilinadi.
private struct SeekAccessibility: ViewModifier {
    let enabled: Bool
    let adjust: (AccessibilityAdjustmentDirection) -> Void

    func body(content: Content) -> some View {
        if enabled { content.accessibilityAdjustableAction(adjust) } else { content }
    }
}
