import SwiftUI

struct WorldClockWidget: View {
    @ObservedObject var store: WorldClockStore
    let size: WidgetSize
    @Environment(\.locale) private var locale

    var body: some View {
        WidgetCard(title: "Dunyo soatlari", icon: "globe", accent: .teal, showHeader: size == .large) {
            TimelineView(.everyMinute) { context in
                let zones = store.zones.prefix(size == .small ? 2 : (size == .medium ? 3 : 4)).compactMap(TimeZone.init(identifier:))
                if size == .medium {
                    HStack(spacing: 6) {
                        ForEach(zones, id: \.identifier) { zone in
                            VStack(spacing: 2) {
                                Text(WorldClockStore.city(zone.identifier)).font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.muted).lineLimit(1)
                                Text(time(context.date, zone)).font(.system(size: 18, weight: .semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                                Text(WorldClockStore.offset(zone, at: context.date)).font(.system(size: 9).monospacedDigit()).foregroundStyle(Palette.muted)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(zones, id: \.identifier) { zone in
                            HStack {
                                Text(WorldClockStore.city(zone.identifier)).font(.system(size: 11)).lineLimit(1)
                                Spacer(minLength: 4)
                                if size == .large {
                                    Text(WorldClockStore.offset(zone, at: context.date)).font(.system(size: 10).monospacedDigit()).foregroundStyle(Palette.muted)
                                }
                                Text(time(context.date, zone)).font(.system(size: 13, weight: .semibold).monospacedDigit())
                            }
                            .accessibilityElement(children: .combine)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func time(_ date: Date, _ zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = zone
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: date)
    }
}

struct ShortcutsWidget: View {
    @ObservedObject var store: ShortcutsStore
    let size: WidgetSize

    var body: some View {
        WidgetCard(title: "Shortcuts", icon: "square.stack.3d.forward.dottedline", accent: .pink, showHeader: size == .large) {
            let names = Array(store.selected.prefix(size == .small ? 2 : 4))
            let columns = size == .small ? 1 : 2
            VStack(spacing: 5) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: columns), spacing: 5) {
                    ForEach(names, id: \.self) { name in
                        Button { store.run(name) } label: {
                            HStack(spacing: 5) {
                                if store.running.contains(name) {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "play.fill").font(.system(size: 9)).foregroundStyle(.pink)
                                }
                                Text(name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8).frame(height: 26)
                            .background(Palette.softFill, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.format("Ishga tushirish: %@", name))
                    }
                }
                if let error = store.errorMessage {
                    Text(error).font(.system(size: 10)).foregroundStyle(Palette.warning).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct PrayerWidget: View {
    @ObservedObject var prayer: PrayerService
    let size: WidgetSize

    var body: some View {
        WidgetCard(title: "Namoz vaqtlari", icon: "moon.stars.fill", accent: .teal, showHeader: size == .large) {
            TimelineView(.everyMinute) { context in
                let next = prayer.next(after: context.date)
                if size == .small {
                    VStack(alignment: .leading, spacing: 2) {
                        if let next {
                            Text(next.title).font(.system(size: 12, weight: .semibold))
                            Text(next.date, format: .dateTime.hour().minute()).font(.system(size: 20, weight: .semibold).monospacedDigit())
                            Text(remaining(next, now: context.date)).font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                } else if size == .medium {
                    HStack(spacing: 4) {
                        ForEach(prayer.times) { time in
                            VStack(spacing: 2) {
                                Text(time.title).font(.system(size: 9, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                Text(time.date, format: .dateTime.hour().minute()).font(.system(size: 12, weight: .semibold).monospacedDigit())
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .foregroundStyle(time.id == next?.id && Calendar.current.isDate(time.date, inSameDayAs: context.date) ? Color.teal : Palette.text.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    VStack(spacing: 3) {
                        ForEach(prayer.times) { time in
                            HStack {
                                Text(time.title).font(.system(size: 12))
                                Spacer()
                                Text(time.date, format: .dateTime.hour().minute()).font(.system(size: 12, weight: .semibold).monospacedDigit())
                            }
                            .foregroundStyle(time.id == next?.id && Calendar.current.isDate(time.date, inSameDayAs: context.date) ? Color.teal : Palette.text.opacity(0.85))
                        }
                        if let next { Text(remaining(next, now: context.date)).font(.system(size: 10)).foregroundStyle(Palette.muted) }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func remaining(_ time: PrayerTime, now: Date) -> String {
        L10n.format("%@ qoldi", ScreenTimeFormat.duration(time.date.timeIntervalSince(now)))
    }
}
