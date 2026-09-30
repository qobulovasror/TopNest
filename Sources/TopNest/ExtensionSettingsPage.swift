import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ExtensionSettingsPage: View {
    @ObservedObject var state: AppState
    @ObservedObject var widgets: WidgetStore
    @StateObject private var catalog = ExtensionCatalogStore()
    @State private var pendingPackage: ExtensionPackage?
    @State private var busyID: String?
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Text("TopNest katalogidagi widgetlarni tanlang. O‘rnatishdan oldin manba va kerakli ruxsatlar ko‘rsatiladi.")
                    .font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Paket faylini import…", action: importPackage)
                    Button("Katalogni yangilash") { Task { await catalog.refresh(); await prepareRequestedExtension() } }
                        .disabled(catalog.isLoading)
                }
                if catalog.isLoading { ProgressView { Text("Katalog yuklanmoqda…") } }
                if let error = catalog.errorMessage {
                    Text(error).foregroundStyle(.orange).font(.footnote)
                }
                if catalog.entries.isEmpty && !catalog.isLoading && catalog.errorMessage == nil {
                    Text("Hozircha extension yo‘q").foregroundStyle(.secondary)
                }
                ForEach(catalog.entries) { entry in
                    catalogRow(entry)
                }
            } header: {
                Text("Katalog")
            } footer: {
                Text("Katalog internet orqali yuklanadi. Saytdagi O‘rnatish tugmasi TopNest’ni ochadi; hech narsa siz tasdiqlamaguncha o‘rnatilmaydi.")
                    .font(.footnote)
            }
            let installed = widgets.widgets.filter { $0.extensionID != nil }
            if !installed.isEmpty {
                Section("O‘rnatilganlar") {
                    ForEach(installed) { widget in
                        HStack {
                            Image(systemName: widget.icon).frame(width: 22)
                            VStack(alignment: .leading) {
                                Text(widget.title)
                                Text(verbatim: "v\(widget.extensionVersion ?? "—") · \(widget.extensionID ?? "")")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button("O‘chirish", role: .destructive) { _ = widgets.remove(widget.id) }
                        }
                    }
                }
            }
            if let message { Text(message).font(.footnote).foregroundStyle(.orange) }
        }
        .formStyle(.grouped)
        .task {
            await catalog.refresh()
            await prepareRequestedExtension()
        }
        .onChange(of: state.pendingExtensionID) { _, _ in
            Task { await prepareRequestedExtension() }
        }
        .sheet(item: $pendingPackage) { package in
            installPreview(package)
        }
    }

    private func catalogRow(_ entry: ExtensionCatalogEntry) -> some View {
        let installed = widgets.installedExtension(entry.id)
        let hasUpdate = installed.flatMap { ExtensionVersion($0.extensionVersion ?? "") }
            .map { $0 < ExtensionVersion(entry.version)! } ?? false
        return HStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension").font(.title2).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name).fontWeight(.semibold)
                Text(entry.summary).font(.caption).foregroundStyle(.secondary)
                Text("\(entry.author) · v\(entry.version)").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if busyID == entry.id { ProgressView().controlSize(.small) }
            else {
                Button(L10n.tr(installed == nil ? "O‘rnatish" : (hasUpdate ? "Yangilash" : "O‘rnatilgan"))) {
                    Task { await prepare(entry) }
                }
                .disabled(installed != nil && !hasUpdate)
            }
        }
        .padding(.vertical, 4)
    }

    private func prepareRequestedExtension() async {
        guard let id = state.pendingExtensionID else { return }
        guard let entry = catalog.entries.first(where: { $0.id == id }) else {
            if !catalog.isLoading && catalog.errorMessage == nil {
                message = L10n.tr("Extension katalogda topilmadi")
                state.pendingExtensionID = nil
            }
            return
        }
        state.pendingExtensionID = nil
        await prepare(entry)
    }

    private func prepare(_ entry: ExtensionCatalogEntry) async {
        guard busyID == nil else { return }
        busyID = entry.id
        defer { busyID = nil }
        do {
            pendingPackage = try await catalog.package(for: entry, currentVersion: SettingsWindowView.appVersion)
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    private func importPackage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= 128_000 else { throw ExtensionInstallError.invalidPackage }
            guard let package = try? JSONDecoder().decode(ExtensionPackage.self, from: data) else {
                throw ExtensionInstallError.invalidPackage
            }
            pendingPackage = try package.validated(currentVersion: SettingsWindowView.appVersion)
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    private func installPreview(_ package: ExtensionPackage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(package.widget.title).font(.title2.bold())
                Text(package.summary).foregroundStyle(.secondary)
                LabeledContent("Muallif", value: package.author)
                LabeledContent("Versiya", value: package.version)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ma’lumot manbasi").font(.caption).foregroundStyle(.secondary)
                    Text(package.widget.target).font(.callout).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LabeledContent("Yangilanish oralig‘i", value: "\(package.widget.refreshSeconds) s")
                Text("Bu widget ko‘rsatilgan HTTPS manzilga muntazam so‘rov yuboradi. Shell buyrug‘i bajarilmaydi.")
                    .font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Bekor qilish") { pendingPackage = nil }
                    Button(L10n.tr(widgets.installedExtension(package.id) == nil ? "O‘rnatish" : "Yangilash")) {
                        widgets.install(package)
                        pendingPackage = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
        .frame(width: 490, height: 420)
    }
}
