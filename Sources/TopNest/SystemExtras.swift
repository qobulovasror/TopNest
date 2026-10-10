import Foundation
import IOKit

struct DiskUsage: Equatable, Sendable {
    let free: Int64
    let total: Int64
    var usedFraction: Double { total > 0 ? Double(total - free) / Double(total) : 0 }
}

struct BatteryHealth: Equatable, Sendable {
    let cycles: Int
    // Joriy maksimal sig'imning zavod sig'imiga nisbati (Activity Monitor/System Information'dagi "Maximum Capacity").
    let capacity: Double
}

struct ProcessUsage: Identifiable, Equatable, Sendable {
    let id: Int32
    let name: String
    let cpu: Double
    let memory: Int64
}

enum SystemExtras {
    // "Muhim foydalanish uchun bo'sh joy": Finder ko'rsatadigan qiymat (purgeable joy hisobga olinadi).
    static func disk() -> DiskUsage? {
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        guard let free = values?.volumeAvailableCapacityForImportantUsage, let total = values?.volumeTotalCapacity, total > 0 else { return nil }
        return DiskUsage(free: free, total: Int64(total))
    }

    static func battery() -> BatteryHealth? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        func property(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        let data = property("BatteryData") as? [String: Any] ?? [:]
        return health(top: { property($0) as? Int }, data: data)
    }

    // Yangi macOS'da sig'imlar BatteryData ichida (NominalChargeCapacity — System Information'dagi "Maximum Capacity"),
    // eskilarida yuqori darajada (AppleRawMaxCapacity). MaxCapacity Apple Silicon'da foiz, shuning uchun ishlatilmaydi.
    static func health(top: (String) -> Int?, data: [String: Any]) -> BatteryHealth? {
        let design = (data["DesignCapacity"] as? Int) ?? top("DesignCapacity")
        let maximum = (data["NominalChargeCapacity"] as? Int) ?? top("AppleRawMaxCapacity")
        guard let design, design > 0, let maximum, maximum > 0 else { return nil }
        return BatteryHealth(cycles: top("CycleCount") ?? 0, capacity: min(1, Double(maximum) / Double(design)))
    }

    // `ps` chiqishi: "pid %cpu rss(KB) nom", CPU bo'yicha kamayish tartibida.
    static func parseProcesses(_ output: String, limit: Int = 3, excluding ownPID: Int32? = nil) -> [ProcessUsage] {
        output.split(whereSeparator: \.isNewline).compactMap { line -> ProcessUsage? in
            let fields = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard fields.count == 4, let pid = Int32(fields[0]), let cpu = Double(fields[1].replacingOccurrences(of: ",", with: ".")),
                  let rss = Int64(fields[2]), pid != ownPID else { return nil }
            return ProcessUsage(id: pid, name: String(fields[3]), cpu: cpu, memory: rss * 1024)
        }
        .sorted { $0.cpu > $1.cpu }
        .prefix(limit)
        .map { $0 }
    }

    static func topProcesses() -> [ProcessUsage] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Aceo", "pid=,pcpu=,rss=,comm=", "-r"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return [] }
        let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5, execute: killer)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        killer.cancel()
        return parseProcesses(String(decoding: data, as: UTF8.self), excluding: ProcessInfo.processInfo.processIdentifier)
    }
}

// CPU uzoq vaqt yuqori bo'lsa bir marta ogohlantiradi; yuklama tushgach qayta qurollanadi.
struct CPUAlertPolicy {
    var threshold = 0.9
    var duration: TimeInterval = 120
    var rearmBelow = 0.7
    private var highSince: Date?
    private var fired = false

    init(threshold: Double = 0.9, duration: TimeInterval = 120, rearmBelow: Double = 0.7) {
        self.threshold = threshold
        self.duration = duration
        self.rearmBelow = rearmBelow
    }

    // true — hozir ogohlantirish kerak. 70–90% oralig'idagi qisqa pasayish hisobni uzmaydi.
    mutating func feed(_ value: Double, at now: Date) -> Bool {
        if value < rearmBelow {
            fired = false
            highSince = nil
            return false
        }
        if value >= threshold, highSince == nil { highSince = now }
        guard let since = highSince, value >= threshold, !fired, now.timeIntervalSince(since) >= duration else { return false }
        fired = true
        return true
    }
}
