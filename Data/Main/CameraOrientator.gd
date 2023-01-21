@tool
extends Node3D

@export var yaw:float
@export var pitch:float
@export var roll:float
@export var quatOverride:Quaternion = Quaternion(0,0,0,1)
#@export var useEulerAngles:bool = false
@export var eulerAnglesFraction:float = 0
@export var cloneQuat:bool = false

var lastBasis:Basis

func _process(_delta):
	if (cloneQuat):
		# For editor: This way you can edit the node's quaternion and clone it to "override"
		quatOverride = quaternion
		cloneQuat = false
		
	var eulerQuat = Basis.IDENTITY.rotated(Vector3(0, 0, 1), deg_to_rad(roll)).rotated(Vector3(1, 0, 0), deg_to_rad(pitch)).rotated(Vector3(0, 1, 0), deg_to_rad(-yaw)).orthonormalized()
	var newBasis = Basis(quatOverride.slerp(eulerQuat, eulerAnglesFraction))
	if (newBasis != lastBasis):
		# This if is here because otherwise it is not possible to edit the
		# orientation as @tool-script updates it all the time
		transform.basis = newBasis
		lastBasis = newBasis

#	if useEulerAngles:
#		transform.basis = Basis.IDENTITY.rotated(Vector3(0, 0, 1), deg2rad(roll)).rotated(Vector3(1, 0, 0), deg2rad(pitch)).rotated(Vector3(0, 1, 0), deg2rad(-yaw))
#	else:
#		transform.basis = Basis(quatOverride)
