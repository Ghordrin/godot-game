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
# Never modified after _ready — used as the ground-truth base for scale_max_health
# so pooled enemies don't compound health multipliers across reuses.
var base_max_health: int = 0


func _ready() -> void:
	base_max_health = max_health
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: float, damage_type: String = "physical") -> void:
	var packet := DamagePacket.new()
	packet.add_damage(amount, damage_type, "legacy")
	take_damage_packet(packet)


func take_damage_packet(packet: DamagePacket) -> void:
	if packet == null:
		_log_damage_ignored("packet_null", "")
		return

	if is_dead:
		_log_damage_ignored("already_dead", CombatDebugLogger.summarize_packet(packet))
		return

	if is_invincible:
		_log_damage_ignored("invincible", CombatDebugLogger.summarize_packet(packet))
		return

	if packet.is_empty():
		_log_damage_ignored("packet_empty", CombatDebugLogger.summarize_packet(packet))
		return

	var health_before: int = current_health
	var raw_total: float = _get_packet_raw_total(packet)
	var total_final_damage: int = DamageMitigation.resolve_packet(get_parent(), packet)

	if total_final_damage <= 0:
		_log_damage_ignored(
			"final_damage_zero",
			CombatDebugLogger.summarize_packet(packet)
		)
		return

	current_health = max(current_health - total_final_damage, 0)

	_log_damage_event(
		raw_total,
		total_final_damage,
		packet.entries,
		health_before,
		current_health
	)

	damaged.emit(total_final_damage)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()


func heal(amount: int) -> void:
	if is_dead:
		return

	if amount <= 0:
		return

	var old_health: int = current_health
	current_health = min(current_health + amount, max_health)

	CombatDebugLogger.log_heal(get_parent(), amount, old_health, current_health, max_health)

	healed.emit(amount)
	health_changed.emit(current_health, max_health)


func set_health(value: int) -> void:
	if is_dead:
		return

	var old_health: int = current_health
	current_health = clamp(value, 0, max_health)

	CombatDebugLogger.log_health_set(get_parent(), old_health, current_health, max_health)

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


func scale_max_health(multiplier: float, refill_health: bool = true) -> void:
	var base: int = base_max_health if base_max_health > 0 else max_health
	var scaled_health: int = max(1, int(round(float(base) * multiplier)))
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

	CombatDebugLogger.log_death(get_parent(), max_health)

	health_changed.emit(current_health, max_health)
	died.emit()


func _get_packet_raw_total(packet: DamagePacket) -> float:
	if packet == null:
		return 0.0

	var total: float = 0.0

	for entry: Dictionary in packet.entries:
		total += float(entry.get("amount", 0.0))

	return total


func _log_damage_event(
	raw_total: float,
	final_damage: int,
	damage_breakdown: Array,
	health_before: int,
	health_after: int
) -> void:
	CombatDebugLogger.log_damage(
		get_parent(),
		raw_total,
		final_damage,
		damage_breakdown,
		health_before,
		health_after,
		max_health
	)


func _log_damage_ignored(reason: String, packet_summary: String) -> void:
	CombatDebugLogger.log_damage_ignored(
		get_parent(),
		reason,
		packet_summary
	)
