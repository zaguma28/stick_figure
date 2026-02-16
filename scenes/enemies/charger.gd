extends BaseEnemy

var charge_speed: float = 450.0

func _ready() -> void:
	max_hp = 55; contact_damage = 22; move_speed = 100.0
	attack_range = 150.0; attack_telegraph = 0.35
	attack_duration = 0.5; attack_cooldown = 1.5
	super()

func _execute_attack() -> void:
	current_state = EnemyState.ATTACK
	state_timer = attack_duration
	velocity = facing_dir * charge_speed

func _do_attack() -> void:
	if not has_hit_this_attack and target:
		if global_position.distance_to(target.global_position) < 30.0:
			_deal_damage_to_player(contact_damage)
			has_hit_this_attack = true
	if state_timer <= 0:
		attack_cd_timer = attack_cooldown
		current_state = EnemyState.CHASE
