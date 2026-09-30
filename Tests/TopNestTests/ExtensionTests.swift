import CryptoKit
import Foundation
import XCTest
@testable import TopNest

final class ExtensionTests: XCTestCase {
    private func package(source: CustomWidgetSpec.Source = .url, target: String = "https://api.github.com/repos/swiftlang/swift") -> ExtensionPackage {
        var widget = CustomWidgetSpec(title: "Swift stars")
        widget.source = source
        widget.target = target
        return ExtensionPackage(schemaVersion: 1, id: "org.topnest.swift-stars", version: "1.0.0",
                                minTopNestVersion: "0.5.0", author: "TopNest", summary: "Star count", widget: widget)
    }

    func testPackageAcceptsHTTPSAndChecksCompatibility() throws {
        XCTAssertNoThrow(try package().validated(currentVersion: "0.5.0"))
        XCTAssertThrowsError(try package().validated(currentVersion: "0.4.0"))
        XCTAssertTrue(ExtensionVersion("0.5.1")! > ExtensionVersion("0.5.0")!)
        XCTAssertNil(ExtensionVersion("latest"))
    }

    func testRemotePackageRejectsCommandsAndNonHTTPS() {
        XCTAssertThrowsError(try package(source: .command, target: "echo hello").validated(currentVersion: "0.5.0"))
        XCTAssertThrowsError(try package(target: "http://example.com").validated(currentVersion: "0.5.0"))
        XCTAssertThrowsError(try package(target: "https://user:secret@example.com").validated(currentVersion: "0.5.0"))
    }

    func testInstallLinkOnlyAcceptsCatalogIdentifier() {
        XCTAssertEqual(ExtensionInstallLink.id(from: URL(string: "topnest://install?id=org.topnest.swift-stars")!), "org.topnest.swift-stars")
        XCTAssertNil(ExtensionInstallLink.id(from: URL(string: "topnest://install?url=https://example.com/a.json")!))
        XCTAssertNil(ExtensionInstallLink.id(from: URL(string: "topnest://install?id=org.topnest.a&id=org.topnest.b")!))
        XCTAssertNil(ExtensionInstallLink.id(from: URL(string: "topnest://install/other?id=org.topnest.a")!))
    }

    func testSiteCatalogMatchesPublishedSamplePackage() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalogData = try Data(contentsOf: root.appendingPathComponent("docs/extensions/catalog.json"))
        let entries = try JSONDecoder().decode(ExtensionCatalogDocument.self, from: catalogData).validated()
        let entry = try XCTUnwrap(entries.first { $0.id == "org.topnest.swift-stars" })
        let packageData = try Data(contentsOf: root.appendingPathComponent("docs/extensions/packages/swift-stars.json"))
        let decoded = try ExtensionDownload.decodePackage(packageData, entry: entry, currentVersion: "0.5.0")
        XCTAssertEqual(decoded.widget.jsonPath, "stargazers_count")
    }

    func testCatalogPackageRequiresMatchingDigestIdentityAndVersion() throws {
        let data = try JSONEncoder().encode(package())
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let entry = ExtensionCatalogEntry(id: "org.topnest.swift-stars", version: "1.0.0", name: "Swift stars",
                                          summary: "Star count", author: "TopNest",
                                          packageURL: URL(string: "https://example.com/swift-stars.json")!, sha256: hash)
        XCTAssertNoThrow(try ExtensionDownload.decodePackage(data, entry: entry, currentVersion: "0.5.0"))
        let changed = data + Data(" ".utf8)
        XCTAssertThrowsError(try ExtensionDownload.decodePackage(changed, entry: entry, currentVersion: "0.5.0"))
        let wrongID = ExtensionCatalogEntry(id: "org.topnest.other", version: "1.0.0", name: "Other",
                                            summary: "Other", author: "TopNest", packageURL: entry.packageURL, sha256: hash)
        XCTAssertThrowsError(try ExtensionDownload.decodePackage(data, entry: wrongID, currentVersion: "0.5.0"))
    }

    @MainActor
    func testInstallingUpdateKeepsWidgetPositionAndSize() throws {
        let suite = "topnest-extension-test-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let store = WidgetStore(preferences: preferences)
        let first = try package().validated(currentVersion: "0.5.0")
        store.install(first)
        var installed = try XCTUnwrap(store.installedExtension(first.id))
        installed.size = .large
        store.update(installed)
        var update = first
        update.widget.title = "Swift stars updated"
        update = ExtensionPackage(schemaVersion: 1, id: update.id, version: "1.1.0",
                                  minTopNestVersion: "0.5.0", author: update.author, summary: update.summary, widget: update.widget)
        store.install(update)
        let result = try XCTUnwrap(store.installedExtension(first.id))
        XCTAssertEqual(result.id, installed.id)
        XCTAssertEqual(result.size, .large)
        XCTAssertEqual(result.extensionVersion, "1.1.0")
        XCTAssertEqual(result.custom?.title, "Swift stars updated")
        XCTAssertEqual(store.widgets.filter { $0.extensionID == first.id }.count, 1)
    }
}
