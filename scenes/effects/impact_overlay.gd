extends CanvasLayer

const IMPACT_SHADER := preload("res://scenes/effects/impact_overlay.gdshader")

var overlay_rect: ColorRect
var overlay_material: ShaderMaterial
var active_timer: float = 0.0
var active_duration: float = 0.0
var active_strength: float = 0.0
var active_tint: Color = Color(1.0, 0.78, 0.45, 1.0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	add_to_group("impact_overlay")
	overlay_rect = ColorRect.new()
	overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	overlay_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = IMPACT_SHADER
	overlay_rect.material = overlay_material
	add_child(overlay_rect)
	_apply_impact_uniform(0.0, active_tint)

func _process(delta: float) -> void:
	if active_timer <= 0.0:
		if active_strength > 0.0:
			active_strength = 0.0
			_apply_impact_uniform(0.0, active_tint)
		return
	active_timer = maxf(0.0, active_timer - delta)
	var decay = active_timer / maxf(active_duration, 0.001)
	var curved = pow(decay, 1.7)
	_apply_impact_uniform(active_strength * curved, active_tint)

func trigger_impact(strength: float, duration: float, tint: Color = Color(1.0, 0.78, 0.45, 1.0)) -> void:
	var s = clampf(strength, 0.0, 1.0)
	var d = maxf(0.03, duration)
	active_strength = maxf(active_strength, s)
	active_timer = maxf(active_timer, d)
	active_duration = active_timer
	active_tint = tint
	_apply_impact_uniform(active_strength, active_tint)

func _apply_impact_uniform(strength: float, tint: Color) -> void:
	if overlay_material == null:
		return
	overlay_material.set_shader_parameter("impact_strength", strength)
	overlay_material.set_shader_parameter("impact_tint", tint)
