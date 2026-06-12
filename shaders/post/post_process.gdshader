shader_type spatial;
render_mode unshaded, fog_disabled;

// Screen-space texture uniforms (skill: godot-screen-textures)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

// Outline thresholds
uniform float depth_threshold : hint_range(0.0, 2.0) = 0.5;
uniform float normal_threshold : hint_range(0.0, 1.0) = 0.4;

// Linear view-space depth at a given UV (Forward+, Godot 4.3+ reversed-Z)
float get_linear_depth(vec2 uv, mat4 inv_projection_matrix) {
	float depth = texture(depth_texture, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

// View-space normal at a given UV, decoded from 0..1 to -1..1
vec3 get_normal(vec2 uv) {
	return texture(normal_texture, uv).xyz * 2.0 - 1.0;
}

void vertex() {
	// Snap the quad to the full screen at the near plane (reversed-Z, Godot 4.3+)
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel_size = 1.0 / vec2(textureSize(depth_texture, 0));

	// Center depth and normal
	float depth_center = get_linear_depth(uv, INV_PROJECTION_MATRIX);
	vec3 normal_center = get_normal(uv);

	// 4-tap cross kernel samples
	float depth_up = get_linear_depth(uv + vec2(0.0, texel_size.y), INV_PROJECTION_MATRIX);
	float depth_down = get_linear_depth(uv + vec2(0.0, -texel_size.y), INV_PROJECTION_MATRIX);
	float depth_left = get_linear_depth(uv + vec2(-texel_size.x, 0.0), INV_PROJECTION_MATRIX);
	float depth_right = get_linear_depth(uv + vec2(texel_size.x, 0.0), INV_PROJECTION_MATRIX);

	vec3 normal_up = get_normal(uv + vec2(0.0, texel_size.y));
	vec3 normal_down = get_normal(uv + vec2(0.0, -texel_size.y));
	vec3 normal_left = get_normal(uv + vec2(-texel_size.x, 0.0));
	vec3 normal_right = get_normal(uv + vec2(texel_size.x, 0.0));

	// Compute depth delta (maximum absolute difference from center)
	float depth_delta = max(
		max(abs(depth_center - depth_up), abs(depth_center - depth_down)),
		max(abs(depth_center - depth_left), abs(depth_center - depth_right))
	);

	// Compute normal discontinuity (minimum dot product = largest angle difference)
	float normal_diff = min(
		min(dot(normal_center, normal_up), dot(normal_center, normal_down)),
		min(dot(normal_center, normal_left), dot(normal_center, normal_right))
	);

	// Edge detection: black outline where depth delta or normal discontinuity exceeds threshold
	bool is_depth_edge = depth_delta > depth_threshold;
	bool is_normal_edge = normal_diff < normal_threshold;

	if (is_depth_edge || is_normal_edge) {
		ALBEDO = vec3(0.0, 0.0, 0.0); // Black outline
	} else {
		// Pass through original screen color
		ALBEDO = texture(screen_texture, uv).rgb;
	}
}
