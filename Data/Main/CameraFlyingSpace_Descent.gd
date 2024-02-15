@tool
extends Node3D

@export var anchorNodePath:NodePath

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	pass
	
func _process(_delta):
	if (!anchorNodePath.is_empty() && get_node(anchorNodePath)):
		var anchorNode:Node3D = get_node(anchorNodePath)
		self.global_transform = Transform3D(self.basis, anchorNode.global_transform.origin)
