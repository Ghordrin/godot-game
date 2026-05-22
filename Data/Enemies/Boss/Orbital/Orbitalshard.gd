extends Area2D
class_name OrbitalShard

## Radial shard fired after an orbital strike lands.
## Eight spawn simultaneously pointing in all directions.
## Built entirely in code — no scene file needed.

## Travel direction. Set via OrbitalShard.from_direction() before adding to scene.
var direction: Vector2 = Vector2.RIGHT

## Travel speed in pixels per second.
var speed: float = 220.0

## Damage on contact with the player.
var damage: float = 35.0

## Seconds before the shard self-destructs if it never hits anything.
var lifetime: float = 4.5

var _elapsed: float = 0.0


## Convenience constructor — returns a ready-to-add shard flying in `dir`.
static func create(dir: Vector2, spd: float = 220.0, dmg: float = 35.0) -> OrbitalShard:
	var shard       := OrbitalShard.new()
	shard.direction  = dir.normalized()
	shard.speed      = spd
	shard.damage     = dmg
	shard.rotation   = dir.angle()  # Rotate visual to face travel direction
	return shard


func _ready() -> void:
	add_to_group("projectiles")  # Cleared by WaveManager on wave end

	# Collision shape — sized to match the drawn visual
	var col   := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	col.shape    = shape
	add_child(col)

	monitoring      = true
	monitorable     = false
	collision_layer = 0
	collision_mask  = 1  # Match your player's collision layer

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_elapsed        += delta
	global_position += direction * speed * delta

	# Fade out in the final 0.8s so it doesn't just vanish
	var fade_start: float = lifetime - 0.8
	if _elapsed > fade_start:
		modulate.a = 1.0 - (_elapsed - fade_start) / 0.8

	queue_redraw()

	if _elapsed >= lifetime:
		queue_free()


func _draw() -> void:
	## Draws a glowing teardrop/energy bolt shape.
	## The node is rotated to face the travel direction so the point leads.
	var alpha: float = modulate.a

	# Tail glow — soft orange ellipse behind the tip
	draw_circle(Vector2(-10.0, 0.0), 5.0, Color(1.0, 0.45, 0.05, 0.25 * alpha))
	draw_circle(Vector2(-6.0,  0.0), 7.0, Color(1.0, 0.55, 0.05, 0.35 * alpha))

	# Core body — brighter inner
	draw_circle(Vector2(-2.0, 0.0), 8.0, Color(1.0, 0.65, 0.10, 0.80 * alpha))

	# Bright tip pointing forward
	draw_circle(Vector2(4.0, 0.0), 5.0, Color(1.0, 0.85, 0.50, 0.95 * alpha))

	# Hot white core
	draw_circle(Vector2(2.0, 0.0), 3.0, Color(1.0, 1.0,  0.90, alpha))


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var hc := body.get_node_or_null("HealthComponent")
	if hc and hc.has_method("take_damage"):
		hc.take_damage(damage, "physical")
	if is_inside_tree():
		DamageNumber.spawn(get_tree().current_scene, global_position, damage, Color(1.0, 0.55, 0.05))
	queue_free()
