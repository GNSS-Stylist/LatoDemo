extends MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# Tried to do this in the shader, but failed...
	# (moving the halo farther away to get the satellite itself not distracted by it)
	# As this kind-of billboarding is done here anyway, also basis is calculated here

	var camera = get_viewport().get_camera_3d()
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
	global_transform = Transform3D(newBasis.transposed(), newOrigin)
