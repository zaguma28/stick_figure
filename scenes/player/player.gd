extends CharacterBody2D

# === ステート定義 ===
enum State {
	IDLE, MOVE, ATTACK_1, ATTACK_2, ATTACK_3,
	ROLL, GUARD, PARRY, PARRY_FAIL, ESTUS,
	STAGGER, SKILL_1, SKILL_2
}

# === SPEC.md 準拠パラメータ ===
@export var max_hp: int = 100
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 22.0       # /秒
@export var stamina_delay: float = 0.25        # 行動後ディレイ
@export var move_speed: float = 276.0          # 4.6 * 60
@export var iframes_duration: float = 0.35     # 被弾後無敵

# 通常攻撃
var attack_damage := [10, 10, 18]
var attack_stamina := [18.0, 18.0, 26.0]
var attack_poise := [8, 8, 14]
var attack3_recovery := 0.30

# ロール
@export var roll_stamina: float = 28.0
@export var roll_iframes: float = 0.24
@export var roll_recovery: float = 0.14
@export var roll_distance: float = 168.0       # 2.8 * 60

# パリィ
@export var parry_stamina: float = 24.0
@export var parry_window: float = 0.18
@export var parry_fail_stagger: float = 0.35

# エスト
@export var estus_stamina: float = 16.0
@export var estus_heal: int = 35
@export var estus_max_charges: int = 3

# 弱ガード
@export var guard_reduction: float = 0.30      # 30%カット
@export var guard_stamina_per_hit: float = 22.0
@export var guard_break_stagger: float = 0.6

# === ランタイム変数 ===
var hp: int
var stamina: float
var estus_charges: int
var current_state: State = State.IDLE
var move_dir := Vector2.ZERO
var facing_dir := Vector2.RIGHT

# タイマー
var stamina_delay_timer: float = 0.0
var state_timer: float = 0.0
var iframes_timer: float = 0.0
var parry_active_timer: float = 0.0
var combo_window_timer: float = 0.0

# スキルクールダウン
var skill1_cd: float = 0.0   # 直線突き CT6s
var skill2_cd: float = 0.0   # 円斬り   CT9s

# 攻撃ヒット追跡
var attack_hit_ids: Array = []

# デバッグ用シグナル
signal debug_log(msg: String)
signal hp_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal estus_changed(current: int, maximum: int)

func _ready() -> void:
	hp = max_hp
	stamina = max_stamina
	estus_charges = estus_max_charges
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("stamina_changed", stamina, max_stamina)
	emit_signal("estus_changed", estus_charges, estus_max_charges)

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_handle_input()
	_process_state(delta)
	_check_attack_hits()
	move_and_slide()
	_update_visuals()

# === タイマー更新 ===
func _update_timers(delta: float) -> void:
	if stamina_delay_timer > 0:
		stamina_delay_timer -= delta
	elif stamina < max_stamina:
		stamina = minf(stamina + stamina_regen * delta, max_stamina)
		emit_signal("stamina_changed", stamina, max_stamina)

	if iframes_timer > 0:
		iframes_timer -= delta

	if state_timer > 0:
		state_timer -= delta

	if parry_active_timer > 0:
		parry_active_timer -= delta

	if combo_window_timer > 0:
		combo_window_timer -= delta

	if skill1_cd > 0:
		skill1_cd -= delta
	if skill2_cd > 0:
		skill2_cd -= delta

# === 入力処理 ===
func _handle_input() -> void:
	# 移動入力は常に取得
	move_dir = Vector2.ZERO
	move_dir.x = Input.get_axis("move_left", "move_right")
	move_dir.y = Input.get_axis("move_up", "move_down")
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()

	# ロック状態中は入力を受け付けない
	if _is_locked():
		return

	# パリィ / ガード（同キー: L）
	if Input.is_action_just_pressed("guard"):
		if _can_use_stamina(parry_stamina):
			_enter_parry()
			return

	if Input.is_action_pressed("guard"):
		if current_state != State.PARRY:
			_enter_guard()
			return

	if Input.is_action_just_released("guard"):
		if current_state == State.GUARD:
			_change_state(State.IDLE)
			return

	# 攻撃
	if Input.is_action_just_pressed("attack"):
		_try_attack()
		return

	# ロール
	if Input.is_action_just_pressed("roll"):
		if _can_use_stamina(roll_stamina):
			_enter_roll()
			return

	# エスト
	if Input.is_action_just_pressed("estus"):
		if estus_charges > 0 and _can_use_stamina(estus_stamina):
			_enter_estus()
			return

	# スキル1: 直線突き
	if Input.is_action_just_pressed("skill_1"):
		if skill1_cd <= 0 and _can_use_stamina(18.0):
			_enter_skill1()
			return

	# スキル2: 円斬り
	if Input.is_action_just_pressed("skill_2"):
		if skill2_cd <= 0 and _can_use_stamina(18.0):
			_enter_skill2()
			return

	# 移動 / 待機
	if move_dir != Vector2.ZERO:
		if current_state != State.MOVE:
			_change_state(State.MOVE)
	else:
		if current_state == State.MOVE:
			_change_state(State.IDLE)

# === ステート処理 ===
func _process_state(_delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO

		State.MOVE:
			if move_dir != Vector2.ZERO:
				facing_dir = move_dir.normalized()
			velocity = move_dir * move_speed

		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				# コンボ窓を開く（3段目以外）
				if current_state != State.ATTACK_3:
					combo_window_timer = 0.3
				_change_state(State.IDLE)

		State.ROLL:
			if state_timer > 0:
				velocity = facing_dir * (roll_distance / (roll_iframes + roll_recovery))
			else:
				_change_state(State.IDLE)

		State.GUARD:
			velocity = Vector2.ZERO

		State.PARRY:
			velocity = Vector2.ZERO
			if parry_active_timer <= 0 and state_timer <= 0:
				# パリィ窓が閉じた: 失敗扱い
				_change_state(State.PARRY_FAIL)

		State.PARRY_FAIL:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				_change_state(State.IDLE)

		State.ESTUS:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				_change_state(State.IDLE)

		State.STAGGER:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				_change_state(State.IDLE)

		State.SKILL_1, State.SKILL_2:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				_change_state(State.IDLE)

# === アクション関数 ===
func _enter_parry() -> void:
	_consume_stamina(parry_stamina)
	_change_state(State.PARRY)
	parry_active_timer = parry_window
	state_timer = parry_window + 0.1
	emit_signal("debug_log", "PARRY (窓 %.2fs)" % parry_window)

func _enter_guard() -> void:
	_change_state(State.GUARD)
	emit_signal("debug_log", "GUARD (軽減 %d%%)" % int(guard_reduction * 100))

func _try_attack() -> void:
	# _last_attack ベースでコンボ段数を決定
	var stage := 0
	if combo_window_timer > 0 and _last_attack == 1:
		stage = 1
	elif combo_window_timer > 0 and _last_attack == 2:
		stage = 2

	if not _can_use_stamina(attack_stamina[stage]):
		return

	_consume_stamina(attack_stamina[stage])
	combo_window_timer = 0.0

	match stage:
		0:
			_change_state(State.ATTACK_1)
			state_timer = 0.25
			_last_attack = 1
		1:
			_change_state(State.ATTACK_2)
			state_timer = 0.25
			_last_attack = 2
		2:
			_change_state(State.ATTACK_3)
			state_timer = attack3_recovery + 0.15
			_last_attack = 0

	emit_signal("debug_log", "ATTACK %d (dmg:%d stm:%.0f)" % [stage + 1, attack_damage[stage], attack_stamina[stage]])

var _last_attack: int = 0

func _enter_roll() -> void:
	_consume_stamina(roll_stamina)
	if move_dir != Vector2.ZERO:
		facing_dir = move_dir.normalized()
	_change_state(State.ROLL)
	state_timer = roll_iframes + roll_recovery
	iframes_timer = roll_iframes
	emit_signal("debug_log", "ROLL (無敵 %.2fs)" % roll_iframes)

func _enter_estus() -> void:
	_consume_stamina(estus_stamina)
	estus_charges -= 1
	var heal_amount := mini(estus_heal, max_hp - hp)
	hp += heal_amount
	_change_state(State.ESTUS)
	state_timer = 0.6  # 回復硬直
	emit_signal("debug_log", "ESTUS +%d HP (残%d回)" % [heal_amount, estus_charges])
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("estus_changed", estus_charges, estus_max_charges)

func _enter_skill1() -> void:
	_consume_stamina(18.0)
	_change_state(State.SKILL_1)
	state_timer = 0.35
	skill1_cd = 6.0
	emit_signal("debug_log", "SKILL1: 直線突き (dmg:42 CT:6s)")

func _enter_skill2() -> void:
	_consume_stamina(18.0)
	_change_state(State.SKILL_2)
	state_timer = 0.40
	skill2_cd = 9.0
	emit_signal("debug_log", "SKILL2: 円斬り (dmg:24 CT:9s)")

# === ダメージ受付 ===
func take_damage(amount: int, _poise_damage: int = 0, source: Node = null) -> void:
	if iframes_timer > 0:
		return

	if current_state == State.PARRY and parry_active_timer > 0:
		emit_signal("debug_log", "PARRY SUCCESS!")
		if source and source.has_method("take_damage") and source.is_in_group("enemies"):
			var kb := (source.global_position - global_position).normalized()
			source.take_damage(0, 45, kb)
		_change_state(State.IDLE)
	elif current_state == State.GUARD:
		var reduced := int(amount * (1.0 - guard_reduction))
		hp -= reduced
		stamina -= guard_stamina_per_hit
		stamina_delay_timer = stamina_delay
		emit_signal("debug_log", "GUARD HIT -%d HP" % reduced)
		if stamina <= 0:
			stamina = 0
			_change_state(State.STAGGER)
			state_timer = guard_break_stagger
			emit_signal("debug_log", "GUARD BREAK!")
	else:
		hp -= amount
		iframes_timer = iframes_duration
		emit_signal("debug_log", "HIT -%d HP" % amount)

	hp = maxi(hp, 0)
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("stamina_changed", stamina, max_stamina)

# === 攻撃ヒット判定（距離ベース）===
func _check_attack_hits() -> void:
	var atk_range := 0.0
	var atk_arc := 0.0
	var dmg := 0
	var poise_dmg := 0

	match current_state:
		State.ATTACK_1:
			atk_range = 44.0; atk_arc = PI * 0.6; dmg = attack_damage[0]; poise_dmg = attack_poise[0]
		State.ATTACK_2:
			atk_range = 44.0; atk_arc = PI * 0.6; dmg = attack_damage[1]; poise_dmg = attack_poise[1]
		State.ATTACK_3:
			atk_range = 50.0; atk_arc = PI * 0.7; dmg = attack_damage[2]; poise_dmg = attack_poise[2]
		State.SKILL_1:
			atk_range = 60.0; atk_arc = PI * 0.3; dmg = 42; poise_dmg = 18
		State.SKILL_2:
			atk_range = 50.0; atk_arc = PI; dmg = 24; poise_dmg = 12
		_:
			return

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get_instance_id() in attack_hit_ids:
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist > atk_range:
			continue
		var to_enemy := (enemy.global_position - global_position).normalized()
		if current_state != State.SKILL_2:  # 円斬りは全方位
			var angle := absf(facing_dir.angle_to(to_enemy))
			if angle > atk_arc:
				continue
		attack_hit_ids.append(enemy.get_instance_id())
		enemy.take_damage(dmg, poise_dmg, to_enemy)
		_trigger_hitstop()
		emit_signal("debug_log", "HIT enemy -%d HP" % dmg)

# === ヒットストップ ===
func _trigger_hitstop() -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(0.06, true, false, true).timeout.connect(_end_hitstop)

func _end_hitstop() -> void:
	Engine.time_scale = 1.0

# === ユーティリティ ===
func _can_use_stamina(cost: float) -> bool:
	return stamina >= cost

func _consume_stamina(cost: float) -> void:
	stamina -= cost
	stamina = maxf(stamina, 0.0)
	stamina_delay_timer = stamina_delay
	emit_signal("stamina_changed", stamina, max_stamina)

func _change_state(new_state: State) -> void:
	# 攻撃開始時にヒットリストをクリア
	if new_state in [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3, State.SKILL_1, State.SKILL_2]:
		attack_hit_ids.clear()
	current_state = new_state

func _is_locked() -> bool:
	return current_state in [
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3,
		State.ROLL, State.PARRY, State.PARRY_FAIL,
		State.ESTUS, State.STAGGER, State.SKILL_1, State.SKILL_2
	]

# === 描画 ===
func _update_visuals() -> void:
	queue_redraw()

func _draw() -> void:
	# 棒人間を描画
	var body_color := Color.WHITE
	match current_state:
		State.ROLL:
			body_color = Color(0.5, 0.8, 1.0, 0.6)  # 半透明の青（無敵表現）
		State.GUARD:
			body_color = Color(0.3, 1.0, 0.3)         # 緑（ガード中）
		State.PARRY:
			body_color = Color(1.0, 1.0, 0.2)         # 黄（パリィ窓）
		State.PARRY_FAIL:
			body_color = Color(1.0, 0.3, 0.1)         # 赤（パリィ失敗）
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			body_color = Color(1.0, 0.7, 0.2)         # オレンジ（攻撃中）
		State.ESTUS:
			body_color = Color(0.2, 1.0, 0.6)         # エメラルド（回復中）
		State.STAGGER:
			body_color = Color(1.0, 0.1, 0.1)         # 赤点滅
		State.SKILL_1, State.SKILL_2:
			body_color = Color(0.8, 0.4, 1.0)         # 紫（スキル）

	# 頭
	draw_circle(Vector2(0, -32), 8, body_color)
	# 体
	draw_line(Vector2(0, -24), Vector2(0, 4), body_color, 2.0)
	# 腕
	var arm_offset := Vector2.ZERO
	if current_state in [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3]:
		arm_offset = facing_dir * 12
	draw_line(Vector2(-10, -16) + arm_offset * 0.3, Vector2(10, -16) + arm_offset, body_color, 2.0)
	# 脚
	draw_line(Vector2(0, 4), Vector2(-8, 20), body_color, 2.0)
	draw_line(Vector2(0, 4), Vector2(8, 20), body_color, 2.0)

	# 攻撃エフェクト
	if current_state in [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3]:
		var atk_pos := facing_dir * 28
		var atk_radius := 14.0 if current_state != State.ATTACK_3 else 18.0
		draw_arc(atk_pos, atk_radius, 0, TAU, 16, Color(1, 1, 1, 0.5), 2.0)

	# ガードの盾表現
	if current_state == State.GUARD:
		var shield_pos := facing_dir * 16
		draw_line(shield_pos + Vector2(-8, -12), shield_pos + Vector2(-8, 12), Color(0.3, 1.0, 0.3, 0.8), 4.0)
