@tool
extends Node3D

@export var yaw:float
@export var pitch:float
@export var roll:float
@export var quatOverride:Quaternion = Quaternion(0,0,0,1)
#@export var useEulerAngles:bool = false
@export var eulerAnglesFraction:float = 0

func _process(_delta):
	var eulerQuat = Basis.IDENTITY.rotated(Vector3(0, 0, 1), deg2rad(roll)).rotated(Vector3(1, 0, 0), deg2rad(pitch)).rotated(Vector3(0, 1, 0), deg2rad(-yaw)).orthonormalized()
	transform.basis = Basis(quatOverride.slerp(eulerQuat, eulerAnglesFraction))

#	if useEulerAngles:
#		transform.basis = Basis.IDENTITY.rotated(Vector3(0, 0, 1), deg2rad(roll)).rotated(Vector3(1, 0, 0), deg2rad(pitch)).rotated(Vector3(0, 1, 0), deg2rad(-yaw))
#	else:
#		transform.basis = Basis(quatOverride)
