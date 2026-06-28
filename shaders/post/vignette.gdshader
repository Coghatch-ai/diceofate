shader_type canvas_item;

// Vignette intensity: 0.0 = no effect, 1.0 = max darkening at edges.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// Inner radius (fraction of screen from center): edge darkening starts here.
uniform float inner_radius : hint_range(0.0, 1.0) = 0.35;
// Outer radius: full darkening at this distance from center.
uniform float outer_radius : hint_range(0.0, 1.4) = 0.85;
// Max darkness fraction at the extreme edge (comfort: never full black).
uniform float max_darkness : hint_range(0.0, 0.8) = 0.55;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	// Aspect-correct distance from center.
	float dist = length(uv * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0) * 2.0);
	float vignette = smoothstep(inner_radius, outer_radius, dist);
	float darkness = vignette * intensity * max_darkness;
	// Output: black with alpha = darkness. ColorRect must be Color(0,0,0,0).
	// Canvas blends this over the 3D scene (normal blend mode).
	COLOR = vec4(0.0, 0.0, 0.0, darkness);
}
