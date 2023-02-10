@tool
extends Node3D

@export var yaw:float
@export var pitch:float
@export var roll:float
@export var quatOverride:Quaternion = Quaternion(0,0,0,1)
#@export var useEulerAngles:bool = false
@export var eulerAnglesFraction:float = 0
@export var cloneQuat:bool = false
@export var cloneEulerYawRounds:int = 0
@export var cloneEuler:bool = false

@export var lookAtPathFollowNodePath:NodePath
@export var lookAtRoll:float
@export var lookAtFraction:float

# "Priority of fractions":
# First rotation is calculated based on quaternion
# Then it is slerped to the direction calculated from euler angles by eulerAnglesFraction
# Then it is slerped to the direction calculated from lookAt by lookAtFraction

var lastBasis:Basis

func _process(_delta):
	if (cloneQuat):
		# For editor: This way you can edit the node's quaternion and clone it to "override"
		quatOverride = quaternion
		cloneQuat = false
	
	if (cloneEuler):
		# For editor: This way you can edit the node's euler angles and clone them
		var eulers:Vector3 = quaternion.get_euler(EULER_ORDER_YXZ)
		yaw = -(rad_to_deg(eulers.y) + cloneEulerYawRounds * 360.0)
		pitch = rad_to_deg(eulers.x)
		roll = rad_to_deg(eulers.z)
		cloneEuler = false

	var eulerQuat = Basis.IDENTITY.rotated(Vector3(0, 0, 1), deg_to_rad(roll)).rotated(Vector3(1, 0, 0), deg_to_rad(pitch)).rotated(Vector3(0, 1, 0), deg_to_rad(-yaw)).orthonormalized()
	var newBasis = Basis(quatOverride.slerp(eulerQuat, eulerAnglesFraction))

	if (!lookAtPathFollowNodePath.is_empty()):
		# TODO: calculate up based on roll (or rotate afterwards?)
		var lookAtNode = get_node(lookAtPathFollowNodePath)
		var up = Vector3(0, 1, 0)
		var lookingAtTransform = self.global_transform.looking_at(lookAtNode.global_transform.origin, up)
		newBasis = Basis(newBasis.slerp(lookingAtTransform.basis, lookAtFraction))

	if (newBasis != lastBasis):
		# This if is here because otherwise it is not possible to edit the
		# orientation as @tool-script updates it all the time
		transform.basis = newBasis
		lastBasis = newBasis

#	if useEulerAngles:
#		transform.basis = Basis.IDENTITY.rotated(Vector3(0, 0, 1), deg2rad(roll)).rotated(Vector3(1, 0, 0), deg2rad(pitch)).rotated(Vector3(0, 1, 0), deg2rad(-yaw))
#	else:
#		transform.basis = Basis(quatOverride)
