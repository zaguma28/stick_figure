extends CharacterBody2D
const HIT_SPARK_FX_SCRIPT := preload("res://scenes/effects/hit_spark_fx.gd")
@onready var camera: Camera2D = $Camera2D
const SWING_SE_MIX_RATE := 44100
const IMPACT_SE_MIX_RATE := 44100

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
@export var ground_accel: float = 4200.0
@export var ground_brake: float = 6200.0
@export var air_accel: float = 1450.0
@export var air_brake: float = 1180.0
@export var turn_accel_multiplier: float = 1.8
@export var iframes_duration: float = 0.35
@export var gravity: float = 1800.0
@export var jump_velocity: float = -700.0
@export var max_fall_speed: float = 1400.0
@export var air_control: float = 0.72
@export var ground_decel: float = 1650.0
@export var apex_hang_gravity_scale: float = 0.58
@export var apex_hang_velocity_band: float = 140.0
@export var apex_hang_move_boost: float = 1.1
@export var jump_buffer_time: float = 0.12
@export var coyote_time: float = 0.1
@export var jump_cut_velocity_multiplier: float = 0.5
@export var wall_slide_fall_speed: float = 270.0
@export var wall_slide_gravity_scale: float = 0.42
@export var wall_jump_x_speed: float = 300.0
@export var wall_jump_y_speed: float = -660.0
@export var wall_jump_lock_time: float = 0.1
@export var fast_fall_gravity_scale: float = 1.55
@export var fast_fall_max_speed: float = 1760.0
@export var max_air_rolls: int = 1
@export var silhouette_scale: float = 1.14
@export var show_combat_trails: bool = true
@export var stylish_afterimages: bool = true
@export var stylish_afterimage_interval: float = 0.03
@export var stylish_afterimage_lifetime: float = 0.14
@export var stylish_ring_boost: float = 1.0

var attack_damage = [12, 16, 24]
var attack_stamina = [20.0, 24.0, 32.0]
var attack_poise = [10, 14, 20]
var attack3_recovery = 0.46
var skill1_damage: int = 42
var skill2_damage: int = 24
var skill1_poise_damage: int = 18
var skill2_poise_damage: int = 12

@export var roll_stamina: float = 28.0
@export var roll_iframes: float = 0.24
@export var roll_recovery: float = 0.14
@export var roll_distance: float = 168.0
@export var in_place_dodge_iframes: float = 0.16
@export var in_place_dodge_recovery: float = 0.16

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
var virtual_move_axis: float = 0.0
var facing_dir = Vector2.RIGHT

var stamina_delay_timer: float = 0.0
var state_timer: float = 0.0
var iframes_timer: float = 0.0
var parry_active_timer: float = 0.0
var combo_window_timer: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_jump_lock_timer: float = 0.0
var remaining_air_rolls: int = 1
var wall_slide_active: bool = false
var wall_slide_side: float = 0.0
var queued_attack: bool = false
var attack_elapsed: float = 0.0
var attack_duration_current: float = 0.0
var attack_stage_current: int = 0
var swing_fx_timer: float = 0.0
var swing_fx_duration: float = 0.0
var swing_fx_stage: int = 0
var swing_fx_heavy: bool = false
var slash_chain_spawn_timer: float = 0.0
var slash_chain_phase: int = 0
var slash_chain_trails: Array[Dictionary] = []
var roll_dir_x: float = 1.0
var roll_start_speed: float = 0.0
var roll_stationary: bool = false
var style_afterimage_timer: float = 0.0
var style_afterimages: Array[Dictionary] = []
var style_ring_timer: float = 0.0
var style_ring_duration: float = 0.0
var style_ring_radius: float = 0.0
var style_ring_color: Color = Color(1.0, 0.95, 0.8, 0.0)
var dodge_success_timer: float = 0.0
var dodge_success_duration: float = 0.18
var parry_success_timer: float = 0.0
var parry_success_duration: float = 0.28
var defense_feedback_cooldown: float = 0.0
var camera_shake_timer: float = 0.0
var camera_shake_duration: float = 0.0
var camera_shake_strength: float = 0.0

var skill1_cd: float = 0.0
var skill2_cd: float = 0.0

var attack_hit_ids: Array = []
var _last_attack: int = 0
var bonus_damage_multiplier: float = 1.0
var low_hp_damage_multiplier: float = 1.0
var low_hp_damage_threshold: float = 0.35
var guard_stamina_multiplier: float = 1.0
var bullet_clear_on_guard: bool = false
var hitstop_enabled: bool = true
var combat_fx_enabled: bool = true

signal debug_log(msg: String)
signal hp_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal estus_changed(current: int, maximum: int)
signal impact_fx_requested(strength: float, duration: float, tint: Color)

func _ready() -> void:
	reset_for_new_run()

func reset_for_new_run() -> void:
	max_hp = 100
	max_stamina = 100.0
	stamina_regen = 22.0
	stamina_delay = 0.25
	move_speed = 276.0
	ground_accel = 4200.0
	ground_brake = 6200.0
	air_accel = 1450.0
	air_brake = 1180.0
	turn_accel_multiplier = 1.8
	iframes_duration = 0.35
	jump_buffer_time = 0.12
	coyote_time = 0.1
	jump_cut_velocity_multiplier = 0.5
	apex_hang_gravity_scale = 0.58
	apex_hang_velocity_band = 140.0
	apex_hang_move_boost = 1.1
	wall_slide_fall_speed = 270.0
	wall_slide_gravity_scale = 0.42
	wall_jump_x_speed = 300.0
	wall_jump_y_speed = -660.0
	wall_jump_lock_time = 0.1
	fast_fall_gravity_scale = 1.55
	fast_fall_max_speed = 1760.0
	max_air_rolls = 1
	silhouette_scale = 1.14
	show_combat_trails = true
	stylish_afterimages = true
	stylish_afterimage_interval = 0.03
	stylish_afterimage_lifetime = 0.14
	stylish_ring_boost = 1.0
	roll_stamina = 28.0
	roll_iframes = 0.24
	roll_recovery = 0.14
	roll_distance = 168.0
	in_place_dodge_iframes = 0.16
	in_place_dodge_recovery = 0.16
	parry_stamina = 24.0
	parry_window = 0.18
	parry_fail_stagger = 0.35
	estus_stamina = 16.0
	estus_heal = 35
	estus_max_charges = 3
	guard_reduction = 0.30
	guard_stamina_per_hit = 22.0
	guard_break_stagger = 0.6
	attack_damage = [12, 16, 24]
	attack_stamina = [20.0, 24.0, 32.0]
	attack_poise = [10, 14, 20]
	attack3_recovery = 0.46
	skill1_damage = 42
	skill2_damage = 24
	skill1_poise_damage = 18
	skill2_poise_damage = 12
	bonus_damage_multiplier = 1.0
	low_hp_damage_multiplier = 1.0
	low_hp_damage_threshold = 0.35
	guard_stamina_multiplier = 1.0
	bullet_clear_on_guard = false
	hp = max_hp
	stamina = max_stamina
	estus_charges = estus_max_charges
	current_state = State.IDLE
	move_axis = 0.0
	virtual_move_axis = 0.0
	facing_dir = Vector2.RIGHT
	velocity = Vector2.ZERO
	stamina_delay_timer = 0.0
	state_timer = 0.0
	iframes_timer = 0.0
	parry_active_timer = 0.0
	combo_window_timer = 0.0
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	wall_jump_lock_timer = 0.0
	remaining_air_rolls = max_air_rolls
	wall_slide_active = false
	wall_slide_side = 0.0
	queued_attack = false
	attack_elapsed = 0.0
	attack_duration_current = 0.0
	attack_stage_current = 0
	swing_fx_timer = 0.0
	swing_fx_duration = 0.0
	swing_fx_stage = 0
	swing_fx_heavy = false
	slash_chain_spawn_timer = 0.0
	slash_chain_phase = 0
	slash_chain_trails.clear()
	roll_dir_x = 1.0
	roll_start_speed = 0.0
	roll_stationary = false
	style_afterimage_timer = 0.0
	style_afterimages.clear()
	style_ring_timer = 0.0
	style_ring_duration = 0.0
	style_ring_radius = 0.0
	style_ring_color = Color(1.0, 0.95, 0.8, 0.0)
	dodge_success_timer = 0.0
	dodge_success_duration = 0.18
	parry_success_timer = 0.0
	parry_success_duration = 0.28
	defense_feedback_cooldown = 0.0
	camera_shake_timer = 0.0
	camera_shake_duration = 0.0
	camera_shake_strength = 0.0
	skill1_cd = 0.0
	skill2_cd = 0.0
	attack_hit_ids.clear()
	_last_attack = 0
	if camera:
		camera.offset = Vector2.ZERO
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
	if is_on_floor():
		coyote_timer = coyote_time
		remaining_air_rolls = max_air_rolls
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
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
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if wall_jump_lock_timer > 0:
		wall_jump_lock_timer -= delta
	if swing_fx_timer > 0:
		swing_fx_timer = maxf(0.0, swing_fx_timer - delta)
	_update_slash_chain(delta)
	_update_style_afterimages(delta)
	if style_ring_timer > 0.0:
		style_ring_timer = maxf(0.0, style_ring_timer - delta)
	if dodge_success_timer > 0.0:
		dodge_success_timer = maxf(0.0, dodge_success_timer - delta)
	if parry_success_timer > 0.0:
		parry_success_timer = maxf(0.0, parry_success_timer - delta)
	if defense_feedback_cooldown > 0.0:
		defense_feedback_cooldown = maxf(0.0, defense_feedback_cooldown - delta)
	if skill1_cd > 0:
		skill1_cd -= delta
	if skill2_cd > 0:
		skill2_cd -= delta
	_update_camera_shake(delta)

func _input_hub() -> Node:
	return get_node_or_null("/root/InputHub")

func _input_axis(negative_action: String, positive_action: String) -> float:
	var hub = _input_hub()
	if hub and hub.has_method("get_axis"):
		return float(hub.get_axis(negative_action, positive_action))
	return Input.get_axis(negative_action, positive_action)

func _action_pressed(action: String) -> bool:
	var hub = _input_hub()
	if hub and hub.has_method("is_action_pressed"):
		return bool(hub.is_action_pressed(action))
	return Input.is_action_pressed(action)

func _action_just_pressed(action: String) -> bool:
	var hub = _input_hub()
	if hub and hub.has_method("is_action_just_pressed"):
		return bool(hub.is_action_just_pressed(action))
	return Input.is_action_just_pressed(action)

func _action_just_released(action: String) -> bool:
	var hub = _input_hub()
	if hub and hub.has_method("is_action_just_released"):
		return bool(hub.is_action_just_released(action))
	return Input.is_action_just_released(action)

func _handle_input() -> void:
	var keyboard_axis = _input_axis("move_left", "move_right")
	move_axis = keyboard_axis
	if absf(virtual_move_axis) > absf(move_axis):
		move_axis = virtual_move_axis
	if wall_jump_lock_timer > 0 and not is_on_floor():
		move_axis = 0.0
	if absf(move_axis) > 0.05 and not _is_attack_state(current_state):
		facing_dir = Vector2(signf(move_axis), 0.0)

	if _action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	if _action_just_released("jump"):
		_apply_jump_cut()

	if jump_buffer_timer > 0.0:
		if _can_ground_jump():
			_perform_ground_jump()
		elif _can_wall_jump():
			_perform_wall_jump()

	if _action_just_pressed("attack") and _is_attack_state(current_state):
		queued_attack = true

	if _is_locked():
		return

	if _action_just_pressed("guard"):
		if _can_use_stamina(parry_stamina):
			_enter_parry()
			return

	if _action_pressed("guard"):
		if current_state != State.GUARD:
			_enter_guard()
		return

	if _action_just_released("guard"):
		if current_state == State.GUARD:
			_change_state(State.IDLE)
			return

	if _action_just_pressed("attack"):
		_try_attack()
		return

	if _action_just_pressed("roll"):
		if _can_use_stamina(roll_stamina):
			_enter_roll()
			return

	if _action_just_pressed("estus"):
		if estus_charges > 0 and _can_use_stamina(estus_stamina):
			_enter_estus()
			return

	if _action_just_pressed("skill_1"):
		if skill1_cd <= 0 and _can_use_stamina(18.0):
			_enter_skill1()
			return

	if _action_just_pressed("skill_2"):
		if skill2_cd <= 0 and _can_use_stamina(18.0):
			_enter_skill2()
			return

	if current_state in [State.IDLE, State.MOVE]:
		if absf(move_axis) > 0.05:
			if current_state != State.MOVE:
				_change_state(State.MOVE)
		elif is_on_floor() and current_state == State.MOVE:
			_change_state(State.IDLE)

func _process_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			_apply_horizontal_control(delta, 0.0)
			if not is_on_floor() and absf(move_axis) > 0.05:
				_change_state(State.MOVE)

		State.MOVE:
			_apply_horizontal_control(delta, move_axis * move_speed)
			if absf(move_axis) <= 0.05 and is_on_floor():
				_change_state(State.IDLE)

		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			_update_attack_motion(delta)
			if state_timer <= 0:
				if current_state != State.ATTACK_3:
					combo_window_timer = 0.3
				var had_queue = queued_attack
				queued_attack = false
				_change_state(State.IDLE)
				if had_queue:
					_try_attack()

		State.ROLL:
			if state_timer > 0:
				_process_roll_motion(delta)
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

	if current_state in [State.IDLE, State.MOVE, State.GUARD]:
		_update_wall_slide_state()
	else:
		wall_slide_active = false
		wall_slide_side = 0.0

func _apply_horizontal_control(delta: float, target_speed: float) -> void:
	if is_on_floor():
		if absf(target_speed) <= 0.05:
			velocity.x = move_toward(velocity.x, 0.0, ground_brake * 1.35 * delta)
			if absf(velocity.x) < 7.0:
				velocity.x = 0.0
			return
		var floor_accel = ground_accel
		if absf(velocity.x) > 0.1 and signf(target_speed) != signf(velocity.x):
			floor_accel *= turn_accel_multiplier
		velocity.x = move_toward(velocity.x, target_speed, floor_accel * delta)
		if absf(target_speed - velocity.x) < 5.0:
			velocity.x = target_speed
		return

	var accel = air_accel
	var brake = air_brake
	accel *= air_control
	brake *= air_control

	var same_dir = absf(target_speed) > 0.05 and signf(target_speed) == signf(velocity.x)
	var rate = accel
	if absf(target_speed) <= absf(velocity.x) and same_dir:
		rate = brake
	if absf(target_speed) > 0.05 and absf(velocity.x) > 20.0 and signf(target_speed) != signf(velocity.x):
		rate *= turn_accel_multiplier
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)

func _update_attack_motion(delta: float) -> void:
	if attack_duration_current <= 0.001:
		attack_duration_current = maxf(0.001, state_timer + delta)
	attack_elapsed += delta
	var progress = _attack_progress()
	if not queued_attack and _action_pressed("attack"):
		var queue_open: float = 0.26
		if current_state == State.ATTACK_3:
			queue_open = 0.3
		if progress >= queue_open and state_timer > 0.06:
			queued_attack = true
	if is_on_floor():
		velocity.x = 0.0
	else:
		var air_damp = air_brake * 2.4
		velocity.x = move_toward(velocity.x, 0.0, air_damp * delta)

func _process_roll_motion(delta: float) -> void:
	if roll_stationary:
		var damp = ground_brake * 3.4 if is_on_floor() else air_brake * 2.5
		velocity.x = move_toward(velocity.x, 0.0, damp * delta)
		return
	var total = maxf(0.001, roll_iframes + roll_recovery)
	var p = 1.0 - clampf(state_timer / total, 0.0, 1.0)
	var curve = 1.0 - pow(p, 1.35)
	if p > 0.72:
		curve *= clampf((1.0 - p) / 0.28, 0.0, 1.0)
	var desired_speed = roll_dir_x * roll_start_speed * (0.75 + 0.38 * curve)
	if p > 0.84:
		desired_speed *= 0.42
	var accel = ground_accel * 3.2 if is_on_floor() else air_accel * 2.0
	velocity.x = move_toward(velocity.x, desired_speed, accel * delta)
	if is_on_wall():
		velocity.x = 0.0

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		return

	if wall_slide_active:
		var wall_gravity = gravity * wall_slide_gravity_scale
		velocity.y = minf(velocity.y + wall_gravity * delta, wall_slide_fall_speed)
		return

	var gravity_scale = 1.0
	var fall_limit = max_fall_speed
	var fast_fall = velocity.y > 0.0 and _action_pressed("move_down")
	if fast_fall:
		gravity_scale = fast_fall_gravity_scale
		fall_limit = fast_fall_max_speed
	elif absf(velocity.y) <= apex_hang_velocity_band and _action_pressed("jump"):
		gravity_scale *= apex_hang_gravity_scale
		if absf(move_axis) > 0.08:
			var apex_speed = move_axis * move_speed * apex_hang_move_boost
			velocity.x = move_toward(velocity.x, apex_speed, air_accel * air_control * delta)
	velocity.y = minf(velocity.y + gravity * gravity_scale * delta, fall_limit)

func _update_wall_slide_state() -> void:
	wall_slide_active = false
	wall_slide_side = 0.0
	if is_on_floor() or velocity.y <= 0.0:
		return
	if not is_on_wall():
		return
	var wall_normal: Vector2 = get_wall_normal()
	if absf(wall_normal.x) < 0.2:
		return
	var toward_wall = false
	if absf(move_axis) > 0.1:
		toward_wall = signf(move_axis) == -signf(wall_normal.x)
	if not toward_wall and absf(move_axis) <= 0.05:
		toward_wall = true
	if toward_wall:
		wall_slide_active = true
		wall_slide_side = -signf(wall_normal.x)

func _can_ground_jump() -> bool:
	return coyote_timer > 0.0 and current_state in [State.IDLE, State.MOVE, State.GUARD]

func _can_wall_jump() -> bool:
	if is_on_floor():
		return false
	if current_state not in [State.IDLE, State.MOVE, State.GUARD]:
		return false
	if not is_on_wall():
		return false
	var wall_normal: Vector2 = get_wall_normal()
	return absf(wall_normal.x) > 0.2

func _perform_ground_jump() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	wall_slide_active = false
	wall_slide_side = 0.0
	velocity.y = jump_velocity
	emit_signal("debug_log", "JUMP")

func _perform_wall_jump() -> void:
	var wall_normal: Vector2 = get_wall_normal()
	var jump_dir_x = wall_normal.x
	if absf(jump_dir_x) < 0.2:
		jump_dir_x = -signf(facing_dir.x)
		if jump_dir_x == 0.0:
			jump_dir_x = 1.0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	wall_slide_active = false
	wall_slide_side = 0.0
	wall_jump_lock_timer = wall_jump_lock_time
	velocity.x = jump_dir_x * wall_jump_x_speed
	velocity.y = wall_jump_y_speed
	facing_dir = Vector2(signf(jump_dir_x), 0.0)
	_change_state(State.MOVE)
	emit_signal("debug_log", "WALL JUMP")

func _apply_jump_cut() -> void:
	if velocity.y < -80.0:
		velocity.y *= jump_cut_velocity_multiplier

func _enter_parry() -> void:
	_consume_stamina(parry_stamina)
	_change_state(State.PARRY)
	parry_active_timer = parry_window
	state_timer = parry_window + 0.1
	emit_signal("debug_log", "PARRY (window %.2fs)" % parry_window)

func _enter_guard() -> void:
	_change_state(State.GUARD)
	velocity.x = 0.0
	emit_signal("debug_log", "GUARD (%d%% reduction)" % int(guard_reduction * 100))
	if bullet_clear_on_guard:
		var removed = _clear_enemy_projectiles(220.0)
		if removed > 0:
			emit_signal("debug_log", "GUARD WAVE: 弾消し x%d" % removed)

func _try_attack() -> void:
	queued_attack = false
	var stage = 0
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
			state_timer = 0.36
			_last_attack = 1
			_begin_attack_profile(1, state_timer, false)
		1:
			_change_state(State.ATTACK_2)
			state_timer = 0.42
			_last_attack = 2
			_begin_attack_profile(2, state_timer, false)
		2:
			_change_state(State.ATTACK_3)
			state_timer = attack3_recovery + 0.22
			_last_attack = 0
			_begin_attack_profile(3, state_timer, true)
	var stage_strength = float(stage + 1)
	_trigger_camera_shake(1.0 + 0.4 * stage_strength, 0.04 + 0.01 * stage_strength)
	_trigger_style_ring(_attack_style_color(int(current_state), 0.92), 10.0 + 2.2 * stage_strength, 0.12 + 0.02 * stage_strength)

	emit_signal("debug_log", "ATTACK %d (dmg:%d stm:%.0f)" % [stage + 1, attack_damage[stage], attack_stamina[stage]])

func _enter_roll(force_directional: bool = false) -> void:
	var airborne = not is_on_floor()
	if airborne and remaining_air_rolls <= 0:
		emit_signal("debug_log", "ROLL LIMIT")
		return
	var input_dir: float = 0.0
	if absf(move_axis) > 0.22:
		input_dir = signf(move_axis)
	elif force_directional:
		input_dir = 1.0 if facing_dir.x >= 0.0 else -1.0
	_consume_stamina(roll_stamina)
	roll_stationary = absf(input_dir) <= 0.01
	if not roll_stationary:
		facing_dir = Vector2(input_dir, 0.0)
	if airborne:
		remaining_air_rolls -= 1
	wall_slide_active = false
	wall_slide_side = 0.0
	_change_state(State.ROLL)
	roll_dir_x = facing_dir.x
	if roll_dir_x == 0.0:
		roll_dir_x = 1.0
	if roll_stationary:
		roll_start_speed = 0.0
		velocity.x = 0.0
		state_timer = in_place_dodge_iframes + in_place_dodge_recovery
		iframes_timer = in_place_dodge_iframes
		emit_signal(
			"debug_log",
			"DODGE IN PLACE (iframes %.2fs)" % in_place_dodge_iframes
		)
		return
	var roll_total = maxf(0.001, roll_iframes + roll_recovery)
	roll_start_speed = roll_distance / roll_total
	velocity.x = roll_dir_x * roll_start_speed
	state_timer = roll_iframes + roll_recovery
	iframes_timer = roll_iframes
	emit_signal("debug_log", "ROLL (iframes %.2fs dist %.0f)" % [roll_iframes, roll_distance])

func _enter_estus() -> void:
	_consume_stamina(estus_stamina)
	estus_charges -= 1
	var heal_amount = mini(estus_heal, max_hp - hp)
	hp += heal_amount
	_change_state(State.ESTUS)
	state_timer = 0.6
	emit_signal("debug_log", "ESTUS +%d HP (left:%d)" % [heal_amount, estus_charges])
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("estus_changed", estus_charges, estus_max_charges)

func _enter_skill1() -> void:
	_consume_stamina(18.0)
	_change_state(State.SKILL_1)
	state_timer = 0.52
	_begin_attack_profile(4, state_timer, true)
	_trigger_style_ring(_attack_style_color(int(State.SKILL_1), 0.95), 17.0, 0.2)
	_trigger_camera_shake(1.9, 0.08)
	skill1_cd = 6.0
	emit_signal("debug_log", "SKILL1: thrust (dmg:%d CT:6s)" % skill1_damage)

func _enter_skill2() -> void:
	_consume_stamina(18.0)
	_change_state(State.SKILL_2)
	state_timer = 0.62
	_begin_attack_profile(5, state_timer, true)
	_trigger_style_ring(_attack_style_color(int(State.SKILL_2), 0.95), 20.0, 0.24)
	_trigger_camera_shake(2.1, 0.1)
	skill2_cd = 9.0
	emit_signal("debug_log", "SKILL2: spin slash (dmg:%d CT:9s)" % skill2_damage)

func take_damage(amount: int, _poise_damage: int = 0, source: Node = null) -> void:
	if iframes_timer > 0:
		if current_state == State.ROLL:
			_on_dodge_success(source)
		return

	if current_state == State.PARRY and parry_active_timer > 0:
		_on_parry_success(source)
		if source and source.has_method("take_damage") and source.is_in_group("enemies"):
			var src2d: Node2D = source as Node2D
			var dir_x = signf(src2d.global_position.x - global_position.x)
			if dir_x == 0.0:
				dir_x = facing_dir.x
			var kb = Vector2(dir_x, -0.2).normalized()
			source.take_damage(0, 45, kb)
		_change_state(State.IDLE)
	elif current_state == State.GUARD:
		var reduced = int(amount * (1.0 - guard_reduction))
		hp -= reduced
		stamina -= guard_stamina_per_hit * guard_stamina_multiplier
		stamina_delay_timer = stamina_delay
		_trigger_camera_shake(1.2, 0.05)
		emit_signal("impact_fx_requested", 0.22, 0.07, Color(0.52, 0.9, 1.0))
		emit_signal("debug_log", "GUARD HIT -%d HP" % reduced)
		if stamina <= 0:
			stamina = 0
			_change_state(State.STAGGER)
			state_timer = guard_break_stagger
			emit_signal("debug_log", "GUARD BREAK")
	else:
		hp -= amount
		iframes_timer = iframes_duration
		_trigger_camera_shake(2.3, 0.08)
		emit_signal("impact_fx_requested", 0.4, 0.1, Color(1.0, 0.35, 0.26))
		emit_signal("debug_log", "HIT -%d HP" % amount)

	hp = maxi(hp, 0)
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("stamina_changed", stamina, max_stamina)

func take_hazard_damage(amount: int, source: Node = null) -> void:
	if iframes_timer > 0:
		if current_state == State.ROLL:
			_on_dodge_success(source)
		return
	var previous_hp = hp
	hp = maxi(0, hp - amount)
	if hp < previous_hp:
		iframes_timer = maxf(iframes_timer, 0.08)
		emit_signal("impact_fx_requested", 0.32, 0.09, Color(1.0, 0.32, 0.26))
		var src_name = "HAZARD"
		if source:
			src_name = source.name
		emit_signal("debug_log", "%s -%d HP (ガード不可)" % [src_name, amount])
	emit_signal("hp_changed", hp, max_hp)

func _on_dodge_success(_source: Node = null) -> void:
	if defense_feedback_cooldown > 0.0:
		return
	defense_feedback_cooldown = 0.12
	dodge_success_timer = dodge_success_duration
	_trigger_camera_shake(1.1, 0.05)
	_trigger_style_ring(Color(0.56, 0.98, 1.0, 0.95), 12.0 if roll_stationary else 14.0, 0.14)
	emit_signal("impact_fx_requested", 0.16, 0.05, Color(0.56, 0.98, 1.0, 0.8))
	emit_signal("debug_log", "DODGE SUCCESS")
	if DisplayServer.get_name() != "headless":
		_play_defense_se(false)

func _on_parry_success(_source: Node = null) -> void:
	parry_success_timer = parry_success_duration
	_trigger_camera_shake(2.8, 0.09)
	_trigger_style_ring(Color(1.0, 0.92, 0.36, 0.96), 18.0, 0.22)
	emit_signal("impact_fx_requested", 0.26, 0.08, Color(1.0, 0.92, 0.36, 0.9))
	emit_signal("debug_log", "PARRY SUCCESS")
	_trigger_hitstop(true)
	if DisplayServer.get_name() != "headless":
		_play_defense_se(true)

func _check_attack_hits() -> void:
	var atk_range = 0.0
	var dmg = 0
	var poise_dmg = 0
	var vertical_tolerance = 56.0

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
	if not _is_attack_hit_window_active():
		return

	var scaled_dmg = _scale_damage(dmg)
	var forward = facing_dir.x
	if forward == 0.0:
		forward = 1.0

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D
		if not enemy or enemy.get_instance_id() in attack_hit_ids:
			continue

		var dx = enemy.global_position.x - global_position.x
		var dy = absf(enemy.global_position.y - global_position.y)
		if absf(dx) > atk_range or dy > vertical_tolerance:
			continue

		if current_state != State.SKILL_2:
			if signf(dx) != signf(forward) and absf(dx) > 8.0:
				continue

		attack_hit_ids.append(enemy.get_instance_id())
		var kb_dir = Vector2(signf(dx), 0.0)
		if kb_dir.x == 0.0:
			kb_dir.x = signf(forward)
		var heavy_hit = current_state in [State.ATTACK_3, State.SKILL_1, State.SKILL_2]
		enemy.take_damage(scaled_dmg, poise_dmg, kb_dir.normalized())
		_spawn_hit_spark(enemy.global_position, kb_dir.normalized(), heavy_hit)
		_trigger_hitstop(heavy_hit)
		_on_attack_hit_confirm(heavy_hit)
		emit_signal("debug_log", "HIT enemy -%d HP" % scaled_dmg)

func _trigger_hitstop(heavy: bool = false) -> void:
	if not hitstop_enabled:
		return
	var restore_scale = maxf(1.0, Engine.time_scale)
	var stage = clampi(attack_stage_current, 1, 5)
	var hitstop_scale = 0.028
	var hitstop_time = 0.09
	if stage >= 2:
		hitstop_scale = 0.024
		hitstop_time = 0.104
	if heavy:
		hitstop_scale = 0.012
		hitstop_time = 0.13
		if stage >= 4:
			hitstop_time = 0.145
	Engine.time_scale = minf(hitstop_scale, restore_scale)
	get_tree().create_timer(hitstop_time, true, false, true).timeout.connect(
		func() -> void:
			Engine.time_scale = restore_scale
	)

func set_hitstop_enabled(enabled: bool) -> void:
	hitstop_enabled = enabled

func set_combat_fx_enabled(enabled: bool) -> void:
	combat_fx_enabled = enabled

func _begin_attack_profile(stage: int, duration: float, heavy: bool) -> void:
	attack_stage_current = stage
	attack_duration_current = maxf(0.001, duration)
	attack_elapsed = 0.0
	slash_chain_spawn_timer = 0.0
	slash_chain_phase = 0
	_trigger_swing_fx(stage, heavy)
	if DisplayServer.get_name() != "headless":
		_play_swing_se(stage, heavy)

func _attack_progress() -> float:
	if attack_duration_current <= 0.001:
		return 1.0
	return clampf(attack_elapsed / attack_duration_current, 0.0, 1.0)

func _is_attack_hit_window_active() -> bool:
	var p = _attack_progress()
	match current_state:
		State.ATTACK_1:
			return p >= 0.34 and p <= 0.58
		State.ATTACK_2:
			return p >= 0.38 and p <= 0.64
		State.ATTACK_3:
			return p >= 0.42 and p <= 0.72
		State.SKILL_1:
			return p >= 0.34 and p <= 0.72
		State.SKILL_2:
			return p >= 0.3 and p <= 0.78
		_:
			return false

func _on_attack_hit_confirm(heavy_hit: bool) -> void:
	var recoil = 56.0
	if heavy_hit:
		recoil = 34.0
	velocity.x -= facing_dir.x * recoil
	if not is_on_floor() and _action_pressed("move_down"):
		velocity.y = minf(velocity.y, -280.0)
	_trigger_camera_shake(4.4 if heavy_hit else 3.0, 0.1 if heavy_hit else 0.08)
	var tint = Color(0.72, 0.94, 1.0)
	if heavy_hit:
		tint = Color(1.0, 0.78, 0.44)
	_trigger_style_ring(tint, 13.5 if heavy_hit else 11.0, 0.18 if heavy_hit else 0.14)
	emit_signal("impact_fx_requested", 0.107, 0.04, tint)
	if DisplayServer.get_name() != "headless":
		_play_impact_se(heavy_hit)

func _trigger_swing_fx(stage: int, heavy: bool) -> void:
	if not show_combat_trails:
		swing_fx_timer = 0.0
		swing_fx_duration = 0.0
		return
	swing_fx_stage = stage
	swing_fx_heavy = heavy
	swing_fx_duration = 0.31 if heavy else 0.22
	swing_fx_timer = swing_fx_duration

func _update_style_afterimages(delta: float) -> void:
	if not show_combat_trails or not stylish_afterimages:
		style_afterimages.clear()
		style_afterimage_timer = 0.0
		return
	var kept: Array[Dictionary] = []
	for image_variant in style_afterimages:
		var image: Dictionary = image_variant
		var remaining = float(image.get("time", 0.0)) - delta
		if remaining <= 0.0:
			continue
		image["time"] = remaining
		kept.append(image)
	style_afterimages = kept
	var in_stylish_state = current_state in [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3, State.SKILL_1, State.SKILL_2, State.ROLL]
	if not in_stylish_state:
		style_afterimage_timer = 0.0
		return
	style_afterimage_timer -= delta
	if style_afterimage_timer > 0.0:
		return
	_spawn_style_afterimage()
	var interval = clampf(stylish_afterimage_interval, 0.01, 0.08)
	if current_state in [State.ATTACK_3, State.SKILL_1, State.SKILL_2]:
		interval *= 0.78
	elif current_state == State.ROLL:
		interval *= 0.85
	style_afterimage_timer = interval

func _spawn_style_afterimage() -> void:
	var lifetime = clampf(stylish_afterimage_lifetime, 0.05, 0.28)
	if current_state in [State.ATTACK_3, State.SKILL_1, State.SKILL_2]:
		lifetime += 0.03
	var roll_total = maxf(
		0.001,
		(in_place_dodge_iframes + in_place_dodge_recovery) if roll_stationary else (roll_iframes + roll_recovery)
	)
	var roll_p = 0.0
	if current_state == State.ROLL:
		roll_p = 1.0 - clampf(state_timer / roll_total, 0.0, 1.0)
	style_afterimages.append(
		{
			"global_pos": global_position,
			"facing": 1.0 if facing_dir.x >= 0.0 else -1.0,
			"state": int(current_state),
			"attack_p": _attack_progress() if _is_attack_state(current_state) else 0.0,
			"roll_p": roll_p,
			"roll_stationary": roll_stationary,
			"time": lifetime,
			"max_time": lifetime
		}
	)
	if style_afterimages.size() > 24:
		style_afterimages.remove_at(0)

func _trigger_style_ring(color: Color, radius: float, duration: float) -> void:
	style_ring_color = color
	style_ring_radius = radius
	style_ring_duration = duration
	style_ring_timer = duration

func _attack_style_color(state_id: int, alpha: float) -> Color:
	match state_id:
		int(State.ATTACK_1):
			return Color(0.58, 0.94, 1.0, alpha)
		int(State.ATTACK_2):
			return Color(0.82, 0.66, 1.0, alpha)
		int(State.ATTACK_3):
			return Color(1.0, 0.72, 0.4, alpha)
		int(State.SKILL_1):
			return Color(1.0, 0.54, 0.28, alpha)
		int(State.SKILL_2):
			return Color(0.68, 0.9, 1.0, alpha)
		_:
			return Color(0.86, 0.92, 1.0, alpha)

func _draw_style_afterimages() -> void:
	if style_afterimages.is_empty():
		return
	for image_variant in style_afterimages:
		var image: Dictionary = image_variant
		var max_time = maxf(0.001, float(image.get("max_time", 0.1)))
		var fade = clampf(float(image.get("time", 0.0)) / max_time, 0.0, 1.0)
		var snapshot_pos: Vector2 = global_position
		var snapshot_variant = image.get("global_pos", global_position)
		if snapshot_variant is Vector2:
			snapshot_pos = snapshot_variant
		var center = to_local(snapshot_pos)
		var facing = float(image.get("facing", 1.0))
		var state_id = int(image.get("state", int(State.IDLE)))
		var attack_p = float(image.get("attack_p", 0.0))
		var roll_p = float(image.get("roll_p", 0.0))
		var image_roll_stationary = bool(image.get("roll_stationary", false))
		var color = _attack_style_color(state_id, 0.26 * fade)
		var head = center + Vector2(0.5 * facing, -13.0)
		var neck = center + Vector2(0.2 * facing, -7.1)
		var pelvis = center + Vector2(-0.25 * facing, 1.9)
		if state_id in [int(State.ATTACK_1), int(State.ATTACK_2), int(State.ATTACK_3), int(State.SKILL_1), int(State.SKILL_2)]:
			head += Vector2(1.5 * facing * attack_p, -0.8 * attack_p)
			neck += Vector2(2.6 * facing * attack_p, -0.4 * attack_p)
			pelvis += Vector2(-1.8 * facing * attack_p, 0.3 * attack_p)
		elif state_id == int(State.ROLL):
			if image_roll_stationary:
				head += Vector2(-1.6 * facing, 1.8 + 1.0 * roll_p)
				neck += Vector2(-1.2 * facing, 1.5 + 0.8 * roll_p)
				pelvis += Vector2(0.5 * facing, 1.5)
			else:
				head += Vector2(-3.0 * facing, 2.4 + 1.2 * roll_p)
				neck += Vector2(-2.4 * facing, 2.0 + 1.0 * roll_p)
				pelvis += Vector2(-0.9 * facing, 1.9)
		draw_line(neck, pelvis, color, 1.6)
		draw_circle(head, 2.5, color)
		draw_line(neck, neck + Vector2(5.8 * facing, -1.0), Color(color.r, color.g, color.b, color.a * 0.72), 1.2)
		draw_line(pelvis, pelvis + Vector2(-4.8 * facing, 3.3), Color(color.r, color.g, color.b, color.a * 0.62), 1.15)

func _draw_attack_speed_lines(facing: float, attack_p: float) -> void:
	var base_color = _attack_style_color(int(current_state), 0.38 + 0.18 * sin(attack_p * PI))
	for i in range(5):
		var t = float(i) / 4.0
		var y = -12.0 + t * 16.0 + sin((attack_p + t * 0.4) * PI) * 0.9
		var line_len = 8.0 + 5.8 * (1.0 - absf(t - 0.5) * 1.8)
		var start = Vector2(-facing * 2.6, y)
		var end = start + Vector2(facing * line_len, 0.5 * sin((attack_p + t) * TAU))
		draw_line(start, end, Color(base_color.r, base_color.g, base_color.b, base_color.a * (1.0 - 0.1 * t)), 1.05 + 0.32 * (1.0 - t))

func _update_slash_chain(delta: float) -> void:
	if not show_combat_trails:
		slash_chain_trails.clear()
		slash_chain_spawn_timer = 0.0
		return
	var kept: Array[Dictionary] = []
	for trail_variant in slash_chain_trails:
		var trail: Dictionary = trail_variant
		var remaining = float(trail.get("time", 0.0)) - delta
		if remaining <= 0.0:
			continue
		trail["time"] = remaining
		kept.append(trail)
	slash_chain_trails = kept
	if not _is_attack_state(current_state):
		slash_chain_spawn_timer = 0.0
		return
	var p = _attack_progress()
	if p < 0.22 or p > 0.9:
		return
	slash_chain_spawn_timer -= delta
	if slash_chain_spawn_timer > 0.0:
		return
	var heavy = current_state in [State.ATTACK_3, State.SKILL_1, State.SKILL_2]
	_spawn_slash_chain_slice(heavy, p)
	var interval = 0.03 if heavy else 0.036
	interval *= 0.85 + 0.2 * (1.0 - p)
	slash_chain_spawn_timer = interval

func _spawn_slash_chain_slice(heavy: bool, progress: float) -> void:
	var stage = clampi(attack_stage_current, 1, 5)
	var phase = slash_chain_phase
	slash_chain_phase += 1
	var profile: Dictionary = _build_slash_chain_profile(progress, stage, phase, heavy)
	var lifetime = 0.14 if heavy else 0.1
	profile["time"] = lifetime
	profile["max_time"] = lifetime
	profile["heavy"] = heavy
	slash_chain_trails.append(profile)
	if slash_chain_trails.size() > 24:
		slash_chain_trails.remove_at(0)

func _build_slash_chain_profile(progress: float, stage: int, phase: int, heavy: bool) -> Dictionary:
	var facing = 1.0 if facing_dir.x >= 0.0 else -1.0
	var stage_f = float(stage)
	var phase_f = float(phase)
	var offset = -0.09 + 0.18 * fmod(phase_f, 3.0) / 2.0
	var center = Vector2(
		(8.6 + stage_f * 1.35 + progress * 5.2 + offset * 7.0) * facing,
		-6.0 - progress * 0.8 + sin(phase_f * 1.4) * 0.75
	)
	var sweep = PI * (0.68 + 0.05 * stage_f + 0.03 * sin(progress * PI))
	var start_angle = -PI * (0.95 - 0.66 * progress) + offset
	if facing < 0.0:
		start_angle = PI - start_angle - sweep
	var outer = 13.8 + stage_f * 1.5 + (2.4 if heavy else 0.0) + 0.8 * sin(phase_f * 0.7)
	var inner = outer - (4.1 + 1.15 * sin(progress * PI))
	return {
		"center": center,
		"start": start_angle,
		"sweep": sweep,
		"inner": inner,
		"outer": outer
	}

func _play_swing_se(stage: int, heavy: bool) -> void:
	var se = AudioStreamPlayer2D.new()
	se.max_distance = 1900.0
	se.volume_db = -3.4 if heavy else -4.8
	var duration = 0.24 if heavy else 0.18
	var start_freq = 174.0 + 26.0 * float(stage)
	var end_freq = 640.0 + 46.0 * float(stage)
	if heavy:
		start_freq = 148.0 + 24.0 * float(stage)
		end_freq = 582.0 + 42.0 * float(stage)
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = SWING_SE_MIX_RATE
	stream.buffer_length = 0.42
	se.stream = stream
	add_child(se)
	se.play()

	var playback = se.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		se.queue_free()
		return
	var total_frames = int(SWING_SE_MIX_RATE * duration)
	var write_count = mini(total_frames, playback.get_frames_available())
	var pitch_jitter = randf_range(0.985, 1.018)
	start_freq *= pitch_jitter
	end_freq *= pitch_jitter
	var delay_frames = int(0.014 * float(SWING_SE_MIX_RATE))
	var delay_buffer: Array[float] = []
	delay_buffer.resize(delay_frames + 1)
	for d in range(delay_buffer.size()):
		delay_buffer[d] = 0.0
	var delay_index = 0
	var low_noise = 0.0
	for i in range(write_count):
		var p = float(i) / float(maxi(1, total_frames - 1))
		var freq = lerpf(start_freq, end_freq, pow(p, 0.72))
		var t = float(i) / float(SWING_SE_MIX_RATE)
		var envelope = pow(1.0 - p, 1.48 if heavy else 1.38)
		var noise = randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, noise, 0.08 + 0.17 * p)
		var air = (noise - low_noise) * (0.42 + 0.16 * (1.0 - p))
		var chirp = sin(TAU * freq * t + 8.0 * p * p)
		var undertone = sin(TAU * (freq * 0.41) * t) * exp(-5.6 * p)
		var metallic = sin(TAU * (freq * 1.52) * t + sin(TAU * 6.2 * t) * 0.38) * exp(-8.8 * p)
		var attack_click = sin(TAU * (960.0 + 130.0 * float(stage)) * t) * exp(-42.0 * p)
		var dry = (
			chirp * (0.48 if heavy else 0.44)
			+ undertone * (0.56 if heavy else 0.48)
			+ metallic * (0.34 if heavy else 0.26)
			+ air * (0.42 if heavy else 0.34)
			+ attack_click * 0.22
		) * envelope
		var delayed = delay_buffer[delay_index]
		var sample = dry + delayed * (0.36 if heavy else 0.28)
		delay_buffer[delay_index] = dry
		delay_index = (delay_index + 1) % delay_buffer.size()
		sample = sample / (1.0 + absf(sample) * 0.95)
		var width = 0.06 + 0.05 * sin(p * PI)
		var left = clampf(sample * (1.0 + width), -1.0, 1.0)
		var right = clampf(sample * (1.0 - width), -1.0, 1.0)
		playback.push_frame(Vector2(left, right))
	get_tree().create_timer(duration + 0.1).timeout.connect(
		func() -> void:
			if is_instance_valid(se):
				se.queue_free()
	)

func _play_impact_se(heavy: bool) -> void:
	var se = AudioStreamPlayer2D.new()
	se.max_distance = 1700.0
	se.volume_db = -2.1 if heavy else -3.8
	var duration = 0.26 if heavy else 0.2
	var sub_freq = 44.0 if heavy else 62.0
	var body_freq = 112.0 if heavy else 152.0
	var clang_a = 520.0 if heavy else 690.0
	var clang_b = 860.0 if heavy else 1060.0
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = IMPACT_SE_MIX_RATE
	stream.buffer_length = 0.4
	se.stream = stream
	add_child(se)
	se.play()

	var playback = se.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		se.queue_free()
		return
	var total_frames = int(IMPACT_SE_MIX_RATE * duration)
	var write_count = mini(total_frames, playback.get_frames_available())
	var delay_frames = int(0.017 * float(IMPACT_SE_MIX_RATE))
	var delay_buffer: Array[float] = []
	delay_buffer.resize(delay_frames + 1)
	for i in range(delay_buffer.size()):
		delay_buffer[i] = 0.0
	var delay_index = 0
	for i in range(write_count):
		var p = float(i) / float(maxi(1, total_frames - 1))
		var t = float(i) / float(IMPACT_SE_MIX_RATE)
		var env = pow(1.0 - p, 1.86 if heavy else 1.74)
		var sub = sin(TAU * sub_freq * t) * exp(-4.8 * p) * (0.92 if heavy else 0.74)
		var body = sin(TAU * body_freq * t + sin(TAU * 17.0 * t) * 0.2) * exp(-7.2 * p) * 0.66
		var clang = (
			sin(TAU * clang_a * t) * (0.36 if heavy else 0.3)
			+ sin(TAU * clang_b * t) * (0.3 if heavy else 0.24)
		) * exp(-15.5 * p)
		var edge = sin(TAU * (clang_b * 1.48) * t + sin(TAU * 12.0 * t) * 0.3) * exp(-21.0 * p) * (0.24 if heavy else 0.18)
		var grit = randf_range(-1.0, 1.0) * (0.3 if heavy else 0.24) * exp(-22.0 * p)
		var click = randf_range(-1.0, 1.0) * exp(-95.0 * p) * (0.46 if heavy else 0.34)
		var dry = (sub + body + clang + edge + grit + click) * env
		var delayed = delay_buffer[delay_index]
		var sample = dry + delayed * (0.44 if heavy else 0.34)
		delay_buffer[delay_index] = dry
		delay_index = (delay_index + 1) % delay_buffer.size()
		sample = sample / (1.0 + absf(sample) * 1.05)
		var width = 0.03 + 0.03 * sin(p * PI)
		var left = clampf(sample * (1.0 + width), -1.0, 1.0)
		var right = clampf(sample * (1.0 - width), -1.0, 1.0)
		playback.push_frame(Vector2(left, right))
	get_tree().create_timer(duration + 0.12).timeout.connect(
		func() -> void:
			if is_instance_valid(se):
				se.queue_free()
	)

func _play_defense_se(parry_success: bool) -> void:
	var se = AudioStreamPlayer2D.new()
	se.max_distance = 1800.0
	se.volume_db = -2.8 if parry_success else -5.2
	var duration = 0.2 if parry_success else 0.12
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = IMPACT_SE_MIX_RATE
	stream.buffer_length = 0.3
	se.stream = stream
	add_child(se)
	se.play()

	var playback = se.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		se.queue_free()
		return
	var total_frames = int(IMPACT_SE_MIX_RATE * duration)
	var write_count = mini(total_frames, playback.get_frames_available())
	for i in range(write_count):
		var p = float(i) / float(maxi(1, total_frames - 1))
		var t = float(i) / float(IMPACT_SE_MIX_RATE)
		var env = 0.0
		var sample = 0.0
		if parry_success:
			env = pow(1.0 - p, 1.65)
			var ping = sin(TAU * 980.0 * t + sin(TAU * 26.0 * t) * 0.2) * exp(-8.4 * p)
			var bell = sin(TAU * 1520.0 * t) * exp(-9.8 * p)
			var low = sin(TAU * 146.0 * t) * exp(-13.0 * p)
			var sparkle = randf_range(-1.0, 1.0) * exp(-28.0 * p)
			sample = (ping * 0.56 + bell * 0.44 + low * 0.24 + sparkle * 0.18) * env
		else:
			env = pow(1.0 - p, 1.38)
			var whoosh = randf_range(-1.0, 1.0) * exp(-10.0 * p)
			var tone = sin(TAU * 460.0 * t + p * 6.0) * exp(-7.0 * p)
			var tick = sin(TAU * 790.0 * t) * exp(-26.0 * p)
			sample = (whoosh * 0.42 + tone * 0.5 + tick * 0.3) * env
		sample = sample / (1.0 + absf(sample) * 0.88)
		playback.push_frame(Vector2(sample, sample))
	get_tree().create_timer(duration + 0.08).timeout.connect(
		func() -> void:
			if is_instance_valid(se):
				se.queue_free()
	)

func _update_camera_shake(delta: float) -> void:
	if not camera:
		return
	if camera_shake_timer > 0.0:
		camera_shake_timer -= delta
		var t = clampf(camera_shake_timer / maxf(camera_shake_duration, 0.001), 0.0, 1.0)
		var strength = camera_shake_strength * t
		camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		return
	if camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

func _trigger_camera_shake(strength: float, duration: float) -> void:
	camera_shake_strength = maxf(camera_shake_strength, strength)
	camera_shake_duration = maxf(camera_shake_duration, duration)
	camera_shake_timer = maxf(camera_shake_timer, duration)

func _scale_damage(base_damage: int) -> int:
	return maxi(1, int(round(float(base_damage) * _current_damage_multiplier())))

func _current_damage_multiplier() -> float:
	var mult = bonus_damage_multiplier
	if max_hp > 0 and float(hp) / float(max_hp) <= low_hp_damage_threshold:
		mult *= low_hp_damage_multiplier
	return mult

func _clear_enemy_projectiles(radius: float) -> int:
	var removed = 0
	for node in get_tree().get_nodes_in_group("enemy_projectiles"):
		var projectile = node as Node2D
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

func _spawn_hit_spark(world_pos: Vector2, hit_dir: Vector2, heavy: bool = false) -> void:
	if not combat_fx_enabled:
		return
	var parent_node = get_parent()
	if not parent_node:
		return
	var fx = Node2D.new()
	fx.set_script(HIT_SPARK_FX_SCRIPT)
	var dir = hit_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(facing_dir.x, 0.0).normalized()
	fx.global_position = world_pos + Vector2(0.0, -6.0) + dir * 10.0
	if fx.has_method("configure"):
		var color = _attack_style_color(int(current_state), 0.95)
		if heavy:
			color = Color(1.0, 0.8, 0.4, 0.95)
		fx.call("configure", dir, color, heavy)
	parent_node.add_child(fx)

func set_virtual_move_axis(axis: float) -> void:
	virtual_move_axis = clampf(axis, -1.0, 1.0)

func ai_attack() -> void:
	if _is_locked():
		return
	_try_attack()

func ai_roll() -> void:
	if _is_locked():
		return
	if _can_use_stamina(roll_stamina):
		_enter_roll(true)

func ai_guard_start() -> void:
	if _is_locked():
		return
	if current_state != State.PARRY and current_state != State.GUARD:
		_enter_guard()

func ai_guard_end() -> void:
	if current_state == State.GUARD:
		_change_state(State.IDLE)

func ai_estus() -> void:
	if _is_locked():
		return
	if estus_charges > 0 and _can_use_stamina(estus_stamina):
		_enter_estus()

func ai_skill1() -> void:
	if _is_locked():
		return
	if skill1_cd <= 0 and _can_use_stamina(18.0):
		_enter_skill1()

func ai_skill2() -> void:
	if _is_locked():
		return
	if skill2_cd <= 0 and _can_use_stamina(18.0):
		_enter_skill2()

func _can_use_stamina(cost: float) -> bool:
	return stamina >= cost

func _consume_stamina(cost: float) -> void:
	stamina -= cost
	stamina = maxf(stamina, 0.0)
	stamina_delay_timer = stamina_delay
	emit_signal("stamina_changed", stamina, max_stamina)

func _change_state(new_state: State) -> void:
	if _is_attack_state(new_state):
		attack_hit_ids.clear()
	elif _is_attack_state(current_state):
		attack_elapsed = 0.0
		attack_duration_current = 0.0
		attack_stage_current = 0
	current_state = new_state

func _is_attack_state(state: int) -> bool:
	return state in [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3, State.SKILL_1, State.SKILL_2]

func _can_jump() -> bool:
	return _can_ground_jump() or _can_wall_jump()

func _is_locked() -> bool:
	return current_state in [
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3,
		State.ROLL, State.PARRY, State.PARRY_FAIL,
		State.ESTUS, State.STAGGER, State.SKILL_1, State.SKILL_2
	]

func _update_visuals() -> void:
	queue_redraw()

func _draw() -> void:
	var draw_scale = clampf(silhouette_scale, 0.8, 1.2)
	var attack_pose = current_state in [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3, State.SKILL_1, State.SKILL_2]
	var attack_p = _attack_progress() if attack_pose else 0.0
	var roll_pose = current_state == State.ROLL
	var roll_total = maxf(
		0.001,
		(in_place_dodge_iframes + in_place_dodge_recovery) if roll_stationary else (roll_iframes + roll_recovery)
	)
	var roll_p = 0.0
	if roll_pose:
		roll_p = 1.0 - clampf(state_timer / roll_total, 0.0, 1.0)
	var draw_rotation = 0.0
	var draw_offset = Vector2.ZERO
	var draw_stretch = Vector2(draw_scale, draw_scale)
	var visual_facing = 1.0 if facing_dir.x >= 0.0 else -1.0
	if attack_pose:
		var attack_stage = float(clampi(attack_stage_current, 1, 5))
		var motion_power = 1.0 + 0.1 * minf(attack_stage, 3.0)
		var prep_curve = sin(clampf(attack_p / 0.34, 0.0, 1.0) * PI * 0.5)
		var strike_curve = sin(clampf((attack_p - 0.2) / 0.52, 0.0, 1.0) * PI)
		var recover_curve = pow(clampf((attack_p - 0.66) / 0.34, 0.0, 1.0), 1.15)
		draw_offset += Vector2(
			visual_facing * ((-1.6 * prep_curve) + (4.2 * strike_curve) - (2.0 * recover_curve)) * motion_power,
			-0.9 * prep_curve + 1.0 * strike_curve
		)
		draw_rotation += visual_facing * ((-0.07 * prep_curve) + (0.11 * strike_curve) - (0.06 * recover_curve)) * motion_power
		draw_stretch = Vector2(
			draw_stretch.x * (1.0 + 0.08 * strike_curve),
			draw_stretch.y * (1.0 - 0.06 * strike_curve + 0.04 * prep_curve)
		)
	if roll_pose:
		if roll_stationary:
			var evade_wave = sin(roll_p * PI)
			draw_rotation += roll_dir_x * 0.19 * sin((roll_p - 0.18) * PI)
			draw_offset += Vector2(-roll_dir_x * 1.5 * evade_wave, -0.7 * evade_wave)
			draw_stretch = Vector2(draw_scale * (1.04 + 0.04 * evade_wave), draw_scale * (0.9 - 0.05 * evade_wave))
		else:
			draw_rotation = roll_dir_x * (roll_p * TAU)
			draw_offset = Vector2(0.0, sin(roll_p * PI) * 1.0)
			draw_stretch = Vector2(draw_scale * 1.06, draw_scale * 0.88)
	draw_set_transform(draw_offset, draw_rotation, draw_stretch)
	var body_color = Color(0.78, 0.9, 1.0)
	match current_state:
		State.ROLL:
			body_color = Color(0.36, 0.78, 1.0, 0.78)
		State.GUARD:
			body_color = Color(0.42, 1.0, 0.56)
		State.PARRY:
			body_color = Color(1.0, 0.95, 0.3)
		State.PARRY_FAIL:
			body_color = Color(1.0, 0.42, 0.18)
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			body_color = Color(1.0, 0.72, 0.26)
		State.ESTUS:
			body_color = Color(0.24, 1.0, 0.66)
		State.STAGGER:
			body_color = Color(1.0, 0.2, 0.2)
		State.SKILL_1, State.SKILL_2:
			body_color = Color(0.72, 0.42, 1.0)

	var facing = 1.0 if facing_dir.x >= 0.0 else -1.0
	var step = 0.0
	if current_state == State.MOVE and is_on_floor():
		step = sin(float(Time.get_ticks_msec()) * 0.02) * 2.7
	var lean = clampf(velocity.x / maxf(move_speed, 1.0), -1.0, 1.0) * 1.6

	if show_combat_trails and stylish_afterimages:
		_draw_style_afterimages()

	draw_circle(Vector2(0, 12), 6.8, Color(0.0, 0.0, 0.0, 0.19))

	var head = Vector2(lean * 0.35, -13.8)
	var neck = Vector2(lean * 0.2, -7.8)
	var pelvis = Vector2(-lean * 0.2, 2.0)
	var lead_knee = Vector2(3.8 * facing, 7.2 + step * 0.2)
	var rear_knee = Vector2(-3.2 * facing, 6.8 - step * 0.2)
	var lead_foot = Vector2(5.2 * facing + step, 13.0)
	var rear_foot = Vector2(-4.8 * facing - step * 0.7, 12.4)
	var lead_arm = Vector2(6.2 * facing, -1.7 + step * 0.22)
	var rear_arm = Vector2(-5.8 * facing, -2.2 - step * 0.2)
	if attack_pose:
		var stage_id = clampi(attack_stage_current, 1, 5)
		var stage_power = 1.0 + 0.16 * float(mini(stage_id, 3) - 1)
		var prep = clampf(attack_p / 0.32, 0.0, 1.0)
		var strike = clampf((attack_p - 0.2) / 0.5, 0.0, 1.0)
		var recover = clampf((attack_p - 0.68) / 0.32, 0.0, 1.0)
		var prep_curve = sin(prep * PI * 0.5)
		var strike_curve = sin(strike * PI)
		var recover_curve = pow(recover, 1.2)
		var swing_snap = sin((strike - 0.08) * PI)
		head += Vector2(
			(-1.0 * prep_curve + 2.3 * strike_curve - 1.3 * recover_curve) * facing * stage_power,
			-0.5 - 1.2 * prep_curve + 0.9 * strike_curve
		)
		neck += Vector2(
			(-1.2 * prep_curve + 2.9 * strike_curve - 1.4 * recover_curve) * facing * stage_power,
			-0.2 - 1.0 * prep_curve + 0.7 * strike_curve
		)
		pelvis += Vector2(
			(1.4 * prep_curve - 1.9 * strike_curve + 1.1 * recover_curve) * facing * stage_power,
			0.3 + 0.6 * prep_curve
		)
		lead_knee += Vector2(
			(1.8 * prep_curve - 1.9 * strike_curve + 1.0 * recover_curve) * facing * stage_power,
			0.5 + 0.7 * prep_curve
		)
		rear_knee += Vector2(
			(-1.3 * prep_curve + 1.3 * strike_curve) * facing * stage_power,
			0.7 + 0.5 * prep_curve
		)
		lead_foot += Vector2(
			(-0.8 * strike_curve + 0.7 * recover_curve) * facing * stage_power,
			0.3 + 0.4 * prep_curve
		)
		rear_foot += Vector2(
			(1.0 * strike_curve - 0.6 * recover_curve) * facing * stage_power,
			0.2 + 0.4 * prep_curve
		)
		lead_arm = Vector2(
			(6.0 + 3.2 * prep_curve + 5.6 * strike_curve - 3.1 * recover_curve + 0.8 * swing_snap) * facing,
			-5.6 - 3.2 * prep_curve + 4.8 * strike_curve + 1.2 * recover_curve
		)
		rear_arm = Vector2(
			(-5.3 + 0.9 * prep_curve - 2.1 * strike_curve + 1.1 * recover_curve) * facing,
			-4.6 + 1.6 * prep_curve - 0.8 * strike_curve
		)
		match current_state:
			State.ATTACK_1:
				lead_arm += Vector2(-1.2 * facing, -0.7)
				rear_arm += Vector2(0.7 * facing, 0.5)
			State.ATTACK_2:
				head += Vector2(0.6 * facing, -0.2)
				lead_arm += Vector2(1.2 * facing, -0.1)
				rear_arm += Vector2(-0.9 * facing, -0.4)
			State.ATTACK_3:
				head += Vector2(-0.8 * facing, -0.8 * prep_curve)
				pelvis += Vector2(-1.1 * facing, 0.8 * prep_curve)
				lead_arm = Vector2(
					(4.6 + 2.4 * prep_curve + 7.4 * strike_curve) * facing,
					-8.8 - 5.6 * prep_curve + 8.0 * strike_curve
				)
				rear_arm = Vector2(
					(-4.5 - 1.6 * strike_curve) * facing,
					-6.1 + 1.5 * prep_curve
				)
				lead_knee += Vector2(1.2 * facing, 0.8)
				rear_knee += Vector2(-0.9 * facing, 0.7)
			State.SKILL_1:
				var thrust = clampf((attack_p - 0.2) / 0.44, 0.0, 1.0)
				var thrust_curve = sin(thrust * PI * 0.5)
				head += Vector2(0.9 * thrust_curve * facing, -0.4)
				neck += Vector2(1.8 * thrust_curve * facing, -0.2)
				pelvis += Vector2(-0.9 * thrust_curve * facing, 0.0)
				lead_arm = Vector2(
					(9.0 + 3.6 * thrust_curve - 1.9 * recover_curve) * facing,
					-5.5 + 1.6 * thrust_curve
				)
				rear_arm = Vector2((-4.8 - 1.2 * thrust_curve) * facing, -4.8)
			State.SKILL_2:
				var spin = sin(attack_p * TAU * 1.25)
				var spin_up = sin(attack_p * TAU)
				head += Vector2(0.8 * spin * facing, -0.5 + 0.3 * spin_up)
				neck += Vector2(1.1 * spin * facing, -0.2 + 0.4 * spin_up)
				lead_arm = Vector2((6.8 + 4.0 * spin) * facing, -4.9 + 2.2 * spin_up)
				rear_arm = Vector2((-6.4 - 3.3 * spin) * facing, -4.5 - 2.0 * spin_up)
				lead_knee += Vector2(0.9 * spin * facing, 0.2)
				rear_knee += Vector2(-0.8 * spin * facing, 0.2)
			_:
				pass
	elif roll_pose:
		if roll_stationary:
			var evade_wave = sin(roll_p * PI)
			var evade_twist = sin((roll_p - 0.15) * PI)
			head += Vector2(-2.6 * facing, 1.9 + 1.5 * evade_wave)
			neck += Vector2(-2.0 * facing, 1.5 + 1.1 * evade_wave)
			pelvis += Vector2(1.0 * facing * evade_twist, 1.2 + 0.8 * evade_wave)
			lead_knee += Vector2(0.8 * facing, -1.5 + 0.5 * evade_wave)
			rear_knee += Vector2(-0.9 * facing, -1.2 - 0.5 * evade_wave)
			lead_foot += Vector2(-0.9 * facing, -1.3)
			rear_foot += Vector2(0.9 * facing, -1.1)
			lead_arm = Vector2(4.3 * facing, -0.6 + 0.9 * evade_wave)
			rear_arm = Vector2(-4.6 * facing, -0.4 - 0.9 * evade_wave)
		else:
			var tuck = sin(roll_p * PI)
			var spin_curve = sin(roll_p * PI * 1.35)
			var tumble_wave = sin(roll_p * TAU)
			head += Vector2(-5.8 * facing + 0.9 * tumble_wave, 4.4 + 2.1 * tuck)
			neck += Vector2(-4.6 * facing + 0.7 * tumble_wave, 3.4 + 1.5 * tuck)
			pelvis += Vector2(-3.1 * facing, 3.2 + 1.1 * spin_curve)
			lead_knee += Vector2(3.3 * facing, -2.7 + 0.9 * spin_curve)
			rear_knee += Vector2(-3.2 * facing, -2.3 - 0.7 * spin_curve)
			lead_foot += Vector2(-3.8 * facing, -3.3)
			rear_foot += Vector2(3.7 * facing, -2.9)
			lead_arm = Vector2(5.6 * facing, 0.8 + 1.3 * spin_curve)
			rear_arm = Vector2(-5.8 * facing, 0.6 - 1.3 * spin_curve)

	draw_line(neck, pelvis, body_color, 2.1)
	draw_line(neck, lead_arm, body_color.darkened(0.08), 1.9)
	draw_line(neck, rear_arm, body_color.darkened(0.22), 1.85)
	draw_line(pelvis, lead_knee, body_color.darkened(0.08), 1.95)
	draw_line(lead_knee, lead_foot, body_color.darkened(0.08), 1.85)
	draw_line(pelvis, rear_knee, body_color.darkened(0.22), 1.9)
	draw_line(rear_knee, rear_foot, body_color.darkened(0.22), 1.8)
	draw_circle(head, 4.2, body_color.lightened(0.05))
	draw_circle(head + Vector2(1.65 * facing, -0.55), 0.78, Color(0.08, 0.08, 0.1))

	if show_combat_trails and current_state in [State.SKILL_1, State.SKILL_2]:
		var skill_p = clampf(_attack_progress(), 0.0, 1.0)
		var skill_center = Vector2(8.0 * facing, -5.0)
		var skill_ring = 14.0 + 5.0 * sin(skill_p * PI)
		var skill_alpha = 0.14 + 0.18 * sin(skill_p * PI)
		draw_arc(skill_center, skill_ring, 0.0, TAU, 40, Color(0.86, 0.54, 1.0, skill_alpha), 1.5)
		draw_arc(skill_center, skill_ring + 5.0, 0.0, TAU, 40, Color(0.52, 0.88, 1.0, skill_alpha * 0.65), 1.1)

	if show_combat_trails and not slash_chain_trails.is_empty():
		for trail_variant in slash_chain_trails:
			var trail: Dictionary = trail_variant
			var remaining = float(trail.get("time", 0.0))
			var max_time = maxf(0.001, float(trail.get("max_time", 0.1)))
			var fade = clampf(remaining / max_time, 0.0, 1.0)
			var heavy_trail = bool(trail.get("heavy", false))
			var fill_color = Color(0.94, 0.97, 1.0, 0.15 * fade)
			var edge_color = Color(1.0, 0.86, 0.62, 0.26 * fade)
			if heavy_trail:
				fill_color = Color(1.0, 0.72, 0.44, 0.2 * fade)
				edge_color = Color(1.0, 0.5, 0.24, 0.34 * fade)
			_draw_slash_crescent(
				Vector2(trail.get("center", Vector2.ZERO)),
				float(trail.get("inner", 8.0)),
				float(trail.get("outer", 12.0)),
				float(trail.get("start", 0.0)),
				float(trail.get("sweep", PI * 0.6)),
				fill_color,
				edge_color,
				18,
				1.2
			)

	if show_combat_trails and current_state in [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3]:
		var attack_fx_p = clampf(_attack_progress(), 0.0, 1.0)
		var slash_center = Vector2((9.6 + 4.2 * attack_fx_p) * facing, -5.8 - 0.8 * attack_fx_p)
		var stage_bonus = float(clampi(attack_stage_current, 1, 3) - 1)
		var sweep = PI * (0.86 + 0.12 * stage_bonus + 0.08 * sin(attack_fx_p * PI))
		var start_angle = -PI * (0.9 - 0.58 * attack_fx_p)
		if facing < 0.0:
			start_angle = PI - start_angle - sweep
		var outer_r = 17.0 + stage_bonus * 3.2
		var inner_r = outer_r - (5.4 + 1.2 * sin(attack_fx_p * PI))
		var core_alpha = 0.24 + 0.28 * sin(attack_fx_p * PI)
		var fill_color = Color(0.96, 0.96, 0.92, core_alpha)
		var edge_color = Color(1.0, 0.84, 0.58, minf(0.82, core_alpha + 0.22))
		if current_state == State.ATTACK_3:
			fill_color = Color(1.0, 0.78, 0.48, core_alpha + 0.08)
			edge_color = Color(1.0, 0.62, 0.28, minf(0.88, core_alpha + 0.3))
		_draw_slash_crescent(
			slash_center,
			inner_r,
			outer_r,
			start_angle,
			sweep,
			fill_color,
			edge_color,
			26,
			1.8
		)
		var tip_angle = start_angle + sweep
		var tip_pos = slash_center + Vector2.RIGHT.rotated(tip_angle) * (outer_r + 1.6)
		var core_start = slash_center + Vector2.RIGHT.rotated(start_angle + sweep * 0.52) * (inner_r + 0.6)
		draw_line(core_start, tip_pos, Color(1.0, 1.0, 0.94, 0.22 + 0.38 * (1.0 - attack_fx_p)), 1.35)
		draw_circle(tip_pos, 1.3 + 0.6 * (1.0 - attack_fx_p), Color(1.0, 0.95, 0.82, 0.5 * (1.0 - attack_fx_p)))
		if _is_attack_hit_window_active():
			_draw_attack_speed_lines(facing, attack_fx_p)

	if current_state == State.GUARD:
		var guard_pos = Vector2(7.0 * facing, -4.2)
		var guard_perp = Vector2(-facing, 0.0)
		var guard_center = guard_pos + guard_perp * 2.2
		var guard_wave = float(Time.get_ticks_msec()) * 0.018
		var guard_pulse = 0.5 + 0.5 * sin(guard_wave)
		var outer_r = 10.5 + guard_pulse * 1.8
		var inner_r = 7.0 + guard_pulse * 0.9
		draw_arc(
			guard_center,
			outer_r,
			-PI * 0.56,
			PI * 0.56,
			26,
			Color(0.42, 1.0, 0.62, 0.62 + 0.2 * guard_pulse),
			2.5
		)
		draw_arc(
			guard_center,
			inner_r,
			-PI * 0.52,
			PI * 0.52,
			22,
			Color(0.72, 1.0, 0.84, 0.44 + 0.16 * guard_pulse),
			1.55
		)
		draw_line(
			guard_center + Vector2(0.0, -8.0),
			guard_center + Vector2(0.0, 9.0),
			Color(0.28, 1.0, 0.54, 0.95),
			2.8
		)
		draw_circle(guard_center + Vector2(0.0, -8.6), 1.15, Color(0.76, 1.0, 0.86, 0.9))
		draw_circle(guard_center + Vector2(0.0, 9.4), 1.15, Color(0.76, 1.0, 0.86, 0.9))
		for i in range(3):
			var t = float(i) / 2.0
			var a = lerpf(-PI * 0.34, PI * 0.34, t)
			var spark_dir = Vector2.RIGHT.rotated(a)
			var p0 = guard_center + spark_dir * (inner_r + 1.3)
			var p1 = guard_center + spark_dir * (outer_r + 2.0)
			draw_line(p0, p1, Color(0.9, 1.0, 0.96, 0.58 + 0.16 * guard_pulse), 1.2)

	if current_state == State.ROLL:
		var dodge_fade = 1.0 - roll_p
		var dodge_wave = sin(roll_p * PI)
		var dodge_center = Vector2(-0.8 * facing, -1.6)
		var dodge_ring = 9.8 + dodge_wave * 3.0
		draw_arc(
			dodge_center,
			dodge_ring,
			0.0,
			TAU,
			32,
			Color(0.48, 0.92, 1.0, 0.34 + 0.24 * dodge_fade),
			1.8
		)
		for i in range(3):
			var t = float(i + 1) / 3.0
			var after_offset = Vector2(-facing * (2.4 + t * 2.8), 0.4 + t * 0.5)
			if roll_stationary:
				after_offset = Vector2(-roll_dir_x * (1.0 + t * 1.4), -0.2 + t * 0.35)
			var after_alpha = (0.22 - 0.05 * float(i)) * dodge_fade
			draw_line(neck + after_offset, pelvis + after_offset, Color(0.66, 0.95, 1.0, after_alpha), 1.3)
			draw_circle(head + after_offset * 0.8, 2.3 - 0.3 * t, Color(0.66, 0.95, 1.0, after_alpha * 0.7))
		if roll_stationary:
			for i in range(4):
				var a = TAU * float(i) / 4.0 + roll_p * PI * 0.6
				var dir = Vector2.RIGHT.rotated(a)
				var p0 = dodge_center + dir * (4.0 + dodge_wave * 1.8)
				var p1 = dodge_center + dir * (8.2 + dodge_wave * 3.0)
				draw_line(p0, p1, Color(0.66, 0.96, 1.0, (0.26 - 0.04 * float(i)) * dodge_fade), 1.05)
			draw_arc(
				dodge_center + Vector2(0.0, -0.6),
				dodge_ring * 0.74,
				0.0,
				TAU,
				24,
				Color(0.7, 1.0, 1.0, 0.28 * dodge_fade),
				1.0
			)
		else:
			var spin_angle = float(Time.get_ticks_msec()) * 0.02 * roll_dir_x
			for i in range(2):
				var sweep = PI * (0.72 - 0.12 * float(i))
				var arc_r = dodge_ring + 3.4 + float(i) * 2.8
				draw_arc(
					dodge_center + Vector2(-facing * 2.4, -0.6),
					arc_r,
					spin_angle + float(i) * 0.55,
					spin_angle + float(i) * 0.55 + sweep,
					24,
					Color(0.62, 0.96, 1.0, (0.22 - 0.06 * float(i)) * dodge_fade),
					1.15
				)
			var skid_start = pelvis + Vector2(-facing * 5.6, 8.4)
			var skid_end = skid_start + Vector2(-facing * 7.8, 0.0)
			draw_line(skid_start, skid_end, Color(0.9, 0.98, 1.0, 0.24 * dodge_fade), 1.0)

	if show_combat_trails and swing_fx_timer > 0.0:
		var p = 1.0 - clampf(swing_fx_timer / maxf(0.001, swing_fx_duration), 0.0, 1.0)
		var swing_center = Vector2((8.9 + 1.4 * p) * facing, -5.1 - 0.3 * p)
		var sweep = PI * (0.56 + 0.04 * float(clampi(swing_fx_stage, 1, 5)))
		var start_angle = -PI * 0.72 + p * PI * 0.62
		if facing < 0.0:
			start_angle = PI - start_angle - sweep
		var stage_scale = float(clampi(swing_fx_stage, 1, 5))
		var outer_r = 12.8 + stage_scale * 1.9 + (2.2 if swing_fx_heavy else 0.0)
		var inner_r = outer_r - (5.0 + 1.6 * (1.0 - p))
		var alpha = (1.0 - p) * (0.48 if swing_fx_heavy else 0.38)
		var fill_color = Color(0.95, 0.98, 1.0, alpha)
		var edge_color = Color(1.0, 0.88, 0.62, alpha * 1.35)
		if swing_fx_heavy:
			fill_color = Color(1.0, 0.76, 0.44, alpha * 1.15)
			edge_color = Color(1.0, 0.52, 0.24, alpha * 1.5)
		_draw_slash_crescent(
			swing_center,
			inner_r,
			outer_r,
			start_angle,
			sweep,
			fill_color,
			edge_color,
			28,
			2.1
		)
		_draw_slash_crescent(
			swing_center + Vector2(1.2 * facing, 0.4),
			inner_r + 1.8,
			outer_r + 5.2,
			start_angle + 0.07,
			sweep * 0.88,
			Color(fill_color.r, fill_color.g, fill_color.b, fill_color.a * 0.55),
			Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.72),
			24,
			1.55
		)
		var spark_count = 4 if swing_fx_heavy else 3
		for i in range(spark_count):
			var rt = float(i) / float(maxi(1, spark_count - 1))
			var a = start_angle + sweep * rt
			var r = outer_r + 1.6 + 2.4 * sin((p + rt) * PI)
			var pos = swing_center + Vector2.RIGHT.rotated(a) * r
			var spark_dir = Vector2.RIGHT.rotated(a)
			draw_line(
				pos - spark_dir * 0.85,
				pos + spark_dir * (1.5 + 0.7 * (1.0 - p)),
				Color(1.0, 0.94, 0.78, 0.28 * (1.0 - p)),
				1.05
			)
		if swing_fx_heavy:
			draw_arc(
				swing_center,
				outer_r + 8.0 * p,
				0.0,
				TAU,
				30,
				Color(1.0, 0.58, 0.28, 0.22 * (1.0 - p)),
				1.3
			)

	if style_ring_timer > 0.0:
		var ring_t = 1.0 - clampf(style_ring_timer / maxf(0.001, style_ring_duration), 0.0, 1.0)
		var ring_color = style_ring_color
		var ring_alpha = (1.0 - ring_t) * (0.62 + 0.18 * clampf(stylish_ring_boost, 0.6, 1.8))
		var ring_radius = style_ring_radius + ring_t * (10.0 + 4.0 * clampf(stylish_ring_boost, 0.6, 1.8))
		draw_arc(
			Vector2(0.0, -2.0),
			ring_radius,
			0.0,
			TAU,
			34,
			Color(ring_color.r, ring_color.g, ring_color.b, ring_alpha),
			1.9
		)
		draw_arc(
			Vector2(0.0, -2.0),
			ring_radius * 0.72,
			0.0,
			TAU,
			30,
			Color(ring_color.r, ring_color.g, ring_color.b, ring_alpha * 0.58),
			1.2
		)

	if wall_slide_active:
		var side_x = 5.6 * wall_slide_side
		draw_line(
			Vector2(side_x, -9.5),
			Vector2(side_x, 8.2),
			Color(0.9, 0.98, 1.0, 0.52),
			1.2
		)
		draw_circle(Vector2(side_x, 10.2), 1.2, Color(0.55, 0.9, 1.0, 0.7))

	# Keep HUD-like bars fixed to the top of the player without roll rotation.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if dodge_success_timer > 0.0:
		var dodge_t = 1.0 - clampf(dodge_success_timer / maxf(0.001, dodge_success_duration), 0.0, 1.0)
		var dodge_alpha = 1.0 - dodge_t
		var dodge_center = Vector2(0.0, -11.0)
		var dodge_radius = 10.0 + dodge_t * 11.0
		draw_arc(dodge_center, dodge_radius, 0.0, TAU, 26, Color(0.6, 1.0, 1.0, 0.58 * dodge_alpha), 1.7)
		draw_arc(dodge_center, dodge_radius * 0.66, 0.0, TAU, 22, Color(0.76, 1.0, 1.0, 0.34 * dodge_alpha), 1.1)
		var dodge_chevron = 4.8 + dodge_t * 2.6
		var dodge_color = Color(0.82, 1.0, 1.0, 0.7 * dodge_alpha)
		draw_line(
			dodge_center + Vector2(-dodge_chevron, -1.2),
			dodge_center + Vector2(0.0, -6.3),
			dodge_color,
			1.5
		)
		draw_line(
			dodge_center + Vector2(0.0, -6.3),
			dodge_center + Vector2(dodge_chevron, -1.2),
			dodge_color,
			1.5
		)
	if parry_success_timer > 0.0:
		var parry_t = 1.0 - clampf(parry_success_timer / maxf(0.001, parry_success_duration), 0.0, 1.0)
		var parry_alpha = 1.0 - parry_t
		var parry_center = Vector2(0.0, -13.0)
		var parry_radius = 8.0 + parry_t * 13.0
		draw_arc(parry_center, parry_radius * 0.72, 0.0, TAU, 28, Color(1.0, 0.94, 0.62, 0.56 * parry_alpha), 1.6)
		draw_circle(parry_center, 1.8 + 0.6 * (1.0 - parry_t), Color(1.0, 0.98, 0.78, 0.85 * parry_alpha))
		for i in range(6):
			var a = TAU * float(i) / 6.0 + parry_t * 0.34
			var dir = Vector2.RIGHT.rotated(a)
			var p0 = parry_center + dir * (2.6 + parry_t * 2.2)
			var p1 = parry_center + dir * parry_radius
			draw_line(p0, p1, Color(1.0, 0.92, 0.44, (0.66 - 0.06 * float(i)) * parry_alpha), 1.35)
	var hp_ratio = 0.0
	if max_hp > 0:
		hp_ratio = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var hp_bg_rect = Rect2(Vector2(-16.0, -36.0), Vector2(32.0, 3.0))
	draw_rect(hp_bg_rect, Color(0.05, 0.05, 0.06, 0.88))
	draw_rect(
		Rect2(hp_bg_rect.position, Vector2(hp_bg_rect.size.x * hp_ratio, hp_bg_rect.size.y)),
		Color(1.0, 0.25 + 0.45 * hp_ratio, 0.28, 0.95)
	)
	if hp_ratio <= 0.3:
		draw_rect(hp_bg_rect.grow(0.9), Color(1.0, 0.2, 0.2, 0.45), false, 1.2)

func _build_arc_points(center: Vector2, radius: float, start_angle: float, sweep: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var safe_segments = maxi(4, segments)
	for i in range(safe_segments + 1):
		var t = float(i) / float(safe_segments)
		var a = start_angle + sweep * t
		points.push_back(center + Vector2.RIGHT.rotated(a) * radius)
	return points

func _draw_slash_crescent(
	center: Vector2,
	inner_radius: float,
	outer_radius: float,
	start_angle: float,
	sweep: float,
	fill_color: Color,
	edge_color: Color,
	segments: int = 20,
	edge_width: float = 1.6
) -> void:
	if outer_radius <= inner_radius or sweep <= 0.01:
		return
	var outer_points = _build_arc_points(center, outer_radius, start_angle, sweep, segments)
	var inner_points = _build_arc_points(center, inner_radius, start_angle + sweep, -sweep, segments)
	var poly: PackedVector2Array = PackedVector2Array()
	for pt in outer_points:
		poly.push_back(pt)
	for pt in inner_points:
		poly.push_back(pt)
	if poly.size() >= 3:
		draw_colored_polygon(poly, fill_color)
	draw_arc(center, outer_radius, start_angle, start_angle + sweep, maxi(10, segments), edge_color, edge_width)
	draw_arc(
		center,
		inner_radius,
		start_angle,
		start_angle + sweep,
		maxi(10, segments),
		Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.72),
		maxf(0.8, edge_width * 0.68)
	)
