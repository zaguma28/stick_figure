extends BaseEnemy

var bullet_scene: PackedScene = preload("res://scenes/enemies/bullet.tscn")
var retreat_range: float = 160.0
var advance_range: float = 360.0
var burst_count: int = 2
var telegraph_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	max_hp = 52
	contact_damage = 20
	move_speed = 115.0
	attack_range = 430.0
	attack_telegraph = 0.42
	attack_duration = 0.22
	attack_cooldown = 1.9
	engagement_height = 110.0
	super()

func _do_chase(delta: float) -> void:
	if not target:
		velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
		return

	var dx = target.global_position.x - global_position.x
	var abs_dx = absf(dx)
	var dir_to_target = signf(dx)
	if dir_to_target == 0.0:
		dir_to_target = 1.0
	facing_dir = Vector2(dir_to_target, 0.0)

	var move_dir = 0.0
	if abs_dx < retreat_range:
		move_dir = -dir_to_target
	elif abs_dx > advance_range:
		move_dir = dir_to_target

	var desired_speed = move_dir * move_speed
	var accel = ground_accel if is_on_floor() else ground_accel * air_control
	velocity.x = move_toward(velocity.x, desired_speed, accel * delta)

func _execute_attack() -> void:
	current_state = EnemyState.ATTACK
	state_timer = attack_duration
	_fire_burst()

func _check_attack_range() -> void:
	if not target or attack_cd_timer > 0:
		return
	var dx = absf(global_position.x - target.global_position.x)
	var dy = absf(global_position.y - target.global_position.y)
	if dx < attack_range and dy < engagement_height:
		telegraph_dir = _get_shot_direction()
		current_state = EnemyState.TELEGRAPH
		state_timer = attack_telegraph
		has_hit_this_attack = false

func _do_attack() -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_accel * 0.8 * get_physics_process_delta_time())
	if state_timer <= 0:
		attack_cd_timer = attack_cooldown
		current_state = EnemyState.CHASE

func _get_shot_direction() -> Vector2:
	if target:
		var to_target = target.global_position - global_position
		if to_target.length() > 0.001:
			var aimed = to_target.normalized()
			aimed.y = clampf(aimed.y, -0.38, 0.24)
			return aimed.normalized()
	var dir_x = 1.0 if facing_dir.x >= 0.0 else -1.0
	return Vector2(dir_x, 0.0)

func _fire_burst() -> void:
	var base_dir = _get_shot_direction()
	telegraph_dir = base_dir
	for i in range(burst_count):
		var spread = -0.04 + 0.08 * float(i) / float(maxi(1, burst_count - 1))
		var dir = base_dir.rotated(spread).normalized()
		var bullet = bullet_scene.instantiate()
		bullet.direction = dir
		bullet.damage = int(round(float(contact_damage) * (1.05 if i == 0 else 0.9)))
		bullet.speed = 470.0
		bullet.lifetime = 2.7
		bullet.global_position = global_position + Vector2(12.0 * dir.x, -8.0 + float(i))
		get_parent().add_child(bullet)

func _draw() -> void:
	super()
	if current_state != EnemyState.TELEGRAPH:
		return
	var dir = telegraph_dir
	if dir.length() <= 0.001:
		dir = _get_shot_direction()
	dir = dir.normalized()
	var start = Vector2(12.0 * signf(dir.x), -8.0)
	var end = start + dir * 250.0
	var c = Color(0.78, 1.0, 0.88, 0.58)
	draw_line(start, end, c, 1.35)
	draw_arc(end, 8.0, 0.0, TAU, 22, Color(0.84, 1.0, 0.92, 0.42), 1.15)
	draw_circle(end, 2.0, Color(0.9, 1.0, 0.96, 0.66))
