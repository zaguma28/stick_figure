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
	roll_stamina = 28.0
	roll_iframes = 0.24
	roll_recovery = 0.14
	roll_distance = 168.0
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
	if skill1_cd > 0:
		skill1_cd -= delta
	if skill2_cd > 0:
		skill2_cd -= delta
	_update_camera_shake(delta)

func _handle_input() -> void:
	var keyboard_axis = Input.get_axis("move_left", "move_right")
	move_axis = keyboard_axis
	if absf(virtual_move_axis) > absf(move_axis):
		move_axis = virtual_move_axis
	if wall_jump_lock_timer > 0 and not is_on_floor():
		move_axis = 0.0
	if absf(move_axis) > 0.05 and not _is_attack_state(current_state):
		facing_dir = Vector2(signf(move_axis), 0.0)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_released("jump"):
		_apply_jump_cut()

	if jump_buffer_timer > 0.0:
		if _can_ground_jump():
			_perform_ground_jump()
		elif _can_wall_jump():
			_perform_wall_jump()

	if Input.is_action_just_pressed("attack") and _is_attack_state(current_state):
		queued_attack = true

	if _is_locked():
		return

	if Input.is_action_just_pressed("guard"):
		if _can_use_stamina(parry_stamina):
			_enter_parry()
			return

	if Input.is_action_pressed("guard"):
		if current_state != State.GUARD:
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
				velocity.x = move_toward(velocity.x, 0.0, ground_brake * 2.6 * delta)
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
	if not queued_attack and Input.is_action_pressed("attack"):
		var queue_open: float = 0.26
		if current_state == State.ATTACK_3:
			queue_open = 0.3
		if progress >= queue_open and state_timer > 0.06:
			queued_attack = true
	var lunge_strength = 0.0
	var windup_backstep = 0.0
	var startup = 0.36
	match current_state:
		State.ATTACK_1:
			lunge_strength = 330.0
			windup_backstep = 85.0
			startup = 0.34
		State.ATTACK_2:
			lunge_strength = 410.0
			windup_backstep = 100.0
			startup = 0.38
		State.ATTACK_3:
			lunge_strength = 500.0
			windup_backstep = 120.0
			startup = 0.42
		_:
			lunge_strength = 0.0
	var target_speed = 0.0
	if progress < startup:
		var prep = clampf(progress / maxf(0.01, startup), 0.0, 1.0)
		target_speed = -facing_dir.x * windup_backstep * pow(prep, 1.5)
	else:
		var swing_phase = clampf((progress - startup) / maxf(0.01, 1.0 - startup), 0.0, 1.0)
		var swing_wave = sin(swing_phase * PI)
		target_speed = facing_dir.x * lunge_strength * maxf(0.0, swing_wave)
	velocity.x = move_toward(velocity.x, target_speed, ground_decel * 1.05 * delta)

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
	var fast_fall = velocity.y > 0.0 and Input.is_action_pressed("move_down")
	if fast_fall:
		gravity_scale = fast_fall_gravity_scale
		fall_limit = fast_fall_max_speed
	elif absf(velocity.y) <= apex_hang_velocity_band and Input.is_action_pressed("jump"):
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

	emit_signal("debug_log", "ATTACK %d (dmg:%d stm:%.0f)" % [stage + 1, attack_damage[stage], attack_stamina[stage]])

func _enter_roll() -> void:
	var airborne = not is_on_floor()
	if airborne and remaining_air_rolls <= 0:
		emit_signal("debug_log", "ROLL LIMIT")
		return
	_consume_stamina(roll_stamina)
	if absf(move_axis) > 0.05:
		facing_dir = Vector2(signf(move_axis), 0.0)
	if airborne:
		remaining_air_rolls -= 1
	wall_slide_active = false
	wall_slide_side = 0.0
	_change_state(State.ROLL)
	velocity.x = 0.0
	state_timer = roll_iframes + roll_recovery
	iframes_timer = roll_iframes
	emit_signal("debug_log", "ROLL (iframes %.2fs)" % roll_iframes)

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
	skill1_cd = 6.0
	emit_signal("debug_log", "SKILL1: thrust (dmg:%d CT:6s)" % skill1_damage)

func _enter_skill2() -> void:
	_consume_stamina(18.0)
	_change_state(State.SKILL_2)
	state_timer = 0.62
	_begin_attack_profile(5, state_timer, true)
	skill2_cd = 9.0
	emit_signal("debug_log", "SKILL2: spin slash (dmg:%d CT:9s)" % skill2_damage)

func take_damage(amount: int, _poise_damage: int = 0, source: Node = null) -> void:
	if iframes_timer > 0:
		return

	if current_state == State.PARRY and parry_active_timer > 0:
		emit_signal("debug_log", "PARRY SUCCESS")
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
	var hitstop_scale = 0.04
	var hitstop_time = 0.065
	if heavy:
		hitstop_scale = 0.02
		hitstop_time = 0.095
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
	if not is_on_floor() and Input.is_action_pressed("move_down"):
		velocity.y = minf(velocity.y, -280.0)
	_trigger_camera_shake(4.4 if heavy_hit else 3.0, 0.1 if heavy_hit else 0.08)
	var tint = Color(0.72, 0.94, 1.0)
	if heavy_hit:
		tint = Color(1.0, 0.78, 0.44)
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
	swing_fx_duration = 0.27 if heavy else 0.19
	swing_fx_timer = swing_fx_duration

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
	se.volume_db = -4.1
	var start_freq = 152.0 + 12.0 * float(stage)
	var end_freq = 360.0 + 22.0 * float(stage)
	var duration = 0.2
	var noise_mix = 0.24
	var tone_mix = 0.42
	if heavy:
		start_freq = 112.0 + 10.0 * float(stage)
		end_freq = 308.0 + 18.0 * float(stage)
		duration = 0.24
		noise_mix = 0.3
		tone_mix = 0.34
		se.volume_db = -2.3
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
	var pitch_jitter = randf_range(0.97, 1.03)
	start_freq *= pitch_jitter
	end_freq *= pitch_jitter
	var delay_frames = int(0.016 * float(SWING_SE_MIX_RATE))
	var delay_buffer: Array[float] = []
	delay_buffer.resize(delay_frames + 1)
	for d in range(delay_buffer.size()):
		delay_buffer[d] = 0.0
	var delay_index = 0
	var lp = 0.0
	for i in range(write_count):
		var p = float(i) / float(maxi(1, total_frames - 1))
		var freq = lerpf(start_freq, end_freq, p)
		var t = float(i) / float(SWING_SE_MIX_RATE)
		var envelope = pow(1.0 - p, 1.65)
		var noise = randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.22 + 0.09 * p)
		var whoosh = noise - lp
		var tone = sin(TAU * freq * t)
		var sub = sin(TAU * (46.0 + 4.0 * float(stage)) * t) * exp(-4.2 * p)
		var scrape = sin(TAU * (freq * 1.44) * t + sin(TAU * 5.6 * t) * 0.26) * exp(-5.5 * p)
		var transient = exp(-60.0 * p) * randf_range(-1.0, 1.0)
		var dry = (
			tone * tone_mix
			+ sub * (0.64 if heavy else 0.52)
			+ scrape * (0.4 if heavy else 0.3)
			+ whoosh * noise_mix
			+ transient * 0.42
		) * envelope
		var delayed = delay_buffer[delay_index]
		var sample = dry + delayed * (0.4 if heavy else 0.3)
		delay_buffer[delay_index] = dry
		delay_index = (delay_index + 1) % delay_buffer.size()
		sample = sample / (1.0 + absf(sample) * 1.2)
		sample = clampf(sample, -1.0, 1.0)
		playback.push_frame(Vector2(sample, sample))
	get_tree().create_timer(duration + 0.1).timeout.connect(
		func() -> void:
			if is_instance_valid(se):
				se.queue_free()
	)

func _play_impact_se(heavy: bool) -> void:
	var se = AudioStreamPlayer2D.new()
	se.max_distance = 1700.0
	se.volume_db = -2.2 if heavy else -4.3
	var duration = 0.24 if heavy else 0.18
	var sub_freq = 42.0 if heavy else 58.0
	var body_freq = 94.0 if heavy else 128.0
	var clang_a = 230.0 if heavy else 310.0
	var clang_b = 420.0 if heavy else 590.0
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
	var delay_frames = int(0.02 * float(IMPACT_SE_MIX_RATE))
	var delay_buffer: Array[float] = []
	delay_buffer.resize(delay_frames + 1)
	for i in range(delay_buffer.size()):
		delay_buffer[i] = 0.0
	var delay_index = 0
	for i in range(write_count):
		var p = float(i) / float(maxi(1, total_frames - 1))
		var t = float(i) / float(IMPACT_SE_MIX_RATE)
		var env = pow(1.0 - p, 2.05)
		var sub = sin(TAU * sub_freq * t) * 0.92 * exp(-4.3 * p)
		var body = sin(TAU * body_freq * t) * 0.62 * exp(-6.5 * p)
		var clang = (sin(TAU * clang_a * t) * 0.28 + sin(TAU * clang_b * t) * 0.24) * exp(-11.0 * p)
		var crack = sin(TAU * (clang_b * 1.5) * t + sin(TAU * 11.0 * t) * 0.35) * exp(-15.0 * p) * (0.36 if heavy else 0.22)
		var grit = randf_range(-1.0, 1.0) * (0.44 if heavy else 0.32) * exp(-17.0 * p)
		var dry = (sub + body + clang + crack + grit) * env
		var delayed = delay_buffer[delay_index]
		var sample = dry + delayed * (0.48 if heavy else 0.36)
		delay_buffer[delay_index] = dry
		delay_index = (delay_index + 1) % delay_buffer.size()
		sample = sample / (1.0 + absf(sample) * 1.2)
		sample = clampf(sample, -1.0, 1.0)
		playback.push_frame(Vector2(sample, sample))
	get_tree().create_timer(duration + 0.12).timeout.connect(
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
		var color = Color(0.58, 0.9, 1.0, 0.95)
		if heavy:
			color = Color(1.0, 0.82, 0.42, 0.95)
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
		_enter_roll()

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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(draw_scale, draw_scale))
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
	var attack_pose = current_state in [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3, State.SKILL_1, State.SKILL_2]
	var attack_p = _attack_progress() if attack_pose else 0.0
	var roll_pose = current_state == State.ROLL
	var roll_total = maxf(0.001, roll_iframes + roll_recovery)
	var roll_p = 0.0
	if roll_pose:
		roll_p = 1.0 - clampf(state_timer / roll_total, 0.0, 1.0)

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
		var swing_bias = sin(attack_p * PI)
		head += Vector2(0.45 * facing, -0.7)
		neck += Vector2(0.65 * facing, -0.3)
		pelvis += Vector2(-0.8 * facing, 0.15)
		lead_knee += Vector2(0.9 * facing, 0.2)
		rear_knee += Vector2(-0.8 * facing, 0.4)
		lead_arm = Vector2((7.2 + 2.0 * swing_bias) * facing, -6.0 + 3.6 * attack_p)
		rear_arm = Vector2((-5.5 + 1.0 * swing_bias) * facing, -4.6)
	elif roll_pose:
		var tuck = sin(roll_p * PI)
		head += Vector2(-2.4 * facing, 2.8 + 0.8 * tuck)
		neck += Vector2(-1.9 * facing, 2.2 + 0.8 * tuck)
		pelvis += Vector2(-0.3 * facing, 2.0)
		lead_knee += Vector2(1.5 * facing, -1.6)
		rear_knee += Vector2(-1.6 * facing, -1.2)
		lead_foot += Vector2(-1.9 * facing, -2.1)
		rear_foot += Vector2(1.8 * facing, -1.6)
		lead_arm = Vector2(3.9 * facing, -1.1)
		rear_arm = Vector2(-4.3 * facing, -0.8)

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
			var after_alpha = (0.22 - 0.05 * float(i)) * dodge_fade
			draw_line(neck + after_offset, pelvis + after_offset, Color(0.66, 0.95, 1.0, after_alpha), 1.3)
			draw_circle(head + after_offset * 0.8, 2.3 - 0.3 * t, Color(0.66, 0.95, 1.0, after_alpha * 0.7))

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

	if wall_slide_active:
		var side_x = 5.6 * wall_slide_side
		draw_line(
			Vector2(side_x, -9.5),
			Vector2(side_x, 8.2),
			Color(0.9, 0.98, 1.0, 0.52),
			1.2
		)
		draw_circle(Vector2(side_x, 10.2), 1.2, Color(0.55, 0.9, 1.0, 0.7))

	var hp_ratio = 0.0
	if max_hp > 0:
		hp_ratio = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var hp_bg_rect = Rect2(Vector2(-14.0, -29.0), Vector2(28.0, 3.0))
	draw_rect(hp_bg_rect, Color(0.05, 0.05, 0.06, 0.88))
	draw_rect(
		Rect2(hp_bg_rect.position, Vector2(hp_bg_rect.size.x * hp_ratio, hp_bg_rect.size.y)),
		Color(1.0, 0.25 + 0.45 * hp_ratio, 0.28, 0.95)
	)
	if hp_ratio <= 0.3:
		draw_rect(hp_bg_rect.grow(0.9), Color(1.0, 0.2, 0.2, 0.45), false, 1.2)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
