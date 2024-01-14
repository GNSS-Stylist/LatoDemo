// NOTE: Shader automatically converted from Godot Engine 4.0.alpha's StandardMaterial3D.

shader_type spatial;
//render_mode blend_mix,depth_draw_opaque,cull_disabled,diffuse_lambert,specular_disabled;
render_mode cull_disabled, depth_draw_always, specular_disabled;
//uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D zoomed_texture_albedo : source_color,filter_linear_mipmap,repeat_disable;
/*uniform float point_size : hint_range(0,128);
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform float specular;
uniform float metallic;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;
*/

uniform vec4 baseColor : source_color = vec4(1.0);

uniform int numOfBlackHoles = 4;
uniform vec3 blackHoleOriginalLocations[4];
uniform vec3 blackHoleCurrentLocations[4];
uniform float flySpeed = 1.0;			// Distance units per fraction
uniform float detachmentSpeed = 1.0;	// Distance units per fraction
uniform float maxEndAngle = 6.0;
uniform float shrinkMaxDistance = 0.1;

uniform float destructionFraction = 0.0;	// May need to be over 1 to get a total destruction

uniform float sphereOfAvoidanceRadius = 1.0;
uniform vec3 sphereOfAvoidanceCenterPoint = vec3(0.0, 0.0, 0.0);

uniform sampler2D customDataSampler;

uniform float constructionMaxDistance = 10.0;
uniform float constructionMinDistance = 2.0;
uniform float constructionFlyDistance = 1.0;
uniform float constructionMaxStartAngle = 6.0;
uniform vec3 constructionFlyTowardsPoint = vec3(0.0, 0.0, -1.0);

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

float distanceSquared(vec3 A, vec3 B)
{
    vec3 C = A - B;
    return dot(C, C);
}

ivec2 getTexelCoord(int faceIndex) {
	return ivec2(faceIndex % 4096, faceIndex / 4096);
}

void vertex() {
//	UV=UV*uv1_scale.xy+uv1_offset.xy;

	if (destructionFraction > 0.0)
	{
		int faceId = VERTEX_ID / 3;
		vec3 faceCenterPoint = texelFetch(customDataSampler, getTexelCoord(faceId), 0).xyz;
		
		// Find the nearest black hole (original location)
		
		float nearestDistanceSquared = 1.0e9;
		int nearestBlackHoleIndex = 0;
		
		for (int i = 0; i < numOfBlackHoles; i++)
		{
			float dist = distanceSquared(faceCenterPoint, blackHoleOriginalLocations[i]);
			if (dist < nearestDistanceSquared)
			{
				nearestDistanceSquared = dist;
				nearestBlackHoleIndex = i;
			}
		}
		
		float distanceToNearestBlackHoleOriginalLocation = sqrt(nearestDistanceSquared);
		
		vec3 nearestBlackHoleCurrentLocation = blackHoleCurrentLocations[nearestBlackHoleIndex];
		float distanceToNearestBlackHoleCurrentLocation = distance(nearestBlackHoleCurrentLocation, faceCenterPoint);
		
		// pow(destructionFraction, 2) to ge more precision on low values
		float detachmentRadius = destructionFraction * destructionFraction * detachmentSpeed;
		
		if (distanceToNearestBlackHoleOriginalLocation < detachmentRadius)
		{
			float flyTemp = flySpeed * (detachmentRadius - distanceToNearestBlackHoleOriginalLocation);
			
			float flyFractionSmoothsteppedScalar = clamp(smoothstep(0, distanceToNearestBlackHoleCurrentLocation * 2.0, flyTemp) ,0.0, 1.0);
			
			// "Randomize" the maximum rotations
			float maxAngleX = random(faceCenterPoint.x) * maxEndAngle - maxEndAngle / 2.0;
			float maxAngleY = random(faceCenterPoint.y) * maxEndAngle - maxEndAngle / 2.0;
			float maxAngleZ = random(faceCenterPoint.z) * maxEndAngle - maxEndAngle / 2.0;
			
			mat3 linearPart = rotation3dX(maxAngleX * flyFractionSmoothsteppedScalar);
			linearPart *= rotation3dY(maxAngleY * flyFractionSmoothsteppedScalar);
			linearPart *= rotation3dZ(maxAngleZ * flyFractionSmoothsteppedScalar);
			
			vec3 translation = mix(faceCenterPoint, nearestBlackHoleCurrentLocation, flyFractionSmoothsteppedScalar);

			// "Hollow planet" looked stupid so add a "core" to it and avoid hitting it
			
			if (distance(translation, sphereOfAvoidanceCenterPoint) < sphereOfAvoidanceRadius)
			{
				translation = sphereOfAvoidanceCenterPoint + (sphereOfAvoidanceRadius * normalize(translation - sphereOfAvoidanceCenterPoint));
			}

			vec3 relVertPos = VERTEX - faceCenterPoint;
			
			float scaling = clamp((smoothstep(-shrinkMaxDistance, shrinkMaxDistance, distance(translation, nearestBlackHoleCurrentLocation)) - 0.5) * 2.0, 0.0, 1.0);
			
			vec3 rotatedAndScaledRelVertPos = scaling * linearPart * relVertPos;

			NORMAL = linearPart * NORMAL;
			VERTEX = rotatedAndScaledRelVertPos + translation;
		}
	}
	else if (constructionMinDistance < 10.0e6)
	{
		int faceId = VERTEX_ID / 3;
		vec3 faceCenterPoint = texelFetch(customDataSampler, getTexelCoord(faceId), 0).xyz;

		// Huge multiplier to make it possible to use the inspector (with 0.001 resolution)
		float dist = length(faceCenterPoint) * 1.0e6;
		
//		float minDistScaled = pow(constructionMinDistance, 10);
//		float maxDistScaled = pow(constructionMaxDistance, 10);
		
		if (dist > constructionMaxDistance)
		{
			// Face of this vertex is not visible yet, so set all vertices
			// to zero coords to make the face invisible
			VERTEX = vec3(0.0);
		}
		else if (dist > constructionMinDistance)
		{
			// Face is flying and rotating to it's final place
			
			float flyFraction = clamp(smoothstep(constructionMinDistance, constructionMaxDistance + (constructionMaxDistance - constructionMinDistance), dist) * 2.0, 0.0, 1.0);

			// "Randomize" the maximum rotations
			float maxAngleX = random(faceCenterPoint.x) * constructionMaxStartAngle;
			float maxAngleY = random(faceCenterPoint.y) * constructionMaxStartAngle;
			float maxAngleZ = random(faceCenterPoint.z) * constructionMaxStartAngle;

			mat3 linearPart = rotation3dX(maxAngleX * flyFraction);
			linearPart *= rotation3dY(maxAngleY * flyFraction);
			linearPart *= rotation3dZ(maxAngleZ * flyFraction);
			
			vec3 translation = flyFraction * constructionFlyDistance * normalize(faceCenterPoint - constructionFlyTowardsPoint);

			vec3 relVertPos = VERTEX - faceCenterPoint;
			
			vec3 rotatedAndScaledRelVertPos = (1.0 - flyFraction) * (linearPart * relVertPos);
			
			NORMAL = linearPart * NORMAL;
			VERTEX = rotatedAndScaledRelVertPos + translation + faceCenterPoint;
		}
	}
	
	// Otherwise keep face where it belongs
}


const float zoomAmount = 10.0;

// Not sure why the longitude value (55.88) doesn't match the one given to
// the texture generator (should be 56.25). This 55.88 is an experimental value
// found by just overlaying these textures and twiddling until they matched.
// Zoomed texture was generated by command:
// planet -o test7.bmp -s 0.41 -w 4096 -h 4096 -c -l 280 -L 56.25 -m 10
const vec2 zoomCorner = vec2(100.0 / 360.0, 55.88 / 180.0) - vec2(1.0 / zoomAmount * 0.5);

void fragment() {
	vec2 base_uv = UV;
	
	vec2 zoom_uv = zoomAmount * (UV - zoomCorner);

	if (zoom_uv.x > 0.0 && zoom_uv.x < 1.0 && zoom_uv.y > 0.0 && zoom_uv.y < 1.0) {
		vec4 albedo_tex = texture(zoomed_texture_albedo,zoom_uv);
		ALBEDO = baseColor.rgb * albedo_tex.rgb;
	}
	else {
		vec4 albedo_tex = texture(texture_albedo,base_uv);
		ALBEDO = baseColor.rgb * albedo_tex.rgb;
	}
}
