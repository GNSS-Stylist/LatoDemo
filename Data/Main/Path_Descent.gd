@tool
extends Path3D

@export var flyDistance:float = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if (get_parent() is Node3D):	# type check needed for editor
		global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, -flyDistance))
