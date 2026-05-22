// MotionRecorder.swift
// Watch App
//
// startDeviceMotionUpdates を使い、加速度・回転レートを 50Hz で
// 単一コールバックから同期取得する（watchOS 推奨方式）。
// 旧実装の startAccelerometerUpdates + startGyroUpdates は
// watchOS で isGyroAvailable = false になる場合があり動作しなかった。

import Foundation
import CoreMotion

struct MotionSample {
    let time: Double       // Unix timestamp (秒)
    let accX: Double
    let accY: Double
    let accZ: Double
    let gyroX: Double
    let gyroY: Double
    let gyroZ: Double
}

final class MotionRecorder {

    // MARK: - 設定
    private let sampleRate: Double    = 50.0   // Hz
    private let bufferDuration: Double = 10.0  // バッファ保持量（秒）
    private let windowBefore: Double   = 5.0   // ボタン押下前の取り出し幅

    // MARK: - 内部状態
    private let manager    = CMMotionManager()
    private let queue      = OperationQueue()
    private var buffer: [MotionSample] = []
    private let bufferLock = NSLock()

    // MARK: - 公開 API

    var isRecording: Bool { manager.isDeviceMotionActive }

    func start() {
        guard manager.isDeviceMotionAvailable else {
            print("[MotionRecorder] DeviceMotion 利用不可")
            return
        }

        manager.deviceMotionUpdateInterval = 1.0 / sampleRate

        manager.startDeviceMotionUpdates(to: queue) { [weak self] data, error in
            guard let self else { return }
            if let error {
                print("[MotionRecorder] エラー: \(error)")
                return
            }
            guard let data else { return }

            let now = Date().timeIntervalSince1970
            let sample = MotionSample(
                time:  now,
                accX:  data.userAcceleration.x,
                accY:  data.userAcceleration.y,
                accZ:  data.userAcceleration.z,
                gyroX: data.rotationRate.x,
                gyroY: data.rotationRate.y,
                gyroZ: data.rotationRate.z
            )

            self.bufferLock.lock()
            self.buffer.append(sample)
            let oldest = now - self.bufferDuration
            while let first = self.buffer.first, first.time < oldest {
                self.buffer.removeFirst()
            }
            self.bufferLock.unlock()
        }
        print("[MotionRecorder] 開始 (\(Int(sampleRate))Hz)")
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    /// ボタン押下時に呼ぶ。直近 windowBefore 秒分のサンプルを返す。
    func snapshot() -> [MotionSample] {
        let cutoff = Date().timeIntervalSince1970 - windowBefore
        bufferLock.lock()
        let result = buffer.filter { $0.time >= cutoff }
        bufferLock.unlock()
        print("[MotionRecorder] snapshot: \(result.count) サンプル")
        return result
    }
}

// MARK: - CSV 変換

extension [MotionSample] {
    /// header 付き CSV 文字列を生成。label 列を末尾に追加。
    func toCSV(label: String) -> String {
        var lines = ["time,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z,label"]
        for s in self {
            lines.append(String(format: "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%@",
                                s.time,
                                s.accX, s.accY, s.accZ,
                                s.gyroX, s.gyroY, s.gyroZ,
                                label))
        }
        return lines.joined(separator: "\n")
    }
}
