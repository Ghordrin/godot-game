extends Node
class_name StatusEffectComponent

signal effect_applied(type: EffectType)
signal effect_expired(type: EffectType)

enum EffectType {
	BURN,
	SLOW,
	STUN,
	POISON,
	CRYSTALLIZED,
	CONTAGION,
}

const TINT_STUN := Color(1.3, 1.3, 0.5)
const TINT_BURN := Color(1.5, 0.5, 0.2)
const TINT_POISON := Color(0.5, 1.3, 0.3)
const TINT_SLOW := Color(0.4, 0.7, 1.4)
const TINT_CRYSTALLIZED := Color(0.5, 0.9, 1.5)
const TINT_CONTAGION := Color(0.6, 1.4, 0.5)

var immune: bool = false
var active_effects: Array[Dictionary] = []

var _parent: Node2D = null
var _sprite: Node = null
var _health_comp: Node = null
var _original_speed: float = -1.0
var _original_color: Color = Color.WHITE
var _contagion_timer: Timer = null
var _pulse_tween: Tween = null


func _ready() -> void:
	_parent = get_parent() as Node2D
	if _parent == null:
		push_warning("StatusEffectComponent: parent is not Node2D")
		return

	_sprite = _parent.get_node_or_null("AnimatedSprite2D")
	if _sprite == null:
		_sprite = _parent.get_node_or_null("Sprite2D")

	_health_comp = _parent.get_node_or_null("HealthComponent")

	if "move_speed" in _parent:
		_original_speed = _parent.move_speed

	if _sprite:
		_original_color = _sprite.modulate


func _process(delta: float) -> void:
	if active_effects.is_empty():
		return

	for i in range(active_effects.size() - 1, -1, -1):
		var fx: Dictionary = active_effects[i]
		fx.elapsed += delta

		if fx.tick_rate > 0.0 and not immune:
			fx.tick_timer += delta
			while fx.tick_timer >= fx.tick_rate:
				fx.tick_timer -= fx.tick_rate
				_on_tick(fx)

		if fx.elapsed >= fx.duration:
			active_effects.remove_at(i)
			_on_expired(fx)

	_update_tint()


func apply_burn(damage_per_tick: float, duration: float = 3.0, tick_rate: float = 0.5) -> void:
	_apply(EffectType.BURN, {
		"damage": damage_per_tick,
		"duration": duration,
		"tick_rate": tick_rate,
	})


func apply_slow(slow_percent: float, duration: float = 2.0, element_pool: float = 0.0) -> void:
	var affix := get_parent().get_node_or_null("AffixComponent") as AffixComponent
	if affix and affix.is_cc_immune:
		return

	_apply(EffectType.SLOW, {
		"slow_percent": clamp(slow_percent, 0.0, 0.9),
		"duration": duration,
		"tick_rate": 0.0,
		"element_pool": element_pool,
	})


func apply_stun(duration: float = 0.5) -> void:
	var affix := get_parent().get_node_or_null("AffixComponent") as AffixComponent
	if affix and affix.is_cc_immune:
		return

	_apply(EffectType.STUN, {
		"duration": duration,
		"tick_rate": 0.0,
	})


func apply_poison(base_damage: float, duration: float = 4.0, tick_rate: float = 0.5) -> void:
	_apply(EffectType.POISON, {
		"damage": base_damage,
		"duration": duration,
		"tick_rate": tick_rate,
	})


func apply_crystallize(shatter_damage: float, duration: float = 3.0) -> void:
	_remove_effect_type(EffectType.SLOW)
	_remove_effect_type(EffectType.POISON)

	var shield := get_parent().get_node_or_null("ShieldComponent") as ShieldComponent
	if shield:
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
		if fx.type == type:
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
	if PlayerInventory.active_combination == PlayerInventory.ElementalCombo.THERMAL_SHOCK:
		if has_effect(EffectType.BURN) and has_effect(EffectType.SLOW):
			_trigger_thermal_shock_explosion()


func _apply(type: EffectType, data: Dictionary) -> void:
	for fx: Dictionary in active_effects:
		if fx.type == type:
			fx.duration = data.get("duration", fx.duration)
			fx.elapsed = 0.0

			if data.has("damage"):
				fx.damage = data.damage

			return

	var fx: Dictionary = {
		"type": type,
		"duration": data.get("duration", 3.0),
		"elapsed": 0.0,
		"tick_rate": data.get("tick_rate", 0.0),
		"tick_timer": 0.0,
		"damage": data.get("damage", 0.0),
		"slow_percent": data.get("slow_percent", 0.0),
		"element_pool": data.get("element_pool", 0.0),
		"shatter_damage": data.get("shatter_damage", 0.0),
		"pulse_pool": data.get("pulse_pool", 0.0),
		"pulse_interval": data.get("pulse_interval", 1.5),
	}

	active_effects.append(fx)
	_on_applied(fx)
	effect_applied.emit(type)


func _on_applied(fx: Dictionary) -> void:
	match fx.type:
		EffectType.SLOW:
			_set_speed_multiplier(1.0 - fx.slow_percent)
		EffectType.STUN:
			_set_speed_multiplier(0.0)
		EffectType.CRYSTALLIZED:
			_set_speed_multiplier(0.0)
			immune = true


func _on_tick(fx: Dictionary) -> void:
	if not is_instance_valid(_parent):
		return

	match fx.type:
		EffectType.BURN:
			_deal_damage(fx.damage, "fire")

		EffectType.POISON:
			var progress: float = fx.elapsed / fx.duration
			var ramp: float = 1.0 + progress * 2.0
			_deal_damage(fx.damage * ramp, "poison")


func _on_expired(fx: Dictionary) -> void:
	match fx.type:
		EffectType.SLOW, EffectType.STUN:
			_restore_speed()

		EffectType.CRYSTALLIZED:
			immune = false
			_restore_speed()
			_trigger_crystallize_shatter(fx.shatter_damage)

		EffectType.CONTAGION:
			_stop_contagion_timer()

	effect_expired.emit(fx.type)


func _deal_damage(amount: float, damage_type: String = "physical") -> void:
	if _health_comp == null:
		return
	if not _health_comp.has_method("take_damage"):
		return

	_health_comp.take_damage(amount, damage_type)

	if _parent != null and _parent.is_inside_tree():
		DamageNumberSpawner.spawn(
			_parent.global_position,
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

	var shatter_radius: float = 130.0

	if _sprite:
		_kill_pulse_tween()
		_sprite.modulate = Color(2.0, 2.0, 2.0)

	var self_hc := _parent.get_node_or_null("HealthComponent")
	if self_hc and self_hc.has_method("take_damage"):
		self_hc.take_damage(shatter_damage, "combo")

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == _parent or not is_instance_valid(enemy):
			continue

		var dist: float = _parent.global_position.distance_to(enemy.global_position)
		if dist > shatter_radius:
			continue

		var falloff: float = 1.0 - (dist / shatter_radius) * 0.4
		var hc := enemy.get_node_or_null("HealthComponent")

		if hc and hc.has_method("take_damage"):
			hc.take_damage(shatter_damage * falloff, "combo")

	_spawn_shatter_visual(_parent.global_position, shatter_radius)


func _start_contagion_timer(pulse_pool: float, pulse_interval: float) -> void:
	_stop_contagion_timer()

	_contagion_timer = Timer.new()
	_contagion_timer.wait_time = pulse_interval
	_contagion_timer.one_shot = false
	add_child(_contagion_timer)

	_contagion_timer.timeout.connect(_on_contagion_pulse.bind(pulse_pool))
	_contagion_timer.start()

	if _sprite:
		_kill_pulse_tween()
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_sprite, "modulate", TINT_CONTAGION.lightened(0.4), 0.3)
		_pulse_tween.tween_property(_sprite, "modulate", TINT_CONTAGION, 0.4)
		_pulse_tween.tween_interval(max(0.1, pulse_interval - 0.7))


func _on_contagion_pulse(pulse_pool: float) -> void:
	if not is_instance_valid(_parent):
		_stop_contagion_timer()
		return

	var pulse_radius: float = 120.0
	var pulse_poison: float = pulse_pool / 8.0
	var pulse_stun: float = 0.4

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == _parent or not is_instance_valid(enemy):
			continue

		var dist: float = _parent.global_position.distance_to(enemy.global_position)
		if dist > pulse_radius:
			continue

		var sec := enemy.get_node_or_null("StatusEffectComponent") as StatusEffectComponent
		if sec:
			sec.apply_poison(pulse_poison, 4.0, 0.5)
			sec.apply_stun(pulse_stun)

	if _sprite:
		var flash_tween := create_tween()
		flash_tween.tween_property(_sprite, "modulate", Color(1.0, 2.0, 0.5), 0.1)
		flash_tween.tween_property(_sprite, "modulate", TINT_CONTAGION, 0.2)


func _stop_contagion_timer() -> void:
	if _contagion_timer and is_instance_valid(_contagion_timer):
		_contagion_timer.stop()
		_contagion_timer.queue_free()

	_contagion_timer = null


func _trigger_thermal_shock_explosion() -> void:
	if _parent == null:
		return

	var explosion_radius: float = 120.0
	var explosion_damage: float = 0.0

	for fx: Dictionary in active_effects:
		if fx.type == EffectType.BURN:
			explosion_damage = fx.damage * 6.0
			break

	if explosion_damage <= 0.0:
		return

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == _parent or not is_instance_valid(enemy):
			continue

		var dist: float = _parent.global_position.distance_to(enemy.global_position)
		if dist > explosion_radius:
			continue

		var falloff: float = 1.0 - (dist / explosion_radius) * 0.5
		var hc := enemy.get_node_or_null("HealthComponent")

		if hc and hc.has_method("take_damage"):
			hc.take_damage(explosion_damage * falloff)

	_spawn_shatter_visual(_parent.global_position, explosion_radius)


func _spawn_shatter_visual(_pos: Vector2, _radius: float) -> void:
	pass


func _remove_effect_type(type: EffectType) -> void:
	for i in range(active_effects.size() - 1, -1, -1):
		if active_effects[i].type == type:
			_on_expired(active_effects[i])
			active_effects.remove_at(i)
			return


func _set_speed_multiplier(multiplier: float) -> void:
	if _parent == null:
		return
	if not "move_speed" in _parent:
		return

	if _original_speed < 0.0:
		_original_speed = _parent.move_speed

	_parent.move_speed = _original_speed * multiplier


func _restore_speed() -> void:
	if _parent == null:
		return
	if not "move_speed" in _parent:
		return
	if _original_speed < 0.0:
		return

	for fx: Dictionary in active_effects:
		if fx.type == EffectType.STUN or fx.type == EffectType.CRYSTALLIZED:
			_parent.move_speed = 0.0
			return

		if fx.type == EffectType.SLOW:
			_parent.move_speed = _original_speed * (1.0 - fx.slow_percent)
			return

	_parent.move_speed = _original_speed


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
		EffectType.BURN,
		EffectType.POISON,
		EffectType.SLOW,
	]

	for effect_type: int in priority:
		if not has_effect(effect_type):
			continue

		match effect_type:
			EffectType.STUN:
				_sprite.modulate = TINT_STUN
			EffectType.BURN:
				_sprite.modulate = TINT_BURN
			EffectType.POISON:
				_sprite.modulate = TINT_POISON
			EffectType.SLOW:
				_sprite.modulate = TINT_SLOW

		return

	_sprite.modulate = _original_color


func _kill_pulse_tween() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = null
