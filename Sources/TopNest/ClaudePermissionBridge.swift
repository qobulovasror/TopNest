import Darwin
import Foundation

struct PermissionRequest: Identifiable, Equatable {
    let id: UUID
    let tool: String
    let summary: String
    let detail: String
    let truncated: Bool
    let project: String
    let receivedAt: Date

    // Kesilgan yoki fayl yozadigan so'rovni to'liq ko'rib bo'lmaydi — qaror terminalda qabul qilinadi.
    var canApproveHere: Bool {
        !truncated && !["Write", "Edit", "MultiEdit", "NotebookEdit"].contains(tool)
    }
}

enum PermissionDecision: String {
    case allow, deny
}

// Claude Code PermissionRequest hook'i va TopNest orasidagi ko'prik.
// Javob bo'lmasa (ilova yopiq, vaqt tugadi) hook hech narsa chiqarmaydi va Claude odatiy so'rovni ko'rsatadi.
enum ClaudePermissionBridge {
    static let commandFlag = "--claude-permission"
    static let waitSeconds = 110
    static let hookTimeout = 120
    static let detailLimit = 4000

    static var socketURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TopNest/permission.sock")
    }

    // MARK: Hook jarayoni

    static func runHook() {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard let root = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any],
              let tool = root["tool_name"] as? String else { return }
        let fields = root["tool_input"] as? [String: Any] ?? [:]
        let full = describe(tool: tool, fields: fields)
        let request: [String: Any] = [
            "tool": tool,
            "summary": fields["description"] as? String ?? "",
            "detail": String(full.prefix(detailLimit)),
            "truncated": full.count > detailLimit,
            "project": ((root["cwd"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent }) ?? ""
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: request),
              let reply = exchange(payload + Data([10]), timeout: waitSeconds),
              let answer = (try? JSONSerialization.jsonObject(with: reply)) as? [String: Any],
              let raw = answer["decision"] as? String,
              let decision = PermissionDecision(rawValue: raw) else { return }
        var output: [String: Any] = ["behavior": decision.rawValue]
        if decision == .deny { output["message"] = "Foydalanuvchi TopNest orqali rad etdi." }
        let result: [String: Any] = ["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": output]]
        if let data = try? JSONSerialization.data(withJSONObject: result) {
            FileHandle.standardOutput.write(data)
        }
    }

    // Buyruq yoki kiritma to'liq ko'rsatiladi; faqat ma'lum maydonlar qisqa ko'rinishda.
    private static func describe(tool: String, fields: [String: Any]) -> String {
        if tool == "Bash", let command = fields["command"] as? String {
            let extra = fields.keys.filter { !["command", "description", "timeout"].contains($0) }
            if extra.isEmpty { return command }
        }
        if let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]),
           let json = String(data: data, encoding: .utf8) { return json }
        return tool
    }

    private static func exchange(_ payload: Data, timeout: Int) -> Data? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_un()
        guard fill(&address) else { return nil }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0, writeAll(fd, payload) else { return nil }
        return readLine(fd, deadline: Date().addingTimeInterval(TimeInterval(timeout)))
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

// Ilova ichidagi Unix socket serveri. Har ulanish bitta so'rov va bitta javob.
final class PermissionServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "topnest.permission")
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var clients: [UUID: (fd: Int32, source: DispatchSourceRead)] = [:]
    private let onRequest: @Sendable (PermissionRequest) -> Void
    private let onCancel: @Sendable (UUID) -> Void

    init(onRequest: @escaping @Sendable (PermissionRequest) -> Void, onCancel: @escaping @Sendable (UUID) -> Void) {
        self.onRequest = onRequest
        self.onCancel = onCancel
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

    func respond(_ id: UUID, decision: PermissionDecision?) {
        queue.async {
            guard let client = self.clients.removeValue(forKey: id) else { return }
            if let decision, let data = try? JSONSerialization.data(withJSONObject: ["decision": decision.rawValue]) {
                _ = ClaudePermissionBridge.writeAll(client.fd, data + Data([10]))
            }
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
        let request = PermissionRequest(
            id: UUID(), tool: tool,
            summary: body["summary"] as? String ?? "",
            detail: body["detail"] as? String ?? "",
            truncated: body["truncated"] as? Bool ?? true,
            project: body["project"] as? String ?? "",
            receivedAt: Date()
        )
        // Hook uzilsa (vaqt tugadi) yoki protokoldan tashqari bayt yuborsa, so'rov paneldan olinadi.
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            guard let self, self.clients.removeValue(forKey: request.id) != nil else { return }
            source.cancel()
            self.onCancel(request.id)
        }
        source.setCancelHandler { close(fd) }
        clients[request.id] = (fd, source)
        source.resume()
        onRequest(request)
    }
}
