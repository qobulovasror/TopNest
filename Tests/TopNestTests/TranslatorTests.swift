import XCTest
@testable import TopNest

final class TranslatorTests: XCTestCase {
    func testGoogleRequestCarriesKeyInQueryAndTextInBody() throws {
        let request = try XCTUnwrap(GoogleTranslate.request(text: "Salom & dunyo", source: "", target: "en", key: "k+1"))
        XCTAssertEqual(request.httpMethod, "POST")
        let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "translation.googleapis.com")
        // Kalit URL'da emas, sarlavhada.
        XCTAssertNil(components.queryItems)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Goog-Api-Key"), "k+1")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: String])
        XCTAssertEqual(body["q"], "Salom & dunyo")
        XCTAssertEqual(body["target"], "en")
        // Bo'sh manba — avtomatik aniqlash, maydon yuborilmaydi.
        XCTAssertNil(body["source"])
    }

    func testGoogleResponseParsing() throws {
        let ok = #"{"data":{"translations":[{"translatedText":"Hello world","detectedSourceLanguage":"uz"}]}}"#
        let result = try GoogleTranslate.parse(Data(ok.utf8))
        XCTAssertEqual(result.text, "Hello world")
        XCTAssertEqual(result.detected, "uz")
        let error = #"{"error":{"code":400,"message":"API key not valid."}}"#
        XCTAssertThrowsError(try GoogleTranslate.parse(Data(error.utf8))) { XCTAssertEqual($0.localizedDescription, "API key not valid.") }
        XCTAssertThrowsError(try GoogleTranslate.parse(Data("{}".utf8)))
    }

    @MainActor
    func testSwapUsesDetectedLanguageAndAvoidsSamePair() {
        let store = TranslatorStore()
        store.source = ""
        store.target = "en"
        store.swapLanguages()
        // Aniqlangan til yo'q — almashtirish bajarilmaydi.
        XCTAssertEqual(store.source, "")
        store.finish(id: 0, text: "Hello", detected: "uz")
        store.source = "en"
        store.swapLanguages()
        XCTAssertEqual(store.source, "en")
        store.adoptLanguages([TranslationLanguage(id: "en"), TranslationLanguage(id: "ru")])
        store.target = "uz"
        store.adoptLanguages([TranslationLanguage(id: "en"), TranslationLanguage(id: "ru")])
        XCTAssertNotEqual(store.target, "uz")
    }

    func testWidgetNeedsSetupUntilServiceReady() {
        var context = WidgetContext()
        if case .needsSetup(_, let action) = WidgetRules.state(for: WidgetConfig(kind: .translate), in: context) {
            XCTAssertEqual(action, .openSettings(.translate))
        } else { XCTFail() }
        context.translationReady = true
        XCTAssertEqual(WidgetRules.state(for: WidgetConfig(kind: .translate), in: context), .ready)
    }
}
