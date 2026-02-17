extends CharacterBody2D
class_name BaseEnemy

enum EnemyState { IDLE, CHASE, TELEGRAPH, ATTACK, STAGGER, DOWN, DEAD }

@export var max_hp: int = 50
@export var move_speed: float = 100.0
@export var contact_damage: int = 15
@export var max_poise: float = 40.0
@export var poise_regen_rate: float = 8.0
@export var down_duration: float = 1.2
@export var gravity: float = 1750.0
@export var max_fall_speed: float = 1300.0
@export var ground_accel: float = 1700.0
@export var air_control: float = 0.45
@export var engagement_height: float = 92.0

var hp: int
var poise: float
var current_state: EnemyState = EnemyState.IDLE
var state_timer: float = 0.0
var facing_dir: Vector2 = Vector2.RIGHT
var target: Node2D = null
var knockback_vel: Vector2 = Vector2.ZERO

var attack_range: float = 40.0
var attack_telegraph: float = 0.3
var attack_duration: float = 0.3
var attack_cooldown: float = 1.0
var attack_cd_timer: float = 0.0
var has_hit_this_attack: bool = false
var poise_delay_timer: float = 0.0
var floor_hp_scale: float = 1.0
var floor_damage_scale: float = 1.0

signal enemy_died(enemy: Node2D)

func apply_floor_scaling(hp_scale: float, damage_scale: float) -> void:
	floor_hp_scale = hp_scale
	floor_damage_scale = damage_scale
	max_hp = maxi(1, int(round(float(max_hp) * floor_hp_scale)))
	contact_damage = maxi(1, int(round(float(contact_damage) * floor_damage_scale)))
	hp = max_hp

func _ready() -> void:
	hp = max_hp
	poise = max_poise
	add_to_group("enemies")
	target = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if current_state == EnemyState.DEAD:
		return

	if not target:
		target = get_tree().get_first_node_in_group("player")

	_update_timers(delta)
	_update_state(delta)
	_apply_gravity(delta)
	_apply_knockback(delta)

	if absf(velocity.x) > 5.0:
		facing_dir = Vector2(signf(velocity.x), 0.0)

	move_and_slide()
	queue_redraw()

func _update_timers(delta: float) -> void:
	if state_timer > 0:
		state_timer -= delta
	if attack_cd_timer > 0:
		attack_cd_timer -= delta
	if poise_delay_timer > 0:
		poise_delay_timer -= delta
	elif poise < max_poise and current_state != EnemyState.DOWN:
		poise = minf(poise + poise_regen_rate * delta, max_poise)

func _update_state(delta: float) -> void:
	match current_state:
		EnemyState.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
			if target:
				current_state = EnemyState.CHASE

		EnemyState.CHASE:
			_do_chase(delta)
			_check_attack_range()

		EnemyState.TELEGRAPH:
			velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
			if state_timer <= 0:
				_execute_attack()

		EnemyState.ATTACK:
			_do_attack()

		EnemyState.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
			if state_timer <= 0:
				current_state = EnemyState.CHASE

		EnemyState.DOWN:
			velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
			if state_timer <= 0:
				poise = max_poise
				current_state = EnemyState.CHASE

func _do_chase(delta: float) -> void:
	if not target:
		velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
		return

	var dx := target.global_position.x - global_position.x
	var dir_x := signf(dx)
	if absf(dx) < 8.0:
		dir_x = 0.0

	if dir_x != 0.0:
		facing_dir = Vector2(dir_x, 0.0)

	var desired_speed := dir_x * move_speed
	var accel := ground_accel if is_on_floor() else ground_accel * air_control
	velocity.x = move_toward(velocity.x, desired_speed, accel * delta)

func _check_attack_range() -> void:
	if not target or attack_cd_timer > 0:
		return

	var dx := absf(global_position.x - target.global_position.x)
	var dy := absf(global_position.y - target.global_position.y)
	if dx < attack_range and dy < engagement_height:
		current_state = EnemyState.TELEGRAPH
		state_timer = attack_telegraph
		has_hit_this_attack = false

func _execute_attack() -> void:
	current_state = EnemyState.ATTACK
	state_timer = attack_duration

func _do_attack() -> void:
	if not has_hit_this_attack and target:
		var dx := absf(global_position.x - target.global_position.x)
		var dy := absf(global_position.y - target.global_position.y)
		if dx < attack_range * 1.3 and dy < engagement_height:
			_deal_damage_to_player(contact_damage)
			has_hit_this_attack = true

	if state_timer <= 0:
		attack_cd_timer = attack_cooldown
		current_state = EnemyState.CHASE

func _deal_damage_to_player(amount: int) -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(amount, 0, self)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _apply_knockback(delta: float) -> void:
	if knockback_vel.length() > 5.0:
		velocity += knockback_vel
		knockback_vel = knockback_vel.lerp(Vector2.ZERO, 8.0 * delta)
	else:
		knockback_vel = Vector2.ZERO

func take_damage(amount: int, poise_dmg: int = 0, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if current_state == EnemyState.DEAD:
		return

	hp -= amount

	if knockback_dir != Vector2.ZERO:
		var push := knockback_dir.normalized()
		if absf(push.x) < 0.1:
			push.x = -facing_dir.x
		knockback_vel = Vector2(push.x * 240.0, -90.0)

	if poise_dmg > 0:
		poise -= poise_dmg
		poise_delay_timer = 1.0
		if poise <= 0 and current_state != EnemyState.DOWN:
			poise = 0
			current_state = EnemyState.DOWN
			state_timer = down_duration

	if hp <= 0:
		hp = 0
		_die()

func _die() -> void:
	current_state = EnemyState.DEAD
	emit_signal("enemy_died", self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var c := Color(0.86, 0.36, 0.28)
	match current_state:
		EnemyState.TELEGRAPH:
			c = Color(1.0, 0.9, 0.25)
		EnemyState.DOWN:
			c = Color(0.5, 0.5, 0.5)
		EnemyState.STAGGER:
			c = Color(1.0, 0.58, 0.26)

	var facing := 1.0 if facing_dir.x >= 0.0 else -1.0
	var step := 0.0
	if current_state == EnemyState.CHASE and absf(velocity.x) > 10.0:
		step = sin(float(Time.get_ticks_msec()) * 0.016) * 3.4

	draw_circle(Vector2(0, 20), 11.5, Color(0.0, 0.0, 0.0, 0.2))

	var hip := Vector2(0, 6)
	var left_foot := Vector2(-7.0 + step, 24.0)
	var right_foot := Vector2(7.0 - step, 24.0)
	draw_line(hip, left_foot, c.darkened(0.2), 3.0)
	draw_line(hip, right_foot, c.darkened(0.05), 3.0)

	draw_rect(Rect2(-7.0, -20.0, 14.0, 26.0), c)
	draw_circle(Vector2(0, -29), 8.0, c.lightened(0.06))
	draw_circle(Vector2(3.0 * facing, -30), 1.2, Color(0.08, 0.08, 0.1))

	var shoulder := Vector2(0, -12)
	var lead_arm := Vector2(10.0 * facing, -8.0 + step * 0.35)
	var rear_arm := Vector2(-8.0 * facing, -11.0 - step * 0.25)
	draw_line(shoulder, lead_arm, c.darkened(0.1), 3.0)
	draw_line(shoulder, rear_arm, c.darkened(0.25), 3.0)

	var hp_bar_width := 34.0
	var hp_y := -40.0
	var hp_ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	draw_rect(Rect2(-hp_bar_width * 0.5, hp_y, hp_bar_width, 4.0), Color(0.15, 0.15, 0.15, 0.8))
	draw_rect(Rect2(-hp_bar_width * 0.5, hp_y, hp_bar_width * hp_ratio, 4.0), Color(0.92, 0.2, 0.2, 0.9))

	if poise < max_poise:
		var poise_ratio := clampf(poise / max_poise, 0.0, 1.0)
		draw_rect(Rect2(-hp_bar_width * 0.5, hp_y - 6.0, hp_bar_width, 2.5), Color(0.15, 0.15, 0.15, 0.7))
		draw_rect(Rect2(-hp_bar_width * 0.5, hp_y - 6.0, hp_bar_width * poise_ratio, 2.5), Color(1.0, 0.82, 0.25, 0.9))
