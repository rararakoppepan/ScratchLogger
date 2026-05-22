// WatchLoggerVM.swift
// Watch Extension

import SwiftUI
import Combine

final class WatchLoggerVM: NSObject, ObservableObject {

    @Published var itchLevel: Int = 5
    @Published var statusText: String = "待機中..."
    @Published var isSending: Bool = false
    @Published var sessionCount: Int = 0      // このセッションで記録した件数
    @Published var showConfirmation: Bool = false
    @Published var lastLabel: String = ""

    private let recorder = MotionRecorder()
    private let session = WatchSessionManager.shared

    override init() {
        super.init()
        recorder.start()
        session.onStatusUpdate = { [weak self] message in
            self?.statusText = message
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

        // 確認アニメーションを1.5秒表示
        showConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showConfirmation = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSending = false
        }
    }
}
