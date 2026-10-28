shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = SCREEN_PIXEL_SIZE;
	vec3 color;
	color.r = texture(screen_texture, uv + vec2(texel.x * 0.38, 0.0)).r;
	color.g = texture(screen_texture, uv).g;
	color.b = texture(screen_texture, uv - vec2(texel.x * 0.38, 0.0)).b;
	float scan = 0.965 + 0.035 * cos(uv.y / texel.y * 3.14159265);
	float grain = fract(sin(dot(floor(uv / texel) + floor(TIME * 8.0), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	vec2 centered = uv * 2.0 - 1.0;
	float vignette = 1.0 - 0.11 * pow(clamp(dot(centered, centered) * 0.5, 0.0, 1.0), 1.5);
	float refresh = 0.996 + 0.004 * sin(TIME * 43.0);
	COLOR = vec4(color * scan * vignette * refresh + grain * 0.008, 1.0);
}
