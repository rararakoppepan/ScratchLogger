# ScratchLogger

Apple Watch を使ってアトピー性皮膚炎の**掻き行動を記録・分析**するiOS / watchOSアプリです。
将来的にはCoreMLによる自動検知と、掻き始めたときに**振動で警告する機能**の実装を目指しています。

---

## 背景・動機

アトピー性皮膚炎の患者は、無意識に患部を掻いてしまうことが多く、本人が気づかないうちに症状が悪化します。
「掻いたタイミング・強さ・頻度」を客観的なデータとして記録し、機械学習で自動検知できれば、患者の自己管理に役立てられると考えこのアプリを開発しました。

---

## 機能

### ⌚ Watch App
- ワンタップで掻き行動を記録（「掻いた！」ボタン）
- 痒みレベル（0〜10）をスライダーで入力
- 通常動作を4種類に分類して記録（静止 / 歩き / 食事 / タイピング）
- iPhoneと未接続でも**オフラインキューで保持**し、接続後に自動送信
- セッション中の掻き件数・通常動作件数をリアルタイム表示

### 📱 iPhone App
- Watchから受信したモーションデータをリスト表示
- 今日の掻き回数・平均痒みレベル・最大痒みレベルをサマリー表示
- Swift Charts による**痒みレベル推移グラフ**
- ML用データ収集の進捗バー（目標：掻き50件 / 通常50件）
- CSV形式でMacにエクスポート（AirDrop・Files対応）
- スワイプで個別ログを削除

---

## アーキテクチャ

```
┌────────────────────────────┐       WatchConnectivity        ┌────────────────────────────┐
│       Apple Watch           │  ──── transferUserInfo ──▶    │          iPhone             │
│                             │                                │                             │
│  MotionRecorder             │                                │  PhoneSessionManager        │
│  (CoreMotion 50Hz)          │                                │  (WCSessionDelegate)        │
│       ↓                     │                                │       ↓                     │
│  WatchSessionManager        │                                │  Documents/ScratchLogger/   │
│  (offline queue)            │                                │  ├ meta.csv                 │
│       ↓                     │                                │  └ motion/{ts}_{label}.csv  │
│  WatchContentView (SwiftUI) │                                │  PhoneContentView (SwiftUI) │
└────────────────────────────┘                                └────────────────────────────┘
```

---

## 技術スタック

| 領域 | 技術 |
|---|---|
| UI | SwiftUI |
| センサー取得 | CoreMotion（`startDeviceMotionUpdates` / 50Hz） |
| Watch↔iPhone 通信 | WatchConnectivity（`transferUserInfo`） |
| グラフ描画 | Swift Charts |
| データ保存 | CSV（Documents ディレクトリ） |
| 将来実装予定 | CoreML / Create ML |

---

## データ形式

### meta.csv（記録サマリー）
```
timestamp,label,itch_level,sample_count
2026-05-22T10:56:01Z,scratch,5,491
2026-05-22T11:03:14Z,normal_walk,0,247
```

### motion/{timestamp}_{label}.csv（モーションデータ）
```
time,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z,label
1779447350.534337,0.358683,-0.054334,0.037199,0.432440,0.466815,1.937867,scratch
...
```
6軸センサーデータ（加速度3軸 + ジャイロ3軸）を50Hzで記録します。

---

## 開発ロードマップ

| フェーズ | 内容 | 状態 |
|---|---|---|
| Phase 1 | Watch でモーション記録 → iPhone に転送・CSV保存 | ✅ 完了 |
| Phase 2 | Create ML でバイナリ分類器（scratch / normal）を学習 | 🔄 データ収集中 |
| Phase 3 | CoreML モデルをWatch に組み込み、リアルタイム検知 | 📋 予定 |
| Phase 4 | 検知時にハプティクス + iPhone プッシュ通知で警告 | 📋 予定 |

---

## ビルド方法

**必要環境**
- Xcode 16以上
- iOS 17以上のiPhone
- watchOS 10以上のApple Watch

```bash
git clone https://github.com/rararakoppepan/ScratchLogger.git
cd ScratchLogger
open ScratchLogger.xcodeproj
```

Xcodeで Bundle ID を自分のものに変更してから実機にビルドしてください。

---

## ファイル構成

```
ScratchLogger/
├── ScratchLogger/                        # iPhone App
│   ├── PhoneContentView.swift            # メイン画面（リスト・グラフ・進捗）
│   ├── PhoneSessionManager.swift         # WatchConnectivity受信・CSV保存
│   └── ScratchLoggerApp.swift
│
├── ScratchLoggerWatch Watch App/         # Watch App
│   ├── WatchContentView.swift            # Watch UI（ボタン・スライダー・進捗）
│   ├── WatchLoggerVM.swift               # ViewModel（NormalActivity enum）
│   ├── WatchSessionManager.swift         # 送信・オフラインキュー
│   ├── MotionRecorder.swift              # CoreMotion 50Hz記録
│   └── ScratchLoggerWatchApp.swift
│
└── ScratchLogger.xcodeproj
```
