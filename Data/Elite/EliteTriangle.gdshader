shader_type spatial;
render_mode unshaded;

uniform vec4 pointColors[16] : source_color;
global uniform float masterReplayTime;

//global uniform vec2 eliteOverlayResolution;

varying flat vec3 paintColors[2];

const vec3 blinkColor1 = vec3(1.5, 0.1, 0.1);
const vec3 blinkColor2 = vec3 (0.2, 0.0, 0.0);
const float blinkFreq = 2.0;

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
}

void fragment() {
//	int x = int(SCREEN_UV.x * eliteOverlayResolution.x);
//	int y = int(SCREEN_UV.y * eliteOverlayResolution.y);
	
	int x = int(FRAGCOORD.x);
	int y = int(FRAGCOORD.y);

//	int x = int(SCREEN_UV.x * VIEWPORT_SIZE.x);
//	int y = int(SCREEN_UV.y * VIEWPORT_SIZE.y);


	// Bitwise xor may not work everywhere(?)
	ALBEDO = paintColors[(x ^ y) & 1];
	
//	ALBEDO = paintColors[(x & 1)];
	
//	ALBEDO = mix(pointColors[int(floor(UV.x + 0.5))].rgb, pointColors[int(floor(UV.y + 0.5))].rgb, 0.0);
}
