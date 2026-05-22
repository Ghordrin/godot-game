extends Area2D
class_name OrbitalShard

## Radial shard fired after an orbital strike lands.
## Built entirely in code — no scene file needed.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 220.0
var damage: float = 35.0
var lifetime: float = 4.5

var _elapsed: float = 0.0


static func create(dir: Vector2, spd: float = 220.0, dmg: float = 35.0) -> OrbitalShard:
	var shard := OrbitalShard.new()
	shard.direction = dir.normalized()
	shard.speed = spd
	shard.damage = dmg
	shard.rotation = dir.angle()
	return shard


func _ready() -> void:
	add_to_group("projectiles")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	add_child(col)

	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_elapsed += delta
	global_position += direction * speed * delta

	var fade_start: float = lifetime - 0.8
	if _elapsed > fade_start:
		modulate.a = 1.0 - (_elapsed - fade_start) / 0.8

	queue_redraw()

	if _elapsed >= lifetime:
		queue_free()


func _draw() -> void:
	var alpha: float = modulate.a

	draw_circle(Vector2(-10.0, 0.0), 5.0, Color(1.0, 0.45, 0.05, 0.25 * alpha))
	draw_circle(Vector2(-6.0, 0.0), 7.0, Color(1.0, 0.55, 0.05, 0.35 * alpha))
	draw_circle(Vector2(-2.0, 0.0), 8.0, Color(1.0, 0.65, 0.10, 0.80 * alpha))
	draw_circle(Vector2(4.0, 0.0), 5.0, Color(1.0, 0.85, 0.50, 0.95 * alpha))
	draw_circle(Vector2(2.0, 0.0), 3.0, Color(1.0, 1.0, 0.90, alpha))


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var damage_type: String = "physical"

	var hc := body.get_node_or_null("HealthComponent")
	if hc and hc.has_method("take_damage"):
		hc.take_damage(damage, damage_type)

	if is_inside_tree():
		DamageNumberSpawner.spawn(
			global_position,
			damage,
			DamageVisuals.get_display_name(damage_type),
			DamageVisuals.get_color(damage_type),
			0,
			false
		)

	queue_free()
