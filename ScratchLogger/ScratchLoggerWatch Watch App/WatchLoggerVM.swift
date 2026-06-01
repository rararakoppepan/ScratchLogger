// WatchLoggerVM.swift
// Watch App

import SwiftUI
import Combine

// MARK: - 通常動作の種類

enum NormalActivity: String, CaseIterable, Identifiable {
    case still = "normal_still"
    case walk  = "normal_walk"
    case eat   = "normal_eat"
    case type  = "normal_type"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .still: return "静止"
        case .walk:  return "歩き"
        case .eat:   return "食事"
        case .type:  return "タイプ"
        }
    }

    var icon: String {
        switch self {
        case .still: return "figure.stand"
        case .walk:  return "figure.walk"
        case .eat:   return "fork.knife"
        case .type:  return "keyboard"
        }
    }
}

// MARK: - ViewModel

final class WatchLoggerVM: NSObject, ObservableObject {

    @Published var itchLevel: Int = 5
    @Published var isSending: Bool = false
    @Published var scratchCount: Int = 0    // セッション中の掻き件数
    @Published var normalCount: Int = 0     // セッション中の通常動作件数
    @Published var showConfirmation: Bool = false
    @Published var lastLabel: String = ""
    @Published var statusText: String = "接続中..."
    @Published var connectionState: WatchSessionManager.ConnectionState = .connecting
    @Published var pendingCount: Int = 0

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

    // MARK: - 記録

    func logScratch() {
        sendLog(label: "scratch")
    }

    func logNormal(activity: NormalActivity) {
        sendLog(label: activity.rawValue)
    }

    private func sendLog(label: String) {
        guard !isSending else { return }
        isSending = true
        lastLabel = label

        let samples = recorder.snapshot()
        session.send(samples: samples, label: label, itchLevel: itchLevel)

        if label == "scratch" {
            scratchCount += 1
        } else {
            normalCount += 1
        }

        showConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showConfirmation = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSending = false
        }
    }
}
