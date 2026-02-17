extends CanvasLayer

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxContainer/StaminaBar
@onready var estus_label: Label = $MarginContainer/VBoxContainer/EstusLabel
@onready var floor_label: Label = $MarginContainer/VBoxContainer/FloorLabel
@onready var floor_desc_label: Label = $MarginContainer/VBoxContainer/FloorDescLabel
@onready var run_label: Label = $MarginContainer/VBoxContainer/RunLabel
@onready var reward_tag_label: Label = $MarginContainer/VBoxContainer/RewardTagLabel
@onready var state_label: Label = $MarginContainer/VBoxContainer/StateLabel
@onready var debug_label: Label = $DebugContainer/DebugLabel
@onready var reward_panel: PanelContainer = $RewardPanel
@onready var reward_title_label: Label = $RewardPanel/VBoxContainer/RewardTitleLabel
@onready var reward_hint_label: Label = $RewardPanel/VBoxContainer/RewardHintLabel
@onready var reward_option_1: Label = $RewardPanel/VBoxContainer/RewardOption1
@onready var reward_option_2: Label = $RewardPanel/VBoxContainer/RewardOption2
@onready var reward_option_3: Label = $RewardPanel/VBoxContainer/RewardOption3
@onready var reward_pick_1: Button = $RewardPanel/VBoxContainer/RewardButtons/Pick1Button
@onready var reward_pick_2: Button = $RewardPanel/VBoxContainer/RewardButtons/Pick2Button
@onready var reward_pick_3: Button = $RewardPanel/VBoxContainer/RewardButtons/Pick3Button

var debug_lines: Array[String] = []
const MAX_DEBUG_LINES := 8

signal reward_selected(index: int)

func _ready() -> void:
	var buttons := [reward_pick_1, reward_pick_2, reward_pick_3]
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_reward_pick_pressed.bind(i))

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
	set_reward_summary({})
	hide_reward_options()

func set_floor_info(current: int, total: int, floor_type: String, floor_name: String) -> void:
	floor_label.text = "Floor: %d/%d" % [current, total]
	floor_desc_label.text = "%s | %s" % [floor_type, floor_name]

func set_run_message(message: String) -> void:
	run_label.text = message

func set_reward_summary(tag_counts: Dictionary) -> void:
	if tag_counts.is_empty():
		reward_tag_label.text = "Build: (none)"
		return
	var pieces: Array[String] = []
	for key in tag_counts.keys():
		pieces.append("%s:%d" % [str(key), int(tag_counts[key])])
	pieces.sort()
	reward_tag_label.text = "Build: " + "  ".join(pieces)

func show_reward_options(floor_index: int, options: Array[Dictionary], guaranteed: bool) -> void:
	reward_panel.visible = true
	var title := "報酬選択 F%d" % floor_index
	if guaranteed:
		title += "（9F救済）"
	reward_title_label.text = title
	reward_hint_label.text = "1/2/3キー or タップで選択"
	var labels := [reward_option_1, reward_option_2, reward_option_3]
	var buttons := [reward_pick_1, reward_pick_2, reward_pick_3]
	for i in range(labels.size()):
		var text := "[%d] ---" % (i + 1)
		if i < options.size():
			text = _format_reward_option(i + 1, options[i])
		labels[i].text = text
		var available := i < options.size()
		buttons[i].disabled = not available
		buttons[i].text = "選択 %d" % (i + 1)

func hide_reward_options() -> void:
	reward_panel.visible = false
	reward_pick_1.disabled = true
	reward_pick_2.disabled = true
	reward_pick_3.disabled = true

func _format_reward_option(index: int, reward: Dictionary) -> String:
	var name := str(reward.get("name", "UNKNOWN"))
	var desc := str(reward.get("desc", ""))
	return "[%d] %s | %s" % [index, name, desc]

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

func _on_reward_pick_pressed(index: int) -> void:
	emit_signal("reward_selected", index)
