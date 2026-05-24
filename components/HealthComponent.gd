extends Node
class_name HealthComponent

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

@export var max_health: int = 100

var current_health: int
var is_dead: bool = false
var is_invincible: bool = false


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: float, damage_type: String = "physical") -> void:
	var packet := DamagePacket.new()
	packet.add_damage(amount, damage_type, "legacy")
	take_damage_packet(packet)


func take_damage_packet(packet: DamagePacket) -> void:
	if packet == null:
		return

	if is_dead or is_invincible:
		return

	if packet.is_empty():
		return

	var total_final_damage: int = DamageMitigation.resolve_packet(get_parent(), packet)

	if total_final_damage <= 0:
		return

	current_health = max(current_health - total_final_damage, 0)

	damaged.emit(total_final_damage)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()


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


func set_max_health(new_max_health: int, refill_health: bool = true) -> void:
	max_health = max(1, new_max_health)

	if refill_health:
		current_health = max_health
	else:
		current_health = clamp(current_health, 0, max_health)

	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()


func scale_max_health(multiplier: float, refill_health: bool = true) -> void:
	var scaled_health: int = max(1, int(round(float(max_health) * multiplier)))
	set_max_health(scaled_health, refill_health)


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
