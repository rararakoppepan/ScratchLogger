// ScratchLoggerWatchApp.swift
// Watch Extension

import SwiftUI

@main
struct ScratchLoggerWatchApp: App {

    // WatchSessionManager を起動時に初期化
    private let sessionManager = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}
