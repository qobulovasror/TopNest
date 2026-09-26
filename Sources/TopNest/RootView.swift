import AppKit
import SwiftUI

private enum Palette {
    static let background = Color(red: 0.055, green: 0.069, blue: 0.095)
    static let card = Color(red: 0.105, green: 0.125, blue: 0.165)
    static let accent = Color(red: 0.43, green: 0.91, blue: 0.78)
    static let muted = Color(red: 0.59, green: 0.64, blue: 0.72)
}

struct RootView: View {
    @ObservedObject var state: AppState

    var body: some View {
        Group {
            if state.expanded { expandedBody }
            else { compactBody }
        }
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
        .accessibilityLabel("TopNest panelini ochish")
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
        case .music:
            ArtworkView(url: state.track?.artworkURL, cornerRadius: 5)
                .frame(width: 20, height: 20)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var rightWing: some View {
        switch state.displayedActivity {
        case .music:
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .symbolEffect(.variableColor.iterative, isActive: state.track?.playing == true)
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
            HStack {
                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Palette.accent)
                        Image(systemName: "square.stack.3d.up.fill").foregroundStyle(Palette.background)
                    }.frame(width: 27, height: 27)
                    Text("TopNest").font(.system(size: 17, weight: .bold))
                }
                Spacer()
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                Button { state.showSettings() } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 11, weight: .semibold))
                        .frame(width: 25, height: 25).background(.white.opacity(0.08), in: Circle())
                }.buttonStyle(.plain).accessibilityLabel("Sozlamalarni ochish")
                Button { state.onCollapse?() } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                        .frame(width: 25, height: 25).background(.white.opacity(0.08), in: Circle())
                }.buttonStyle(.plain).accessibilityLabel("Yopish")
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 15)

            HStack(spacing: 5) {
                ForEach(AppState.Tab.allCases, id: \.self) { tab in
                    Button { state.selectedTab = tab } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: state.selectedTab == tab ? .semibold : .medium))
                            .foregroundStyle(state.selectedTab == tab ? Palette.background : Palette.muted)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(state.selectedTab == tab ? Palette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
            }
            .padding(4).background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 13))
            .padding(.horizontal, 20).padding(.bottom, 14)

            Group {
                switch state.selectedTab {
                case .home: HomeContent(state: state, clipboard: state.clipboard, calendar: state.calendar, weather: state.weather)
                case .clips: ClipboardContent(state: state, clipboard: state.clipboard)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
    }
}

private struct HomeContent: View {
    @ObservedObject var state: AppState
    @ObservedObject var clipboard: ClipboardService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var weather: WeatherService

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                PanelCard(title: "Hozir ijroda", icon: "music.note", accent: .pink) {
                    if !state.musicEnabled {
                        HStack {
                            EmptyHint("Musiqa kuzatuvi o‘chiq.")
                            Spacer()
                            SmallAction("Yoqish") { state.musicEnabled = true }
                        }
                    } else if let track = state.track {
                        VStack(spacing: 11) {
                            HStack(spacing: 12) {
                                ArtworkView(url: track.artworkURL)
                                    .frame(width: 56, height: 56)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                    Text(track.artist).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                                    Text("\(track.source) · \(track.playing ? "Ijroda" : "Pauza")")
                                        .font(.system(size: 10)).foregroundStyle(Palette.accent)
                                }
                                Spacer(minLength: 0)
                            }
                            TimelineView(.periodic(from: .now, by: 1)) { _ in
                                VStack(spacing: 5) {
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(.white.opacity(0.12))
                                            Capsule().fill(Palette.accent)
                                                .frame(width: geo.size.width * track.progress)
                                        }
                                    }.frame(height: 4)
                                    HStack {
                                        Text(musicTime(track.position + (track.playing ? Date().timeIntervalSince(track.observedAt) : 0)))
                                        Spacer()
                                        Text(musicTime(track.duration))
                                    }.font(.system(size: 10)).foregroundStyle(Palette.muted)
                                }
                            }
                            HStack(spacing: 20) {
                                Spacer()
                                control("backward.end.fill", "previous track", label: "Oldingi trek")
                                control(track.playing ? "pause.fill" : "play.fill", "playpause", label: track.playing ? "Pauza" : "Ijro etish", primary: true)
                                control("forward.end.fill", "next track", label: "Keyingi trek")
                                Spacer()
                            }
                        }
                    } else {
                        EmptyHint("Spotify yoki Music’da trek ijro etilganda shu yerda chiqadi.")
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    PanelCard(title: "Kalendar", icon: "calendar", accent: .orange) {
                        if !calendar.events.isEmpty {
                            ForEach(calendar.events.prefix(3)) { event in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                                    Text(event.start, format: .dateTime.weekday(.abbreviated).hour().minute())
                                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                                    if let url = event.url, ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                                        SmallAction("Havolani ochish") { NSWorkspace.shared.open(url) }
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else if calendar.accessGranted {
                            EmptyHint("Yaqinlashayotgan uchrashuv yo‘q.")
                        } else {
                            SmallAction("Ruxsat berish") { calendar.requestAccess() }
                            if let error = calendar.errorMessage { EmptyHint(error) }
                        }
                    }
                    PanelCard(title: "Ob-havo", icon: "cloud.sun.fill", accent: .cyan) {
                        if let info = weather.weather {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Image(systemName: info.symbol).foregroundStyle(.cyan)
                                Text("\(Int(info.temperature.rounded()))°").font(.system(size: 20, weight: .semibold))
                            }
                            Text(info.city).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                            if Date().timeIntervalSince(info.updatedAt) > 3600 {
                                Text("Ma’lumot eskirgan").font(.system(size: 10)).foregroundStyle(.orange)
                            }
                        } else {
                            SmallAction("Shahar tanlash") { state.showSettings(.weather) }
                        }
                    }
                }

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
                                .font(.system(size: 11)).lineLimit(1).foregroundStyle(Palette.muted)
                            Spacer()
                            SmallAction("Ko‘rish") { state.selectedTab = .clips }
                        }
                    } else { EmptyHint("Nusxalangan matn shu yerda paydo bo‘ladi.") }
                }

                PanelCard(title: "AI limitlari", icon: "sparkle", accent: .purple) {
                    VStack(spacing: 12) {
                        UsageRow(name: "Codex", snapshot: state.codexUsage, primaryLabel: "Asosiy", secondaryLabel: "Qo‘shimcha", fallback: state.codexEnabled ? (state.codexError ?? "Yuklanmoqda…") : "Sozlamalarda o‘chirilgan")
                        Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                        UsageRow(name: "Claude", snapshot: state.claudeUsage, primaryLabel: "5 soat", secondaryLabel: "7 kun", fallback: state.claudeInstalled ? "Claude Code ishlatilgach yangilanadi" : "Sozlamalardan ulash mumkin")
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func control(_ icon: String, _ action: String, label: String, primary: Bool = false) -> some View {
        Button { state.controlMusic(action) } label: {
            Image(systemName: icon).font(.system(size: primary ? 15 : 12, weight: .semibold))
                .frame(width: primary ? 38 : 30, height: primary ? 38 : 30)
                .background(primary ? Palette.accent : .white.opacity(0.08), in: Circle())
                .foregroundStyle(primary ? Palette.background : .white)
        }.buttonStyle(.plain).accessibilityLabel(label)
    }

    private func musicTime(_ seconds: Double) -> String {
        let value = max(0, Int(seconds))
        return "\(value / 60):\(String(format: "%02d", value % 60))"
    }
}

private struct ArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = 11

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

private struct ClipboardContent: View {
    @ObservedObject var state: AppState
    @ObservedObject var clipboard: ClipboardService
    @State private var query = ""

    private var filtered: [ClipItem] {
        query.isEmpty ? clipboard.items : clipboard.items.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                TextField("Matndan qidirish", text: $query).textFieldStyle(.plain)
            }
            .padding(11).background(Palette.card, in: RoundedRectangle(cornerRadius: 11))
            HStack {
                Text("Faqat xotirada · \(clipboard.items.count)/25")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                Spacer()
                Button("Tozalash") { clipboard.clear() }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.red.opacity(0.9))
            }
            if !state.clipboardEnabled {
                Spacer()
                Text("Clipboard tarixi o‘chiq").font(.system(size: 14, weight: .semibold))
                Text("Yoqilgach, yangi nusxalangan matnlar faqat ilova xotirasida saqlanadi.")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                Button("Tarixni yoqish") { state.clipboardEnabled = true }
                    .buttonStyle(.borderedProminent).tint(Palette.accent)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(filtered) { item in
                            HStack(spacing: 7) {
                                Button { clipboard.copy(item) } label: {
                                    HStack {
                                    Text(item.text).lineLimit(3).multilineTextAlignment(.leading)
                                        .font(.system(size: 12))
                                    Spacer()
                                    Image(systemName: "doc.on.doc").foregroundStyle(Palette.accent)
                                    }
                                    .padding(11).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                Button { clipboard.remove(item) } label: {
                                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Palette.muted).frame(width: 25, height: 25)
                                }.buttonStyle(.plain).accessibilityLabel("Yozuvni o‘chirish")
                            }
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }.scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 18)
    }
}

private struct PanelCard<Content: View>: View {
    let title: String
    let icon: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon).foregroundStyle(accent)
                Text(title).foregroundStyle(.white.opacity(0.9))
            }.font(.system(size: 11, weight: .semibold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct EmptyHint: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true) }
}

private struct SmallAction: View {
    let text: String
    let action: () -> Void
    init(_ text: String, action: @escaping () -> Void) { self.text = text; self.action = action }
    var body: some View {
        Button(action: action) { Text(text).font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.accent) }
            .buttonStyle(.plain)
    }
}

private struct UsageRow: View {
    let name: String
    let snapshot: UsageSnapshot?
    let primaryLabel: String
    let secondaryLabel: String
    let fallback: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(name).font(.system(size: 12, weight: .semibold))
                Spacer()
                if let snapshot {
                    Text(snapshot.updatedAt, style: .time).font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            }
            if let snapshot, Date().timeIntervalSince(snapshot.updatedAt) < 900 {
                if let primary = snapshot.primary { meter(primaryLabel, window: primary) }
                if let secondary = snapshot.secondary { meter(secondaryLabel, window: secondary) }
                if snapshot.primary == nil && snapshot.secondary == nil { EmptyHint("Limit ma’lumoti mavjud emas") }
            } else if snapshot != nil {
                EmptyHint("Ma’lumot eskirgan; qayta yangilanishini kuting")
            } else { EmptyHint(fallback) }
        }
    }

    private func meter(_ label: String, window: UsageWindow) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(label).foregroundStyle(Palette.muted)
                Spacer()
                Text("\(window.remainingPercent)% qoldi")
                if let reset = window.resetAt {
                    Text("· \(reset, style: .time)").foregroundStyle(Palette.muted)
                }
            }.font(.system(size: 10))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule().fill(window.remainingPercent < 20 ? Color.orange : Palette.accent)
                        .frame(width: geo.size.width * CGFloat(window.remainingPercent) / 100)
                }
            }.frame(height: 4)
        }
    }
}
