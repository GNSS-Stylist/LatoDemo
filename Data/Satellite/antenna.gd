@tool
extends Node3D

@export var antennaRodAngle:float = 10:
	get:
		return antennaRodAngle
	set(newAngle):
		antennaRodAngle = newAngle
	
@export var localTranslation: Vector3:
	get:
		return localTranslation
	set(newLocalTranslation):
		localTranslation = newLocalTranslation

@export var baseAngle: float:
	get:
		return baseAngle
	set(newBaseAngle):
		baseAngle = newBaseAngle

func _process(_delta):
	#Accessing children is apparently not possible since
	# it causes "Invalid set index 'foo' (on base: 'null instance')
	# So the children have not been created yet?
	$GroupTransform/Rod.rotation = Vector3(0, 0, -deg_to_rad(antennaRodAngle))
	$GroupTransform.transform.origin = localTranslation
	$GroupTransform.rotation = Vector3(0, 0, deg_to_rad(baseAngle))
