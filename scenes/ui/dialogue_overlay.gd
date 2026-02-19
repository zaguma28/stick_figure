extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var text_label: Label = $Panel/VBoxContainer/TextLabel

var _fade_tween: Tween = null

func _ready() -> void:
	panel.visible = false
	set_process_unhandled_input(true)
	var dialogue = _dialogue_service()
	if dialogue:
		if dialogue.has_signal("line_started"):
			dialogue.line_started.connect(_on_line_started)
		if dialogue.has_signal("line_cleared"):
			dialogue.line_cleared.connect(_on_line_cleared)

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	var skip := false
	if event is InputEventScreenTouch and event.pressed:
		skip = true
	elif event is InputEventMouseButton and event.pressed:
		skip = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			skip = true
	if skip:
		var dialogue = _dialogue_service()
		if dialogue and dialogue.has_method("skip_current"):
			dialogue.skip_current()
		get_viewport().set_input_as_handled()

func _on_line_started(title: String, text: String, _hold_seconds: float) -> void:
	title_label.text = title
	text_label.text = text
	panel.visible = true
	panel.modulate.a = 0.0
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(panel, "modulate:a", 1.0, 0.12)

func _on_line_cleared() -> void:
	if not panel.visible:
		return
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(panel, "modulate:a", 0.0, 0.08)
	_fade_tween.tween_callback(func() -> void:
		panel.visible = false
	)

func _dialogue_service() -> Node:
	return get_node_or_null("/root/DialogueService")
