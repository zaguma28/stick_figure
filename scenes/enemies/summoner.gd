extends BaseEnemy

var bullet_scene: PackedScene = preload("res://scenes/enemies/bullet.tscn")
var enemy_scene: PackedScene = preload("res://scenes/enemies/base_enemy.tscn")
var summon_cd: float = 6.5
var summon_cd_timer: float = 3.0
var max_minions: int = 2

func _ready() -> void:
	max_hp = 70; contact_damage = 12; move_speed = 50.0
	attack_range = 350.0; attack_telegraph = 0.3
	attack_duration = 0.3; attack_cooldown = 2.0
	super()

func _update_timers(delta: float) -> void:
	super(delta)
	if summon_cd_timer > 0:
		summon_cd_timer -= delta

func _execute_attack() -> void:
	current_state = EnemyState.ATTACK
	state_timer = attack_duration
	# 弾を撃つ
	var b = bullet_scene.instantiate()
	b.direction = facing_dir.normalized()
	b.damage = contact_damage
	b.global_position = global_position
	get_parent().add_child(b)
	# 召喚判定
	if summon_cd_timer <= 0:
		_summon_minions()
		summon_cd_timer = summon_cd

func _do_attack() -> void:
	if state_timer <= 0:
		attack_cd_timer = attack_cooldown
		current_state = EnemyState.CHASE

func _summon_minions() -> void:
	for i in range(max_minions):
		var minion = enemy_scene.instantiate()
		minion.max_hp = 25
		minion.contact_damage = 12
		minion.move_speed = 130.0
		minion.max_poise = 20.0
		var offset := Vector2(randf_range(-40, 40), randf_range(-40, 40))
		minion.position = global_position + offset
		get_parent().call_deferred("add_child", minion)

func _draw() -> void:
	var c := Color(0.8, 0.2, 1.0)
	match current_state:
		EnemyState.TELEGRAPH: c = Color(1.0, 1.0, 0.0)
		EnemyState.DOWN: c = Color(0.5, 0.5, 0.5)
	draw_circle(Vector2(0, -24), 6, c)
	draw_line(Vector2(0, -18), Vector2(0, 4), c, 2.0)
	draw_line(Vector2(-12, -14), Vector2(12, -14), c, 2.0)
	draw_line(Vector2(0, 4), Vector2(-6, 16), c, 2.0)
	draw_line(Vector2(0, 4), Vector2(6, 16), c, 2.0)
	# 召喚マーク
	draw_arc(Vector2(0, -24), 12, 0, TAU, 12, Color(0.8, 0.2, 1.0, 0.4), 1.5)
	var bw := 30.0; var by := -40.0
	var hr := clampf(float(hp) / float(max_hp), 0, 1)
	draw_rect(Rect2(-bw / 2, by, bw, 3), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-bw / 2, by, bw * hr, 3), Color(1.0, 0.2, 0.2))
