// NOTE: Shader automatically converted from Godot Engine 4.0.alpha's StandardMaterial3D.

shader_type spatial;

instance uniform float basePosY = 0.0;
instance uniform int textureIndex = 0;
instance uniform float preXShift = 0.0;

//render_mode blend_mix,depth_draw_opaque,cull_disabled,diffuse_lambert,specular_disabled;
render_mode blend_mix,depth_draw_opaque,diffuse_lambert,specular_disabled,cull_disabled;
uniform vec4 albedo : source_color;
uniform sampler2D albedoTextures[8] : source_color;	// : repeat_disable, source_color, filter_linear_mipmap;

uniform float randomSeed = 0.0;
uniform float displacementXCenterPoint = 0.0;

uniform float maxEndAngle = 6;

//instance uniform float fragmentScaling = 1.0;
uniform float autoFragmentScalingStartFraction = 0.0;
uniform float autoFragmentScalingEndFraction = 1.0;

uniform vec3 displacementMinDeviation_Appear = vec3(-1.0, -1.0, 0.1);
uniform vec3 displacementMaxDeviation_Appear = vec3(-0.5, -0.5, 1.0);

uniform vec3 displacementMinDeviation_Disappear = vec3(0.5, 0.5, 0.1);
uniform vec3 displacementMaxDeviation_Disappear = vec3(1.0, 1.0, 1.0);

uniform float displacementXMultiplier_Appear = 0.5;
uniform float displacementXMultiplier_Disappear = 0.5;

uniform float disintegrationMinY_Appear = -1.5;
uniform float disintegrationMaxY_Appear = -0.5;

uniform float disintegrationMinY_Disappear = 0.5;
uniform float disintegrationMaxY_Disappear = 1.5;

//uniform float endScrollerYPos = 0.0;
global uniform float endScrollerYPos;

//instance uniform vec3 displacementMultiplier = vec3(1.0, 1.0, 1.0);
//instance uniform float centerXDragMultiplier = 0.0;
//instance uniform float centerXDragMinWidth = 0.0;
//instance uniform float centerXDragMaxWidth = 1.0;
//instance uniform float centerXDragPower = 1.0;

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
	
	VERTEX.x += preXShift;

//	float shiftY = endScrollerYPos + basePosY;
	
//	VERTEX.y += shiftY;

	vec3 faceCenterPoint = CUSTOM0.xyz;
	faceCenterPoint.x += preXShift;
	
	// "Randomize" the maximum rotations
	float maxAngleX = random(shapeId + CUSTOM0.y) * maxEndAngle * 2.0 - maxEndAngle;
	float maxAngleY = random(shapeId + CUSTOM0.z) * maxEndAngle * 2.0 - maxEndAngle;
	float maxAngleZ = random(shapeId + CUSTOM0.x) * maxEndAngle * 2.0 - maxEndAngle;
	
	vec3 relVertPos = VERTEX - faceCenterPoint;

	faceCenterPoint.y += (endScrollerYPos + basePosY);

	float disintegrationFraction_Appear = 1.0 - smoothstep(disintegrationMinY_Appear, disintegrationMaxY_Appear, faceCenterPoint.y);
	float disintegrationFraction_Disappear = smoothstep(disintegrationMinY_Disappear, disintegrationMaxY_Disappear, faceCenterPoint.y);
	
	float maxFraction = max(disintegrationFraction_Appear, disintegrationFraction_Disappear);
	
	mat3 linearPart = rotation3dX(maxAngleX * maxFraction);
	linearPart *= rotation3dY(maxAngleY * maxFraction);
	linearPart *= rotation3dZ(maxAngleZ * maxFraction);
	
	float fragmentScaling = 1.0 - smoothstep(autoFragmentScalingStartFraction, autoFragmentScalingEndFraction, maxFraction);
	
	vec3 rotatedAndScaledRelVertPos = fragmentScaling * 
		linearPart * relVertPos;

	vec3 displacementDeviation = disintegrationFraction_Appear * displacementMinDeviation_Appear + disintegrationFraction_Appear * vec3(
			(displacementMaxDeviation_Appear.x - displacementMinDeviation_Appear.x) * random(shapeId),
			(displacementMaxDeviation_Appear.y - displacementMinDeviation_Appear.y) * random(shapeId * 2.0),
			(displacementMaxDeviation_Appear.z - displacementMinDeviation_Appear.z) * random(shapeId * 3.0)) +
			disintegrationFraction_Disappear * displacementMinDeviation_Disappear + disintegrationFraction_Disappear * vec3(
			(displacementMaxDeviation_Disappear.x - displacementMinDeviation_Disappear.x) * random(shapeId),
			(displacementMaxDeviation_Disappear.y - displacementMinDeviation_Disappear.y) * random(shapeId * 2.0),
			(displacementMaxDeviation_Disappear.z - displacementMinDeviation_Disappear.z) * random(shapeId * 3.0));
	
//	displacementDeviation = vec3(0.0);
	
	NORMAL = linearPart * NORMAL;
	VERTEX = faceCenterPoint + rotatedAndScaledRelVertPos +
//			faceScalingCenterPoint + 
//			(faceCenterPoint - faceScalingCenterPoint) * displacementMultiplier *
//			(faceCenterPoint) * displacementMultiplier *
//			(1.0 + disintegrationFraction) + 
			displacementDeviation;

	VERTEX.x += (faceCenterPoint.x - displacementXCenterPoint) * displacementXMultiplier_Appear * disintegrationFraction_Appear +
			(faceCenterPoint.x - displacementXCenterPoint) * displacementXMultiplier_Disappear * disintegrationFraction_Disappear;
	
}

void fragment() {
//	vec2 base_uv = UV;
//	vec4 albedo_tex = texture(texture_albedo,base_uv);
	if (UV.x < 0.0) {
		ALBEDO = albedo.rgb;
	}
	else {
		ALBEDO = texture(albedoTextures[textureIndex], UV).rgb;
	}
/*	ALBEDO = albedo.rgb * albedo_tex.rgb;
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	*/
}

