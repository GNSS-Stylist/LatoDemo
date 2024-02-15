@tool
extends MeshInstance3D

@export var editorCameraPath:NodePath

# Called when the node enters the scene tree for the first time.
func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if ((!Global) ||(Engine.is_editor_hint() && Global.cleanTempToolData)):
		return
		
	# Tried to do this in the shader, but failed...
	# (moving the halo farther away to get the satellite itself not distracted by it)
	# As this kind-of billboarding is done here anyway, also basis is calculated here

	var camera:Camera3D = null
	
	if (Engine.is_editor_hint()):
		if (!editorCameraPath.is_empty()):
			camera = get_node(editorCameraPath)
	else:
		camera = get_viewport().get_camera_3d()
		
	if (camera):
		var cameraTransform = camera.global_transform
		var newBasisZ = -(get_parent().global_transform.origin - cameraTransform.origin).normalized()
		var newOrigin = (get_parent().global_transform.origin + 
				newBasisZ * -10)
		var newBasisX = newBasisZ.cross(cameraTransform.basis.y).normalized()
		var newBasis = Basis(
				newBasisX,
				newBasisX.cross(newBasisZ).normalized(),
				newBasisZ
		)

	# Already forgot that basis is transposed here
	# (deja vu from LOScriptReplayer after finding out again)
	# (took me an hour to realize...)

#	global_transform = Transform3D(newBasis.transposed(), newOrigin)
# ... But it changed back to non-transposed sometime before 3-sep-2022. :D
# (this time it only took like 10 mins to realize! :D )
		global_transform = Transform3D(newBasis, newOrigin)
