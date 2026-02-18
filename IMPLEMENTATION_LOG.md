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
- [x] Sprint 4.1 ボス3フェーズ
- [x] Sprint 4.2 バランス調整

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

### 2026-02-17（Sprint 4.2）

- Decision: クリア速度が速すぎる戦闘フロアに増援を1〜2体追加
- Rationale: 平均フロア時間35〜60秒に寄せるための即効性が高い調整
- Notes: combatフロアのみ、28秒以内に殲滅した場合に1回だけ増援

- Decision: ラン内/セッション内のKPIログを追加（平均フロア時間、到達率、撃破率）
- Rationale: Acceptance Criteriaの追跡を実機ログで回せるようにするため
- Notes: RUN終了時にdebug_logへ集計値を出力

- Decision: プレイヤーに `reset_for_new_run()` を追加し、再挑戦時にビルドを初期化
- Rationale: 報酬効果が次ランへ残留するとKPIが歪むため

### 2026-02-17（入力統合）

- Decision: `main.tscn` に `VirtualJoystick` を常設し、`stick_input.x` を `player.gd` の移動軸へ統合
- Rationale: TODOの「virtual_joystick とキーボード入力の統合」を解消するため
- Notes: キーボード軸と仮想スティック軸は絶対値が大きい方を採用

### 2026-02-17（未完項目の前進）

- Decision: 敵同士の衝突回避を `BaseEnemy` 共通の「ソフト分離」で実装
- Rationale: コリジョンマスク変更だけだと詰まりやすいため、追従AIを維持しつつ重なりだけを解消するため
- Notes: 近接時のみ横方向へ押し戻し、攻撃中は干渉しない設計

- Decision: 敵死亡時に描画ベースのワンショットFX（リング+スパーク）を生成
- Rationale: 追加アセット無しで視認性を即改善でき、敵撃破の手応えを強化できるため
- Notes: `res://scenes/effects/enemy_death_fx.gd` を新規追加し、通常敵/ボスで半径を分岐

- Decision: 報酬選択UIにタップボタンを追加し、`main.gd` の既存 `_select_reward()` に接続
- Rationale: キーボード限定操作を解消し、モバイル入力でも周回を完結できるようにするため
- Notes: 1/2/3キー操作は維持したまま、同一経路で処理

### 2026-02-18（仕上げ実装）

- Decision: 敵死亡FXに手続き生成SE（短い減衰ノイズ+トーン）を追加
- Rationale: 外部アセット無しで「撃破の手応え」を即時に強化するため
- Notes: `enemy_death_fx.gd` 内で `AudioStreamGenerator` を使ってワンショット再生

- Decision: ボスに床危険帯ギミック（safe_slide / erase_rain）を追加し、ガード不可ダメージを分離
- Rationale: BOSS_PATTERN.md の「安全地帯へ移動」の読み合いを成立させ、被弾理由を明確化するため
- Notes: `player.gd` に `take_hazard_damage()` を追加、ローリング無敵は有効・ガード軽減は無効

- Decision: KPIに連動したセッション難易度補正（HP/DMG/増援）を追加
- Rationale: 目標帯（35〜60秒 / 到達率 / 撃破率）へ連続ランで収束させるため
- Notes: RUN終了時に `main.gd` が次ラン向け係数を更新、debug_logへ反映値を出力

- Decision: 敵の吹っ飛びを「短いリコイル減衰」に変更し、プレイヤー/敵を小型・細身の棒人間へ刷新
- Rationale: 吹っ飛びの違和感を抑えつつ、視認性とスタイリッシュさを両立するため
- Notes: ノックバックはdeltaスケール加算へ変更、`player.tscn` / `base_enemy.tscn` のカプセルも縮小

### 2026-02-18（KPI自動計測基盤）

- Decision: `main.gd` に `--kpi_autorun=N` の自動計測モードを追加（自動操作・自動再挑戦・結果保存）
- Rationale: 手動20ランの工数を下げ、KPI調整ループを短縮するため
- Notes: `KPI_AUTORUN_LOG.md` へ集計を書き出す。オート計測時はヒットストップ/演出FXを軽量化

- Decision: プレイヤーにAI制御用API（`ai_attack/roll/guard/skill/estus`）を追加
- Rationale: Input擬似押下よりも再現性高く制御できるため
- Notes: 通常操作には影響なし

- Decision: ヒットストップ復帰を「直前のtime_scaleへ戻す」方式へ変更
- Rationale: 高速検証時に `Engine.time_scale` が1.0へ固定される問題を防ぐため
- Notes: `set_hitstop_enabled(false)` で計測モード中は無効化可能

### 2026-02-18（KPI実測と追加調整）

- Decision: `KPI_AUTORUN_LOG.md` に 20ラン計測（`--kpi_autorun=20 --kpi_timescale=6`）を実施
- Rationale: まず現状の到達/撃破の実測値を取り、調整方向を確定するため
- Notes: 1回目結果は `avg_floor_time 10.31s / reach 0% / clear 0%`。主因は1F〜5Fでの早期敗北

- Decision: オート計測用にプレイヤー補正・回復ロジック・行動AIを段階的に調整
- Rationale: `run_avg=0` の即死状態ではKPI比較が成立しないため
- Notes: 調整後はボス到達サンプルが発生（例: 6ランで到達16.67%）したが、撃破0%は継続

- Decision: ボスで発生した `Dictionary is in read-only state` を修正
- Rationale: `PHASE_PATTERNS` 参照中の辞書を `clear()` していたため
- Notes: `boss_eraser.gd` の `current_action.clear()` を `current_action = {}` へ置換

- Decision: ボス火力/HPを段階的に緩和（P1〜P3ダメージとHP 1250→1100）
- Rationale: 到達後の即敗北率を下げ、撃破率を0%から持ち上げるため
- Notes: 予兆時間は維持して理不尽感を増やさない方針

- Decision: `KPI_AUTORUN_RUN_TIMEOUT` を 50s → 120s に拡張し、ボス戦を計測範囲に含める
- Rationale: 平均フロア時間から逆算すると50sではボス到達前に打ち切られるため
- Notes: 到達サンプルは取得できたが、シード依存で結果の揺れが大きい

- Observation: KPIサンプルの代表値
- Notes: 20ラン（t=6）で `reach 0% / clear 0%`、別サンプル6〜8ランで `reach 12.5〜16.7% / clear 0%`、10ラン（t=10）で再び `reach 0% / clear 0%`
- Notes: オート操作ベンチは分散が大きく、現状は「ボス撃破率評価」指標として不安定

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

- TODO: ボス撃破率を 5〜15% へ引き上げる（現状サンプルは到達あり/撃破0%）
- TODO: KPI評価を「オート操作のみ」から「実プレイログ併用」へ移行し、分散の大きさを吸収する
- TODO: オート計測の floor_time が目標35〜60秒より短いため、計測時補正値を再設計
- TODO: 実機（通常起動）での長時間連続ランを再確認し、クラッシュ再発有無を最終判定
