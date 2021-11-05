shader_type canvas_item;

uniform mat4 global_transform;
uniform vec2 unit_positions[1024];
uniform float unit_ranges[1024];
uniform int array_length = 0;
varying vec2 world_position;

void vertex(){
	world_position = (global_transform * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment(){
	bool skip = false;
	for(int i = 0; i < array_length; i += 1){
		if((unit_positions[i] != vec2(0,0)) && (length(world_position - unit_positions[i]) <= unit_ranges[i])){
			skip = true;
		}
	}
	if(skip){
		discard;
	}
}