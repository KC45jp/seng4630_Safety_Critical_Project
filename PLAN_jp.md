# ADAS プロジェクト 実装計画

**SENG 4630 — Safety Critical Software Systems**
締切: April 14, 2026

---

## 1. プロジェクト概要

車両向け運転支援システム（ADAS）をAdaで実装する。
センサーとアクチュエーターはすべてシミュレーション。

**要件まとめ（仕様書より）:**

| 項目 | 内容 |
|---|---|
| 言語 | Ada 2012 |
| センサー（模擬） | 速度・前方距離・車線位置 |
| 制御（模擬） | アクセル・ブレーキ・ステアリング |
| ドライバー操作 | engage / disengage / manual override |
| 必須Adaコンセプト | Tasks/rendezvous, Protected objects, Contracts, 列挙型 |
| フォールト分類 | severity levelで分類（後述） |

---

## 2. パッケージ構成

```
autopilot_system/src/
├── autopilot_system.adb                      ← メインエントリー（全タスクを起動）
├── autopilot_system-types.ads                ← 共通型・定数（実装なし）
├── autopilot_system-vehicle_state.ads/.adb   ← Protected object（共有状態ハブ）
├── autopilot_system-sensors.ads/.adb         ← センサータスク
├── autopilot_system-fault_detection.ads/.adb ← フォールト検知タスク
├── autopilot_system-control.ads/.adb         ← 制御タスク
└── autopilot_system-driver_input.ads/.adb    ← ドライバー入力タスク
```

---

## 3. 各パッケージの詳細

### 3.1 `Autopilot_System.Types`（型定義のみ、`.ads`）

すべての共通型・定数をここで定義する。他のパッケージはこれをwithする。

```ada
package Autopilot_System.Types is

   -- システム状態（ステートマシンのノード）
   type System_State is (
      STANDBY,      -- 待機中（起動前）
      ENGAGING,     -- オートパイロット起動確認中
      ACTIVE,       -- オートパイロット稼働中
      WARNING_ACTIVE,  -- 軽微な異常（警告のみ、走行継続）
      SENSOR_FAULT,  -- 重大な異常（制御縮退）
      EMERGENCY,    -- 緊急ブレーキ実行中
      SAFE_STOP     -- 安全停止完了（終端状態）
   );

   -- フォールト重大度
   type Fault_Level is (NONE, CRITICAL, FATAL);

   -- センサーデータ
   type Sensor_Data is record
      Speed          : Float;   -- km/h
      Front_Distance : Float;   -- m（前方障害物距離）
      Lane_Offset    : Float;   -- m（車線中央からのズレ）
      Valid          : Boolean; -- センサーが有効かどうか
   end record;

   -- アクチュエーター出力
   type Actuator_Output is record
      Throttle : Float;   -- 0.0〜1.0
      Brake    : Float;   -- 0.0〜1.0
      Steering : Float;   -- -1.0〜1.0（左右）
   end record;

   -- ドライバーコマンド
   type Driver_Command is (ENGAGE, DISENGAGE, OVERRIDE);

   -- 定数
   MAX_SPEED         : constant Float := 130.0;  -- km/h
   MIN_SAFE_DISTANCE : constant Float := 10.0;   -- m
   MAX_LANE_OFFSET   : constant Float := 0.5;    -- m
   SENSOR_TIMEOUT    : constant Duration := 0.5; -- 秒

end Autopilot_System.Types;
```

---

### 3.2 `Autopilot_System.Vehicle_State`（Protected object）

複数のタスクが同時に読み書きする共有データをここで管理する。
Adaの `protected` 構文を使い、レースコンディションを防ぐ。

```
【アクセスパターン】
Sensor_Task        → Write sensor data
Fault_Detection    → Read sensor data, Write state
Driver_Input_Task  → Write state (override/engage)
Control_Task       → Read sensor data + state
```

```ada
protected type Vehicle_State_Object is
   procedure Update_Sensors (Data : in Sensor_Data);
   procedure Set_State (S : in System_State);
   procedure Set_Fault (F : in Fault_Level);
   function  Get_Sensors return Sensor_Data;
   function  Get_State   return System_State;
   function  Get_Fault   return Fault_Level;
private
   Sensors : Sensor_Data := (...);
   State   : System_State := STANDBY;
   Fault   : Fault_Level  := NONE;
end Vehicle_State_Object;
```

---

### 3.3 `Autopilot_System.Sensors`（Task）

50ms周期でセンサー値をシミュレートし、Vehicle_Stateを更新する。

- センサー値は乱数または事前定義シナリオで生成
- タイムアウト検出のためタイムスタンプも記録
- センサー値が範囲外の場合は`Valid := False`をセット

```ada
task type Sensor_Task is
   entry Start;
   entry Stop;
end Sensor_Task;
```

---

### 3.4 `Autopilot_System.Fault_Detection`（Task）

100ms周期でVehicle_Stateを監視し、異常を検出・分類する。

| 条件 | Fault Level | アクション |
|---|---|---|
| センサー値範囲外 | CRITICAL | 状態をSENSOR_FAULTへ |
| センサータイムアウト | CRITICAL | 状態をSENSOR_FAULTへ |
| 前方距離 < MIN_SAFE_DISTANCE | CRITICAL | 状態をEMERGENCYへ |
| 速度 > MAX_SPEED | NONE | 状態をWARNING_ACTIVEへ |
| 複数センサー同時故障 | FATAL | 状態をSAFE_STOPへ |

```ada
task type Fault_Detection_Task is
   entry Start;
end Fault_Detection_Task;
```

---

### 3.5 `Autopilot_System.Control`（Task）

100ms周期でアクチュエーター出力を計算し、シミュレート出力する。

| 状態 | 制御内容 |
|---|---|
| STANDBY | throttle=0, brake=0, steering=0（何もしない） |
| ACTIVE | 速度制御 + 車線維持（簡易PID） |
| WARNING_ACTIVE | 通常制御継続 + 警告表示 |
| SENSOR_FAULT | スロットル縮退、ブレーキ準備 |
| EMERGENCY | throttle=0, brake=1.0（フルブレーキ） |
| SAFE_STOP | brake=1.0 → 速度0で停止維持 |

```ada
task type Control_Task is
   entry Start;
end Control_Task;
```

---

### 3.6 `Autopilot_System.Driver_Input`（Task + rendezvous）

ドライバーからのコマンドをrendezvousで受け付け、Vehicle_Stateに反映する。

- `ENGAGE`：STANDBYからENGAGINGへ（安全確認後ACTIVEへ）
- `DISENGAGE`：ACTIVEからSTANDBYへ
- `OVERRIDE`：どの状態からでも即STANDBYへ（安全最優先）

```ada
task type Driver_Input_Task is
   entry Send_Command (Cmd : in Driver_Command);
   entry Start;
end Driver_Input_Task;
```

---

## 4. ステートマシン（遷移図）

```
                  ┌─────────────────┐
                  │     STANDBY     │◄─── OVERRIDE / DISENGAGE
                  └────────┬────────┘
                           │ ENGAGE
                           ▼
                  ┌─────────────────┐
                  │    ENGAGING     │  （センサー健全性チェック）
                  └────────┬────────┘
             センサーOK ───┘  └─── センサーNG
                  ▼                    ▼
         ┌────────────────┐   ┌──────────────────┐
         │    ACTIVE      │   │   SENSOR_FAULT    │
         └──┬───────┬─────┘   └────────┬─────────┘
     警告発生│       │重大異常          │
            ▼       ▼                  │
    ┌───────────┐  ┌──────────┐        │
    │WARNING_ACTIVE│  │EMERGENCY │◄───────┘ 前方衝突危険
    └───────────┘  └────┬─────┘
                        │ 停止完了
                        ▼
                  ┌─────────────┐
                  │  SAFE_STOP  │  （終端状態）
                  └─────────────┘
```

---

## 5. Adaコンセプトの使い方まとめ

| コンセプト | 使用箇所 |
|---|---|
| **Tasks** | Sensors, Fault_Detection, Control, Driver_Input の各タスク |
| **Rendezvous** | `Driver_Input_Task.Send_Command` エントリー |
| **Protected objects** | `Vehicle_State_Object`（センサーデータ・状態の共有） |
| **Contracts（Pre/Post）** | `Set_State`の遷移チェック、センサー値の範囲検証 |
| **Enumerated types** | `System_State`, `Fault_Level`, `Driver_Command` |
| **Exception handling** | センサー読み取り失敗、不正な状態遷移 |

---

## 6. 外部ライブラリ

| ライブラリ | 推奨度 | 理由 |
|---|---|---|
| **AUnit** (`alr with aunit`) | ★★★ 強く推奨 | フォールト検知ロジックの単体テスト。安全重視システムでテストなしは危険 |
| その他 | 不要 | `Ada.Real_Time`, `Ada.Text_IO`, `Ada.Numerics` で十分 |

---

## 7. 実装ステップ（推奨順序）

1. `Types` パッケージ（型定義）
2. `Vehicle_State` パッケージ（protected object）
3. `Sensors` タスク（値のシミュレート）
4. `Fault_Detection` タスク（異常検知ロジック）
5. `Control` タスク（制御出力）
6. `Driver_Input` タスク（rendezvous）
7. `autopilot_system.adb` を修正してすべてを起動
8. （任意）AUnitテスト追加

---

## 8. ⚠️ 注意点

- 仕様書には **Ada 2012** と明記されている（Ada 2022は上位互換なので使用可だが、提出前に教員確認推奨）
- Execution complexityは最低にすること（仕様書 Design要件 #2）
- フォールト分類はseverity levelで行うこと（仕様書 Design要件 #3）
- グループプロジェクト（チームワーク戦略も評価対象）


diff --git a//workspaces/seng4630_Safety_Critical_Project/.doc/adas_csv_scenario_replay_plan_ja.md b//workspaces/seng4630_Safety_Critical_Project/.doc/adas_csv_scenario_replay_plan_ja.md
new file mode 100644
--- /dev/null
+++ b//workspaces/seng4630_Safety_Critical_Project/.doc/adas_csv_scenario_replay_plan_ja.md
@@ -0,0 +1,99 @@
+# ADAS CSVシナリオ実行・検証計画
+
+## 目的
+- Ada tasking / rendezvous / protected object / contracts を維持したまま、CSV ベースの決定的なシナリオ replay と検証を追加する
+- Python は補助ツールに限定し、本体の state machine と safety 判断は Ada に残す
+- ランダムセンサ生成を置き換え、再現可能なテストとデモを可能にする
+
+## 要件適合の前提
+- `doc/SENG_4630_Overview_2026.md` の以下を満たす
+- fail-safe, deterministic, robust against sensor failures
+- Ada tasking, contracts, exception handling
+- Tasks and rendezvous, protected objects, enumerated types for states
+- 実装本体は Ada 2012 とする
+- CSV/CI 用の実行でも task 構成は崩さない
+- Python は testing harness / scenario generator としてのみ使う
+
+## ディレクトリ方針
+- `SensorData/`
+  - 統合シナリオ CSV の生成を担当する
+  - 正式な出力先は `SensorData/scenarios/`
+- `ScenarioTest/`
+  - シナリオ一覧
+  - trace 検証
+  - `alr run` 起動ラッパー
+  を担当する
+
+## 変更方針
+- `Autopilot_System.Sensors` は乱数生成をやめ、統合 CSV を 50 ms 周期で 1 行ずつ replay する
+- 既存の `Apply_Emergency_Profile` は削除する
+- `Main` は固定 9.5 秒実行をやめ、`--scenario` と `--trace-out` を受けて CSV EOF まで実行する
+- 旧 `SensorData/Senario*` 形式は移行対象とし、新規正式入力は統合 CSV のみとする
+- Python wrapper は scenario 生成、`alr run` 起動、trace 検証だけを担当する
+
+## シナリオ CSV 仕様
+- 正式ヘッダ:
+  `step,speed_mode,speed_value,distance_mode,distance_value,lane_mode,lane_value,driver_command,expected_state,expected_fault`
+- `speed_mode` / `distance_mode` / `lane_mode`:
+  `VALID | INVALID | MISSING`
+- 意味:
+  - `VALID`: 値を反映し valid=true
+  - `INVALID`: サンプル到着扱いで timestamp 更新、valid=false
+  - `MISSING`: 未到着扱いで値も timestamp も更新しない
+- `driver_command`:
+  `NONE | ENGAGE | DISENGAGE | OVERRIDE`
+- `expected_state`:
+  `System_State` の列挙子名をそのまま使う
+- `expected_fault`:
+  `Fault_Level` の列挙子名をそのまま使う
+- `expected_state` / `expected_fault` は毎行必須とする
+
+## 主要な型 / API 変更
+- `Vehicle_State`
+  - センサ別更新 API を追加する
+  - `Update_Speed`
+  - `Update_Distance`
+  - `Update_Lane`
+  - timeout 判定用 timestamp は「最後に valid だった時刻」ではなく「最後にサンプルが到着した時刻」とする
+- `Driver_Input`
+  - package-level の `Apply_Command (Cmd : Driver_Command)` を追加する
+  - `Driver_Input_Task.Send_Command` はこの procedure を呼ぶ
+  - scenario 行の `driver_command` も同じ procedure を使う
+- `Sensors`
+  - CSV parser / row decoder / replay 処理を package body 内の helper に分割する
+- `Main`
+  - `--scenario` と `--trace-out` を受ける
+  - `Sensor_Task` EOF 後に残り task を orderly shutdown する
+
+## Trace 出力仕様
+- Ada 側で trace CSV を出力する
+- 正式ヘッダ:
+  `step,observed_state,observed_fault,observed_speed,observed_distance,observed_lane,observed_speed_valid,observed_distance_valid,observed_lane_valid`
+
+## Python wrapper の責務
+- 決定的な scenario CSV を生成する
+- `alr run -- --scenario <path> --trace-out <path>` を実行する
+- trace CSV を読み、各行の `expected_state` / `expected_fault` がその step から 2 sensor ticks 以内に観測されたかを判定する
+- Ada に 1 行ずつライブ送信して state machine を外から駆動しない
+
+## テスト観点
+- parser が bad header / bad enum / bad numeric / missing required field を行番号つきで拒否すること
+- `VALID` / `INVALID` / `MISSING` が valid flag / timestamp / timeout に正しく影響すること
+- `ENGAGE` / `DISENGAGE` / `OVERRIDE` が scenario 行から適用されること
+- `expected_state` / `expected_fault` が 2 sensor ticks の window で検証されること
+- 少なくとも以下の scenario を用意すること
+- nominal engage/cruise
+- overspeed warning
+- lane deviation warning
+- emergency braking
+- invalid sensor on engage
+- single-sensor invalid
+- single-sensor timeout
+- multiple-sensor failure
+- recovery from minor fault
+- driver override
+
+## 補足
+- レーン値は contract を満たす範囲に正規化する
+- 速度・距離・レーンの値域は fault 判定しきい値と整合するよう Python 側で再設計する
+- シナリオ長は固定 100 行や 200 行ではなく CSV EOF を正式終了条件にする
