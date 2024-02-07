@tool
extends Node3D

@export var angle:float = 0
@export var height:float = 1999
@export var distance:float = 1
@export var quat:Quaternion = Quaternion.IDENTITY
@export var cloneQuat:bool = false

var lastTransform:Transform3D

func _process(_delta):
	if (cloneQuat):
		# For editor: This way you can edit the node's quaternion and clone it to "override"
		quat = quaternion
		cloneQuat = false

	var newTransform = Transform3D(Basis(quat), Vector3(sin(deg_to_rad(angle)) * distance, cos(deg_to_rad(angle)) * distance, height))

	if (newTransform != lastTransform):
		# This if is here because otherwise it is not possible to edit the
		# orientation as @tool-script updates it all the time
		transform = newTransform
		lastTransform = newTransform
