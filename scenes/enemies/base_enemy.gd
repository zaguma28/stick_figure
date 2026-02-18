extends CharacterBody2D
class_name BaseEnemy

enum EnemyState { IDLE, CHASE, TELEGRAPH, ATTACK, STAGGER, DOWN, DEAD }
const ENEMY_DEATH_FX_SCRIPT := preload("res://scenes/effects/enemy_death_fx.gd")
static var death_fx_enabled: bool = false

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
@export var knockback_impulse_x: float = 140.0
@export var knockback_impulse_y: float = 8.0
@export var knockback_decay: float = 16.0
@export var knockback_max_speed_x: float = 180.0
@export var hit_recoil_duration: float = 0.08

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
var hit_recoil_timer: float = 0.0

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
	if hit_recoil_timer > 0:
		hit_recoil_timer -= delta
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
			if hit_recoil_timer > 0.0:
				velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
			else:
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

	var dx = target.global_position.x - global_position.x
	var dir_x = signf(dx)
	if absf(dx) < 8.0:
		dir_x = 0.0

	if dir_x != 0.0:
		facing_dir = Vector2(dir_x, 0.0)

	var desired_speed = dir_x * move_speed
	var accel = ground_accel if is_on_floor() else ground_accel * air_control
	velocity.x = move_toward(velocity.x, desired_speed, accel * delta)

func _apply_enemy_separation(delta: float) -> void:
	if current_state not in [EnemyState.IDLE, EnemyState.CHASE, EnemyState.TELEGRAPH]:
		return
	if separation_radius <= 0.0 or separation_force <= 0.0:
		return

	var push_x = 0.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self:
			continue
		var other = node as BaseEnemy
		if not other or other.current_state == EnemyState.DEAD:
			continue
		if absf(global_position.y - other.global_position.y) > separation_vertical_tolerance:
			continue

		var delta_x = global_position.x - other.global_position.x
		var dist_x = absf(delta_x)
		if dist_x >= separation_radius:
			continue

		var dir_x = signf(delta_x)
		if dir_x == 0.0:
			dir_x = 1.0 if get_instance_id() > other.get_instance_id() else -1.0
		var overlap_ratio = 1.0 - clampf(dist_x / separation_radius, 0.0, 1.0)
		push_x += dir_x * separation_force * overlap_ratio

	if absf(push_x) <= 0.01:
		return
	velocity.x += push_x * delta
	var max_separation_speed = move_speed * 1.75
	velocity.x = clampf(velocity.x, -max_separation_speed, max_separation_speed)

func _check_attack_range() -> void:
	if not target or attack_cd_timer > 0:
		return

	var dx = absf(global_position.x - target.global_position.x)
	var dy = absf(global_position.y - target.global_position.y)
	if dx < attack_range and dy < engagement_height:
		current_state = EnemyState.TELEGRAPH
		state_timer = attack_telegraph
		has_hit_this_attack = false

func _execute_attack() -> void:
	current_state = EnemyState.ATTACK
	state_timer = attack_duration

func _do_attack() -> void:
	if not has_hit_this_attack and target:
		var dx = absf(global_position.x - target.global_position.x)
		var dy = absf(global_position.y - target.global_position.y)
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
	if absf(knockback_vel.x) <= 0.8 and absf(knockback_vel.y) <= 0.8:
		knockback_vel = Vector2.ZERO
		return
	velocity.x += knockback_vel.x * delta
	if knockback_vel.y < 0.0:
		velocity.y = minf(velocity.y, knockback_vel.y)
	var t = clampf(knockback_decay * delta, 0.0, 1.0)
	knockback_vel.x = lerpf(knockback_vel.x, 0.0, t)
	knockback_vel.y = lerpf(knockback_vel.y, 0.0, minf(1.0, t * 1.25))

func take_damage(amount: int, poise_dmg: int = 0, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if current_state == EnemyState.DEAD:
		return

	hp -= amount

	if knockback_dir != Vector2.ZERO:
		var push = knockback_dir.normalized()
		if absf(push.x) < 0.1:
			push.x = -facing_dir.x
		knockback_vel.x = clampf(
			knockback_vel.x * 0.3 + push.x * knockback_impulse_x,
			-knockback_max_speed_x,
			knockback_max_speed_x
		)
		if knockback_impulse_y > 0.0:
			knockback_vel.y = minf(knockback_vel.y, -knockback_impulse_y)
		hit_recoil_timer = hit_recoil_duration

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
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _spawn_death_fx() -> void:
	if not BaseEnemy.death_fx_enabled:
		return
	var parent_node = get_parent()
	if not parent_node:
		return
	var fx = Node2D.new()
	fx.set_script(ENEMY_DEATH_FX_SCRIPT)
	fx.global_position = global_position + Vector2(0.0, -8.0)
	if fx.has_method("configure"):
		var fx_radius = 13.0
		var se_variant = "normal"
		if max_hp >= 500:
			fx_radius = 22.0
			se_variant = "boss"
		elif max_hp >= 90:
			fx_radius = 16.0
			se_variant = "elite"
		fx.call("configure", Color(1.0, 0.42, 0.22, 0.95), fx_radius, se_variant)
	parent_node.add_child(fx)

func _enemy_visual_kind() -> String:
	if get_script() is Script:
		var script_path = String((get_script() as Script).resource_path)
		if script_path.ends_with("charger.gd"):
			return "charger"
		if script_path.ends_with("shooter.gd"):
			return "shooter"
		if script_path.ends_with("spreader.gd"):
			return "spreader"
		if script_path.ends_with("shield_enemy.gd"):
			return "shield"
		if script_path.ends_with("bomber.gd"):
			return "bomber"
		if script_path.ends_with("summoner.gd"):
			return "summoner"
		if script_path.ends_with("hunter_drone.gd"):
			return "hunter"
	return "base"

func _draw_poly_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in range(points.size()):
		var a = points[i]
		var b = points[(i + 1) % points.size()]
		draw_line(a, b, color, width)

func _draw() -> void:
	var c = Color(0.9, 0.35, 0.24)
	var accent = Color(1.0, 0.74, 0.5)
	var core = Color(0.32, 0.08, 0.07)
	var kind = _enemy_visual_kind()
	match kind:
		"charger":
			c = Color(0.96, 0.34, 0.2)
			accent = Color(1.0, 0.78, 0.48)
		"shooter":
			c = Color(0.28, 0.86, 1.0)
			accent = Color(0.82, 0.98, 1.0)
			core = Color(0.04, 0.18, 0.26)
		"spreader":
			c = Color(0.9, 0.46, 1.0)
			accent = Color(1.0, 0.8, 1.0)
			core = Color(0.2, 0.06, 0.24)
		"shield":
			c = Color(0.44, 0.78, 1.0)
			accent = Color(0.88, 0.98, 1.0)
			core = Color(0.06, 0.16, 0.24)
		"bomber":
			c = Color(1.0, 0.52, 0.16)
			accent = Color(1.0, 0.84, 0.52)
			core = Color(0.28, 0.1, 0.02)
		"summoner":
			c = Color(0.76, 0.35, 1.0)
			accent = Color(0.9, 0.76, 1.0)
			core = Color(0.16, 0.04, 0.22)
		"hunter":
			c = Color(0.3, 1.0, 0.7)
			accent = Color(0.82, 1.0, 0.9)
			core = Color(0.04, 0.2, 0.14)
		_:
			pass
	match current_state:
		EnemyState.TELEGRAPH:
			c = Color(1.0, 0.84, 0.2)
			accent = Color(1.0, 0.94, 0.45)
		EnemyState.DOWN:
			c = Color(0.55, 0.55, 0.55)
			accent = Color(0.78, 0.78, 0.78)
			core = Color(0.14, 0.14, 0.14)
		EnemyState.STAGGER:
			c = Color(1.0, 0.56, 0.2)
			accent = Color(1.0, 0.82, 0.4)

	var facing = 1.0 if facing_dir.x >= 0.0 else -1.0
	var hover = 0.0
	if current_state == EnemyState.CHASE and absf(velocity.x) > 10.0:
		hover = sin(float(Time.get_ticks_msec()) * 0.022) * 1.6

	draw_circle(Vector2(0, 13.0), 6.8, Color(0.0, 0.0, 0.0, 0.18))

	var shell = PackedVector2Array([
		Vector2(0.0, -16.0),
		Vector2(9.4, -8.8),
		Vector2(10.8, 3.1),
		Vector2(0.0, 12.2),
		Vector2(-10.8, 3.1),
		Vector2(-9.4, -8.8)
	])
	for i in range(shell.size()):
		shell[i] += Vector2(0.0, hover - 1.2)
	draw_colored_polygon(shell, c)
	_draw_poly_outline(shell, c.darkened(0.38), 1.15)

	var front_horn = PackedVector2Array([
		Vector2(7.8 * facing, -5.6 + hover),
		Vector2(14.4 * facing, -2.8 + hover),
		Vector2(8.2 * facing, -0.2 + hover)
	])
	draw_colored_polygon(front_horn, c.lightened(0.12))

	var rear_fin = PackedVector2Array([
		Vector2(-7.4 * facing, -6.2 + hover),
		Vector2(-12.8 * facing, -2.0 + hover),
		Vector2(-7.8 * facing, 0.8 + hover)
	])
	draw_colored_polygon(rear_fin, c.darkened(0.12))

	var core_pos = Vector2(1.3 * facing, -2.8 + hover)
	draw_circle(core_pos, 4.3, core)
	draw_circle(core_pos + Vector2(0.5 * facing, -0.3), 3.1, accent)
	draw_circle(core_pos + Vector2(1.35 * facing, -0.2), 0.9, Color(0.03, 0.03, 0.04, 0.95))

	if kind == "spreader":
		draw_line(
			Vector2(-8.5 * facing, -2.5 + hover),
			Vector2(8.5 * facing, -2.5 + hover),
			Color(accent.r, accent.g, accent.b, 0.55),
			1.2
		)
	if kind == "shooter":
		draw_arc(
			Vector2(2.0 * facing, -2.0 + hover),
			5.4,
			-0.42 * PI if facing > 0.0 else 0.58 * PI,
			0.42 * PI if facing > 0.0 else 1.42 * PI,
			16,
			Color(0.82, 0.98, 1.0, 0.58),
			1.2
		)
	if kind == "summoner":
		draw_arc(
			Vector2(0.0, -18.5 + hover),
			6.2,
			0.0,
			TAU,
			24,
			Color(0.85, 0.44, 1.0, 0.42),
			1.25
		)
	if kind == "hunter":
		draw_line(
			Vector2(-7.0 * facing, -9.0 + hover),
			Vector2(10.0 * facing, -9.0 + hover),
			Color(0.7, 1.0, 0.86, 0.56),
			1.35
		)
		draw_circle(Vector2(11.5 * facing, -9.0 + hover), 1.6, Color(0.88, 1.0, 0.94, 0.74))
	if kind == "bomber":
		var pulse = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.03)
		draw_circle(
			Vector2(0.0, -18.8 + hover),
			2.0 + pulse * 0.9,
			Color(1.0, 0.56 + pulse * 0.28, 0.2, 0.78)
		)

	if current_state == EnemyState.TELEGRAPH:
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 28, Color(1.0, 0.72, 0.18, 0.45), 1.4)

	var hp_bar_width = 26.0
	var hp_y = -27.0
	var hp_ratio = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	draw_rect(Rect2(-hp_bar_width * 0.5, hp_y, hp_bar_width, 3.0), Color(0.15, 0.15, 0.15, 0.8))
	draw_rect(Rect2(-hp_bar_width * 0.5, hp_y, hp_bar_width * hp_ratio, 3.0), Color(0.92, 0.2, 0.2, 0.9))

	if poise < max_poise:
		var poise_ratio = clampf(poise / max_poise, 0.0, 1.0)
		draw_rect(Rect2(-hp_bar_width * 0.5, hp_y - 4.6, hp_bar_width, 2.0), Color(0.15, 0.15, 0.15, 0.7))
		draw_rect(Rect2(-hp_bar_width * 0.5, hp_y - 4.6, hp_bar_width * poise_ratio, 2.0), Color(1.0, 0.82, 0.25, 0.9))
