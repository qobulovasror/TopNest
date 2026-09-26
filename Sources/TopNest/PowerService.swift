import Foundation
import IOKit.ps

@MainActor
final class PowerService: ObservableObject {
    @Published private(set) var percent: Int?
    @Published private(set) var onAC = false
    @Published private(set) var charging = false
    var onPluggedIn: (() -> Void)?
    private var source: CFRunLoopSource?

    init() {
        read()
        let context = Unmanaged.passUnretained(self).toOpaque()
        // Callback asosiy run loop'da keladi; servis ilova yopilguncha yashaydi.
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<PowerService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.update() }
        }, context)?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
    }

    private func update() {
        let wasOnAC = onAC
        read()
        if onAC && !wasOnAC && percent != nil { onPluggedIn?() }
    }

    private func read() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            percent = min(100, max(0, current * 100 / maximum))
            onAC = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            charging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            return
        }
        percent = nil
    }
}
