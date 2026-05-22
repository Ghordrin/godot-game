extends Node
class_name HealthComponent

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

@export var max_health: int = 100

var current_health: int
var is_dead: bool       = false

## When true all incoming damage is ignored.
## Set by the player dash for iFrames, or by any other invincibility source.
var is_invincible: bool = false

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

## Main damage entry point.
## Uses lazy component lookup so ShieldComponent and ArmorComponent added
## dynamically by AffixComponent are always found regardless of spawn order.
func take_damage(amount: float, damage_type: String = "physical") -> void:
	if is_dead or is_invincible:
		return
	if amount <= 0.0:
		return

	var actual: float = amount

	# Lazy lookup — components may be added after _ready() by AffixComponent
	var affix  := get_parent().get_node_or_null("AffixComponent")  as AffixComponent
	var shield := get_parent().get_node_or_null("ShieldComponent") as ShieldComponent
	var armor  := get_parent().get_node_or_null("ArmorComponent")  as ArmorComponent

	# AffixComponent modifies damage first (CONDUCTIVE doubles lightning, WARDED blocks combo)
	if affix != null:
		actual = affix.modify_incoming_damage(actual, damage_type)
		if actual <= 0.0:
			return

	# Shield absorbs before health.
	# Poison and combo bypass it — they represent effects that ignore external defences.
	if shield != null and not shield.is_broken and damage_type != "poison" and damage_type != "combo":
		actual = shield.absorb(actual)
		if actual <= 0.0:
			return

	# Armour reduces remaining damage based on type
	if armor != null:
		actual = armor.reduce(actual, damage_type)

	var final_damage: int = max(1, int(round(actual)))
	current_health = max(current_health - final_damage, 0)
	damaged.emit(final_damage)
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
	is_dead        = true
	current_health = 0
	health_changed.emit(current_health, max_health)
	died.emit()
