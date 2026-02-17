extends Node2D

var base_color: Color = Color(1.0, 0.42, 0.22, 0.95)
var base_radius: float = 14.0
var duration: float = 0.34
var elapsed: float = 0.0
var spark_count: int = 10
var spin_offset: float = 0.0
var se_player: AudioStreamPlayer2D = null
var se_variant: String = "normal"

const SE_MIX_RATE := 22050
const SE_DURATION := 0.16

func _ready() -> void:
	spin_offset = float(get_instance_id() % 17) * 0.23
	z_index = 50
	if DisplayServer.get_name() != "headless":
		_play_death_se()
	queue_redraw()

func configure(color: Color, radius: float = 14.0, variant: String = "normal") -> void:
	base_color = color
	base_radius = maxf(6.0, radius)
	se_variant = variant

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - t, 2.0)
	var alpha := 1.0 - t
	var core_color := Color(base_color.r, base_color.g, base_color.b, 0.28 * alpha)
	var ring_color := Color(base_color.r, base_color.g, base_color.b, 0.85 * alpha)

	draw_circle(Vector2.ZERO, base_radius * (0.28 + 0.72 * ease_out), core_color)
	draw_arc(Vector2.ZERO, base_radius * (0.8 + 1.6 * ease_out), 0.0, TAU, 30, ring_color, 2.2)

	for i in range(spark_count):
		var seed := float(i + 1)
		var angle := TAU * seed / float(spark_count) + spin_offset + t * (1.9 + seed * 0.03)
		var distance := base_radius * (0.5 + 2.4 * ease_out) + fmod(seed * 3.7, 5.0)
		var spark_pos := Vector2.RIGHT.rotated(angle) * distance
		var spark_alpha := clampf((0.82 - 0.06 * seed) * alpha, 0.0, 1.0)
		var spark_size := maxf(1.0, 2.4 - t * 1.6)
		draw_circle(spark_pos, spark_size, Color(1.0, 0.92, 0.74, spark_alpha))

func _play_death_se() -> void:
	se_player = AudioStreamPlayer2D.new()
	se_player.max_distance = 1800.0
	var start_freq := 900.0
	var end_freq := 210.0
	var noise_mix := 0.22
	var se_duration := SE_DURATION
	var volume_db := -8.0
	match se_variant:
		"elite":
			start_freq = 1050.0
			end_freq = 250.0
			noise_mix = 0.18
			se_duration = 0.18
			volume_db = -6.5
		"boss":
			start_freq = 1280.0
			end_freq = 170.0
			noise_mix = 0.14
			se_duration = 0.24
			volume_db = -4.0
		_:
			pass
	var pitch_jitter := randf_range(0.94, 1.06)
	start_freq *= pitch_jitter
	end_freq *= pitch_jitter
	se_player.volume_db = volume_db
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SE_MIX_RATE
	stream.buffer_length = 0.22
	se_player.stream = stream
	add_child(se_player)
	se_player.play()

	var playback := se_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var total_frames := int(SE_MIX_RATE * se_duration)
	var frames_available := playback.get_frames_available()
	var write_count := mini(total_frames, frames_available)
	for i in range(write_count):
		var progress := float(i) / float(maxi(1, total_frames - 1))
		var freq := lerpf(start_freq, end_freq, progress)
		var time_sec := float(i) / float(SE_MIX_RATE)
		var envelope := pow(1.0 - progress, 1.8)
		var tone := sin(TAU * freq * time_sec)
		var grit := randf_range(-1.0, 1.0) * noise_mix
		var sample := clampf((tone * 0.68 + grit) * envelope, -1.0, 1.0)
		playback.push_frame(Vector2(sample, sample))
