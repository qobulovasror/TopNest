import SwiftUI

extension FocusPhase {
    var color: Color {
        switch self {
        case .timer: .orange
        case .work: Palette.danger
        case .shortBreak, .longBreak: Palette.accent
        }
    }
}

// Taymer va Pomodoro: bo'sh holatda tayyor tugmalar, ishlayotganda halqa, vaqt va boshqaruv.
struct FocusTimerWidget: View {
    @ObservedObject var focus: FocusTimerService
    let size: WidgetSize

    var body: some View {
        WidgetCard(title: focus.session?.phase.titleKey ?? "Taymer", icon: "timer", accent: focus.session?.phase.color ?? .orange,
                   showHeader: focus.session == nil || size == .large) {
            if let session = focus.session {
                running(session)
            } else {
                idle
            }
        }
    }

    // MARK: Bo'sh holat

    private var idle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                ForEach(size == .small ? Array(FocusTimerService.presets.prefix(2)) : FocusTimerService.presets, id: \.self) { minutes in
                    // Kichik kartada faqat raqam: "10 daq" sig'maydi.
                    chip(size == .small ? "\(minutes)′" : L10n.format("%d daq", minutes)) { focus.startTimer(minutes: minutes) }
                        .accessibilityLabel(L10n.format("%d daqiqalik taymer", minutes))
                }
                chip("🍅", prominent: true) { focus.startPomodoro() }
                    .help(L10n.format("Pomodoro: %d daqiqa diqqat", focus.settings.workMinutes))
                    .accessibilityLabel(L10n.tr("Pomodoro boshlash"))
            }
            if size == .large {
                Text(L10n.format("Pomodoro: %d daq diqqat, %d daq tanaffus. ⌃⌥⌘T — boshlash/pauza.", focus.settings.workMinutes, focus.settings.shortBreakMinutes))
                    .font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ text: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 11, weight: .semibold).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 8).frame(height: 24)
                .frame(maxWidth: .infinity)
                .background(prominent ? Palette.danger.opacity(0.18) : Palette.softFill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Ishlayotgan holat

    @ViewBuilder
    private func running(_ session: FocusSession) -> some View {
        TimelineView(.periodic(from: session.tickStart(), by: 1)) { context in
            let remaining = session.remaining(at: context.date)
            let ring = RingGauge(value: session.progress(at: context.date), color: session.phase.color,
                                 lineWidth: size == .large ? 7 : 5, label: size == .small ? FocusFormat.short(remaining) : nil)
                .aspectRatio(1, contentMode: .fit)
                .opacity(session.isPaused ? 0.6 : 1)
            if size == .large {
                VStack(spacing: 8) {
                    ring.frame(maxHeight: .infinity).overlay { timeText(remaining, session: session, size: 24) }
                    controls(session)
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 10) {
                    ring.frame(maxHeight: .infinity)
                    if size == .medium {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.phase.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(session.phase.color)
                            timeText(remaining, session: session, size: 22)
                            if session.phase.isPomodoro { cycleDots(session) }
                        }
                        .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    controls(session)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func timeText(_ remaining: TimeInterval, session: FocusSession, size: CGFloat) -> some View {
        Text(FocusFormat.short(remaining))
            .font(.system(size: size, weight: .semibold).monospacedDigit())
            .foregroundStyle(session.isPaused ? Palette.muted : Palette.text)
            .minimumScaleFactor(0.6)
            .accessibilityLabel(L10n.format("Qolgan vaqt: %@", FocusFormat.short(remaining)))
    }

    private func cycleDots(_ session: FocusSession) -> some View {
        let total = max(1, focus.settings.cyclesBeforeLongBreak)
        let done = session.completedWork % total
        return HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                Circle().fill(index < done ? Palette.danger : Palette.outline).frame(width: 5, height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.format("%d / %d diqqat bosqichi", done, total))
    }

    @ViewBuilder
    private func controls(_ session: FocusSession) -> some View {
        let layout = size == .small ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
        layout {
            control(session.isRunning ? "pause.fill" : "play.fill", label: session.isRunning ? "Pauza" : "Davom ettirish") { focus.toggle() }
            if size != .small {
                control("goforward.plus", label: "1 daqiqa qo‘shish") { focus.add(minutes: 1) }
                if session.phase.isPomodoro {
                    control("forward.end.fill", label: "Keyingi bosqich") { focus.skip() }
                }
            }
            control("stop.fill", label: "To‘xtatish") { focus.stop() }
        }
    }

    private func control(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Palette.softFill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(L10n.tr(label))
        .accessibilityLabel(L10n.tr(label))
    }
}

// Compact qanot: chapda progress halqasi, o'ngda qolgan vaqt (har soniya faqat shu view chiziladi).
struct FocusWingRing: View {
    let session: FocusSession

    var body: some View {
        TimelineView(.periodic(from: session.tickStart(), by: 1)) { context in
            RingGauge(value: session.progress(at: context.date), color: session.phase.color, lineWidth: 2.5)
                .frame(width: 15, height: 15)
                .opacity(session.isPaused ? 0.5 : 1)
        }
    }
}

struct FocusWingTime: View {
    let session: FocusSession

    var body: some View {
        TimelineView(.periodic(from: session.tickStart(), by: 1)) { context in
            Text(FocusFormat.short(session.remaining(at: context.date)))
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(session.isPaused ? Palette.compactMuted : session.phase.color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}
