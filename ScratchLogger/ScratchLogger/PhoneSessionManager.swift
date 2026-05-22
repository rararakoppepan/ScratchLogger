// PhoneSessionManager.swift
// iPhone App
// Watchから受け取ったデータをDocumentsに保存し、ログ一覧を公開する。
//
// ファイル構成（Documents/ScratchLogger/）
//   meta.csv              … 全記録のサマリー（1行1記録）
//   motion/
//     {timestamp}_{label}.csv … モーションデータ本体

import Foundation
import WatchConnectivity
import Combine

struct ScratchLog: Identifiable {
    let id = UUID()
    let timestamp: String
    let label: String
    let itchLevel: Int
    let sampleCount: Int
}

final class PhoneSessionManager: NSObject, WCSessionDelegate, ObservableObject {

    static let shared = PhoneSessionManager()

    @Published var logs: [ScratchLog] = []

    // MARK: - ファイルパス

    private var baseDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("ScratchLogger")
    }

    private var motionDir: URL {
        baseDir.appendingPathComponent("motion")
    }

    private var metaURL: URL {
        baseDir.appendingPathComponent("meta.csv")
    }

    // MARK: - 初期化

    override init() {
        super.init()
        setupDirectories()
        loadExistingLogs()

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {

        guard let meta   = userInfo["meta"]      as? String,
              let motion = userInfo["motion"]    as? String,
              let label  = userInfo["label"]     as? String,
              let tsRaw  = userInfo["timestamp"] as? String else { return }

        // meta.csv に追記
        appendToMeta(meta)

        // motion CSVを個別ファイルに保存
        let safeTS = tsRaw.replacingOccurrences(of: ":", with: "-")
        let motionFile = motionDir.appendingPathComponent("\(safeTS)_\(label).csv")
        try? motion.write(to: motionFile, atomically: true, encoding: .utf8)

        // ログパースしてUI更新
        if let log = parseMeta(meta) {
            DispatchQueue.main.async {
                self.logs.insert(log, at: 0)   // 新しい順に
            }
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    // MARK: - Private helpers

    private func setupDirectories() {
        let fm = FileManager.default
        try? fm.createDirectory(at: motionDir, withIntermediateDirectories: true)

        if !fm.fileExists(atPath: metaURL.path) {
            let header = "timestamp,label,itch_level,sample_count\n"
            try? header.write(to: metaURL, atomically: true, encoding: .utf8)
        }
    }

    private func appendToMeta(_ line: String) {
        guard let data = line.data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: metaURL) else { return }
        try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
        try? handle.close()
    }

    private func parseMeta(_ line: String) -> ScratchLog? {
        // フォーマット: timestamp,label,itch_level,sample_count\n
        let parts = line.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ",")
        guard parts.count >= 4 else { return nil }
        return ScratchLog(
            timestamp:   String(parts[0]),
            label:       String(parts[1]),
            itchLevel:   Int(parts[2]) ?? 0,
            sampleCount: Int(parts[3]) ?? 0
        )
    }

    private func loadExistingLogs() {
        guard let content = try? String(contentsOf: metaURL, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: .newlines).dropFirst() // headerスキップ
        logs = lines.compactMap { parseMeta($0) }.reversed()
    }

    // MARK: - エクスポート

    /// 全CSV（meta + 各モーションファイル）のURLを返す
    func allExportURLs() -> [URL] {
        let fm = FileManager.default
        var urls: [URL] = []
        if fm.fileExists(atPath: metaURL.path) { urls.append(metaURL) }
        if let files = try? fm.contentsOfDirectory(at: motionDir, includingPropertiesForKeys: nil) {
            urls.append(contentsOf: files.filter { $0.pathExtension == "csv" }.sorted { $0.lastPathComponent < $1.lastPathComponent })
        }
        return urls
    }

    // MARK: - 削除

    func deleteLog(_ log: ScratchLog) {
        logs.removeAll { $0.id == log.id }
        // モーションCSVを削除
        let safeTS = log.timestamp.replacingOccurrences(of: ":", with: "-")
        let motionFile = motionDir.appendingPathComponent("\(safeTS)_\(log.label).csv")
        try? FileManager.default.removeItem(at: motionFile)
        // meta.csvを再書き込み
        rewriteMeta()
    }

    private func rewriteMeta() {
        var lines = ["timestamp,label,itch_level,sample_count"]
        for log in logs.reversed() { // logs は新しい順なので逆順で時系列に
            lines.append("\(log.timestamp),\(log.label),\(log.itchLevel),\(log.sampleCount)")
        }
        let content = lines.joined(separator: "\n") + "\n"
        try? content.write(to: metaURL, atomically: true, encoding: .utf8)
    }
}
