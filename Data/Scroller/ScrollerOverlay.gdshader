// NOTE: Shader automatically converted from Godot Engine 4.0.2.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,unshaded;
uniform sampler2D texture_albedo : source_color,filter_nearest,repeat_disable;

void fragment() {
	ALBEDO = texture(texture_albedo,SCREEN_UV).rgb;
//	ALBEDO = vec3(0.0);
	ALPHA = texture(texture_albedo,SCREEN_UV).a;
//	ALPHA = 0.5;

//	ALPHA = max(texture(texture_albedo,SCREEN_UV).a, 0.5);
//	ALBEDO.r = 1.0;
}
