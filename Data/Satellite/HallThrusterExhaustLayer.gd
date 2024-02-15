@tool
extends Node3D

var material:Material:
	get:
		return material
	set(newMaterial):
		material = newMaterial
		$ExhaustCombiner.material_override = newMaterial

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
