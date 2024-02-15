@tool
extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# Something broke in godot sometime around oct-2022 (or so) and
	# the global_translate below doesn't work any more.
	# (Likely related to handling of top level-property)
	# Replacing with recalculated global transform instead
	#global_translate(get_parent().global_transform.origin - global_transform.origin)

	if (get_parent() is Node3D):	# type check needed for editor
		global_transform = Transform3D(Basis.IDENTITY, get_parent().global_transform.origin)
