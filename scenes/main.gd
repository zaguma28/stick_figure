extends Node2D

@onready var player = $Player
@onready var hud = $HUD
@onready var camera: Camera2D = $Player/Camera2D

var enemy_scene: PackedScene = preload("res://scenes/enemies/base_enemy.tscn")
var charger_script: GDScript = preload("res://scenes/enemies/charger.gd")
var shooter_script: GDScript = preload("res://scenes/enemies/shooter.gd")
var spreader_script: GDScript = preload("res://scenes/enemies/spreader.gd")
var shield_script: GDScript = preload("res://scenes/enemies/shield_enemy.gd")
var bomber_script: GDScript = preload("res://scenes/enemies/bomber.gd")
var summoner_script: GDScript = preload("res://scenes/enemies/summoner.gd")

const TOTAL_FLOORS := 10
const FLOOR_CLEAR_DELAY := 1.2
const EVENT_FLOOR_DURATION := 2.2
const LEVEL_LEFT := -220.0
const LEVEL_RIGHT := 3600.0
const LEVEL_TOP := 60.0
const LEVEL_BOTTOM := 760.0
const GROUND_Y := 620.0
const PLAYER_START := Vector2(180, 500)
const ENEMY_SPAWN_START_X := 860.0
const ENEMY_SPAWN_END_X := 2100.0
const ENEMY_SPAWN_Y := 470.0
const SPAWN_JITTER_X := 120.0
const SPAWN_JITTER_Y := 18.0

var floor_definitions: Array[Dictionary] = [
	{
		"type": "combat",
		"name": "Shooter x2 / Charger x1",
		"enemies": ["shooter", "shooter", "charger"]
	},
	{
		"type": "combat",
		"name": "Spreader x1 / Shooter x2",
		"enemies": ["spreader", "shooter", "shooter"]
	},
	{
		"type": "combat",
		"name": "Shield x1 / Shooter x2",
		"enemies": ["shield", "shooter", "shooter"]
	},
	{
		"type": "event",
		"name": "事件: 休息の間"
	},
	{
		"type": "combat",
		"name": "Summoner x1 / Charger x2",
		"enemies": ["summoner", "charger", "charger"]
	},
	{
		"type": "combat",
		"name": "Spreader x2 / Bomber x1",
		"enemies": ["spreader", "spreader", "bomber"]
	},
	{
		"type": "combat",
		"name": "Shield x1 / Summoner x1 / Shooter x2",
		"enemies": ["shield", "summoner", "shooter", "shooter"]
	},
	{
		"type": "combat",
		"name": "Bomber x2 / Spreader x1",
		"enemies": ["bomber", "bomber", "spreader"]
	},
	{
		"type": "event",
		"name": "事件: 深淵の契約"
	},
	{
		"type": "boss_proxy",
		"name": "BOSS FLOOR (仮): 精鋭ラッシュ",
		"enemies": ["shield", "summoner", "spreader", "charger", "bomber"]
	}
]

var current_floor: int = 1
var floor_phase: String = "idle"
var floor_timer: float = 0.0
var run_finished: bool = false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.08, 0.12))
	player.add_to_group("player")
	hud.setup(player)
	_build_stage()
	_setup_camera()
	player.position = PLAYER_START
	player.velocity = Vector2.ZERO
	queue_redraw()
	_start_run()

func _process(delta: float) -> void:
	if run_finished:
		return
	match floor_phase:
		"combat":
			if _is_combat_cleared():
				_on_floor_cleared()
		"event_wait", "clear_wait":
			floor_timer -= delta
			if floor_timer <= 0:
				_go_to_next_floor()

func _start_run() -> void:
	run_finished = false
	current_floor = 1
	floor_phase = "idle"
	_start_floor(current_floor)

func _start_floor(floor_number: int) -> void:
	_clear_current_floor_nodes()
	player.position = PLAYER_START
	player.velocity = Vector2.ZERO
	var floor_data := floor_definitions[floor_number - 1]
	var floor_type: String = floor_data.get("type", "combat")
	var floor_name: String = floor_data.get("name", "")
	_update_hud_floor(floor_type, floor_name)
	match floor_type:
		"combat", "boss_proxy":
			_spawn_floor_enemies(floor_data.get("enemies", []))
			floor_phase = "combat"
			if floor_type == "boss_proxy":
				_set_run_message("10F: 仮ボスフロア開始（本ボスはSprint 4で実装）")
			else:
				_set_run_message("F%d 開始" % current_floor)
		"event":
			_apply_event_floor_effect()
			floor_phase = "event_wait"
			floor_timer = EVENT_FLOOR_DURATION
			_set_run_message("F%d 事件フロア: 力を整える..." % current_floor)
		_:
			push_warning("Unknown floor type: %s" % floor_type)
			floor_phase = "event_wait"
			floor_timer = 0.5

func _spawn_floor_enemies(enemy_keys: Array) -> void:
	var count := enemy_keys.size()
	if count <= 0:
		return
	var span_start := ENEMY_SPAWN_START_X + float(current_floor - 1) * 70.0
	var span_end := minf(ENEMY_SPAWN_END_X + float(current_floor - 1) * 90.0, LEVEL_RIGHT - 240.0)
	if span_end <= span_start:
		span_end = span_start + 220.0
	for i in range(count):
		var t := float(i + 1) / float(count + 1)
		var x := lerpf(span_start, span_end, t) + randf_range(-SPAWN_JITTER_X, SPAWN_JITTER_X)
		var y := ENEMY_SPAWN_Y + randf_range(-SPAWN_JITTER_Y, SPAWN_JITTER_Y)
		var key: String = str(enemy_keys[i])
		_spawn_enemy_by_key(key, Vector2(x, y))

func _spawn_enemy_by_key(enemy_key: String, pos: Vector2) -> void:
	var script := _get_enemy_script(enemy_key)
	if script == null:
		push_warning("Invalid enemy key: %s" % enemy_key)
		return
	var enemy := enemy_scene.instantiate()
	enemy.set_script(script)
	enemy.position = pos
	add_child(enemy)
	_apply_floor_scaling(enemy)

func _get_enemy_script(enemy_key: String) -> GDScript:
	match enemy_key:
		"charger":
			return charger_script
		"shooter":
			return shooter_script
		"spreader":
			return spreader_script
		"shield":
			return shield_script
		"bomber":
			return bomber_script
		"summoner":
			return summoner_script
		_:
			return null

func _apply_floor_scaling(node: Node) -> void:
	var enemy := node as BaseEnemy
	if not enemy:
		return
	var hp_scale := 1.0 + 0.08 * float(current_floor - 1)
	var dmg_scale := 1.0 + 0.06 * float(current_floor - 1)
	if enemy.has_method("apply_floor_scaling"):
		enemy.call_deferred("apply_floor_scaling", hp_scale, dmg_scale)

func _apply_event_floor_effect() -> void:
	var heal_amount := mini(20, player.max_hp - player.hp)
	player.hp += heal_amount
	player.stamina = player.max_stamina
	player.emit_signal("hp_changed", player.hp, player.max_hp)
	player.emit_signal("stamina_changed", player.stamina, player.max_stamina)
	player.emit_signal("debug_log", "EVENT: HP +%d / STAMINA FULL" % heal_amount)

func _is_combat_cleared() -> bool:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for node in enemies:
		var enemy := node as BaseEnemy
		if enemy and enemy.current_state != BaseEnemy.EnemyState.DEAD:
			return false
	return true

func _on_floor_cleared() -> void:
	floor_phase = "clear_wait"
	floor_timer = FLOOR_CLEAR_DELAY
	_set_run_message("F%d CLEAR" % current_floor)

func _go_to_next_floor() -> void:
	if current_floor >= TOTAL_FLOORS:
		_finish_run()
		return
	current_floor += 1
	_start_floor(current_floor)

func _finish_run() -> void:
	run_finished = true
	floor_phase = "finished"
	_clear_current_floor_nodes()
	_set_run_message("RUN CLEAR! 10F 完走")
	player.emit_signal("debug_log", "RUN CLEAR (Sprint 3.1達成)")

func _clear_current_floor_nodes() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("enemy_projectiles"):
		node.queue_free()

func _update_hud_floor(floor_type: String, floor_name: String) -> void:
	if not hud.has_method("set_floor_info"):
		return
	var type_label := "COMBAT"
	if floor_type == "event":
		type_label = "EVENT"
	elif floor_type == "boss_proxy":
		type_label = "BOSS"
	hud.set_floor_info(current_floor, TOTAL_FLOORS, type_label, floor_name)

func _set_run_message(message: String) -> void:
	if hud.has_method("set_run_message"):
		hud.set_run_message(message)
	player.emit_signal("debug_log", message)

func _build_stage() -> void:
	if has_node("Stage"):
		return
	var stage := Node2D.new()
	stage.name = "Stage"
	add_child(stage)
	_create_static_rect(
		stage,
		Vector2((LEVEL_LEFT + LEVEL_RIGHT) * 0.5, GROUND_Y + 110.0),
		Vector2((LEVEL_RIGHT - LEVEL_LEFT) + 900.0, 220.0)
	)
	_create_static_rect(
		stage,
		Vector2(LEVEL_LEFT - 32.0, (LEVEL_TOP + LEVEL_BOTTOM) * 0.5),
		Vector2(64.0, (LEVEL_BOTTOM - LEVEL_TOP) + 500.0)
	)
	_create_static_rect(
		stage,
		Vector2(LEVEL_RIGHT + 32.0, (LEVEL_TOP + LEVEL_BOTTOM) * 0.5),
		Vector2(64.0, (LEVEL_BOTTOM - LEVEL_TOP) + 500.0)
	)
	_create_static_rect(stage, Vector2(1260.0, 470.0), Vector2(400.0, 28.0))
	_create_static_rect(stage, Vector2(2040.0, 390.0), Vector2(280.0, 28.0))
	_create_static_rect(stage, Vector2(2840.0, 330.0), Vector2(240.0, 28.0))

func _create_static_rect(parent: Node, center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func _setup_camera() -> void:
	camera.enabled = true
	camera.limit_left = int(LEVEL_LEFT)
	camera.limit_right = int(LEVEL_RIGHT)
	camera.limit_top = int(LEVEL_TOP - 260.0)
	camera.limit_bottom = int(LEVEL_BOTTOM)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0

func _draw() -> void:
	var world_width := (LEVEL_RIGHT - LEVEL_LEFT) + 1000.0
	var world_left := LEVEL_LEFT - 500.0
	var sky_rect := Rect2(world_left, LEVEL_TOP - 1200.0, world_width, GROUND_Y - LEVEL_TOP + 1200.0)
	draw_rect(sky_rect, Color(0.09, 0.11, 0.16))
	for i in range(6):
		var y := GROUND_Y - 240.0 - float(i) * 45.0
		var c := Color(0.14, 0.16 + 0.02 * i, 0.2 + 0.03 * i, 0.28)
		draw_line(Vector2(world_left, y), Vector2(world_left + world_width, y), c, 2.0)
	var ground_rect := Rect2(world_left, GROUND_Y, world_width, 420.0)
	draw_rect(ground_rect, Color(0.18, 0.16, 0.13))
	for x in range(int(LEVEL_LEFT), int(LEVEL_RIGHT), 160):
		draw_line(
			Vector2(float(x), GROUND_Y),
			Vector2(float(x) + 80.0, GROUND_Y),
			Color(0.25, 0.23, 0.18, 0.35),
			2.0
		)
	draw_line(
		Vector2(ENEMY_SPAWN_START_X, LEVEL_TOP),
		Vector2(ENEMY_SPAWN_START_X, GROUND_Y),
		Color(0.8, 0.35, 0.2, 0.12),
		1.0
	)
	draw_line(
		Vector2(ENEMY_SPAWN_END_X, LEVEL_TOP),
		Vector2(ENEMY_SPAWN_END_X, GROUND_Y),
		Color(0.8, 0.35, 0.2, 0.12),
		1.0
	)
