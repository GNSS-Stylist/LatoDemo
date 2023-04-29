// NOTE: Shader automatically converted from Godot Engine 4.0.alpha's StandardMaterial3D.

shader_type spatial;

instance uniform float basePosY = 0.0;
instance uniform int textureIndex = 0;
instance uniform float preXShift = 0.0;

//render_mode blend_mix,depth_draw_opaque,cull_disabled,diffuse_lambert,specular_disabled;
render_mode blend_mix,depth_draw_opaque,diffuse_lambert,specular_disabled,cull_disabled;
uniform vec4 albedo : source_color;
uniform sampler2D albedoTextures[8] : source_color;	// : repeat_disable, source_color, filter_linear_mipmap;

//uniform float endScrollerYPos = 0.0;
global uniform float endScrollerYPos;

void vertex() {
	VERTEX.y += basePosY + endScrollerYPos;
	VERTEX.x += preXShift;
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

