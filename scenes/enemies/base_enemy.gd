extends CharacterBody2D
class_name BaseEnemy

enum EnemyState { IDLE, CHASE, TELEGRAPH, ATTACK, STAGGER, DOWN, DEAD }
const ENEMY_DEATH_FX_SCRIPT := preload("res://scenes/effects/enemy_death_fx.gd")

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
@export var separation_radius: float = 30.0
@export var separation_force: float = 360.0
@export var separation_vertical_tolerance: float = 56.0
@export var knockback_impulse_x: float = 220.0
@export var knockback_impulse_y: float = 28.0
@export var knockback_decay: float = 10.0

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
	_apply_enemy_separation(delta)
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

func _apply_enemy_separation(delta: float) -> void:
	if current_state not in [EnemyState.IDLE, EnemyState.CHASE, EnemyState.TELEGRAPH]:
		return
	if separation_radius <= 0.0 or separation_force <= 0.0:
		return

	var push_x := 0.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self:
			continue
		var other := node as BaseEnemy
		if not other or other.current_state == EnemyState.DEAD:
			continue
		if absf(global_position.y - other.global_position.y) > separation_vertical_tolerance:
			continue

		var delta_x := global_position.x - other.global_position.x
		var dist_x := absf(delta_x)
		if dist_x >= separation_radius:
			continue

		var dir_x := signf(delta_x)
		if dir_x == 0.0:
			dir_x = 1.0 if get_instance_id() > other.get_instance_id() else -1.0
		var overlap_ratio := 1.0 - clampf(dist_x / separation_radius, 0.0, 1.0)
		push_x += dir_x * separation_force * overlap_ratio

	if absf(push_x) <= 0.01:
		return
	velocity.x += push_x * delta
	var max_separation_speed := move_speed * 1.75
	velocity.x = clampf(velocity.x, -max_separation_speed, max_separation_speed)

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
	if knockback_vel.length() <= 0.6:
		knockback_vel = Vector2.ZERO
		return
	velocity.x += knockback_vel.x * delta
	if knockback_vel.y < 0.0:
		velocity.y += knockback_vel.y * delta
	var t := clampf(knockback_decay * delta, 0.0, 1.0)
	knockback_vel = knockback_vel.lerp(Vector2.ZERO, t)

func take_damage(amount: int, poise_dmg: int = 0, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if current_state == EnemyState.DEAD:
		return

	hp -= amount

	if knockback_dir != Vector2.ZERO:
		var push := knockback_dir.normalized()
		if absf(push.x) < 0.1:
			push.x = -facing_dir.x
		knockback_vel = Vector2(push.x * knockback_impulse_x, -knockback_impulse_y)

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
	collision_layer = 0
	collision_mask = 0
	_spawn_death_fx()
	emit_signal("enemy_died", self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _spawn_death_fx() -> void:
	var parent_node := get_parent()
	if not parent_node:
		return
	var fx := Node2D.new()
	fx.set_script(ENEMY_DEATH_FX_SCRIPT)
	fx.global_position = global_position + Vector2(0.0, -8.0)
	if fx.has_method("configure"):
		var fx_radius := 22.0 if max_hp >= 500 else 14.0
		fx.call("configure", Color(1.0, 0.42, 0.22, 0.95), fx_radius)
	parent_node.add_child(fx)

func _draw() -> void:
	var c := Color(0.9, 0.35, 0.24)
	match current_state:
		EnemyState.TELEGRAPH:
			c = Color(1.0, 0.84, 0.2)
		EnemyState.DOWN:
			c = Color(0.55, 0.55, 0.55)
		EnemyState.STAGGER:
			c = Color(1.0, 0.56, 0.2)

	var facing := 1.0 if facing_dir.x >= 0.0 else -1.0
	var walk := 0.0
	if current_state == EnemyState.CHASE and absf(velocity.x) > 10.0:
		walk = sin(float(Time.get_ticks_msec()) * 0.018) * 3.0

	draw_circle(Vector2(0, 14), 7.5, Color(0.0, 0.0, 0.0, 0.22))

	var head := Vector2(0, -16)
	var neck := Vector2(0, -9)
	var pelvis := Vector2(0, 2)
	var front_foot := Vector2(5.2 * facing + walk, 14)
	var back_foot := Vector2(-5.0 * facing - walk * 0.7, 13)
	var front_hand := Vector2(6.5 * facing, -2.5 + walk * 0.25)
	var back_hand := Vector2(-6.0 * facing, -3.2 - walk * 0.22)

	draw_line(neck, pelvis, c, 2.4)
	draw_line(pelvis, front_foot, c.darkened(0.1), 2.2)
	draw_line(pelvis, back_foot, c.darkened(0.25), 2.2)
	draw_line(neck, front_hand, c.darkened(0.06), 2.1)
	draw_line(neck, back_hand, c.darkened(0.28), 2.0)
	draw_circle(head, 4.8, c.lightened(0.08))
	draw_circle(head + Vector2(1.8 * facing, -0.6), 0.9, Color(0.06, 0.06, 0.08))

	if current_state == EnemyState.TELEGRAPH:
		draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 32, Color(1.0, 0.72, 0.18, 0.45), 1.6)

	var hp_bar_width := 26.0
	var hp_y := -27.0
	var hp_ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	draw_rect(Rect2(-hp_bar_width * 0.5, hp_y, hp_bar_width, 3.0), Color(0.15, 0.15, 0.15, 0.8))
	draw_rect(Rect2(-hp_bar_width * 0.5, hp_y, hp_bar_width * hp_ratio, 3.0), Color(0.92, 0.2, 0.2, 0.9))

	if poise < max_poise:
		var poise_ratio := clampf(poise / max_poise, 0.0, 1.0)
		draw_rect(Rect2(-hp_bar_width * 0.5, hp_y - 4.6, hp_bar_width, 2.0), Color(0.15, 0.15, 0.15, 0.7))
		draw_rect(Rect2(-hp_bar_width * 0.5, hp_y - 4.6, hp_bar_width * poise_ratio, 2.0), Color(1.0, 0.82, 0.25, 0.9))
