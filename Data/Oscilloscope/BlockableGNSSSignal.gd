#@tool
extends Node3D

#var initDone:bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	# Not sure if this is needed:
	await get_tree().process_frame

	$Surface.material_override = Global.blockableGNSSSignalMaterial
	$Surface.material_override.set_shader_param("startOrigin_Object", Vector3($Surface.mesh.size.x / 2, 0, 0) + $Surface.mesh.center_offset)
	$Surface.material_override.set_shader_param("endOrigin_Object", Vector3(-$Surface.mesh.size.x / 2, 0, 0) + $Surface.mesh.center_offset)

#func _process(_delta):
# Another hack: When physics are disabled (due to scaling breaking it)
# raycasting is _physics_process is not ran.
# So show all signals when physics is disabled

# no get_active here...........
#	if (!PhysicsServer3D.get_active()):
#		$Surface.visible = true
		
# NOTE: These are not set here since the same material is shared between
# all instances of this class. So you can't have different signals this way, 
# sorry (not sorry)
#	if (Global.soundDataTexture != null) && (!initDone):
#		$Surface.material_override.set_shader_param("soundDataSampler", Global.soundDataTexture)
#		initDone = true
#	$Surface.material_override.set_shader_param("startOrigin_Object", Vector3($Surface.mesh.size.x / 2, 0, 0) + $Surface.mesh.center_offset)
#	$Surface.material_override.set_shader_param("endOrigin_Object", Vector3(-$Surface.mesh.size.x / 2, 0, 0) + $Surface.mesh.center_offset)

func _physics_process(_delta):
	var space_state = get_world_3d().direct_space_state
	# use global coordinates, not local to node
	var params:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	params.from = self.global_transform.origin
	params.to = self.global_transform.origin - global_transform.basis.x * 20
	var result = space_state.intersect_ray(params)
	$Surface.visible = result.is_empty()
