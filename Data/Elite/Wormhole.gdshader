// NOTE: Shader automatically converted from Godot Engine 4.0.alpha's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,cull_disabled,unshaded;
uniform vec4 baseAlbedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float centerHoleRadius = 0.0;
uniform int numOfSamples = 1542747;	// Hoffman - Intrinsic.raw
uniform float soundPos = 0.0;
uniform float soundOffset = 0.0;
uniform float soundLength = 8000.0;
uniform float soundPreCutStart = 0.0;	// Don't draw samples before this time
uniform float soundPreCutEnd = 0.0;		// Don't draw samples before this time
uniform float soundPostCut = 1e9;	// Don't draw samples after this time (after: ALPHA = 1.0)
uniform float soundAmplification = 1.0;
uniform sampler2D soundDataSampler : hint_default_black;
uniform float baseAlpha = 0.0;

void vertex() {
	// Billboarding:
	//MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}


ivec2 getTexelCoord(int sampleIndex) {
	return ivec2(sampleIndex % 4096, sampleIndex / 4096);
}

float getSampleValue(int sampleIndex) {
//	return texelFetch(soundDataSampler, getTexelCoord(sampleIndex), 0).r;
	float retVal = 0.5;
	if ((sampleIndex >= 0) && (sampleIndex < numOfSamples)) {
		retVal = texelFetch(soundDataSampler, getTexelCoord(sampleIndex), 0).r;
	}
	return retVal;
}

void fragment() {
	ALBEDO = baseAlbedo.rgb;
	float distanceFromCenterPoint = 2.0 * distance(UV, vec2(0.5, 0.5));
	
	float distanceFromEventHorizon = (distanceFromCenterPoint - centerHoleRadius) * (1.0 / (1.0 - centerHoleRadius));
	
	float sampleIndex =  soundPos + soundOffset + sqrt(distanceFromEventHorizon) * soundLength;

	if ((distanceFromCenterPoint < centerHoleRadius) || (distanceFromCenterPoint >= 1.0) ||
			(sampleIndex < soundPreCutStart) || (sampleIndex > soundPostCut)) {
		ALPHA = 0.0;
//		ALPHA = 0.5;
//		ALBEDO = vec3(1.0, 0.0, 0.0);
	}
	else {
//		ALBEDO = textureLod(SCREEN_TEXTURE, SCREEN_UV + clamp(soundAmplification * (1.0 - distanceFromEventHorizon) * (1.0 - distanceFromEventHorizon) * getSampleValue(int(sampleIndex)), 0.0, 1.0) * vec2(0.03, 0.03), 0.0).rgb;
		ALPHA = baseAlpha;
		ALPHA += (1.0 - baseAlpha) * baseAlbedo.a * clamp(soundAmplification * (1.0 - distanceFromEventHorizon) * 
		(1.0 - distanceFromEventHorizon) * getSampleValue(int(sampleIndex)), 0.0, 1.0) *
		smoothstep(sampleIndex, soundPreCutStart, soundPreCutEnd);
//		ALPHA = distanceFromEventHorizon;
//		ALPHA = distanceFromCenterPoint;

	}
	
//	ALPHA = 1.0;
	
	
	
	
}
