extends Node

## Autoload that tracks damage dealt during the current wave.
## Add this as an AutoLoad in Project Settings → AutoLoad.
## Name it "DamageMeter".

signal damage_recorded

## Damage type keys and their display colors
const TYPES := {
	"physical":  { "label": "Physical",  "color": Color(1.00, 1.00, 1.00) },
	"fire":      { "label": "Fire",      "color": Color(1.00, 0.42, 0.08) },
	"ice":       { "label": "Ice",       "color": Color(0.40, 0.85, 1.00) },
	"lightning": { "label": "Lightning", "color": Color(0.80, 0.55, 1.00) },
	"poison":    { "label": "Poison",    "color": Color(0.35, 1.00, 0.30) },
	"combo":     { "label": "Combo",     "color": Color(1.00, 0.88, 0.15) },
}

var wave_totals: Dictionary = {}
var total_damage: float = 0.0


func _ready() -> void:
	reset()


## Record damage of a given type. Called from Projectile and StatusEffectComponent.
func record(amount: float, type: String) -> void:
	if amount <= 0.0:
		return
	if not wave_totals.has(type):
		wave_totals[type] = 0.0
	wave_totals[type] += amount
	total_damage += amount
	damage_recorded.emit()


## Reset at the start of each wave.
func reset() -> void:
	wave_totals.clear()
	for type in TYPES:
		wave_totals[type] = 0.0
	total_damage = 0.0
	damage_recorded.emit()


## Returns damage share as 0.0-1.0 for a given type.
func get_share(type: String) -> float:
	if total_damage <= 0.0:
		return 0.0
	return wave_totals.get(type, 0.0) / total_damage


## Returns formatted total string e.g. "12,450"
func get_total_formatted() -> String:
	return _format_number(total_damage)


## Returns breakdown as array of {type, amount, share, color, label}
func get_breakdown() -> Array:
	var entries := []
	for type in TYPES:
		var amount: float = wave_totals.get(type, 0.0)
		if amount <= 0.0:
			continue
		entries.append({
			"type":   type,
			"amount": amount,
			"share":  get_share(type),
			"color":  TYPES[type].color,
			"label":  TYPES[type].label,
		})
	# Sort by amount descending
	entries.sort_custom(func(a, b): return a.amount > b.amount)
	return entries


func _format_number(n: float) -> String:
	var i := int(round(n))
	if i >= 1000000:
		return "%.1fM" % (i / 1000000.0)
	if i >= 1000:
		return "%.1fK" % (i / 1000.0)
	return str(i)
