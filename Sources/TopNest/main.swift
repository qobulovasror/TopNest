import AppKit
import Foundation

if CommandLine.arguments.contains(ClaudeStatusBridge.commandFlag) {
    ClaudeStatusBridge.run()
} else if CommandLine.arguments.contains(ClaudePermissionBridge.commandFlag) {
    ClaudePermissionBridge.runHook()
} else {
    MainActor.assumeIsolated {
        SettingsMigration.migrateIfNeeded()
        let app = NSApplication.shared
        let delegate = TopNestAppDelegate()
        app.delegate = delegate
        app.run()
    }
}
