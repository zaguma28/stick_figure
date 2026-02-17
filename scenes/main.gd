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
const FLOOR_CENTER := Vector2(360, 640)
const FLOOR_RADIUS := 280.0

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
	player.position = FLOOR_CENTER
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
	player.position = FLOOR_CENTER
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
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var pos := FLOOR_CENTER + Vector2.RIGHT.rotated(angle) * FLOOR_RADIUS
		pos += Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		var key: String = str(enemy_keys[i])
		_spawn_enemy_by_key(key, pos)

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

func _draw() -> void:
	var grid_size := 80
	var grid_range := 3000
	var grid_color := Color(0.2, 0.2, 0.3, 0.3)
	for x in range(-grid_range, grid_range + 1, grid_size):
		draw_line(Vector2(x, -grid_range), Vector2(x, grid_range), grid_color, 1.0)
	for y in range(-grid_range, grid_range + 1, grid_size):
		draw_line(Vector2(-grid_range, y), Vector2(grid_range, y), grid_color, 1.0)
	draw_circle(Vector2.ZERO, 6, Color(1.0, 0.3, 0.3, 0.6))
	draw_circle(FLOOR_CENTER, 6, Color(0.3, 0.5, 1.0, 0.6))
