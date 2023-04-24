@tool
extends MeshDisintegratorBase
class_name ScrollerTextLine

@export var basePosY:float:
	set(newPos):
		disintegratedMesh.set_instance_shader_parameter("basePosY",newPos)
		basePosY = newPos
	get:
		return basePosY
