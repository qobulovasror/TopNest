import AppKit
import Foundation

if CommandLine.arguments.contains("--claude-statusline") {
    ClaudeStatusBridge.run()
} else {
    MainActor.assumeIsolated {
        SettingsMigration.migrateIfNeeded()
        let app = NSApplication.shared
        let delegate = TopNestAppDelegate()
        app.delegate = delegate
        app.run()
    }
}
