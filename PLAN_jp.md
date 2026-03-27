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
      FAULT_MINOR,  -- 軽微な異常（警告のみ、走行継続）
      FAULT_MAJOR,  -- 重大な異常（制御縮退）
      EMERGENCY,    -- 緊急ブレーキ実行中
      SAFE_STOP     -- 安全停止完了（終端状態）
   );

   -- フォールト重大度
   type Fault_Level is (NONE, WARNING, CRITICAL, FATAL);

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
| センサー値範囲外 | WARNING | ログ出力のみ |
| センサータイムアウト | CRITICAL | 状態をFAULT_MAJORへ |
| 前方距離 < MIN_SAFE_DISTANCE | CRITICAL | 状態をEMERGENCYへ |
| 速度 > MAX_SPEED | WARNING | スロットルを0に |
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
| FAULT_MINOR | 通常制御継続 + 警告表示 |
| FAULT_MAJOR | スロットル縮退、ブレーキ準備 |
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
         │    ACTIVE      │   │   FAULT_MAJOR    │
         └──┬───────┬─────┘   └────────┬─────────┘
     警告発生│       │重大異常          │
            ▼       ▼                  │
    ┌───────────┐  ┌──────────┐        │
    │FAULT_MINOR│  │EMERGENCY │◄───────┘ 前方衝突危険
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
