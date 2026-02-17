extends BaseEnemy

var bullet_scene: PackedScene = preload("res://scenes/enemies/bullet.tscn")

const LOOP_DURATIONS := {
	1: 18.0,
	2: 22.0,
	3: 24.0
}

const PHASE_PATTERNS := {
	1: [
		{"time": 0.0, "name": "起動小弾", "type": "small_burst", "telegraph": 0.8, "duration": 0.45, "count": 3, "damage": 14, "speed": 320.0, "spread": 0.34},
		{"time": 2.2, "name": "横薙ぎ", "type": "slash", "telegraph": 0.45, "duration": 0.4, "range": 86.0, "damage": 28},
		{"time": 4.6, "name": "直線突進", "type": "dash_combo", "telegraph": 0.75, "duration": 0.85, "damage": 34, "dashes": 1, "dash_distance": 220.0, "dash_interval": 0.35},
		{"time": 7.0, "name": "押しつぶし小", "type": "crush_small", "telegraph": 0.65, "duration": 0.6, "radius": 112.0, "damage": 28},
		{"time": 10.0, "name": "休止", "type": "rest", "telegraph": 0.0, "duration": 2.0}
	],
	2: [
		{"time": 0.0, "name": "弾幕リング", "type": "ring_shot", "telegraph": 0.55, "duration": 0.45, "count": 12, "damage": 14, "speed": 300.0},
		{"time": 3.2, "name": "安全地帯スライド", "type": "safe_slide", "telegraph": 0.4, "duration": 1.35, "damage": 10, "field_duration": 2.8, "safe_half": 105.0},
		{"time": 7.0, "name": "追跡小弾", "type": "tracking_burst", "telegraph": 0.2, "duration": 1.25, "count": 5, "damage": 14, "speed": 360.0, "interval": 0.22},
		{"time": 10.5, "name": "押しつぶし中", "type": "crush_mid", "telegraph": 0.75, "duration": 0.75, "radius": 132.0, "damage": 28},
		{"time": 14.5, "name": "突進2連", "type": "dash_combo", "telegraph": 0.65, "duration": 1.35, "damage": 34, "dashes": 2, "dash_distance": 230.0, "dash_interval": 0.42}
	],
	3: [
		{"time": 0.0, "name": "危険弾バースト", "type": "danger_burst", "telegraph": 0.35, "duration": 0.45, "count": 6, "damage": 38, "speed": 430.0, "spread": 0.5},
		{"time": 3.4, "name": "斬上→叩き", "type": "slash_smash", "telegraph": 0.4, "duration": 0.95, "slash_range": 92.0, "slash_damage": 28, "smash_radius": 155.0, "smash_damage": 50},
		{"time": 7.8, "name": "突進3連", "type": "dash_combo", "telegraph": 0.55, "duration": 1.75, "damage": 34, "dashes": 3, "dash_distance": 240.0, "dash_interval": 0.36},
		{"time": 12.0, "name": "全消し（大技）", "type": "erase_rain", "telegraph": 0.9, "duration": 4.0, "rain_damage": 14, "interval": 0.18, "field_damage": 12, "safe_half": 140.0},
		{"time": 18.0, "name": "休止", "type": "rest", "telegraph": 0.0, "duration": 1.6}
	]
}

var phase_index: int = 1
var phase_timer: float = 0.0
var next_action_index: int = 0
var current_action: Dictionary = {}
var action_timer: float = 0.0
var action_step: int = 0
var telegraph_radius: float = 140.0
var telegraph_color: Color = Color(1.0, 0.86, 0.25, 0.35)
var floor_hazards: Array[Dictionary] = []

func _ready() -> void:
	max_hp = 1250
	contact_damage = 28
	move_speed = 92.0
	max_poise = 220.0
	poise_regen_rate = 6.0
	down_duration = 1.5
	attack_range = 96.0
	engagement_height = 120.0
	super()
	current_state = EnemyState.CHASE
	_enter_phase(1)
	_broadcast_to_player("BOSS: 消しゴム神 出現")

func apply_floor_scaling(_hp_scale: float, _damage_scale: float) -> void:
	# ボスは仕様値を固定で運用する
	hp = max_hp

func _update_state(delta: float) -> void:
	if current_state == EnemyState.DEAD:
		return

	_update_phase_by_hp()
	_update_floor_hazards(delta)

	match current_state:
		EnemyState.DOWN:
			velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
			if state_timer <= 0:
				poise = max_poise
				current_state = EnemyState.CHASE
		EnemyState.TELEGRAPH:
			velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
			if state_timer <= 0:
				_start_action()
		EnemyState.ATTACK:
			_process_action(delta)
			if state_timer <= 0:
				_end_action()
		_:
			_chase_target(delta)
			_advance_pattern(delta)

func _chase_target(delta: float) -> void:
	if not target:
		velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
		return
	var dx := target.global_position.x - global_position.x
	var abs_dx := absf(dx)
	var dir_x := signf(dx)
	if dir_x != 0.0:
		facing_dir = Vector2(dir_x, 0.0)
	var desired_speed := 0.0
	if abs_dx > 180.0:
		desired_speed = dir_x * move_speed
	elif abs_dx < 110.0:
		desired_speed = -dir_x * (move_speed * 0.4)
	velocity.x = move_toward(velocity.x, desired_speed, ground_accel * delta)

func _advance_pattern(delta: float) -> void:
	phase_timer += delta
	var pattern: Array = PHASE_PATTERNS.get(phase_index, [])
	if pattern.is_empty():
		return
	if next_action_index >= pattern.size():
		var loop_time := float(LOOP_DURATIONS.get(phase_index, 18.0))
		if phase_timer >= loop_time:
			phase_timer = 0.0
			next_action_index = 0
		return
	var action: Dictionary = pattern[next_action_index]
	if phase_timer >= float(action.get("time", 0.0)):
		_start_telegraph(action)
		next_action_index += 1

func _start_telegraph(action: Dictionary) -> void:
	current_action = action
	current_state = EnemyState.TELEGRAPH
	state_timer = float(action.get("telegraph", 0.35))
	action_step = 0
	action_timer = 0.0
	_set_telegraph_visual(str(action.get("type", "")))
	_broadcast_to_player("BOSS予兆: %s" % str(action.get("name", "ATTACK")))

func _set_telegraph_visual(action_type: String) -> void:
	match action_type:
		"dash_combo":
			telegraph_radius = 200.0
			telegraph_color = Color(1.0, 0.4, 0.25, 0.38)
		"ring_shot", "danger_burst", "erase_rain":
			telegraph_radius = 170.0
			telegraph_color = Color(1.0, 0.2, 0.2, 0.35)
		"slash", "slash_smash":
			telegraph_radius = 120.0
			telegraph_color = Color(1.0, 0.9, 0.2, 0.34)
		"crush_small", "crush_mid", "safe_slide":
			telegraph_radius = 150.0
			telegraph_color = Color(1.0, 0.62, 0.2, 0.36)
		_:
			telegraph_radius = 135.0
			telegraph_color = Color(1.0, 0.85, 0.3, 0.32)

func _start_action() -> void:
	current_state = EnemyState.ATTACK
	state_timer = float(current_action.get("duration", 0.45))
	action_timer = 0.0
	action_step = 0
	var action_type := str(current_action.get("type", ""))
	match action_type:
		"small_burst":
			_fire_aimed_burst(
				int(current_action.get("count", 3)),
				float(current_action.get("spread", 0.3)),
				int(current_action.get("damage", 14)),
				float(current_action.get("speed", 320.0))
			)
		"ring_shot":
			_fire_ring(
				int(current_action.get("count", 12)),
				int(current_action.get("damage", 14)),
				float(current_action.get("speed", 300.0)),
				0.0
			)
		"safe_slide":
			_spawn_slide_wave(int(current_action.get("damage", 10)))
			_spawn_safe_slide_hazard(
				int(current_action.get("damage", 10)),
				float(current_action.get("field_duration", 2.8)),
				float(current_action.get("safe_half", 105.0))
			)
		"danger_burst":
			_fire_aimed_burst(
				int(current_action.get("count", 6)),
				float(current_action.get("spread", 0.5)),
				int(current_action.get("damage", 38)),
				float(current_action.get("speed", 440.0))
			)
		"erase_rain":
			_spawn_erase_field_hazard(
				int(current_action.get("field_damage", 12)),
				float(current_action.get("duration", 4.0)),
				float(current_action.get("safe_half", 140.0))
			)
		"rest":
			velocity.x = 0.0

func _process_action(delta: float) -> void:
	action_timer += delta
	var action_type := str(current_action.get("type", ""))
	match action_type:
		"slash":
			if action_step == 0 and action_timer >= 0.08:
				_try_melee_hit(float(current_action.get("range", 86.0)), int(current_action.get("damage", 28)), true)
				action_step = 1
		"crush_small", "crush_mid":
			if action_step == 0 and action_timer >= 0.16:
				_aoe_hit(float(current_action.get("radius", 120.0)), int(current_action.get("damage", 28)))
				if action_type == "crush_mid":
					_fire_ring(6, 14, 260.0, PI * 0.16)
				action_step = 1
		"dash_combo":
			var interval := maxf(0.12, float(current_action.get("dash_interval", 0.36)))
			var total := int(current_action.get("dashes", 1))
			while action_step < total and action_timer >= interval * float(action_step):
				_perform_dash_strike(
					float(current_action.get("dash_distance", 220.0)),
					int(current_action.get("damage", 34))
				)
				action_step += 1
		"tracking_burst":
			var t_interval := maxf(0.1, float(current_action.get("interval", 0.22)))
			var count := int(current_action.get("count", 5))
			while action_step < count and action_timer >= t_interval * float(action_step):
				_fire_tracking_shot(
					int(current_action.get("damage", 14)),
					float(current_action.get("speed", 360.0))
				)
				action_step += 1
		"slash_smash":
			if action_step == 0 and action_timer >= 0.12:
				_try_melee_hit(
					float(current_action.get("slash_range", 90.0)),
					int(current_action.get("slash_damage", 28)),
					true
				)
				action_step = 1
			if action_step == 1 and action_timer >= 0.58:
				_aoe_hit(float(current_action.get("smash_radius", 150.0)), int(current_action.get("smash_damage", 50)))
				action_step = 2
		"erase_rain":
			var r_interval := maxf(0.08, float(current_action.get("interval", 0.18)))
			var emission_count := int(floor(action_timer / r_interval))
			while action_step < emission_count:
				_spawn_rain_bullet(int(current_action.get("rain_damage", 14)))
				action_step += 1
		_:
			pass

func _end_action() -> void:
	current_action.clear()
	current_state = EnemyState.CHASE
	action_timer = 0.0
	action_step = 0
	velocity.x = move_toward(velocity.x, 0.0, 900.0)

func _try_melee_hit(hit_range: float, damage: int, front_only: bool = false) -> void:
	if not target:
		return
	var dx := target.global_position.x - global_position.x
	var dy := absf(target.global_position.y - global_position.y)
	if front_only and signf(dx) != signf(facing_dir.x) and absf(dx) > 6.0:
		return
	if absf(dx) <= hit_range and dy <= engagement_height:
		_deal_damage_to_player(damage)

func _aoe_hit(radius: float, damage: int) -> void:
	if not target:
		return
	if global_position.distance_to(target.global_position) <= radius:
		_deal_damage_to_player(damage)

func _perform_dash_strike(distance: float, damage: int) -> void:
	if target:
		var dir_x := signf(target.global_position.x - global_position.x)
		if dir_x == 0.0:
			dir_x = facing_dir.x
		facing_dir = Vector2(dir_x, 0.0)
	global_position.x += facing_dir.x * distance
	_try_melee_hit(96.0, damage)
	_fire_ring(4, 12, 240.0, PI * 0.25)

func _fire_aimed_burst(count: int, spread: float, damage: int, speed: float) -> void:
	var base_dir := _get_aim_direction()
	if count <= 1:
		_spawn_bullet(base_dir, damage, speed)
		return
	for i in range(count):
		var t := (float(i) / float(count - 1)) * 2.0 - 1.0
		var dir := base_dir.rotated(spread * t)
		_spawn_bullet(dir, damage, speed)

func _fire_ring(count: int, damage: int, speed: float, angle_offset: float) -> void:
	var safe_count := maxi(1, count)
	for i in range(safe_count):
		var angle := angle_offset + TAU * float(i) / float(safe_count)
		_spawn_bullet(Vector2.RIGHT.rotated(angle), damage, speed)

func _fire_tracking_shot(damage: int, speed: float) -> void:
	var dir := _get_aim_direction().rotated(randf_range(-0.12, 0.12))
	_spawn_bullet(dir, damage, speed)

func _spawn_slide_wave(damage: int) -> void:
	_fire_ring(8, damage, 230.0, PI * 0.14)

func _spawn_rain_bullet(damage: int) -> void:
	var center_x := global_position.x
	if target:
		center_x = target.global_position.x
	var spawn_pos := Vector2(center_x + randf_range(-300.0, 300.0), global_position.y - 210.0)
	var dir := Vector2(randf_range(-0.16, 0.16), 1.0).normalized()
	_spawn_bullet(dir, damage, randf_range(240.0, 360.0), spawn_pos)

func _spawn_bullet(dir: Vector2, damage: int, speed: float, spawn_pos: Vector2 = Vector2.INF) -> void:
	var bullet := bullet_scene.instantiate()
	bullet.direction = dir.normalized()
	bullet.damage = damage
	bullet.speed = speed
	if spawn_pos == Vector2.INF:
		bullet.global_position = global_position + Vector2(18.0 * signf(dir.x), -10.0)
	else:
		bullet.global_position = spawn_pos
	get_parent().add_child(bullet)

func _get_aim_direction() -> Vector2:
	if target:
		var to_target := target.global_position - global_position
		if to_target.length() > 0.001:
			return to_target.normalized()
	var dir_x := 1.0 if facing_dir.x >= 0.0 else -1.0
	return Vector2(dir_x, 0.0)

func _spawn_safe_slide_hazard(damage: int, hazard_duration: float, safe_half_width: float) -> void:
	if not target:
		return
	var safe_center := target.global_position.x + randf_range(-80.0, 80.0)
	floor_hazards.append(
		{
			"type": "safe_slide",
			"damage": damage,
			"duration": maxf(0.6, hazard_duration),
			"tick_interval": 0.5,
			"tick_timer": 0.22,
			"safe_center_x": safe_center,
			"safe_half_width": maxf(70.0, safe_half_width),
			"visual_height": 170.0,
			"color": Color(1.0, 0.55, 0.22, 0.26)
		}
	)
	_broadcast_to_player("BOSS: 安全地帯へ移動")

func _spawn_erase_field_hazard(damage: int, hazard_duration: float, safe_half_width: float) -> void:
	if not target:
		return
	var offset := 280.0 if randf() < 0.5 else -280.0
	var safe_center := target.global_position.x + offset
	floor_hazards.append(
		{
			"type": "erase_field",
			"damage": damage,
			"duration": maxf(1.0, hazard_duration),
			"tick_interval": 0.4,
			"tick_timer": 0.2,
			"safe_center_x": safe_center,
			"safe_half_width": maxf(110.0, safe_half_width),
			"visual_height": 190.0,
			"color": Color(1.0, 0.16, 0.16, 0.28)
		}
	)
	_broadcast_to_player("BOSS: 全消し - 安全地帯へ")

func _update_floor_hazards(delta: float) -> void:
	if floor_hazards.is_empty():
		return
	var remove_indices: Array[int] = []
	for i in range(floor_hazards.size()):
		var hazard: Dictionary = floor_hazards[i]
		var remaining := float(hazard.get("duration", 0.0)) - delta
		hazard["duration"] = remaining
		var tick_timer := float(hazard.get("tick_timer", 0.0)) - delta
		if tick_timer <= 0.0:
			var tick_interval := maxf(0.1, float(hazard.get("tick_interval", 0.4)))
			tick_timer += tick_interval
			_apply_hazard_tick(hazard)
		hazard["tick_timer"] = tick_timer
		floor_hazards[i] = hazard
		if remaining <= 0.0:
			remove_indices.push_front(i)
	for idx in remove_indices:
		floor_hazards.remove_at(idx)

func _apply_hazard_tick(hazard: Dictionary) -> void:
	if not target:
		return
	var safe_center := float(hazard.get("safe_center_x", global_position.x))
	var safe_half := float(hazard.get("safe_half_width", 120.0))
	var px := target.global_position.x
	if absf(px - safe_center) > safe_half:
		_deal_unblockable_damage(int(hazard.get("damage", 10)))

func _deal_unblockable_damage(amount: int) -> void:
	if not target:
		return
	if target.has_method("take_hazard_damage"):
		target.take_hazard_damage(amount, self)
	else:
		_deal_damage_to_player(amount)

func _update_phase_by_hp() -> void:
	if max_hp <= 0:
		return
	var hp_ratio := float(hp) / float(max_hp)
	var next_phase := 1
	if hp_ratio <= 0.35:
		next_phase = 3
	elif hp_ratio <= 0.7:
		next_phase = 2
	if next_phase != phase_index:
		_enter_phase(next_phase)

func _enter_phase(next_phase: int) -> void:
	phase_index = clampi(next_phase, 1, 3)
	phase_timer = 0.0
	next_action_index = 0
	current_action.clear()
	action_timer = 0.0
	action_step = 0
	current_state = EnemyState.CHASE
	state_timer = 0.0
	_broadcast_to_player("BOSS PHASE %d" % phase_index)

func _broadcast_to_player(message: String) -> void:
	if target and target.has_signal("debug_log"):
		target.emit_signal("debug_log", message)

func _draw_floor_hazards() -> void:
	for hazard in floor_hazards:
		var safe_center_local := float(hazard.get("safe_center_x", global_position.x)) - global_position.x
		var safe_half := float(hazard.get("safe_half_width", 120.0))
		var visual_h := float(hazard.get("visual_height", 180.0))
		var color := hazard.get("color", Color(1.0, 0.2, 0.2, 0.24))
		var field_half := 520.0
		var left_w := maxf(0.0, safe_center_local - safe_half + field_half)
		var right_x := safe_center_local + safe_half
		var right_w := maxf(0.0, field_half - right_x)
		if left_w > 0.0:
			draw_rect(Rect2(-field_half, -visual_h * 0.5, left_w, visual_h), color)
		if right_w > 0.0:
			draw_rect(Rect2(right_x, -visual_h * 0.5, right_w, visual_h), color)
		draw_line(
			Vector2(safe_center_local - safe_half, -visual_h * 0.54),
			Vector2(safe_center_local - safe_half, visual_h * 0.54),
			Color(0.98, 0.95, 0.92, 0.35),
			1.3
		)
		draw_line(
			Vector2(safe_center_local + safe_half, -visual_h * 0.54),
			Vector2(safe_center_local + safe_half, visual_h * 0.54),
			Color(0.98, 0.95, 0.92, 0.35),
			1.3
		)

func _draw() -> void:
	super()
	_draw_floor_hazards()
	var phase_color := Color(0.95, 0.8, 0.3, 0.85)
	if phase_index == 2:
		phase_color = Color(1.0, 0.55, 0.25, 0.9)
	elif phase_index == 3:
		phase_color = Color(1.0, 0.24, 0.24, 0.92)
	draw_circle(Vector2(0, -42), 6.0 + float(phase_index) * 2.0, phase_color)
	if current_state == EnemyState.TELEGRAPH:
		draw_arc(Vector2.ZERO, telegraph_radius, 0.0, TAU, 48, telegraph_color, 3.0)
	if current_state == EnemyState.ATTACK:
		draw_circle(Vector2.ZERO, 44.0, Color(1.0, 0.2, 0.2, 0.1))
