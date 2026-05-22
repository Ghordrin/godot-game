extends CanvasLayer
class_name DashIndicator

## Screen-space dash cooldown indicator.
## Spawned by the player in _ready(). Reads player.dash_cooldown directly.
## Draws a circular arc that fills as the cooldown expires.
##
## SETUP: Set `player` before adding to the scene tree.

## Reference to the player node. Set before add_child().
var player: Node = null

## Radius of the indicator circle in pixels.
const RADIUS: float   = 20.0

## Thickness of the arc and ring strokes.
const STROKE: float   = 3.5

## Screen position offset from bottom-center.
const OFFSET: Vector2 = Vector2(0.0, -48.0)

var _draw_node: _IndicatorDraw = null
var _ready_pulse: float        = 0.0   # Increases when dash becomes ready for flash


func _ready() -> void:
	layer = 15   # Render above game elements

	_draw_node         = _IndicatorDraw.new()
	_draw_node.owner_indicator = self
	add_child(_draw_node)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	## Drive pulse animation when dash is ready
	var on_cooldown: bool = player.get("_dash_cooldown") > 0.0
	if not on_cooldown:
		_ready_pulse = min(_ready_pulse + delta * 4.0, 1.0)
	else:
		_ready_pulse = 0.0


# ══════════════════════════════════════════════════════════════════════
# Inner draw node — handles all rendering
# ══════════════════════════════════════════════════════════════════════

class _IndicatorDraw extends Node2D:

	var owner_indicator: Node = null

	func _ready() -> void:
		## Position at bottom-center of viewport
		var vp: Vector2 = get_viewport().get_visible_rect().size
		position = vp / 2.0 * Vector2(1.0, 2.0) + DashIndicator.OFFSET

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if owner_indicator == null:
			return

		var player: Node = owner_indicator.player
		if player == null or not is_instance_valid(player):
			return

		var cooldown_remaining: float = player.get("_dash_cooldown")
		var cooldown_total: float     = player.get("dash_cooldown_time")
		var is_dashing: bool          = player.get("_dash_active")
		var ready_pulse: float        = owner_indicator.get("_ready_pulse")

		var on_cooldown: bool = cooldown_remaining > 0.0
		var progress: float   = 1.0 - clamp(cooldown_remaining / max(cooldown_total, 0.001), 0.0, 1.0)

		## ── Background ring ─────────────────────────────────────────
		draw_arc(
			Vector2.ZERO, DashIndicator.RADIUS,
			0.0, TAU, 64,
			Color(0.2, 0.2, 0.25, 0.7),
			DashIndicator.STROKE
		)

		if on_cooldown:
			## ── Cooldown fill arc ────────────────────────────────────
			## Fills clockwise from the top (−π/2) as cooldown expires
			var end_angle: float = -PI * 0.5 + progress * TAU
			draw_arc(
				Vector2.ZERO, DashIndicator.RADIUS,
				-PI * 0.5, end_angle, 64,
				Color(0.35, 0.75, 1.0, 0.9),
				DashIndicator.STROKE
			)
		else:
			## ── Ready state — full bright ring + inner glow ──────────
			var pulse: float = sin(owner_indicator._ready_pulse * PI * 3.0) * 0.15 + 0.85

			## Full ring in bright cyan
			draw_arc(
				Vector2.ZERO, DashIndicator.RADIUS,
				0.0, TAU, 64,
				Color(0.4, 0.85, 1.0, 0.95),
				DashIndicator.STROKE
			)

			## Inner glow circle — pulses to draw attention
			draw_circle(
				Vector2.ZERO,
				DashIndicator.RADIUS * 0.55 * pulse,
				Color(0.5, 0.9, 1.0, 0.35 * pulse)
			)

		## ── Center icon — solid dot or dashed indicator ──────────────
		var center_color: Color
		if is_dashing:
			## Bright white while actively dashing
			center_color = Color(1.0, 1.0, 1.0, 0.95)
		elif on_cooldown:
			center_color = Color(0.3, 0.3, 0.35, 0.5)
		else:
			center_color = Color(0.45, 0.88, 1.0, 0.85)

		draw_circle(Vector2.ZERO, 5.0, center_color)

		## ── "DASH" label below the circle ────────────────────────────
		var font: Font   = ThemeDB.fallback_font
		var label: String = "DASH"
		var label_color: Color

		if on_cooldown:
			label_color = Color(0.5, 0.5, 0.55, 0.7)
		else:
			label_color = Color(0.7, 0.92, 1.0, 0.95)

		## Outline
		for offset in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
			draw_string(font,
				Vector2(-12.0, DashIndicator.RADIUS + 14.0) + offset,
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(0.0, 0.0, 0.0, 0.7 if on_cooldown else 0.8)
			)

		draw_string(font,
			Vector2(-12.0, DashIndicator.RADIUS + 14.0),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			label_color
		)

		## Cooldown remaining as small number
		if on_cooldown and cooldown_remaining > 0.1:
			var num_str: String = "%.1f" % cooldown_remaining
			draw_string(font,
				Vector2(-7.0, 5.0),
				num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(0.7, 0.7, 0.75, 0.8)
			)
