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
