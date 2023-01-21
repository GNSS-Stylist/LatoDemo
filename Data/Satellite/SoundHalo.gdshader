// NOTE: Shader automatically converted from Godot Engine 4.0.alpha's StandardMaterial3D.

shader_type spatial;
render_mode blend_add,cull_disabled,unshaded;
uniform vec4 baseAlbedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float centerHoleRadius = 0.0;
uniform int numOfSamples = 1542747;	// Hoffman - Intrinsic.raw
uniform float soundPos = 0.0;
uniform float soundOffset = 0.0;
uniform float soundLength = 8000.0;
uniform float soundPreCut = 0.0;		// Don't draw samples before this time
uniform float soundPostCut = 1e9;	// Don't draw samples after this time
uniform float soundAmplification = 1.0;
uniform sampler2D soundDataSampler : hint_default_black;

void vertex() {
// This (moving the halo farther away to get the satellite itself not distracted by it)
// is now handled in gd's process-function. I just couldn't get it working here...
// The "solution" below worked when satellite was at the world origin, though.
//	VERTEX += 10.0 * normalize(VIEW_MATRIX[3].xyz);

	// Billboarding:
	// (Also done in gdscript-side now)
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
	
	float sampleIndex =  soundPos + soundOffset + distanceFromEventHorizon * soundLength;

	if ((distanceFromCenterPoint < centerHoleRadius) || (distanceFromCenterPoint >= 1.0) ||
			(sampleIndex < soundPreCut) || (sampleIndex > soundPostCut)) {
		discard;
	}
	else {
//		ALBEDO = textureLod(SCREEN_TEXTURE, SCREEN_UV + clamp(soundAmplification * (1.0 - distanceFromEventHorizon) * (1.0 - distanceFromEventHorizon) * getSampleValue(int(sampleIndex)), 0.0, 1.0) * vec2(0.03, 0.03), 0.0).rgb;
		
		ALPHA = baseAlbedo.a * clamp(soundAmplification * (1.0 - distanceFromEventHorizon) * (1.0 - distanceFromEventHorizon) * getSampleValue(int(sampleIndex)), 0.0, 1.0);
//		ALPHA = distanceFromEventHorizon;
//		ALPHA = distanceFromCenterPoint;

	}
	
	
	
	
}
