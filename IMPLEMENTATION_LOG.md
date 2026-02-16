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
- [ ] Sprint 3.1 フロア進行
- [ ] Sprint 3.2 報酬3択
- [ ] Sprint 3.3 詰み防止
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
- TODO: フロアスケーリング（HP/ダメ係数）未実装
- TODO: virtual_joystickとキーボード入力の統合
