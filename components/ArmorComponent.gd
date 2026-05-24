# components/ArmorComponent.gd
class_name ArmorComponent
extends Node

## Flat armor value. Reduces incoming physical damage by this amount before health.
@export var base_armor: float = 10.0

## Current effective armor — reduced by Corrosive stacks and pressure.
var current_armor: float = 0.0

## Corrosive strip — each stack permanently reduces armor by this fraction.
const STRIP_PER_STACK: float   = 0.1
const MAX_STRIP_FRACTION: float = 0.8   ## Can never strip more than 80%

## Thermal pressure — temporary armor reduction, recovers after duration.
var _pressure_reduction: float = 0.0
var _pressure_timer: float     = 0.0

## Tracks how many Corrosive stacks have been applied.
var _strip_stacks: int = 0

## Compatibility property — AffixComponent sets armor_value by name.
var armor_value: float:
	get: return base_armor
	set(v):
		base_armor = v
		current_armor = v

## Compatibility shim — DamageMitigation calls reduce(amount, damage_type).
## Routes fire through erosion, everything else through flat absorption.
func reduce(incoming: float, damage_type: String = "physical") -> float:
	if damage_type == "fire" and not is_broken:
		var erosion: float = incoming * 0.5
		current_armor = maxf(0.0, current_armor - erosion)
		if current_armor <= 0.0:
			is_broken = true
	return absorb(incoming)

## Called by Corrosive combo — strips armor without dealing health damage.
func erode(amount: float) -> void:
	if is_broken:
		return
	current_armor = maxf(0.0, current_armor - amount)

var is_broken: bool = false


func _ready() -> void:
	current_armor = base_armor


func _process(delta: float) -> void:
	if _pressure_timer > 0.0:
		_pressure_timer -= delta
		if _pressure_timer <= 0.0:
			_pressure_reduction = 0.0


## Returns damage remaining after armor absorption.
func absorb(incoming: float) -> float:
	var effective: float = _get_effective_armor()
	var reduced: float   = maxf(0.0, incoming - effective)
	return reduced


## Thermal: temporary armor reduction by fraction for duration seconds.
func apply_pressure(fraction: float, duration: float) -> void:
	_pressure_reduction = maxf(_pressure_reduction, base_armor * fraction)
	_pressure_timer     = maxf(_pressure_timer, duration)


## Corrosive: permanent stack-based strip.
func apply_strip_stack(stacks: int) -> void:
	_strip_stacks = mini(stacks, 10)
	var strip_fraction: float = minf(float(_strip_stacks) * STRIP_PER_STACK, MAX_STRIP_FRACTION)
	current_armor = base_armor * (1.0 - strip_fraction)


func get_effective_armor() -> float:
	return _get_effective_armor()


func _get_effective_armor() -> float:
	return maxf(0.0, current_armor - _pressure_reduction)
	
	
