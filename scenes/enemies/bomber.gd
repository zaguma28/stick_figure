extends BaseEnemy

var explosion_radius: float = 80.0

func _ready() -> void:
	max_hp = 35
	contact_damage = 32
	move_speed = 130.0
	attack_range = 50.0
	attack_telegraph = 0.45
	attack_duration = 0.1
	attack_cooldown = 99.0
	super()

func _execute_attack() -> void:
	current_state = EnemyState.ATTACK
	state_timer = attack_duration
	if target:
		var dx := absf(global_position.x - target.global_position.x)
		var dy := absf(global_position.y - target.global_position.y)
		if dx < explosion_radius and dy < 90.0:
			_deal_damage_to_player(contact_damage)
	_die()

func _draw() -> void:
	super()

	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.03)
	var fuse_color := Color(1.0, 0.45, 0.15)
	if current_state == EnemyState.TELEGRAPH:
		fuse_color = Color(1.0, 0.9 * pulse, 0.1)

	draw_circle(Vector2(0, -38), 4.2, fuse_color)
	draw_line(Vector2(0, -34), Vector2(0, -26), Color(0.1, 0.1, 0.1), 2.0)
	draw_circle(Vector2(0, -8), 8.0, Color(0.3, 0.24, 0.18, 0.75))

	if current_state == EnemyState.TELEGRAPH:
		draw_arc(Vector2.ZERO, explosion_radius * 0.55, PI, TAU, 32, Color(1.0, 0.18, 0.08, 0.55), 2.0)
