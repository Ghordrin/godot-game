shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

// 1. HIGH RESOLUTION PIXEL GRID
// Match this closer to your actual window resolution (e.g., 1024x768 or 1280x720)
// This keeps the "retro" pixel layout without turning your small isometric tiles into mush.
uniform int resolution_x = 1024; 
uniform int resolution_y = 768; 

// 2. HIGHER COLOR DEPTH
// Small details vanish if color depth is too low. 6-bit or 7-bit preserves isometric depth.
uniform int color_bit_depth = 6; 
uniform float dither_strength = 0.008; // Very subtle to prevent diagonal lines from breaking

// 3. SUB-PIXEL JITTER
// Lowered frequency and tiny amount so it feels like a subtle CRT hum rather than a violent shake.
uniform float jitter_amount = 0.001; 
uniform float jitter_speed = 0.4;    
uniform float jitter_frequency = 60.0; // Lower frequency stops the "flicker" on diagonals

// 4. CLEAN EDGES
uniform float chromatic_aberration_strength : hint_range(0.0, 0.1) = 0.002;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;
uniform float vignette_radius : hint_range(0.0, 2.0) = 1.4;

float hash(vec2 p){
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 psx_jitter(vec2 uv, vec2 px){
    float t = floor(TIME * jitter_speed * 4.0) / 4.0; // Slower time steps
    
    float h_shake = hash(vec2(floor(uv.y * jitter_frequency), t)) - 0.5;
    float v_shake = hash(vec2(floor(uv.x * jitter_frequency * 0.5), t)) - 0.5;
    
    // Crucial Change: Scale the jitter directly by the pixel size (px)
    // This ensures the screen never jitters more than a fraction of a single tiny pixel.
    return uv + vec2(h_shake, v_shake) * px * jitter_amount * 100.0;
}

void fragment(){
    vec2 px = vec2(1.0 / float(resolution_x), 1.0 / float(resolution_y));
    
    // Align coordinates to our high-density grid
    vec2 uv = floor(SCREEN_UV / px) * px + px * 0.5;
    
    // Apply the sub-pixel scaled jitter
    uv = psx_jitter(uv, px); 
    
    vec3 col;
    if(chromatic_aberration_strength > 0.0005){
        // Scale aberration by pixel size so it doesn't bleed across whole tiles
        vec2 offset = (uv - 0.5) * chromatic_aberration_strength * 0.5;
        col.r = texture(SCREEN_TEXTURE, uv + offset).r;
        col.g = texture(SCREEN_TEXTURE, uv).g;
        col.b = texture(SCREEN_TEXTURE, uv - offset).b;
    } else {
        col = texture(SCREEN_TEXTURE, uv).rgb;
    }
    
    // Color crush
    float levels = pow(2.0, float(color_bit_depth));
    col = floor(col * levels) / levels;
    
    // Soft vignette
    if(vignette_strength > 0.0){
        float dist = distance(SCREEN_UV, vec2(0.5));
        float vignette = 1.0 - vignette_strength * smoothstep(vignette_radius * 0.5, vignette_radius, dist);
        col *= vignette;
    }
    
    // Fine-grain dither
    if(dither_strength > 0.0){
        // Multiplied by 4.0 to make the noise pattern tiny and tight
        float noise = hash(SCREEN_UV * 320.0 + floor(TIME * 15.0)); 
        col += (noise - 0.5) * dither_strength;
    }
    
    COLOR = vec4(col, 1.0);
}