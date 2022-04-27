shader_type spatial;

render_mode cull_disabled, depth_draw_always, specular_disabled;

uniform vec4 baseColor : hint_color = vec4(1.0);
uniform vec4 baseLight : hint_color = vec4(0.0);
uniform float lightFraction = 1.0;

void fragment() {
	ALBEDO = baseColor.rgb;
// Writing to ALPHA makes this 
//	ALPHA = baseColor.a;
}

void light() {
	if (DIFFUSE_LIGHT == vec3(0.0)) {
		// This is kind of hack to initialize DIFFUSE_LIGHT.
		// Not sure if initial value for DIFFUSE_LIGHT can be relied being full of zeroes.
		// Seems to work, though.
		DIFFUSE_LIGHT = baseLight.rgb;
	}
	
//    DIFFUSE_LIGHT += LIGHT_COLOR * clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * ALBEDO * lightFraction;
    DIFFUSE_LIGHT += LIGHT_COLOR * clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * ALBEDO * lightFraction;
//	SPECULAR_LIGHT = vec3(0.0);
	
// This barn aint no specular
//    vec3 H = normalize(VIEW + LIGHT);
//    float NdotH = max(0, dot(NORMAL, H));
//    float specular = pow(NdotH, specular_power) * specular_strength * ATTENUATION;
//    SPECULAR_LIGHT += specular * LIGHT_COLOR * lightFraction;
}




