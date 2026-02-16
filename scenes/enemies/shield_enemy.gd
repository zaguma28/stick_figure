extends BaseEnemy

func _ready() -> void:
	max_hp = 95; contact_damage = 20; move_speed = 70.0
	max_poise = 70.0; attack_range = 60.0
	attack_telegraph = 0.3; attack_duration = 0.35
	attack_cooldown = 1.2
	super()

func take_damage(amount: int, poise_dmg: int = 0, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	# 正面からの攻撃を80%軽減
	if knockback_dir != Vector2.ZERO and current_state != EnemyState.DOWN:
		var dot := facing_dir.dot(knockback_dir)
		if dot < -0.3:
			amount = int(amount * 0.2)
			poise_dmg = int(poise_dmg * 0.3)
	super.take_damage(amount, poise_dmg, knockback_dir)

func _draw() -> void:
	super()
	# 盾を描画（正面方向）
	if current_state != EnemyState.DOWN and current_state != EnemyState.DEAD:
		var shield_pos := facing_dir * 14
		var perp := Vector2(-facing_dir.y, facing_dir.x)
		draw_line(shield_pos - perp * 10, shield_pos + perp * 10, Color(0.6, 0.8, 1.0, 0.8), 3.0)
