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

### 2026-02-18（継続改善）

- Decision: 実プレイログを `RUN_PLAY_LOG.md` へ自動追記（AUTO/MANUAL共通）
- Rationale: KPI_AUTORUNだけでなく、手動プレイ結果も同じ粒度で比較可能にするため
- Notes: 1ランごとに終了理由/到達フロア/実時間/フロア時間内訳を保存

- Decision: HUDにセッション統計表示（runs / reach / clear / boss_fail_streak）を追加
- Rationale: ログを開かなくても調整ループ中に現状の到達傾向を即確認するため
- Notes: `hud.gd` に `set_session_metrics()` を追加し、`main.gd` から更新

- Decision: 通常プレイ向けに「ボス連敗時の段階的アシスト」を追加
- Rationale: 到達後の連敗が続く場合に撃破率0%から脱出しやすくするため
- Notes: ボス開始時に連敗数に応じて回復/防御/回避/火力を小幅補正（最大Lv3）

### 2026-02-18（継続改善2）

- Decision: ボスに `get_autoplay_hint()` を追加し、安全地帯中心座標をオート操作へ公開
- Rationale: `safe_slide / erase_rain` 中に安全地帯へ寄れず、到達後の生存率が下がっていたため
- Notes: `main.gd` のオート操作は「移動目標」と「攻撃距離判定」を分離して処理

- Decision: ボス基礎性能とP2/P3パターンを軽量化し、ボスにもセッション係数を反映
- Rationale: 到達サンプルは出るが撃破0%の状態を改善するため
- Notes: `boss_eraser.gd` の基礎HP/接触ダメージを引き下げ、`main.gd` 側でボスは floor係数ではなく session係数のみ適用

- Decision: 敵被弾ノックバックを「短いリコイル中心」に再調整し、プレイヤー/敵の体格をさらにスリム化
- Rationale: 「吹っ飛びが不自然」「棒人間の図体が大きい」という違和感に直接対応するため
- Notes: `player.tscn` / `base_enemy.tscn` のカプセル縮小、`player.gd` / `base_enemy.gd` の描画スケールを縮小

### 2026-02-18（視認性とテンポの加速）

- Decision: 戦闘エフェクトを視認性優先に再整理（斬撃は残しつつ薄く、重なりFXは抑制）
- Rationale: 敵がエフェクトで隠れる問題を解消しつつ、攻撃の手応えは維持するため
- Notes: `hit_spark_fx.gd` の粒子/前面表示を抑制、`player.gd` の斬撃トレイルはトグル化＋低アルファ

- Decision: 事件フロアを「休息」と「深淵契約」の2系統へ拡張
- Rationale: 周回中の意思決定を増やし、毎回同じ回復イベントになる単調さを減らすため
- Notes: 4F系は回復＋エスト補充、9FはHPを払う火力契約 or 低HP時の防御契約

- Decision: 通常戦闘フロアに長期戦圧縮（戦場崩壊パルス）を追加
- Rationale: 進行テンポが落ちるケースを自動で畳み、周回速度を底上げするため
- Notes: 一定時間経過後、通常戦闘フロアの敵へ周期ダメージ＋体幹削りを適用

### 2026-02-18（連続実装: バリエーション追加）

- Decision: 新敵 `hunter_drone` を追加（距離管理 + 高速2連射）
- Rationale: 既存の近接/拡散/召喚とは異なる「中遠距離プレッシャー」を作るため
- Notes: `hunter_drone.gd` を追加し、複数フロアの編成へ組み込み

- Decision: 戦闘フロアにモディファイア（猛攻/装甲化/暴発）を導入
- Rationale: 同じ敵編成でも毎ランの立ち回りを変え、進行の体感速度を上げるため
- Notes: `main.gd` のフロア開始時に抽選し、HUD/開始メッセージへ表示

### 2026-02-18（連続実装: 予兆とボス新行動）

- Decision: `hunter_drone` に射線予兆（ライン+着弾マーカー）を追加
- Rationale: 中遠距離敵の攻撃方向を事前に読めるようにして、回避判断の質を上げるため
- Notes: TELEGRAPH中のみ描画し、実射方向と同期

- Decision: ボスに新行動 `sniper_lance`（ロック予兆付き狙撃）を追加
- Rationale: パターンの単調さを減らし、「構えを見て避ける」行動密度を増やすため
- Notes: P2に編入、予兆ロック線→高速3連射+残光ラインの順で実行

### 2026-02-18（連続実装: 戦闘テンポ圧縮）

- Decision: 通常戦闘フロアの長期戦圧縮を3段階化（Lv1/Lv2/Lv3）し、時間経過でパルス間隔と威力を強化
- Rationale: フロア停滞時のテンポ低下を抑え、周回速度の下振れを減らすため
- Notes: `main.gd` の `COMBAT_STALL_*` を拡張し、38s/52s/66sで段階上昇

- Decision: 通常戦闘フロアに崩壊終端（92s）を追加し、敵を強制掃討
- Rationale: 稀なアンチスタック失敗や敵行動噛み合いで進行が止まるケースを確実に解消するため
- Notes: bossフロアは対象外、combatフロアのみ適用

### 2026-02-18（連続実装: 予兆視認性UI）

- Decision: HUDに `ThreatLabel` を追加し、TELEGRAPH中の脅威をリアルタイム表示
- Rationale: Hunter/Bossの予兆を見落としにくくし、回避判断を早めるため
- Notes: `main.gd` で敵状態を集計し、最危険ターゲットのみ `DANGER Lv1-3` 表示

- Decision: 脅威ラベルに方向マーカー（`<<` / `>>`）と近距離タグ（`[NEAR]`）を追加
- Rationale: 画面内でどちらを優先して避けるべきかを即時判断しやすくするため
- Notes: 戦闘フェーズ以外では自動で `Threat: -` に戻す

### 2026-02-18（連続実装: 背景レイヤー刷新）

- Decision: 新規 `world_backdrop.gd` を追加し、背景描画を `main.gd` から分離
- Rationale: 進行と演出を分離して、背景の拡張をしやすくするため
- Notes: 空/遠景遺構/霧/地面/足場の5層を描画、カメラ追従で疑似パララックス

- Decision: floor種別（combat/event/boss）と mutator（猛攻/装甲化/暴発）で背景演出を可変化
- Rationale: 周回中の見た目変化を増やし、同じフロア構成でも体感の単調さを減らすため
- Notes: `main.gd` の `_start_floor` から `set_floor_theme()` を呼び、背景テーマを都度更新

### 2026-02-18（連続実装: 背景強化2）

- Decision: 背景天候を追加（雨/灰）し、フロア種別・mutatorに応じて強度を切替
- Rationale: 戦闘の空気感と周回時の視覚差分を増やすため
- Notes: `world_backdrop.gd` の `weather_type` / `weather_intensity` で制御

- Decision: ボス専用の背景警告演出（赤脈動オーラ + 走査ライン）を追加
- Rationale: ボス戦突入時の緊張感とフェーズ全体の視認インパクトを上げるため
- Notes: bossフロア時のみ `draw` で有効化

- Decision: 当たり判定なしの装飾オブジェクト（崩れ柱・警告看板）を配置
- Rationale: プレイ感に影響を与えず、ステージ情報量を増やすため
- Notes: 描画のみで実装し、衝突判定は追加しない

- Decision: 背景装飾データ配列を `Array[Dictionary]` 明示型へ修正
- Rationale: `Variant` 推論警告を警告エラー設定でも発生させないため
- Notes: `world_backdrop.gd` の `_draw_props()` を型安全な取得へ変更

### 2026-02-18（連続実装: ボス詰まり緩和）

- Decision: `Boss Assist` をプレイヤー側バフだけでなく、ボス側にも直接反映
- Rationale: 連敗時に「被弾し続けて押し切られる」状態を減らし、突破率を上げるため
- Notes: `boss_eraser.gd` に `apply_boss_assist()` を追加し、火力/予兆/弾幕密度/ハザードtickを段階緩和

- Decision: ボス戦限定 `Second Wind`（ASSIST Lv2以上で1回復帰）を追加
- Rationale: 終盤のワンミス全損で進行が止まるケースを減らすため
- Notes: `main.gd` の `_try_trigger_boss_second_wind()` でHP/スタミナ/短時間無敵を再付与

### 2026-02-18（連続実装: 斬撃リワーク）

- Decision: プレイヤー通常攻撃の斬撃描画を線弧中心から「面を持つ三日月スラッシュ」へ変更
- Rationale: 斬撃の存在感を強め、手応えを視覚的に分かりやすくするため
- Notes: `player.gd` に `_draw_slash_crescent()` を追加し、通常/重撃で色味と厚みを分岐

- Decision: スイングFXの表示時間と多層トレイルを増強
- Rationale: 斬り終わりの余韻を作り、攻撃モーションをスタイリッシュに見せるため
- Notes: `swing_fx_duration` を延長し、芯線/残像/火花ラインを追加

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

- TODO: ボス撃破率を 5〜15% へ引き上げる（現状は到達サンプル増加したが撃破0%）
- TODO: `RUN_PLAY_LOG.md` を使って実プレイ20ランを収集し、オート計測分散を吸収する
- TODO: オート計測の floor_time が目標35〜60秒より短いため、計測時補正値を再設計
- TODO: オート計測で稀に中盤フロア timeout が発生するため、フロア停滞時のアンチスタック処理を追加
- TODO: KPI起動引数は `-- --kpi_autorun=N --kpi_timescale=X` 形式で実行する運用を README/TODO に反映
- TODO: 実機（通常起動）での長時間連続ランを再確認し、クラッシュ再発有無を最終判定
