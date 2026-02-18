extends Node2D

var level_left: float = -220.0
var level_right: float = 3600.0
var level_top: float = 60.0
var level_bottom: float = 760.0
var ground_y: float = 620.0

var focus_x: float = 0.0
var anim_time: float = 0.0
var floor_number: int = 1
var floor_type: String = "combat"
var mutator_id: String = ""
var weather_type: String = "none"
var weather_intensity: float = 0.0

var sky_top_color: Color = Color(0.06, 0.08, 0.14, 1.0)
var sky_mid_color: Color = Color(0.13, 0.16, 0.24, 1.0)
var sky_low_color: Color = Color(0.2, 0.16, 0.15, 1.0)
var horizon_glow_color: Color = Color(0.72, 0.46, 0.26, 0.32)
var ruin_far_color: Color = Color(0.09, 0.11, 0.17, 0.92)
var ruin_mid_color: Color = Color(0.12, 0.12, 0.16, 0.94)
var fog_color: Color = Color(0.58, 0.66, 0.78, 0.2)
var ground_top_color: Color = Color(0.26, 0.22, 0.19, 0.98)
var ground_deep_color: Color = Color(0.14, 0.11, 0.1, 1.0)
var platform_top_color: Color = Color(0.42, 0.36, 0.29, 0.96)
var platform_body_color: Color = Color(0.28, 0.24, 0.21, 0.96)
var platform_shadow_color: Color = Color(0.08, 0.08, 0.09, 0.45)

func _ready() -> void:
	z_as_relative = false
	z_index = -80
	set_process(true)
	queue_redraw()

func configure(left: float, right: float, top: float, bottom: float, ground: float) -> void:
	level_left = left
	level_right = right
	level_top = top
	level_bottom = bottom
	ground_y = ground
	queue_redraw()

func set_focus_x(x: float) -> void:
	focus_x = x

func set_floor_theme(next_floor_type: String, next_floor: int, floor_mutator: Dictionary = {}) -> void:
	floor_type = next_floor_type
	floor_number = maxi(1, next_floor)
	mutator_id = str(floor_mutator.get("id", ""))
	weather_type = "none"
	weather_intensity = 0.0

	match floor_type:
		"boss":
			sky_top_color = Color(0.09, 0.03, 0.04, 1.0)
			sky_mid_color = Color(0.18, 0.06, 0.08, 1.0)
			sky_low_color = Color(0.26, 0.1, 0.09, 1.0)
			horizon_glow_color = Color(1.0, 0.24, 0.16, 0.32)
			ruin_far_color = Color(0.16, 0.05, 0.08, 0.92)
			ruin_mid_color = Color(0.2, 0.08, 0.09, 0.94)
			fog_color = Color(0.88, 0.35, 0.3, 0.18)
			ground_top_color = Color(0.29, 0.18, 0.16, 0.98)
			ground_deep_color = Color(0.12, 0.07, 0.07, 1.0)
			weather_type = "ash"
			weather_intensity = 1.0
		"event":
			sky_top_color = Color(0.05, 0.12, 0.16, 1.0)
			sky_mid_color = Color(0.08, 0.19, 0.22, 1.0)
			sky_low_color = Color(0.16, 0.24, 0.2, 1.0)
			horizon_glow_color = Color(0.42, 0.68, 0.6, 0.25)
			ruin_far_color = Color(0.07, 0.15, 0.16, 0.9)
			ruin_mid_color = Color(0.1, 0.17, 0.17, 0.94)
			fog_color = Color(0.54, 0.78, 0.72, 0.16)
			ground_top_color = Color(0.2, 0.23, 0.19, 0.98)
			ground_deep_color = Color(0.11, 0.13, 0.12, 1.0)
			weather_type = "none"
			weather_intensity = 0.0
		_:
			var depth = clampf(float(floor_number - 1) / 9.0, 0.0, 1.0)
			sky_top_color = _mix_color(Color(0.07, 0.1, 0.17, 1.0), Color(0.04, 0.05, 0.09, 1.0), depth)
			sky_mid_color = _mix_color(Color(0.13, 0.17, 0.26, 1.0), Color(0.11, 0.1, 0.18, 1.0), depth)
			sky_low_color = _mix_color(Color(0.23, 0.19, 0.16, 1.0), Color(0.2, 0.12, 0.11, 1.0), depth)
			horizon_glow_color = _mix_color(Color(0.78, 0.52, 0.28, 0.26), Color(0.85, 0.3, 0.2, 0.25), depth)
			ruin_far_color = _mix_color(Color(0.08, 0.1, 0.16, 0.92), Color(0.1, 0.08, 0.13, 0.92), depth)
			ruin_mid_color = _mix_color(Color(0.12, 0.12, 0.16, 0.94), Color(0.14, 0.1, 0.12, 0.94), depth)
			fog_color = _mix_color(Color(0.55, 0.65, 0.78, 0.16), Color(0.78, 0.5, 0.42, 0.14), depth)
			ground_top_color = _mix_color(Color(0.27, 0.22, 0.2, 0.98), Color(0.3, 0.18, 0.16, 0.98), depth)
			ground_deep_color = _mix_color(Color(0.14, 0.11, 0.1, 1.0), Color(0.11, 0.08, 0.08, 1.0), depth)
			if mutator_id == "aggressive":
				weather_type = "rain"
				weather_intensity = 0.9
			elif mutator_id == "volatile":
				weather_type = "ash"
				weather_intensity = 0.9
			elif mutator_id == "fortified":
				weather_type = "rain"
				weather_intensity = 0.64
			else:
				var selector = floor_number % 4
				if selector == 0:
					weather_type = "rain"
					weather_intensity = 0.56
				elif selector == 2:
					weather_type = "ash"
					weather_intensity = 0.5
	queue_redraw()

func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()

func _draw() -> void:
	var pad = 1200.0
	var world_left = level_left - pad
	var world_right = level_right + pad
	var world_width = world_right - world_left
	_draw_sky(world_left, world_width)
	_draw_celestial(world_left)
	_draw_ruin_layer(world_left, world_right, ground_y - 280.0, 250.0, 0.1, 190.0, ruin_far_color)
	_draw_ruin_layer(world_left, world_right, ground_y - 250.0, 300.0, 0.18, 170.0, ruin_mid_color)
	_draw_boss_alert(world_left, world_right)
	_draw_weather(world_left, world_right)
	_draw_fog(world_left, world_right)
	_draw_mutator_overlay(world_left, world_right)
	_draw_ground(world_left, world_width)
	_draw_props(world_left, world_right)
	_draw_platforms()

func _draw_sky(world_left: float, world_width: float) -> void:
	var y_top = level_top - 980.0
	var y_bottom = ground_y + 140.0
	var strip_count = 22
	for i in range(strip_count):
		var t0 = float(i) / float(strip_count)
		var t1 = float(i + 1) / float(strip_count)
		var y = lerpf(y_top, y_bottom, t0)
		var next_y = lerpf(y_top, y_bottom, t1)
		var h = maxf(1.0, next_y - y + 1.0)
		var color = sky_top_color
		if t0 < 0.6:
			color = _mix_color(sky_top_color, sky_mid_color, t0 / 0.6)
		else:
			color = _mix_color(sky_mid_color, sky_low_color, (t0 - 0.6) / 0.4)
		draw_rect(Rect2(world_left, y, world_width, h), color)
	var glow_y = ground_y - 190.0
	draw_rect(Rect2(world_left, glow_y, world_width, 130.0), horizon_glow_color)

func _draw_celestial(world_left: float) -> void:
	var loop_width = (level_right - level_left) + 1000.0
	var moon_x = level_left - 300.0 + fposmod(focus_x * 0.16 + 760.0, loop_width)
	var moon_y = level_top + 170.0 + sin(anim_time * 0.23) * 6.0
	var moon_center = Vector2(moon_x, moon_y)
	draw_circle(moon_center, 86.0, Color(0.9, 0.9, 0.95, 0.08))
	draw_circle(moon_center, 46.0, Color(0.97, 0.93, 0.88, 0.24))
	var streak_y = moon_y + 80.0
	draw_line(
		Vector2(world_left, streak_y),
		Vector2(world_left + (level_right - level_left) + 2400.0, streak_y),
		Color(0.92, 0.78, 0.64, 0.06),
		2.2
	)

func _draw_ruin_layer(
	world_left: float,
	world_right: float,
	base_y: float,
	max_height: float,
	parallax: float,
	step: float,
	color: Color
) -> void:
	var offset = fposmod(-focus_x * parallax, step)
	var x = world_left - step + offset
	while x < world_right + step:
		var n = _noise01(x * 0.011 + float(floor_number) * 0.83)
		var width = step * (0.44 + 0.64 * _noise01(x * 0.021 + 13.0))
		var height = max_height * (0.36 + 0.64 * n)
		draw_rect(Rect2(x, base_y - height, width, height + 16.0), color)
		if _noise01(x * 0.017 + 3.7) > 0.58:
			var spire_x = x + width * (0.2 + 0.62 * _noise01(x * 0.013 + 8.0))
			var spire_h = height * (0.16 + 0.34 * _noise01(x * 0.009 + 4.0))
			var spire_color = Color(
				minf(color.r + 0.05, 1.0),
				minf(color.g + 0.05, 1.0),
				minf(color.b + 0.05, 1.0),
				color.a
			)
			draw_rect(Rect2(spire_x, base_y - height - spire_h, 4.0, spire_h + 4.0), spire_color)
		x += maxf(44.0, step * (0.74 + 0.56 * _noise01(x * 0.015 + 2.0)))

func _draw_fog(world_left: float, world_right: float) -> void:
	for layer in range(4):
		var layer_f = float(layer)
		var y_base = ground_y - 232.0 + layer_f * 52.0
		var step = 88.0
		var x = world_left
		var prev = Vector2(x, y_base)
		while x <= world_right + step:
			x += step
			var wave = sin((x + focus_x * (0.14 + layer_f * 0.03)) * 0.007 + anim_time * (0.48 + layer_f * 0.16))
			var ripple = sin((x + focus_x * 0.06) * 0.019 + anim_time * 0.85 + layer_f)
			var y = y_base + wave * (8.0 - layer_f) + ripple * 2.5
			var alpha = maxf(0.04, 0.2 - layer_f * 0.04)
			var c = Color(fog_color.r, fog_color.g, fog_color.b, alpha)
			var current = Vector2(x, y)
			draw_line(prev, current, c, 2.2 - layer_f * 0.28)
			prev = current

func _draw_mutator_overlay(world_left: float, world_right: float) -> void:
	if mutator_id == "":
		return
	var width = world_right - world_left
	match mutator_id:
		"aggressive":
			var step = 220.0
			var phase = fposmod(anim_time * 220.0 + focus_x * 0.24, step)
			var x = world_left - step + phase
			while x < world_right + step:
				draw_line(
					Vector2(x, ground_y - 248.0),
					Vector2(x + 96.0, ground_y - 112.0),
					Color(0.9, 0.26, 0.24, 0.12),
					1.5
				)
				x += step
		"fortified":
			var bar_count = 18
			for i in range(bar_count):
				var t = float(i) / float(maxi(1, bar_count - 1))
				var x = world_left + t * width + fposmod(-focus_x * 0.08, width / float(bar_count))
				draw_rect(Rect2(x, ground_y - 300.0, 18.0, 190.0), Color(0.24, 0.56, 0.64, 0.08))
		"volatile":
			var spark_count = 28
			for i in range(spark_count):
				var seed = float(i)
				var px = world_left + fposmod(seed * 171.0 + anim_time * 180.0, width)
				var py = ground_y - 210.0 + sin(anim_time * 2.0 + seed * 0.7) * (68.0 + fmod(seed * 3.3, 34.0))
				var r = 1.2 + fmod(seed, 3.0) * 0.7
				draw_circle(Vector2(px, py), r, Color(1.0, 0.62, 0.24, 0.2))
		_:
			pass

func _draw_weather(world_left: float, world_right: float) -> void:
	if weather_type == "none" or weather_intensity <= 0.0:
		return
	var width = world_right - world_left
	match weather_type:
		"rain":
			var drop_count = int(round(70.0 + 88.0 * weather_intensity))
			for i in range(drop_count):
				var seed = float(i + 1)
				var px = world_left + fposmod(
					seed * 137.0 + anim_time * (560.0 + 120.0 * weather_intensity) + focus_x * 0.06,
					width
				)
				var py = level_top - 420.0 + fposmod(
					seed * 91.0 + anim_time * (730.0 + 220.0 * weather_intensity),
					(ground_y - level_top) + 640.0
				)
				var drop_len = 14.0 + 18.0 * _noise01(seed * 0.31 + anim_time * 1.2)
				var dx = 3.5 + 2.4 * weather_intensity
				var rain_alpha = 0.1 + 0.16 * weather_intensity
				draw_line(
					Vector2(px, py),
					Vector2(px + dx, py + drop_len),
					Color(0.72, 0.82, 0.95, rain_alpha),
					1.0
				)
				if py >= ground_y - 6.0 and py <= ground_y + 20.0 and fmod(seed, 4.0) <= 1.0:
					draw_line(
						Vector2(px - 2.0, ground_y + 1.0),
						Vector2(px + 4.0, ground_y + 1.0),
						Color(0.82, 0.9, 0.98, 0.14),
						1.0
					)
		"ash":
			var flake_count = int(round(46.0 + 74.0 * weather_intensity))
			for i in range(flake_count):
				var seed = float(i + 1)
				var px = world_left + fposmod(seed * 157.0 - anim_time * 34.0 + focus_x * 0.04, width)
				var py = level_top - 320.0 + fposmod(seed * 68.0 + anim_time * (42.0 + 24.0 * weather_intensity), (ground_y - level_top) + 520.0)
				var drift = sin(anim_time * 1.1 + seed * 0.22) * (8.0 + 16.0 * weather_intensity)
				var radius = 1.1 + 2.2 * _noise01(seed * 0.17 + anim_time * 0.7)
				draw_circle(
					Vector2(px + drift, py),
					radius,
					Color(0.96, 0.72, 0.62, 0.08 + 0.15 * weather_intensity)
				)
		_:
			pass

func _draw_boss_alert(world_left: float, world_right: float) -> void:
	if floor_type != "boss":
		return
	var width = world_right - world_left
	var pulse = 0.5 + 0.5 * sin(anim_time * 2.4)
	var aura_alpha = 0.05 + 0.09 * pulse
	draw_rect(
		Rect2(world_left, level_top - 980.0, width, (ground_y - level_top) + 1180.0),
		Color(1.0, 0.12, 0.1, aura_alpha)
	)
	var step = 260.0
	var offset = fposmod(anim_time * 260.0 + focus_x * 0.12, step)
	var x = world_left - step + offset
	while x < world_right + step:
		draw_line(
			Vector2(x, ground_y - 420.0),
			Vector2(x + 110.0, ground_y - 118.0),
			Color(1.0, 0.52, 0.42, 0.14 + 0.08 * pulse),
			1.6
		)
		x += step
	var ring_y = ground_y - 184.0 + sin(anim_time * 2.1) * 9.0
	draw_line(
		Vector2(world_left, ring_y),
		Vector2(world_right, ring_y),
		Color(1.0, 0.74, 0.65, 0.12 + pulse * 0.07),
		2.2
	)

func _draw_ground(world_left: float, world_width: float) -> void:
	draw_rect(Rect2(world_left, ground_y, world_width, 420.0), ground_top_color)
	draw_rect(Rect2(world_left, ground_y + 80.0, world_width, 360.0), ground_deep_color)
	var seam_step = 180.0
	var seam_offset = fposmod(-focus_x * 0.22, seam_step)
	var x = world_left - seam_step + seam_offset
	while x < world_left + world_width + seam_step:
		var y0 = ground_y + 18.0 + sin((x + anim_time * 40.0) * 0.01) * 3.2
		var y1 = y0 + 22.0 + sin((x + anim_time * 25.0) * 0.015) * 4.0
		draw_line(Vector2(x, y0), Vector2(x + 96.0, y1), Color(0.34, 0.3, 0.24, 0.24), 1.5)
		x += seam_step

func _draw_props(world_left: float, world_right: float) -> void:
	var props: Array[Dictionary] = [
		{"x": 420.0, "h": 118.0, "w": 20.0, "lean": -0.05},
		{"x": 760.0, "h": 138.0, "w": 24.0, "lean": 0.03},
		{"x": 1120.0, "h": 96.0, "w": 18.0, "lean": -0.08},
		{"x": 1700.0, "h": 124.0, "w": 22.0, "lean": 0.04},
		{"x": 2360.0, "h": 110.0, "w": 20.0, "lean": -0.03},
		{"x": 3020.0, "h": 132.0, "w": 24.0, "lean": 0.05},
		{"x": 3400.0, "h": 102.0, "w": 18.0, "lean": -0.06}
	]
	for prop_variant in props:
		var prop: Dictionary = prop_variant
		var x: float = float(prop.get("x", 0.0))
		if x < world_left - 180.0 or x > world_right + 180.0:
			continue
		_draw_ruin_column(
			x,
			ground_y + 2.0,
			float(prop.get("h", 100.0)),
			float(prop.get("w", 20.0)),
			float(prop.get("lean", 0.0))
		)
	_draw_warning_sign(980.0, ground_y)
	_draw_warning_sign(2540.0, ground_y)

func _draw_ruin_column(x: float, base_y: float, height: float, width: float, lean: float) -> void:
	var shift = lean * height
	var half = width * 0.5
	var p0 = Vector2(x - half, base_y)
	var p1 = Vector2(x + half, base_y)
	var p2 = Vector2(x + half + shift, base_y - height)
	var p3 = Vector2(x - half + shift, base_y - height)
	var poly = PackedVector2Array([p0, p1, p2, p3])
	draw_colored_polygon(poly, Color(0.22, 0.21, 0.2, 0.32))
	draw_line(p0, p3, Color(0.08, 0.08, 0.09, 0.34), 1.5)
	draw_line(p1, p2, Color(0.08, 0.08, 0.09, 0.34), 1.5)
	draw_line(p3, p2, Color(0.42, 0.37, 0.3, 0.24), 1.3)
	for i in range(3):
		var t = float(i + 1) / 4.0
		var lx0 = lerpf(p0.x, p3.x, t)
		var ly0 = lerpf(p0.y, p3.y, t)
		var lx1 = lerpf(p1.x, p2.x, t)
		var ly1 = lerpf(p1.y, p2.y, t)
		draw_line(Vector2(lx0, ly0), Vector2(lx1, ly1), Color(0.5, 0.44, 0.34, 0.16), 1.0)

func _draw_warning_sign(x: float, base_y: float) -> void:
	var post_h = 74.0
	draw_rect(Rect2(x - 3.0, base_y - post_h, 6.0, post_h), Color(0.2, 0.19, 0.18, 0.42))
	var board = Rect2(x - 28.0, base_y - post_h - 28.0, 56.0, 24.0)
	draw_rect(board, Color(0.28, 0.2, 0.16, 0.42))
	var stripe_count = 4
	for i in range(stripe_count):
		var sx = board.position.x + float(i) * 16.0 - 2.0
		draw_line(
			Vector2(sx, board.position.y + board.size.y),
			Vector2(sx + 18.0, board.position.y),
			Color(0.88, 0.62, 0.3, 0.35),
			1.6
		)

func _draw_platforms() -> void:
	_draw_platform(1260.0, 470.0, 400.0)
	_draw_platform(2040.0, 390.0, 280.0)
	_draw_platform(2840.0, 330.0, 240.0)

func _draw_platform(center_x: float, y: float, width: float) -> void:
	var half = width * 0.5
	var top_rect = Rect2(center_x - half, y - 12.0, width, 14.0)
	var body_rect = Rect2(center_x - half + 10.0, y + 2.0, width - 20.0, 20.0)
	draw_rect(top_rect, platform_top_color)
	draw_rect(body_rect, platform_body_color)
	draw_line(
		Vector2(center_x - half, y + 4.0),
		Vector2(center_x + half, y + 4.0),
		Color(0.94, 0.84, 0.66, 0.14),
		1.2
	)
	var support_count = maxi(2, int(round(width / 120.0)))
	for i in range(support_count):
		var t = float(i + 1) / float(support_count + 1)
		var x = lerpf(center_x - half + 20.0, center_x + half - 20.0, t)
		draw_line(
			Vector2(x, y + 22.0),
			Vector2(x, y + 56.0),
			platform_shadow_color,
			2.0
		)

func _mix_color(a: Color, b: Color, t: float) -> Color:
	var ct = clampf(t, 0.0, 1.0)
	return Color(
		lerpf(a.r, b.r, ct),
		lerpf(a.g, b.g, ct),
		lerpf(a.b, b.b, ct),
		lerpf(a.a, b.a, ct)
	)

func _noise01(v: float) -> float:
	return 0.5 + 0.5 * sin(v * 1.231 + sin(v * 0.73) * 1.7)
