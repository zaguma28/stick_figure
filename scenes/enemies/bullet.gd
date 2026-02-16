extends Area2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0
var damage: int = 16
var lifetime: float = 5.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, 0, null)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4, Color(1.0, 0.5, 0.2))
