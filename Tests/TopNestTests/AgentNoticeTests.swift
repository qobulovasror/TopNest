import XCTest
@testable import TopNest

final class AgentNoticeTests: XCTestCase {
    func testClaudeQuestionShowsQuestionWithoutRawJSONOrApprovalDecision() {
        let input: [String: Any] = [
            "tool_name": "AskUserQuestion",
            "cwd": "/projects/vehicle_registry",
            "tool_input": ["questions": [[
                "header": "Списан",
                "question": "Hisobdan chiqarilgan skuterlar jami parkka kirsinmi?",
                "options": [["label": "Kirmasin"], ["label": "Kirsin"]]
            ]]]
        ]
        let notice = ClaudePermissionBridge.noticePayload(provider: "Claude", root: input)
        XCTAssertEqual(notice?["summary"] as? String, "Hisobdan chiqarilgan skuterlar jami parkka kirsinmi?")
        XCTAssertEqual(notice?["tool"] as? String, "AskUserQuestion")
        XCTAssertEqual(notice?["project"] as? String, "vehicle_registry")
        XCTAssertNil(notice?["decision"])
        XCTAssertFalse((notice?["summary"] as? String ?? "").contains("options"))
    }

    func testCodexPermissionDoesNotExposeCommand() {
        let input: [String: Any] = [
            "tool_name": "Bash",
            "tool_input": ["command": "echo secret-value", "description": "Run command"]
        ]
        let notice = ClaudePermissionBridge.noticePayload(provider: "Codex", root: input)
        XCTAssertEqual(notice?["summary"] as? String, "Bash uchun qarorni Codex oynasida qabul qiling.")
        XCTAssertFalse((notice?["summary"] as? String ?? "").contains("secret-value"))
    }

    func testGenericEventCanUseMessageWithoutTool() {
        let notice = ClaudePermissionBridge.noticePayload(provider: "Other AI", root: ["message": "Javobingiz kutilmoqda"])
        XCTAssertEqual(notice?["summary"] as? String, "Javobingiz kutilmoqda")
    }

    func testCodexHookInstallAndRemovePreservesOtherHooks() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("hooks.json")
        let original: [String: Any] = ["description": "Keep this", "hooks": [
            "PermissionRequest": [["matcher": "Bash", "hooks": [["type": "command", "command": "echo existing"]]]],
            "Stop": [["hooks": [["type": "command", "command": "echo done"]]]]
        ]]
        try JSONSerialization.data(withJSONObject: original).write(to: url)
        let executable = URL(fileURLWithPath: "/Applications/TopNest.app/Contents/MacOS/TopNest")
        XCTAssertNotNil(CodexHookBridge.update(enabled: true, at: url, executable: executable))
        let installed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let hooks = try XCTUnwrap(installed["hooks"] as? [String: Any])
        XCTAssertNotNil(hooks["Stop"])
        XCTAssertEqual((hooks["PermissionRequest"] as? [Any])?.count, 2)
        XCTAssertNil(CodexHookBridge.update(enabled: false, at: url, executable: nil))
        let restored = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(restored["description"] as? String, "Keep this")
        let restoredHooks = try XCTUnwrap(restored["hooks"] as? [String: Any])
        XCTAssertEqual((restoredHooks["PermissionRequest"] as? [Any])?.count, 1)
        XCTAssertNotNil(restoredHooks["Stop"])
    }
}
