shader_type canvas_item;

uniform vec2 unit_positions[1024];
uniform float unit_visual_ranges[1024];
uniform float unit_radar_ranges[1024];
uniform float unit_arc_direction[1024];
uniform float unit_arc_size[1024];
uniform float unit_radar_brightness[1024];
uniform int array_length = 0;


uniform mat4 global_transform;
varying vec2 world_position;


void vertex(){
	world_position = (global_transform * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment(){
	bool skip = false;
	vec2 zero = vec2(0,0);
	COLOR = vec4(0.8, 0.8, 0.8, 0.0);
	for(int i = 0; i < array_length && !skip; i += 1){
		vec2 direction = (world_position - unit_positions[i]);
		float dist = length(direction);
		if(dist <= unit_visual_ranges[i]){
			COLOR.a = 1.0;
		}
		else if(dist <= unit_radar_ranges[i]){
			// atan2(y, x) is equivalent to angle() 
			// based on https://docs.godotengine.org/en/latest/classes/class_vector2.html
			float angle = atan(direction.x, direction.y);
			if(abs(angle - unit_arc_direction[i]) <= unit_arc_size[i]){
				COLOR.a = unit_radar_brightness[i];
			}
		}
	}
	if(skip){
		discard;
	}
}