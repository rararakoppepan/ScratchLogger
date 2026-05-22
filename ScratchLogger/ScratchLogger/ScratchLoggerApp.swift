// ScratchLoggerApp.swift
// iPhone App

import SwiftUI

@main
struct ScratchLoggerApp: App {

    // 起動時にWCSessionを初期化
    private let sessionManager = PhoneSessionManager.shared

    var body: some Scene {
        WindowGroup {
            PhoneContentView()
        }
    }
}
