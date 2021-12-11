shader_type canvas_item;

uniform bool see_all = false;

uniform vec2 positions[1024];
uniform float radars[1024]; // range = this/radar_falloff
uniform float visuals[1024]; // range = this
uniform int array_length = 0;

uniform float radar_falloff = 0;


const float visual_a = 0.6;  
const float high_radar_a = 0.5;
const float medium_radar_a = 0.45;
const float low_radar_a = 0.4;
const float no_detection_a = 0.3;




uniform mat4 global_transform;
varying vec2 world_position;


void vertex(){
	world_position = (global_transform * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment(){
	float strength = 0.0;
	bool visual = false;
	if(see_all){
		visual = true;
	}else{
		for(int i = 0; (i < array_length) && (!visual); i += 1){
			float dist = distance(world_position, positions[i]);
			if(dist <= visuals[i]){
				visual = true;
			}else{
				float to_strength = clamp((radars[i] - (dist * radar_falloff)), 0.0, 1.0);
				if(to_strength > 0.0){
					strength = max(strength, to_strength);
				}
			}
		}
	}
	if (visual){
		COLOR.rgb = vec3(visual_a, visual_a, visual_a);
	}else if(strength >= 1.0){
		COLOR.rgb = vec3(high_radar_a, high_radar_a, high_radar_a);
	}else if(strength >= 0.5){
		COLOR.rgb = vec3(medium_radar_a, medium_radar_a, medium_radar_a);
	}else if(strength > 0.0){
		COLOR.rgb = vec3(low_radar_a, low_radar_a, low_radar_a);
	}else{
		COLOR.rgb = vec3(no_detection_a, no_detection_a, no_detection_a);
	}
}