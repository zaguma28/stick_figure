extends CharacterBody2D

enum State {
	IDLE, MOVE, ATTACK_1, ATTACK_2, ATTACK_3,
	ROLL, GUARD, PARRY, PARRY_FAIL, ESTUS,
	STAGGER, SKILL_1, SKILL_2
}

@export var max_hp: int = 100
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 22.0
@export var stamina_delay: float = 0.25
@export var move_speed: float = 276.0
@export var iframes_duration: float = 0.35
@export var gravity: float = 1800.0
@export var jump_velocity: float = -700.0
@export var max_fall_speed: float = 1400.0
@export var air_control: float = 0.72
@export var ground_decel: float = 1650.0

var attack_damage := [10, 10, 18]
var attack_stamina := [18.0, 18.0, 26.0]
var attack_poise := [8, 8, 14]
var attack3_recovery := 0.30
var skill1_damage: int = 42
var skill2_damage: int = 24
var skill1_poise_damage: int = 18
var skill2_poise_damage: int = 12

@export var roll_stamina: float = 28.0
@export var roll_iframes: float = 0.24
@export var roll_recovery: float = 0.14
@export var roll_distance: float = 168.0

@export var parry_stamina: float = 24.0
@export var parry_window: float = 0.18
@export var parry_fail_stagger: float = 0.35

@export var estus_stamina: float = 16.0
@export var estus_heal: int = 35
@export var estus_max_charges: int = 3

@export var guard_reduction: float = 0.30
@export var guard_stamina_per_hit: float = 22.0
@export var guard_break_stagger: float = 0.6

var hp: int
var stamina: float
var estus_charges: int
var current_state: State = State.IDLE
var move_axis: float = 0.0
var facing_dir := Vector2.RIGHT

var stamina_delay_timer: float = 0.0
var state_timer: float = 0.0
var iframes_timer: float = 0.0
var parry_active_timer: float = 0.0
var combo_window_timer: float = 0.0

var skill1_cd: float = 0.0
var skill2_cd: float = 0.0

var attack_hit_ids: Array = []
var _last_attack: int = 0
var bonus_damage_multiplier: float = 1.0
var low_hp_damage_multiplier: float = 1.0
var low_hp_damage_threshold: float = 0.35
var guard_stamina_multiplier: float = 1.0
var bullet_clear_on_guard: bool = false

signal debug_log(msg: String)
signal hp_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal estus_changed(current: int, maximum: int)

func _ready() -> void:
	hp = max_hp
	stamina = max_stamina
	estus_charges = estus_max_charges
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("stamina_changed", stamina, max_stamina)
	emit_signal("estus_changed", estus_charges, estus_max_charges)

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_handle_input()
	_process_state(delta)
	_apply_gravity(delta)
	move_and_slide()
	_check_attack_hits()
	_update_visuals()

func _update_timers(delta: float) -> void:
	if stamina_delay_timer > 0:
		stamina_delay_timer -= delta
	elif stamina < max_stamina:
		stamina = minf(stamina + stamina_regen * delta, max_stamina)
		emit_signal("stamina_changed", stamina, max_stamina)

	if iframes_timer > 0:
		iframes_timer -= delta
	if state_timer > 0:
		state_timer -= delta
	if parry_active_timer > 0:
		parry_active_timer -= delta
	if combo_window_timer > 0:
		combo_window_timer -= delta
	if skill1_cd > 0:
		skill1_cd -= delta
	if skill2_cd > 0:
		skill2_cd -= delta

func _handle_input() -> void:
	move_axis = Input.get_axis("move_left", "move_right")
	if absf(move_axis) > 0.05:
		facing_dir = Vector2(signf(move_axis), 0.0)

	if Input.is_action_just_pressed("jump") and _can_jump():
		velocity.y = jump_velocity
		emit_signal("debug_log", "JUMP")

	if _is_locked():
		return

	if Input.is_action_just_pressed("guard"):
		if _can_use_stamina(parry_stamina):
			_enter_parry()
			return

	if Input.is_action_pressed("guard"):
		if current_state != State.PARRY:
			_enter_guard()
			return

	if Input.is_action_just_released("guard"):
		if current_state == State.GUARD:
			_change_state(State.IDLE)
			return

	if Input.is_action_just_pressed("attack"):
		_try_attack()
		return

	if Input.is_action_just_pressed("roll"):
		if _can_use_stamina(roll_stamina):
			_enter_roll()
			return

	if Input.is_action_just_pressed("estus"):
		if estus_charges > 0 and _can_use_stamina(estus_stamina):
			_enter_estus()
			return

	if Input.is_action_just_pressed("skill_1"):
		if skill1_cd <= 0 and _can_use_stamina(18.0):
			_enter_skill1()
			return

	if Input.is_action_just_pressed("skill_2"):
		if skill2_cd <= 0 and _can_use_stamina(18.0):
			_enter_skill2()
			return

	if absf(move_axis) > 0.05:
		if current_state != State.MOVE:
			_change_state(State.MOVE)
	else:
		if current_state == State.MOVE:
			_change_state(State.IDLE)

func _process_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)

		State.MOVE:
			var control := 1.0 if is_on_floor() else air_control
			velocity.x = move_axis * move_speed * control
			if absf(move_axis) <= 0.05 and is_on_floor():
				_change_state(State.IDLE)

		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
			if state_timer <= 0:
				if current_state != State.ATTACK_3:
					combo_window_timer = 0.3
				_change_state(State.IDLE)

		State.ROLL:
			if state_timer > 0:
				velocity.x = facing_dir.x * (roll_distance / (roll_iframes + roll_recovery))
			else:
				_change_state(State.IDLE)

		State.GUARD:
			velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)

		State.PARRY:
			velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
			if parry_active_timer <= 0 and state_timer <= 0:
				_change_state(State.PARRY_FAIL)

		State.PARRY_FAIL:
			velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
			if state_timer <= 0:
				_change_state(State.IDLE)

		State.ESTUS:
			velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
			if state_timer <= 0:
				_change_state(State.IDLE)

		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
			if state_timer <= 0:
				_change_state(State.IDLE)

		State.SKILL_1, State.SKILL_2:
			velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
			if state_timer <= 0:
				_change_state(State.IDLE)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _enter_parry() -> void:
	_consume_stamina(parry_stamina)
	_change_state(State.PARRY)
	parry_active_timer = parry_window
	state_timer = parry_window + 0.1
	emit_signal("debug_log", "PARRY (window %.2fs)" % parry_window)

func _enter_guard() -> void:
	_change_state(State.GUARD)
	emit_signal("debug_log", "GUARD (%d%% reduction)" % int(guard_reduction * 100))
	if bullet_clear_on_guard:
		var removed := _clear_enemy_projectiles(220.0)
		if removed > 0:
			emit_signal("debug_log", "GUARD WAVE: 弾消し x%d" % removed)

func _try_attack() -> void:
	var stage := 0
	if combo_window_timer > 0 and _last_attack == 1:
		stage = 1
	elif combo_window_timer > 0 and _last_attack == 2:
		stage = 2

	if not _can_use_stamina(attack_stamina[stage]):
		return

	_consume_stamina(attack_stamina[stage])
	combo_window_timer = 0.0

	match stage:
		0:
			_change_state(State.ATTACK_1)
			state_timer = 0.25
			_last_attack = 1
		1:
			_change_state(State.ATTACK_2)
			state_timer = 0.25
			_last_attack = 2
		2:
			_change_state(State.ATTACK_3)
			state_timer = attack3_recovery + 0.15
			_last_attack = 0

	emit_signal("debug_log", "ATTACK %d (dmg:%d stm:%.0f)" % [stage + 1, attack_damage[stage], attack_stamina[stage]])

func _enter_roll() -> void:
	_consume_stamina(roll_stamina)
	if absf(move_axis) > 0.05:
		facing_dir = Vector2(signf(move_axis), 0.0)
	_change_state(State.ROLL)
	state_timer = roll_iframes + roll_recovery
	iframes_timer = roll_iframes
	emit_signal("debug_log", "ROLL (iframes %.2fs)" % roll_iframes)

func _enter_estus() -> void:
	_consume_stamina(estus_stamina)
	estus_charges -= 1
	var heal_amount := mini(estus_heal, max_hp - hp)
	hp += heal_amount
	_change_state(State.ESTUS)
	state_timer = 0.6
	emit_signal("debug_log", "ESTUS +%d HP (left:%d)" % [heal_amount, estus_charges])
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("estus_changed", estus_charges, estus_max_charges)

func _enter_skill1() -> void:
	_consume_stamina(18.0)
	_change_state(State.SKILL_1)
	state_timer = 0.35
	skill1_cd = 6.0
	emit_signal("debug_log", "SKILL1: thrust (dmg:%d CT:6s)" % skill1_damage)

func _enter_skill2() -> void:
	_consume_stamina(18.0)
	_change_state(State.SKILL_2)
	state_timer = 0.40
	skill2_cd = 9.0
	emit_signal("debug_log", "SKILL2: spin slash (dmg:%d CT:9s)" % skill2_damage)

func take_damage(amount: int, _poise_damage: int = 0, source: Node = null) -> void:
	if iframes_timer > 0:
		return

	if current_state == State.PARRY and parry_active_timer > 0:
		emit_signal("debug_log", "PARRY SUCCESS")
		if source and source.has_method("take_damage") and source.is_in_group("enemies"):
			var src2d: Node2D = source as Node2D
			var dir_x := signf(src2d.global_position.x - global_position.x)
			if dir_x == 0.0:
				dir_x = facing_dir.x
			var kb := Vector2(dir_x, -0.2).normalized()
			source.take_damage(0, 45, kb)
		_change_state(State.IDLE)
	elif current_state == State.GUARD:
		var reduced := int(amount * (1.0 - guard_reduction))
		hp -= reduced
		stamina -= guard_stamina_per_hit * guard_stamina_multiplier
		stamina_delay_timer = stamina_delay
		emit_signal("debug_log", "GUARD HIT -%d HP" % reduced)
		if stamina <= 0:
			stamina = 0
			_change_state(State.STAGGER)
			state_timer = guard_break_stagger
			emit_signal("debug_log", "GUARD BREAK")
	else:
		hp -= amount
		iframes_timer = iframes_duration
		emit_signal("debug_log", "HIT -%d HP" % amount)

	hp = maxi(hp, 0)
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("stamina_changed", stamina, max_stamina)

func _check_attack_hits() -> void:
	var atk_range := 0.0
	var dmg := 0
	var poise_dmg := 0
	var vertical_tolerance := 56.0

	match current_state:
		State.ATTACK_1:
			atk_range = 56.0; dmg = attack_damage[0]; poise_dmg = attack_poise[0]
		State.ATTACK_2:
			atk_range = 60.0; dmg = attack_damage[1]; poise_dmg = attack_poise[1]
		State.ATTACK_3:
			atk_range = 68.0; dmg = attack_damage[2]; poise_dmg = attack_poise[2]
		State.SKILL_1:
			atk_range = 82.0; dmg = skill1_damage; poise_dmg = skill1_poise_damage
		State.SKILL_2:
			atk_range = 76.0; dmg = skill2_damage; poise_dmg = skill2_poise_damage; vertical_tolerance = 84.0
		_:
			return

	var scaled_dmg := _scale_damage(dmg)
	var forward := facing_dir.x
	if forward == 0.0:
		forward = 1.0

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D
		if not enemy or enemy.get_instance_id() in attack_hit_ids:
			continue

		var dx := enemy.global_position.x - global_position.x
		var dy := absf(enemy.global_position.y - global_position.y)
		if absf(dx) > atk_range or dy > vertical_tolerance:
			continue

		if current_state != State.SKILL_2:
			if signf(dx) != signf(forward) and absf(dx) > 8.0:
				continue

		attack_hit_ids.append(enemy.get_instance_id())
		var kb_dir := Vector2(signf(dx), -0.12)
		if kb_dir.x == 0.0:
			kb_dir.x = signf(forward)
		enemy.take_damage(scaled_dmg, poise_dmg, kb_dir.normalized())
		_trigger_hitstop()
		emit_signal("debug_log", "HIT enemy -%d HP" % scaled_dmg)

func _trigger_hitstop() -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(0.06, true, false, true).timeout.connect(_end_hitstop)

func _end_hitstop() -> void:
	Engine.time_scale = 1.0

func _scale_damage(base_damage: int) -> int:
	return maxi(1, int(round(float(base_damage) * _current_damage_multiplier())))

func _current_damage_multiplier() -> float:
	var mult := bonus_damage_multiplier
	if max_hp > 0 and float(hp) / float(max_hp) <= low_hp_damage_threshold:
		mult *= low_hp_damage_multiplier
	return mult

func _clear_enemy_projectiles(radius: float) -> int:
	var removed := 0
	for node in get_tree().get_nodes_in_group("enemy_projectiles"):
		var projectile := node as Node2D
		if not projectile:
			continue
		if projectile.global_position.distance_to(global_position) <= radius:
			projectile.queue_free()
			removed += 1
	return removed

func apply_reward(reward: Dictionary) -> void:
	var reward_id: String = str(reward.get("id", ""))
	match reward_id:
		"strong_guard_unlock":
			guard_reduction = 0.65
			guard_stamina_multiplier = minf(guard_stamina_multiplier, 0.65)
			emit_signal("debug_log", "REWARD: 強ガード解放")
		"bullet_sweep_guard":
			bullet_clear_on_guard = true
			emit_signal("debug_log", "REWARD: 弾消しガード")
		"roll_iframe_plus":
			roll_iframes += 0.05
			emit_signal("debug_log", "REWARD: 回避無敵 +0.05s")
		"roll_cost_down":
			roll_stamina = maxf(8.0, roll_stamina * 0.85)
			emit_signal("debug_log", "REWARD: ロール消費 -15%")
		"low_hp_fury":
			low_hp_damage_multiplier = maxf(low_hp_damage_multiplier, 1.35)
			emit_signal("debug_log", "REWARD: 低HP火力 +35%")
		"poise_breaker":
			attack_poise[0] += 2
			attack_poise[1] += 2
			attack_poise[2] += 4
			skill1_poise_damage += 4
			skill2_poise_damage += 3
			emit_signal("debug_log", "REWARD: 体幹削り強化")
		"focus_parry":
			parry_window += 0.03
			parry_stamina = maxf(12.0, parry_stamina * 0.85)
			emit_signal("debug_log", "REWARD: パリィ窓 +0.03s")
		"thrust_amp":
			skill1_damage += 8
			bonus_damage_multiplier *= 1.05
			emit_signal("debug_log", "REWARD: 突き強化")
		"stamina_flow":
			stamina_regen += 5.0
			emit_signal("debug_log", "REWARD: スタミナ回復 +5/s")
		_:
			emit_signal("debug_log", "REWARD: %s" % reward.get("name", reward_id))

func _can_use_stamina(cost: float) -> bool:
	return stamina >= cost

func _consume_stamina(cost: float) -> void:
	stamina -= cost
	stamina = maxf(stamina, 0.0)
	stamina_delay_timer = stamina_delay
	emit_signal("stamina_changed", stamina, max_stamina)

func _change_state(new_state: State) -> void:
	if new_state in [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3, State.SKILL_1, State.SKILL_2]:
		attack_hit_ids.clear()
	current_state = new_state

func _can_jump() -> bool:
	return is_on_floor() and current_state in [State.IDLE, State.MOVE, State.GUARD]

func _is_locked() -> bool:
	return current_state in [
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3,
		State.ROLL, State.PARRY, State.PARRY_FAIL,
		State.ESTUS, State.STAGGER, State.SKILL_1, State.SKILL_2
	]

func _update_visuals() -> void:
	queue_redraw()

func _draw() -> void:
	var body_color := Color(0.85, 0.9, 1.0)
	match current_state:
		State.ROLL:
			body_color = Color(0.45, 0.8, 1.0, 0.7)
		State.GUARD:
			body_color = Color(0.45, 1.0, 0.45)
		State.PARRY:
			body_color = Color(1.0, 0.98, 0.35)
		State.PARRY_FAIL:
			body_color = Color(1.0, 0.45, 0.2)
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			body_color = Color(1.0, 0.72, 0.28)
		State.ESTUS:
			body_color = Color(0.26, 1.0, 0.62)
		State.STAGGER:
			body_color = Color(1.0, 0.2, 0.2)
		State.SKILL_1, State.SKILL_2:
			body_color = Color(0.76, 0.48, 1.0)

	var facing := 1.0 if facing_dir.x >= 0.0 else -1.0
	var step := 0.0
	if current_state == State.MOVE and is_on_floor():
		step = sin(float(Time.get_ticks_msec()) * 0.018) * 4.0

	draw_circle(Vector2(0, 20), 12.0, Color(0.0, 0.0, 0.0, 0.2))

	var hip := Vector2(0, 8)
	var left_foot := Vector2(-7.0 + step, 26.0)
	var right_foot := Vector2(7.0 - step, 26.0)
	draw_line(hip, left_foot, body_color.darkened(0.2), 3.0)
	draw_line(hip, right_foot, body_color.darkened(0.05), 3.0)

	draw_rect(Rect2(-8.0, -20.0, 16.0, 28.0), body_color)
	draw_circle(Vector2(0, -30), 9.0, body_color)
	draw_circle(Vector2(3.0 * facing, -31), 1.2, Color(0.08, 0.08, 0.1))

	var shoulder := Vector2(0, -12)
	var lead_arm := Vector2(12.0 * facing, -8.0 + step * 0.3)
	var rear_arm := Vector2(-9.0 * facing, -10.0 - step * 0.2)
	draw_line(shoulder, lead_arm, body_color.darkened(0.1), 3.0)
	draw_line(shoulder, rear_arm, body_color.darkened(0.25), 3.0)

	if current_state in [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3]:
		var slash_pos := Vector2(24.0 * facing, -10.0)
		var start_angle := -PI * 0.35 if facing > 0.0 else PI * 0.65
		draw_arc(slash_pos, 20.0, start_angle, start_angle + PI * 0.7, 16, Color(1, 1, 1, 0.6), 2.5)

	if current_state == State.GUARD:
		var shield_rect := Rect2(12.0 * facing - (14.0 if facing < 0.0 else 0.0), -18.0, 14.0, 24.0)
		draw_rect(shield_rect, Color(0.35, 0.9, 0.45, 0.8))
