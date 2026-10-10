import Foundation
import Security

enum TranslationProvider: String, CaseIterable, Identifiable {
    case apple, google

    var id: Self { self }

    var title: String {
        switch self {
        case .apple: L10n.tr("Apple (qurilmada)")
        case .google: L10n.tr("Google Cloud (API kaliti)")
        }
    }
}

// API kaliti Keychain'da: UserDefaults yoki faylga yozilmaydi.
enum KeychainSecret {
    private static let service = "com.codex.topnest.translate"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func write(_ value: String, account: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return true }
        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
}

struct TranslationLanguage: Identifiable, Hashable, Sendable {
    let id: String

    var name: String {
        Locale.current.localizedString(forIdentifier: id)?.capitalized(with: .current) ?? id
    }

    // Google Cloud qo'llaydigan tillardan eng ko'p ishlatiladiganlari (o'zbek tili shu yo'l bilan mavjud).
    static let googleDefaults = ["uz", "en", "ru", "tr", "kk", "ky", "tg", "de", "fr", "es", "it", "ar", "fa", "zh", "ja", "ko", "hi", "uk"]
        .map(TranslationLanguage.init)
}

enum GoogleTranslate {
    struct Failure: LocalizedError { let errorDescription: String? }

    static func request(text: String, source: String?, target: String, key: String) -> URLRequest? {
        guard let url = URL(string: "https://translation.googleapis.com/language/translate/v2") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Kalit sarlavhada: URL xato matnlari va keshlarga tushmaydi.
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        var body: [String: Any] = ["q": text, "target": target, "format": "text"]
        if let source, !source.isEmpty { body["source"] = source }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func parse(_ data: Data) throws -> (text: String, detected: String?) {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let error = object?["error"] as? [String: Any] {
            throw Failure(errorDescription: (error["message"] as? String) ?? L10n.tr("Tarjima xizmati xato qaytardi"))
        }
        guard let first = ((object?["data"] as? [String: Any])?["translations"] as? [[String: Any]])?.first,
              let text = first["translatedText"] as? String else { throw Failure(errorDescription: L10n.tr("Tarjima javobi noto‘g‘ri")) }
        return (text, first["detectedSourceLanguage"] as? String)
    }

    static func translate(_ text: String, source: String?, target: String, key: String) async throws -> (text: String, detected: String?) {
        guard let request = request(text: text, source: source, target: target, key: key) else { throw Failure(errorDescription: L10n.tr("Tarjima javobi noto‘g‘ri")) }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        do {
            return try parse(data)
        } catch let failure as Failure where status == 200 || failure.errorDescription != L10n.tr("Tarjima javobi noto‘g‘ri") {
            throw failure
        } catch {
            throw Failure(errorDescription: L10n.format("Tarjima xizmati xato qaytardi (HTTP %d)", status))
        }
    }
}

// Tarjima holati: kiritish, natija, tillar. Apple tarjimasi view'dagi translationTask orqali bajariladi
// (macOS 15 talabi), Google — shu yerda URLSession bilan.
@MainActor
final class TranslatorStore: ObservableObject {
    static let maxLength = 5000

    @Published var input = "" {
        didSet { if input != oldValue { detected = nil } }
    }
    @Published private(set) var output = ""
    @Published private(set) var detected: String?
    @Published private(set) var translating = false
    @Published var errorMessage: String?
    // Bo'sh — avtomatik aniqlash.
    @Published var source = UserDefaults.standard.string(forKey: "translateSource") ?? "" {
        didSet { UserDefaults.standard.set(source, forKey: "translateSource") }
    }
    @Published var target = UserDefaults.standard.string(forKey: "translateTarget") ?? TranslatorStore.defaultTarget {
        didSet { UserDefaults.standard.set(target, forKey: "translateTarget") }
    }
    @Published var provider = TranslationProvider(rawValue: UserDefaults.standard.string(forKey: "translateProvider") ?? "") ?? .apple {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "translateProvider"); languages = [] }
    }
    // Keychain ishga tushishda o'qilmaydi (ad hoc imzoda parol so'rashi mumkin): faqat bayroq saqlanadi.
    @Published private(set) var hasGoogleKey = UserDefaults.standard.bool(forKey: "translateHasGoogleKey")
    // Apple tarjimasi uchun so'rov: o'zgarsa view yangi tarjimani boshlaydi.
    struct AppleRequest: Equatable { let id: Int; let text: String }
    @Published private(set) var appleRequest: AppleRequest?
    @Published var languages: [TranslationLanguage] = []
    private var requestCounter = 0
    private var claimedID = 0
    private var googleTask: Task<Void, Never>?

    static var defaultTarget: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return code == "en" ? "ru" : (code == "uz" ? "en" : code)
    }

    var appleAvailable: Bool {
        if #available(macOS 15, *) { return true }
        return false
    }

    var canTranslate: Bool {
        switch provider {
        case .apple: appleAvailable
        case .google: hasGoogleKey
        }
    }

    @discardableResult
    func setGoogleKey(_ key: String) -> Bool {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = KeychainSecret.write(value, account: "google")
        hasGoogleKey = ok && !value.isEmpty
        UserDefaults.standard.set(hasGoogleKey, forKey: "translateHasGoogleKey")
        return ok
    }

    // Avtomatik manbada aniqlangan til ishlatiladi; tillar bir xil bo'lib qolsa almashtirilmaydi.
    func swapLanguages() {
        guard let from = source.isEmpty ? detected : source, from != target else { return }
        (source, target) = (target, from)
        swapTexts()
    }

    // Tanlangan til yangi xizmat ro'yxatida bo'lmasa mos tilga qaytariladi.
    func adoptLanguages(_ list: [TranslationLanguage]) {
        languages = list
        let ids = Set(list.map(\.id))
        guard !ids.isEmpty else { return }
        if !source.isEmpty, !ids.contains(source) { source = "" }
        if !ids.contains(target) { target = ids.contains(Self.defaultTarget) ? Self.defaultTarget : (ids.contains("en") ? "en" : list[0].id) }
    }

    // Bir nechta panel ko'rinib tursa ham so'rovni faqat bittasi bajaradi.
    func claim(_ id: Int) -> Bool {
        guard id > claimedID else { return false }
        claimedID = id
        return true
    }

    // Panel yopilib, Apple so'rovi bajarilmay qolsa spinner osilib qolmaydi.
    func cancelPending() {
        guard translating, provider == .apple else { return }
        translating = false
        appleRequest = nil
    }

    private func swapTexts() {
        guard !output.isEmpty else { return }
        input = output
        output = ""
    }

    func translate() {
        let text = String(input.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxLength))
        guard !text.isEmpty, canTranslate else { return }
        errorMessage = nil
        translating = true
        requestCounter += 1
        let id = requestCounter
        switch provider {
        case .apple:
            appleRequest = AppleRequest(id: id, text: text)
        case .google:
            guard let key = KeychainSecret.read("google") else {
                fail(id: id, L10n.tr("Google Cloud uchun API kaliti kiritilmagan."))
                return
            }
            let source = source, target = target
            googleTask?.cancel()
            googleTask = Task { [weak self] in
                do {
                    let result = try await GoogleTranslate.translate(text, source: source, target: target, key: key)
                    self?.finish(id: id, text: result.text, detected: result.detected)
                } catch {
                    self?.fail(id: id, error.localizedDescription)
                }
            }
        }
    }

    // Kech kelgan eski javob yangisini bosmaydi.
    func finish(id: Int, text: String, detected: String?) {
        guard id == requestCounter else { return }
        output = text
        self.detected = detected
        translating = false
    }

    func fail(id: Int, _ message: String) {
        guard id == requestCounter else { return }
        errorMessage = message
        translating = false
    }

    func clear() {
        input = ""
        output = ""
        detected = nil
        errorMessage = nil
    }
}
