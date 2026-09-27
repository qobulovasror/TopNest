import AppKit
import SwiftUI

// Asosiy ekran: widgetlar 4×2 katakli sahifalarga joylashadi, vertikal scroll yo'q.
// Ma'lumoti yo'q yoki ruxsati berilmagan widget joy egallamaydi.
struct HomeContent: View {
    @ObservedObject var state: AppState
    @ObservedObject var widgets: WidgetStore
    @ObservedObject var clipboard: ClipboardService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var weather: WeatherService
    @State private var page: Int? = 0

    static let columns = 4
    static let rows = 2
    static let spacing: CGFloat = 8

    var body: some View {
        if let request = state.permissionRequests.first {
            // So'rov bor paytda panel butunlay unga beriladi.
            PermissionCard(request: request, queued: state.permissionRequests.count - 1) { decision in
                state.answerPermission(request, decision: decision)
            }
            .padding(.horizontal, 16)
        } else {
            // Har daqiqa qayta hisoblanadi: tugagan uchrashuv widgeti o'z-o'zidan yashiriladi.
            TimelineView(.everyMinute) { context in
                grid(visible(at: context.date)).padding(.horizontal, 16)
            }
            .onChange(of: widgets.widgets.map(\.id)) { _, ids in state.customRunners.prune(keeping: Set(ids)) }
        }
    }

    private func visible(at now: Date) -> [WidgetConfig] { widgets.widgets.filter { isAvailable($0, now: now) } }

    private func isAvailable(_ widget: WidgetConfig, now: Date) -> Bool {
        switch widget.kind {
        case .music: state.musicEnabled && state.track != nil
        case .calendar: calendar.accessGranted && calendar.events.contains { $0.end > now }
        case .weather: weather.weather != nil
        case .clipboard: state.clipboardEnabled && !(clipboard.items.isEmpty && clipboard.pinned.isEmpty)
        case .codexLimits: state.codexEnabled && state.codexUsage != nil
        case .claudeLimits: state.claudeInstalled && state.claudeUsage != nil
        case .cpu, .memory, .gpu, .network: false
        case .custom: widget.custom != nil
        }
    }

    private func grid(_ visible: [WidgetConfig]) -> some View {
        let placements = WidgetLayout.place(visible, columns: Self.columns, rows: Self.rows)
        let pageCount = (placements.map(\.page).max() ?? -1) + 1
        return GeometryReader { geo in
            let gridHeight = geo.size.height - (pageCount > 1 ? 14 : 0)
            let cellWidth = (geo.size.width - Self.spacing * CGFloat(Self.columns - 1)) / CGFloat(Self.columns)
            let cellHeight = (gridHeight - Self.spacing * CGFloat(Self.rows - 1)) / CGFloat(Self.rows)
            if placements.isEmpty {
                emptyState.frame(width: geo.size.width, height: geo.size.height)
            } else {
                VStack(spacing: 6) {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(0..<pageCount, id: \.self) { index in
                                ZStack(alignment: .topLeading) {
                                    ForEach(placements.filter { $0.page == index }) { placement in
                                        let size = placement.widget.size
                                        WidgetView(state: state, widget: placement.widget, clipboard: clipboard, calendar: calendar, weather: weather)
                                            .frame(width: cellWidth * CGFloat(size.columns) + Self.spacing * CGFloat(size.columns - 1),
                                                   height: cellHeight * CGFloat(size.rows) + Self.spacing * CGFloat(size.rows - 1))
                                            .offset(x: CGFloat(placement.column) * (cellWidth + Self.spacing),
                                                    y: CGFloat(placement.row) * (cellHeight + Self.spacing))
                                    }
                                }
                                .frame(width: geo.size.width, height: gridHeight, alignment: .topLeading)
                                .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollIndicators(.hidden)
                    .scrollPosition(id: $page)
                    if pageCount > 1 { pageDots(pageCount) }
                }
            }
        }
        // Sahifalar kamaysa joriy sahifa mavjud oralig'iga qaytariladi.
        .onChange(of: pageCount) { _, count in
            if (page ?? 0) >= count { page = max(0, count - 1) }
        }
    }

    private func pageDots(_ count: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Button {
                    withAnimation(state.motionReduced ? nil : .easeOut(duration: 0.25)) { page = index }
                } label: {
                    Circle().fill((page ?? 0) == index ? Palette.accent : .white.opacity(0.25)).frame(width: 6, height: 6)
                        .padding(2).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(index + 1)-sahifa")
                .accessibilityAddTraits((page ?? 0) == index ? .isSelected : [])
            }
        }
        .frame(height: 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2").font(.system(size: 22)).foregroundStyle(Palette.muted)
            Text("Hozircha ko‘rsatiladigan ma’lumot yo‘q").font(.system(size: 13, weight: .semibold))
            Text("Musiqa, kalendar, ob-havo yoki limitlar paydo bo‘lganda widgetlar shu yerda chiqadi.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            SmallAction("Widgetlarni sozlash") { state.showSettings(.widgets) }
        }
        .padding(.horizontal, 40)
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
            if let track = state.track { MusicWidget(state: state, track: track, size: widget.size) }
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
            EmptyView()
        case .custom:
            if let spec = widget.custom {
                CustomWidgetView(spec: spec, size: widget.size, runner: state.customRunners.runner(for: widget.id))
            }
        }
    }
}

// MARK: Musiqa

struct MusicWidget: View {
    @ObservedObject var state: AppState
    let track: TrackInfo
    let size: WidgetSize

    var body: some View {
        WidgetCard(title: "Hozir ijroda", icon: "music.note", accent: .pink, showHeader: false) {
            switch size {
            case .small:
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        ArtworkView(url: track.artworkURL, cornerRadius: 8).frame(width: 36, height: 36)
                        Spacer()
                        control(track.playing ? "pause.fill" : "play.fill", "playpause", label: track.playing ? "Pauza" : "Ijro etish", primary: true)
                    }
                    Spacer(minLength: 0)
                    titles
                }
            case .medium:
                HStack(spacing: 10) {
                    ArtworkView(url: track.artworkURL, cornerRadius: 10).frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 6) {
                        titles
                        controls
                    }
                }
                .frame(maxHeight: .infinity)
            case .large:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        ArtworkView(url: track.artworkURL, cornerRadius: 10).frame(width: 60, height: 60)
                        titles
                    }
                    Spacer(minLength: 0)
                    progress
                    HStack { Spacer(); controls; Spacer() }
                }
            }
        }
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Text(track.artist).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
            if size != .small {
                Text(track.source).font(.system(size: 10)).foregroundStyle(Palette.accent).lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            control("backward.end.fill", "previous track", label: "Oldingi trek")
            control(track.playing ? "pause.fill" : "play.fill", "playpause", label: track.playing ? "Pauza" : "Ijro etish", primary: true)
            control("forward.end.fill", "next track", label: "Keyingi trek")
        }
    }

    private var progress: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let elapsed = track.position + (track.playing ? Date().timeIntervalSince(track.observedAt) : 0)
            VStack(spacing: 3) {
                ProgressBar(value: track.progress, color: Palette.accent, height: 4)
                HStack {
                    Text(musicTime(elapsed))
                    Spacer()
                    Text(musicTime(track.duration))
                }.font(.system(size: 10).monospacedDigit()).foregroundStyle(Palette.muted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Ijro holati")
            .accessibilityValue("\(musicTime(elapsed)) / \(musicTime(track.duration))")
        }
    }

    private func control(_ icon: String, _ action: String, label: String, primary: Bool = false) -> some View {
        Button { state.controlMusic(action) } label: {
            Image(systemName: icon).font(.system(size: primary ? 12 : 10, weight: .semibold))
                .frame(width: primary ? 30 : 24, height: primary ? 30 : 24)
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
