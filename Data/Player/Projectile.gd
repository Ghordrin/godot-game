extends Area2D
class_name Projectile

@export var speed: float = 450.0
@export var damage: int = 10
@export var lifetime: float = 10.0
@export var animation_name: String = "default"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2    = Vector2.RIGHT
var pierces_enemies: bool = false
var base_damage: float    = 10.0

## Projectile type properties — set by apply_projectile_type()
var projectile_type: int     = PowerUpData.ProjectileType.NONE
var bounces_remaining: int   = 0
var homing_strength: float   = 0.0
var nova_radius: float       = 80.0
var nova_damage_ratio: float = 0.5

## Secondary projectile type — modifies impact behavior only
var secondary_type: int = PowerUpData.ProjectileType.NONE
var secondary_rank: int = 1

## Sprite frames override — swap this before calling setup() to change visuals
var sprite_frames_override: SpriteFrames = null

## Damage type colors — passed to DamageNumber so each type is visually distinct
const DMG_PHYSICAL  := Color(1.00, 1.00, 1.00)  # White
const DMG_FIRE      := Color(1.00, 0.42, 0.08)  # Orange-red
const DMG_ICE       := Color(0.40, 0.85, 1.00)  # Light blue
const DMG_LIGHTNING := Color(0.80, 0.55, 1.00)  # Purple
const DMG_POISON    := Color(0.35, 1.00, 0.30)  # Green
const DMG_COMBO     := Color(1.00, 0.88, 0.15)  # Gold — combination triggers

## Damage accumulator — tracks per-type hits to each enemy per hit event
var _hit_tracker: Dictionary = {}

const CHAIN_RADIUS: float        = 150.0
const CHAIN_DAMAGE_FALLOFF: float = 0.6

# ══════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("projectiles")
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	play_projectile_animation()
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()


func _physics_process(delta: float) -> void:
	match projectile_type:
		PowerUpData.ProjectileType.HOMING:
			_update_homing(delta)
		PowerUpData.ProjectileType.RICOCHET:
			_check_ricochet(delta)

	global_position += direction.normalized() * speed * delta


func setup(new_direction: Vector2, new_damage: int = 10, new_base_damage: float = -1.0) -> void:
	direction   = new_direction.normalized()
	damage      = new_damage
	base_damage = new_base_damage if new_base_damage >= 0.0 else float(new_damage)

	# Apply sprite frames override if provided
	if sprite_frames_override and animated_sprite:
		animated_sprite.sprite_frames = sprite_frames_override

	if direction != Vector2.ZERO:
		rotation = direction.angle()


## Call this after setup() to configure projectile type behavior and visuals.
## Rank scales the strength of the effect.
func apply_projectile_type(type: int, rank: int) -> void:
	projectile_type = type

	match type:
		PowerUpData.ProjectileType.PHASE:
			# Pierce count = rank. Projectile passes through enemies.
			pierces_enemies = true
			# projectile_pierce stat is already handled by StatsComponent
			# but we also set it here as a direct override
			var pierce_count := rank
			# Store pierce remaining — tracked via hit counter in _try_damage
			set_meta("pierce_remaining", pierce_count)

		PowerUpData.ProjectileType.BOULDER:
			# Large slow projectile — bigger, slower, hits harder, pierces
			var size_mult: float = 1.0 + rank * 0.5  # 1.5, 2.0, 2.5, 3.0, 3.5
			speed *= 0.35
			lifetime = 6.0  # Slower → longer lifetime to reach same distance
			pierces_enemies = true
			if animated_sprite:
				animated_sprite.scale = Vector2(size_mult, size_mult)
			# Scale collision shape (duplicate first to avoid modifying shared resource)
			var col := get_node_or_null("CollisionShape2D")
			if col and col.shape != null:
				col.shape = col.shape.duplicate()
				if col.shape is CircleShape2D:
					col.shape.radius *= size_mult
				elif col.shape is RectangleShape2D:
					col.shape.size *= size_mult

		PowerUpData.ProjectileType.RICOCHET:
			# Bounces off walls. Rank = bounce count + 1
			bounces_remaining = rank + 1  # 2, 3, 4, 5, 6 bounces

		PowerUpData.ProjectileType.NOVA:
			# Explodes on impact. Radius and damage scale with rank.
			nova_radius      = 80.0 + rank * 20.0       # 100, 120, 140, 160, 180
			nova_damage_ratio = 0.5 + rank * 0.25        # 0.75, 1.0, 1.25, 1.5, 1.75
			# Nova doesn't pierce — it detonates on first hit
			pierces_enemies = false

		PowerUpData.ProjectileType.HOMING:
			# Curves toward nearest enemy. Rank = turn strength.
			homing_strength = 2.5 + rank * 1.5  # 4.0, 5.5, 7.0, 8.5, 10.0
			lifetime = 6.0  # Homing gets extra time to find targets


func play_projectile_animation() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	else:
		var anims := animated_sprite.sprite_frames.get_animation_names()
		if anims.size() > 0:
			animated_sprite.play(anims[0])


## Apply secondary projectile behavior — only impact effects, not movement.
## Movement is fully controlled by the primary type.
func apply_secondary_type(type: int, rank: int) -> void:
	secondary_type = type
	secondary_rank = rank

	match type:
		PowerUpData.ProjectileType.PHASE:
			# Phase secondary: pierce enemies without slowing the projectile
			pierces_enemies = true
			set_meta("pierce_remaining", rank)

		PowerUpData.ProjectileType.NOVA:
			# Nova secondary: explode on impact in addition to primary behavior
			nova_radius       = 80.0 + rank * 20.0
			nova_damage_ratio = 0.5  + rank * 0.25

		# Boulder, Homing, Ricochet as secondary are ignored —
		# movement behavior cannot stack with itself

# ══════════════════════════════════════════════════════════════════════
# PROJECTILE TYPE BEHAVIORS
# ══════════════════════════════════════════════════════════════════════

func _update_homing(delta: float) -> void:
	var nearest := _find_nearest_enemy()
	if nearest == null:
		return
	var target_dir: Vector2 = global_position.direction_to(nearest.global_position)
	# Lerp direction toward target — strength controls how tightly it tracks
	direction = direction.lerp(target_dir, homing_strength * delta).normalized()
	rotation  = direction.angle()


func _check_ricochet(delta: float) -> void:
	if bounces_remaining <= 0:
		return

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + direction * speed * delta * 3.0
	)
	query.exclude = [self]

	var result := space.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Node = result.collider
	# Only bounce off walls — not enemies, not the player
	if collider.is_in_group("enemies") or collider.is_in_group("player"):
		return

	direction = direction.bounce(result.normal).normalized()
	rotation  = direction.angle()
	bounces_remaining -= 1

	# Visual flash on bounce
	if animated_sprite:
		var t := create_tween()
		t.tween_property(animated_sprite, "modulate", Color(1.5, 1.5, 1.5), 0.05)
		t.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)


func _apply_nova(enemy_root: Node) -> void:
	# Explode: deal AOE damage to all enemies within nova_radius
	var nova_damage: float = damage * nova_damage_ratio
	print("[NOVA] Exploding radius=%.0f damage=%.1f" % [nova_radius, nova_damage])

	for nearby in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(nearby):
			continue
		var dist: float = enemy_root.global_position.distance_to(nearby.global_position)
		if dist > nova_radius:
			continue
		var falloff: float = 1.0 - (dist / nova_radius) * 0.5
		var hc := nearby.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			_deal(nearby, hc, nova_damage * falloff, DMG_FIRE)

	# Visual ring
	_draw_nova_ring(enemy_root.global_position, nova_radius)


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = 9999.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy as Node2D
	return nearest

# ══════════════════════════════════════════════════════════════════════
# HIT DETECTION
# ══════════════════════════════════════════════════════════════════════

func _on_body_entered(_body: Node2D) -> void:
	pass


func _on_area_entered(area: Area2D) -> void:
	_try_damage(area)


func _try_damage(target: Node) -> void:
	var health_component := target.get_node_or_null("HealthComponent")
	var enemy_root: Node  = target

	if health_component == null and target.get_parent() != null:
		health_component = target.get_parent().get_node_or_null("HealthComponent")
		if health_component != null:
			enemy_root = target.get_parent()

	if health_component == null:
		return

	# Crystallized enemies are immune
	var sec: StatusEffectComponent = enemy_root.get_node_or_null("StatusEffectComponent")
	if sec and sec.immune:
		return

	# Clear tracker for this hit event
	_hit_tracker.clear()

	# Primary Nova detonates on first hit — no physical damage, pure AOE
	if projectile_type == PowerUpData.ProjectileType.NOVA:
		_apply_nova(enemy_root)
		_apply_elemental_effects(enemy_root, health_component, sec)
		_flush_damage_numbers()
		queue_free()
		return

	# Physical hit
	_deal(enemy_root, health_component, float(damage), DMG_PHYSICAL)

	# Elemental + combo effects
	_apply_elemental_effects(enemy_root, health_component, sec)

	# Secondary Nova: also explode on impact even though primary isn't Nova
	if secondary_type == PowerUpData.ProjectileType.NOVA:
		_apply_nova(enemy_root)

	# Show one merged damage number per enemy
	_flush_damage_numbers()

	# Phase pierce tracking (handles both primary Phase and secondary Phase)
	if projectile_type == PowerUpData.ProjectileType.PHASE or secondary_type == PowerUpData.ProjectileType.PHASE:
		var remaining: int = get_meta("pierce_remaining", 0)
		remaining -= 1
		set_meta("pierce_remaining", remaining)
		if remaining < 0:
			queue_free()
		return

	if not pierces_enemies:
		queue_free()


## Route all damage through here — tracks type and amount per enemy for display.
func _deal(enemy_root: Node, health_component: Node, amount: float, color: Color = DMG_PHYSICAL) -> void:
	if amount <= 0.0:
		return
	var damage_type := _color_to_type(color)
	health_component.take_damage(amount, damage_type)
	var id := enemy_root.get_instance_id()
	if not _hit_tracker.has(id):
		_hit_tracker[id] = {"root": enemy_root, "hits": []}
	_hit_tracker[id]["hits"].append({"amount": amount, "color": color})
	DamageMeter.record(amount, damage_type)


## Map a damage color back to its type string for the damage meter.
func _color_to_type(color: Color) -> String:
	if color == DMG_FIRE:      return "fire"
	if color == DMG_ICE:       return "ice"
	if color == DMG_LIGHTNING: return "lightning"
	if color == DMG_POISON:    return "poison"
	if color == DMG_COMBO:     return "combo"
	return "physical"


## Show one merged damage number per enemy per hit event.
## Color is determined by the largest single damage source in that hit.
func _flush_damage_numbers() -> void:
	for id in _hit_tracker:
		var entry: Dictionary = _hit_tracker[id]
		var root: Node        = entry["root"]
		if not is_instance_valid(root):
			continue

		var total: float          = 0.0
		var dominant_color: Color = DMG_PHYSICAL
		var dominant_amount: float = 0.0

		for hit in entry["hits"]:
			total += hit.amount
			if hit.amount > dominant_amount:
				dominant_amount = hit.amount
				dominant_color  = hit.color

		DamageNumber.spawn(get_tree().current_scene, root.global_position, total, dominant_color)
	_hit_tracker.clear()

# ══════════════════════════════════════════════════════════════════════
# ELEMENTAL EFFECTS
# ══════════════════════════════════════════════════════════════════════

func _apply_elemental_effects(enemy: Node, health_component: Node, sec: StatusEffectComponent) -> void:
	var wave_scale: float = 1.0 + (PlayerInventory.current_wave - 1) * 0.20
	print("[DMG] Wave=%d  wave_scale=%.2f" % [PlayerInventory.current_wave, wave_scale])

	var element_pools: Dictionary = {}
	var equipped := PlayerInventory.get_equipped_powerups_with_ranks()

	for entry in equipped:
		var powerup: PowerUpData = entry.powerup
		var rank: int            = entry.rank

		if not "element_type" in powerup or powerup.element_type == PowerUpData.ElementType.NONE:
			continue

		var pool: float = float(damage) * powerup.amount * rank * wave_scale
		element_pools[powerup.element_type] = pool
		print("[DMG] %s pool=%.1f (damage=%.1f × amount=%.2f × rank=%d × wave_scale=%.2f)" % [
			PowerUpData.ElementType.keys()[powerup.element_type],
			pool, float(damage), powerup.amount, rank, wave_scale
		])

	if element_pools.is_empty():
		return

	var consumed: Array = []

	for combo in PlayerInventory.active_combinations:
		var combo_elements := _get_combo_element_types(combo)
		var pools_available := true
		for et in combo_elements:
			if not element_pools.has(et):
				pools_available = false
				break
		if not pools_available:
			continue
		consumed.append_array(combo_elements)
		_apply_specific_combination(combo, enemy, health_component, sec, element_pools)

	for element_type in element_pools:
		if element_type in consumed:
			continue
		print("[DMG] %s → individual" % PowerUpData.ElementType.keys()[element_type])
		_apply_individual_element(element_type, element_pools[element_type], enemy, health_component, sec)


func _apply_individual_element(
	element_type: int,
	pool: float,
	enemy: Node,
	health_component: Node,
	sec: StatusEffectComponent
) -> void:
	match element_type:
		PowerUpData.ElementType.FIRE:
			if sec:
				sec.apply_burn(pool / 6.0, 3.0, 0.5)
		PowerUpData.ElementType.ICE:
			_deal(enemy, health_component, pool, DMG_ICE)
			if sec:
				sec.apply_slow(0.30, 2.0, pool)
		PowerUpData.ElementType.LIGHTNING:
			_deal(enemy, health_component, pool, DMG_LIGHTNING)
			if sec:
				sec.apply_stun(0.5)
			_chain_lightning(enemy, pool, 1)
		PowerUpData.ElementType.POISON:
			if sec:
				sec.apply_poison(pool / 8.0, 4.0, 0.5)

# ══════════════════════════════════════════════════════════════════════
# COMBINATION IMPLEMENTATIONS
# ══════════════════════════════════════════════════════════════════════

func _get_combo_element_types(combo: PlayerInventory.ElementalCombo) -> Array:
	match combo:
		PlayerInventory.ElementalCombo.THERMAL_SHOCK:   return [PowerUpData.ElementType.FIRE,      PowerUpData.ElementType.ICE]
		PlayerInventory.ElementalCombo.PLASMA_CASCADE:  return [PowerUpData.ElementType.FIRE,      PowerUpData.ElementType.LIGHTNING]
		PlayerInventory.ElementalCombo.CORROSIVE_MELT:  return [PowerUpData.ElementType.FIRE,      PowerUpData.ElementType.POISON]
		PlayerInventory.ElementalCombo.FROST_PULSE:     return [PowerUpData.ElementType.ICE,       PowerUpData.ElementType.LIGHTNING]
		PlayerInventory.ElementalCombo.WITHERING_TOUCH: return [PowerUpData.ElementType.ICE,       PowerUpData.ElementType.POISON]
		PlayerInventory.ElementalCombo.VIRAL_SPREAD:    return [PowerUpData.ElementType.LIGHTNING, PowerUpData.ElementType.POISON]
	return []


func _apply_specific_combination(
	combo: PlayerInventory.ElementalCombo,
	enemy: Node,
	health_component: Node,
	sec: StatusEffectComponent,
	pools: Dictionary
) -> void:
	match combo:
		PlayerInventory.ElementalCombo.THERMAL_SHOCK:   _apply_shatter(enemy, health_component, sec, pools)
		PlayerInventory.ElementalCombo.PLASMA_CASCADE:  _apply_superheated_arc(enemy, health_component, sec, pools)
		PlayerInventory.ElementalCombo.CORROSIVE_MELT:  _apply_acid_cloud(enemy, health_component, sec, pools)
		PlayerInventory.ElementalCombo.FROST_PULSE:     _apply_magnetic_freeze(enemy, health_component, sec, pools)
		PlayerInventory.ElementalCombo.WITHERING_TOUCH: _apply_crystallize(enemy, health_component, sec, pools)
		PlayerInventory.ElementalCombo.VIRAL_SPREAD:    _apply_contagion(enemy, health_component, sec, pools)


func _apply_shatter(enemy: Node, health_component: Node, sec: StatusEffectComponent, pools: Dictionary) -> void:
	var fire_pool: float    = pools.get(PowerUpData.ElementType.FIRE, 0.0)
	var ice_pool: float     = pools.get(PowerUpData.ElementType.ICE,  0.0)
	var burst_damage: float = (fire_pool + ice_pool) * 1.5

	if sec:
		if sec.has_effect(StatusEffectComponent.EffectType.BURN):
			print("[COMBO] SHATTER triggered! burst=%.1f" % burst_damage)
			sec._remove_effect_type(StatusEffectComponent.EffectType.BURN)
			_deal(enemy, health_component, burst_damage, DMG_COMBO)
			_flash_white(sec)
			return
		if sec.has_effect(StatusEffectComponent.EffectType.SLOW):
			print("[COMBO] SHATTER triggered! burst=%.1f" % burst_damage)
			sec._remove_effect_type(StatusEffectComponent.EffectType.SLOW)
			_deal(enemy, health_component, burst_damage, DMG_COMBO)
			_flash_white(sec)
			return

	print("[COMBO] SHATTER primed")
	if sec and fire_pool > 0.0:
		sec.apply_burn(fire_pool / 6.0, 3.0, 0.5)
	elif sec and ice_pool > 0.0:
		sec.apply_slow(0.30, 2.0, ice_pool)
		_deal(enemy, health_component, ice_pool, DMG_ICE)


func _apply_superheated_arc(enemy: Node, _health_component: Node, _sec: StatusEffectComponent, pools: Dictionary) -> void:
	var fire_pool: float      = pools.get(PowerUpData.ElementType.FIRE,      0.0)
	var lightning_pool: float = pools.get(PowerUpData.ElementType.LIGHTNING, 0.0)
	var aoe_damage: float     = fire_pool + lightning_pool

	print("[COMBO] SUPERHEATED ARC aoe=%.1f" % aoe_damage)

	for nearby in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(nearby):
			continue
		var dist: float = enemy.global_position.distance_to(nearby.global_position)
		if dist > 150.0:
			continue
		var falloff: float = 1.0 - (dist / 150.0) * 0.5
		var hc := nearby.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			_deal(nearby, hc, aoe_damage * falloff, DMG_FIRE)
		var nearby_sec: StatusEffectComponent = nearby.get_node_or_null("StatusEffectComponent")
		if nearby_sec:
			nearby_sec.apply_burn(fire_pool / 6.0, 1.5, 0.5)


func _apply_acid_cloud(enemy: Node, _health_component: Node, sec: StatusEffectComponent, pools: Dictionary) -> void:
	var fire_pool: float   = pools.get(PowerUpData.ElementType.FIRE,   0.0)
	var poison_pool: float = pools.get(PowerUpData.ElementType.POISON, 0.0)

	if sec:
		if sec.has_effect(StatusEffectComponent.EffectType.BURN):
			print("[COMBO] ACID CLOUD triggered!")
			sec._remove_effect_type(StatusEffectComponent.EffectType.BURN)
			for nearby in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(nearby):
					continue
				if enemy.global_position.distance_to(nearby.global_position) <= 120.0:
					var nearby_sec: StatusEffectComponent = nearby.get_node_or_null("StatusEffectComponent")
					if nearby_sec:
						nearby_sec.apply_poison((fire_pool + poison_pool) / 8.0, 4.0, 0.5)
			return
		if sec.has_effect(StatusEffectComponent.EffectType.POISON):
			print("[COMBO] ACID CLOUD burn trigger!")
			sec._remove_effect_type(StatusEffectComponent.EffectType.POISON)
			sec.apply_burn((fire_pool + poison_pool) / 4.0, 3.0, 0.5)
			return

	print("[COMBO] ACID CLOUD primed")
	if sec:
		sec.apply_burn(fire_pool / 6.0, 3.0, 0.5)


func _apply_magnetic_freeze(enemy: Node, _health_component: Node, sec: StatusEffectComponent, pools: Dictionary) -> void:
	var ice_pool: float       = pools.get(PowerUpData.ElementType.ICE,       0.0)
	var lightning_pool: float = pools.get(PowerUpData.ElementType.LIGHTNING, 0.0)
	var pull_damage: float    = (ice_pool + lightning_pool) * 0.5

	print("[COMBO] MAGNETIC FREEZE pull_damage=%.1f" % pull_damage)

	if sec:
		sec.apply_slow(0.50, 2.0, ice_pool)

	for nearby in get_tree().get_nodes_in_group("enemies"):
		if nearby == enemy or not is_instance_valid(nearby):
			continue
		if enemy.global_position.distance_to(nearby.global_position) > 250.0:
			continue
		var tween := nearby.create_tween()
		tween.tween_property(nearby, "global_position",
			enemy.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 0.35)
		var hc := nearby.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			_deal(nearby, hc, pull_damage, DMG_LIGHTNING)
		var nearby_sec: StatusEffectComponent = nearby.get_node_or_null("StatusEffectComponent")
		if nearby_sec:
			nearby_sec.apply_slow(0.40, 1.5)


func _apply_crystallize(enemy: Node, health_component: Node, sec: StatusEffectComponent, pools: Dictionary) -> void:
	var ice_pool: float    = pools.get(PowerUpData.ElementType.ICE,    0.0)
	var poison_pool: float = pools.get(PowerUpData.ElementType.POISON, 0.0)
	var shatter_damage: float = (ice_pool + poison_pool) * 2.0

	if sec:
		if sec.has_effect(StatusEffectComponent.EffectType.POISON) or sec.has_effect(StatusEffectComponent.EffectType.SLOW):
			print("[COMBO] CRYSTALLIZE triggered! shatter=%.1f" % shatter_damage)
			sec.apply_crystallize(shatter_damage, 3.0)
			return

	print("[COMBO] CRYSTALLIZE primed")
	if sec and poison_pool > 0.0:
		sec.apply_poison(poison_pool / 8.0, 4.0, 0.5)
	elif sec:
		sec.apply_slow(0.30, 2.0, ice_pool)
		_deal(enemy, health_component, ice_pool, DMG_ICE)


func _apply_contagion(_enemy: Node, _health_component: Node, sec: StatusEffectComponent, pools: Dictionary) -> void:
	var lightning_pool: float = pools.get(PowerUpData.ElementType.LIGHTNING, 0.0)
	var poison_pool: float    = pools.get(PowerUpData.ElementType.POISON,    0.0)
	var pulse_pool: float     = lightning_pool + poison_pool

	if sec and not sec.has_effect(StatusEffectComponent.EffectType.CONTAGION):
		print("[COMBO] CONTAGION PULSE applied! pulse_pool=%.1f" % pulse_pool)
		sec.apply_contagion(pulse_pool, 1.5, 8.0)

# ══════════════════════════════════════════════════════════════════════
# CHAIN LIGHTNING
# ══════════════════════════════════════════════════════════════════════

func _chain_lightning(source_enemy: Node, element_pool: float, rank: int) -> void:
	var current_damage: float = element_pool
	var hit_enemies: Array    = [source_enemy]

	for _i in rank:
		var last_hit: Node = hit_enemies.back()
		if not is_instance_valid(last_hit):
			break

		var nearest_enemy: Node = null
		var nearest_dist: float = CHAIN_RADIUS

		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy in hit_enemies or not is_instance_valid(enemy):
				continue
			var dist: float = last_hit.global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist  = dist
				nearest_enemy = enemy

		if nearest_enemy == null:
			break

		current_damage *= CHAIN_DAMAGE_FALLOFF

		var hc := nearest_enemy.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			_deal(nearest_enemy, hc, current_damage, DMG_LIGHTNING)

		var chained_sec: StatusEffectComponent = nearest_enemy.get_node_or_null("StatusEffectComponent")
		if chained_sec:
			chained_sec.apply_stun(0.5)

		_draw_chain_arc(last_hit.global_position, nearest_enemy.global_position)
		hit_enemies.append(nearest_enemy)

# ══════════════════════════════════════════════════════════════════════
# VISUALS
# ══════════════════════════════════════════════════════════════════════

func _flash_white(sec: StatusEffectComponent) -> void:
	if sec._sprite == null:
		return
	var t := sec.create_tween()
	t.tween_property(sec._sprite, "modulate", Color(2.5, 2.5, 2.5), 0.05)
	t.tween_property(sec._sprite, "modulate", sec._original_color,  0.2)


func _draw_chain_arc(from_pos: Vector2, to_pos: Vector2) -> void:
	var line := Line2D.new()
	line.z_index = 10
	for i in range(9):
		var t: float    = float(i) / 8.0
		var pt: Vector2 = from_pos.lerp(to_pos, t)
		if i > 0 and i < 8:
			var perp: Vector2 = (to_pos - from_pos).normalized().rotated(PI * 0.5)
			pt += perp * randf_range(-12.0, 12.0)
		line.add_point(pt)
	line.width         = 2.0
	line.default_color = Color(0.7, 0.85, 1.0, 0.9)
	get_tree().current_scene.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)


func _draw_nova_ring(_pos: Vector2, _radius: float) -> void:
	pass  # TODO: add particle effect when art is ready
