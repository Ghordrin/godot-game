extends Node

class_name StatsComponent

@export var damage := 10.0
@export var move_speed := 300.0
@export var attack_speed := 1.0
@export var projectile_speed := 500.0
@export var projectile_count = 1
@export var projectile_pierce: int = 0

var gold := 0
var gold_multiplier := 1.0

var pickup_range := 48.0
var luck := 0.0

var crit_chance := 0.05
var crit_multiplier := 2.0

var powerup_stacks := {}
var temporary_powerups: Array[Dictionary] = []


func _process(delta: float) -> void:
	_update_temporary_powerups(delta)


func add_gold(amount: int) -> void:
	var final_amount := int(round(amount * gold_multiplier))
	gold += final_amount


func apply_powerup(powerup: PowerUpData) -> void:
	if powerup == null:
		return
		


	var current_stacks = powerup_stacks.get(powerup.id, 0)

	if current_stacks >= powerup.max_stacks:
		return

	powerup_stacks[powerup.id] = current_stacks + 1

	_apply_powerup_modifier(powerup)

	if powerup.is_temporary and powerup.duration > 0.0:
		temporary_powerups.append({
			"powerup": powerup,
			"time_left": powerup.duration
		})
		
	if powerup.stat_to_modify == "projectile_count":
		match powerup.modifier_type:
			PowerUpData.ModifierType.ADDITIVE:
				projectile_count += int(powerup.amount)

			PowerUpData.ModifierType.MULTIPLICATIVE:
				projectile_count *= int(powerup.amount)
				
	if powerup.stat_to_modify== "projectile_pierce":
		match powerup.modifier_type:
			PowerUpData.ModifierType.ADDITIVE:
				projectile_pierce += int(powerup.amount)

			PowerUpData.ModifierType.MULTIPLICATIVE:
				projectile_pierce *= int(powerup.amount)			
				
				
	



func _update_temporary_powerups(delta: float) -> void:
	for i in range(temporary_powerups.size() - 1, -1, -1):
		var temporary_powerup: Dictionary = temporary_powerups[i]
		temporary_powerup["time_left"] -= delta

		if temporary_powerup["time_left"] <= 0.0:
			var powerup: PowerUpData = temporary_powerup["powerup"]
			_remove_powerup_modifier(powerup)
			temporary_powerups.remove_at(i)



func _apply_powerup_modifier(powerup: PowerUpData) -> void:
	match powerup.stat_to_modify:
		"damage":
			damage = _apply_modifier(damage, powerup)

		"move_speed":
			move_speed = _apply_modifier(move_speed, powerup)

		"attack_speed":
			attack_speed = _apply_modifier(attack_speed, powerup)

		"projectile_speed":
			projectile_speed = _apply_modifier(projectile_speed, powerup)

		"pickup_range":
			pickup_range = _apply_modifier(pickup_range, powerup)

		"gold_multiplier":
			gold_multiplier = _apply_modifier(gold_multiplier, powerup)

		"luck":
			luck = _apply_modifier(luck, powerup)

		"crit_chance":
			crit_chance = _apply_modifier(crit_chance, powerup)

		"crit_multiplier":
			crit_multiplier = _apply_modifier(crit_multiplier, powerup)

		_:
			push_warning("Unknown stat: " + powerup.stat_to_modify)


func _remove_powerup_modifier(powerup: PowerUpData) -> void:
	match powerup.stat_to_modify:
		"damage":
			damage = _remove_modifier(damage, powerup)

		"move_speed":
			move_speed = _remove_modifier(move_speed, powerup)

		"attack_speed":
			attack_speed = _remove_modifier(attack_speed, powerup)

		"projectile_speed":
			projectile_speed = _remove_modifier(projectile_speed, powerup)

		"pickup_range":
			pickup_range = _remove_modifier(pickup_range, powerup)

		"gold_multiplier":
			gold_multiplier = _remove_modifier(gold_multiplier, powerup)

		"luck":
			luck = _remove_modifier(luck, powerup)

		"crit_chance":
			crit_chance = _remove_modifier(crit_chance, powerup)

		"crit_multiplier":
			crit_multiplier = _remove_modifier(crit_multiplier, powerup)


func _apply_modifier(current_value: float, powerup: PowerUpData) -> float:
	match powerup.modifier_type:
		PowerUpData.ModifierType.ADDITIVE:
			return current_value + powerup.amount

		PowerUpData.ModifierType.MULTIPLICATIVE:
			return current_value * powerup.amount

	return current_value


func _remove_modifier(current_value: float, powerup: PowerUpData) -> float:
	match powerup.modifier_type:
		PowerUpData.ModifierType.ADDITIVE:
			return current_value - powerup.amount

		PowerUpData.ModifierType.MULTIPLICATIVE:
			if powerup.amount == 0:
				return current_value

			return current_value / powerup.amount

	return current_value
