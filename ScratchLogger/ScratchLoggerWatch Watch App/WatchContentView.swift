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
            VStack(spacing: 8) {

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

                Divider()

                // 通常動作グリッド
                normalActivityGrid

                Divider()

                // 収集進捗
                progressRow
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - 通常動作グリッド（2×2）

    private var normalActivityGrid: some View {
        VStack(spacing: 4) {
            HStack {
                Text("通常動作を記録")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 4
            ) {
                ForEach(NormalActivity.allCases) { activity in
                    Button(action: { vm.logNormal(activity: activity) }) {
                        VStack(spacing: 2) {
                            Image(systemName: activity.icon)
                                .font(.system(size: 13))
                            Text(activity.displayName)
                                .font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .disabled(vm.isSending)
                }
            }
        }
    }

    // MARK: - セッション進捗

    private var progressRow: some View {
        HStack(spacing: 0) {
            // 掻き
            VStack(spacing: 2) {
                Text("\(vm.scratchCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                Text("掻き")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 30)

            // 通常
            VStack(spacing: 2) {
                Text("\(vm.normalCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                Text("通常")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 30)

            // 送信待ち or 合計
            VStack(spacing: 2) {
                if vm.pendingCount > 0 {
                    Text("\(vm.pendingCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("待機")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                } else {
                    Text("\(vm.scratchCount + vm.normalCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("合計")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 接続状態バー

    private var connectionBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)

            Text(vm.connectionState.label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            if vm.pendingCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 10))
                    Text("\(vm.pendingCount)件待機")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - 確認オーバーレイ

    private var confirmationOverlay: some View {
        VStack(spacing: 6) {
            Image(systemName: confirmationIcon)
                .font(.system(size: 36))
                .foregroundStyle(confirmationColor)
            Text("記録しました")
                .font(.system(size: 13, weight: .semibold))
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

    private var confirmationIcon: String {
        vm.lastLabel == "scratch" ? "hand.raised.fill" : "checkmark.circle.fill"
    }

    private var confirmationColor: Color {
        vm.lastLabel == "scratch" ? .red : .blue
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
