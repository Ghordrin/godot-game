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

	var total_final_damage: int = 0

	for entry: Dictionary in packet.entries:
		var amount: float = float(entry.amount)
		var damage_type: String = String(entry.type)

		if amount <= 0.0:
			continue

		var final_amount: float = _resolve_single_damage_entry(amount, damage_type)

		if final_amount <= 0.0:
			continue

		total_final_damage += max(1, int(round(final_amount)))

	if total_final_damage <= 0:
		return

	current_health = max(current_health - total_final_damage, 0)
	damaged.emit(total_final_damage)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()


func _resolve_single_damage_entry(amount: float, damage_type: String) -> float:
	var actual: float = amount

	var affix := get_parent().get_node_or_null("AffixComponent") as AffixComponent
	var shield := get_parent().get_node_or_null("ShieldComponent") as ShieldComponent
	var armor := get_parent().get_node_or_null("ArmorComponent") as ArmorComponent

	if affix != null:
		actual = affix.modify_incoming_damage(actual, damage_type)
		if actual <= 0.0:
			return 0.0

	if shield != null and not shield.is_broken and damage_type != "poison" and damage_type != "combo":
		actual = shield.absorb(actual)
		if actual <= 0.0:
			return 0.0

	if armor != null:
		actual = armor.reduce(actual, damage_type)

	return actual


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
