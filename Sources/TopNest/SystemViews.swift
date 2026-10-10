import SwiftUI

// "Tizim": bir kartada bir nechta ko'rsatkich. Kichik — CPU va RAM, o'rta — CPU/RAM/GPU/tarmoq,
// katta — qo'shimcha disk, batareya salomatligi va eng ko'p CPU olayotgan jarayonlar.
struct SystemWidget: View {
    let id: UUID
    @ObservedObject var stats: SystemStatsService
    let size: WidgetSize

    private var kinds: Set<WidgetKind> {
        switch size {
        case .small: [.cpu, .memory]
        case .medium: [.cpu, .memory, .gpu, .network]
        case .large: [.cpu, .memory, .gpu, .network, .system]
        }
    }

    var body: some View {
        WidgetCard(title: "Tizim", icon: "gauge.with.dots.needle.33percent", accent: Palette.accent, showHeader: size == .large) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    gauge("CPU", stats.cpu)
                    gauge("RAM", stats.memoryUsed > 0 ? stats.memoryFraction : nil)
                    if size != .small {
                        gauge("GPU", stats.gpu)
                        network
                    }
                }
                .frame(maxHeight: size == .large ? 44 : .infinity)
                if size == .large { extras }
            }
        }
        .onAppear { stats.retain(id, kinds: kinds) }
        .onChange(of: size) { stats.retain(id, kinds: kinds) }
        .onDisappear { stats.release(id) }
    }

    private func color(_ value: Double) -> Color {
        value > 0.85 ? Palette.danger : (value > 0.6 ? Palette.warning : Palette.accent)
    }

    private func gauge(_ label: String, _ value: Double?) -> some View {
        VStack(spacing: 2) {
            RingGauge(value: value ?? 0, color: color(value ?? 0), lineWidth: 4,
                      label: value.map { "\(Int(($0 * 100).rounded()))" } ?? "—")
                .aspectRatio(1, contentMode: .fit)
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value.map { "\(Int(($0 * 100).rounded()))%" } ?? L10n.tr("Ma’lumot yo‘q"))
    }

    private var network: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(stats.download?.byteRate ?? "—", systemImage: "arrow.down").foregroundStyle(Palette.accent)
            Label(stats.upload?.byteRate ?? "—", systemImage: "arrow.up").foregroundStyle(Palette.warning)
        }
        .font(.system(size: 10, weight: .semibold).monospacedDigit())
        .labelStyle(CompactLabelStyle())
        .lineLimit(1).minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var extras: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let disk = stats.disk {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive").font(.system(size: 10)).foregroundStyle(Palette.muted).frame(width: 14)
                    Text(L10n.format("%@ bo‘sh", ByteCountFormatter.string(fromByteCount: disk.free, countStyle: .file)))
                        .font(.system(size: 11, weight: .medium)).lineLimit(1)
                    ProgressBar(value: disk.usedFraction, color: color(disk.usedFraction))
                }
                .accessibilityElement(children: .combine)
            }
            if let battery = stats.battery {
                HStack(spacing: 6) {
                    Image(systemName: battery.capacity < 0.8 ? "battery.50percent" : "battery.100percent").font(.system(size: 10)).foregroundStyle(Palette.muted).frame(width: 14)
                    Text(L10n.format("Batareya salomatligi %d%% · %d sikl", Int((battery.capacity * 100).rounded()), battery.cycles))
                        .font(.system(size: 11)).lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(battery.capacity < 0.8 ? Palette.warning : Palette.text.opacity(0.85))
                }
                .accessibilityElement(children: .combine)
            }
            // Batareya qatori bo'lsa 2 jarayon: katta katakka sig'ishi uchun.
            ForEach(stats.topProcesses.prefix(stats.battery == nil ? 3 : 2)) { process in
                HStack(spacing: 6) {
                    Text(process.name).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(String(format: "%.0f%%", process.cpu)).font(.system(size: 10, weight: .semibold).monospacedDigit())
                }
                .help(L10n.format("%@ — %@ xotira", process.name, ByteCountFormatter.string(fromByteCount: process.memory, countStyle: .memory)))
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) { configuration.icon.font(.system(size: 8, weight: .bold)); configuration.title }
    }
}
