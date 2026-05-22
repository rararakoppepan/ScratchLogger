// PhoneContentView.swift
// iPhone App

import SwiftUI
import UIKit

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Filter

enum LogFilter: String, CaseIterable {
    case all     = "全て"
    case scratch = "掻き"
    case normal  = "通常"
}

// MARK: - Main View

struct PhoneContentView: View {
    @StateObject private var session = PhoneSessionManager.shared
    @State private var filter: LogFilter = .all
    @State private var showingShare = false

    var filteredLogs: [ScratchLog] {
        switch filter {
        case .all:     return session.logs
        case .scratch: return session.logs.filter { $0.label == "scratch" }
        case .normal:  return session.logs.filter { $0.label == "normal" }
        }
    }

    // 今日の統計
    private var todayLogs: [ScratchLog] {
        let today = Calendar.current.startOfDay(for: Date())
        let parser = ISO8601DateFormatter()
        return session.logs.filter {
            guard let date = parser.date(from: $0.timestamp) else { return false }
            return date >= today
        }
    }
    private var todayScratchCount: Int { todayLogs.filter { $0.label == "scratch" }.count }
    private var todayAvgItch: Double {
        let s = todayLogs.filter { $0.label == "scratch" }
        guard !s.isEmpty else { return 0 }
        return Double(s.map(\.itchLevel).reduce(0, +)) / Double(s.count)
    }

    var body: some View {
        NavigationStack {
            List {
                // 統計カード（今日記録があるときのみ）
                if !todayLogs.isEmpty {
                    Section {
                        StatsCard(
                            scratchCount: todayScratchCount,
                            avgItch: todayAvgItch
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // フィルターピッカー
                Section {
                    Picker("フィルター", selection: $filter) {
                        ForEach(LogFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .listRowBackground(Color.clear)

                // ログ一覧
                Section {
                    if filteredLogs.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.largeTitle)
                                    .foregroundStyle(.tertiary)
                                Text("記録なし")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 24)
                            Spacer()
                        }
                    } else {
                        ForEach(filteredLogs) { log in
                            LogRow(log: log)
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                session.deleteLog(filteredLogs[i])
                            }
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
                    Button {
                        showingShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(session.logs.isEmpty)
                }
            }
            .sheet(isPresented: $showingShare) {
                ShareSheet(items: session.allExportURLs())
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Stats Card

struct StatsCard: View {
    let scratchCount: Int
    let avgItch: Double

    var body: some View {
        HStack(spacing: 0) {
            statCell(
                icon: "hand.raised.fill",
                value: "\(scratchCount)",
                label: "今日の掻き回数",
                color: scratchCount == 0 ? .green : .red
            )
            Divider().padding(.vertical, 16)
            statCell(
                icon: "thermometer.medium",
                value: avgItch > 0 ? String(format: "%.1f", avgItch) : "—",
                label: "平均痒みレベル",
                color: itchColor(avgItch)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func statCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func itchColor(_ level: Double) -> Color {
        switch level {
        case ..<4: return .green
        case ..<7: return .orange
        default:   return .red
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
