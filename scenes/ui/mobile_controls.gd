extends Control

signal stick_input(direction: Vector2)

@export var dead_zone: float = 10.0
@export var max_distance: float = 64.0
@export var show_on_desktop: bool = true

var is_pressed: bool = false
var stick_center: Vector2 = Vector2.ZERO
var current_input: Vector2 = Vector2.ZERO
var _held_actions: Dictionary = {}

@onready var joystick_area: Control = $JoystickArea
@onready var bg: ColorRect = $JoystickArea/Background
@onready var knob: ColorRect = $JoystickArea/Background/Knob

@onready var jump_button: Button = $ButtonsRoot/JumpButton
@onready var attack_button: Button = $ButtonsRoot/AttackButton
@onready var roll_button: Button = $ButtonsRoot/RollButton
@onready var guard_button: Button = $ButtonsRoot/GuardButton
@onready var estus_button: Button = $ButtonsRoot/EstusButton
@onready var skill1_button: Button = $ButtonsRoot/Skill1Button
@onready var skill2_button: Button = $ButtonsRoot/Skill2Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_center = bg.size * 0.5
	joystick_area.gui_input.connect(_on_joystick_gui_input)
	_bind_action_button(jump_button, "jump")
	_bind_action_button(attack_button, "attack")
	_bind_action_button(roll_button, "roll")
	_bind_action_button(guard_button, "guard")
	_bind_action_button(estus_button, "estus")
	_bind_action_button(skill1_button, "skill_1")
	_bind_action_button(skill2_button, "skill_2")
	var hub = _input_hub()
	if hub and hub.has_signal("touch_controls_toggled"):
		hub.touch_controls_toggled.connect(_on_touch_controls_toggled)
	_apply_visibility_from_settings()

func set_enabled(enabled: bool) -> void:
	visible = enabled
	if not visible:
		_reset_knob()
		_release_all_actions()

func _exit_tree() -> void:
	_release_all_actions()
	var hub = _input_hub()
	if hub and hub.has_method("clear_virtual_axis"):
		hub.clear_virtual_axis()

func _on_touch_controls_toggled(_enabled: bool) -> void:
	_apply_visibility_from_settings()

func _apply_visibility_from_settings() -> void:
	var should_show := true
	var hub = _input_hub()
	if hub and hub.has_method("are_touch_controls_enabled"):
		should_show = bool(hub.are_touch_controls_enabled())
	if not show_on_desktop and not (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()):
		should_show = false
	visible = should_show
	if not visible:
		_reset_knob()
		_release_all_actions()

func _bind_action_button(button: Button, action: String) -> void:
	if button == null:
		return
	button.button_down.connect(_on_action_button_down.bind(action))
	button.button_up.connect(_on_action_button_up.bind(action))

func _on_action_button_down(action: String) -> void:
	_held_actions[action] = true
	var hub = _input_hub()
	if hub and hub.has_method("set_virtual_action"):
		hub.set_virtual_action(action, true)

func _on_action_button_up(action: String) -> void:
	_held_actions.erase(action)
	var hub = _input_hub()
	if hub and hub.has_method("set_virtual_action"):
		hub.set_virtual_action(action, false)

func _release_all_actions() -> void:
	var hub = _input_hub()
	for action in _held_actions.keys():
		if hub and hub.has_method("set_virtual_action"):
			hub.set_virtual_action(str(action), false)
	_held_actions.clear()

func _on_joystick_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			is_pressed = true
			_update_knob(touch.position)
		else:
			is_pressed = false
			_reset_knob()
	elif event is InputEventScreenDrag and is_pressed:
		var drag := event as InputEventScreenDrag
		_update_knob(drag.position)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed:
			is_pressed = true
			_update_knob(mouse_button.position)
		else:
			is_pressed = false
			_reset_knob()
	elif event is InputEventMouseMotion and is_pressed:
		var mouse_motion := event as InputEventMouseMotion
		_update_knob(mouse_motion.position)

func _update_knob(touch_pos: Vector2) -> void:
	var delta_vec := touch_pos - stick_center
	var dist := delta_vec.length()
	if dist < dead_zone:
		current_input = Vector2.ZERO
		knob.position = stick_center - knob.size * 0.5
	else:
		if dist > max_distance:
			delta_vec = delta_vec.normalized() * max_distance
		current_input = delta_vec / max_distance
		knob.position = stick_center + delta_vec - knob.size * 0.5
	_emit_axis()

func _reset_knob() -> void:
	current_input = Vector2.ZERO
	knob.position = stick_center - knob.size * 0.5
	_emit_axis()

func _emit_axis() -> void:
	var hub = _input_hub()
	if hub and hub.has_method("set_virtual_axis"):
		hub.set_virtual_axis(current_input)
	emit_signal("stick_input", current_input)

func _input_hub() -> Node:
	return get_node_or_null("/root/InputHub")
