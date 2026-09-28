import AppKit
import Foundation

// Kengaytirilgan rejim (standart o'chiq, foydalanuvchi roziligi bilan yoqiladi): barcha playerlar
// (brauzer, Spotify, Music, Yandex Music va boshq.). macOS 15.4+ da MediaRemote faqat Apple imzoli
// jarayonlarga ochiq, shuning uchun yordamchi kutubxona /usr/bin/perl ichida ishga tushiriladi.
@MainActor
final class MediaRemoteService: ObservableObject {
    enum Command: Int {
        case play = 0, pause = 1, togglePlayPause = 2, next = 4, previous = 5
    }

    enum Status: Equatable {
        case off, starting, active, failed
    }

    var onUpdate: ((TrackInfo?) -> Void)?
    var onFallback: (() -> Void)?
    @Published private(set) var status: Status = .off
    // Kamida bitta javob kelgan bo'lsa true: shundan keyin AppleScript zaxirasi ishlatilmaydi.
    var available: Bool { status == .active }
    // Qayta urinish davrida (oldingi urinish xato bo'lgan) AppleScript zaxirasi ishlashi mumkin.
    var recovering: Bool { status == .starting && failures > 0 }
    private(set) var lastTrack: TrackInfo?
    private var process: Process?
    private var input: Pipe?
    private var failures = 0
    private var running = false
    // Har start/stop/launch'da oshadi: eski jarayonning kechikkan hodisalari e'tiborsiz qoldiriladi.
    private var generation = 0

    private static let loader = #"use DynaLoader; my $l = DynaLoader::dl_load_file($ARGV[0], 0) or exit 3; my $s = DynaLoader::dl_find_symbol($l, $ARGV[1]) or exit 4; DynaLoader::dl_install_xsub("main::run", $s); run();"#
    private static let startTimeout: TimeInterval = 5

    static var bridgePath: String? {
        let candidates = [
            Bundle.main.privateFrameworksURL?.appendingPathComponent("libTopNestMediaBridge.dylib").path,
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("libTopNestMediaBridge.dylib").path
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0) }
    }

    func start() {
        guard !running else { return }
        guard Self.bridgePath != nil else { status = .failed; return }
        running = true
        failures = 0
        launch()
    }

    func stop() {
        running = false
        generation += 1
        status = .off
        lastTrack = nil
        shutdownProcess()
    }

    func send(_ command: Command) {
        run(symbol: "tn_command", environment: ["TN_COMMAND": String(command.rawValue)])
    }

    func seek(to seconds: Double) {
        run(symbol: "tn_command", environment: ["TN_SEEK_MS": String(Int(max(0, seconds) * 1000))])
    }

    private func run(symbol: String, environment: [String: String]) {
        guard let path = Self.bridgePath else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-e", Self.loader, path, symbol]
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    private func shutdownProcess() {
        try? input?.fileHandleForWriting.close()
        process?.terminate()
        process = nil
        input = nil
    }

    private func launch() {
        guard running, let path = Self.bridgePath else { return }
        generation += 1
        let current = generation
        status = .starting
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-e", Self.loader, path, "tn_stream"]
        let output = Pipe(), input = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        // stdin ochiq turadi; TopNest yopilsa pipe yopiladi va yordamchi ham to'xtaydi.
        process.standardInput = input
        // Qatorlarga bo'lish va JSON/rasmni o'qish fon oqimida; asosiy oqimga tayyor natija keladi.
        let reader = LineReader()
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { handle.readabilityHandler = nil; return }
            let messages = reader.append(chunk).compactMap(Self.decode)
            guard !messages.isEmpty else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.receive(messages, generation: current) } }
        }
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.terminated(generation: current) } }
        }
        do {
            try process.run()
            self.process = process
            self.input = input
        } catch {
            terminated(generation: current)
            return
        }
        // Javob kelmasa (masalan, kutubxona yuklanmadi) cheksiz "ishga tushmoqda" bo'lib qolmasin.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.startTimeout) { [weak self] in
            guard let self, self.generation == current, self.status == .starting else { return }
            self.shutdownProcess()
            self.terminated(generation: current)
        }
    }

    // Kutilmagan to'xtashda qayta ishga tushiriladi; 3 marta ketma-ket xato bo'lsa zaxiraga o'tiladi.
    private func terminated(generation ended: Int) {
        guard ended == generation, running else { return }
        // Shu jarayonning ikkinchi hodisasi (timeout + terminationHandler) yoki kech chiqishi hisoblanmasin.
        generation += 1
        process = nil
        input = nil
        failures += 1
        status = .starting
        lastTrack = nil
        onUpdate?(nil)
        if failures >= 3 {
            // Ishlamay qoldi (masalan, macOS yangilanishidan keyin): AppleScript zaxirasiga o'tiladi.
            running = false
            generation += 1
            status = .failed
            onFallback?()
            return
        }
        let delay = min(30, pow(2, Double(failures)))
        let scheduled = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.generation == scheduled else { return }
            self.launch()
        }
    }

    private func receive(_ messages: [Message], generation current: Int) {
        guard running, current == generation else { return }
        if status != .active { status = .active }
        failures = 0
        for message in messages {
            let track = makeTrack(message)
            lastTrack = track
            onUpdate?(track)
        }
    }

    // MARK: Fon oqimida o'qish

    struct Message: Sendable {
        let title: String?
        let artist: String
        let bundleID: String
        let pid: Int32
        let playing: Bool
        let elapsed: Double
        let duration: Double
        let timestamp: Date?
        let artwork: Data?
    }

    nonisolated private static func decode(_ line: Data) -> Message? {
        guard let json = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else { return nil }
        let rate = (json["rate"] as? NSNumber)?.doubleValue ?? 0
        return Message(
            title: (json["title"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            artist: json["artist"] as? String ?? "",
            bundleID: json["bundle"] as? String ?? "",
            pid: (json["pid"] as? NSNumber)?.int32Value ?? 0,
            playing: ((json["playing"] as? NSNumber)?.boolValue ?? false) || rate > 0,
            elapsed: (json["elapsed"] as? NSNumber)?.doubleValue ?? 0,
            duration: (json["duration"] as? NSNumber)?.doubleValue ?? 0,
            timestamp: (json["timestamp"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) },
            artwork: (json["artwork"] as? String).flatMap { Data(base64Encoded: $0) }
        )
    }

    private func makeTrack(_ message: Message) -> TrackInfo? {
        guard let title = message.title else { return nil }
        let appName = NSRunningApplication(processIdentifier: message.pid)?.localizedName
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: message.bundleID).map { FileManager.default.displayName(atPath: $0.path) }
            ?? "Media"
        var artwork = message.artwork
        // Rasm faqat o'zgarganda keladi: shu trek uchun oldingisi saqlanadi.
        if artwork == nil, let lastTrack, lastTrack.title == title, lastTrack.artist == message.artist {
            artwork = lastTrack.artworkData
        }
        return TrackInfo(
            title: title, artist: message.artist, source: appName, bundleID: message.bundleID, playing: message.playing,
            position: message.elapsed, duration: message.duration,
            artworkURL: nil, artworkData: artwork, observedAt: message.timestamp ?? Date()
        )
    }

    // Faqat yangi qo'shilgan qismda yangi qator qidiriladi (katta rasmli qatorlarda O(n²) bo'lmasin).
    private final class LineReader: @unchecked Sendable {
        private let lock = NSLock()
        private var buffer = Data()
        private var scanned = 0

        func append(_ chunk: Data) -> [Data] {
            lock.withLock {
                buffer.append(chunk)
                var lines: [Data] = []
                while let newline = buffer[(buffer.startIndex + scanned)...].firstIndex(of: 10) {
                    lines.append(Data(buffer[buffer.startIndex..<newline]))
                    buffer = Data(buffer[(newline + 1)...])
                    scanned = 0
                }
                scanned = buffer.count
                if buffer.count > 16 * 1024 * 1024 { buffer = Data(); scanned = 0 }
                return lines
            }
        }
    }
}

// Rasm har qayta chizishda qayta dekod qilinmasin. NSData hash'i arzon (uzunlik + boshi).
@MainActor
enum ArtworkCache {
    private static let images: NSCache<NSData, NSImage> = {
        let cache = NSCache<NSData, NSImage>()
        cache.countLimit = 8
        return cache
    }()
    private static var icons: [String: NSImage] = [:]

    static func image(for data: Data) -> NSImage? {
        let key = data as NSData
        if let cached = images.object(forKey: key) { return cached }
        guard let image = NSImage(data: data) else { return nil }
        images.setObject(image, forKey: key)
        return image
    }

    static func appIcon(for bundleID: String) -> NSImage? {
        if let cached = icons[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundleID] = icon
        return icon
    }
}
