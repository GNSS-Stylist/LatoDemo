@tool
extends Node3D

@export var antennaRodAngle:float
@export var localTranslation:Vector3
@export var baseAngle:float
@export var collisionObjectEnabled:bool = false

func _process(_delta):
	if (collisionObjectEnabled):
		if ($CharacterBody3D_Rod.process_mode != PROCESS_MODE_INHERIT):
			$CharacterBody3D_Rod.process_mode = PROCESS_MODE_INHERIT
	else:
		if ($CharacterBody3D_Rod.process_mode != PROCESS_MODE_DISABLED):
			$CharacterBody3D_Rod.process_mode = Node.PROCESS_MODE_DISABLED
	
	var newRotation = Vector3(0, 0, -deg_to_rad(antennaRodAngle))
	
	if (newRotation != $GroupTransform/Rod.rotation):
		$GroupTransform/Rod.rotation = newRotation

	var newTransform = Transform3D(Basis.IDENTITY.rotated(Vector3(0, 0, 1), deg_to_rad(baseAngle)), localTranslation)

	if ($GroupTransform.transform != newTransform):
		$GroupTransform.transform = newTransform

#	$GroupTransform.transform.origin = localTranslation
#	$GroupTransform.rotation = Vector3(0, 0, deg_to_rad(baseAngle))

func _physics_process(_delta):
	if ($CharacterBody3D_Rod.global_transform != $GroupTransform/Rod/AntennaRod.global_transform):
		$CharacterBody3D_Rod.global_transform = $GroupTransform/Rod/AntennaRod.global_transform
