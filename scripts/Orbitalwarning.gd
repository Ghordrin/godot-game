extends Node2D
class_name OrbitalWarning

## Orbital strike telegraph and impact effect.
##
## Phase 1 — WARNING: a circle expands from nothing to full danger radius.
##   Players see the area filling up and must escape before it peaks.
##
## Phase 2 — IMPACT: bright flash and expanding shockwave ring.
##   Emits warning_complete so the boss script deals damage at this moment.
##
## Phase 3 — PARTICLES: 200 sparks and chunks erupt radially, arc with
##   gravity, and fade. Node frees itself when all particles have died.

signal warning_complete  ## Emitted at the moment of impact so the boss deals damage.

## How long the expanding warning circle takes to reach full size.
@export var duration: float          = 2.5

## Radius of the instant-damage inner zone.
@export var inner_radius: float      = 60.0

## Full danger area radius — outer edge of the expanding circle.
@export var outer_radius: float      = 140.0

## How many particles fire on impact. Higher = more spectacular but more draw calls.
@export var particle_count: int      = 200

# ── Phase tracking ─────────────────────────────────────────────────────
enum Phase { WARNING, IMPACT, PARTICLES }
var _phase: Phase        = Phase.WARNING
var _elapsed: float      = 0.0     # Time within the current phase
var _pulse: float        = 0.0     # 0→1 oscillation for pulsing effects

# ── Particle data ──────────────────────────────────────────────────────
## Each particle is a Dictionary:
## { pos, vel, life, max_life, size, color: Color, gravity: float }
var _particles: Array = []


func _ready() -> void:
	## z_index 5 renders above most tilemaps (which default to 0-1).
	## If your TileMapLayer uses a custom z_index higher than 5,
	## increase this value to match it + 1.
	## Bumped to 15 during particles so the explosion reads above enemies too.
	z_index = 5


func _process(delta: float) -> void:
	_elapsed  += delta
	_pulse     = sin(_elapsed * 6.0) * 0.5 + 0.5  # Smooth 0→1 oscillation

	match _phase:
		Phase.WARNING:
			if _elapsed >= duration:
				_enter_impact()

		Phase.IMPACT:
			if _elapsed >= 0.18:
				_enter_particles()

		Phase.PARTICLES:
			_tick_particles(delta)
			# Once every particle has expired, clean up the node
			if _all_particles_dead():
				queue_free()
				return

	queue_redraw()


# ══════════════════════════════════════════════════════════════════════
# PHASE TRANSITIONS
# ══════════════════════════════════════════════════════════════════════

func _enter_impact() -> void:
	_phase   = Phase.IMPACT
	_elapsed = 0.0
	warning_complete.emit()  ## Boss deals damage now


func _enter_particles() -> void:
	_phase   = Phase.PARTICLES
	_elapsed = 0.0
	z_index  = 15  # Rise above enemies so explosion reads clearly
	_spawn_particles()


# ══════════════════════════════════════════════════════════════════════
# DRAWING
# ══════════════════════════════════════════════════════════════════════

func _draw() -> void:
	match _phase:
		Phase.WARNING:   _draw_warning()
		Phase.IMPACT:    _draw_impact()
		Phase.PARTICLES: _draw_particles()


func _draw_warning() -> void:
	var progress: float   = clamp(_elapsed / duration, 0.0, 1.0)
	var cur_r: float      = lerp(0.0, outer_radius, progress)

	# ── Expanding fill ──────────────────────────────────────────────
	# Intensity ramps up as the circle approaches full size
	var fill_alpha: float = 0.12 + progress * 0.16 + _pulse * 0.06
	draw_circle(Vector2.ZERO, cur_r, Color(0.85, 0.08, 0.05, fill_alpha))

	# ── Edge ring ──────────────────────────────────────────────────
	# The bright expanding edge is the primary timing cue for players
	var edge_alpha: float = 0.55 + progress * 0.45
	var edge_width: float = 2.5  + progress * 3.5
	draw_arc(Vector2.ZERO, cur_r, 0.0, TAU, 72,
		Color(1.0, 0.50, 0.08, edge_alpha), edge_width)

	# ── Inner kill zone — visible once circle grows over it ─────────
	if cur_r >= inner_radius * 0.6:
		var inner_alpha: float = clamp((cur_r - inner_radius * 0.6) / (inner_radius * 0.4), 0.0, 1.0)
		draw_circle(Vector2.ZERO, inner_radius,
			Color(1.0, 0.05, 0.05, (0.2 + progress * 0.25 + _pulse * 0.08) * inner_alpha))
		draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 48,
			Color(1.0, 0.15, 0.15, 0.75 * inner_alpha), 2.5)

	# ── Crosshair ──────────────────────────────────────────────────
	var cross: float      = inner_radius * 0.55
	var cross_alpha: float = (0.4 + progress * 0.5) * (0.6 + _pulse * 0.4)
	var cross_col := Color(1.0, 0.30, 0.30, cross_alpha)
	draw_line(Vector2(-cross, 0.0), Vector2(cross,  0.0), cross_col, 1.5)
	draw_line(Vector2(0.0, -cross), Vector2(0.0,  cross), cross_col, 1.5)

	# ── Spinning spokes ─────────────────────────────────────────────
	# Rotate faster as the strike approaches to build urgency
	var spoke_speed: float = 1.2 + progress * 5.0
	var base_a: float      = fmod(_elapsed * spoke_speed, TAU / 6.0)
	for i in 6:
		var a: float       = base_a + i * (TAU / 6.0)
		var s: Vector2     = Vector2(cos(a), sin(a)) * (inner_radius + 3.0)
		var e: Vector2     = Vector2(cos(a), sin(a)) * (cur_r - 3.0)
		if (e - s).length() > 4.0:
			draw_line(s, e, Color(1.0, 0.45, 0.1, 0.12 + progress * 0.10), 1.0)


func _draw_impact() -> void:
	var t: float = clamp(_elapsed / 0.18, 0.0, 1.0)

	# Bright white flash filling the full danger zone
	var flash_alpha: float = (1.0 - t) * 0.95
	draw_circle(Vector2.ZERO, outer_radius, Color(1.0, 0.85, 0.55, flash_alpha))

	# Expanding shockwave ring — grows past outer_radius then fades
	var ring_r: float = lerp(outer_radius * 0.8, outer_radius * 1.6, t)
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 72,
		Color(1.0, 1.0, 1.0, (1.0 - t) * 0.9), 5.0 * (1.0 - t * 0.5))


func _draw_particles() -> void:
	for p in _particles:
		var t: float = p["life"] / p["max_life"]
		if t >= 1.0:
			continue

		var alpha: float = 1.0 - t
		var size: float  = p["size"] * (1.0 - t * 0.6)  # Shrink as they age
		var c: Color     = p["color"]
		draw_circle(p["pos"], size, Color(c.r, c.g, c.b, alpha))

		# Bright white core on larger chunks for a hot-coal look
		if p["size"] > 4.0:
			draw_circle(p["pos"], size * 0.45, Color(1.0, 1.0, 0.9, alpha * 0.7))


# ══════════════════════════════════════════════════════════════════════
# PARTICLE SYSTEM
# ══════════════════════════════════════════════════════════════════════

func _spawn_particles() -> void:
	_particles.clear()

	for i in particle_count:
		var angle: float  = randf() * TAU
		var is_spark: bool = randf() < 0.62  # 62% small fast sparks, 38% slower chunks

		var p := {}

		if is_spark:
			# Fast white-to-orange sparks — the main "flash" energy
			var spd: float = randf_range(200.0, 650.0)
			p["pos"]       = Vector2.ZERO
			p["vel"]       = Vector2(cos(angle), sin(angle)) * spd
			p["life"]      = 0.0
			p["max_life"]  = randf_range(0.35, 1.1)
			p["size"]      = randf_range(1.2, 3.5)
			p["gravity"]   = randf_range(20.0, 60.0)   # Light gravity — sparks arc gently
			# Color: white core → orange tip
			var heat: float = randf()
			p["color"]     = Color(1.0, lerpf(0.65, 1.0, heat), lerpf(0.0, 0.5, heat))
		else:
			# Slower heavier chunks — feel like shrapnel/debris
			var spd: float = randf_range(50.0, 230.0)
			p["pos"]       = Vector2.ZERO
			p["vel"]       = Vector2(cos(angle), sin(angle)) * spd
			p["life"]      = 0.0
			p["max_life"]  = randf_range(0.7, 2.2)
			p["size"]      = randf_range(3.0, 9.0)
			p["gravity"]   = randf_range(60.0, 140.0)  # Stronger gravity — chunks fall faster
			# Color: orange-red range
			p["color"]     = Color(
				randf_range(0.85, 1.0),
				randf_range(0.15, 0.55),
				randf_range(0.0,  0.1)
			)

		_particles.append(p)


func _tick_particles(delta: float) -> void:
	for p in _particles:
		if p["life"] >= p["max_life"]:
			continue
		p["life"]    += delta
		p["vel"].y   += p["gravity"] * delta  # Gravity pulls chunks downward
		p["vel"]     *= 0.97                  # Drag — velocity decays over time
		p["pos"]     += p["vel"] * delta


func _all_particles_dead() -> bool:
	if _particles.is_empty():
		return false
	for p in _particles:
		if p["life"] < p["max_life"]:
			return false
	return true
