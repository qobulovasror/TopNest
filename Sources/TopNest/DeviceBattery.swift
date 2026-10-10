import CoreAudio
import Foundation
import IOKit

enum DeviceKind: String, Equatable, Sendable {
    case airpods, headphones, keyboard, mouse, trackpad, other

    var icon: String {
        switch self {
        case .airpods: "airpodspro"
        case .headphones: "headphones"
        case .keyboard: "keyboard"
        case .mouse: "computermouse"
        case .trackpad: "rectangle.and.hand.point.up.left"
        case .other: "dot.radiowaves.left.and.right"
        }
    }

    static func guess(name: String, minorType: String? = nil) -> DeviceKind {
        let text = "\(name) \(minorType ?? "")".lowercased()
        if text.contains("airpods max") { return .headphones }
        if text.contains("airpods") { return .airpods }
        if text.contains("keyboard") { return .keyboard }
        if text.contains("trackpad") { return .trackpad }
        if text.contains("mouse") { return .mouse }
        if ["headphone", "headset", "beats", "buds", "earphone"].contains(where: text.contains) { return .headphones }
        return .other
    }
}

struct BatteryReading: Equatable, Sendable {
    enum Part: String, Sendable { case main, left, right, caseUnit }
    let part: Part
    let percent: Int

    var label: String {
        switch part {
        case .main: ""
        case .left: L10n.tr("Chap")
        case .right: L10n.tr("O‘ng")
        case .caseUnit: L10n.tr("G‘ilof")
        }
    }
}

struct BluetoothDevice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: DeviceKind
    let batteries: [BatteryReading]

    // Asosiy ko'rsatkich: quloqchinlarda g'ilofsiz eng kami, boshqalarda asosiy batareya.
    var percent: Int? {
        let worn = batteries.filter { $0.part != .caseUnit }
        return (worn.isEmpty ? batteries : worn).map(\.percent).min()
    }
}

// Bluetooth qurilmalar batareyasi: Magic Keyboard/Mouse/Trackpad — IOKit (tez, ruxsatsiz),
// AirPods va boshqa quloqchinlar — system_profiler (sekin, shuning uchun kam va fonda).
enum DeviceBatteryReader {
    static func hidDevices() -> [BluetoothDevice] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var result: [BluetoothDevice] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let properties = unmanaged?.takeRetainedValue() as? [String: Any],
                  let percent = properties["BatteryPercent"] as? Int,
                  let name = properties["Product"] as? String else { continue }
            let id = normalizedID((properties["DeviceAddress"] as? String) ?? (properties["SerialNumber"] as? String) ?? name)
            guard !result.contains(where: { $0.id == id }) else { continue }
            result.append(BluetoothDevice(id: id, name: name, kind: .guess(name: name),
                                          batteries: [BatteryReading(part: .main, percent: min(100, max(0, percent)))]))
        }
        return result
    }

    // `system_profiler SPBluetoothDataType -json` chiqishidan faqat ulangan va batareyasi ma'lum qurilmalar.
    static func parseProfiler(_ data: Data) -> [BluetoothDevice] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]] else { return [] }
        var result: [BluetoothDevice] = []
        for section in sections {
            for entry in section["device_connected"] as? [[String: Any]] ?? [] {
                for (name, value) in entry {
                    guard let info = value as? [String: Any] else { continue }
                    let parts: [(String, BatteryReading.Part)] = [
                        ("device_batteryLevelMain", .main), ("device_batteryLevel", .main),
                        ("device_batteryLevelLeft", .left), ("device_batteryLevelRight", .right),
                        ("device_batteryLevelCase", .caseUnit)
                    ]
                    var batteries: [BatteryReading] = []
                    for (key, part) in parts {
                        guard let raw = info[key] as? String, let percent = Int(raw.filter(\.isNumber)),
                              !batteries.contains(where: { $0.part == part }) else { continue }
                        batteries.append(BatteryReading(part: part, percent: min(100, max(0, percent))))
                    }
                    guard !batteries.isEmpty else { continue }
                    let id = normalizedID((info["device_address"] as? String) ?? name)
                    result.append(BluetoothDevice(id: id, name: name, kind: .guess(name: name, minorType: info["device_minorType"] as? String),
                                                  batteries: batteries))
                }
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // IOKit "aa-bb-..", system_profiler "AA:BB:.." beradi: bitta qurilma bitta id olsin.
    static func normalizedID(_ raw: String) -> String {
        raw.lowercased().replacingOccurrences(of: "-", with: ":")
    }

    // IOKit o'qigan qurilma ustun (tezroq yangilanadi); nom ham solishtiriladi.
    static func merge(hid: [BluetoothDevice], profiler: [BluetoothDevice]) -> [BluetoothDevice] {
        let hidIDs = Set(hid.map(\.id)), hidNames = Set(hid.map(\.name))
        return hid + profiler.filter { !hidIDs.contains($0.id) && !hidNames.contains($0.name) }
    }

    static func runProfiler() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        // 10 soniyadan ko'p kutilmaydi: jarayon to'xtatilsa o'qish ham tugaydi.
        let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 10, execute: killer)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        killer.cancel()
        return process.terminationStatus == 0 ? data : nil
    }
}

@MainActor
final class DeviceBatteryService: ObservableObject {
    static let lowThreshold = 20

    @Published private(set) var devices: [BluetoothDevice] = []
    // Yangi ulangan qurilma (live activity uchun) va kam zaryad haqida xabar.
    var onConnect: ((BluetoothDevice) -> Void)?
    var onLow: ((BluetoothDevice) -> Void)?
    private var profilerDevices: [BluetoothDevice] = []
    private var profilerAt: Date?
    private var profilerRunning = false
    private var timer: Timer?
    // Qurilma oxirgi marta qachon ko'rilgan: qisqa uzilish qayta "ulandi" deb e'lon qilinmaydi.
    private var lastSeen: [String: Date] = [:]
    private var warned: Set<String> = []
    private var started = false
    private var audioListener: AudioObjectPropertyListenerBlock?

    // HID har daqiqa (arzon IOKit), system_profiler har 5 daqiqa (~0,1–0,2 s) — uzilgan qurilma uzoq "ulangan" bo'lib qolmaydi.
    func start() {
        guard !started else { return }
        started = true
        refresh(includeProfiler: true, announceProfiler: false, announceHID: false)
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refresh(includeProfiler: self.profilerAge > 290, announceProfiler: false, announceHID: true)
            }
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        listenForAudioDevices()
    }

    // Faqat rasm testlari uchun.
    func setPreview(_ devices: [BluetoothDevice]) { self.devices = devices }

    private var profilerAge: TimeInterval { profilerAt.map { Date().timeIntervalSince($0) } ?? .infinity }

    // Panel ochilganda: system_profiler natijasi 1 daqiqadan eski bo'lsa yangilanadi (bu yerda "ulandi" ko'rsatilmaydi).
    func refreshIfStale() {
        refresh(includeProfiler: profilerAge > 60, announceProfiler: false, announceHID: true)
    }

    // "Ulandi" faqat hodisa bilan bog'liq yangilanishda ko'rsatiladi: kech kelgan profiler natijasi eski ulanishni e'lon qilmaydi.
    func refresh(includeProfiler: Bool, announceProfiler: Bool, announceHID: Bool) {
        ingest(hid: DeviceBatteryReader.hidDevices(), announceProfiler: false, announceHID: announceHID)
        guard includeProfiler, !profilerRunning else { return }
        profilerRunning = true
        Task { [weak self] in
            let parsed = await Task.detached(priority: .utility) {
                DeviceBatteryReader.runProfiler().map(DeviceBatteryReader.parseProfiler)
            }.value
            guard let self else { return }
            self.profilerRunning = false
            // Xato bo'lsa ham vaqt yoziladi: har panel ochilishida qayta urinilmaydi.
            self.profilerAt = Date()
            if let parsed { self.profilerDevices = parsed }
            self.ingest(hid: DeviceBatteryReader.hidDevices(), announceProfiler: announceProfiler, announceHID: announceHID)
        }
    }

    func ingest(hid: [BluetoothDevice], profiler: [BluetoothDevice]? = nil, announceProfiler: Bool, announceHID: Bool, now: Date = Date()) {
        if let profiler { profilerDevices = profiler }
        lastSeen = lastSeen.filter { now.timeIntervalSince($0.value) < 180 }
        let next = DeviceBatteryReader.merge(hid: hid, profiler: profilerDevices)
        let hidIDs = Set(hid.map(\.id))
        for device in next where lastSeen[device.id] == nil {
            if hidIDs.contains(device.id) ? announceHID : announceProfiler { onConnect?(device) }
        }
        for device in next { lastSeen[device.id] = now }
        // Kam zaryad: qurilma uchun bir marta; 30% dan oshgach qayta ogohlantirish mumkin.
        for device in next {
            guard let percent = device.percent else { continue }
            if percent <= Self.lowThreshold, !warned.contains(device.id) {
                warned.insert(device.id)
                onLow?(device)
            } else if percent > 30 {
                warned.remove(device.id)
            }
        }
        if next != devices { devices = next }
    }

    // Quloqchin ulanganda audio qurilmalar ro'yxati o'zgaradi: batareya ma'lumoti bir necha soniyadan keyin paydo bo'ladi.
    private func listenForAudioDevices() {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        // Batareya ma'lumoti kechikishi mumkin: 4 va 12 soniyadan keyin tekshiriladi.
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            for delay in [4.0, 12.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    MainActor.assumeIsolated { self?.refresh(includeProfiler: true, announceProfiler: true, announceHID: true) }
                }
            }
        }
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener) == noErr {
            audioListener = listener
        }
    }
}
