// NOTE: Shader automatically converted from Godot Engine 4.0.2.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_disabled,unshaded;
uniform sampler2D texture_albedo : source_color,filter_nearest,repeat_disable;
//uniform vec2 resolution = vec2(320.0, 180.0);
global uniform vec2 eliteOverlayResolution;


void fragment() {
	// Do some kind of "anti-aliasing" here
	// Since we want to keep this looking blocky (as was the case with Amiga-Elite),
	// the default interpolation methods do not look too good
	// but also point sampling looks ugly due to uneven "grid".
	// Therefore do "anti-aliasing" only on pixel edges (of low-res source).
	// This looks good enough (tm).
	// (I first tried to match the resolution of the low-res source to
	// some multiple of destination pixels to keep maximum blockiness, but failed).
	// This method causes all kinds of moire and aliasing artifacts when
	// destination res is less than source. But source is 320*whatever, so...
	
	float xCoord1 = SCREEN_UV.x * eliteOverlayResolution.x;
	float xCoord2 = (SCREEN_UV.x + dFdx(SCREEN_UV.x)) * eliteOverlayResolution.x;
	float yCoord1 = SCREEN_UV.y * eliteOverlayResolution.y;
	float yCoord2 = (SCREEN_UV.y + dFdy(SCREEN_UV.y)) * eliteOverlayResolution.y;
	
	float x1Fract = 1.0 - fract(xCoord1);
	float x2Fract = fract(xCoord2);
	float xFractSum = x1Fract + x2Fract;
	vec4 xTexel1 = texelFetch(texture_albedo, ivec2(int(xCoord1), int(yCoord1)), 0);
	vec4 xTexel2 = texelFetch(texture_albedo, ivec2(int(xCoord2), int(yCoord1)), 0);
	vec4 row1 = mix(xTexel2, xTexel1, x1Fract / xFractSum);
	
	xTexel1 = texelFetch(texture_albedo, ivec2(int(xCoord1), int(yCoord2)), 0);
	xTexel2 = texelFetch(texture_albedo, ivec2(int(xCoord2), int(yCoord2)), 0);
	vec4 row2 = mix(xTexel2, xTexel1, x1Fract / xFractSum);

	float y1Fract = 1.0 - fract(yCoord1);
	float y2Fract = fract(yCoord2);
	float yFractSum = y1Fract + y2Fract;

	vec4 val = mix(row2, row1, y1Fract / yFractSum);
//	vec4 val = mix(row1, row1, 0.0);

	ALBEDO = val.rgb;
	ALPHA = val.a;
	
//	ALBEDO = texelFetch(texture_albedo, ivec2(int(xCoord1), int(yCoord1)), 0).rgb;
//	ALBEDO = texture(texture_albedo,SCREEN_UV).rgb;
//	ALPHA = texture(texture_albedo,SCREEN_UV).a;
//	ALPHA = 0.5;

//	ALPHA = max(texture(texture_albedo,SCREEN_UV).a, 0.5);
//	ALBEDO.r = 1.0;
}
