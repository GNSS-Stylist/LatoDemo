extends MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready():
	await get_tree().process_frame

	material_override.set_shader_parameter("startOrigin_Object", Vector3(mesh.size.x / 2, 0, 0) + mesh.center_offset)
	material_override.set_shader_parameter("endOrigin_Object", Vector3(-mesh.size.x / 2, 0, 0) + mesh.center_offset)
	material_override.set_shader_parameter("soundDataSampler", get_node("/root/Main/EKGScopeDataStorage").imageTexture)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(_delta):
#	pass
