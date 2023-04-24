// NOTE: Shader automatically converted from Godot Engine 4.0.alpha's StandardMaterial3D.

shader_type spatial;
//render_mode blend_mix,depth_draw_opaque,cull_disabled,diffuse_lambert,specular_disabled;
render_mode blend_mix,depth_draw_opaque,diffuse_lambert,specular_disabled,cull_disabled;

instance uniform float basePosY = 0.0;

uniform vec4 albedo : source_color;
uniform float scrollPosY = 0.0;

void vertex() {
	
	VERTEX.y += basePosY + scrollPosY;
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

