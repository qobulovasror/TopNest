import SwiftUI

// Bluetooth qurilmalar: kichikda eng kam zaryadlisi, o'rta/kattada 3 yoki 6 tagacha qurilma halqa bilan.
struct DeviceBatteryWidget: View {
    @ObservedObject var service: DeviceBatteryService
    @ObservedObject var power: PowerService
    let size: WidgetSize
    var includeMac = false

    private struct Row: Identifiable {
        let id: String
        let name: String
        let icon: String
        let percent: Int
        let detail: String?
        var charging = false
    }

    private var rows: [Row] {
        var rows = service.devices.compactMap { device -> Row? in
            guard let percent = device.percent else { return nil }
            let parts = device.batteries.filter { $0.part != .main }
            let detail = parts.isEmpty ? nil : parts.map { "\($0.label) \($0.percent)%" }.joined(separator: " · ")
            return Row(id: device.id, name: device.name, icon: device.kind.icon, percent: percent, detail: detail)
        }
        if includeMac, let percent = power.percent {
            rows.insert(Row(id: "mac", name: "Mac", icon: "laptopcomputer", percent: percent, detail: nil, charging: power.charging), at: 0)
        }
        // Eng kam zaryadli tepada: o'rta kartada 2 qator sig'adi, muhimi ko'rinib tursin.
        return rows.sorted { ($0.percent, $0.name) < ($1.percent, $1.name) }
    }

    var body: some View {
        let rows = rows
        WidgetCard(title: "Qurilmalar", icon: "dot.radiowaves.left.and.right", accent: Palette.accent, showHeader: size != .small) {
            if size == .small, let lowest = rows.min(by: { $0.percent < $1.percent }) {
                HStack(spacing: 10) {
                    RingGauge(value: Double(lowest.percent) / 100, color: color(lowest.percent), lineWidth: 5)
                        .overlay(Image(systemName: lowest.icon).font(.system(size: 13)).foregroundStyle(Palette.text.opacity(0.85)))
                        .aspectRatio(1, contentMode: .fit)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(lowest.percent)%").font(.system(size: 18, weight: .semibold).monospacedDigit()).foregroundStyle(color(lowest.percent))
                        Text(lowest.name).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(rows.prefix(size == .large ? 6 : 2)) { row in
                        HStack(spacing: 7) {
                            Image(systemName: row.icon).font(.system(size: 12)).frame(width: 18).foregroundStyle(Palette.muted)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(row.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                if let detail = row.detail, size == .large {
                                    Text(detail).font(.system(size: 10).monospacedDigit()).foregroundStyle(Palette.muted).lineLimit(1)
                                }
                            }
                            Spacer(minLength: 4)
                            if row.charging {
                                Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(.green).accessibilityLabel(L10n.tr("Zaryadlanmoqda"))
                            }
                            Text("\(row.percent)%").font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundStyle(color(row.percent))
                            ProgressBar(value: Double(row.percent) / 100, color: color(row.percent)).frame(width: 34)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func color(_ percent: Int) -> Color {
        percent <= DeviceBatteryService.lowThreshold ? Palette.danger : (percent <= 40 ? Palette.warning : Palette.accent)
    }
}
