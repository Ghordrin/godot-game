extends Node
class_name AffixComponent

## Handles elite affixes on an enemy.
## Attach to any enemy scene and call apply_affixes() with AffixTable.roll().

var active_affixes: Array[AffixData] = []

var _regen_timer: float = 0.0
var _aura_timer: float = 0.0
var _trail_timer: float = 0.0

var is_cc_immune: bool = false
var is_combo_immune: bool = false

var _fire_aura_particles: CPUParticles2D = null

const REGEN_RATE: float = 0.05
const FIRE_AURA_TICK: float = 1.5
const FIRE_AURA_RADIUS: float = 80.0
const TOXIC_TRAIL_INTERVAL: float = 0.7


func _ready() -> void:
	set_process(true)


func apply_affixes(affixes: Array[AffixData]) -> void:
	active_affixes = affixes.duplicate()

	for affix: AffixData in active_affixes:
		_setup_affix(affix)


func has_affix(type: AffixData.AffixType) -> bool:
	for affix: AffixData in active_affixes:
		if affix.affix_type == type:
			return true

	return false


func _setup_affix(affix: AffixData) -> void:
	match affix.affix_type:
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

		_:
			pass


func _process(delta: float) -> void:
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return

	var health: HealthComponent = parent.get_node_or_null("HealthComponent") as HealthComponent

	if has_affix(AffixData.AffixType.REGENERATING) and health != null:
		_regen_timer += delta
		if _regen_timer >= 1.0:
			_regen_timer -= 1.0

			var heal_amount: int = int(round(float(health.max_health) * REGEN_RATE))
			if heal_amount > 0:
				health.heal(heal_amount)

	if has_affix(AffixData.AffixType.FIRE_AURA):
		_aura_timer += delta
		if _aura_timer >= FIRE_AURA_TICK:
			_aura_timer -= FIRE_AURA_TICK
			_apply_fire_aura(parent)

	if has_affix(AffixData.AffixType.TOXIC_CLOUD):
		_trail_timer += delta
		if _trail_timer >= TOXIC_TRAIL_INTERVAL:
			_trail_timer -= TOXIC_TRAIL_INTERVAL
			_spawn_poison_cloud_visual(parent.global_position)


func _apply_fire_aura(parent: Node2D) -> void:
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player: Node2D = node as Node2D
		if player == null:
			continue

		if parent.global_position.distance_to(player.global_position) <= FIRE_AURA_RADIUS:
			var status: StatusEffectComponent = player.get_node_or_null("StatusEffectComponent") as StatusEffectComponent
			if status != null:
				status.apply_burn(5.0, 2.0, 0.5)


func modify_incoming_damage(amount: float, damage_type: String) -> float:
	var value: float = amount

	if has_affix(AffixData.AffixType.CONDUCTIVE) and damage_type == "lightning":
		value *= 2.0

	if has_affix(AffixData.AffixType.COMBINATION_IMMUNE) and damage_type == "combo":
		return 0.0

	return value


func _spawn_fire_aura_visual() -> void:
	var parent: Node2D = get_parent() as Node2D
	if parent == null or _fire_aura_particles != null:
		return

	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = "FireAuraParticles"
	particles.emitting = true
	particles.lifetime = FIRE_AURA_TICK
	particles.one_shot = false
	particles.amount = 100
	particles.gravity = Vector2.ZERO

	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = FIRE_AURA_RADIUS

	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 22.0
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.85
	particles.speed_scale = 1.0

	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.6, 0.2, 0.65))
	grad.set_color(1, Color(1.0, 0.2, 0.05, 0.0))
	particles.color_ramp = grad

	parent.add_child(particles)
	_fire_aura_particles = particles


func _spawn_poison_cloud_visual(pos: Vector2) -> void:
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return

	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = "PoisonCloudParticles"
	particles.position = parent.to_local(pos)
	particles.emitting = true
	particles.one_shot = true
	particles.lifetime = 1.2
	particles.amount = 40
	particles.gravity = Vector2.ZERO

	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 12.0

	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 14.0
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.95

	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.4, 1.0, 0.3, 0.65))
	grad.set_color(1, Color(0.4, 1.0, 0.3, 0.0))
	particles.color_ramp = grad

	parent.add_child(particles)

	particles.finished.connect(particles.queue_free)
