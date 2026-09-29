import Darwin
import Foundation

struct AIEvent: Identifiable, Equatable {
    let id: UUID
    let provider: String
    let tool: String
    let summary: String
    let project: String
}

// Claude/Codex hook'i faqat bildirishnoma uzatadi. stdout doim bo'sh:
// AI dasturining o'z savoli yoki ruxsat oynasi odatdagidek ishlaydi.
enum ClaudePermissionBridge {
    static let commandFlag = "--claude-permission"
    static let genericFlag = "--ai-event"
    static let hookTimeout = 3

    static var socketURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TopNest/permission.sock")
    }

    // MARK: Hook jarayoni

    static func runHook(provider: String = "Claude") {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard input.count <= 65_536 else { return }
        guard let root = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any],
              let payload = noticePayload(provider: provider, root: root),
              let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        // stdout hech qachon qaror qaytarmaydi. Claude/Codex o'z oynasida kutishda davom etadi.
        _ = exchange(data + Data([10]))
    }

    static func noticePayload(provider: String, root: [String: Any]) -> [String: Any]? {
        let name = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 32 else { return nil }
        let tool = root["tool_name"] as? String ?? ""
        let fields = root["tool_input"] as? [String: Any] ?? [:]
        let summary: String
        if tool == "AskUserQuestion" {
            guard let questions = fields["questions"] as? [[String: Any]],
                  let question = questions.first?["question"] as? String, !question.isEmpty else { return nil }
            summary = questions.count > 1 ? "\(questions.count) savoldan birinchisi: \(question)" : question
        } else if tool == "ExitPlanMode" {
            summary = "Rejani \(name) oynasida ko‘rib chiqing."
        } else if !tool.isEmpty {
            summary = "\(tool) uchun qarorni \(name) oynasida qabul qiling."
        } else if let message = root["message"] as? String, !message.isEmpty {
            summary = message
        } else { return nil }
        return [
            "provider": name,
            "tool": tool,
            "summary": String(summary.replacingOccurrences(of: "\n", with: " ").prefix(240)),
            "project": ((root["cwd"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent }) ?? ""
        ]
    }

    private static func exchange(_ payload: Data) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_un()
        guard fill(&address) else { return false }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        return connected == 0 && writeAll(fd, payload)
    }

    // Boshqa TopNest nusxasi socket'ni tinglayotgan bo'lsa, u o'chirilmaydi.
    fileprivate static func socketInUse() -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var address = sockaddr_un()
        guard fill(&address) else { return false }
        return withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        } == 0
    }

    // MARK: Umumiy yordamchilar

    fileprivate static func fill(_ address: inout sockaddr_un) -> Bool {
        let path = socketURL.path
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < capacity else { return false }
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.initializeMemory(as: UInt8.self, repeating: 0)
            buffer.copyBytes(from: path.utf8)
        }
        return true
    }

    fileprivate static func writeAll(_ fd: Int32, _ data: Data) -> Bool {
        data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let written = write(fd, buffer.baseAddress! + offset, buffer.count - offset)
                if written <= 0 { return false }
                offset += written
            }
            return true
        }
    }

    fileprivate static func readLine(_ fd: Int32, deadline: Date) -> Data? {
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while buffer.count < 65_536 {
            let remaining = Int32(max(0, deadline.timeIntervalSinceNow) * 1000)
            guard remaining > 0 else { return nil }
            var poller = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            guard poll(&poller, 1, remaining) > 0 else { return nil }
            let count = read(fd, &chunk, chunk.count)
            guard count > 0 else { return nil }
            buffer.append(chunk, count: count)
            if let newline = buffer.firstIndex(of: 10) { return buffer[..<newline] }
        }
        return nil
    }
}

// Ilova ichidagi Unix socket serveri. Har ulanishdan keyin darhol yopiladi.
final class AIEventServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "topnest.ai-events")
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var clients: [UUID: (fd: Int32, source: DispatchSourceRead)] = [:]
    private let onEvent: @Sendable (AIEvent) -> Void

    init(onEvent: @escaping @Sendable (AIEvent) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        queue.async { self.listen() }
    }

    func stop() {
        queue.sync {
            acceptSource?.cancel()
            acceptSource = nil
            for (_, client) in clients { client.source.cancel() }
            clients.removeAll()
            if listenFD >= 0 {
                listenFD = -1
                unlink(ClaudePermissionBridge.socketURL.path)
            }
        }
    }

    func finish(_ id: UUID) {
        queue.async {
            guard let client = self.clients.removeValue(forKey: id) else { return }
            client.source.cancel()
        }
    }

    private func listen() {
        guard listenFD < 0 else { return }
        let directory = ClaudePermissionBridge.socketURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        chmod(directory.path, 0o700)
        guard !ClaudePermissionBridge.socketInUse() else { return }
        unlink(ClaudePermissionBridge.socketURL.path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
        var address = sockaddr_un()
        guard ClaudePermissionBridge.fill(&address) else { close(fd); return }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, Darwin.listen(fd, 8) == 0 else { close(fd); return }
        chmod(ClaudePermissionBridge.socketURL.path, 0o600)
        listenFD = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptClient() }
        // libdispatch qoidasi: fd faqat source bekor qilingandan keyin yopiladi.
        source.setCancelHandler { close(fd) }
        source.resume()
        acceptSource = source
    }

    private func acceptClient() {
        let fd = accept(listenFD, nil, nil)
        guard fd >= 0 else { return }
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        guard let line = ClaudePermissionBridge.readLine(fd, deadline: Date().addingTimeInterval(0.5)),
              let body = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              let tool = body["tool"] as? String else { close(fd); return }
        let request = AIEvent(
            id: UUID(), provider: body["provider"] as? String ?? "Claude", tool: tool,
            summary: body["summary"] as? String ?? "",
            project: body["project"] as? String ?? ""
        )
        // Hook ulanishni yopganida klient resurslari darhol tozalanadi.
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            guard let self, self.clients.removeValue(forKey: request.id) != nil else { return }
            source.cancel()
        }
        source.setCancelHandler { close(fd) }
        clients[request.id] = (fd, source)
        source.resume()
        onEvent(request)
    }
}
