extends Node

signal line_started(title: String, text: String, hold_seconds: float)
signal line_cleared()
signal queue_finished()

var _queue: Array[Dictionary] = []
var _line_timer: float = 0.0
var _active: bool = false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_process(true)

func show_message(title: String, text: String, hold_seconds: float = 1.8, clear_existing: bool = false) -> void:
	if clear_existing:
		clear_queue()
	_queue.append(
		{
			"title": title,
			"text": text,
			"hold": maxf(0.4, hold_seconds)
		}
	)
	if not _active:
		_start_next_line()

func show_lines(title: String, lines: Array, hold_seconds: float = 1.6, clear_existing: bool = false) -> void:
	if clear_existing:
		clear_queue()
	for line in lines:
		var text := str(line).strip_edges()
		if text == "":
			continue
		_queue.append(
			{
				"title": title,
				"text": text,
				"hold": maxf(0.35, hold_seconds)
			}
		)
	if not _active:
		_start_next_line()

func skip_current() -> void:
	if not _active:
		return
	_line_timer = 0.0

func clear_queue() -> void:
	_queue.clear()
	_active = false
	_line_timer = 0.0
	emit_signal("line_cleared")
	emit_signal("queue_finished")

func is_active() -> bool:
	return _active

func _process(delta: float) -> void:
	if not _active:
		return
	_line_timer -= delta
	if _line_timer <= 0.0:
		_start_next_line()

func _start_next_line() -> void:
	if _queue.is_empty():
		_active = false
		_line_timer = 0.0
		emit_signal("line_cleared")
		emit_signal("queue_finished")
		return
	var next_line: Dictionary = _queue.pop_front()
	_active = true
	_line_timer = float(next_line.get("hold", 1.2))
	emit_signal(
		"line_started",
		str(next_line.get("title", "")),
		str(next_line.get("text", "")),
		_line_timer
	)
