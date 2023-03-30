shader_type spatial;

render_mode blend_mix,cull_disabled,unshaded,world_vertex_coords, depth_draw_opaque;

// isampler's values seem to be corrupted somehow, so use floats...
uniform sampler2D soundDataSamplerA : hint_default_black;
uniform int numOfSamplesA = 1542747;	// Hoffman - Intrinsic.raw
uniform float soundAmplificationA = 0.9;	// This + soundAmplificationB should be <= 1 - lineWidthHigh / 2.0 to avoid clipping
uniform float soundPosA = 0.0;
uniform int soundOffsetA = 0;			// Offset to soundPos
uniform float soundLengthA = 4096.0;			// Length (time) of the scope in samples
//uniform float soundPreCutA = 0.0;		// Don't draw samples before this time (not even as zero valued)
//uniform float soundPostCutA = 1e9;	// Don't draw samples after this time (not even as zero valued)

uniform sampler2D soundDataSamplerB : hint_default_black;
uniform int numOfSamplesB = 1542747;	// Hoffman - Intrinsic.raw
uniform float soundAmplificationB = 0.9;	// This + soundAmplificationA should be <= 1 - lineWidthHigh / 2.0 to avoid clipping
uniform float soundPosB = 0.0;
uniform int soundOffsetB = 0;			// Offset to soundPos
uniform float soundLengthB = 4096.0;			// Length (time) of the scope in samples
//uniform float soundPreCutB = 0.0;		// Don't draw samples before this time (not even as zero valued)
//uniform float soundPostCutB = 1e9;	// Don't draw samples after this time (not even as zero valued)


uniform float innerLineWidthLow = 0.025;		// Smoothstep low value
uniform float innerLineWidthHigh = 0.075;	// Smoothstep high value
uniform float lineFadeOutLow = 0.1;
uniform float lineFadeOutHigh = 0.15;
uniform float scopeHeight = 1;


uniform vec3 startOrigin_Object = vec3(0.0, 0.0, 0.0);
uniform vec3 endOrigin_Object = vec3(1.0, 0.0, 0.0);

uniform vec4 innerAlbedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 outerAlbedo : source_color = vec4(0.0, 0.0, 0.0, 1.0);

uniform float startNarrowing_Level = 0.1;
uniform float startNarrowing_Start = 0.0;
uniform float startNarrowing_End = 0.01;

uniform float endNarrowing_Level = 0.1;
uniform float endNarrowing_Start = 0.99;
uniform float endNarrowing_End = 1.0;

uniform bool skipBillboarding = false;

void vertex() {
	if (!skipBillboarding) {
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
}

ivec2 getTexelCoord(int sampleIndex) {
	return ivec2(sampleIndex % 4096, sampleIndex / 4096);
}

float getSampleValueA(int sampleIndex) {
//	return texelFetch(soundDataSampler, getTexelCoord(sampleIndex), 0).r;
	float retVal;
	if ((sampleIndex >= 0) && (sampleIndex < numOfSamplesA)) {
		retVal = texelFetch(soundDataSamplerA, getTexelCoord(sampleIndex), 0).r;
	}
	else
	{
		retVal = 0.5;
	}
	
//	retVal = float(sampleIndex % 255) / 255.0;
	return retVal;
}

float getSampleValueB(int sampleIndex) {
//	return texelFetch(soundDataSampler, getTexelCoord(sampleIndex), 0).r;
	float retVal;
	if ((sampleIndex >= 0) && (sampleIndex < numOfSamplesB)) {
		retVal = texelFetch(soundDataSamplerB, getTexelCoord(sampleIndex), 0).r;
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

	int sampleIndexA = int(soundPosA + UV.x * soundLengthA) + soundOffsetA;	// + int(TIME * 8000.0);
	int sampleIndexB = int(soundPosB + UV.x * soundLengthB) + soundOffsetB;	// + int(TIME * 8000.0);
		
//	if ((sampleIndex < soundPreCutA) || (sampleIndex > soundPostCutA)) {
//	if (true) {
//		ALPHA = 0.1;
//		discard;
//	}
//	else {
	float prevSampleValA = getSampleValueA(sampleIndexA);
	float nextSampleValA = getSampleValueA(sampleIndexA + 1);
	
	float prevSampleValB = getSampleValueB(sampleIndexB);
	float nextSampleValB = getSampleValueB(sampleIndexB + 1);

	float totalWidth =
			(startNarrowing_Level + (1.0 - startNarrowing_Level) * smoothstep(startNarrowing_Start, startNarrowing_End, UV.x * 1000.0)) *
			(endNarrowing_Level + (1.0 - endNarrowing_Level) * (1.0 - smoothstep(endNarrowing_Start, endNarrowing_End, UV.x * 100.0)));

	float sampleValA = 0.5 + soundAmplificationA * totalWidth *
			(mix(prevSampleValA, nextSampleValA, fract(soundPosA + UV.x * soundLengthA)) - 0.5);
	
	float sampleValB = 0.5 + soundAmplificationB * totalWidth *
			(mix(prevSampleValB, nextSampleValB, fract(soundPosB + UV.x * soundLengthB)) - 0.5);

//	sampleVal = 0.5;
	
	float dist = abs(sampleValA + sampleValB - 0.5 - UV.y) * 2.0;
	
//	ALBEDO = innerAlbedo.rgb;
	ALBEDO = innerAlbedo.rgb + (outerAlbedo.rgb - innerAlbedo.rgb) * smoothstep(totalWidth * innerLineWidthLow, totalWidth * innerLineWidthHigh, dist);
	ALPHA = innerAlbedo.a * (1.0 - smoothstep(totalWidth * lineFadeOutLow, totalWidth * lineFadeOutHigh, dist));

//	ALBEDO = innerAlbedo.rgb + (outerAlbedo.rgb - innerAlbedo.rgb) * smoothstep(innerLineWidthLow, innerLineWidthHigh, dist);
//	ALPHA = innerAlbedo.a * (1.0 - smoothstep(lineFadeOutLow, lineFadeOutHigh, dist));

//	}
}









