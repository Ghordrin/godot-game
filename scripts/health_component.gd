extends Node
class_name HealthComponent

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

@export var max_health: int = 100
@export var damage_number_scene: PackedScene

var current_health: int
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: int) -> void:
	if is_dead:
		return

	if amount <= 0:
		return

	current_health = max(current_health - amount, 0)

	damaged.emit(amount)
	_spawn_damage_number(amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()

func _spawn_damage_number(amount: int) -> void:
	if damage_number_scene == null:
		return

	var damage_number := damage_number_scene.instantiate() as DamageNumber

	if damage_number == null:
		return

	get_tree().current_scene.add_child(damage_number)

	var owner_node := owner as Node2D
	if owner_node != null:
		damage_number.global_position = owner_node.global_position + Vector2(0, -24)

	damage_number.setup(amount)

func heal(amount: int) -> void:
	if is_dead:
		return

	if amount <= 0:
		return

	current_health = min(current_health + amount, max_health)

	healed.emit(amount)
	health_changed.emit(current_health, max_health)


func set_health(value: int) -> void:
	if is_dead:
		return

	current_health = clamp(value, 0, max_health)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()


func revive(health_amount: int = -1) -> void:
	is_dead = false

	if health_amount < 0:
		current_health = max_health
	else:
		current_health = clamp(health_amount, 1, max_health)

	health_changed.emit(current_health, max_health)


func die() -> void:
	if is_dead:
		return

	is_dead = true
	current_health = 0

	health_changed.emit(current_health, max_health)
	died.emit()
