import XCTest
@testable import TopNest

final class DeviceBatteryTests: XCTestCase {
    private let sample = """
    {"SPBluetoothDataType":[{"controller_properties":{},
      "device_connected":[
        {"AirPods Pro":{"device_address":"AA:BB:CC:DD:EE:01","device_batteryLevelLeft":"85%","device_batteryLevelRight":"90%","device_batteryLevelCase":"40%","device_minorType":"Headphones"}},
        {"Magic Mouse":{"device_address":"AA:BB:CC:DD:EE:02","device_batteryLevelMain":"15%","device_minorType":"Mouse"}},
        {"Speaker":{"device_address":"AA:BB:CC:DD:EE:03","device_minorType":"Speaker"}}
      ],
      "device_not_connected":[{"Old Keyboard":{"device_batteryLevelMain":"50%"}}]}]}
    """

    func testParsesOnlyConnectedDevicesWithBattery() {
        let devices = DeviceBatteryReader.parseProfiler(Data(sample.utf8))
        XCTAssertEqual(devices.map(\.name), ["AirPods Pro", "Magic Mouse"])
        let airpods = devices[0]
        XCTAssertEqual(airpods.kind, .airpods)
        XCTAssertEqual(airpods.batteries.count, 3)
        // G'ilof hisobga olinmaydi: quloqchinlardan eng kami.
        XCTAssertEqual(airpods.percent, 85)
        XCTAssertEqual(devices[1].kind, .mouse)
        XCTAssertEqual(devices[1].percent, 15)
        XCTAssertTrue(DeviceBatteryReader.parseProfiler(Data("{}".utf8)).isEmpty)
        XCTAssertTrue(DeviceBatteryReader.parseProfiler(Data("not json".utf8)).isEmpty)
    }

    func testMergePrefersHIDReading() {
        // Manzil formati farq qiladi va nom ham boshqacha: id normalizatsiyasi bo'yicha birlashadi.
        let hid = [BluetoothDevice(id: DeviceBatteryReader.normalizedID("aa-bb-cc-dd-ee-02"), name: "Mouse", kind: .mouse, batteries: [BatteryReading(part: .main, percent: 16)])]
        let merged = DeviceBatteryReader.merge(hid: hid, profiler: DeviceBatteryReader.parseProfiler(Data(sample.utf8)))
        XCTAssertEqual(merged.map(\.name), ["Mouse", "AirPods Pro"])
        XCTAssertEqual(merged[0].percent, 16)
    }

    func testKindGuess() {
        XCTAssertEqual(DeviceKind.guess(name: "Magic Keyboard"), .keyboard)
        XCTAssertEqual(DeviceKind.guess(name: "Magic Trackpad"), .trackpad)
        XCTAssertEqual(DeviceKind.guess(name: "WH-1000XM5", minorType: "Headphones"), .headphones)
        XCTAssertEqual(DeviceKind.guess(name: "Galaxy Buds2"), .headphones)
        XCTAssertEqual(DeviceKind.guess(name: "Gamepad"), .other)
    }

    func testWidgetHiddenWithoutDevices() {
        var context = WidgetContext()
        XCTAssertFalse(WidgetRules.state(for: WidgetConfig(kind: .devices), in: context).isVisible)
        context.hasDevices = true
        XCTAssertEqual(WidgetRules.state(for: WidgetConfig(kind: .devices), in: context), .ready)
    }

    func testDeviceFlashOutranksMusic() {
        let input = ActivityInputs(flash: .device(name: "AirPods", icon: "airpodspro", percent: 80), musicPlaying: true)
        XCTAssertEqual(ActivityPolicy.resolve(input), .device(name: "AirPods", icon: "airpodspro", percent: 80))
    }

    @MainActor
    func testConnectAndLowBatteryAnnouncements() {
        let service = DeviceBatteryService()
        var connected: [String] = [], low: [String] = []
        service.onConnect = { connected.append($0.name) }
        service.onLow = { low.append($0.name) }
        func mouse(_ percent: Int) -> BluetoothDevice {
            BluetoothDevice(id: "m", name: "Mouse", kind: .mouse, batteries: [BatteryReading(part: .main, percent: percent)])
        }
        let start = Date()
        // Birinchi o'qishda "ulandi" yo'q, lekin kam zaryad xabari bor.
        service.ingest(hid: [mouse(15)], announceProfiler: false, announceHID: false, now: start)
        XCTAssertEqual(connected, [])
        XCTAssertEqual(low, ["Mouse"])
        // Qisqa uzilish va qaytish: qayta e'lon ham, qayta ogohlantirish ham yo'q.
        service.ingest(hid: [], announceProfiler: true, announceHID: true, now: start.addingTimeInterval(60))
        service.ingest(hid: [mouse(14)], announceProfiler: true, announceHID: true, now: start.addingTimeInterval(120))
        XCTAssertEqual(connected, [])
        XCTAssertEqual(low, ["Mouse"])
        // Uzoq uzilishdan keyin — yangi ulanish; zaryadlangach ogohlantirish qayta qurollanadi.
        service.ingest(hid: [], announceProfiler: true, announceHID: true, now: start.addingTimeInterval(200))
        service.ingest(hid: [mouse(80)], announceProfiler: true, announceHID: true, now: start.addingTimeInterval(500))
        XCTAssertEqual(connected, ["Mouse"])
        service.ingest(hid: [mouse(18)], announceProfiler: true, announceHID: true, now: start.addingTimeInterval(560))
        XCTAssertEqual(low, ["Mouse", "Mouse"])
        // Profiler orqali topilgan qurilma faqat hodisa yangilanishida e'lon qilinadi.
        let pods = BluetoothDevice(id: "p", name: "AirPods", kind: .airpods, batteries: [BatteryReading(part: .left, percent: 90)])
        service.ingest(hid: [mouse(18)], profiler: [pods], announceProfiler: false, announceHID: true, now: start.addingTimeInterval(600))
        XCTAssertEqual(connected, ["Mouse"])
    }
}
