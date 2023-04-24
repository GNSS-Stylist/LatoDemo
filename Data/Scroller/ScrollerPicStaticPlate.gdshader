// NOTE: Shader automatically converted from Godot Engine 4.0.alpha's StandardMaterial3D.

shader_type spatial;
//render_mode blend_mix,depth_draw_opaque,cull_disabled,diffuse_lambert,specular_disabled;
render_mode blend_mix,depth_draw_opaque,diffuse_lambert,specular_disabled;
uniform vec4 albedo : source_color;
uniform sampler2D albedo_texture : repeat_disable, source_color, filter_linear_mipmap;

instance uniform float basePosY = 0.0;
uniform float scrollPosY = 0.0;

void vertex() {
	VERTEX.y += basePosY + scrollPosY;
}

void fragment() {
	if (UV.x < 0.0) {
		ALBEDO = albedo.rgb;
	}
	else {
		ALBEDO = texture(albedo_texture, UV).rgb;
	}
}

