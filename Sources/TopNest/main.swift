import AppKit
import Foundation

if CommandLine.arguments.contains(ClaudeStatusBridge.commandFlag) {
    ClaudeStatusBridge.run()
} else if CommandLine.arguments.contains(ClaudePermissionBridge.commandFlag) {
    ClaudePermissionBridge.runHook()
} else if let index = CommandLine.arguments.firstIndex(of: ClaudePermissionBridge.genericFlag),
          CommandLine.arguments.indices.contains(index + 1) {
    ClaudePermissionBridge.runHook(provider: CommandLine.arguments[index + 1])
} else {
    MainActor.assumeIsolated {
        SettingsMigration.migrateIfNeeded()
        let app = NSApplication.shared
        let delegate = TopNestAppDelegate()
        app.delegate = delegate
        app.run()
    }
}
