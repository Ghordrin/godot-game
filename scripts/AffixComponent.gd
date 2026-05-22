extends Node
class_name AffixComponent

## Handles elite affixes on an enemy.
## Attach to any enemy scene and call apply_affixes() with the rolled affix data
## from AffixTable.roll().  This component implements core affix behaviour
## (e.g. regeneration, fire aura, toxic trail) and spawns simple particle
## visuals for aura and trail effects.  Affixes that affect other
## components (e.g. armour, shields) are left to those components and
## queried via modify_incoming_damage().

var active_affixes: Array[AffixData] = []

## Regeneration timer – heals once per second when REGENERATING is active
var _regen_timer: float = 0.0
## Fire aura timer – damages nearby players periodically
var _aura_timer: float = 0.0
## Toxic cloud timer – leaves a poison trail
var _trail_timer: float = 0.0

## Flags exposed to other systems
var is_cc_immune: bool = false     ## TRUE when NULLIFYING_AURA or FROST_SHELL is present
var is_combo_immune: bool = false  ## TRUE when COMBINATION_IMMUNE is present

## Visual nodes (spawned on demand and freed automatically)
var _fire_aura_particles: CPUParticles2D = null

## Constants for timing and radii.  Adjust these to tune the behaviour.
const REGEN_RATE := 0.05            # 5% of max health per second
const FIRE_AURA_TICK := 1.5         # Seconds between burn pulses
const FIRE_AURA_RADIUS := 80.0      # Distance to affect players
const TOXIC_TRAIL_INTERVAL := 0.7   # Seconds between poison cloud spawns

func _ready() -> void:
	set_process(true)

## Call this once to initialise the component with a list of affixes.
func apply_affixes(affixes: Array[AffixData]) -> void:
	active_affixes = affixes.duplicate()
	for a in active_affixes:
		_setup_affix(a)

## Returns true if this enemy has the given affix type.
func has_affix(type: AffixData.AffixType) -> bool:
	for a in active_affixes:
		if a.affix_type == type:
			return true
	return false

## Performs per-affix setup.  Flags or visuals can be created here.
func _setup_affix(a: AffixData) -> void:
	match a.affix_type:
		AffixData.AffixType.REGENERATING:
			_regen_timer = 0.0
		AffixData.AffixType.FIRE_AURA:
			_spawn_fire_aura_visual()
			_aura_timer = 0.0
		AffixData.AffixType.TOXIC_CLOUD:
			_trail_timer = 0.0
		AffixData.AffixType.NULLIFYING_AURA, AffixData.AffixType.FROST_SHELL:
			is_cc_immune = true
		AffixData.AffixType.COMBINATION_IMMUNE:
			is_combo_immune = true
		# FRENZIED could modify move speed here if the parent exposes it
		_:
			pass

## Called every frame.  Handles timers for regeneration, fire aura and toxic cloud.
func _process(delta: float) -> void:
	var parent = get_parent() as Node2D
	if parent == null:
		return
	var health := parent.get_node_or_null("HealthComponent") as HealthComponent

	# Regeneration – heal max_health * REGEN_RATE once per second
	if has_affix(AffixData.AffixType.REGENERATING) and health:
		_regen_timer += delta
		if _regen_timer >= 1.0:
			_regen_timer -= 1.0
			var heal_amount: int = int(round(health.max_health * REGEN_RATE))
			if heal_amount > 0:
				health.heal(heal_amount)

	# Fire aura – burn players within radius every tick
	if has_affix(AffixData.AffixType.FIRE_AURA):
		_aura_timer += delta
		if _aura_timer >= FIRE_AURA_TICK:
			_aura_timer -= FIRE_AURA_TICK
			_apply_fire_aura(parent)

	# Toxic cloud – spawn poison clouds along the path
	if has_affix(AffixData.AffixType.TOXIC_CLOUD):
		_trail_timer += delta
		if _trail_timer >= TOXIC_TRAIL_INTERVAL:
			_trail_timer -= TOXIC_TRAIL_INTERVAL
			_spawn_poison_cloud_visual(parent.global_position)

## Applies the fire aura effect to any player within range.
func _apply_fire_aura(parent: Node2D) -> void:
	var players := get_tree().get_nodes_in_group("Players")
	for p in players:
		if not p is Node2D:
			continue
		var player := p as Node2D
		if parent.global_position.distance_to(player.global_position) <= FIRE_AURA_RADIUS:
			var status := player.get_node_or_null("StatusEffectComponent") as StatusEffectComponent
			if status:
				status.apply_burn(5.0, 2.0, 0.5)

## Modify incoming damage based on the active affixes.
## Should be called from HealthComponent.take_damage() before shields and armour.
func modify_incoming_damage(amount: float, damage_type: String) -> float:
	var value := amount
	# Conductive doubles lightning damage
	if has_affix(AffixData.AffixType.CONDUCTIVE) and damage_type == "lightning":
		value *= 2.0
	# Combination immune negates combo damage
	if has_affix(AffixData.AffixType.COMBINATION_IMMUNE) and damage_type == "combo":
		return 0.0
	return value

## Spawns a CPUParticles2D node around the parent to visualise the fire aura.
func _spawn_fire_aura_visual() -> void:
	var parent := get_parent() as Node2D
	if parent == null or _fire_aura_particles:
		return
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.lifetime = FIRE_AURA_TICK
	particles.one_shot = false
	particles.amount = 100
	particles.gravity = Vector2.ZERO
	# Configure emission shape as a circle around the enemy
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = FIRE_AURA_RADIUS
	# Configure scale and velocity for subtle flame effect
	particles.scale = Vector2.ONE * 1.0
	particles.initial_velocity = 20.0
	particles.angular_velocity = 0.0
	particles.speed_scale = 1.0
	# Colour ramp: fades from yellow-orange to transparent
	var ramp := GradientTexture.new()
	var grad := Gradient.new()
	grad.colors = [Color(1.0, 0.6, 0.2, 0.7), Color(1.0, 0.3, 0.1, 0.0)]
	ramp.gradient = grad
	particles.color_ramp = ramp
	parent.add_child(particles)
	_fire_aura_particles = particles

## Spawns a one–shot CPUParticles2D cloud at the given world position for the toxic cloud affix.
func _spawn_poison_cloud_visual(pos: Vector2) -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var particles := CPUParticles2D.new()
	particles.position = parent.to_local(pos)
	particles.emitting = true
	particles.one_shot = true
	particles.lifetime = 1.2
	particles.amount = 40
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 12.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity = 10.0
	particles.scale = Vector2.ONE * 0.8
	# Colour ramp: green fading to transparent
	var ramp := GradientTexture.new()
	var grad := Gradient.new()
	grad.colors = [Color(0.4, 1.0, 0.3, 0.7), Color(0.4, 1.0, 0.3, 0.0)]
	ramp.gradient = grad
	particles.color_ramp = ramp
	parent.add_child(particles)
	# Free the particles after they finish
	particles.connect("finished", particles, "queue_free")
