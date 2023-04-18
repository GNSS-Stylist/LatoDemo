@tool
extends "MeshDisintegratorBase.gd"

@export var disintegrationFraction:float:
	set(newFraction):
		if (newFraction != disintegrationFraction):
			smoothMesh.visible = (newFraction == 0)
			disintegratedMesh.visible = (newFraction != 0)
			disintegrationFraction = newFraction
			disintegratedMesh.set_instance_shader_parameter("disintegrationFraction", disintegrationFraction)
	get:
		return disintegrationFraction
