// NOTE: Shader automatically converted from Godot Engine 4.0.alpha's StandardMaterial3D.

shader_type spatial;
//render_mode blend_mix,depth_draw_opaque,cull_disabled,diffuse_lambert,specular_disabled;
render_mode blend_mix,depth_draw_opaque,diffuse_lambert,specular_disabled;
instance uniform vec4 albedo : source_color = vec4(1.0);

instance uniform vec3 faceScalingCenterPoint = vec3(0.0, 0.0, 0.0);
//uniform float displacementFraction = 0.0;
instance uniform float disintegrationFraction = 0.0;

instance uniform float maxEndAngle = 6;
instance uniform float randomSeed = 0.0;
instance uniform float fragmentScaling = 1.0;
instance uniform float autoFragmentScalingStartFraction = 0.0;
instance uniform float autoFragmentScalingEndFraction = 1.0;

instance uniform vec3 displacementMinDeviation = vec3(0.0, 0.0, 0.0);
instance uniform vec3 displacementMaxDeviation = vec3(0.0, 0.0, 0.0);
instance uniform vec3 displacementMultiplier = vec3(1.0, 1.0, 1.0);
instance uniform float centerXDragMultiplier = 0.0;
instance uniform float centerXDragMinWidth = 0.0;
instance uniform float centerXDragMaxWidth = 1.0;
instance uniform float centerXDragPower = 1.0;

//instance uniform float displacementMultiplier = 1.0;

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

	uint h = hash( floatBitsToUint( f + randomSeed ) );
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

void vertex() {
//	UV=UV*uv1_scale.xy+uv1_offset.xy;

	float shapeId = CUSTOM0.a;

	vec3 faceCenterPoint = CUSTOM0.xyz;
	
	// "Randomize" the maximum rotations
	float maxAngleX = random(shapeId + faceCenterPoint.y) * maxEndAngle * 2.0 - maxEndAngle;
	float maxAngleY = random(shapeId + faceCenterPoint.z) * maxEndAngle * 2.0 - maxEndAngle;
	float maxAngleZ = random(shapeId + faceCenterPoint.x) * maxEndAngle * 2.0 - maxEndAngle;
	
	mat3 linearPart = rotation3dX(maxAngleX * disintegrationFraction);
	linearPart *= rotation3dY(maxAngleY * disintegrationFraction);
	linearPart *= rotation3dZ(maxAngleZ * disintegrationFraction);
	
	vec3 relVertPos = VERTEX - faceCenterPoint;
	vec3 rotatedAndScaledRelVertPos = fragmentScaling * 
		(1.0 - smoothstep(autoFragmentScalingStartFraction, autoFragmentScalingEndFraction, disintegrationFraction)) *
		linearPart * relVertPos;
	
	vec3 displacementDeviation = disintegrationFraction * displacementMinDeviation + disintegrationFraction * vec3(
			(displacementMaxDeviation.x - displacementMinDeviation.x) * random(shapeId),
			(displacementMaxDeviation.y - displacementMinDeviation.y) * random(shapeId * 2.0),
			(displacementMaxDeviation.z - displacementMinDeviation.z) * random(shapeId * 3.0)
		);
	
	NORMAL = linearPart * NORMAL;
	VERTEX = rotatedAndScaledRelVertPos + 
			faceScalingCenterPoint + 
			(faceCenterPoint - faceScalingCenterPoint) * displacementMultiplier *
			(1.0 + disintegrationFraction) + 
			displacementDeviation;
			
	VERTEX.x += centerXDragMultiplier * 
			(1.0 - 1.0 / pow(clamp((abs(faceCenterPoint.y) - centerXDragMinWidth) / (centerXDragMaxWidth - centerXDragMinWidth), 0.0, 1.0), centerXDragPower));
			
//	VERTEX.x += centerXDrag * (1.0 - smoothstep(0, centerXDragWidth, abs(faceCenterPoint.y)));
}

void fragment() {
//	vec2 base_uv = UV;
//	vec4 albedo_tex = texture(texture_albedo,base_uv);
	ALBEDO = albedo.rgb;
/*	ALBEDO = albedo.rgb * albedo_tex.rgb;
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	*/
}

