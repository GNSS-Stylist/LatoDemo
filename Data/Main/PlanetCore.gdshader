// NOTE: Shader automatically converted from Godot Engine 4.0.2.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_lambert,specular_disabled;
uniform vec4 baseAlbedo : source_color;
uniform vec4 bloodAlbedo : source_color;
uniform float bloodPower = 1.0;
uniform float bloodRange = 0.0;
uniform float time = 0.0;

// Simplex noise, source: https://www.shadertoy.com/view/Msf3WH
// (MIT license)
vec2 hash( vec2 p ) // replace this by something better
{
	p = vec2( dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)) );
	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise( in vec2 p )
{
    const float K1 = 0.366025404; // (sqrt(3)-1)/2;
    const float K2 = 0.211324865; // (3-sqrt(3))/6;

	vec2  i = floor( p + (p.x+p.y)*K1 );
    vec2  a = p - i + (i.x+i.y)*K2;
    float m = step(a.y,a.x); 
    vec2  o = vec2(m,1.0-m);
    vec2  b = a - o + K2;
	vec2  c = a - 1.0 + 2.0*K2;
    vec3  h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
	vec3  n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
    return dot( n, vec3(70.0) );
}

void fragment() {
	vec2 uv = 3.0 * UV + vec2(10.0, 1.0 - time * 0.1);
	vec2 uv2 = 10.0 * UV + vec2(10.0, 1.0 - time * 0.05);
    const mat2 m = mat2(vec2(1.6,  1.2), vec2(-1.2,  1.6) );
	
	float f2 = 0.0;
	f2  = 0.7500*noise( uv2 ); uv2 = m*uv2;
	f2 += 0.2500*noise( uv2 ); uv2 = m*uv2;
//	f += 0.1250*noise( uv ); uv = m*uv;
//	f += 0.1625*noise( uv ); uv = m*uv;
/*	f += 0.1625*noise( uv ); uv = m*uv;
	f += 0.1625*noise( uv ); uv = m*uv;
	f += 0.1625*noise( uv ); uv = m*uv;
	f += 0.1625*noise( uv ); uv = m*uv;
*/

	f2 = 0.5 + f2;

	float f = 0.0;
	
	f  = 0.5000*noise( uv ); uv = m*uv;
	f += 0.5000*noise( uv ); uv = m*uv;
//	f += 0.1250*noise( uv ); uv = m*uv;
//	f += 0.1625*noise( uv ); uv = m*uv;
/*	f += 0.1625*noise( uv ); uv = m*uv;
	f += 0.1625*noise( uv ); uv = m*uv;
	f += 0.1625*noise( uv ); uv = m*uv;
	f += 0.1625*noise( uv ); uv = m*uv;
*/
	f = 0.5 + f;

	ALBEDO = mix(baseAlbedo.rgb, bloodAlbedo.rgb, bloodPower * f * f2 * (1.0 - pow(smoothstep(0.0, bloodRange, (UV.y)), 0.5)));
}
