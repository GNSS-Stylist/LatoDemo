shader_type spatial;

//const int maxVertices = 500000;

//render_mode cull_disabled, vertex_lighting;
render_mode cull_disabled, unshaded;

//uniform float shotTimes[4095];

uniform float replayTime;

uniform float outOfSightShift_Y = 10.0;
uniform float disappearanceDelay = 10000.0;

uniform float initialWobbleTime = 5000.0;
uniform float initialWobbleAmplitude_Min = 0.01;
uniform float initialWobbleAmplitude_Max = 0.1;
uniform float initialWobbleFrequency_Min = 0.001;
uniform float initialWobbleFrequency_Max = 0.01;
uniform float wobbleTimeOffset = 0.0;

uniform float initialAlphaFadeInTime = 1000.0;
uniform float alphaFadeOutStartTime = 5000.0;
uniform float alphaFadeOutEndTime = 6000.0;

uniform float initialEmissionFadeInStartTime = 1000.0;
uniform float initialEmissionFadeInEndTime = 2000.0;
uniform float emissionFadeOutStartTime = 5000.0;
uniform float emissionFadeOutEndTime = 6000.0;

uniform float initialColorTime = 1000.0;
uniform float finalColorTime = 5000.0;
uniform vec4 initialColor : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 finalColor : source_color = vec4(0.0, 1.0, 0.0, 1.0);

uniform float initialEmissionTime = 1000.0;
uniform float finalEmissionTime = 5000.0;
uniform vec4 initialEmission: source_color = vec4(10.0, 10.0, 0.0, 1.0);
uniform vec4 finalEmission: source_color = vec4(0.0, 10.0, 0.0, 1.0);

uniform float emissionMixGamma = 4.0;

uniform float edgeWidth = 0.02;

uniform sampler2D customDataSampler;	// : source_color;


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



float calcWobble(float wobbleFraction, float time, float timeDiff, float seed)
{
	return (initialWobbleAmplitude_Min + (random(seed) * 
			(initialWobbleAmplitude_Max - initialWobbleAmplitude_Min))) * wobbleFraction *
			sin(random(seed + 2.0) * 6.28 + time * (initialWobbleFrequency_Min + 
				(random(seed + 1.0) * (initialWobbleFrequency_Max - initialWobbleFrequency_Min))));
}

varying flat float discardFragment;// This is bool...
varying flat float fragmentTimeDiff;
varying flat vec3 fragmentAlbedo;
varying flat float fragmentInitialAlpha;
varying flat vec4 fragmentEmission;
varying vec3 fragmentDistanceFromEdge;

void vertex()
{
	int faceId = VERTEX_ID / 3;
	float timeDiff = replayTime - texelFetch(customDataSampler, ivec2(faceId % 4096, faceId / 4096), 0).r;

	if ((timeDiff <= 0.0) || (timeDiff > disappearanceDelay))
	{
		// Face not yet or no longer visible -> Throw it out of sight
		VERTEX.y += outOfSightShift_Y;
		discardFragment = 1.0;
//		VERTEX.y += 10.0;
	}
	else
	{
		fragmentTimeDiff = timeDiff;
		discardFragment = 0.0;
		
		if (timeDiff < initialWobbleTime)
		{
			float wobbleFraction = 1.0 - smoothstep(0.0, initialWobbleTime, timeDiff);
			
			vec3 wobbleTranslation;
			
			float wobbleRandomizerTime = replayTime + wobbleTimeOffset;
			
			wobbleTranslation.x = calcWobble(wobbleFraction, wobbleRandomizerTime, timeDiff, VERTEX.x);
			wobbleTranslation.y = calcWobble(wobbleFraction, wobbleRandomizerTime, timeDiff, VERTEX.y);
			wobbleTranslation.z = calcWobble(wobbleFraction, wobbleRandomizerTime, timeDiff, VERTEX.z);
			
			VERTEX += wobbleTranslation;
		}

		vec4 currentColor = mix(initialColor, finalColor, smoothstep(initialColorTime, finalColorTime, timeDiff));

		//	ALBEDO = vec3(1.0, 0.0, 0.0 );
		fragmentAlbedo = vec3(currentColor.r, currentColor.g, currentColor.b);

		if (timeDiff < initialAlphaFadeInTime)
		{
			fragmentInitialAlpha = clamp((timeDiff / initialAlphaFadeInTime), 0.0, 1.0);
		}
		else if ((timeDiff > alphaFadeOutStartTime) &&
				(timeDiff < alphaFadeOutEndTime))
		{
			fragmentInitialAlpha = clamp((1.0 - ((timeDiff - alphaFadeOutStartTime) / (alphaFadeOutEndTime - alphaFadeOutStartTime))), 0.0, 1.0);
		}
		else if (timeDiff > alphaFadeOutEndTime)
		{
			fragmentInitialAlpha = 0.0;
		}
		else
		{
			fragmentInitialAlpha = 1.0;
		}

		vec4 emissionGammas = vec4(emissionMixGamma, emissionMixGamma, emissionMixGamma, emissionMixGamma);

		vec4 emission = mix(
				pow(initialEmission, emissionGammas), 
				pow(finalEmission, emissionGammas), 
				smoothstep(initialEmissionTime, finalEmissionTime, timeDiff));

		if ((timeDiff > initialEmissionFadeInStartTime) &&
				(timeDiff < initialEmissionFadeInEndTime))
		{
			float fraction = clamp((timeDiff - initialEmissionFadeInStartTime) /
					(initialEmissionFadeInEndTime - initialEmissionFadeInStartTime), 0.0, 1.0);
			fragmentEmission = fraction * vec4(emission.r, emission.g, emission.b, 1.0);
		}
		else if ((timeDiff > emissionFadeOutStartTime) && (timeDiff < emissionFadeOutEndTime))
		{
			float fraction = clamp(1.0 - ((timeDiff - emissionFadeOutStartTime) /
					(emissionFadeOutEndTime - emissionFadeOutStartTime)), 0.0, 1.0);
			fragmentEmission = fraction * vec4(emission.r, emission.g, emission.b, 1.0);
		}
		else if (timeDiff < emissionFadeOutEndTime)
		{
			fragmentEmission = vec4(emission.r, emission.g, emission.b, 1.0);
		}
		else
		{
			fragmentEmission = vec4(0.0, 0.0, 0.0, 0.0);
		}
		
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
}

/*
// Compute barycentric coordinates (u, v, w) for
// point p with respect to triangle (a, b, c)
// Source: https://gamedev.stackexchange.com/a/49370
vec3 barycentric(const vec3 p, const vec3 a, const vec3 b, vec3 c)
{
	vec3 v0 = b - a;
	vec3 v1 = c - a;
	vec3 v2 = p - a;
	float d00 = dot(v0, v0);
	float d01 = dot(v0, v1);
	float d11 = dot(v1, v1);
	float d20 = dot(v2, v0);
	float d21 = dot(v2, v1);
	float invDenom = 1.0 / (d00 * d11 - d01 * d01);
	vec3 retval;
	retval.y = (d11 * d20 - d01 * d21) * invDenom;
	retval.z = (d00 * d21 - d01 * d20) * invDenom;
	retval.x = 1.0f - retval.y - retval.z;
	return retval;
}
*/

void fragment() {
	if (discardFragment == 0.0)
	{
		float timeDiff = fragmentTimeDiff;

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

		ALPHA = fragmentInitialAlpha * clamp(max(edgeAFraction, max(edgeBFraction, edgeCFraction)), 0.0, 1.0);
		ALBEDO = fragmentAlbedo;
		if (fragmentEmission.a != 0.0)
		{
			EMISSION = fragmentEmission.rgb;
		}
		
//		ALBEDO.r = edgeAFraction;
//		ALBEDO.g = edgeBFraction;
//		ALBEDO.b = edgeCFraction;
		
	}
	else
	{
		discard;
	}
}