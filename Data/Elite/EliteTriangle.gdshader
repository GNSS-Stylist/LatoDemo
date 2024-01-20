shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 pointColors[16] : source_color;
global uniform float masterReplayTime;

//instance uniform vec3 faceScalingCenterPoint = vec3(0.0, 0.0, 0.0);
//uniform float displacementFraction = 0.0;
instance uniform float disintegrationFraction = 0.0;
instance uniform float disintegrationDisplacementSpeed = 10.0;

instance uniform float maxEndAngle = 6;
instance uniform float randomSeed = 0.0;
instance uniform float fragmentScaling = 1.0;
instance uniform float autoFragmentScalingStartFraction = 0.0;
instance uniform float autoFragmentScalingEndFraction = 1.0;

instance uniform vec3 displacementMinDeviation = vec3(0.0, 0.0, 0.0);
instance uniform vec3 displacementMaxDeviation = vec3(0.0, 0.0, 0.0);
//instance uniform vec3 displacementMultiplier = vec3(1.0, 1.0, 1.0);

varying flat vec3 paintColors[2];

const vec3 blinkColor1 = vec3(1.5, 0.1, 0.1);
const vec3 blinkColor2 = vec3 (0.2, 0.0, 0.0);
const float blinkFreq = 2.0;

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

void vertex() {
	int colorIndex1 = int(UV.x);
	int colorIndex2 = int(UV.y);
	
	if (colorIndex1 > 15) {
		paintColors[0] = mix(blinkColor1, blinkColor2, 0.5 + 0.5 * sin(masterReplayTime * blinkFreq * 6.28));
	}
	else {
		paintColors[0] = pointColors[int(UV.x)].rgb;
	}
	
	if (colorIndex1 > 15) {
		paintColors[1] = mix(blinkColor1, blinkColor2, 0.5 + 0.5 * sin(masterReplayTime * blinkFreq * 6.28));
	}
	else {
		paintColors[1] = pointColors[int(UV.y)].rgb;
	}
	
	vec3 faceCenterPoint = CUSTOM0.xyz;

//	float randomSeed2 = CUSTOM0.a;
	float randomSeed2 = faceCenterPoint.x + faceCenterPoint.y + faceCenterPoint.z;
	
	// "Randomize" the maximum rotations
	float maxAngleX = random(randomSeed2 + faceCenterPoint.y) * maxEndAngle * 2.0 - maxEndAngle;
	float maxAngleY = random(randomSeed2 + faceCenterPoint.z) * maxEndAngle * 2.0 - maxEndAngle;
	float maxAngleZ = random(randomSeed2 + faceCenterPoint.x) * maxEndAngle * 2.0 - maxEndAngle;
	
	mat3 linearPart = rotation3dX(maxAngleX * disintegrationFraction);
	linearPart *= rotation3dY(maxAngleY * disintegrationFraction);
	linearPart *= rotation3dZ(maxAngleZ * disintegrationFraction);
	
	vec3 relVertPos = VERTEX - faceCenterPoint;
	vec3 rotatedAndScaledRelVertPos = fragmentScaling * 
		(1.0 - smoothstep(autoFragmentScalingStartFraction, autoFragmentScalingEndFraction, disintegrationFraction)) *
		linearPart * relVertPos;
	
	vec3 displacementDeviation = disintegrationFraction * displacementMinDeviation + disintegrationFraction * vec3(
			(displacementMaxDeviation.x - displacementMinDeviation.x) * random(randomSeed2),
			(displacementMaxDeviation.y - displacementMinDeviation.y) * random(randomSeed2 * 2.0),
			(displacementMaxDeviation.z - displacementMinDeviation.z) * random(randomSeed2 * 3.0)
		);
	
	NORMAL = linearPart * NORMAL;
	VERTEX = rotatedAndScaledRelVertPos + 
			faceCenterPoint *
			(1.0 + disintegrationFraction * disintegrationDisplacementSpeed) + 
			displacementDeviation;
}

void fragment() {
#if false
	// Use these versions to see low-res dithering on the editor
	float pixelsPerPixel = 5.0;
	int x = int(FRAGCOORD.x / pixelsPerPixel);
	int y = int(FRAGCOORD.y / pixelsPerPixel);
#else
	int x = int(FRAGCOORD.x);
	int y = int(FRAGCOORD.y);
#endif

	// Bitwise xor may not work everywhere(?)
	ALBEDO = paintColors[(x ^ y) & 1];
}
