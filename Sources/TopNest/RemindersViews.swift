import SwiftUI

// Vazifa qatori: doira bosilsa bajarilgan deb belgilanadi, 1,5 s chizilgan holda turadi.
struct TaskRow: View {
    @ObservedObject var reminders: RemindersService
    let item: TaskItem
    var now = Date()
    var compact = false
    var showList = false

    var body: some View {
        let completing = reminders.isCompleting(item)
        HStack(spacing: 7) {
            Button { completing ? reminders.undoComplete(item) : reminders.complete(item) } label: {
                Image(systemName: completing ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 13 : 15))
                    .foregroundStyle(completing ? Palette.accent : (item.priority == 1 ? Palette.danger : Palette.muted))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.format(completing ? "Bajarilmagan deb belgilash: %@" : "Bajarildi deb belgilash: %@", item.title))
            if showList, let list = reminders.list(item.listID) {
                Circle().fill(Color(nsColor: list.color)).frame(width: 6, height: 6).accessibilityHidden(true)
            }
            Text(item.title)
                .font(.system(size: compact ? 11 : 12))
                .strikethrough(completing)
                .foregroundStyle(completing ? Palette.muted : Palette.text.opacity(0.9))
                .lineLimit(1)
            Spacer(minLength: 4)
            if let label = TaskDueFormat.label(item, now: now) {
                Text(label)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(item.isOverdue(at: now) ? Palette.danger : Palette.muted)
                    .lineLimit(1)
            }
        }
        .animation(.easeOut(duration: 0.2), value: completing)
    }
}

enum TaskDueFormat {
    // Qisqa muddat yorlig'i: bugun — vaqt yoki "Bugun", kecha/ertaga, boshqa kunlar — sana.
    static func label(_ item: TaskItem, now: Date, calendar: Calendar = .current) -> String? {
        guard let due = item.due else { return nil }
        if calendar.isDate(due, inSameDayAs: now) {
            return item.hasTime ? due.formatted(date: .omitted, time: .shortened) : L10n.tr("Bugun")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(due, inSameDayAs: yesterday) {
            return L10n.tr("Kecha")
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(due, inSameDayAs: tomorrow) {
            return L10n.tr("Ertaga")
        }
        return due.formatted(.dateTime.day().month(.abbreviated))
    }
}

struct TaskQuickAdd: View {
    @ObservedObject var reminders: RemindersService
    let dueToday: Bool
    @State private var text = ""

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill").foregroundStyle(Palette.accent).accessibilityHidden(true)
            TextField(dueToday ? L10n.tr("Bugungi vazifa qo‘shish") : L10n.tr("Vazifa qo‘shish"), text: $text)
                .textFieldStyle(.plain).font(.system(size: 12))
                .onSubmit {
                    if reminders.add(text, dueToday: dueToday) { text = "" }
                }
        }
        .padding(.horizontal, 8).frame(height: 26)
        .background(Palette.softFill, in: RoundedRectangle(cornerRadius: 8))
    }
}

// Widget: muddati o'tgan, bugungi va muddatsiz vazifalar; o'rta/katta o'lchamda tez qo'shish.
struct TasksWidget: View {
    @ObservedObject var reminders: RemindersService
    let size: WidgetSize
    let onOpen: () -> Void

    // Kataklarga sig'ishi uchun: kichik — 2 qator, o'rta — sarlavhasiz 1 qator + qo'shish, katta — 4 qator + qo'shish + "Hammasi".
    private var limit: Int { size == .large ? 4 : (size == .medium ? 1 : 2) }

    var body: some View {
        WidgetCard(title: "Vazifalar", icon: "checklist", accent: Palette.accent, showHeader: size != .medium) {
            TimelineView(.everyMinute) { context in
                let visible = TaskOrdering.focus(reminders.items, now: context.date).prefix(limit)
                VStack(alignment: .leading, spacing: size == .small ? 3 : 4) {
                    if visible.isEmpty {
                        EmptyHint("Bajarilmagan vazifa yo‘q.")
                    }
                    ForEach(visible) { item in
                        TaskRow(reminders: reminders, item: item, now: context.date, compact: size == .small)
                    }
                    Spacer(minLength: 0)
                    if size != .small {
                        TaskQuickAdd(reminders: reminders, dueToday: true)
                    }
                    if size == .large {
                        HStack {
                            let rest = reminders.items.count - visible.count
                            if rest > 0 { Text(L10n.format("Yana %d ta", rest)).font(.system(size: 10)).foregroundStyle(Palette.muted) }
                            Spacer()
                            SmallAction("Hammasi", action: onOpen)
                        }
                    }
                }
            }
        }
    }
}

// "Vazifalar" tabi: ro'yxat tanlash, barcha bajarilmagan vazifalar va qo'shish.
struct TasksContent: View {
    @ObservedObject var reminders: RemindersService
    let onSetup: (SetupAction) -> Void
    @State private var listFilter = ""

    var body: some View {
        Group {
            switch reminders.access {
            case .granted: content
            case .notDetermined: permission(L10n.tr("Apple Eslatmalar’dagi vazifalarni ko‘rsatish uchun ruxsat kerak."), action: .requestRemindersAccess)
            case .denied: permission(L10n.tr("Eslatmalar ruxsati rad etilgan. Uni Tizim sozlamalarida yoqing."), action: .openRemindersPrivacy)
            }
        }
        .padding(.horizontal, 16)
        .onAppear { reminders.refresh() }
    }

    private var filtered: [TaskItem] {
        let items = listFilter.isEmpty ? reminders.items : reminders.items.filter { $0.listID == listFilter }
        return TaskOrdering.focus(items, now: Date())
    }

    private var content: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker("Ro‘yxat", selection: $listFilter) {
                    Text("Barcha ro‘yxatlar").tag("")
                    ForEach(reminders.lists) { list in Text(list.title).tag(list.id) }
                }
                .labelsHidden()
                .frame(width: 170)
                TaskQuickAdd(reminders: reminders, dueToday: false)
                Button { reminders.openInReminders() } label: { Image(systemName: "arrow.up.forward.app") }
                    .buttonStyle(.plain).foregroundStyle(Palette.muted)
                    .help(L10n.tr("Eslatmalar ilovasida ochish"))
                    .accessibilityLabel(L10n.tr("Eslatmalar ilovasida ochish"))
            }
            TimelineView(.everyMinute) { context in
            if filtered.isEmpty {
                Spacer()
                EmptyHint("Bajarilmagan vazifa yo‘q.")
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filtered) { item in
                            TaskRow(reminders: reminders, item: item, now: context.date, showList: listFilter.isEmpty)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Palette.card, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            }
            if let error = reminders.errorMessage {
                Text(error).font(.system(size: 11)).foregroundStyle(Palette.warning).lineLimit(1)
            }
        }
    }

    private func permission(_ text: String, action: SetupAction) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist").font(.system(size: 22)).foregroundStyle(Palette.muted)
            Text(text).font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            Button(action.title) { onSetup(action) }
                .buttonStyle(.borderedProminent).tint(Palette.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
