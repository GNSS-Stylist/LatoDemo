@tool
extends MeshDisintegratorBase
class_name ScrollerTextLine

enum ShownMesh { SMOOTH, DISINTEGRATED }

@export var basePosY:float:
	set(newPos):
		if (smoothMesh && disintegratedMesh):
			disintegratedMesh.set_instance_shader_parameter("basePosY",newPos)
			smoothMesh.set_instance_shader_parameter("basePosY",newPos)
		basePosY = newPos
	get:
		return basePosY

@export var shownMesh:ShownMesh = ShownMesh.DISINTEGRATED:
	set(newShownMesh):
		shownMesh = newShownMesh
		if (disintegratedMesh && smoothMesh):
			disintegratedMesh.visible = (newShownMesh == ShownMesh.DISINTEGRATED)
			smoothMesh.visible = (newShownMesh == ShownMesh.SMOOTH)
	get:
		return shownMesh

func _ready():
	super._ready()
	disintegratedMesh.set_instance_shader_parameter("basePosY",basePosY)
	smoothMesh.set_instance_shader_parameter("basePosY",basePosY)
