// WatchLoggerVM.swift
// Watch App

import SwiftUI
import Combine

final class WatchLoggerVM: NSObject, ObservableObject {

    @Published var itchLevel: Int = 5
    @Published var isSending: Bool = false
    @Published var sessionCount: Int = 0
    @Published var showConfirmation: Bool = false
    @Published var lastLabel: String = ""
    @Published var statusText: String = "接続中..."
    @Published var connectionState: WatchSessionManager.ConnectionState = .connecting
    @Published var pendingCount: Int = 0   // iPhoneへの送信待ち件数

    private let recorder = MotionRecorder()
    private let session  = WatchSessionManager.shared

    override init() {
        super.init()
        recorder.start()

        session.onStatusUpdate = { [weak self] message in
            self?.statusText = message
        }
        session.onConnectionStateChange = { [weak self] state in
            self?.connectionState = state
        }
        session.onPendingCountChange = { [weak self] count in
            self?.pendingCount = count
        }
    }

    func logScratch() { sendLog(label: "scratch") }
    func logNormal()  { sendLog(label: "normal") }

    private func sendLog(label: String) {
        guard !isSending else { return }
        isSending = true
        lastLabel = label

        let samples = recorder.snapshot()
        session.send(samples: samples, label: label, itchLevel: itchLevel)
        sessionCount += 1

        showConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showConfirmation = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSending = false
        }
    }
}
