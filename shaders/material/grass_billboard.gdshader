shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// blade_texture is optional for Slice 1; set to a 1x1 white pixel when no art asset exists.
uniform sampler2D blade_texture : source_color, filter_nearest;
uniform vec4 blade_color : source_color = vec4(0.25, 0.55, 0.2, 1.0);
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
uniform bool use_texture = false;

uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
uniform float wind_strength : hint_range(0.0, 0.5) = 0.08;
uniform vec2 wind_direction = vec2(1.0, 0.0); // world XZ
uniform float animation_fps : hint_range(1.0, 24.0) = 8.0; // target framerate for time quantization

float noise2d(vec2 p) {
	// Cheap 2D value noise — enough for wind, no texture dependency
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep
	return mix(
		mix(noise2d(i), noise2d(i + vec2(1.0, 0.0)), f.x),
		mix(noise2d(i + vec2(0.0, 1.0)), noise2d(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	// Billboard: rotate the quad to face the camera using its BASIS, not look_at.
	// Orthographic cameras have no vanishing point — look_at would tilt blades as
	// the camera moves. Using the camera basis keeps every blade perfectly upright.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);

	// Fake-perspective UV: under orthographic, tall objects don't appear to recede.
	// Scale the UV horizontally at the top of the blade so it looks like it angles
	// away — gives depth without perspective projection.
	// UV.y == 0 is the top of the quad (Godot QuadMesh default).
	float perspective_scale = 1.0 - UV.y * 0.15;
	UV.x = (UV.x - 0.5) * perspective_scale + 0.5;
	UV.x = clamp(UV.x, 0.0, 1.0);

	// Wind: only the top of the blade sways (UV.y == 0 is top in QuadMesh default)
	float sway_mask = 1.0 - UV.y; // 1 at top, 0 at pivot

	// Per-instance phase: offset by world-space XZ position so blades are out of sync
	vec2 world_xz = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;
	float phase = fract(world_xz.x * 0.37 + world_xz.y * 0.59); // deterministic, no rand()

	// Quantize TIME to discrete steps — the "handdrawn" snap
	float frame_time = 1.0 / animation_fps;
	float quantized_time = floor(TIME / frame_time) * frame_time;
	float snap_phase = fract(world_xz.x * 0.17 + world_xz.y * 0.31) * frame_time;
	float t = (quantized_time + snap_phase) * wind_speed + phase;

	// Two noise samples at diverging angles — one scaled by π to kill repetition
	vec2 dir1 = wind_direction;
	vec2 dir2 = vec2(-wind_direction.y, wind_direction.x) * 3.14159; // perpendicular × π
	float n1 = smooth_noise(world_xz * 0.3 + dir1 * t);
	float n2 = smooth_noise(world_xz * 0.3 + dir2 * t * 0.7);
	float wind = (n1 * 0.7 + n2 * 0.3) * 2.0 - 1.0; // remap to [-1, 1]

	// Rotate the sway around the wind-perpendicular axis for stable direction
	vec3 perp = vec3(-wind_direction.y, 0.0, wind_direction.x);
	VERTEX += perp * wind * wind_strength * sway_mask;
}

void fragment() {
	vec4 col;
	if (use_texture) {
		col = texture(blade_texture, UV);
	} else {
		// Procedural blade silhouette: taper from wide at base (UV.y=1) to a point at tip (UV.y=0).
		// half_width drives the alpha cutout: 5% wide at tip, 45% at base.
		float half_width = mix(0.05, 0.45, UV.y);
		float alpha = step(abs(UV.x - 0.5), half_width);
		col = vec4(blade_color.rgb, blade_color.a * alpha);
	}
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ALPHA = col.a;
	ALBEDO = col.rgb;
}
