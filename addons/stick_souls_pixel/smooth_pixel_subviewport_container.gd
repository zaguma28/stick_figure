@tool
extends SubViewportContainer
class_name SmoothPixelSubViewportContainer

@export var snap_enabled: bool = true
@export var pixel_snap_step: float = 1.0
@export var target_camera_path: NodePath

func _process(_delta: float) -> void:
	if not snap_enabled:
		return
	if pixel_snap_step <= 0.0:
		return
	if target_camera_path == NodePath(""):
		return
	var camera := get_node_or_null(target_camera_path) as Camera2D
	if camera == null:
		return
	camera.global_position = _snap_vec2(camera.global_position, pixel_snap_step)

func _snap_vec2(v: Vector2, step: float) -> Vector2:
	return Vector2(round(v.x / step) * step, round(v.y / step) * step)
