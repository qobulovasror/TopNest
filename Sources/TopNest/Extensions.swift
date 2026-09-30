import CryptoKit
import Foundation

struct ExtensionVersion: Comparable, Equatable {
    let parts: [Int]

    init?(_ value: String) {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3,
              components.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              components.allSatisfy({ Int($0) != nil }) else { return nil }
        parts = components.compactMap { Int($0) }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.parts.lexicographicallyPrecedes(rhs.parts)
    }
}

enum ExtensionInstallError: Error, LocalizedError {
    case invalidPackage, incompatibleVersion, unsupportedSource, invalidCatalog, downloadFailed, hashMismatch

    var errorDescription: String? {
        switch self {
        case .invalidPackage: L10n.tr("Extension paketi noto‘g‘ri")
        case .incompatibleVersion: L10n.tr("TopNest versiyasi bu extension uchun eski")
        case .unsupportedSource: L10n.tr("Sayt orqali faqat HTTPS widgetlar o‘rnatiladi")
        case .invalidCatalog: L10n.tr("Extension katalogi noto‘g‘ri")
        case .downloadFailed: L10n.tr("Extensionni yuklab bo‘lmadi")
        case .hashMismatch: L10n.tr("Yuklangan paket tekshiruvdan o‘tmadi")
        }
    }
}

enum ExtensionInstallLink {
    static func id(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "topnest", url.host == "install",
              url.path.isEmpty || url.path == "/",
              url.user == nil, url.password == nil, url.port == nil, url.fragment == nil,
              let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              query.count == 1, query[0].name == "id",
              let id = query[0].value, ExtensionPackage.validID(id) else { return nil }
        return id
    }
}

struct ExtensionPackage: Codable, Equatable, Identifiable {
    let schemaVersion: Int
    let id: String
    let version: String
    let minTopNestVersion: String
    let author: String
    let summary: String
    var widget: CustomWidgetSpec

    func validated(currentVersion: String) throws -> Self {
        guard schemaVersion == 1,
              Self.validID(id),
              ExtensionVersion(version) != nil,
              !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, author.count <= 80,
              !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, summary.count <= 300,
              let minimum = ExtensionVersion(minTopNestVersion),
              let current = ExtensionVersion(currentVersion) else { throw ExtensionInstallError.invalidPackage }
        guard current >= minimum else { throw ExtensionInstallError.incompatibleVersion }
        guard widget.source == .url else { throw ExtensionInstallError.unsupportedSource }
        guard let spec = widget.normalized(),
              spec.title.count <= 80,
              spec.target.count <= 2048,
              let url = URL(string: spec.target),
              url.scheme?.lowercased() == "https", url.host != nil,
              url.user == nil, url.password == nil else { throw ExtensionInstallError.invalidPackage }
        var result = self
        result.widget = spec
        return result
    }

    static func validID(_ id: String) -> Bool {
        id.count <= 120 && id.range(of: #"^[a-z0-9]+(?:[.-][a-z0-9]+)+$"#, options: .regularExpression) != nil
    }
}

struct ExtensionCatalogEntry: Codable, Identifiable, Equatable {
    let id: String
    let version: String
    let name: String
    let summary: String
    let author: String
    let packageURL: URL
    let sha256: String

    func validated() throws -> Self {
        guard ExtensionPackage.validID(id), ExtensionVersion(version) != nil,
              !name.isEmpty, name.count <= 80,
              !summary.isEmpty, summary.count <= 300,
              !author.isEmpty, author.count <= 80,
              packageURL.scheme?.lowercased() == "https", packageURL.host != nil,
              packageURL.user == nil, packageURL.password == nil, packageURL.fragment == nil,
              sha256.count == 64, sha256.allSatisfy({ $0.isHexDigit }) else {
            throw ExtensionInstallError.invalidCatalog
        }
        return self
    }
}

struct ExtensionCatalogDocument: Codable {
    let schemaVersion: Int
    let extensions: [ExtensionCatalogEntry]

    func validated() throws -> [ExtensionCatalogEntry] {
        guard schemaVersion == 1 else { throw ExtensionInstallError.invalidCatalog }
        let entries = try extensions.map { try $0.validated() }
        guard Set(entries.map(\.id)).count == entries.count else { throw ExtensionInstallError.invalidCatalog }
        return entries
    }
}

enum ExtensionDownload {
    static let catalogURL = URL(string: "https://qobulovasror.github.io/TopNest-site/extensions/catalog.json")!

    static func fetch(_ url: URL, maxBytes: Int) async throws -> Data {
        guard url.scheme?.lowercased() == "https", url.host != nil else { throw ExtensionInstallError.downloadFailed }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("TopNest", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              response.url?.scheme?.lowercased() == "https" else { throw ExtensionInstallError.downloadFailed }
        var data = Data()
        data.reserveCapacity(min(maxBytes, 128_000))
        for try await byte in bytes {
            guard data.count < maxBytes else { throw ExtensionInstallError.downloadFailed }
            data.append(byte)
        }
        return data
    }

    static func decodePackage(_ data: Data, entry: ExtensionCatalogEntry, currentVersion: String) throws -> ExtensionPackage {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == entry.sha256.lowercased() else { throw ExtensionInstallError.hashMismatch }
        guard let decoded = try? JSONDecoder().decode(ExtensionPackage.self, from: data) else {
            throw ExtensionInstallError.invalidPackage
        }
        let package = try decoded.validated(currentVersion: currentVersion)
        guard package.id == entry.id, package.version == entry.version else { throw ExtensionInstallError.invalidPackage }
        return package
    }
}

@MainActor
final class ExtensionCatalogStore: ObservableObject {
    @Published private(set) var entries: [ExtensionCatalogEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await ExtensionDownload.fetch(ExtensionDownload.catalogURL, maxBytes: 256_000)
            guard let catalog = try? JSONDecoder().decode(ExtensionCatalogDocument.self, from: data) else {
                throw ExtensionInstallError.invalidCatalog
            }
            entries = try catalog.validated()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func package(for entry: ExtensionCatalogEntry, currentVersion: String) async throws -> ExtensionPackage {
        let data = try await ExtensionDownload.fetch(entry.packageURL, maxBytes: 128_000)
        return try ExtensionDownload.decodePackage(data, entry: entry, currentVersion: currentVersion)
    }
}
