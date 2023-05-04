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

uniform int antiAlias = 8;

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
	// There's unused area around the "payload" to make AA work better
	// Discard fragments there right away.
	if (abs(UV.y - 0.5) * 2.0 > soundAmplificationA + abs(soundAmplificationB) + lineFadeOutHigh)
	{
		discard;
	}

	int sampleIndexA = int(soundPosA + UV.x * soundLengthA) + soundOffsetA;	// + int(TIME * 8000.0);
	int sampleIndexB = int(soundPosB + UV.x * soundLengthB) + soundOffsetB;	// + int(TIME * 8000.0);
		
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

	// This "Slope"-thing is just a really dirty hack to try to prevent
	// disconnected points on sharp changes on EKG
//	float slopeA = abs((nextSampleValA - prevSampleValA) * dFdx(UV.x) * soundAmplificationA);
	float slopeB = abs((nextSampleValB - prevSampleValB) * dFdx(UV.x) * soundAmplificationB);
	float totalSlope = max(1.0, (slopeB) * 200000000.0);

	// Do simplified antialiasing only on "one axis"
	float derivYWidth = sqrt(dFdx(UV.y) * dFdx(UV.y) + dFdy(UV.y) * dFdy(UV.y)) * 0.5;

	// There is only one DeathRay so maybe not worth optimizing AA too much(?)
	vec3 albedoSum = vec3(0.0);
	float alphaSum = 0.0;
	for (int i = 0; i < antiAlias; i++)
	{
		float dist = abs(sampleValA + sampleValB - 0.5 - ((UV.y - derivYWidth) + (float(i) / float(antiAlias)) * derivYWidth * 2.0)) * 2.0;
		dist /= totalSlope;
		
	//	ALBEDO = innerAlbedo.rgb;
		albedoSum += innerAlbedo.rgb + (outerAlbedo.rgb - innerAlbedo.rgb) * smoothstep(totalWidth * innerLineWidthLow, totalWidth * innerLineWidthHigh, dist);
		alphaSum += innerAlbedo.a * (1.0 - smoothstep(totalWidth * lineFadeOutLow, totalWidth * lineFadeOutHigh, dist));
	}
	
	ALBEDO = (1.0 / float(antiAlias)) * albedoSum;
	ALPHA = alphaSum / float(antiAlias);
}
