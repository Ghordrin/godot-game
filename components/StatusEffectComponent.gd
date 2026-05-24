# components/StatusEffectComponent.gd
class_name StatusEffectComponent
extends Node

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
}

const TINT_STUN: Color = Color(1.3, 1.3, 0.5)
const TINT_BURN: Color = Color(1.5, 0.5, 0.2)
const TINT_SHOCK: Color = Color(0.9, 0.8, 1.5)
const TINT_POISON: Color = Color(0.5, 1.3, 0.3)
const TINT_VIRAL: Color = Color(0.7, 1.0, 0.55)
const TINT_SLOW: Color = Color(0.4, 0.7, 1.4)
const TINT_CRYSTALLIZED: Color = Color(0.5, 0.9, 1.5)
const TINT_CONTAGION: Color = Color(0.6, 1.4, 0.5)

const BURN_DOT_MULT: float = 0.18
const BURN_DURATION: float = 3.0
const BURN_TICK_RATE: float = 0.5

const SHOCK_DOT_MULT: float = 0.045
const SHOCK_DURATION: float = 2.0
const SHOCK_TICK_RATE: float = 0.2

const POISON_DOT_MULT: float = 0.12
const POISON_DURATION: float = 5.0
const POISON_TICK_RATE: float = 1.0
const POISON_RAMP_MULT: float = 3.0
const POISON_DURATION_ADD_ON_REAPPLY: float = 2.0
const POISON_MAX_DURATION: float = 12.0

const VIRAL_DURATION: float = 5.0
const VIRAL_DOT_BONUS: float = 0.75

var immune: bool = false
var active_effects: Array[Dictionary] = []

var _parent: Node2D = null
var _sprite: CanvasItem = null
var _health_comp: HealthComponent = null
var _original_speed: float = -1.0
var _original_color: Color = Color.WHITE
var _contagion_timer: Timer = null
var _pulse_tween: Tween = null


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

	if "move_speed" in _parent:
		_original_speed = float(_parent.get("move_speed"))

	if _sprite != null:
		_original_color = _sprite.modulate


func _process(delta: float) -> void:
	if active_effects.is_empty():
		return

	for i: int in range(active_effects.size() - 1, -1, -1):
		var fx: Dictionary = active_effects[i]

		fx["elapsed"] = float(fx["elapsed"]) + delta

		if int(fx["type"]) == EffectType.POISON:
			fx["ramp_elapsed"] = float(fx.get("ramp_elapsed", 0.0)) + delta

		if float(fx["tick_rate"]) > 0.0 and not immune:
			fx["tick_timer"] = float(fx["tick_timer"]) + delta

			while float(fx["tick_timer"]) >= float(fx["tick_rate"]):
				fx["tick_timer"] = float(fx["tick_timer"]) - float(fx["tick_rate"])
				_on_tick(fx)

		if float(fx["elapsed"]) >= float(fx["duration"]):
			active_effects.remove_at(i)
			_on_expired(fx)

	_update_tint()

# ── Public API ─────────────────────────────────────────────────────────

func apply_burn_from_element(element_damage: float) -> void:
	apply_burn(element_damage * BURN_DOT_MULT, BURN_DURATION, BURN_TICK_RATE)


func apply_shock_from_element(element_damage: float) -> void:
	apply_shock(element_damage * SHOCK_DOT_MULT, SHOCK_DURATION, SHOCK_TICK_RATE)


func apply_poison_from_element(element_damage: float) -> void:
	apply_poison(element_damage * POISON_DOT_MULT, POISON_DURATION, POISON_TICK_RATE)


func apply_burn(damage_per_tick: float, duration: float = BURN_DURATION, tick_rate: float = BURN_TICK_RATE) -> void:
	_apply(EffectType.BURN, {
		"damage": damage_per_tick,
		"duration": duration,
		"tick_rate": tick_rate,
	})


func apply_shock(damage_per_tick: float, duration: float = SHOCK_DURATION, tick_rate: float = SHOCK_TICK_RATE) -> void:
	_apply(EffectType.SHOCK, {
		"damage": damage_per_tick,
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
		"damage": base_damage,
		"duration": duration,
		"tick_rate": tick_rate,
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


func clear_all() -> void:
	for fx: Dictionary in active_effects:
		_on_expired(fx)

	active_effects.clear()
	immune = false
	_stop_contagion_timer()
	_update_tint()


func on_enemy_death() -> void:
	if PlayerInventory.active_combinations.has(PlayerInventory.ElementalCombo.THERMAL):
		if has_effect(EffectType.BURN) and has_effect(EffectType.SLOW):
			_trigger_thermal_shock_explosion()

# ── Internal ────────────────────────────────────────────────────────────

func _apply(type: EffectType, data: Dictionary) -> void:
	for fx: Dictionary in active_effects:
		if int(fx["type"]) != int(type):
			continue

		match type:
			EffectType.POISON:
				_refresh_poison(fx, data)

			_:
				_refresh_regular_effect(fx, data)

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


func _on_applied(fx: Dictionary) -> void:
	match int(fx["type"]):
		EffectType.SLOW:
			_set_speed_multiplier(1.0 - float(fx["slow_percent"]))

		EffectType.STUN:
			_set_speed_multiplier(0.0)

		EffectType.CRYSTALLIZED:
			_set_speed_multiplier(0.0)
			immune = true


func _on_tick(fx: Dictionary) -> void:
	if not is_instance_valid(_parent):
		return

	match int(fx["type"]):
		EffectType.BURN:
			_deal_damage(_get_dot_damage(fx), "fire")

		EffectType.SHOCK:
			_deal_damage(_get_dot_damage(fx), "lightning")

		EffectType.POISON:
			var ramp_elapsed: float = float(fx.get("ramp_elapsed", fx["elapsed"]))
			var ramp_progress: float = clampf(ramp_elapsed / POISON_MAX_DURATION, 0.0, 1.0)
			var ramp: float = 1.0 + ramp_progress * POISON_RAMP_MULT
			_deal_damage(_get_dot_damage(fx) * ramp, "poison")


func _get_dot_damage(fx: Dictionary) -> float:
	var amount: float = float(fx["damage"])

	if has_effect(EffectType.VIRAL):
		amount *= 1.0 + _get_viral_dot_bonus()

	return amount


func _get_viral_dot_bonus() -> float:
	var highest_bonus: float = 0.0

	for fx: Dictionary in active_effects:
		if int(fx["type"]) != EffectType.VIRAL:
			continue

		highest_bonus = maxf(highest_bonus, float(fx.get("dot_bonus", VIRAL_DOT_BONUS)))

	return highest_bonus


func _on_expired(fx: Dictionary) -> void:
	match int(fx["type"]):
		EffectType.SLOW, EffectType.STUN:
			_restore_speed()

		EffectType.CRYSTALLIZED:
			immune = false
			_restore_speed()
			_trigger_crystallize_shatter(float(fx["shatter_damage"]))

		EffectType.CONTAGION:
			_stop_contagion_timer()

	effect_expired.emit(int(fx["type"]) as EffectType)


func _deal_damage(amount: float, damage_type: String = "physical") -> void:
	if not is_instance_valid(_health_comp):
		return

	_health_comp.take_damage(amount, damage_type)

	if _parent != null and _parent.is_inside_tree():
		DamageNumberSpawner.spawn(
			DamageNumberSpawner.get_anchor_position(_parent),
			amount,
			DamageVisuals.get_display_name(damage_type),
			DamageVisuals.get_color(damage_type),
			0,
			true
		)

	DamageMeter.record(amount, damage_type)


func _start_crystallize_pulse() -> void:
	if _sprite == null:
		return

	_kill_pulse_tween()

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_sprite, "modulate", TINT_CRYSTALLIZED.lightened(0.3), 0.5)
	_pulse_tween.tween_property(_sprite, "modulate", TINT_CRYSTALLIZED.darkened(0.2), 0.5)


func _trigger_crystallize_shatter(shatter_damage: float) -> void:
	if _parent == null or shatter_damage <= 0.0:
		return

	const SHATTER_RADIUS: float = 130.0

	if _sprite != null:
		_kill_pulse_tween()
		_sprite.modulate = Color(2.0, 2.0, 2.0)

	if is_instance_valid(_health_comp):
		_health_comp.take_damage(shatter_damage, "combo")

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy == _parent or not is_instance_valid(enemy):
			continue

		var enemy_2d: Node2D = enemy as Node2D

		if enemy_2d == null:
			continue

		var dist: float = _parent.global_position.distance_to(enemy_2d.global_position)

		if dist > SHATTER_RADIUS:
			continue

		var falloff: float = 1.0 - (dist / SHATTER_RADIUS) * 0.4
		var hc: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent

		if is_instance_valid(hc):
			hc.take_damage(shatter_damage * falloff, "combo")

	_spawn_shatter_visual(_parent.global_position, SHATTER_RADIUS)


func _start_contagion_timer(pulse_pool: float, pulse_interval: float) -> void:
	_stop_contagion_timer()

	_contagion_timer = Timer.new()
	_contagion_timer.wait_time = maxf(0.1, pulse_interval)
	_contagion_timer.one_shot = false
	add_child(_contagion_timer)

	_contagion_timer.timeout.connect(_on_contagion_pulse.bind(pulse_pool))
	_contagion_timer.start()

	if _sprite != null:
		_kill_pulse_tween()
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_sprite, "modulate", TINT_CONTAGION.lightened(0.4), 0.3)
		_pulse_tween.tween_property(_sprite, "modulate", TINT_CONTAGION, 0.4)
		_pulse_tween.tween_interval(maxf(0.1, pulse_interval - 0.7))


func _on_contagion_pulse(pulse_pool: float) -> void:
	if not is_instance_valid(_parent):
		_stop_contagion_timer()
		return

	const PULSE_RADIUS: float = 120.0
	var pulse_poison: float = pulse_pool / 8.0
	var pulse_stun: float = 0.4

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy == _parent or not is_instance_valid(enemy):
			continue

		var enemy_2d: Node2D = enemy as Node2D

		if enemy_2d == null:
			continue

		var dist: float = _parent.global_position.distance_to(enemy_2d.global_position)

		if dist > PULSE_RADIUS:
			continue

		var sec: StatusEffectComponent = enemy.get_node_or_null("StatusEffectComponent") as StatusEffectComponent

		if is_instance_valid(sec):
			sec.apply_poison(pulse_poison, 4.0, 0.5)
			sec.apply_stun(pulse_stun)

	if _sprite != null:
		var flash_tween: Tween = create_tween()
		flash_tween.tween_property(_sprite, "modulate", Color(1.0, 2.0, 0.5), 0.1)
		flash_tween.tween_property(_sprite, "modulate", TINT_CONTAGION, 0.2)


func _stop_contagion_timer() -> void:
	if _contagion_timer != null and is_instance_valid(_contagion_timer):
		_contagion_timer.stop()
		_contagion_timer.queue_free()

	_contagion_timer = null


func _trigger_thermal_shock_explosion() -> void:
	if _parent == null:
		return

	const EXPLOSION_RADIUS: float = 120.0
	var explosion_damage: float = 0.0

	for fx: Dictionary in active_effects:
		if int(fx["type"]) == EffectType.BURN:
			explosion_damage = float(fx["damage"]) * 6.0
			break

	if explosion_damage <= 0.0:
		return

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy == _parent or not is_instance_valid(enemy):
			continue

		var enemy_2d: Node2D = enemy as Node2D

		if enemy_2d == null:
			continue

		var dist: float = _parent.global_position.distance_to(enemy_2d.global_position)

		if dist > EXPLOSION_RADIUS:
			continue

		var falloff: float = 1.0 - (dist / EXPLOSION_RADIUS) * 0.5
		var hc: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent

		if is_instance_valid(hc):
			hc.take_damage(explosion_damage * falloff, "fire")

	_spawn_shatter_visual(_parent.global_position, EXPLOSION_RADIUS)


func _spawn_shatter_visual(_pos: Vector2, _radius: float) -> void:
	pass


func _remove_effect_type(type: EffectType) -> void:
	for i: int in range(active_effects.size() - 1, -1, -1):
		if int(active_effects[i]["type"]) == int(type):
			_on_expired(active_effects[i])
			active_effects.remove_at(i)
			return


func _set_speed_multiplier(multiplier: float) -> void:
	if _parent == null or not "move_speed" in _parent:
		return

	if _original_speed < 0.0:
		_original_speed = float(_parent.get("move_speed"))

	_parent.set("move_speed", _original_speed * multiplier)


func _restore_speed() -> void:
	if _parent == null or not "move_speed" in _parent or _original_speed < 0.0:
		return

	for fx: Dictionary in active_effects:
		if int(fx["type"]) == EffectType.STUN or int(fx["type"]) == EffectType.CRYSTALLIZED:
			_parent.set("move_speed", 0.0)
			return

		if int(fx["type"]) == EffectType.SLOW:
			_parent.set("move_speed", _original_speed * (1.0 - float(fx["slow_percent"])))
			return

	_parent.set("move_speed", _original_speed)


func _update_tint() -> void:
	if _sprite == null:
		return

	if has_effect(EffectType.CRYSTALLIZED) or has_effect(EffectType.CONTAGION):
		return

	_kill_pulse_tween()

	if active_effects.is_empty():
		_sprite.modulate = _original_color
		return

	var priority: Array[int] = [
		EffectType.STUN,
		EffectType.SHOCK,
		EffectType.BURN,
		EffectType.POISON,
		EffectType.VIRAL,
		EffectType.SLOW,
	]

	for effect_type: int in priority:
		if not has_effect(effect_type as EffectType):
			continue

		match effect_type:
			EffectType.STUN:
				_sprite.modulate = TINT_STUN
			EffectType.SHOCK:
				_sprite.modulate = TINT_SHOCK
			EffectType.BURN:
				_sprite.modulate = TINT_BURN
			EffectType.POISON:
				_sprite.modulate = TINT_POISON
			EffectType.VIRAL:
				_sprite.modulate = TINT_VIRAL
			EffectType.SLOW:
				_sprite.modulate = TINT_SLOW

		return

	_sprite.modulate = _original_color


func _kill_pulse_tween() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = null

# ── Combo reactions ────────────────────────────────────────────────────

func apply_combo_effect(damage_type: String, amount: float) -> void:
	match damage_type:
		"thermal":
			apply_thermal(amount)
		"plasma":
			apply_plasma(amount)
		"corrosive":
			apply_corrosive(amount)
		"magnetic":
			apply_magnetic(amount)
		"viral":
			apply_viral(VIRAL_DURATION, VIRAL_DOT_BONUS)
		"neurotoxin":
			apply_contagion(amount, 1.5, 8.0)


func apply_thermal(base_damage: float) -> void:
	apply_burn(base_damage * 0.25, 4.0, 0.5)

	var armor: ArmorComponent = get_parent().get_node_or_null("ArmorComponent") as ArmorComponent

	if is_instance_valid(armor):
		armor.erode(armor.current_armor * 0.20)

	_spawn_combo_visual(Color(1.0, 0.50, 0.12), 60.0)


func apply_plasma(base_damage: float) -> void:
	const PLASMA_RADIUS: float = 90.0

	_spawn_combo_visual(Color(0.9, 0.20, 1.0), PLASMA_RADIUS)

	if _parent == null:
		return

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy == _parent or not is_instance_valid(enemy):
			continue

		var enemy_2d: Node2D = enemy as Node2D

		if enemy_2d == null:
			continue

		var dist: float = _parent.global_position.distance_to(enemy_2d.global_position)

		if dist > PLASMA_RADIUS:
			continue

		var falloff: float = 1.0 - (dist / PLASMA_RADIUS) * 0.55
		var hc: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent

		if is_instance_valid(hc):
			hc.take_damage(base_damage * falloff * 0.6, "combo")


func apply_corrosive(base_damage: float) -> void:
	var armor: ArmorComponent = get_parent().get_node_or_null("ArmorComponent") as ArmorComponent

	if is_instance_valid(armor):
		armor.erode(armor.current_armor * 0.15)

	apply_poison(base_damage * 0.15, 3.0, 0.75)
	_spawn_combo_visual(Color(0.60, 1.0, 0.08), 50.0)


func apply_magnetic(base_damage: float) -> void:
	var shield: ShieldComponent = get_parent().get_node_or_null("ShieldComponent") as ShieldComponent

	if is_instance_valid(shield):
		shield.absorb(base_damage * 2.0)
	else:
		apply_slow(0.30, 1.5)

	_spawn_combo_visual(Color(0.20, 0.80, 1.0), 55.0)


func _spawn_combo_visual(color: Color, radius: float) -> void:
	if _parent == null or not _parent.is_inside_tree():
		return

	var ring: ComboRing = ComboRing.new()
	ring.ring_color = color
	ring.max_radius = radius
	ring.global_position = _parent.global_position
	get_tree().current_scene.add_child(ring)
