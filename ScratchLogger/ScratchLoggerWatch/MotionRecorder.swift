// MotionRecorder.swift
// Watch Extension
// 加速度 + ジャイロを50Hzで記録し、直近10秒分をバッファリング。
// ボタン押下時に「押下前5秒 + 押下後0秒（即時）」を切り出してCSV化。
// 将来のML自動検出に備え、タイムスタンプはUnix時刻(秒・小数点6桁)で統一。

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
    private let sampleRate: Double = 50.0          // Hz
    private let bufferDuration: Double = 10.0      // 秒（バッファ保持量）
    private let windowBefore: Double = 5.0         // 切り出し：ボタン押下前
    private let windowAfter:  Double = 0.0         // 切り出し：ボタン押下後（即時送信なので0）

    // MARK: - 内部状態
    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    private var buffer: [MotionSample] = []
    private let bufferLock = NSLock()

    // 最新の加速度・ジャイロを別々に受け取り、同一タイムスタンプで合成するための一時変数
    private var latestAcc: CMAcceleration?
    private var latestGyro: CMRotationRate?

    // MARK: - 公開API

    var isRecording: Bool { manager.isAccelerometerActive }

    func start() {
        guard manager.isAccelerometerAvailable,
              manager.isGyroAvailable else { return }

        let interval = 1.0 / sampleRate
        manager.accelerometerUpdateInterval = interval
        manager.gyroUpdateInterval = interval

        // 加速度とジャイロを同じキューで受け取り、両方揃ったらサンプルを確定する
        manager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.latestAcc = data.acceleration
            self.tryCommitSample(time: Date().timeIntervalSince1970)
        }

        manager.startGyroUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.latestGyro = data.rotationRate
            self.tryCommitSample(time: Date().timeIntervalSince1970)
        }
    }

    func stop() {
        manager.stopAccelerometerUpdates()
        manager.stopGyroUpdates()
    }

    /// ボタン押下時に呼ぶ。直近 windowBefore 秒分のサンプルを返す。
    func snapshot() -> [MotionSample] {
        let cutoff = Date().timeIntervalSince1970 - windowBefore
        bufferLock.lock()
        let result = buffer.filter { $0.time >= cutoff }
        bufferLock.unlock()
        return result
    }

    // MARK: - 内部

    private func tryCommitSample(time: Double) {
        guard let acc = latestAcc, let gyro = latestGyro else { return }

        let sample = MotionSample(
            time: time,
            accX: acc.x, accY: acc.y, accZ: acc.z,
            gyroX: gyro.x, gyroY: gyro.y, gyroZ: gyro.z
        )

        bufferLock.lock()
        buffer.append(sample)
        // 古いサンプルを削除
        let oldest = time - bufferDuration
        while let first = buffer.first, first.time < oldest {
            buffer.removeFirst()
        }
        bufferLock.unlock()

        // 使い回しを防ぐためリセット
        latestAcc = nil
        latestGyro = nil
    }
}

// MARK: - CSV変換

extension [MotionSample] {
    /// header付きCSV文字列を生成。label列を末尾に追加。
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
