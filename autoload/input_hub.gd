extends Node

const ACTIONS := [
	"move_up",
	"move_down",
	"move_left",
	"move_right",
	"jump",
	"attack",
	"roll",
	"guard",
	"skill_1",
	"skill_2",
	"estus"
]
const JUST_FLAG_TTL := 2
const MOVE_DEADZONE := 0.08

signal touch_controls_toggled(enabled: bool)
signal bindings_changed()

var _virtual_actions: Dictionary = {}
var _virtual_pressed_ttl: Dictionary = {}
var _virtual_released_ttl: Dictionary = {}
var _virtual_axis: Vector2 = Vector2.ZERO
var _touch_controls_enabled: bool = true

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_physics_process(true)
	for action in ACTIONS:
		_virtual_actions[action] = false
		_virtual_pressed_ttl[action] = 0
		_virtual_released_ttl[action] = 0
		_ensure_action_exists(action)
	_load_touch_setting()
	_load_binding_preset_from_save()
	_ensure_default_gamepad_bindings()

func _physics_process(_delta: float) -> void:
	for action in ACTIONS:
		var pressed_ttl := int(_virtual_pressed_ttl.get(action, 0))
		var released_ttl := int(_virtual_released_ttl.get(action, 0))
		if pressed_ttl > 0:
			_virtual_pressed_ttl[action] = pressed_ttl - 1
		if released_ttl > 0:
			_virtual_released_ttl[action] = released_ttl - 1

func are_touch_controls_enabled() -> bool:
	return _touch_controls_enabled

func set_touch_controls_enabled(enabled: bool, persist: bool = true) -> void:
	_touch_controls_enabled = enabled
	emit_signal("touch_controls_toggled", enabled)
	if persist and has_node("/root/SaveManager"):
		var save_manager = get_node("/root/SaveManager")
		save_manager.set_setting("touch_controls_enabled", enabled, true)

func set_virtual_axis(axis: Vector2) -> void:
	var clamped := axis
	if clamped.length() > 1.0:
		clamped = clamped.normalized()
	_virtual_axis = clamped
	_set_virtual_action_state("move_left", _virtual_axis.x <= -MOVE_DEADZONE, false)
	_set_virtual_action_state("move_right", _virtual_axis.x >= MOVE_DEADZONE, false)
	_set_virtual_action_state("move_up", _virtual_axis.y <= -MOVE_DEADZONE, false)
	_set_virtual_action_state("move_down", _virtual_axis.y >= MOVE_DEADZONE, false)

func clear_virtual_axis() -> void:
	set_virtual_axis(Vector2.ZERO)

func set_virtual_action(action: String, pressed: bool) -> void:
	_set_virtual_action_state(action, pressed, true)

func pulse_virtual_action(action: String) -> void:
	_set_virtual_action_state(action, true, true)
	_set_virtual_action_state(action, false, true)

func clear_virtual_actions() -> void:
	for action in ACTIONS:
		_virtual_actions[action] = false
		_virtual_pressed_ttl[action] = 0
		_virtual_released_ttl[action] = 0
	_virtual_axis = Vector2.ZERO

func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action) or bool(_virtual_actions.get(action, false))

func is_action_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action) or int(_virtual_pressed_ttl.get(action, 0)) > 0

func is_action_just_released(action: String) -> bool:
	return Input.is_action_just_released(action) or int(_virtual_released_ttl.get(action, 0)) > 0

func get_axis(negative_action: String, positive_action: String) -> float:
	var axis := Input.get_axis(negative_action, positive_action)
	var virtual_axis := 0.0
	if negative_action == "move_left" and positive_action == "move_right":
		virtual_axis = _virtual_axis.x
	elif negative_action == "move_up" and positive_action == "move_down":
		virtual_axis = _virtual_axis.y
	if absf(virtual_axis) > absf(axis):
		axis = virtual_axis
	return axis

func get_vector(neg_x: String, pos_x: String, neg_y: String, pos_y: String) -> Vector2:
	var v := Input.get_vector(neg_x, pos_x, neg_y, pos_y)
	if _virtual_axis.length() > v.length():
		v = _virtual_axis
	return v

func export_bindings() -> Dictionary:
	var data := {}
	for action in ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events: Array = []
		for event in InputMap.action_get_events(action):
			var event_data := _serialize_event(event)
			if not event_data.is_empty():
				events.append(event_data)
		if not events.is_empty():
			data[action] = events
	return data

func apply_bindings(binding_data: Dictionary, persist: bool = true) -> void:
	if binding_data.is_empty():
		return
	for action in binding_data.keys():
		if not InputMap.has_action(action):
			continue
		var events: Array = binding_data[action]
		if events.is_empty():
			continue
		InputMap.action_erase_events(action)
		for event_dict in events:
			var input_event: InputEvent = _deserialize_event(event_dict)
			if input_event:
				InputMap.action_add_event(action, input_event)
	_ensure_default_gamepad_bindings()
	emit_signal("bindings_changed")
	if persist:
		_save_bindings_to_save()

func reset_to_project_defaults(persist: bool = true) -> void:
	InputMap.load_from_project_settings()
	_ensure_default_gamepad_bindings()
	emit_signal("bindings_changed")
	if persist:
		_save_bindings_to_save()

func _set_virtual_action_state(action: String, pressed: bool, mark_just: bool) -> void:
	if not _virtual_actions.has(action):
		return
	var current := bool(_virtual_actions.get(action, false))
	if current == pressed:
		return
	_virtual_actions[action] = pressed
	if mark_just:
		if pressed:
			_virtual_pressed_ttl[action] = JUST_FLAG_TTL
		else:
			_virtual_released_ttl[action] = JUST_FLAG_TTL

func _ensure_action_exists(action: String) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)

func _load_touch_setting() -> void:
	if not has_node("/root/SaveManager"):
		return
	var save_manager = get_node("/root/SaveManager")
	_touch_controls_enabled = bool(save_manager.get_setting("touch_controls_enabled", true))

func _load_binding_preset_from_save() -> void:
	if not has_node("/root/SaveManager"):
		return
	var save_manager = get_node("/root/SaveManager")
	var binding_data = save_manager.get_input_bindings()
	if binding_data is Dictionary and not binding_data.is_empty():
		apply_bindings(binding_data, false)

func _save_bindings_to_save() -> void:
	if not has_node("/root/SaveManager"):
		return
	var save_manager = get_node("/root/SaveManager")
	save_manager.set_input_bindings(export_bindings(), true)

func _ensure_default_gamepad_bindings() -> void:
	_add_default_joy_motion("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_default_joy_motion("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_default_joy_motion("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_default_joy_motion("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_default_joy_button("jump", JOY_BUTTON_A)
	_add_default_joy_button("attack", JOY_BUTTON_X)
	_add_default_joy_button("roll", JOY_BUTTON_B)
	_add_default_joy_button("guard", JOY_BUTTON_Y)
	_add_default_joy_button("estus", JOY_BUTTON_RIGHT_SHOULDER)
	_add_default_joy_button("skill_1", JOY_BUTTON_LEFT_SHOULDER)
	_add_default_joy_button("skill_2", JOY_BUTTON_RIGHT_STICK)

func _add_default_joy_button(action: String, button_index: int) -> void:
	if not InputMap.has_action(action):
		return
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	if not _action_has_equivalent_event(action, event):
		InputMap.action_add_event(action, event)

func _add_default_joy_motion(action: String, axis: int, axis_value: float) -> void:
	if not InputMap.has_action(action):
		return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	if not _action_has_equivalent_event(action, event):
		InputMap.action_add_event(action, event)

func _action_has_equivalent_event(action: String, candidate: InputEvent) -> bool:
	for event in InputMap.action_get_events(action):
		if event.as_text() == candidate.as_text():
			return true
	return false

func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var e := event as InputEventKey
		return {
			"type": "key",
			"keycode": int(e.keycode),
			"physical_keycode": int(e.physical_keycode),
			"shift": e.shift_pressed,
			"alt": e.alt_pressed,
			"ctrl": e.ctrl_pressed,
			"meta": e.meta_pressed
		}
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		return {
			"type": "joy_button",
			"button_index": int(jb.button_index)
		}
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		return {
			"type": "joy_motion",
			"axis": int(jm.axis),
			"axis_value": float(jm.axis_value)
		}
	return {}

func _deserialize_event(data: Dictionary) -> InputEvent:
	var t := str(data.get("type", ""))
	match t:
		"key":
			var key_event := InputEventKey.new()
			key_event.keycode = int(data.get("keycode", 0))
			key_event.physical_keycode = int(data.get("physical_keycode", 0))
			key_event.shift_pressed = bool(data.get("shift", false))
			key_event.alt_pressed = bool(data.get("alt", false))
			key_event.ctrl_pressed = bool(data.get("ctrl", false))
			key_event.meta_pressed = bool(data.get("meta", false))
			return key_event
		"joy_button":
			var joy_button := InputEventJoypadButton.new()
			joy_button.button_index = int(data.get("button_index", 0))
			return joy_button
		"joy_motion":
			var joy_motion := InputEventJoypadMotion.new()
			joy_motion.axis = int(data.get("axis", 0))
			joy_motion.axis_value = float(data.get("axis_value", 0.0))
			return joy_motion
		_:
			return null
