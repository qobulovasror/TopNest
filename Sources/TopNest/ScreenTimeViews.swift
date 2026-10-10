import AppKit
import Charts
import SwiftUI

// Ekran vaqti: kichik — bugungi jami, o'rta — top-3 ilova, katta — haftalik grafik va top-3.
struct ScreenTimeWidget: View {
    @ObservedObject var tracker: ScreenTimeTracker
    let size: WidgetSize

    var body: some View {
        WidgetCard(title: "Ekran vaqti", icon: "hourglass", accent: .indigo, showHeader: false) {
            TimelineView(.everyMinute) { context in
                let total = tracker.ledger.total(on: context.date)
                switch size {
                case .small:
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bugun").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted)
                        Text(ScreenTimeFormat.duration(total)).font(.system(size: 22, weight: .semibold).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                case .medium:
                    topApps(on: context.date, limit: 2, total: total)
                case .large:
                    VStack(alignment: .leading, spacing: 6) {
                        WeekChart(week: tracker.ledger.week(endingAt: context.date)).frame(height: 56)
                        topApps(on: context.date, limit: 3, total: total)
                    }
                }
            }
        }
    }

    private func topApps(on date: Date, limit: Int, total: Double) -> some View {
        let apps = tracker.ledger.top(on: date, limit: limit)
        let maximum = apps.first?.seconds ?? 1
        // Sarlavha o'rnida: ikonka va bugungi jami (alohida sarlavha qatori joy olmaydi).
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "hourglass").font(.system(size: 11)).foregroundStyle(.indigo).accessibilityHidden(true)
                Text(L10n.format("Bugun: %@", ScreenTimeFormat.duration(total))).font(.system(size: 11, weight: .semibold))
                Spacer()
            }
            if apps.isEmpty {
                EmptyHint("Hali hisoblanmagan.")
            }
            ForEach(apps, id: \.bundleID) { app in
                HStack(spacing: 6) {
                    AppIcon(bundleID: app.bundleID).frame(width: 14, height: 14)
                    Text(tracker.ledger.names[app.bundleID] ?? app.bundleID).font(.system(size: 11)).lineLimit(1)
                        .frame(width: 92, alignment: .leading)
                    ProgressBar(value: app.seconds / maximum, color: .indigo)
                    Text(ScreenTimeFormat.duration(app.seconds)).font(.system(size: 10).monospacedDigit()).foregroundStyle(Palette.muted)
                        .lineLimit(1).fixedSize()
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
        }
    }
}

struct WeekChart: View {
    let week: [(day: Date, seconds: Double)]

    var body: some View {
        Chart(week, id: \.day) { entry in
            BarMark(x: .value("Kun", entry.day, unit: .day), y: .value("Soat", entry.seconds / 3600))
                .foregroundStyle(Calendar.current.isDateInToday(entry.day) ? Color.indigo : Color.indigo.opacity(0.45))
                .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow)).font(.system(size: 9))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { value in
                AxisGridLine().foregroundStyle(Palette.outline)
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text(hours < 2 && hours != hours.rounded() ? L10n.format("%d daq", Int(hours * 60)) : L10n.format("%.0f s", hours)).font(.system(size: 9))
                    }
                }
            }
        }
        .accessibilityLabel(L10n.tr("Oxirgi 7 kunlik ekran vaqti"))
    }
}

private struct AppIcon: View {
    let bundleID: String

    // LaunchServices so'rovi har chizishda takrorlanmaydi.
    @MainActor private static var cache: [String: NSImage?] = [:]

    var body: some View {
        if let image = Self.icon(for: bundleID) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "app").foregroundStyle(Palette.muted)
        }
    }

    @MainActor private static func icon(for bundleID: String) -> NSImage? {
        if let cached = cache[bundleID] { return cached }
        let image = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
        cache[bundleID] = image
        return image
    }
}
