shader_type canvas_item;

uniform vec4 masking_color : hint_color;
uniform float masking_range = 0.1;
uniform bool invert = false; // if true, discard where not color instead

void fragment()
{
	vec4 world_pixel = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec3 c = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
	float diff = length(abs(masking_color - world_pixel));
	
	if (!invert ? diff > masking_range : diff <= masking_range)
	{
		discard;
	}
}