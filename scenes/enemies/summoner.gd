extends BaseEnemy

var bullet_scene: PackedScene = preload("res://scenes/enemies/bullet.tscn")
var enemy_scene: PackedScene = preload("res://scenes/enemies/base_enemy.tscn")
var summon_cd: float = 6.5
var summon_cd_timer: float = 3.0
var max_minions: int = 2

func _ready() -> void:
	max_hp = 70
	contact_damage = 12
	move_speed = 50.0
	attack_range = 350.0
	attack_telegraph = 0.3
	attack_duration = 0.3
	attack_cooldown = 2.0
	super()

func _update_timers(delta: float) -> void:
	super(delta)
	if summon_cd_timer > 0:
		summon_cd_timer -= delta

func _execute_attack() -> void:
	current_state = EnemyState.ATTACK
	state_timer = attack_duration

	var b = bullet_scene.instantiate()
	b.direction = _get_shot_direction()
	b.damage = contact_damage
	b.global_position = global_position + Vector2(10.0 * b.direction.x, -8.0)
	get_parent().add_child(b)

	if summon_cd_timer <= 0:
		_summon_minions()
		summon_cd_timer = summon_cd

func _do_attack() -> void:
	if state_timer <= 0:
		attack_cd_timer = attack_cooldown
		current_state = EnemyState.CHASE

func _get_shot_direction() -> Vector2:
	if target:
		var to_target := target.global_position - global_position
		if to_target.length() > 0.001:
			var aimed := to_target.normalized()
			aimed.y = clampf(aimed.y, -0.45, 0.35)
			return aimed.normalized()
	var dir_x := 1.0 if facing_dir.x >= 0.0 else -1.0
	return Vector2(dir_x, 0.0)

func _summon_minions() -> void:
	for i in range(max_minions):
		var minion = enemy_scene.instantiate()
		minion.max_hp = 25
		minion.contact_damage = 12
		minion.move_speed = 130.0
		minion.max_poise = 20.0
		if minion.has_method("apply_floor_scaling"):
			minion.apply_floor_scaling(floor_hp_scale, floor_damage_scale)
		var offset := Vector2(randf_range(-140.0, 140.0), randf_range(-20.0, 14.0))
		minion.global_position = global_position + offset
		get_parent().call_deferred("add_child", minion)

func _draw() -> void:
	super()
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.01)
	var aura_radius := 12.0 + pulse * 3.0
	draw_arc(Vector2(0, -26), aura_radius, 0.0, TAU, 24, Color(0.75, 0.25, 1.0, 0.45), 1.8)
	draw_line(Vector2(-12, -14), Vector2(12, -14), Color(0.7, 0.25, 0.95, 0.75), 3.0)
