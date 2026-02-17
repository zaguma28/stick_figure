# IMPLEMENTATION_LOG

## 目的

実装の意思決定・実行コマンド・検証結果を短く残す。

---

## ルール

- 破壊的操作は禁止
- マイルストーンごとにコミット
- 実行したコマンドや変更点、既知のバグを記録する

---

## 進捗

- [x] Sprint 1.1 Godotプロジェクト作成
- [x] Sprint 1.2 入力＆UI
- [x] Sprint 1.3 プレイヤー基礎
- [x] Sprint 2.1 ヒット判定
- [x] Sprint 2.2 敵AI 6種
- [x] Sprint 2.3 体幹
- [x] Sprint 3.1 フロア進行
- [x] Sprint 3.2 報酬3択
- [x] Sprint 3.3 詰み防止
- [ ] Sprint 4.1 ボス3フェーズ
- [ ] Sprint 4.2 バランス調整

---

## 決定ログ

### 2026-02-16（Sprint 1）

- UID削除、コンボリファクタ、キーマップ追加

### 2026-02-16（Sprint 2）

- Decision: 攻撃ヒット判定をArea2Dではなく距離ベースで実装
- Rationale: tscn構造をシンプルに保ち、コード側で制御する方が柔軟
- Notes: 攻撃範囲+角度で扇状判定、円斬りは全方位

- Decision: 敵をbase_enemy.tscn + set_script()で生成
- Rationale: 1つのtscnで6種をカバー、tscn管理コストを最小化

- Decision: ヒットストップをEngine.time_scaleで実装
- Rationale: グローバルな一時停止で全オブジェクトに影響、シンプル
- Notes: ignore_time_scale=trueのタイマーで0.06秒後に復帰

- Decision: パリィ成功時の体幹ダメージをtake_damage内で処理
- Rationale: source引数で攻撃元を追跡、パリィ成功時にsource.take_damage(0, 45, kb)を呼ぶ

### 2026-02-17（Sprint 3.1）

- Decision: main.gdをテスト部屋固定から10Fフロア進行へ移行
- Rationale: Sprint 3.1のDone条件「1周回せる（仮UIでOK）」を最短で満たすため
- Notes: 4F/9Fは事件フロアとして一時的に回復イベントを実装、10Fは仮ボスフロア（精鋭ラッシュ）

- Decision: 敵フロアスケーリングをBaseEnemy.apply_floor_scaling()で統一
- Rationale: SPEC.mdの係数（HP 1+0.08*(floor-1), DMG 1+0.06*(floor-1)）を敵種類に依存せず適用するため
- Notes: Summonerの召喚ミニオンにも同一スケールを継承

### 2026-02-17（Sprint 3.2 / 3.3）

- Decision: 報酬3択は `main.gd` 内で完結させ、フロア遷移フェーズに `reward_select` を追加
- Rationale: 既存のフロア進行ロジック（combat/event/clear）へ最小差分で組み込めるため
- Notes: 1/2/3キー選択、HUDに候補名+説明を表示

- Decision: タグ重み付けは「所持タグ数の最大値」で倍率を適用（0→x1.0、1→x1.3、2以上→x1.8）
- Rationale: 複数タグ報酬でも計算が単純で、ビルド方向への収束を作りやすい

- Decision: 3択の1枠を別系統にするため、主タグプール2枠 + 非主タグプール1枠を優先抽選
- Rationale: SPECの「1枠は別系統」を常に満たしつつ、乗り換え余地を残すため

- Decision: 9F天井は「9F時点で救済未所持なら、救済報酬を候補に強制混入」で実装
- Rationale: Done条件「9Fまでに救済が提示される」を満たす最短実装
- Notes: 救済キーは `strong_guard / bullet_clear / roll_stable / low_hp_damage`

### 2026-02-17（Sprint 4.1 着手）

- Decision: 10Fを `boss_proxy` から本ボス `boss_eraser.gd` へ置換
- Rationale: BOSS_PATTERN.mdの3フェーズ秒刻みをスクリプト内タイムラインで管理するため
- Notes: P1/P2/P3のループ、予兆表示、弾幕・突進・押しつぶし・大技（弾雨）を実装

---

## コリジョンレイヤー設計

| Layer | 用途           | 値  |
| ----- | -------------- | --- |
| 1     | 壁・地形       | 1   |
| 2     | プレイヤー     | 2   |
| 3     | 敵本体         | 4   |
| 4     | プレイヤー攻撃 | 8   |
| 5     | 敵弾           | 16  |

---

## 既知のバグ / TODO

- TODO: 敵同士の衝突回避（現在は重なる）
- TODO: 敵死亡時のSE/エフェクト
- TODO: 本ボスの実機検証と挙動微調整（フェーズ遷移/秒刻み誤差）
- TODO: virtual_joystickとキーボード入力の統合
- TODO: Godot実機検証（報酬選択UI、タグ重み、9F救済候補の提示）
