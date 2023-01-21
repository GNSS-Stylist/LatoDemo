shader_type spatial;

render_mode blend_mix,cull_disabled,unshaded,world_vertex_coords, depth_draw_opaque;

// isampler's values seem to be corrupted somehow, so use floats...
uniform sampler2D soundDataSampler : hint_default_black;
uniform float lineWidthLow = 0.025;		// Smoothstep low value
uniform float lineWidthHigh = 0.075;	// Smoothstep high value
uniform float scopeHeight = 1;

// I just coulnd't find a way to modify value of global uniform.
// So now they need to be set separately for every instance.
//global uniform int soundPos = 0;
uniform float soundPos = 0.0;
uniform float soundOffset = 0;			// Offset to soundPos
uniform float soundAmplification = 0.9;	// Should be <= 1 - lineWidthHigh / 2.0 to avoid clipping
uniform float soundLength = 4096.0;			// Length (time) of the scope in samples
uniform float soundPreCut = 0.0;		// Don't draw samples before this time (not even as zero valued)
uniform float soundPostCut = 1e9;	// Don't draw samples after this time (not even as zero valued)

uniform vec3 startOrigin_Object = vec3(0.0, 0.0, 0.0);
uniform vec3 endOrigin_Object = vec3(1.0, 0.0, 0.0);

uniform int numOfSamples = 1542747;	// Hoffman - Intrinsic.raw
uniform vec4 baseAlbedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float startNarrowing_Level = 0.1;
uniform float startNarrowing_Start = 0.0;
uniform float startNarrowing_End = 0.01;

uniform float endNarrowing_Level = 0.1;
uniform float endNarrowing_Start = 0.99;
uniform float endNarrowing_End = 1.0;

void vertex() {
	vec3 startOrigin = (MODEL_MATRIX * vec4(startOrigin_Object, 1.0)).xyz;
	vec3 endOrigin = (MODEL_MATRIX * vec4(endOrigin_Object, 1.0)).xyz;
	
	vec3 fromStartOriginToEndOrigin = endOrigin - startOrigin;
	vec3 fromStartOriginToCamera = INV_VIEW_MATRIX[3].xyz - startOrigin;
	
	// TODO: zero from cross-product not handled (very unlikely to happen though)
	// rightAngleVec becomes 0.5 m length here so it is possible to set scope height in m
	vec3 rightAngleVec = 0.5 * normalize(cross(fromStartOriginToEndOrigin, fromStartOriginToCamera));
	
	vec3 centerPoint = mix(startOrigin, endOrigin, UV.x);
	
	VERTEX = centerPoint + scopeHeight * (UV.y - 0.5) * rightAngleVec;
}

ivec2 getTexelCoord(int sampleIndex) {
	return ivec2(sampleIndex % 4096, sampleIndex / 4096);
}

float getSampleValue(int sampleIndex) {
//	return texelFetch(soundDataSampler, getTexelCoord(sampleIndex), 0).r;
	float retVal;
	if ((sampleIndex >= 0) && (sampleIndex < numOfSamples)) {
		retVal = texelFetch(soundDataSampler, getTexelCoord(sampleIndex), 0).r;
	}
	else
	{
		retVal = 0.5;
	}
	
//	retVal = float(sampleIndex % 255) / 255.0;
	return retVal;
}

void fragment() {
//	COLOR = vec4(SCREEN_UV.x, SCREEN_UV.y, sin(TIME) * 0.5 + 0.5, 0.5);
	
//	COLOR = vec4(SCREEN_UV.x, SCREEN_UV.y, sin(TIME) * 0.5 + 0.5, (SCREEN_UV.x + SCREEN_UV.y) / 2.0);
//	COLOR = vec4(SCREEN_UV.x, SCREEN_UV.y, sin(TIME) * 0.5 + 0.5, sin(SCREEN_UV.x * 6.28 * 10.0) * 0.5 + 0.5);
//	COLOR = vec4(clamp(UV.x, 0.0, 1.0), clamp(UV.y, 0.0, 1.0), clamp(sin(TIME) * 0.5 + 0.5, 0.0, 1.0), clamp(sin(UV.x * 6.28 * 10.0) * 0.5 + 0.5, 0.0, 1.0));
//	COLOR = vec4(SCREEN_UV.x, SCREEN_UV.y, sin(TIME) * 0.5 + 0.5, 1.0);
//	COLOR = vec4(sin(TIME*2.0), sin(TIME*3.2), sin(TIME) * 0.5 + 0.5, 1.0);
//	vec2 myUV = UV * TEXTURE_PIXEL_SIZE;
//	COLOR = vec4(myUV.x, myUV.y, sin(TIME) * 0.5 + 0.5, 1.0);

//	uint pix = texture(soundDataSampler, UV);
//	vec4 floatPix = vec4(float(pix.r) / 65536.0 + 0.5, float(pix.g) / (65536.0 * 65536.0) + 0.5, float(pix.b) / 256.0 + 0.5, 1.0);
//	vec4 floatPix = vec4(float(pix.r >> 24) / 256.0 + 0.5, float(pix.g >> 16) / 65536.0 + 0.5, float(pix.b >> 24) / 256.0 + 0.5, 1.0);

//	COLOR = vec4(sin(TIME*2.0), sin(TIME*3.2), sin(TIME) * 0.5 + 0.5, 1.0);
//	COLOR = texture(soundDataSampler, UV);
//	COLOR.a = 1.0;

	ALBEDO = baseAlbedo.rgb;
	
	float sampleIndex =  soundPos + soundOffset + UV.x * soundLength;	// + int(TIME * 8000.0);
		
	if ((sampleIndex < soundPreCut) || (sampleIndex > soundPostCut)) {
//	if (true) {
//		ALPHA = 0.1;
		discard;
	}
	else {
		float prevSampleVal = getSampleValue(int(sampleIndex));
		float nextSampleVal = getSampleValue(int(sampleIndex) + 1);

		float sampleVal = 0.5 + soundAmplification * 
				(startNarrowing_Level + (1.0 - startNarrowing_Level) * smoothstep(startNarrowing_Start, startNarrowing_End, UV.x * 1000.0)) *
				(endNarrowing_Level + (1.0 - endNarrowing_Level) * (1.0 - smoothstep(endNarrowing_Start, endNarrowing_End, UV.x * 100.0))) *
				(mix(prevSampleVal, nextSampleVal, fract(sampleIndex)) - 0.5);
		
		ALPHA = baseAlbedo.a * (1.0 - smoothstep(lineWidthLow, lineWidthHigh, abs(sampleVal - UV.y) * 2.0));
	}
}









