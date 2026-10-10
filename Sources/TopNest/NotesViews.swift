import AppKit
import SwiftUI

// "Qaydlar" tabi: chapda qidiruv va ro'yxat, o'ngda tahrirlagich.
struct NotesContent: View {
    @ObservedObject var notes: NotesStore
    @State private var query = ""
    @State private var handledFocus = 0
    @FocusState private var editorFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            sidebar.frame(width: 200)
            editor
        }
        .padding(.horizontal, 16)
        .onAppear(perform: focusIfRequested)
        .onChange(of: notes.focusRequest) { focusIfRequested() }
    }

    private var sidebar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(Palette.muted).accessibilityHidden(true)
                    TextField("Qidirish", text: $query).textFieldStyle(.plain).font(.system(size: 12))
                }
                .padding(.horizontal, 8).frame(height: 26)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 8))
                Button { query = ""; notes.create() } label: {
                    Image(systemName: "square.and.pencil").font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 26).background(Palette.softFill, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.tr("Yangi qayd (⌃⌥⌘J)"))
                .accessibilityLabel(L10n.tr("Yangi qayd"))
            }
            let list = notes.filtered(query)
            if list.isEmpty {
                Spacer()
                EmptyHint(query.isEmpty ? "Hali qayd yo‘q. Yangi qayd yarating yoki matnni notchga sudrab tashlang." : "Hech narsa topilmadi.")
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(list) { note in row(note) }
                    }
                }
                .scrollIndicators(.hidden)
            }
            if let deleted = notes.lastDeleted {
                HStack(spacing: 6) {
                    Text(L10n.format("“%@” o‘chirildi", deleted.title)).lineLimit(1).foregroundStyle(Palette.muted)
                    Spacer(minLength: 0)
                    Button("Qaytarish") { notes.undoDelete() }.buttonStyle(.plain).foregroundStyle(Palette.accent)
                }
                .font(.system(size: 11, weight: .medium))
            }
        }
    }

    private func row(_ note: Note) -> some View {
        let selected = note.id == notes.selectedID
        return Button { notes.select(note.id) } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if note.pinned {
                        Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(.orange).accessibilityLabel(L10n.tr("Mahkamlangan"))
                    }
                    Text(note.title.isEmpty ? L10n.tr("Yangi qayd") : note.title)
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        .foregroundStyle(note.title.isEmpty ? Palette.muted : Palette.text)
                }
                Text(note.preview.isEmpty ? note.updatedAt.formatted(date: .abbreviated, time: .shortened) : note.preview)
                    .font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Palette.accent.opacity(0.18) : Palette.card, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(note.pinned ? "Mahkamlashni bekor qilish" : "Mahkamlash") { notes.togglePin(note.id) }
            Button("Nusxalash") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(note.text, forType: .string)
            }
            Divider()
            Button("O‘chirish", role: .destructive) { notes.delete(note.id) }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var editor: some View {
        if let note = notes.selected {
            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: Binding(get: { notes.selected?.text ?? "" }, set: { notes.update(note.id, text: $0) }))
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .focused($editorFocused)
                        // Har qayd o'z tahrirlagichi: Cmd-Z tarixi boshqa qaydga o'tmaydi.
                        .id(note.id)
                        .accessibilityLabel(L10n.tr("Qayd matni"))
                    if note.text.isEmpty {
                        Text("Yozishni boshlang… Birinchi qator sarlavha bo‘ladi.")
                            .font(.system(size: 13)).foregroundStyle(Palette.muted)
                            .padding(.leading, 5).allowsHitTesting(false)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                HStack {
                    Text(L10n.format("%d belgi · avtomatik saqlanadi", note.text.count))
                    Spacer()
                    Button { notes.togglePin(note.id) } label: { Image(systemName: note.pinned ? "pin.slash" : "pin") }
                        .accessibilityLabel(L10n.tr(note.pinned ? "Mahkamlashni bekor qilish" : "Mahkamlash"))
                    Button { notes.delete(note.id) } label: { Image(systemName: "trash") }
                        .accessibilityLabel(L10n.tr("O‘chirish"))
                }
                .buttonStyle(.plain)
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "note.text").font(.system(size: 22)).foregroundStyle(Palette.muted)
                SmallAction("Yangi qayd") { notes.create() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func focusIfRequested() {
        guard notes.focusRequest != handledFocus else { return }
        handledFocus = notes.focusRequest
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { editorFocused = true }
    }
}

// Widget: mahkamlangan yoki oxirgi qayd. Katta o'lchamda shu yerning o'zida tahrirlanadi.
struct NotesWidget: View {
    @ObservedObject var notes: NotesStore
    let size: WidgetSize
    let onOpen: (UUID?) -> Void
    let onNew: () -> Void
    // Tahrir paytida matn o'chirilsa ham boshqa qaydga sakramasin.
    @State private var editingID: UUID?

    var body: some View {
        WidgetCard(title: "Qaydlar", icon: "note.text", accent: .yellow) {
            VStack(alignment: .leading, spacing: 4) {
                if let note = notes.notes.first(where: { $0.id == editingID }) ?? notes.featured {
                    if size == .large {
                        TextEditor(text: Binding(get: { notes.notes.first { $0.id == note.id }?.text ?? "" },
                                                 set: { editingID = note.id; notes.update(note.id, text: $0) }))
                            .font(.system(size: 12))
                            .scrollContentBackground(.hidden)
                            .accessibilityLabel(L10n.tr("Qayd matni"))
                    } else {
                        Button { onOpen(note.id) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                if size != .small || note.preview.count < 40 {
                                    Text(note.preview).font(.system(size: 11)).foregroundStyle(Palette.muted)
                                        .lineLimit(size == .small ? 1 : 2)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.format("Qaydni ochish: %@", note.title))
                    }
                } else {
                    EmptyHint("Tezkor qaydlar shu yerda ko‘rinadi.")
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    SmallAction("Yangi qayd", action: onNew)
                    Spacer(minLength: 0)
                    if notes.notes.count > 1 {
                        SmallAction("Hammasi") { onOpen(nil) }
                    }
                }
            }
        }
    }
}
