shader_type canvas_item;

uniform bool see_all = false;

uniform vec2 positions[1024];
uniform float radars[1024]; // range = this/radar_falloff
uniform float visuals[1024]; // range = this
uniform int array_length = 0;

uniform float radar_falloff = 0;


uniform float visual_brightness = 0.65;  
uniform float brightest_radar = 0.6; // must be lower than the above
uniform float darkest_radar = 0.4;  // must be lower than the above
uniform float no_detection_brightness = 0.35; // must be lower than the above




uniform mat4 global_transform;
varying vec2 world_position;


void vertex(){
	world_position = (global_transform * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment(){
	float strength = 0.0; // > 1.0 is visual, <=  0.0 is no_detection, else mix between darkest_radar and brightest_radar
	if(see_all){
		strength = 42.0;
	}else{
		vec2 zero = vec2(0,0);
		for(int i = 0; i < array_length && (strength < 1.0); i += 1){
			float dist = distance(world_position, positions[i]);
			if(dist <= visuals[i]){
				strength = 42.0;
			}else{
				float to_strength = clamp((radars[i] - (dist * radar_falloff)), 0.0, 1.0);
				if(to_strength > 0.0){
					strength = max(strength, to_strength);
				}
			}
		}
	}
	if(strength > 1.0){
		COLOR.rgb = vec3(visual_brightness + 0.05, visual_brightness + 0.05, visual_brightness);
	}else if(strength <= 0.0){
		COLOR.rgb = vec3(no_detection_brightness, no_detection_brightness, no_detection_brightness);
	}else{
		float brightness = mix(darkest_radar, brightest_radar, strength);
		if(strength >= 1.0){
			COLOR.rgb = vec3(brightness + 0.06, brightness + 0.06, brightness +0.01);
		}else{
			COLOR.rgb = vec3(brightness, brightness, brightness);
		}
	}
	
}