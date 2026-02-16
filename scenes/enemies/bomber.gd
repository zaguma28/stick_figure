extends BaseEnemy

var explosion_radius: float = 80.0

func _ready() -> void:
	max_hp = 35; contact_damage = 32; move_speed = 130.0
	attack_range = 50.0; attack_telegraph = 0.45
	attack_duration = 0.1; attack_cooldown = 99.0
	super()

func _execute_attack() -> void:
	current_state = EnemyState.ATTACK
	state_timer = attack_duration
	# 範囲内の全プレイヤーにダメージ
	if target:
		if global_position.distance_to(target.global_position) < explosion_radius:
			_deal_damage_to_player(contact_damage)
	_die()

func _draw() -> void:
	var c := Color(1.0, 0.2, 0.0)
	match current_state:
		EnemyState.TELEGRAPH: c = Color(1.0, 0.0, 0.0)
		EnemyState.DOWN: c = Color(0.5, 0.5, 0.5)
	# 爆弾型の棒人間（丸い体）
	draw_circle(Vector2(0, -12), 10, c)
	draw_line(Vector2(0, -2), Vector2(-6, 14), c, 2.0)
	draw_line(Vector2(0, -2), Vector2(6, 14), c, 2.0)
	# 導火線
	if current_state == EnemyState.TELEGRAPH:
		draw_line(Vector2(0, -22), Vector2(4, -30), Color(1.0, 1.0, 0.0), 2.0)
	# HP bar
	var bw := 30.0; var by := -38.0
	var hr := clampf(float(hp) / float(max_hp), 0, 1)
	draw_rect(Rect2(-bw / 2, by, bw, 3), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-bw / 2, by, bw * hr, 3), Color(1.0, 0.2, 0.2))
