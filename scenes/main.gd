extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera2D = $Player/Camera2D

var enemy_scene: PackedScene = preload("res://scenes/enemies/base_enemy.tscn")
var charger_script: GDScript = preload("res://scenes/enemies/charger.gd")
var shooter_script: GDScript = preload("res://scenes/enemies/shooter.gd")
var spreader_script: GDScript = preload("res://scenes/enemies/spreader.gd")
var shield_script: GDScript = preload("res://scenes/enemies/shield_enemy.gd")
var bomber_script: GDScript = preload("res://scenes/enemies/bomber.gd")
var summoner_script: GDScript = preload("res://scenes/enemies/summoner.gd")

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.08, 0.12))
	player.add_to_group("player")
	hud.setup(player)
	player.position = Vector2(360, 640)
	queue_redraw()

	# テスト部屋: 敵を配置
	_spawn_test_room()

func _spawn_test_room() -> void:
	_spawn_enemy(shooter_script, Vector2(500, 400))
	_spawn_enemy(charger_script, Vector2(200, 300))
	_spawn_enemy(spreader_script, Vector2(550, 800))
	_spawn_enemy(shield_script, Vector2(150, 500))
	_spawn_enemy(bomber_script, Vector2(600, 600))
	_spawn_enemy(summoner_script, Vector2(300, 900))

func _spawn_enemy(script: GDScript, pos: Vector2) -> void:
	var enemy = enemy_scene.instantiate()
	enemy.set_script(script)
	enemy.position = pos
	add_child(enemy)

func _draw() -> void:
	var grid_size := 80
	var grid_range := 3000
	var grid_color := Color(0.2, 0.2, 0.3, 0.3)
	for x in range(-grid_range, grid_range + 1, grid_size):
		draw_line(Vector2(x, -grid_range), Vector2(x, grid_range), grid_color, 1.0)
	for y in range(-grid_range, grid_range + 1, grid_size):
		draw_line(Vector2(-grid_range, y), Vector2(grid_range, y), grid_color, 1.0)
	draw_circle(Vector2.ZERO, 6, Color(1.0, 0.3, 0.3, 0.6))
	draw_circle(Vector2(360, 640), 6, Color(0.3, 0.5, 1.0, 0.6))
