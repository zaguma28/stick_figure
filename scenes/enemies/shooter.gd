extends BaseEnemy

var bullet_scene: PackedScene = preload("res://scenes/enemies/bullet.tscn")

func _ready() -> void:
	max_hp = 40; contact_damage = 16; move_speed = 60.0
	attack_range = 300.0; attack_telegraph = 0.3
	attack_duration = 0.2; attack_cooldown = 1.3
	super()

func _execute_attack() -> void:
	current_state = EnemyState.ATTACK
	state_timer = attack_duration
	_fire_bullet(facing_dir)

func _do_attack() -> void:
	if state_timer <= 0:
		attack_cd_timer = attack_cooldown
		current_state = EnemyState.CHASE

func _fire_bullet(dir: Vector2) -> void:
	var b = bullet_scene.instantiate()
	b.direction = dir.normalized()
	b.damage = contact_damage
	b.global_position = global_position
	get_parent().add_child(b)
