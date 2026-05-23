// WatchContentView.swift
// Watch App

import SwiftUI

struct WatchContentView: View {
    @StateObject private var vm = WatchLoggerVM()

    var body: some View {
        ZStack {
            mainContent
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

                // 接続状態バー
                connectionBar

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

    // MARK: - 接続状態バー

    private var connectionBar: some View {
        HStack(spacing: 6) {
            // 接続インジケーター（●）
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)

            Text(vm.connectionState.label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            // 記録件数 or 送信待ちバッジ
            if vm.pendingCount > 0 {
                // 送信待ちがある場合は件数を目立たせる
                HStack(spacing: 2) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 10))
                    Text("\(vm.pendingCount)件待機")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.orange)
            } else {
                Label("\(vm.sessionCount)件", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - 確認オーバーレイ

    private var confirmationOverlay: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(vm.lastLabel == "scratch" ? .red : .blue)
            Text("記録しました")
                .font(.system(size: 13, weight: .semibold))
            // 未送信なら補足メッセージ
            if vm.pendingCount > 0 {
                Text("接続後に自動送信")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - ヘルパー

    private var connectionColor: Color {
        switch vm.connectionState {
        case .connected:    return .green
        case .connecting:   return .orange
        case .disconnected: return .gray
        case .error:        return .red
        }
    }

    private func itchColor(_ level: Int) -> Color {
        switch level {
        case 0...3: return .green
        case 4...6: return .orange
        default:    return .red
        }
    }
}
