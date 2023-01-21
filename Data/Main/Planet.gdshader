// NOTE: Shader automatically converted from Godot Engine 4.0.alpha's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_disabled,diffuse_lambert,specular_disabled;
uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform float point_size : hint_range(0,128);
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

uniform vec4 baseColor : source_color = vec4(1.0);
uniform vec4 baseLight : source_color = vec4(0.0);
uniform float lightFraction = 1.0;

uniform int numOfBlackHoles = 4;
uniform vec3 blackHoleOriginalLocations[4];
uniform vec3 blackHoleCurrentLocations[4];
uniform float flySpeed = 1.0;			// Distance units per fraction
uniform float detachmentSpeed = 1.0;	// Distance units per fraction
uniform float maxEndAngle = 6;
uniform float shrinkMaxDistance = 0.1;

uniform float destructionFraction = 0.0;	// May need to be over 1 to get a total destruction

uniform float sphereOfAvoidanceRadius = 1;
uniform vec3 sphereOfAvoidanceCenterPoint = vec3(0.0, 0.0, 0.0);

uniform sampler2D customDataSampler;

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
	
	float detachmentRadius = destructionFraction * detachmentSpeed;
	
	if (distanceToNearestBlackHoleOriginalLocation < detachmentRadius)
	{
		float flyTemp = flySpeed * (detachmentRadius - distanceToNearestBlackHoleOriginalLocation);
		
		float flyFractionSmoothsteppedScalar = clamp(smoothstep(0, distanceToNearestBlackHoleCurrentLocation * 2.0, flyTemp) ,0.0, 1.0);
		
//		VERTEX += (nearestBlackHoleCurrentLocation - faceCenterPoint) * flyFractionSmoothsteppedScalar;

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
	
	// Otherwise keep face where it belongs
}




void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
}

