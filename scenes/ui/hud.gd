extends CanvasLayer

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxContainer/StaminaBar
@onready var estus_label: Label = $MarginContainer/VBoxContainer/EstusLabel
@onready var floor_label: Label = $MarginContainer/VBoxContainer/FloorLabel
@onready var floor_desc_label: Label = $MarginContainer/VBoxContainer/FloorDescLabel
@onready var run_label: Label = $MarginContainer/VBoxContainer/RunLabel
@onready var state_label: Label = $MarginContainer/VBoxContainer/StateLabel
@onready var debug_label: Label = $DebugContainer/DebugLabel

var debug_lines: Array[String] = []
const MAX_DEBUG_LINES := 8

func setup(player: Node) -> void:
	if player.has_signal("hp_changed"):
		player.hp_changed.connect(_on_hp_changed)
	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_on_stamina_changed)
	if player.has_signal("estus_changed"):
		player.estus_changed.connect(_on_estus_changed)
	if player.has_signal("debug_log"):
		player.debug_log.connect(_on_debug_log)

	# 初期値
	_on_hp_changed(player.hp, player.max_hp)
	_on_stamina_changed(player.stamina, player.max_stamina)
	_on_estus_changed(player.estus_charges, player.estus_max_charges)
	set_floor_info(1, 10, "COMBAT", "Initializing")
	set_run_message("")

func set_floor_info(current: int, total: int, floor_type: String, floor_name: String) -> void:
	floor_label.text = "Floor: %d/%d" % [current, total]
	floor_desc_label.text = "%s | %s" % [floor_type, floor_name]

func set_run_message(message: String) -> void:
	run_label.text = message

func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current

func _on_estus_changed(current: int, maximum: int) -> void:
	estus_label.text = "EST: %d/%d" % [current, maximum]

func _on_debug_log(msg: String) -> void:
	debug_lines.push_front(msg)
	if debug_lines.size() > MAX_DEBUG_LINES:
		debug_lines.resize(MAX_DEBUG_LINES)
	debug_label.text = "\n".join(debug_lines)

func _process(_delta: float) -> void:
	# プレイヤーの現在ステートと座標を表示
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("_is_locked"):
		var state_names := ["IDLE","MOVE","ATK1","ATK2","ATK3","ROLL","GUARD","PARRY","P_FAIL","ESTUS","STAGGER","SK1","SK2"]
		var idx: int = player.current_state
		if idx >= 0 and idx < state_names.size():
			state_label.text = "State: %s | Pos: (%.0f, %.0f)" % [state_names[idx], player.position.x, player.position.y]
