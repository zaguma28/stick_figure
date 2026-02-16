extends Control

signal stick_input(direction: Vector2)

var is_pressed := false
var stick_center := Vector2.ZERO
var current_input := Vector2.ZERO

@export var dead_zone: float = 10.0
@export var max_distance: float = 64.0

@onready var bg: ColorRect = $Background
@onready var knob: ColorRect = $Background/Knob

func _ready() -> void:
	stick_center = bg.size / 2.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			is_pressed = true
			_update_knob(event.position)
		else:
			is_pressed = false
			_reset_knob()
	elif event is InputEventScreenDrag and is_pressed:
		_update_knob(event.position)
	elif event is InputEventMouseButton:
		if event.pressed:
			is_pressed = true
			_update_knob(event.position)
		else:
			is_pressed = false
			_reset_knob()
	elif event is InputEventMouseMotion and is_pressed:
		_update_knob(event.position)

func _update_knob(touch_pos: Vector2) -> void:
	var delta_vec := touch_pos - stick_center
	var dist := delta_vec.length()

	if dist < dead_zone:
		current_input = Vector2.ZERO
		knob.position = stick_center - knob.size / 2.0
	else:
		if dist > max_distance:
			delta_vec = delta_vec.normalized() * max_distance
		current_input = delta_vec / max_distance
		knob.position = stick_center + delta_vec - knob.size / 2.0

	emit_signal("stick_input", current_input)

func _reset_knob() -> void:
	current_input = Vector2.ZERO
	knob.position = stick_center - knob.size / 2.0
	emit_signal("stick_input", Vector2.ZERO)
