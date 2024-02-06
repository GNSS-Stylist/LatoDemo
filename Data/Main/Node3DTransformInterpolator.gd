@tool
extends Node3D

@export var sourceNodePath:NodePath
@export var destinationNodePath:NodePath
@export_range(0, 1) var fraction:float

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var sourceNode:Node3D = get_node_or_null(sourceNodePath)
	var destNode:Node3D = get_node_or_null(destinationNodePath)
	
	if (sourceNode && destNode && (sourceNode is Node3D) && (destNode is Node3D)):
		self.global_position = sourceNode.global_position + (destNode.global_position - sourceNode.global_position) * fraction
		self.global_transform.basis = Basis(Quaternion(sourceNode.global_transform.basis.get_rotation_quaternion()).slerp(Quaternion(destNode.global_transform.basis.get_rotation_quaternion()), fraction))