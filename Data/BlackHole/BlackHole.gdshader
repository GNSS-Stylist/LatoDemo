shader_type spatial;
render_mode blend_mix,cull_disabled,unshaded;
uniform float eventHorizonRadius = 0.5;
uniform float gravity = 500.0;
//uniform float radius = 0.5;

//varying float gravityScale;

void vertex() {
//	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(radius * 2.0 * INV_VIEW_MATRIX[0], radius * 2.0 * INV_VIEW_MATRIX[1], radius * 2.0 * INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
//	VERTEX = (VIEW_MATRIX * vec4(UV.x * radius, UV.y * radius, 0.0, 1.0)).xyz;

	// Shortcut for billboarding (because too stupid to make it right):
	VERTEX = (mat3(INV_VIEW_MATRIX) * VERTEX);
	
//	float quadDistance = abs(length(INV_VIEW_MATRIX[3].xyz));
//	gravityScale = 1.0 / quadDistance;
}

void fragment() {
	float distanceFromCenterPoint = 2.0 * distance(UV, vec2(0.5, 0.5));
	
	float distanceFromEventHorizon = (distanceFromCenterPoint - eventHorizonRadius) * (1.0 / (1.0 - eventHorizonRadius));
	
	if (distanceFromCenterPoint >= 1.0) {
//		ALBEDO = vec3(1.0, 0.0, 0.0);
//		ALPHA = 0.5;
		discard;
	}
	else if (distanceFromCenterPoint < eventHorizonRadius) {
		ALBEDO = vec3(0.0);
		ALPHA = 1.0;
	}
	else {
		ALPHA = 1.0;
		
//		vec2 pixelGravity = pow(1.0 - distanceFromEventHorizon, 2.0) * gravity * (UV - vec2(0.5, 0.5));
		vec2 pixelGravity = pow(1.0 - sin((distanceFromEventHorizon) * (PI * 0.5)), 2.0) * gravity * normalize((UV - vec2(0.5, 0.5)));
		
		vec2 screenDisplacement = pixelGravity * (dFdx(SCREEN_UV) + dFdy(SCREEN_UV));
		
		ALBEDO = textureLod(SCREEN_TEXTURE, 
//				SCREEN_UV - pow(1.0 - distanceFromEventHorizon, 2.0) * gravity * (UV - vec2(0.5, 0.5)), 
				SCREEN_UV - screenDisplacement, 
				0.0).rgb;

//		ALBEDO.g = distanceFromEventHorizon;


//		ALBEDO = vec3(0.5);
//		ALBEDO = textureLod(SCREEN_TEXTURE, SCREEN_UV + clamp(soundAmplification * (1.0 - distanceFromEventHorizon) * (1.0 - distanceFromEventHorizon) * getSampleValue(int(sampleIndex)), 0.0, 1.0) * vec2(0.03, 0.03), 0.0).rgb;
		
		
		
		
//		ALPHA = clamp(soundAmplification * (1.0 - distanceFromEventHorizon) * (1.0 - distanceFromEventHorizon) * getSampleValue(int(sampleIndex)), 0.0, 1.0);
//		ALPHA = distanceFromEventHorizon;
//		ALPHA = distanceFromCenterPoint;

	}
	
	
	
	
}
