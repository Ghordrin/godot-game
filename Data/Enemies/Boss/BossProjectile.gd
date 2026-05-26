extends Area2D
class_name BossProjectile

@export var speed: float = 1200
@export var damage: int = 15
@export var lifetime: float = 8.0

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	
	# Temporary visual — red circle drawn in code until you have a real sprite.
	var dot := Sprite2D.new()
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.2, 0.1))
	dot.texture = ImageTexture.create_from_image(img)
	add_child(dot)
	collision_layer = 0
	collision_mask = 1  # player only

	body_entered.connect(_on_body_entered)

	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta

func setup(new_direction: Vector2, new_damage: int = 15) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var hc := body.get_node_or_null("HealthComponent") as Node
	if hc and hc.has_method("take_damage"):
		hc.take_damage(damage)
	queue_free()
