// WatchSessionManager.swift
// Watch Extension

import Foundation
import WatchConnectivity

final class WatchSessionManager: NSObject, WCSessionDelegate {

    static let shared = WatchSessionManager()

    var onStatusUpdate: ((String) -> Void)?

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
        let motionCSV = samples.toCSV(label: label)
        let metaLine = "\(timestamp),\(label),\(itchLevel),\(samples.count)\n"

        let payload: [String: Any] = [
            "meta": metaLine,
            "motion": motionCSV,
            "label": label,
            "timestamp": timestamp
        ]

        WCSession.default.transferUserInfo(payload)

        DispatchQueue.main.async {
            self.onStatusUpdate?("送信完了 [\(label)] itch=\(itchLevel) (\(samples.count)サンプル)")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            DispatchQueue.main.async {
                self.onStatusUpdate?("接続エラー: \(error.localizedDescription)")
            }
        }
    }
}
