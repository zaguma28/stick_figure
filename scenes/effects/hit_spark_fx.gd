extends Node2D

const BURST_PARTICLES_SCRIPT := preload("res://addons/BurstParticles2D/BurstParticles2D.gd")
const BURST_ORB_TEXTURE := preload("res://addons/BurstParticles2D/BurstParticles2D-demo/orb_soft.png")
const ENABLE_BURST_PARTICLES := false

var direction: Vector2 = Vector2.RIGHT
var base_color: Color = Color(0.58, 0.9, 1.0, 0.95)
var heavy_hit: bool = false
var duration: float = 0.045
var elapsed: float = 0.0
var ray_count: int = 2
var spin: float = 0.0
var burst_radius: float = 3.1

func _ready() -> void:
	spin = randf_range(-0.5, 0.5)
	z_index = -6
	_emit_burst_particles()
	queue_redraw()

func configure(hit_dir: Vector2, color: Color, heavy: bool = false) -> void:
	if hit_dir.length() > 0.01:
		direction = hit_dir.normalized()
	base_color = color
	heavy_hit = heavy
	duration = 0.045
	ray_count = 2
	burst_radius = 3.1

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t = clampf(elapsed / duration, 0.0, 1.0)
	var alpha = 1.0 - t
	var push = direction * (2.13 + 3.02 * t)
	draw_circle(push * 0.14, 0.6 - t * 0.3, Color(base_color.r, base_color.g, base_color.b, 0.3 * alpha))
	draw_arc(
		push * 0.08,
		(1.33 + burst_radius * t),
		0.0,
		TAU,
		24,
		Color(base_color.r, base_color.g, base_color.b, 0.12 * alpha),
		0.4
	)
	var spread = 0.48
	for i in range(ray_count):
		var ratio = (float(i) / float(maxi(1, ray_count - 1))) * 2.0 - 1.0
		var angle = ratio * spread + spin
		var ray_dir = direction.rotated(angle).normalized()
		var start = ray_dir * (0.35 + t * 0.67)
		var ray_len = (1.82 + randf_range(0.0, 0.75)) * (1.0 - t * 0.6)
		var end = start + ray_dir * ray_len
		var line_color = Color(base_color.r, base_color.g, base_color.b, (0.85 - 0.05 * i) * alpha)
		draw_line(start, end, line_color, 0.25)

func _emit_burst_particles() -> void:
	if not ENABLE_BURST_PARTICLES:
		return
	_spawn_burst(direction)

func _spawn_burst(dir: Vector2) -> void:
	var burst = BURST_PARTICLES_SCRIPT.new()
	if burst == null:
		return
	burst.set("autostart", false)
	burst.set("repeat", false)
	burst.set("free_when_finished", true)
	burst.set("texture", BURST_ORB_TEXTURE)
	burst.set("num_particles", 2)
	burst.set("lifetime", 0.045)
	burst.set("distance", 3.5)
	burst.set("spread_degrees", 19.0)
	burst.set("center_concentration", 58.0)
	burst.set("direction", dir.normalized())
	burst.set("image_scale", 0.102)
	burst.set("blend_mode", 1)
	burst.set("angle_randomness", 0.75)
	burst.set("distance_randomness", 0.17)
	add_child(burst)
	burst.call("burst")
