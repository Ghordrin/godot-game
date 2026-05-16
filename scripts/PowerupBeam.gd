extends Node2D
class_name LootBeam

# ── Rarity Presets ───────────────────────────────────────────────────
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

var RARITY_DATA = {
	Rarity.COMMON:    { "label": "Common",    "color": Color(0.85, 0.85, 0.85) },
	Rarity.UNCOMMON:  { "label": "Uncommon",  "color": Color(0.20, 0.95, 0.30) },
	Rarity.RARE:      { "label": "Rare",      "color": Color(0.25, 0.45, 1.00) },
	Rarity.EPIC:      { "label": "Epic",      "color": Color(0.70, 0.10, 1.00) },
	Rarity.LEGENDARY: { "label": "Legendary", "color": Color(1.00, 0.55, 0.05) },
}

# ── Node Refs ─────────────────────────────────────────────────────────
@onready var outer_glow: Sprite2D           = $OuterGlow
@onready var core_beam: Sprite2D            = $CoreBeam
@onready var spark_particles: GPUParticles2D = $SparkParticles
@onready var ground_decal: Sprite2D         = $GroundDecal
@onready var pulse_ring: Sprite2D           = $PulseRing
@onready var floating_label: Label          = $FloatingLabel

# ── State ─────────────────────────────────────────────────────────────
var base_color: Color = Color.WHITE
var time: float = 0.0
var pulse_ring_time: float = 0.0

const PULSE_DURATION: float = 1.2
const LABEL_HEIGHT: float   = -160.0

# ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_textures()
	_setup_particles()
	_setup_point_light()
	set_rarity(Rarity.COMMON)

# ── Texture Generation ───────────────────────────────────────────────
func _build_textures() -> void:
	# CoreBeam — narrow, bright vertical gradient
	var core_g := Gradient.new()
	core_g.colors  = [Color(1,1,1,0), Color(1,1,1,1), Color(1,1,1,0.7), Color(1,1,1,0)]
	core_g.offsets = [0.0, 0.25, 0.65, 1.0]
	var core_tex := GradientTexture2D.new()
	core_tex.gradient = core_g
	core_tex.width    = 32
	core_tex.height   = 160
	core_beam.texture = core_tex
	core_beam.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	core_beam.position = Vector2(0, -80)

	# OuterGlow — wide, soft vertical gradient
	var glow_g := Gradient.new()
	glow_g.colors  = [Color(1,1,1,0), Color(1,1,1,0.3), Color(1,1,1,0.12), Color(1,1,1,0)]
	glow_g.offsets = [0.0, 0.2, 0.6, 1.0]
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = glow_g
	glow_tex.width    = 28
	glow_tex.height   = 160
	outer_glow.texture = glow_tex
	outer_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	outer_glow.position = Vector2(0, -80)

	# GroundDecal — radial, squished for isometric floor
	var decal_g := Gradient.new()
	decal_g.colors  = [Color(1,1,1,0.65), Color(1,1,1,0.2), Color(1,1,1,0)]
	decal_g.offsets = [0.0, 0.5, 1.0]
	var decal_tex := GradientTexture2D.new()
	decal_tex.gradient  = decal_g
	decal_tex.fill      = GradientTexture2D.FILL_RADIAL
	decal_tex.fill_from = Vector2(0.5, 0.5)
	decal_tex.fill_to   = Vector2(1.0, 0.5)
	decal_tex.width     = 128
	decal_tex.height    = 128
	ground_decal.texture = decal_tex
	ground_decal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ground_decal.position = Vector2(0, 8)
	ground_decal.scale = Vector2(1.5, 0.45)

	# PulseRing — thin ring at the outer edge of radial gradient
	var ring_g := Gradient.new()
	ring_g.colors  = [Color(1,1,1,0), Color(1,1,1,0), Color(1,1,1,0.9), Color(1,1,1,0)]
	ring_g.offsets = [0.0, 0.65, 0.82, 1.0]
	var ring_tex := GradientTexture2D.new()
	ring_tex.gradient  = ring_g
	ring_tex.fill      = GradientTexture2D.FILL_RADIAL
	ring_tex.fill_from = Vector2(0.5, 0.5)
	ring_tex.fill_to   = Vector2(1.0, 0.5)
	ring_tex.width     = 128
	ring_tex.height    = 128
	pulse_ring.texture = ring_tex
	pulse_ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pulse_ring.position = Vector2(0, 8)
	pulse_ring.scale = Vector2(1.5, 0.45)

	# ── Shader on CoreBeam ───────────────────────────────────────────
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float scroll_speed : hint_range(0.1, 5.0) = 1.8;
uniform float noise_scale : hint_range(1.0, 20.0) = 6.0;
uniform float brightness : hint_range(0.5, 3.0) = 1.6;
uniform float edge_softness : hint_range(0.01, 0.5) = 0.18;

float hash(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2(1,0)), f.x),
        mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x),
        f.y
    );
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.1;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    vec2 uv = UV;
    vec2 scrolled_uv = uv + vec2(0.0, -TIME * scroll_speed);
    float n = fbm(scrolled_uv * noise_scale);
    float dist_from_center = abs(uv.x - 0.5) * 2.0;
    float edge_mask = 1.0 - smoothstep(1.0 - edge_softness, 1.0, dist_from_center);
    float vertical_mask = smoothstep(0.0, 0.15, uv.y) * smoothstep(1.0, 0.75, uv.y);
    float alpha = n * edge_mask * vertical_mask;
    alpha = pow(alpha, 0.8);
    vec4 base_color = COLOR;
    COLOR = vec4(base_color.rgb * brightness, base_color.a * alpha);
}
"""
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("brightness", 2.4)
	shader_mat.set_shader_parameter("scroll_speed", 2.2)
	shader_mat.set_shader_parameter("noise_scale", 4.0)
	core_beam.material = shader_mat

# ── Particle Setup ────────────────────────────────────────────────────
func _setup_particles() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction            = Vector3(0, -1, 0)
	mat.spread               = 30.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 40.0
	mat.gravity              = Vector3(0, -15, 0)
	mat.scale_min            = 1.5
	mat.scale_max            = 3.5

	var fade := Gradient.new()
	fade.colors  = [Color(1,1,1,1), Color(1,1,1,0)]
	fade.offsets = [0.0, 1.0]
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	mat.color_ramp = fade_tex

	spark_particles.process_material = mat
	spark_particles.position  = Vector2(0, 0)
	spark_particles.amount    = 14
	spark_particles.lifetime  = 1.0
	spark_particles.emitting  = true

# ── Point Light ───────────────────────────────────────────────────────
func _setup_point_light() -> void:
	var light := PointLight2D.new()
	light.texture       = _create_light_texture()
	light.energy        = 0.6
	light.texture_scale = 1.2
	light.position      = Vector2(0, 0)
	add_child(light)

func _create_light_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors  = [Color(1,1,1,1), Color(1,1,1,0)]
	g.offsets = [0.0, 1.0]
	var tex := GradientTexture2D.new()
	tex.gradient  = g
	tex.fill      = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to   = Vector2(1.0, 0.5)
	tex.width     = 128
	tex.height    = 128
	return tex

# ── Public API ────────────────────────────────────────────────────────
func set_rarity(rarity: Rarity) -> void:
	var data = RARITY_DATA[rarity]
	var c: Color = data["color"]
	base_color = c

	core_beam.modulate        = Color(c.r, c.g, c.b, 1.0)
	outer_glow.modulate       = Color(c.r, c.g, c.b, 0.5)
	ground_decal.modulate     = Color(c.r, c.g, c.b, 0.7)
	spark_particles.modulate  = Color(c.r, c.g, c.b, 1.0)
	pulse_ring.modulate       = Color(c.r, c.g, c.b, 0.0)
	floating_label.modulate   = c
	floating_label.text       = data["label"]

	if rarity == Rarity.LEGENDARY:
		spark_particles.amount      = 28
		spark_particles.speed_scale = 1.6

func set_item_name(item_name: String) -> void:
	floating_label.text = item_name

# ── Animation ─────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	time += delta
	_animate_beams()
	_animate_ground(delta)
	_animate_pulse_ring(delta)
	_animate_label()

func _animate_beams() -> void:
	core_beam.modulate.a  = 0.9 + sin(time * 5.0) * 0.1
	outer_glow.modulate.a = 0.6 + sin(time * 3.0 + 0.6) * 0.25
	scale.y = 1.0 + sin(time * 2.5) * 0.03

func _animate_ground(_delta: float) -> void:
	ground_decal.modulate.a = 0.55 + sin(time * 3.5) * 0.2
	var s := 1.4 + sin(time * 2.2) * 0.12
	ground_decal.scale = Vector2(s, s * 0.3)

func _animate_pulse_ring(delta: float) -> void:
	pulse_ring_time += delta
	var t := pulse_ring_time / PULSE_DURATION

	if t >= 1.0:
		pulse_ring_time = 0.0
		t = 0.0

	var ring_size := lerpf(0.8, 2.8, t)
	pulse_ring.scale      = Vector2(ring_size * 1.5, ring_size * 0.45)
	pulse_ring.modulate.a = sin(t * PI) * 0.75

func _animate_label() -> void:
	floating_label.position = Vector2(0, LABEL_HEIGHT + sin(time * 2.0) * 4.0)
