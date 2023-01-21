shader_type spatial;

//const int maxVertices = 500000;

// specular_disabled: Black inside of the barn stay black instead of ugly grey
//render_mode cull_disabled, depth_draw_always, unshaded;
render_mode cull_disabled, depth_draw_always, specular_disabled;

uniform float replayTime;

uniform float faceTimeOverride = 0.0;

//uniform float currentReplayTime = 0.0;
uniform float flyTime = 500.0;
uniform float outOfSightShift_Y = 10.0;
uniform float flatFaceMinDelayTime = 5000.0;	// Faces are always flat until this time
uniform float flatFaceMaxDelayTime = 10000.0;	// From this time onwards vertices use their own normals
uniform float leaveMeAloneDelayTime_Vertex = 10000.0;	// No operations after this time (slight optimization)
uniform float leaveMeAloneDelayTime_Fragment = 10000.0;	// No operations after this time (slight optimization)

//uniform float faceSize = 0.5;
uniform float maxStartAngle = 6;

uniform float initialEdgeColorFadeInStartTime = 1000.0;
uniform float initialEdgeColorFadeInEndTime = 2000.0;
uniform float edgeColorFadeOutStartTime = 5000.0;
uniform float edgeColorFadeOutEndTime = 6000.0;

uniform float initialEdgeEmissionFadeInStartTime = 1000.0;
uniform float initialEdgeEmissionFadeInEndTime = 2000.0;
uniform float edgeEmissionFadeOutStartTime = 5000.0;
uniform float edgeEmissionFadeOutEndTime = 6000.0;
uniform float edgeEmissionFadeGammaCorrection = 0.5;

uniform vec4 baseColor : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 edgeColor : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 edgeEmission : source_color = vec4(10.0, 0.0, 0.0, 1.0);

uniform float edgeWidth = 0.02;

uniform sampler2D albedo_texture : source_color,filter_linear_mipmap,repeat_disable;
uniform float textureFadeInStartTime = 10000.0;
uniform float textureFadeInEndTime = 15000.0;
uniform vec4 albedo_texture_base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

//uniform vec4 baseLight : hint_color = vec4(1.0);
//uniform float lightFraction = 1.0;

uniform vec4 baseLightInitialValue : source_color = vec4(0.0);
uniform vec4 baseLightFinalValue : source_color = vec4(1.0);
uniform float baseLightInitialValueTime = 10000.0;
uniform float baseLightFinalValueTime = 15000.0;

uniform float lightFractionInitialValue = 1.0;
uniform float lightFractionFinalValue = 0.0;
uniform float lightFractionInitialValueTime = 10000.0;
uniform float lightFractionFinalValueTime = 15000.0;

//uniform float specular_power = 1.0;
//uniform float specular_strength = 0.0;
//uniform float dbg_textureFraction = 0.0;

// These are for "blending" the snow surrounding the barn into the background
uniform bool edgeNormalSmoothing = false;
uniform vec2 edgeNormalSmoothOriginXZ = vec2(0.0, 0.0);
uniform float edgeNormalSmoothStartDistance = 1.0e9;
uniform float edgeNormalSmoothEndDistance = 2.0e9;

uniform sampler2D customDataSampler;	// : source_color;

mat3 rotation3dX(float angle) {
	float s = sin(angle);
	float c = cos(angle);

	return mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, c, s),
		vec3(0.0, -s, c)
	);
}

mat3 rotation3dY(float angle) {
	float s = sin(angle);
	float c = cos(angle);

	return mat3(
		vec3(c, 0.0, -s),
		vec3(0.0, 1.0, 0.0),
		vec3(s, 0.0, c)
	);
}

mat3 rotation3dZ(float angle) {
	float s = sin(angle);
	float c = cos(angle);

	return mat3(
		vec3(c, s, 0.0),
		vec3(-s, c, 0.0),
		vec3(0.0, 0.0, 1.0)
	);
}

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

ivec2 getTexelCoord(int faceIndex, int offset) {
	int index = faceIndex * 3 + offset;
	return ivec2(index % 4096, index / 4096);
}

varying flat float discardFragment;	// This is bool
varying flat float fragmentTimeDiff;
varying flat float fragmentEdgeColorFraction;
varying flat float fragmentEdgeEmissionFraction;
varying vec3 fragmentDistanceFromEdge;
varying flat float fragmentTextureFadeInFraction;
varying flat vec3 lightBaseLight;
varying flat float lightLightFraction;


void vertex()
{
//	int faceIndex = int(UV2.y);
//	float shotTime = UV2.x;
	float timeDiff;
	
	int faceId = VERTEX_ID / 3;

	if (faceTimeOverride == 0.0) 
	{
		timeDiff = replayTime - texelFetch(customDataSampler, getTexelCoord(faceId, 0), 0).a;
	}
	else
	{
		timeDiff = replayTime - faceTimeOverride;
	}
	
	fragmentTimeDiff = timeDiff;
	
	if (timeDiff < 0.0)
	{
		// Face not visible yet -> Throw it out of sight
		VERTEX.y += outOfSightShift_Y;
		discardFragment = 1.0;
//		VERTEX.y += 10.0;
	}
	else
	{
		discardFragment = 0.0;
		fragmentTimeDiff = timeDiff;
		
		if (timeDiff < leaveMeAloneDelayTime_Vertex)
		{
			if (timeDiff < flatFaceMinDelayTime) {
				// Face is completely flat
				// Normal for flat shading is relayed in CUSTOM2
				NORMAL = texelFetch(customDataSampler, getTexelCoord(faceId, 0), 0).xyz;
			}
			else if (timeDiff < flatFaceMaxDelayTime) {
				// Interpolate "flatness"
				// Not using quaternion or any fancy methods as
				// face normal and vertex normal are likely near enough
				vec3 flatFaceNormal = texelFetch(customDataSampler, getTexelCoord(faceId, 0), 0).xyz;
				float fraction = (timeDiff - flatFaceMinDelayTime) / (flatFaceMaxDelayTime - flatFaceMinDelayTime);
				NORMAL = normalize(mix(flatFaceNormal, NORMAL, fraction));
			}

			if (timeDiff < flyTime)
			{
				// Face flying
				
//				vec3 startOrigin = CUSTOM0.xyz;
//				vec3 finalOrigin = CUSTOM1.xyz;

//				ivec2 startTexelCoord = ivec2((VERTEX_ID * 4) % 4096, (VERTEX_ID * 4) / 4096);

				vec3 finalOrigin = texelFetch(customDataSampler, getTexelCoord(faceId, 1), 0).xyz;
//				vec3 startOrigin = texelFetch(customDataSampler, startTexelCoord, 0).xyz;
				vec3 startOrigin = texelFetch(customDataSampler, getTexelCoord(faceId, 2), 0).xyz;
//				vec3 finalOrigin = texelFetch(customDataSampler, ivec2(startTexelCoord.x + 1, startTexelCoord.y), 0).xyz;
				
				// Fraction runs from 1 to 0 when time increases
				// Both ends smoothstepped:
	//			float flyFractionSmoothsteppedScalar = smoothstep(0.0, 1.0, 1.0 - (timeDiff / flyTime));
				// Faster initial speed:
				float flyFractionSmoothsteppedScalar = 2.0 * smoothstep(0.0, 2.0, 1.0 - (timeDiff / flyTime));

				// "Randomize" the maximum rotations
				float maxAngleX = random(finalOrigin.x) * maxStartAngle - maxStartAngle / 2.0;
				float maxAngleY = random(finalOrigin.y) * maxStartAngle - maxStartAngle / 2.0;
				float maxAngleZ = random(finalOrigin.z) * maxStartAngle - maxStartAngle / 2.0;

				mat3 linearPart = rotation3dX(maxAngleX * flyFractionSmoothsteppedScalar);
				linearPart *= rotation3dY(maxAngleY * flyFractionSmoothsteppedScalar);
				linearPart *= rotation3dZ(maxAngleZ * flyFractionSmoothsteppedScalar);
				
				vec3 relVertPos = VERTEX - finalOrigin;
				
				vec3 rotatedAndScaledRelVertPos = (1.0 - flyFractionSmoothsteppedScalar) * linearPart * relVertPos;
				
				vec3 translation = mix(finalOrigin, startOrigin, flyFractionSmoothsteppedScalar);

				NORMAL = linearPart * NORMAL;
				VERTEX = rotatedAndScaledRelVertPos + translation;
			}
		}
		
//		fragmentDistanceFromEdge = CUSTOM3.gba;

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
		
		if ((timeDiff > initialEdgeColorFadeInStartTime) &&
				(timeDiff < initialEdgeColorFadeInEndTime))
		{
			fragmentEdgeColorFraction = clamp((timeDiff - initialEdgeColorFadeInStartTime) /
					(initialEdgeColorFadeInEndTime - initialEdgeColorFadeInStartTime), 0.0, 1.0);
		}
		else if ((timeDiff > edgeColorFadeOutStartTime) && (timeDiff < edgeColorFadeOutEndTime))
		{
			fragmentEdgeColorFraction = clamp(1.0 - ((timeDiff - edgeColorFadeOutStartTime) /
					(edgeColorFadeOutEndTime - edgeColorFadeOutStartTime)), 0.0, 1.0);
		}
		else if (timeDiff >= edgeColorFadeOutEndTime)
		{
			fragmentEdgeColorFraction = 0.0;
		}
		else
		{
			fragmentEdgeColorFraction = 1.0;
		}

		if ((timeDiff > initialEdgeEmissionFadeInStartTime) &&
				(timeDiff < initialEdgeEmissionFadeInEndTime))
		{
			fragmentEdgeEmissionFraction = clamp((timeDiff - initialEdgeEmissionFadeInStartTime) /
					(initialEdgeEmissionFadeInEndTime - initialEdgeEmissionFadeInStartTime), 0.0, 1.0);
		}
		else if ((timeDiff > edgeEmissionFadeOutStartTime) && (timeDiff < edgeEmissionFadeOutEndTime))
		{
			fragmentEdgeEmissionFraction = clamp(1.0 - ((timeDiff - edgeEmissionFadeOutStartTime) /
					(edgeEmissionFadeOutEndTime - edgeEmissionFadeOutStartTime)), 0.0, 1.0);
		}
		else if ((timeDiff >= edgeEmissionFadeOutEndTime) ||
				(timeDiff <= initialEdgeEmissionFadeInStartTime))
		{
			fragmentEdgeEmissionFraction = 0.0;
		}
		else
		{
			fragmentEdgeEmissionFraction = 1.0;
		}
		
		fragmentTextureFadeInFraction = clamp((timeDiff - textureFadeInStartTime) /
				(textureFadeInEndTime - textureFadeInStartTime), 0.0, 1.0);
				
		float fraction = clamp((timeDiff - baseLightInitialValueTime) /
				(baseLightFinalValueTime - baseLightInitialValueTime), 0.0, 1.0);

		lightBaseLight = mix(baseLightInitialValue.rgb, baseLightFinalValue.rgb, fraction);
		
		fraction = clamp((timeDiff - lightFractionInitialValueTime) /
				(lightFractionFinalValueTime - lightFractionInitialValueTime), 0.0, 1.0);
				
		lightLightFraction = mix(lightFractionInitialValue, lightFractionFinalValue, fraction);
	}

	if (edgeNormalSmoothing) {
		// This is for "blending" the snow surrounding the barn into the background
		float distanceFromSmoothOrigin = distance(VERTEX.xz, edgeNormalSmoothOriginXZ);

		vec3 normalUp = vec3(0.0, 1.0, 0.0);

		float normalFraction = smoothstep(edgeNormalSmoothStartDistance, edgeNormalSmoothEndDistance, distanceFromSmoothOrigin);

		NORMAL = mix(NORMAL, normalUp, normalFraction);
	}
	
	// Some notes and "log":
	// Issue "VERTEX_ID and mesh-less rendering":
	// https://github.com/godotengine/godot/issues/19473
	// Related ("Support uniform arrays in the shader language"):
	// https://github.com/godotengine/godot-proposals/issues/931
	// Not used here after all.
	// Tried to work around missing per-vertex attributes with this,
	// (leading to https://github.com/godotengine/godot/issues/55674 )
	// since I first tried to use uniforms for per-vertex data,
	// totally overflowing space reserved for them.
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
	if (discardFragment != 0.0)
	{
		discard;
	}
	else
	{
		float timeDiff = fragmentTimeDiff;

		// Texture seems to be flipped around y-axis (from meshlab to here)
		vec3 textureAlbedo = albedo_texture_base_color.rgb * texture(albedo_texture, vec2(UV.x, 1.0 - UV.y)).rgb;

		if (timeDiff < leaveMeAloneDelayTime_Fragment)
		{
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

	//		float fraction = fragmentInitialAlpha * clamp(edgeAFraction + edgeBFraction + edgeCFraction, 0.0, 1.0);
			float fraction = fragmentEdgeColorFraction * clamp(max(edgeAFraction, max(edgeBFraction, edgeCFraction)), 0.0, 1.0);

			vec4 mixedColor = mix(baseColor, edgeColor, fraction);

			ALBEDO = mix(mixedColor.rgb, textureAlbedo, fragmentTextureFadeInFraction);

			fraction *= fragmentEdgeEmissionFraction;
			
			if (fraction != 0.0)
			{
				EMISSION = pow(fraction, edgeEmissionFadeGammaCorrection) * vec3(edgeEmission.r, edgeEmission.g, edgeEmission.b);
			}
		}
		else
		{
			ALBEDO = mix(baseColor.rgb, textureAlbedo, fragmentTextureFadeInFraction);
		}
		

//		vec4 albedo_tex = texture(tex, vec2(UV.x, 1.0 - UV.y));
//		albedo_tex.rgb = mix(pow((albedo_tex.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)),vec3(2.4)),albedo_tex.rgb.rgb * (1.0 / 12.92),lessThan(albedo_tex.rgb,vec3(0.04045)));		
//		ALBEDO = albedo_tex.rgb;
		
	}
}

void light() {
	if (DIFFUSE_LIGHT == vec3(0.0)) {
		// This is kind of hack to initialize DIFFUSE_LIGHT.
		// Not sure if initial value for DIFFUSE_LIGHT can be relied being full of zeroes.
		// Seems to work, though.
		DIFFUSE_LIGHT = lightBaseLight;
	}
	
    DIFFUSE_LIGHT += LIGHT_COLOR * clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * ALBEDO * lightLightFraction;
	
// This barn aint no specular
//    vec3 H = normalize(VIEW + LIGHT);
//    float NdotH = max(0, dot(NORMAL, H));
//    float specular = pow(NdotH, specular_power) * specular_strength * ATTENUATION;
//    SPECULAR_LIGHT += specular * LIGHT_COLOR * lightFraction;
}




