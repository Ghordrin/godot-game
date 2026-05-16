extends Area2D
class_name Projectile

@export var speed: float = 300.0
@export var damage: int = 10
@export var lifetime: float = 10.0
@export var animation_name: String = "default"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.RIGHT
var pierces_enemies: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	play_projectile_animation()

	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta


func setup(new_direction: Vector2, new_damage: int = 10) -> void:
	direction = new_direction.normalized()
	damage = new_damage

	if direction != Vector2.ZERO:
		rotation = direction.angle()


func play_projectile_animation() -> void:
	if animated_sprite == null:
		return

	if animated_sprite.sprite_frames == null:
		return

	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	else:
		var animations := animated_sprite.sprite_frames.get_animation_names()
		if animations.size() > 0:
			animated_sprite.play(animations[0])


func _on_body_entered(body: Node2D) -> void:
	print("BODY HIT: ", body.name,
		  " | parent: ", body.get_parent().name,
		  " | layer: ", body.collision_layer,
		  " | my mask: ", collision_mask)


func _on_area_entered(area: Area2D) -> void:
	print("HIT: ", area.name,
		  " | parent: ", area.get_parent().name,
		  " | layer: ", area.collision_layer,
		  " | my mask: ", collision_mask)
	_try_damage(area)


func _try_damage(target: Node) -> void:
	var health_component := target.get_node_or_null("HealthComponent")

	if health_component == null and target.get_parent() != null:
		health_component = target.get_parent().get_node_or_null("HealthComponent")

	if health_component != null:
		health_component.take_damage(damage)

		if not pierces_enemies:
			queue_free()
