@tool
extends Node
class_name RemoteVisibility

# This is just a simple helper class to clone visibility of a node to another
# (Naming and functionality mimicked from RemoteTransform3D)

@export var remotePath:NodePath

func _process(delta):
	var remoteNode = get_node_or_null(remotePath)
	if (remoteNode && (remoteNode is Node3D)):
		remoteNode.visible = get_parent().is_visible_in_tree()
