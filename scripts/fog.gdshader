shader_type canvas_item;

uniform vec2 unit_positions[1024];
uniform float unit_ranges[1024];
uniform int array_length = 0;



uniform mat4 global_transform;
varying vec2 world_position;


void vertex(){
	world_position = (global_transform * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment(){

	bool skip = false;
	vec2 zero = vec2(0,0);
	for(int i = 0; i < array_length && !skip; i += 1){
		if(distance(world_position, unit_positions[i]) <= unit_ranges[i]){
			discard;
		}
	}
	if(skip){
		discard;
	}
}