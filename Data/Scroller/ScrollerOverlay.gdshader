// NOTE: Shader automatically converted from Godot Engine 4.0.2.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,unshaded;
uniform sampler2D texture_albedo : source_color,filter_nearest,repeat_disable;

// Kernel for gaussian "edge shadow" to make text easier to read
// against light background (like space station)
// This is from:
// https://godotshaders.com/shader/edge-detection-sobel-filter-and-gaussian-blur/
const float gauss[25] = {
		0.00390625, 	0.015625, 	0.0234375, 	0.015625, 	0.00390625,
		0.015625, 		0.0625, 	0.09375, 	0.0625, 	0.015625, 
		0.0234375, 		0.09375, 	0.140625, 	0.09375, 	0.0234375,
		0.015625, 		0.0625, 	0.09375, 	0.0625, 	0.015625,
		0.00390625,		0.015625, 	0.0234375, 	0.015625, 	0.00390625
};

const float multiplier = 5.0;

void fragment() {
	ALBEDO = texture(texture_albedo,SCREEN_UV).rgb;
//	ALBEDO = vec3(0.0);
	ALPHA = texture(texture_albedo,SCREEN_UV).a;
	
//	float pixel_size_x = 1.0 / float(VIEWPORT_SIZE.x);
//	float pixel_size_y = 1.0 / float(VIEWPORT_SIZE.y);
// Const pixel sizes to keep "shadow" same size in different resolutions
// This is dirty, but not able to think how to do this "right" right now...
	float pixel_size_x = 1.0 / 1920.0;
	float pixel_size_y = 1.0 / 1080.0;
	
	if (ALPHA != 1.0) {
		for (int row = 0; row < 5; row++) {
				for (int col = 0; col < 5; col++) {
					ALPHA += texture(texture_albedo, SCREEN_UV + vec2(float(col - 2) * pixel_size_x, float(row - 2) * pixel_size_y)).a * gauss[row * 5 + col];
				}
			}
		}
		ALPHA = clamp(ALPHA * multiplier, 0.0, 1.0);

//	ALPHA = 0.5;

//	ALPHA = max(texture(texture_albedo,SCREEN_UV).a, 0.5);
//	ALBEDO.r = 1.0;
}
