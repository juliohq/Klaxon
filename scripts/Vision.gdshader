shader_type canvas_item;

uniform bool see_all = true;

uniform vec2 positions[1024];
uniform float radars[1024]; // range = this/radar_falloff
uniform float visuals[1024]; // range = this
uniform int array_length = 0;

uniform float radar_falloff = 0;


uniform float visual_brightness = 0.5;  
uniform float best_radar_brightness = 0.4; // must be lower than the above
uniform float no_detection_brightness = 0.3; // must be lower than the above




uniform mat4 global_transform;
varying vec2 world_position;


void vertex(){
	world_position = (global_transform * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment(){
	float brightest = no_detection_brightness;
	if(see_all){
		brightest = visual_brightness;
	}else{
		vec2 zero = vec2(0,0);
		for(int i = 0; i < array_length && brightest != visual_brightness; i += 1){
			float dist = distance(world_position, positions[i]);
			if(dist <= visuals[i]){
				brightest = visual_brightness;
			}else{
				float strength = clamp((radars[i] - (dist * radar_falloff)), 0.0, 1.0);
				brightest = min(brightest, mix(no_detection_brightness, best_radar_brightness, strength));
			}
		}
	}
	COLOR.rgb = vec3(brightest, brightest, brightest);
}