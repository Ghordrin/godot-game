# components/StatusEffectComponent.gd
class_name StatusEffectComponent
extends Node

const GroundDamageZoneScene := preload("res://Data/Damage/AreaEffects/GroundDamageZone.gd")

signal effect_applied(type: EffectType)
signal effect_expired(type: EffectType)

enum EffectType {
	BURN,
	SHOCK,
	SLOW,
	STUN,
	POISON,
	VIRAL,
	CRYSTALLIZED,
	CONTAGION,
	NEUROTOXIN,
}

const TINT_STUN: Color = Color(1.3, 1.3, 0.5)
const TINT_BURN: Color = Color(1.5, 0.5, 0.2)
const TINT_SHOCK: Color = Color(0.9, 0.8, 1.5)
const TINT_POISON: Color = Color(0.5, 1.3, 0.3)
const TINT_NEUROTOXIN: Color = Color(0.35, 1.65, 0.25)
const TINT_VIRAL: Color = Color(0.7, 1.0, 0.55)
const TINT_SLOW: Color = Color(0.4, 0.7, 1.4)
const TINT_CRYSTALLIZED: Color = Color(0.5, 0.9, 1.5)
const TINT_CONTAGION: Color = Color(0.6, 1.4, 0.5)

const BURN_DOT_MULT: float = 0.18
const BURN_DURATION: float = 3.0
const BURN_TICK_RATE: float = 0.50
const BURN_MIN_DOT_DAMAGE: float = 1.0

const SHOCK_DOT_MULT: float = 0.06
const SHOCK_MIN_DOT_DAMAGE: float = 1.0
const SHOCK_DURATION: float = 2.0
const SHOCK_TICK_RATE: float = 0.18

const POISON_DOT_MULT: float = 0.12
const POISON_MIN_DOT_DAMAGE: float = 1.0
const POISON_DURATION: float = 5.0
const POISON_TICK_RATE: float = 0.90
const POISON_RAMP_MULT: float = 3.0
const POISON_DURATION_ADD_ON_REAPPLY: float = 2.0
const POISON_MAX_DURATION: float = 12.0

const NEUROTOXIN_DAMAGE_MULT: float = 0.08
const NEUROTOXIN_MIN_DOT_DAMAGE: float = 1.0
const NEUROTOXIN_TICK_RATE: float = 0.70
const NEUROTOXIN_DAMAGE_RAMP_PER_SECOND: float = 0.08
const NEUROTOXIN_MAX_DAMAGE_RAMP: float = 5.0
const NEUROTOXIN_SLOW_START: float = 0.08
const NEUROTOXIN_SLOW_RAMP_PER_SECOND: float = 0.012
const NEUROTOXIN_MAX_SLOW: float = 0.55
const NEUROTOXIN_BOSS_MAX_SLOW: float = 0.28
const NEUROTOXIN_REAPPLY_DAMAGE_MULT: float = 1.20
const NEUROTOXIN_REAPPLY_RAMP_BONUS: float = 2.0

const VIRAL_DURATION: float = 5.0
const VIRAL_DOT_BONUS: float = 0.75

const SPEED_PROPERTIES: Array[String] = [
	"move_speed",
	"speed",
	"projectile_speed",
	"attack_projectile_speed",
	"burst_speed",
	"rush_speed",
	"rush_trail_speed",
	"rush_impact_speed",
	"charge_speed",
	"charge_debris_speed",
	"charge_impact_speed",
	"stomp_base_speed",
	"stomp_speed_step",
	"stomp_deferred_speed",
	"slam_base_speed",
	"slam_speed_step",
	"slam_cross_speed",
	"spiral_speed",
	"boulder_speed",
	"boulder_fragment_speed",
	"roar_projectile_speed",
	"salvo_speed",
	"cross_base_speed",
	"cross_speed_step",
	"fan_speed",
	"clone_projectile_speed",
	"shard_speed",
]

const INTERVAL_PROPERTIES: Array[String] = [
	"attack_cooldown",
	"attack_interval",
	"fire_interval",
	"shoot_interval",
	"shoot_cooldown",
	"stomp_delay",
	"stomp_fire_interval",
	"spiral_interval",
	"rush_trail_interval",
	"rush_windup_time",
	"charge_windup_time",
	"charge_debris_interval",
	"slam_windup_time",
	"slam_delay",
	"boulder_windup_time",
	"boulder_delay",
	"roar_windup_time",
	"shadow_warn_time",
	"materialize_time",
	"salvo_interval",
	"spiral_fire_interval",
	"cross_delay",
	"fan_burst_interval",
	"clone_warning_time",
	"cooldown_phase1",
	"cooldown_phase2",
	"cooldown_phase3",
	"telegraph_duration",
	"multi_strike_delay",
	"phase3_crossfire_delay",
]

const STATS_SPEED_PROPERTIES: Array[String] = [
	"projectile_speed",
	"attack_projectile_speed",
]

const STATS_INTERVAL_PROPERTIES: Array[String] = [
	"attack_cooldown",
	"attack_interval",
	"fire_interval",
	"shoot_interval",
	"shoot_cooldown",
]

var immune: bool = false
var active_effects: Array[Dictionary] = []

var _parent: Node2D = null
var _sprite: CanvasItem = null
var _health_comp: HealthComponent = null
var _original_color: Color = Color.WHITE
var _contagion_timer: Timer = null
var _pulse_tween: Tween = null

var _base_parent_values: Dictionary = {}
var _base_stats_values: Dictionary = {}


func _ready() -> void:
	_parent = get_parent() as Node2D

	if _parent == null:
		push_warning("StatusEffectComponent: parent is not Node2D")
		return

	var animated := _parent.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	if animated != null:
		_sprite = animated
	else:
		_sprite = _parent.get_node_or_null("Sprite2D") as Sprite2D

	_health_comp = _parent.get_node_or_null("HealthComponent") as HealthComponent

	if _sprite != null:
		_original_color = _sprite.modulate

	_cache_scalable_values()


func _process(delta: float) -> void:
	if active_effects.is_empty():
		return

	var slow_state_needs_recalc: bool = false

	for i: int in range(active_effects.size() - 1, -1, -1):
		var fx: Dictionary = active_effects[i]

		fx["elapsed"] = float(fx["elapsed"]) + delta

		if int(fx["type"]) == EffectType.POISON:
			fx["ramp_elapsed"] = float(fx.get("ramp_elapsed", 0.0)) + delta

		if int(fx["type"]) == EffectType.NEUROTOXIN:
			fx["ramp_elapsed"] = float(fx.get("ramp_elapsed", 0.0)) + delta
			slow_state_needs_recalc = true

		if float(fx["tick_rate"]) > 0.0 and not immune:
			fx["tick_timer"] = float(fx["tick_timer"]) + delta

			while float(fx["tick_timer"]) >= float(fx["tick_rate"]):
				fx["tick_timer"] = float(fx["tick_timer"]) - float(fx["tick_rate"])
				_on_tick(fx)

		if bool(fx.get("permanent", false)):
			continue

		if float(fx["elapsed"]) >= float(fx["duration"]):
			active_effects.remove_at(i)
			_on_expired(fx)

	if slow_state_needs_recalc:
		_recalculate_slow_state()

	_update_tint()


# ══════════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════════

func apply_burn_from_element(element_damage: float) -> void:
	var damage_per_tick: float = maxf(element_damage * BURN_DOT_MULT, BURN_MIN_DOT_DAMAGE)
	apply_burn(damage_per_tick, BURN_DURATION, BURN_TICK_RATE)


func apply_shock_from_element(element_damage: float) -> void:
	var damage_per_tick: float = maxf(element_damage * SHOCK_DOT_MULT, SHOCK_MIN_DOT_DAMAGE)
	apply_shock(damage_per_tick, SHOCK_DURATION, SHOCK_TICK_RATE)


func apply_poison_from_element(element_damage: float) -> void:
	var damage_per_tick: float = maxf(element_damage * POISON_DOT_MULT, POISON_MIN_DOT_DAMAGE)
	apply_poison(damage_per_tick, POISON_DURATION, POISON_TICK_RATE)


func apply_neurotoxin_from_combo(element_damage: float) -> void:
	var damage_per_tick: float = maxf(element_damage * NEUROTOXIN_DAMAGE_MULT, NEUROTOXIN_MIN_DOT_DAMAGE)
	apply_neurotoxin(damage_per_tick)


func apply_combo_effect(combo_type, element_pool: float = 0.0) -> void:
	var combo_name: String = _normalize_combo_name(combo_type)

	match combo_name:
		"plasma":
			_apply_plasma_combo(element_pool)

		"corrosive":
			apply_poison(maxf(1.0, element_pool * 0.18), POISON_DURATION, POISON_TICK_RATE)
			apply_viral(VIRAL_DURATION, 0.35)

		"magnetic":
			apply_shock(maxf(1.0, element_pool * 0.08), SHOCK_DURATION, SHOCK_TICK_RATE)
			apply_slow(0.25, 2.0, element_pool)

		"viral":
			apply_viral(VIRAL_DURATION, VIRAL_DOT_BONUS)

		"neurotoxin":
			apply_neurotoxin_from_combo(element_pool)

		"thermal":
			pass

		_:
			pass


func apply_burn(damage_per_tick: float, duration: float = BURN_DURATION, tick_rate: float = BURN_TICK_RATE) -> void:
	_apply(EffectType.BURN, {
		"damage": maxf(damage_per_tick, BURN_MIN_DOT_DAMAGE),
		"duration": duration,
		"tick_rate": tick_rate,
	})


func apply_shock(damage_per_tick: float, duration: float = SHOCK_DURATION, tick_rate: float = SHOCK_TICK_RATE) -> void:
	_apply(EffectType.SHOCK, {
		"damage": maxf(damage_per_tick, SHOCK_MIN_DOT_DAMAGE),
		"duration": duration,
		"tick_rate": tick_rate,
	})


func apply_slow(slow_percent: float, duration: float = 2.0, element_pool: float = 0.0) -> void:
	var affix: AffixComponent = get_parent().get_node_or_null("AffixComponent") as AffixComponent

	if affix != null and affix.is_cc_immune:
		return

	_apply(EffectType.SLOW, {
		"slow_percent": clampf(slow_percent, 0.0, 0.9),
		"duration": duration,
		"tick_rate": 0.0,
		"element_pool": element_pool,
	})


func apply_stun(duration: float = 0.5) -> void:
	var affix: AffixComponent = get_parent().get_node_or_null("AffixComponent") as AffixComponent

	if affix != null and affix.is_cc_immune:
		return

	_apply(EffectType.STUN, {
		"duration": duration,
		"tick_rate": 0.0,
	})


func apply_poison(base_damage: float, duration: float = POISON_DURATION, tick_rate: float = POISON_TICK_RATE) -> void:
	_apply(EffectType.POISON, {
		"damage": maxf(base_damage, POISON_MIN_DOT_DAMAGE),
		"duration": duration,
		"tick_rate": tick_rate,
	})


func apply_neurotoxin(base_damage: float) -> void:
	_apply(EffectType.NEUROTOXIN, {
		"damage": maxf(base_damage, NEUROTOXIN_MIN_DOT_DAMAGE),
		"duration": 999999.0,
		"tick_rate": NEUROTOXIN_TICK_RATE,
		"permanent": true,
		"slow_percent": NEUROTOXIN_SLOW_START,
	})


func apply_viral(duration: float = VIRAL_DURATION, dot_bonus: float = VIRAL_DOT_BONUS) -> void:
	_apply(EffectType.VIRAL, {
		"duration": duration,
		"tick_rate": 0.0,
		"dot_bonus": dot_bonus,
	})


func apply_crystallize(shatter_damage: float, duration: float = 3.0) -> void:
	_remove_effect_type(EffectType.SLOW)
	_remove_effect_type(EffectType.POISON)

	var shield: ShieldComponent = get_parent().get_node_or_null("ShieldComponent") as ShieldComponent

	if shield != null:
		shield._regen_timer = 0.0

	immune = true

	_apply(EffectType.CRYSTALLIZED, {
		"duration": duration,
		"tick_rate": 0.0,
		"shatter_damage": shatter_damage,
	})

	_start_crystallize_pulse()


func apply_contagion(pulse_pool: float, pulse_interval: float = 1.5, duration: float = 8.0) -> void:
	_apply(EffectType.CONTAGION, {
		"duration": duration,
		"tick_rate": 0.0,
		"pulse_pool": pulse_pool,
		"pulse_interval": pulse_interval,
	})

	_start_contagion_timer(pulse_pool, pulse_interval)


func has_effect(type: EffectType) -> bool:
	for fx: Dictionary in active_effects:
		if int(fx["type"]) == int(type):
			return true

	return false


func get_regen_multiplier() -> float:
	if has_effect(EffectType.NEUROTOXIN):
		return 0.0

	if has_effect(EffectType.POISON):
		return 0.0

	return 1.0


func is_poisoned() -> bool:
	return has_effect(EffectType.POISON) or has_effect(EffectType.NEUROTOXIN)


func clear_all() -> void:
	for fx: Dictionary in active_effects:
		_on_expired(fx)

	active_effects.clear()
	immune = false
	_stop_contagion_timer()
	_apply_slow_multiplier(1.0)
	_update_tint()


func on_enemy_death() -> void:
	if PlayerInventory.active_combinations.has(PlayerInventory.ElementalCombo.THERMAL):
		if has_effect(EffectType.BURN) and has_effect(EffectType.SLOW):
			_trigger_thermal_shock_explosion()


# ══════════════════════════════════════════════════════════════════════
# INTERNAL EFFECT MANAGEMENT
# ══════════════════════════════════════════════════════════════════════

func _normalize_combo_name(combo_type) -> String:
	if combo_type is String:
		return String(combo_type).to_lower()

	match int(combo_type):
		PlayerInventory.ElementalCombo.THERMAL:
			return "thermal"

		PlayerInventory.ElementalCombo.PLASMA:
			return "plasma"

		PlayerInventory.ElementalCombo.CORROSIVE:
			return "corrosive"

		PlayerInventory.ElementalCombo.MAGNETIC:
			return "magnetic"

		PlayerInventory.ElementalCombo.VIRAL:
			return "viral"

		PlayerInventory.ElementalCombo.NEUROTOXIN:
			return "neurotoxin"

		_:
			return ""


func _apply_plasma_combo(element_pool: float) -> void:
	if not is_instance_valid(_health_comp):
		return

	var plasma_damage: float = maxf(1.0, element_pool * 0.30)

	_health_comp.take_damage(plasma_damage, "combo")

	if _parent != null and _parent.is_inside_tree():
		DamageNumberSpawner.spawn(
			DamageNumberSpawner.get_anchor_position(_parent),
			plasma_damage,
			DamageVisuals.get_display_name("combo"),
			DamageVisuals.get_color("combo"),
			4,
			true
		)

	DamageMeter.record(plasma_damage, "combo")


func _apply(type: EffectType, data: Dictionary) -> void:
	for fx: Dictionary in active_effects:
		if int(fx["type"]) != int(type):
			continue

		match type:
			EffectType.POISON:
				_refresh_poison(fx, data)

			EffectType.NEUROTOXIN:
				_refresh_neurotoxin(fx, data)

			_:
				_refresh_regular_effect(fx, data)

		_recalculate_slow_state()
		return

	var fx: Dictionary = {
		"type": int(type),
		"duration": float(data.get("duration", 3.0)),
		"elapsed": 0.0,
		"ramp_elapsed": 0.0,
		"tick_rate": float(data.get("tick_rate", 0.0)),
		"tick_timer": 0.0,
		"damage": float(data.get("damage", 0.0)),
		"slow_percent": float(data.get("slow_percent", 0.0)),
		"element_pool": float(data.get("element_pool", 0.0)),
		"shatter_damage": float(data.get("shatter_damage", 0.0)),
		"pulse_pool": float(data.get("pulse_pool", 0.0)),
		"pulse_interval": float(data.get("pulse_interval", 1.5)),
		"dot_bonus": float(data.get("dot_bonus", 0.0)),
		"permanent": bool(data.get("permanent", false)),
	}

	active_effects.append(fx)
	_on_applied(fx)
	effect_applied.emit(type)


func _refresh_regular_effect(fx: Dictionary, data: Dictionary) -> void:
	fx["duration"] = data.get("duration", fx["duration"])
	fx["elapsed"] = 0.0

	if data.has("damage"):
		fx["damage"] = data["damage"]

	if data.has("dot_bonus"):
		fx["dot_bonus"] = data["dot_bonus"]

	if data.has("slow_percent"):
		fx["slow_percent"] = data["slow_percent"]

	if data.has("tick_rate"):
		fx["tick_rate"] = data["tick_rate"]


func _refresh_poison(fx: Dictionary, data: Dictionary) -> void:
	var current_duration: float = float(fx.get("duration", POISON_DURATION))
	var new_duration: float = float(data.get("duration", POISON_DURATION))

	var extended_duration: float = current_duration + POISON_DURATION_ADD_ON_REAPPLY
	extended_duration = minf(extended_duration, POISON_MAX_DURATION)

	if data.has("damage"):
		fx["damage"] = maxf(float(fx.get("damage", 0.0)), float(data["damage"]))

	fx["duration"] = maxf(extended_duration, new_duration)
	fx["tick_rate"] = data.get("tick_rate", fx.get("tick_rate", POISON_TICK_RATE))

	fx["elapsed"] = minf(float(fx.get("elapsed", 0.0)), float(fx["duration"]) - 0.01)
	fx["ramp_elapsed"] = float(fx.get("ramp_elapsed", fx["elapsed"]))


func _refresh_neurotoxin(fx: Dictionary, data: Dictionary) -> void:
	if data.has("damage"):
		var current_damage: float = float(fx.get("damage", 0.0))
		var incoming_damage: float = float(data["damage"])
		fx["damage"] = maxf(current_damage, incoming_damage) * NEUROTOXIN_REAPPLY_DAMAGE_MULT

	fx["permanent"] = true
	fx["duration"] = 999999.0
	fx["tick_rate"] = data.get("tick_rate", fx.get("tick_rate", NEUROTOXIN_TICK_RATE))
	fx["elapsed"] = 0.0
	fx["ramp_elapsed"] = float(fx.get("ramp_elapsed", 0.0)) + NEUROTOXIN_REAPPLY_RAMP_BONUS


func _on_applied(fx: Dictionary) -> void:
	match int(fx["type"]):
		EffectType.SLOW, EffectType.STUN, EffectType.CRYSTALLIZED, EffectType.NEUROTOXIN:
			_recalculate_slow_state()

		EffectType.CRYSTALLIZED:
			immune = true


func _on_tick(fx: Dictionary) -> void:
	if not is_instance_valid(_parent):
		return

	match int(fx["type"]):
		EffectType.BURN:
			_deal_damage(_get_dot_damage(fx), "fire", fx)

		EffectType.SHOCK:
			_deal_damage(_get_dot_damage(fx), "lightning", fx)

		EffectType.POISON:
			var ramp_elapsed: float = float(fx.get("ramp_elapsed", fx["elapsed"]))
			var ramp_progress: float = clampf(ramp_elapsed / POISON_MAX_DURATION, 0.0, 1.0)
			var ramp: float = 1.0 + ramp_progress * POISON_RAMP_MULT
			_deal_damage(_get_dot_damage(fx) * ramp, "poison", fx)

		EffectType.NEUROTOXIN:
			var neuro_elapsed: float = float(fx.get("ramp_elapsed", 0.0))
			var ramp: float = minf(
				NEUROTOXIN_MAX_DAMAGE_RAMP,
				1.0 + neuro_elapsed * NEUROTOXIN_DAMAGE_RAMP_PER_SECOND
			)
			_deal_damage(_get_dot_damage(fx) * ramp, "neurotoxin", fx)


func _get_dot_damage(fx: Dictionary) -> float:
	var amount: float = float(fx["damage"])

	if has_effect(EffectType.VIRAL):
		amount *= 1.0 + _get_viral_dot_bonus()

	return maxf(amount, 1.0)


func _get_viral_dot_bonus() -> float:
	var highest_bonus: float = 0.0

	for fx: Dictionary in active_effects:
		if int(fx["type"]) != EffectType.VIRAL:
			continue

		highest_bonus = maxf(highest_bonus, float(fx.get("dot_bonus", VIRAL_DOT_BONUS)))

	return highest_bonus


func _on_expired(fx: Dictionary) -> void:
	match int(fx["type"]):
		EffectType.SLOW, EffectType.STUN, EffectType.NEUROTOXIN:
			_recalculate_slow_state()

		EffectType.CRYSTALLIZED:
			immune = false
			_recalculate_slow_state()
			_trigger_crystallize_shatter(float(fx["shatter_damage"]))

		EffectType.CONTAGION:
			_stop_contagion_timer()

	effect_expired.emit(int(fx["type"]) as EffectType)


func _deal_damage(amount: float, damage_type: String = "physical", fx: Dictionary = {}) -> void:
	if not is_instance_valid(_health_comp):
		return

	var applied_amount: float = maxf(amount, 1.0)

	_health_comp.take_damage(applied_amount, damage_type)

	if _parent != null and _parent.is_inside_tree():
		DamageNumberSpawner.spawn(
			DamageNumberSpawner.get_anchor_position(_parent),
			applied_amount,
			DamageVisuals.get_display_name(damage_type),
			DamageVisuals.get_color(damage_type),
			_get_damage_number_index_for_effect(fx),
			true
		)

	DamageMeter.record(applied_amount, damage_type)


func _get_damage_number_index_for_effect(fx: Dictionary) -> int:
	if fx.is_empty():
		return 0

	match int(fx.get("type", -1)):
		EffectType.BURN:
			return 0

		EffectType.SHOCK:
			return 1

		EffectType.POISON:
			return 2

		EffectType.NEUROTOXIN:
			return 3

		_:
			return 0


# ══════════════════════════════════════════════════════════════════════
# SLOW SUPPORT: MOVEMENT, PROJECTILES, ATTACK SPEED
# ══════════════════════════════════════════════════════════════════════

func _cache_scalable_values() -> void:
	if _parent == null:
		return

	for property_name in SPEED_PROPERTIES:
		_cache_parent_property(property_name)

	for property_name in INTERVAL_PROPERTIES:
		_cache_parent_property(property_name)

	var stats := _parent.get_node_or_null("StatsComponent") as Node

	if stats == null:
		return

	for property_name in STATS_SPEED_PROPERTIES:
		_cache_stats_property(stats, property_name)

	for property_name in STATS_INTERVAL_PROPERTIES:
		_cache_stats_property(stats, property_name)


func _cache_parent_property(property_name: String) -> void:
	if _parent == null:
		return

	if not property_name in _parent:
		return

	_base_parent_values[property_name] = float(_parent.get(property_name))


func _cache_stats_property(stats: Node, property_name: String) -> void:
	if stats == null:
		return

	if not property_name in stats:
		return

	_base_stats_values[property_name] = float(stats.get(property_name))


func _recalculate_slow_state() -> void:
	if _parent == null:
		return

	var multiplier: float = 1.0

	for fx: Dictionary in active_effects:
		match int(fx["type"]):
			EffectType.STUN, EffectType.CRYSTALLIZED:
				multiplier = minf(multiplier, 0.0)

			EffectType.SLOW:
				var slow_percent: float = clampf(float(fx.get("slow_percent", 0.0)), 0.0, 0.9)
				multiplier = minf(multiplier, 1.0 - slow_percent)

			EffectType.NEUROTOXIN:
				var neuro_slow: float = _get_neurotoxin_slow_percent(fx)
				multiplier = minf(multiplier, 1.0 - neuro_slow)

	_apply_slow_multiplier(multiplier)


func _get_neurotoxin_slow_percent(fx: Dictionary) -> float:
	var elapsed: float = float(fx.get("ramp_elapsed", 0.0))
	var slow: float = NEUROTOXIN_SLOW_START + elapsed * NEUROTOXIN_SLOW_RAMP_PER_SECOND

	var is_boss: bool = _parent != null and _parent.is_in_group("bosses")
	var max_slow: float = NEUROTOXIN_BOSS_MAX_SLOW if is_boss else NEUROTOXIN_MAX_SLOW

	return clampf(slow, 0.0, max_slow)


func _apply_slow_multiplier(multiplier: float) -> void:
	if _parent == null:
		return

	for property_name in _base_parent_values.keys():
		var base_value: float = float(_base_parent_values[property_name])

		if property_name in SPEED_PROPERTIES:
			_parent.set(property_name, base_value * multiplier)
		elif property_name in INTERVAL_PROPERTIES:
			var safe_multiplier: float = maxf(multiplier, 0.05)
			_parent.set(property_name, base_value / safe_multiplier)

	var stats := _parent.get_node_or_null("StatsComponent") as Node

	if stats == null:
		return

	for property_name in _base_stats_values.keys():
		var base_stats_value: float = float(_base_stats_values[property_name])

		if property_name in STATS_SPEED_PROPERTIES:
			stats.set(property_name, base_stats_value * multiplier)
		elif property_name in STATS_INTERVAL_PROPERTIES:
			var safe_stats_multiplier: float = maxf(multiplier, 0.05)
			stats.set(property_name, base_stats_value / safe_stats_multiplier)


# ══════════════════════════════════════════════════════════════════════
# VISUALS / CLEANUP
# ══════════════════════════════════════════════════════════════════════

func _update_tint() -> void:
	if _sprite == null:
		return

	if active_effects.is_empty():
		_sprite.modulate = _original_color
		return

	var target_color: Color = _original_color

	for fx: Dictionary in active_effects:
		match int(fx["type"]):
			EffectType.STUN:
				target_color = TINT_STUN
			EffectType.BURN:
				target_color = TINT_BURN
			EffectType.SHOCK:
				target_color = TINT_SHOCK
			EffectType.POISON:
				target_color = TINT_POISON
			EffectType.NEUROTOXIN:
				target_color = TINT_NEUROTOXIN
			EffectType.VIRAL:
				target_color = TINT_VIRAL
			EffectType.SLOW:
				target_color = TINT_SLOW
			EffectType.CRYSTALLIZED:
				target_color = TINT_CRYSTALLIZED
			EffectType.CONTAGION:
				target_color = TINT_CONTAGION

	_sprite.modulate = target_color


func _remove_effect_type(type: EffectType) -> void:
	for i in range(active_effects.size() - 1, -1, -1):
		if int(active_effects[i]["type"]) == int(type):
			var fx: Dictionary = active_effects[i]
			active_effects.remove_at(i)
			_on_expired(fx)


func _start_crystallize_pulse() -> void:
	if _sprite == null:
		return

	if _pulse_tween != null:
		_pulse_tween.kill()

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_sprite, "modulate", TINT_CRYSTALLIZED, 0.16)
	_pulse_tween.tween_property(_sprite, "modulate", Color(0.8, 1.1, 1.6), 0.16)


func _start_contagion_timer(pulse_pool: float, pulse_interval: float) -> void:
	_stop_contagion_timer()

	_contagion_timer = Timer.new()
	_contagion_timer.wait_time = pulse_interval
	_contagion_timer.one_shot = false
	_contagion_timer.timeout.connect(
		func() -> void:
			_pulse_contagion(pulse_pool)
	)
	add_child(_contagion_timer)
	_contagion_timer.start()


func _stop_contagion_timer() -> void:
	if _contagion_timer == null:
		return

	_contagion_timer.queue_free()
	_contagion_timer = null


func _pulse_contagion(pulse_pool: float) -> void:
	if _parent == null:
		return

	var packet := DamagePacket.new()
	packet.add_damage(maxf(1.0, pulse_pool), "poison", "contagion")

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == _parent:
			continue

		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D

		if _parent.global_position.distance_to(enemy_2d.global_position) > 130.0:
			continue

		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent

		if health != null:
			health.take_damage_packet(packet)


func _trigger_crystallize_shatter(amount: float) -> void:
	if _parent == null:
		return

	var packet := DamagePacket.new()
	packet.add_damage(maxf(1.0, amount), "cold", "crystallize")

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == _parent:
			continue

		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D

		if _parent.global_position.distance_to(enemy_2d.global_position) > 120.0:
			continue

		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent

		if health != null:
			health.take_damage_packet(packet)


func _trigger_thermal_shock_explosion() -> void:
	if _parent == null:
		return

	var zone := GroundDamageZoneScene.new()
	zone.global_position = _parent.global_position
	zone.radius = 90.0
	zone.damage_per_tick = 4.0
	zone.tick_interval = 0.25
	zone.duration = 0.8
	zone.damage_type = "fire"
	zone.add_to_group("wave_cleanup")
	get_tree().current_scene.add_child(zone)
