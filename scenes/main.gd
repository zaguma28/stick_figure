extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera2D = $Player/Camera2D

func _ready() -> void:
	# 背景色を暗めに
	RenderingServer.set_default_clear_color(Color(0.08, 0.08, 0.12))

	# プレイヤーをグループに追加
	player.add_to_group("player")

	# HUDとプレイヤーを接続
	hud.setup(player)

	# デバッグ: 初期位置を画面中央に
	player.position = Vector2(360, 640)

	# グリッド描画
	queue_redraw()

func _draw() -> void:
	# 移動が視認できるよう背景にグリッドを描画
	var grid_size := 80
	var grid_range := 3000
	var grid_color := Color(0.2, 0.2, 0.3, 0.3)

	for x in range(-grid_range, grid_range + 1, grid_size):
		draw_line(Vector2(x, -grid_range), Vector2(x, grid_range), grid_color, 1.0)
	for y in range(-grid_range, grid_range + 1, grid_size):
		draw_line(Vector2(-grid_range, y), Vector2(grid_range, y), grid_color, 1.0)

	# 原点マーカー（赤い点）
	draw_circle(Vector2.ZERO, 6, Color(1.0, 0.3, 0.3, 0.6))

	# スポーン位置マーカー（青い点）
	draw_circle(Vector2(360, 640), 6, Color(0.3, 0.5, 1.0, 0.6))
