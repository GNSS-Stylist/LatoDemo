shader_type spatial;

render_mode blend_mix,unshaded;

instance uniform float leadingEdge = 1.0;
instance uniform float trailingEdge = 0.0;

instance uniform vec3 albedo : source_color;

void vertex() {
	// This is based on an assumption that the beam mesh is actually
	// a CylinderMesh flipped to Z-axis by Transform
	// Therefore operating on Y-coords here.

	// Some clamping here as the mesh is a CylinderMesh that extends to both sides
	float y = clamp(VERTEX.y, 0.0, 1.0);
	
	y = trailingEdge + (leadingEdge - trailingEdge) * y;
	
	VERTEX.y = y;
}

void fragment() {
	ALBEDO = albedo;
}
