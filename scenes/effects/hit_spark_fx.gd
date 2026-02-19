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
var ray_offsets: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	spin = randf_range(-0.5, 0.5)
	if ray_offsets.is_empty():
		ray_offsets = PackedFloat32Array([0.0, 0.08, -0.09])
	z_index = -6
	_emit_burst_particles()
	queue_redraw()

func configure(hit_dir: Vector2, color: Color, heavy: bool = false) -> void:
	if hit_dir.length() > 0.01:
		direction = hit_dir.normalized()
	base_color = color
	heavy_hit = heavy
	duration = 0.072 if heavy_hit else 0.052
	ray_count = 6 if heavy_hit else 4
	burst_radius = 7.2 if heavy_hit else 4.2
	ray_offsets = PackedFloat32Array()
	for _i in range(ray_count):
		ray_offsets.push_back(randf_range(-0.12, 0.12))

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
	draw_circle(push * 0.14, 0.8 - t * 0.35, Color(base_color.r, base_color.g, base_color.b, 0.34 * alpha))
	draw_arc(
		push * 0.08,
		(1.33 + burst_radius * t),
		0.0,
		TAU,
		24,
		Color(base_color.r, base_color.g, base_color.b, (0.22 if heavy_hit else 0.14) * alpha),
		0.75 if heavy_hit else 0.5
	)
	var spread = 0.66 if heavy_hit else 0.52
	for i in range(ray_count):
		var ratio = (float(i) / float(maxi(1, ray_count - 1))) * 2.0 - 1.0
		var jitter = 0.0
		if i < ray_offsets.size():
			jitter = ray_offsets[i]
		var angle = ratio * spread + spin + jitter
		var ray_dir = direction.rotated(angle).normalized()
		var start = ray_dir * (0.4 + t * 0.9)
		var ray_len = (2.5 + float(i % 3) * 0.7 + (1.4 if heavy_hit else 0.0)) * (1.0 - t * 0.58)
		var end = start + ray_dir * ray_len
		var line_color = Color(base_color.r, base_color.g, base_color.b, (0.92 - 0.06 * i) * alpha)
		draw_line(start, end, line_color, 0.46 if heavy_hit else 0.32)
	if heavy_hit:
		var blast_t = 1.0 - t
		draw_arc(
			Vector2.ZERO,
			4.4 + 7.4 * t,
			0.0,
			TAU,
			30,
			Color(base_color.r, base_color.g, base_color.b, 0.24 * blast_t),
			1.1
		)
		draw_line(Vector2(-2.8, -1.0), Vector2(2.8, 1.0), Color(base_color.r, base_color.g, base_color.b, 0.36 * blast_t), 0.58)
		draw_line(Vector2(-2.8, 1.0), Vector2(2.8, -1.0), Color(base_color.r, base_color.g, base_color.b, 0.36 * blast_t), 0.58)

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
