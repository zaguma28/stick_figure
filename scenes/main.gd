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
