// WatchContentView.swift
// Watch Extension

import SwiftUI

struct WatchContentView: View {
    @StateObject private var vm = WatchLoggerVM()

    var body: some View {
        ZStack {
            mainContent
            // 記録完了オーバーレイ
            if vm.showConfirmation {
                confirmationOverlay
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showConfirmation)
    }

    // MARK: - メインコンテンツ

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 10) {

                // セッション件数 + ステータス
                HStack {
                    Label("\(vm.sessionCount)件記録", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                    Spacer()
                    Text(vm.statusText.prefix(12))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Divider()

                // 痒みレベル
                VStack(spacing: 4) {
                    HStack {
                        Text("痒みレベル")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(vm.itchLevel)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(itchColor(vm.itchLevel))
                    }
                    Slider(
                        value: Binding(
                            get: { Double(vm.itchLevel) },
                            set: { vm.itchLevel = Int($0) }
                        ),
                        in: 0...10,
                        step: 1
                    )
                    .tint(itchColor(vm.itchLevel))
                }

                // 掻いた！ボタン
                Button(action: { vm.logScratch() }) {
                    Label("掻いた！", systemImage: "hand.raised.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(vm.isSending)

                // 通常動作ボタン
                Button(action: { vm.logNormal() }) {
                    Label("通常動作", systemImage: "figure.walk")
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(vm.isSending)
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - 確認オーバーレイ

    private var confirmationOverlay: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(vm.lastLabel == "scratch" ? .red : .blue)
            Text(vm.lastLabel == "scratch" ? "記録しました" : "記録しました")
                .font(.system(size: 13, weight: .semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - ヘルパー

    private func itchColor(_ level: Int) -> Color {
        switch level {
        case 0...3: return .green
        case 4...6: return .orange
        default:    return .red
        }
    }
}
