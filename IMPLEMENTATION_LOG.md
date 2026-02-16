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
- [ ] Sprint 2.1 ヒット判定
- [ ] Sprint 2.2 敵AI 6種
- [ ] Sprint 2.3 体幹
- [ ] Sprint 3.1 フロア進行
- [ ] Sprint 3.2 報酬3択
- [ ] Sprint 3.3 詰み防止
- [ ] Sprint 4.1 ボス3フェーズ
- [ ] Sprint 4.2 バランス調整

---

## 決定ログ

### 2026-02-16（Sprint 1完了）

- Decision: tscnのハードコードuid（uid://main_scene等）を削除
- Rationale: Godot 4.xが自動生成するUID形式に準拠しない値だったため、エディタ読み込みエラー回避
- Notes: Godotが初回ロード時にuid行を自動付与する

- Decision: player.gdの\_try_attack()コンボロジックをリファクタ
- Rationale: stage変数が複数回上書きされる冗長なコードを、\_last_attackベースのシンプルな分岐に整理
- Notes: コンボ窓0.3秒、3段目で窓なし（リセット）

- Decision: HUDにキーマップ表示を追加
- Rationale: 初見で操作方法がわからないため画面下部にガイド表示

---

## 実行コマンドログ

### 2026-02-16

- Command: git init
- Result: リポジトリ初期化完了

- Command: git add -A && git commit -m "Sprint 1.1-1.3: player, UI, input system"
- Result: （実行待ち）

---

## 既知のバグ / TODO

- TODO: virtual_joystickはモバイル向けだがPC操作（WASD）との統合が未完了。現在はキーボード入力のみ有効
- TODO: パリィ成功時の外部連携（敵体幹ダメージ通知）はSprint 2で実装
- TODO: HP/スタミナバーの色分け（低HPで赤等）は演出フェーズで追加
