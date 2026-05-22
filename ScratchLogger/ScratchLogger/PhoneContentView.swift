// PhoneContentView.swift
// iPhone App

import SwiftUI
import Charts
import UIKit

// MARK: - Filter

enum LogFilter: String, CaseIterable {
    case all     = "全て"
    case scratch = "掻き"
    case normal  = "通常"
}

// MARK: - Chart Entry

private struct ItchEntry: Identifiable {
    let id = UUID()
    let time: Date
    let level: Int
}

// MARK: - Main View

struct PhoneContentView: View {
    @StateObject private var session = PhoneSessionManager.shared
    @State private var filter: LogFilter = .all

    // MARK: - Computed

    var filteredLogs: [ScratchLog] {
        switch filter {
        case .all:     return session.logs
        case .scratch: return session.logs.filter { $0.label == "scratch" }
        case .normal:  return session.logs.filter { $0.label == "normal" }
        }
    }

    private let tsParser = ISO8601DateFormatter()
    private var todayStart: Date { Calendar.current.startOfDay(for: Date()) }

    private var todayLogs: [ScratchLog] {
        session.logs.filter {
            guard let d = tsParser.date(from: $0.timestamp) else { return false }
            return d >= todayStart
        }
    }
    private var todayScratch: [ScratchLog] { todayLogs.filter { $0.label == "scratch" } }
    private var todayCount:   Int    { todayScratch.count }
    private var todayAvgItch: Double {
        guard !todayScratch.isEmpty else { return 0 }
        return Double(todayScratch.map(\.itchLevel).reduce(0, +)) / Double(todayScratch.count)
    }
    private var todayMaxItch: Int { todayScratch.map(\.itchLevel).max() ?? 0 }

    private var chartEntries: [ItchEntry] {
        todayScratch.compactMap { log in
            guard let d = tsParser.date(from: log.timestamp) else { return nil }
            return ItchEntry(time: d, level: log.itchLevel)
        }.sorted { $0.time < $1.time }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // 今日のサマリー（記録があるときだけ）
                if !todayScratch.isEmpty {
                    Section("今日のサマリー") {
                        statsRow
                        itchChart
                    }
                }

                // フィルタータブ
                Section {
                    Picker("フィルター", selection: $filter) {
                        ForEach(LogFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                // ログ一覧
                Section {
                    if filteredLogs.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.largeTitle)
                                    .foregroundStyle(.tertiary)
                                Text(session.logs.isEmpty
                                     ? "Watchから掻き動作を送信するとここに表示されます"
                                     : "このフィルターに一致する記録はありません")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 24)
                            Spacer()
                        }
                    } else {
                        ForEach(filteredLogs) { log in
                            LogRow(log: log)
                        }
                        .onDelete { indexSet in
                            for i in indexSet { session.deleteLog(filteredLogs[i]) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("掻き記録")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(session.logs.count)件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: shareAll) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(session.logs.isEmpty)
                }
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell("hand.raised.fill",
                     "\(todayCount)",
                     "掻いた回数",
                     .red)
            Divider().padding(.vertical, 10)
            statCell("thermometer.medium",
                     String(format: "%.1f", todayAvgItch),
                     "平均レベル",
                     itchColor(todayAvgItch))
            Divider().padding(.vertical, 10)
            statCell("arrow.up.circle.fill",
                     "\(todayMaxItch)",
                     "最大レベル",
                     itchColor(Double(todayMaxItch)))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func statCell(
        _ icon: String, _ value: String, _ label: String, _ color: Color
    ) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Itch Chart

    private var itchChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("痒みレベル推移")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart(chartEntries) { e in
                // 塗りつぶしエリア
                AreaMark(
                    x: .value("時刻", e.time),
                    yStart: .value("zero", 0),
                    yEnd:   .value("レベル", e.level)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange.opacity(0.25), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                // ライン
                LineMark(
                    x: .value("時刻", e.time),
                    y: .value("レベル", e.level)
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                // ポイント（色はレベルに応じて変化）
                PointMark(
                    x: .value("時刻", e.time),
                    y: .value("レベル", e.level)
                )
                .foregroundStyle(pointColor(e.level))
                .symbolSize(50)
                .annotation(position: .top, spacing: 3) {
                    Text("\(e.level)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(pointColor(e.level))
                }
            }
            .chartYScale(domain: 0...10)
            .chartYAxis {
                AxisMarks(values: [0, 5, 10]) {
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { _ in
                    AxisGridLine()
                    AxisValueLabel(
                        format: .dateTime.hour(.defaultDigits(amPM: .narrow))
                    )
                }
            }
            .frame(height: 150)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Share（UIActivityViewController を直接 present）

    private func shareAll() {
        let items = session.allExportURLs()
        guard !items.isEmpty else { return }

        let actVC = UIActivityViewController(
            activityItems: items, applicationActivities: nil
        )

        // iPad 向けポップオーバー設定
        if let popover = actVC.popoverPresentationController {
            // ナビゲーションバーの共有ボタン付近を指す
            if let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })?
                .windows.first(where: { $0.isKeyWindow }) {
                popover.sourceView = window
                popover.sourceRect = CGRect(
                    x: window.bounds.maxX - 56,
                    y: window.safeAreaInsets.top + 44,
                    width: 44, height: 1
                )
                popover.permittedArrowDirections = .up
            }
        }

        // 最前面の ViewController から present
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: { $0.isKeyWindow })?
            .rootViewController else { return }

        var top = root
        while let next = top.presentedViewController { top = next }
        top.present(actVC, animated: true)
    }

    // MARK: - Color Helpers

    private func itchColor(_ v: Double) -> Color {
        switch v {
        case ..<4: return .green
        case ..<7: return .orange
        default:   return .red
        }
    }
    private func pointColor(_ v: Int) -> Color {
        switch v {
        case 0...3: return .green
        case 4...6: return .orange
        default:    return .red
        }
    }
}

// MARK: - Log Row

struct LogRow: View {
    let log: ScratchLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.label == "scratch" ? "hand.raised.fill" : "figure.walk")
                .font(.title2)
                .foregroundStyle(log.label == "scratch" ? .red : .blue)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(log.label == "scratch" ? "掻き" : "通常")
                        .font(.headline)
                        .foregroundStyle(log.label == "scratch" ? .red : .primary)
                    Spacer()
                    Text("痒み \(log.itchLevel)/10")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(itchColor(log.itchLevel).opacity(0.15))
                        .foregroundStyle(itchColor(log.itchLevel))
                        .clipShape(Capsule())
                }
                Text(formattedTime(log.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(log.sampleCount)サンプル")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func itchColor(_ level: Int) -> Color {
        switch level {
        case 0...3: return .green
        case 4...6: return .orange
        default:    return .red
        }
    }

    private func formattedTime(_ iso: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: iso) else { return iso }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M/d HH:mm:ss"
        return fmt.string(from: date)
    }
}
