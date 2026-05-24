# components/ArmorComponent.gd
class_name ArmorComponent
extends Node

## Armor value used for percentage-based mitigation.
## Higher armor means more reduction, but damage should never become 0 just because armor is higher.
@export var base_armor: float = 10.0

## Current effective armor after permanent stripping.
var current_armor: float = 0.0

## Corrosive strip — each stack permanently reduces armor by this fraction.
const STRIP_PER_STACK: float = 0.1
const MAX_STRIP_FRACTION: float = 0.8

## Thermal pressure — temporary armor reduction, recovers after duration.
var _pressure_reduction: float = 0.0
var _pressure_timer: float = 0.0

## Tracks how many Corrosive stacks have been applied.
var _strip_stacks: int = 0

var is_broken: bool = false

## Compatibility property — AffixComponent sets armor_value by name.
var armor_value: float:
	get:
		return base_armor
	set(v):
		base_armor = maxf(0.0, v)
		current_armor = base_armor
		is_broken = current_armor <= 0.0


func _ready() -> void:
	current_armor = base_armor
	is_broken = current_armor <= 0.0


func _process(delta: float) -> void:
	if _pressure_timer <= 0.0:
		return

	_pressure_timer -= delta

	if _pressure_timer <= 0.0:
		_pressure_timer = 0.0
		_pressure_reduction = 0.0


## Compatibility shim — DamageMitigation calls reduce(amount, damage_type).
func reduce(incoming: float, damage_type: String = "physical") -> float:
	if incoming <= 0.0:
		return 0.0

	if damage_type == "fire":
		erode(incoming * 0.20)

	return absorb(incoming)


## Returns damage remaining after armor mitigation.
## Formula:
## final_damage = incoming * (100 / (100 + armor))
##
## Examples:
## 25 armor: 18 damage -> 14.4 damage
## 50 armor: 18 damage -> 12.0 damage
## 100 armor: 18 damage -> 9.0 damage
func absorb(incoming: float) -> float:
	if incoming <= 0.0:
		return 0.0

	var effective: float = _get_effective_armor()

	if effective <= 0.0:
		return incoming

	var multiplier: float = 100.0 / (100.0 + effective)
	var reduced: float = incoming * multiplier

	return maxf(1.0, reduced)


## Called by direct erosion effects.
func erode(amount: float) -> void:
	if amount <= 0.0:
		return

	current_armor = maxf(0.0, current_armor - amount)
	is_broken = current_armor <= 0.0


## Thermal: temporary armor reduction by fraction for duration seconds.
func apply_pressure(fraction: float, duration: float) -> void:
	var safe_fraction: float = clampf(fraction, 0.0, 0.95)

	_pressure_reduction = maxf(
		_pressure_reduction,
		base_armor * safe_fraction
	)

	_pressure_timer = maxf(_pressure_timer, duration)


## Corrosive: permanent stack-based strip.
func apply_strip_stack(stacks: int) -> void:
	_strip_stacks = clampi(stacks, 0, 10)

	var strip_fraction: float = minf(
		float(_strip_stacks) * STRIP_PER_STACK,
		MAX_STRIP_FRACTION
	)

	current_armor = base_armor * (1.0 - strip_fraction)
	is_broken = current_armor <= 0.0


func get_effective_armor() -> float:
	return _get_effective_armor()


func _get_effective_armor() -> float:
	return maxf(0.0, current_armor - _pressure_reduction)
