@tool
extends Node3D

@export var anchorNodePath:NodePath

func _process(delta):
	if (!anchorNodePath.is_empty() && get_node(anchorNodePath)):
		var anchorNode:Node3D = get_node(anchorNodePath)
		self.transform = Transform3D(self.basis, anchorNode.global_transform.origin)
