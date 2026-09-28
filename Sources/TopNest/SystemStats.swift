import Darwin
import Foundation
import IOKit

// CPU, RAM, GPU va tarmoq yuklanishi. Faqat statistika widgeti ko'rinib turganda o'lchanadi.
@MainActor
final class SystemStatsService: ObservableObject {
    static let historyLength = 30

    @Published private(set) var cpu: Double?
    @Published private(set) var memoryUsed: UInt64 = 0
    @Published private(set) var gpu: Double?
    @Published private(set) var download: Double?
    @Published private(set) var upload: Double?
    @Published private(set) var history: [WidgetKind: [Double]] = [:]

    let memoryTotal = ProcessInfo.processInfo.physicalMemory
    var memoryFraction: Double { memoryTotal > 0 ? Double(memoryUsed) / Double(memoryTotal) : 0 }

    // Har widget o'z id'si va turi bilan ro'yxatdan o'tadi: faqat ko'rinib turgan turlar o'lchanadi,
    // takroriy onAppear/onDisappear hisobni buzmaydi.
    private var viewers: [UUID: WidgetKind] = [:]
    private var timer: Timer?
    private var sampling = false
    private var resampleRequested = false
    private var previousTicks: (busy: UInt64, total: UInt64)?
    private var previousNetwork: NetworkSnapshot?

    var neededKinds: Set<WidgetKind> { Set(viewers.values) }

    deinit { timer?.invalidate() }

    func retain(_ id: UUID, kind: WidgetKind) {
        let wasIdle = viewers.isEmpty
        let isNewKind = !neededKinds.contains(kind)
        viewers[id] = kind
        if wasIdle {
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.sample() }
            }
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        if wasIdle || isNewKind { sample() }
    }

    // Oxirgi widget yopilganda o'lchov to'xtaydi va eski qiymatlar tozalanadi.
    func release(_ id: UUID) {
        guard let kind = viewers.removeValue(forKey: id) else { return }
        if !neededKinds.contains(kind) { reset(kind) }
        guard viewers.isEmpty else { return }
        timer?.invalidate()
        timer = nil
    }

    private func reset(_ kind: WidgetKind) {
        switch kind {
        case .cpu: cpu = nil; previousTicks = nil
        case .gpu: gpu = nil
        case .network: download = nil; upload = nil; previousNetwork = nil
        case .memory: memoryUsed = 0
        default: break
        }
        history[kind] = nil
    }

    struct NetworkSnapshot: Sendable {
        let counters: [UInt16: Counter]
        let at: Date
    }

    struct Counter: Sendable {
        let received: UInt64
        let sent: UInt64
    }

    private struct Sample: Sendable {
        var ticks: (busy: UInt64, total: UInt64)?
        var memory: UInt64?
        var gpu: Double?
        var network: NetworkSnapshot?
    }

    // O'lchovlar (IOKit, sysctl, Mach) asosiy oqimni band qilmasligi uchun fon navbatida bajariladi.
    private func sample() {
        let kinds = neededKinds
        guard !kinds.isEmpty else { return }
        // Namuna olinayotganda yangi tur qo'shilsa, u tugagach darhol yana olinadi.
        guard !sampling else { resampleRequested = true; return }
        sampling = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var result = Sample()
            if kinds.contains(.cpu) { result.ticks = Self.cpuTicks() }
            if kinds.contains(.memory) { result.memory = Self.memoryInUse() }
            if kinds.contains(.gpu) { result.gpu = Self.gpuUtilization() }
            if kinds.contains(.network) { result.network = Self.networkCounters().map { NetworkSnapshot(counters: $0, at: Date()) } }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.apply(result) } }
        }
    }

    private func apply(_ result: Sample) {
        sampling = false
        defer {
            if resampleRequested {
                resampleRequested = false
                sample()
            }
        }
        let kinds = neededKinds
        if kinds.contains(.cpu), let ticks = result.ticks {
            // Yadro hisoblagichi aylanib qaytsa (busy kamaysa) bu namuna tashlab yuboriladi.
            if let previous = previousTicks, ticks.total > previous.total, ticks.busy >= previous.busy {
                let value = Double(ticks.busy - previous.busy) / Double(ticks.total - previous.total)
                cpu = value
                append(.cpu, value)
            }
            previousTicks = ticks
        }
        if kinds.contains(.memory), let used = result.memory {
            memoryUsed = used
            append(.memory, memoryFraction)
        }
        if kinds.contains(.gpu) {
            gpu = result.gpu
            if let gpu = result.gpu { append(.gpu, gpu) }
        }
        if kinds.contains(.network), let snapshot = result.network {
            if let previous = previousNetwork {
                let seconds = max(0.5, snapshot.at.timeIntervalSince(previous.at))
                var received: UInt64 = 0, sent: UInt64 = 0
                // Har interfeys alohida: yangi paydo bo'lgani faqat boshlang'ich nuqta bo'ladi.
                for (index, value) in snapshot.counters {
                    guard let old = previous.counters[index] else { continue }
                    received += value.received >= old.received ? value.received - old.received : 0
                    sent += value.sent >= old.sent ? value.sent - old.sent : 0
                }
                download = Double(received) / seconds
                upload = Double(sent) / seconds
                append(.network, Double(received + sent) / seconds)
            }
            previousNetwork = snapshot
        }
    }

    private func append(_ kind: WidgetKind, _ value: Double) {
        var values = history[kind] ?? []
        values.append(value)
        if values.count > Self.historyLength { values.removeFirst(values.count - Self.historyLength) }
        history[kind] = values
    }

    // MARK: O'lchovlar

    nonisolated private static func cpuTicks() -> (busy: UInt64, total: UInt64)? {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return nil }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)) }
        var busy: UInt64 = 0, total: UInt64 = 0
        for cpu in 0..<Int(count) {
            let base = cpu * Int(CPU_STATE_MAX)
            let user = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            let system = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            let nice = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            let idle = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            busy += user + system + nice
            total += user + system + nice + idle
        }
        return (busy, total)
    }

    // Activity Monitor'dagi "Memory Used" ga yaqin: faol + wired + siqilgan sahifalar.
    nonisolated private static func memoryInUse() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return nil }
        let page = UInt64(vm_kernel_page_size)
        // Hisoblagichlar atomik olinmaydi: ayirishda underflow bo'lmasin.
        let internalPages = UInt64(stats.internal_page_count), purgeable = UInt64(stats.purgeable_count)
        let app = internalPages > purgeable ? internalPages - purgeable : 0
        return (app + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
    }

    nonisolated private static func gpuUtilization() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var best: Double?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
            guard let property = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue(),
                  let stats = property as? [String: Any],
                  let utilization = stats["Device Utilization %"] as? Int else { continue }
            best = max(best ?? 0, Double(utilization) / 100)
        }
        return best
    }

    // 64-bitli hisoblagichlar (if_data64) — 4 GB dan keyin qaytadan boshlanmaydi.
    // Faqat fizik "en*" interfeyslari: VPN (utun) trafigi ikki marta sanalmaydi.
    nonisolated private static func networkCounters() -> [UInt16: Counter]? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return nil }
        length += length / 8
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else { return nil }
        var counters: [UInt16: Counter] = [:]
        var offset = 0
        while offset + MemoryLayout<if_msghdr>.size <= length {
            let (messageLength, type) = buffer.withUnsafeBytes { raw -> (Int, Int32) in
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                return (Int(header.ifm_msglen), Int32(header.ifm_type))
            }
            guard messageLength > 0 else { break }
            if type == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= length {
                let header = buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self) }
                var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                if header.ifm_flags & IFF_UP != 0, if_indextoname(UInt32(header.ifm_index), &name) != nil,
                   String(cString: name).hasPrefix("en") {
                    counters[header.ifm_index] = Counter(received: header.ifm_data.ifi_ibytes, sent: header.ifm_data.ifi_obytes)
                }
            }
            offset += messageLength
        }
        return counters
    }
}

extension Double {
    // Tarmoq tezligi: "1.2 MB/s" ko'rinishida.
    var byteRate: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .decimal) + "/s"
    }
}
