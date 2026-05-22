extends Node
class_name ArmorComponent

## Reduces incoming damage based on type.
## Fire damage is special — it erodes the armor value over time.
## When armor reaches 0 it breaks permanently for the fight.
## Visual: green square = armor intact, yellow = damaged, red = broken.
## Add as a child node of any enemy scene.

## Starting armor value. Incoming damage is reduced by this amount
## (minus penetration per damage type). Fire gradually destroys it.
@export var armor_value: float = 15.0

## How much of each fire damage point erodes the armor permanently.
## 0.5 = 10 fire damage removes 5 armor. Lower = armor lasts longer against fire.
@export var fire_erosion_rate: float = 0.5

## Minimum damage that always reaches health regardless of armor.
const MIN_DAMAGE: float = 1.0

## How much of the armor value each damage type ignores (0 = none, 1 = all).
const PENETRATION := {
	"physical":  0.00,  # Physical is fully stopped by armor
	"fire":      0.50,  # Fire burns through half the remaining armor
	"ice":       0.25,
	"lightning": 0.25,
	"poison":    0.25,
	"combo":     0.50,
}

var current_armor: float   = 0.0   # Tracks remaining armor after fire erosion
var is_broken: bool        = false  # True once armor_value reaches 0

var _indicator: ColorRect    = null  # Colored armor status square
var _indicator_bg: ColorRect = null  # Dark border behind the square


func _ready() -> void:
	current_armor = armor_value
	_build_indicator()


## Called by HealthComponent before applying damage to health.
## Returns the final damage amount after armor reduction and fire erosion.
func reduce(amount: float, damage_type: String) -> float:
	if is_broken:
		return amount  # Broken armor provides no protection

	if damage_type == "fire":
		# Fire erodes armor permanently before the damage calc
		var erosion: float = amount * fire_erosion_rate
		current_armor = max(0.0, current_armor - erosion)
		_update_indicator()

		if current_armor <= 0.0:
			# Armor just broke — this hit deals full damage as the armor shatters
			_break_armor()
			return amount

	var penetration: float       = PENETRATION.get(damage_type, 0.0)
	var effective_armor: float   = current_armor * (1.0 - penetration)
	return max(MIN_DAMAGE, amount - effective_armor)


func _break_armor() -> void:
	is_broken     = true
	current_armor = 0.0
	_update_indicator()


## Returns a debug string shown in the debug stats panel.
func get_debug_string() -> String:
	if is_broken:
		return "Armor: BROKEN"
	return "Armor: %.0f / %.0f" % [current_armor, armor_value]

# ══════════════════════════════════════════════════════════════════════
# VISUAL INDICATOR
# ══════════════════════════════════════════════════════════════════════

func _build_indicator() -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return

	# Black border background
	_indicator_bg         = ColorRect.new()
	_indicator_bg.color   = Color(0.0, 0.0, 0.0, 0.85)
	_indicator_bg.size    = Vector2(12.0, 12.0)
	_indicator_bg.position = Vector2(12.0, -33.0)  # Right of center, above enemy
	_indicator_bg.z_index = 5
	parent.add_child.call_deferred(_indicator_bg)

	# Colored fill — updated as armor erodes
	_indicator           = ColorRect.new()
	_indicator.color     = Color(0.25, 0.90, 0.25)  # Green = full armor
	_indicator.size      = Vector2(10.0, 10.0)
	_indicator.position  = Vector2(13.0, -32.0)
	_indicator.z_index   = 6
	parent.add_child.call_deferred(_indicator)


func _update_indicator() -> void:
	if _indicator == null:
		return

	if is_broken:
		# Red = armor fully destroyed
		_indicator.color = Color(0.90, 0.18, 0.18)
		return

	# Gradient: green (full) → yellow (eroded) based on remaining armor
	var pct: float = clamp(current_armor / armor_value, 0.0, 1.0)
	_indicator.color = Color(0.25, 0.90, 0.25).lerp(Color(0.90, 0.80, 0.10), 1.0 - pct)
