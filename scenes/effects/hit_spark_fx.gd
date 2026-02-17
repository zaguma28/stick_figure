extends Node2D

var direction: Vector2 = Vector2.RIGHT
var base_color: Color = Color(0.58, 0.9, 1.0, 0.95)
var heavy_hit: bool = false
var duration: float = 0.12
var elapsed: float = 0.0
var ray_count: int = 6
var spin: float = 0.0

func _ready() -> void:
	spin = randf_range(-0.5, 0.5)
	z_index = 60
	queue_redraw()

func configure(hit_dir: Vector2, color: Color, heavy: bool = false) -> void:
	if hit_dir.length() > 0.01:
		direction = hit_dir.normalized()
	base_color = color
	heavy_hit = heavy
	if heavy_hit:
		duration = 0.15
		ray_count = 8

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var alpha := 1.0 - t
	var push := direction * (8.0 + 12.0 * t)
	draw_circle(push * 0.16, 2.6 - t * 1.4, Color(base_color.r, base_color.g, base_color.b, 0.85 * alpha))
	var spread := 0.65 if heavy_hit else 0.48
	for i in range(ray_count):
		var ratio := (float(i) / float(maxi(1, ray_count - 1))) * 2.0 - 1.0
		var angle := ratio * spread + spin
		var ray_dir := direction.rotated(angle).normalized()
		var start := ray_dir * (2.0 + t * 3.0)
		var ray_len := (7.0 + randf_range(0.0, 5.0)) * (1.0 - t * 0.55)
		var end := start + ray_dir * ray_len
		var line_color := Color(base_color.r, base_color.g, base_color.b, (0.8 - 0.07 * i) * alpha)
		draw_line(start, end, line_color, 1.6)
