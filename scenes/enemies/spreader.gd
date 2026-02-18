extends BaseEnemy

var bullet_scene: PackedScene = preload("res://scenes/enemies/bullet.tscn")
var spread_angle: float = 18.0

func _ready() -> void:
	max_hp = 48
	contact_damage = 14
	move_speed = 55.0
	attack_range = 280.0
	attack_telegraph = 0.4
	attack_duration = 0.2
	attack_cooldown = 2.2
	super()

func _execute_attack() -> void:
	current_state = EnemyState.ATTACK
	state_timer = attack_duration
	var base_dir = _get_shot_direction()
	for offset in [-spread_angle, 0.0, spread_angle]:
		var dir = base_dir.rotated(deg_to_rad(offset)).normalized()
		var b = bullet_scene.instantiate()
		b.direction = dir
		b.damage = contact_damage
		b.global_position = global_position + Vector2(10.0 * dir.x, -6.0)
		get_parent().add_child(b)

func _do_attack() -> void:
	if state_timer <= 0:
		attack_cd_timer = attack_cooldown
		current_state = EnemyState.CHASE

func _get_shot_direction() -> Vector2:
	if target:
		var to_target = target.global_position - global_position
		if to_target.length() > 0.001:
			var aimed = to_target.normalized()
			aimed.y = clampf(aimed.y, -0.5, 0.4)
			return aimed.normalized()
	var dir_x = 1.0 if facing_dir.x >= 0.0 else -1.0
	return Vector2(dir_x, 0.0)
