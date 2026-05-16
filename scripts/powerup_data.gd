extends Resource
class_name PowerUpData

enum ModifierType {
	ADDITIVE,
	MULTIPLICATIVE
}

enum Rarity {
	
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export var id: String = "damage_up"
@export var display_name: String = "Damage Up"
@export_multiline var description: String = ""
@export var is_temporary := false
@export var duration := 0.0

@export var icon: Texture2D

@export var rarity: Rarity = Rarity.COMMON

@export var stat_to_modify: String = "damage"
@export var modifier_type: ModifierType = ModifierType.ADDITIVE
@export var amount: float = 5.0

@export var max_stacks := 999
@export var drop_weight := 10
