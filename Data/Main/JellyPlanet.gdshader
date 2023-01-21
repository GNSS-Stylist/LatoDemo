shader_type spatial;

render_mode depth_draw_opaque;
//render_mode unshaded;
//render_mode cull_disabled, depth_draw_always;

//uniform float replayTime;

uniform float wobbleAmplitude_Min = 0.01;
uniform float wobbleAmplitude_Max = 0.1;
uniform float wobbleFrequency_Min = 0.001;
uniform float wobbleFrequency_Max = 0.01;

uniform vec4 edgeAlbedo_Front : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 centerAlbedo_Front : source_color = vec4(1.0, 1.0, 0.0, 0.1);
uniform float edgeWidth = 0.02;
//uniform vec4 edgeAlbedo_Back : hint_color = vec4(0.5, 0.5, 0.0, 1.0);


// Source of hash- and random-functions:
// https://amindforeverprogramming.blogspot.com/2013/07/random-floats-in-glsl-330.html
// Author: Lee C
uint hash(uint x) {
    x += ( x << uint(10u) );
    x ^= ( x >>  uint(6u) );
    x += ( x <<  uint(3u) );
    x ^= ( x >> uint(11u) );
    x += ( x << uint(15u) );
    return x;
}

float random(float f) {
	const uint mantissaMask = uint(0x007FFFFF);
	const uint one          = uint(0x3F800000);

	uint h = hash( floatBitsToUint( f ) );
	h &= mantissaMask;
	h |= one;

	float  r2 = uintBitsToFloat( h );
	return r2 - 1.0;
}



float calcWobble(float wobbleFraction, float time, float seed)
{
	return (wobbleAmplitude_Min + (random(seed) * 
			(wobbleAmplitude_Max - wobbleAmplitude_Min))) * wobbleFraction *
			sin(random(seed + 2.0) * 6.28 + time * (wobbleFrequency_Min + 
				(random(seed + 1.0) * (wobbleFrequency_Max - wobbleFrequency_Min))));
}

//varying flat float discardFragment;// This is bool...
//varying flat float fragmentTimeDiff;
//varying flat vec4 fragmentAlbedo;
//varying flat float fragmentInitialAlpha;
//varying flat vec4 fragmentEmission;
varying vec3 fragmentDistanceFromEdge;

void vertex()
{
//	float wobbleFraction = 1.0 - smoothstep(0.0, initialWobbleTime, timeDiff);
	const float wobbleFraction = 1.0;
	
//	vec3 wobbleTranslation;
	
//	wobbleTranslation.x = calcWobble(wobbleFraction, replayTime, VERTEX.x);
//	wobbleTranslation.y = calcWobble(wobbleFraction, replayTime, VERTEX.y);
//	wobbleTranslation.z = calcWobble(wobbleFraction, replayTime, VERTEX.z);
	
//	VERTEX += wobbleTranslation;

//	fragmentDistanceFromEdge = CUSTOM3.gba;

	if (VERTEX_ID % 3 == 0)
	{
		fragmentDistanceFromEdge = vec3(1.0, 0.0, 0.0);
	}
	else if (VERTEX_ID % 3 == 1)
	{
		fragmentDistanceFromEdge = vec3(0.0, 1.0, 0.0);
	}
	else
	{
		fragmentDistanceFromEdge = vec3(0.0, 0.0, 1.0);
	}

}

void fragment() {
	float derivUVXWidth = fwidth(fragmentDistanceFromEdge.x);
	float derivUVYWidth = fwidth(fragmentDistanceFromEdge.y);
	float derivUV2YWidth = fwidth(fragmentDistanceFromEdge.z);

//		float derivUVXWidth = sqrt(dFdx(UV.x) * dFdx(UV.x) + dFdy(UV.x) * dFdy(UV.x));
//		float derivUVYWidth = sqrt(dFdx(UV.y) * dFdx(UV.y) + dFdy(UV.y) * dFdy(UV.y));
//		float derivUV2YWidth = sqrt(dFdx(UV2.y) * dFdx(UV2.y) + dFdy(UV2.y) * dFdy(UV2.y));
	
	float integrXLow = fragmentDistanceFromEdge.x - derivUVXWidth * 0.5;
	float integrXHigh = fragmentDistanceFromEdge.x + derivUVXWidth * 0.5;
	
	float integrYLow = fragmentDistanceFromEdge.y - derivUVYWidth * 0.5;
	float integrYHigh = fragmentDistanceFromEdge.y + derivUVYWidth * 0.5;
	
	float integrUV2YLow = fragmentDistanceFromEdge.z - derivUV2YWidth * 0.5;
	float integrUV2YHigh = fragmentDistanceFromEdge.z + derivUV2YWidth * 0.5;

	float edgeAFraction = integrYHigh < edgeWidth ? 1.0 : (min(integrYHigh, edgeWidth) - integrYLow) / derivUVYWidth;
	float edgeBFraction = integrXHigh < edgeWidth ? 1.0 : (min(integrXHigh, edgeWidth) - integrXLow) / derivUVXWidth;
	float edgeCFraction = integrUV2YHigh < edgeWidth ? 1.0 : (min(integrUV2YHigh, edgeWidth) - integrUV2YLow) / derivUV2YWidth;

//		float edgeAFraction = (integrYHigh < edgeWidth && integrYLow >= 0.0) ? 1.0 : clamp((min(integrYHigh, edgeWidth) - integrYLow) / derivUVYWidth, 0.0, 1.0);
//		float edgeBFraction = (integrXHigh < edgeWidth && integrXLow >= 0.0) ? 1.0 : clamp((min(integrXHigh, edgeWidth) - integrXLow) / derivUVXWidth, 0.0, 1.0);
//		float edgeCFraction = (integrUV2YHigh < edgeWidth && integrUV2YLow >= 0.0) ? 1.0 : clamp((min(integrUV2YHigh, edgeWidth) - integrUV2YLow) / derivUV2YWidth, 0.0, 1.0);

	vec4 edgeAlbedo;
	
//	if (FRONT_FACING) {
		edgeAlbedo = edgeAlbedo_Front;
//	}
//	else {
//		edgeAlbedo = edgeAlbedo_Back;
//	}

	float edgeFraction = clamp(max(edgeAFraction, max(edgeBFraction, edgeCFraction)), 0.0, 1.0);

	ALPHA = mix(centerAlbedo_Front.a, edgeAlbedo.a, edgeFraction);
	ALBEDO = mix(centerAlbedo_Front.rgb, edgeAlbedo.rgb, edgeFraction);

//	ALPHA = edgeAlbedo.a * clamp(max(edgeAFraction, max(edgeBFraction, edgeCFraction)), 0.0, 1.0);
//	ALBEDO = edgeAlbedo.rgb;
	
	
//		ALBEDO.r = edgeAFraction;
//		ALBEDO.g = edgeBFraction;
//		ALBEDO.b = edgeCFraction;
		
}