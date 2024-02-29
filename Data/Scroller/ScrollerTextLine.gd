@tool
extends MeshDisintegratorBase
class_name ScrollerTextLine

enum ShownMesh { NONE, SMOOTH, DISINTEGRATED }

@export var basePosY:float:
	set(newPos):
		if (smoothMesh && disintegratedMesh):
			disintegratedMesh.set_instance_shader_parameter("basePosY",newPos)
			smoothMesh.set_instance_shader_parameter("basePosY",newPos)
		basePosY = newPos
	get:
		return basePosY

@export var shownMesh:ShownMesh = ShownMesh.NONE:
	set(newShownMesh):
		shownMesh = newShownMesh
		if (disintegratedMesh && smoothMesh):
			disintegratedMesh.visible = (newShownMesh == ShownMesh.DISINTEGRATED)
			smoothMesh.visible = (newShownMesh == ShownMesh.SMOOTH)

		self.visible = (newShownMesh != ShownMesh.NONE)
	get:
		return shownMesh

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	super._ready()
	disintegratedMesh.set_instance_shader_parameter("basePosY",basePosY)
	smoothMesh.set_instance_shader_parameter("basePosY",basePosY)
