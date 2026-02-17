extends Node2D

@onready var player = $Player
@onready var hud = $HUD
@onready var camera: Camera2D = $Player/Camera2D
@onready var virtual_joystick: Control = $VirtualJoystick

var enemy_scene: PackedScene = preload("res://scenes/enemies/base_enemy.tscn")
var charger_script: GDScript = preload("res://scenes/enemies/charger.gd")
var shooter_script: GDScript = preload("res://scenes/enemies/shooter.gd")
var spreader_script: GDScript = preload("res://scenes/enemies/spreader.gd")
var shield_script: GDScript = preload("res://scenes/enemies/shield_enemy.gd")
var bomber_script: GDScript = preload("res://scenes/enemies/bomber.gd")
var summoner_script: GDScript = preload("res://scenes/enemies/summoner.gd")
var boss_script: GDScript = preload("res://scenes/enemies/boss_eraser.gd")

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
const REWARD_WEIGHT_SINGLE := 1.3
const REWARD_WEIGHT_MULTI := 1.8
const REWARD_CHOICE_COUNT := 3
const TARGET_FLOOR_TIME_MIN := 35.0
const TARGET_FLOOR_TIME_MAX := 60.0
const REINFORCEMENT_TRIGGER_TIME := 28.0

const REWARD_POOL := [
	{
		"id": "strong_guard_unlock",
		"name": "強ガード解放",
		"desc": "ガード軽減30%→65%、被弾時スタミナ消費-35%",
		"tags": ["guard", "poise"],
		"rescue_keys": ["strong_guard"]
	},
	{
		"id": "bullet_sweep_guard",
		"name": "弾消しガード",
		"desc": "ガード開始時に近距離の弾を消去",
		"tags": ["bullet", "guard"],
		"rescue_keys": ["bullet_clear"]
	},
	{
		"id": "roll_iframe_plus",
		"name": "回避無敵+",
		"desc": "ロール無敵 +0.05秒",
		"tags": ["dodge"],
		"rescue_keys": ["roll_stable"]
	},
	{
		"id": "roll_cost_down",
		"name": "ロール軽量化",
		"desc": "ロール消費スタミナ -15%",
		"tags": ["dodge"],
		"rescue_keys": ["roll_stable"]
	},
	{
		"id": "low_hp_fury",
		"name": "背水の刃",
		"desc": "HP35%以下で与ダメ +35%",
		"tags": ["crit", "bleed"],
		"rescue_keys": ["low_hp_damage"]
	},
	{
		"id": "poise_breaker",
		"name": "体幹砕き",
		"desc": "通常/スキルの体幹ダメージ増加",
		"tags": ["poise"]
	},
	{
		"id": "focus_parry",
		"name": "見切りの眼",
		"desc": "パリィ受付 +0.03秒、消費-15%",
		"tags": ["parry", "guard"]
	},
	{
		"id": "thrust_amp",
		"name": "致命の突き",
		"desc": "直線突き強化、全体与ダメ微増",
		"tags": ["crit", "parry"]
	},
	{
		"id": "stamina_flow",
		"name": "呼吸法",
		"desc": "スタミナ回復 +5/秒",
		"tags": ["dodge", "guard"]
	}
]

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
		"type": "boss",
		"name": "消しゴム神（3フェーズ）",
		"enemies": ["boss"]
	}
]

var current_floor: int = 1
var floor_phase: String = "idle"
var floor_timer: float = 0.0
var run_finished: bool = false
var current_floor_data: Dictionary = {}
var floor_start_msec: int = 0
var floor_reinforcement_spawned: bool = false
var floor_reward_offered: bool = false
var reward_options: Array[Dictionary] = []
var reward_guaranteed_this_floor: bool = false
var owned_reward_ids: Dictionary = {}
var owned_tag_counts: Dictionary = {}
var owned_rescue_keys: Dictionary = {}
var run_boss_reached: bool = false
var run_combat_floor_time_total: float = 0.0
var run_combat_floor_count: int = 0
var run_floor_times: Dictionary = {}
var session_run_count: int = 0
var session_boss_reach_count: int = 0
var session_boss_clear_count: int = 0
var session_total_combat_floor_time: float = 0.0
var session_total_combat_floor_count: int = 0

func _ready() -> void:
	randomize()
	RenderingServer.set_default_clear_color(Color(0.08, 0.08, 0.12))
	player.add_to_group("player")
	hud.setup(player)
	if virtual_joystick and virtual_joystick.has_signal("stick_input"):
		virtual_joystick.stick_input.connect(_on_stick_input)
	_build_stage()
	_setup_camera()
	player.position = PLAYER_START
	player.velocity = Vector2.ZERO
	queue_redraw()
	_start_run()

func _process(delta: float) -> void:
	if run_finished:
		return
	if player and player.hp <= 0:
		_fail_run()
		return
	match floor_phase:
		"combat":
			if _is_combat_cleared():
				_on_floor_cleared()
		"event_wait", "clear_wait":
			floor_timer -= delta
			if floor_timer <= 0:
				_progress_after_floor()
		"reward_select":
			pass

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if run_finished:
		if key_event.keycode == KEY_R:
			_start_run()
			get_viewport().set_input_as_handled()
		return
	if floor_phase != "reward_select":
		return
	var selected := -1
	match key_event.keycode:
		KEY_1, KEY_KP_1:
			selected = 0
		KEY_2, KEY_KP_2:
			selected = 1
		KEY_3, KEY_KP_3:
			selected = 2
	if selected >= 0:
		_select_reward(selected)
		get_viewport().set_input_as_handled()

func _start_run() -> void:
	session_run_count += 1
	run_finished = false
	current_floor = 1
	floor_phase = "idle"
	run_boss_reached = false
	run_combat_floor_time_total = 0.0
	run_combat_floor_count = 0
	run_floor_times.clear()
	if player and player.has_method("reset_for_new_run"):
		player.reset_for_new_run()
	owned_reward_ids.clear()
	owned_tag_counts.clear()
	owned_rescue_keys.clear()
	reward_options.clear()
	_start_floor(current_floor)

func _start_floor(floor_number: int) -> void:
	_clear_current_floor_nodes()
	player.position = PLAYER_START
	player.velocity = Vector2.ZERO
	floor_reward_offered = false
	reward_guaranteed_this_floor = false
	reward_options.clear()
	floor_reinforcement_spawned = false
	if hud.has_method("hide_reward_options"):
		hud.hide_reward_options()
	var floor_data := floor_definitions[floor_number - 1]
	current_floor_data = floor_data
	floor_start_msec = Time.get_ticks_msec()
	var floor_type: String = floor_data.get("type", "combat")
	var floor_name: String = floor_data.get("name", "")
	_update_hud_floor(floor_type, floor_name)
	match floor_type:
		"combat", "boss":
			_spawn_floor_enemies(floor_data.get("enemies", []))
			floor_phase = "combat"
			if floor_type == "boss":
				if not run_boss_reached:
					run_boss_reached = true
					session_boss_reach_count += 1
				_set_run_message("10F: 消しゴム神 出現")
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
		"boss":
			return boss_script
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
	if _should_spawn_reinforcement():
		_spawn_floor_reinforcement()
		floor_reinforcement_spawned = true
		return false
	return true

func _should_spawn_reinforcement() -> bool:
	if floor_reinforcement_spawned:
		return false
	var floor_type: String = str(current_floor_data.get("type", "combat"))
	if floor_type != "combat":
		return false
	var elapsed := _current_floor_elapsed()
	return elapsed <= REINFORCEMENT_TRIGGER_TIME

func _spawn_floor_reinforcement() -> void:
	var enemy_keys: Array = current_floor_data.get("enemies", [])
	if enemy_keys.is_empty():
		return
	var reinforcement_count := 1
	if current_floor >= 6:
		reinforcement_count = 2
	for i in range(reinforcement_count):
		var key_index := randi_range(0, enemy_keys.size() - 1)
		var key := str(enemy_keys[key_index])
		var x := ENEMY_SPAWN_END_X + randf_range(-180.0, 180.0) + float(i) * 36.0
		x = clampf(x, ENEMY_SPAWN_START_X, LEVEL_RIGHT - 260.0)
		var y := ENEMY_SPAWN_Y + randf_range(-SPAWN_JITTER_Y, SPAWN_JITTER_Y)
		_spawn_enemy_by_key(key, Vector2(x, y))
	_set_run_message("F%d 増援出現 (短時間クリア対策)" % current_floor)

func _on_floor_cleared() -> void:
	_record_floor_time_if_needed()
	floor_phase = "clear_wait"
	floor_timer = FLOOR_CLEAR_DELAY
	_set_run_message("F%d CLEAR - 報酬選択へ" % current_floor)

func _progress_after_floor() -> void:
	if current_floor >= TOTAL_FLOORS:
		_finish_run()
		return
	if _should_offer_reward_for_floor() and not floor_reward_offered:
		_begin_reward_selection()
		return
	_go_to_next_floor()

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
	if hud.has_method("hide_reward_options"):
		hud.hide_reward_options()
	session_boss_clear_count += 1
	_set_run_message("RUN CLEAR! 10F 完走 (Rで再挑戦)")
	player.emit_signal("debug_log", "RUN CLEAR")
	_log_kpi_summary(true)

func _fail_run() -> void:
	run_finished = true
	floor_phase = "finished"
	_clear_current_floor_nodes()
	if hud.has_method("hide_reward_options"):
		hud.hide_reward_options()
	_set_run_message("RUN FAILED (Rで再挑戦)")
	player.emit_signal("debug_log", "RUN FAILED at F%d" % current_floor)
	_log_kpi_summary(false)

func _should_offer_reward_for_floor() -> bool:
	return current_floor < TOTAL_FLOORS

func _begin_reward_selection() -> void:
	floor_reward_offered = true
	reward_options = _generate_reward_options()
	if reward_options.is_empty():
		_set_run_message("報酬候補なし -> 次フロア")
		_go_to_next_floor()
		return
	floor_phase = "reward_select"
	var hint := "報酬選択: 1/2/3 キー"
	if reward_guaranteed_this_floor:
		hint += "（9F救済候補を含む）"
	_set_run_message(hint)
	if hud.has_method("show_reward_options"):
		hud.show_reward_options(current_floor, reward_options, reward_guaranteed_this_floor)

func _select_reward(option_index: int) -> void:
	if option_index < 0 or option_index >= reward_options.size():
		return
	var reward := reward_options[option_index]
	_apply_reward(reward)
	if hud.has_method("hide_reward_options"):
		hud.hide_reward_options()
	_set_run_message("取得: %s" % reward.get("name", "UNKNOWN"))
	_go_to_next_floor()

func _apply_reward(reward: Dictionary) -> void:
	var reward_id: String = str(reward.get("id", ""))
	if reward_id != "":
		owned_reward_ids[reward_id] = true
	var tags: Array = reward.get("tags", [])
	for tag in tags:
		var key := str(tag)
		owned_tag_counts[key] = int(owned_tag_counts.get(key, 0)) + 1
	var rescue_keys: Array = reward.get("rescue_keys", [])
	for rescue_key in rescue_keys:
		owned_rescue_keys[str(rescue_key)] = true
	if player and player.has_method("apply_reward"):
		player.apply_reward(reward)
	if hud.has_method("set_reward_summary"):
		hud.set_reward_summary(owned_tag_counts)
	player.emit_signal("debug_log", "REWARD PICK: %s" % reward.get("name", reward_id))

func _generate_reward_options() -> Array[Dictionary]:
	reward_guaranteed_this_floor = false
	var available := _get_available_rewards()
	if available.is_empty():
		return []

	var primary_tag := _get_primary_tag()
	var options: Array[Dictionary] = []
	if primary_tag == "":
		options = _pick_weighted_unique(available, REWARD_CHOICE_COUNT)
	else:
		var same_pool: Array = []
		var off_pool: Array = []
		for reward in available:
			if _reward_has_tag(reward, primary_tag):
				same_pool.append(reward)
			else:
				off_pool.append(reward)

		options.append_array(_pick_weighted_unique(same_pool, mini(2, same_pool.size())))
		var remaining := REWARD_CHOICE_COUNT - options.size()
		if remaining > 0 and not off_pool.is_empty():
			options.append_array(_pick_weighted_unique(off_pool, 1))
		remaining = REWARD_CHOICE_COUNT - options.size()
		if remaining > 0:
			var merged_pool: Array = []
			merged_pool.append_array(same_pool)
			merged_pool.append_array(off_pool)
			var filtered_pool: Array = []
			for reward in merged_pool:
				var reward_id := str(reward.get("id", ""))
				if not _contains_reward_id(options, reward_id):
					filtered_pool.append(reward)
			options.append_array(_pick_weighted_unique(filtered_pool, remaining))

	if current_floor >= 9 and not _has_rescue_piece():
		var rescue_reward := _pick_rescue_reward(available, options)
		if not rescue_reward.is_empty():
			reward_guaranteed_this_floor = true
			var rescue_id := str(rescue_reward.get("id", ""))
			if not _contains_reward_id(options, rescue_id):
				if options.size() >= REWARD_CHOICE_COUNT:
					options[REWARD_CHOICE_COUNT - 1] = rescue_reward
				else:
					options.append(rescue_reward)

	return options

func _get_available_rewards() -> Array:
	var result: Array = []
	for reward in REWARD_POOL:
		var reward_id := str(reward.get("id", ""))
		if reward_id == "":
			continue
		if owned_reward_ids.has(reward_id):
			continue
		result.append(reward)
	return result

func _pick_weighted_unique(pool: Array, count: int) -> Array[Dictionary]:
	var picks: Array[Dictionary] = []
	if count <= 0:
		return picks
	var mutable_pool: Array = pool.duplicate(true)
	while picks.size() < count and not mutable_pool.is_empty():
		var idx := _pick_weighted_index(mutable_pool)
		if idx < 0 or idx >= mutable_pool.size():
			break
		picks.append(mutable_pool[idx])
		mutable_pool.remove_at(idx)
	return picks

func _pick_weighted_index(pool: Array) -> int:
	if pool.is_empty():
		return -1
	var total_weight := 0.0
	for reward in pool:
		total_weight += _reward_weight(reward)
	if total_weight <= 0.0:
		return randi_range(0, pool.size() - 1)
	var roll := randf() * total_weight
	for i in range(pool.size()):
		roll -= _reward_weight(pool[i])
		if roll <= 0.0:
			return i
	return pool.size() - 1

func _reward_weight(reward: Dictionary) -> float:
	var tags: Array = reward.get("tags", [])
	var max_tag_count := 0
	for tag in tags:
		var count := int(owned_tag_counts.get(str(tag), 0))
		max_tag_count = maxi(max_tag_count, count)
	if max_tag_count >= 2:
		return REWARD_WEIGHT_MULTI
	if max_tag_count == 1:
		return REWARD_WEIGHT_SINGLE
	return 1.0

func _get_primary_tag() -> String:
	var primary_tag := ""
	var best_count := 0
	for key in owned_tag_counts.keys():
		var count := int(owned_tag_counts[key])
		if count > best_count:
			best_count = count
			primary_tag = str(key)
	return primary_tag

func _reward_has_tag(reward: Dictionary, tag: String) -> bool:
	var tags: Array = reward.get("tags", [])
	return tags.has(tag)

func _contains_reward_id(rewards: Array, reward_id: String) -> bool:
	for reward in rewards:
		if str(reward.get("id", "")) == reward_id:
			return true
	return false

func _is_rescue_reward(reward: Dictionary) -> bool:
	var rescue_keys: Array = reward.get("rescue_keys", [])
	return not rescue_keys.is_empty()

func _has_rescue_piece() -> bool:
	return owned_rescue_keys.size() > 0

func _pick_rescue_reward(available: Array, options: Array[Dictionary]) -> Dictionary:
	var candidates: Array = []
	for reward in available:
		if not _is_rescue_reward(reward):
			continue
		var reward_id := str(reward.get("id", ""))
		if _contains_reward_id(options, reward_id):
			continue
		candidates.append(reward)
	if candidates.is_empty():
		return {}
	var picked := _pick_weighted_unique(candidates, 1)
	if picked.is_empty():
		return {}
	return picked[0]

func _current_floor_elapsed() -> float:
	if floor_start_msec <= 0:
		return 0.0
	return maxf(0.0, float(Time.get_ticks_msec() - floor_start_msec) / 1000.0)

func _record_floor_time_if_needed() -> void:
	var floor_type: String = str(current_floor_data.get("type", "combat"))
	if floor_type not in ["combat", "boss"]:
		return
	var elapsed := _current_floor_elapsed()
	run_floor_times[current_floor] = elapsed
	run_combat_floor_time_total += elapsed
	run_combat_floor_count += 1
	session_total_combat_floor_time += elapsed
	session_total_combat_floor_count += 1
	floor_start_msec = 0

func _log_kpi_summary(run_clear: bool) -> void:
	var run_avg := 0.0
	if run_combat_floor_count > 0:
		run_avg = run_combat_floor_time_total / float(run_combat_floor_count)
	var session_avg := 0.0
	if session_total_combat_floor_count > 0:
		session_avg = session_total_combat_floor_time / float(session_total_combat_floor_count)
	var boss_reach_rate := 0.0
	var boss_clear_rate := 0.0
	if session_run_count > 0:
		boss_reach_rate = 100.0 * float(session_boss_reach_count) / float(session_run_count)
		boss_clear_rate = 100.0 * float(session_boss_clear_count) / float(session_run_count)
	var result := "CLEAR" if run_clear else "FAIL"
	player.emit_signal(
		"debug_log",
		"KPI[%s] run_avg:%.1fs session_avg:%.1fs reach:%.1f%% clear:%.1f%% target:%.0f-%.0fs"
		% [result, run_avg, session_avg, boss_reach_rate, boss_clear_rate, TARGET_FLOOR_TIME_MIN, TARGET_FLOOR_TIME_MAX]
	)

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
	elif floor_type == "boss":
		type_label = "BOSS"
	hud.set_floor_info(current_floor, TOTAL_FLOORS, type_label, floor_name)

func _set_run_message(message: String) -> void:
	if hud.has_method("set_run_message"):
		hud.set_run_message(message)
	player.emit_signal("debug_log", message)

func _on_stick_input(direction: Vector2) -> void:
	if player and player.has_method("set_virtual_move_axis"):
		player.set_virtual_move_axis(direction.x)

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
