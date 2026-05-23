// WatchSessionManager.swift
// Watch App

import Foundation
import WatchConnectivity

final class WatchSessionManager: NSObject, WCSessionDelegate {

    static let shared = WatchSessionManager()

    // MARK: - 接続状態

    enum ConnectionState {
        case connecting
        case connected
        case disconnected
        case error

        var label: String {
            switch self {
            case .connecting:    return "接続中..."
            case .connected:     return "接続済み"
            case .disconnected:  return "未接続"
            case .error:         return "接続エラー"
            }
        }
    }

    // MARK: - コールバック（WatchLoggerVM が購読）

    var onStatusUpdate: ((String) -> Void)?
    var onConnectionStateChange: ((ConnectionState) -> Void)?
    var onPendingCountChange: ((Int) -> Void)?

    // MARK: - 内部状態

    private var pendingPayloads: [[String: Any]] = []
    private let lock = NSLock()

    // MARK: - 初期化

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - 送信

    func send(samples: [MotionSample], label: String, itchLevel: Int) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let payload: [String: Any] = [
            "meta":      "\(timestamp),\(label),\(itchLevel),\(samples.count)\n",
            "motion":    samples.toCSV(label: label),
            "label":     label,
            "timestamp": timestamp
        ]
        transferOrQueue(payload, label: label, itchLevel: itchLevel, count: samples.count)
    }

    // MARK: - 内部

    private func transferOrQueue(
        _ payload: [String: Any],
        label: String,
        itchLevel: Int,
        count: Int
    ) {
        guard WCSession.default.activationState == .activated else {
            lock.lock()
            pendingPayloads.append(payload)
            let pending = pendingPayloads.count
            lock.unlock()

            DispatchQueue.main.async {
                self.onPendingCountChange?(pending)
                self.onStatusUpdate?("送信待ち \(pending)件")
            }
            return
        }

        WCSession.default.transferUserInfo(payload)
        DispatchQueue.main.async {
            self.onStatusUpdate?("送信完了 [\(label)] Lv\(itchLevel) \(count)件")
        }
    }

    private func flushPending() {
        lock.lock()
        let payloads = pendingPayloads
        pendingPayloads = []
        lock.unlock()

        guard !payloads.isEmpty else { return }

        for payload in payloads {
            WCSession.default.transferUserInfo(payload)
        }

        DispatchQueue.main.async {
            self.onPendingCountChange?(0)
            self.onStatusUpdate?("再送完了 \(payloads.count)件")
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            if let error {
                print("[WatchSession] activation error: \(error)")
                self.onConnectionStateChange?(.error)
                self.onStatusUpdate?("接続エラー")
            } else if activationState == .activated {
                self.onConnectionStateChange?(.connected)
                self.flushPending()          // 溜まった分を一括送信
            } else {
                self.onConnectionStateChange?(.disconnected)
            }
        }
    }
}
