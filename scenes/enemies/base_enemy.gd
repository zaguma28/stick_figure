extends CharacterBody2D
class_name BaseEnemy

enum EnemyState { IDLE, CHASE, TELEGRAPH, ATTACK, STAGGER, DOWN, DEAD }

@export var max_hp: int = 50
@export var move_speed: float = 100.0
@export var contact_damage: int = 15
@export var max_poise: float = 40.0
@export var poise_regen_rate: float = 8.0
@export var down_duration: float = 1.2

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

signal enemy_died(enemy: Node2D)

func _ready() -> void:
	hp = max_hp
	poise = max_poise
	add_to_group("enemies")
	target = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if current_state == EnemyState.DEAD:
		return
	_update_timers(delta)
	_update_state(delta)
	if knockback_vel.length() > 5.0:
		velocity += knockback_vel
		knockback_vel = knockback_vel.lerp(Vector2.ZERO, 10.0 * delta)
	else:
		knockback_vel = Vector2.ZERO
	move_and_slide()
	queue_redraw()

func _update_timers(delta: float) -> void:
	if state_timer > 0:
		state_timer -= delta
	if attack_cd_timer > 0:
		attack_cd_timer -= delta
	if poise_delay_timer > 0:
		poise_delay_timer -= delta
	elif poise < max_poise and current_state != EnemyState.DOWN:
		poise = minf(poise + poise_regen_rate * delta, max_poise)

func _update_state(_delta: float) -> void:
	match current_state:
		EnemyState.IDLE:
			velocity = Vector2.ZERO
			if target:
				current_state = EnemyState.CHASE
		EnemyState.CHASE:
			_do_chase()
			_check_attack_range()
		EnemyState.TELEGRAPH:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				_execute_attack()
		EnemyState.ATTACK:
			_do_attack()
		EnemyState.STAGGER:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				current_state = EnemyState.CHASE
		EnemyState.DOWN:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				poise = max_poise
				current_state = EnemyState.CHASE

func _do_chase() -> void:
	if not target:
		velocity = Vector2.ZERO
		return
	var dir := (target.global_position - global_position).normalized()
	facing_dir = dir
	velocity = dir * move_speed

func _check_attack_range() -> void:
	if not target or attack_cd_timer > 0:
		return
	if global_position.distance_to(target.global_position) < attack_range:
		current_state = EnemyState.TELEGRAPH
		state_timer = attack_telegraph
		has_hit_this_attack = false

func _execute_attack() -> void:
	current_state = EnemyState.ATTACK
	state_timer = attack_duration

func _do_attack() -> void:
	if not has_hit_this_attack and target:
		if global_position.distance_to(target.global_position) < attack_range * 1.5:
			_deal_damage_to_player(contact_damage)
			has_hit_this_attack = true
	if state_timer <= 0:
		attack_cd_timer = attack_cooldown
		current_state = EnemyState.CHASE

func _deal_damage_to_player(amount: int) -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(amount, 0, self)

func take_damage(amount: int, poise_dmg: int = 0, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if current_state == EnemyState.DEAD:
		return
	hp -= amount
	if knockback_dir != Vector2.ZERO:
		knockback_vel = knockback_dir * 200.0
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
	emit_signal("enemy_died", self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var c := Color(1.0, 0.3, 0.2)
	match current_state:
		EnemyState.TELEGRAPH: c = Color(1.0, 1.0, 0.0)
		EnemyState.DOWN: c = Color(0.5, 0.5, 0.5)
		EnemyState.STAGGER: c = Color(1.0, 0.5, 0.0)
	draw_circle(Vector2(0, -24), 6, c)
	draw_line(Vector2(0, -18), Vector2(0, 4), c, 2.0)
	draw_line(Vector2(-8, -12), Vector2(8, -12), c, 2.0)
	draw_line(Vector2(0, 4), Vector2(-6, 16), c, 2.0)
	draw_line(Vector2(0, 4), Vector2(6, 16), c, 2.0)
	var bw := 30.0; var by := -34.0
	var hr := clampf(float(hp) / float(max_hp), 0, 1)
	draw_rect(Rect2(-bw / 2, by, bw, 3), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-bw / 2, by, bw * hr, 3), Color(1.0, 0.2, 0.2))
	if poise < max_poise:
		var pr := clampf(poise / max_poise, 0, 1)
		draw_rect(Rect2(-bw / 2, by - 5, bw, 2), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(-bw / 2, by - 5, bw * pr, 2), Color(1.0, 0.8, 0.2))
