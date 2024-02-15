@tool
extends Node3D

@export var maxAcceleration:float = 1:
	set (newMaxAcceleration):
		maxAcceleration = newMaxAcceleration
		$HallThruster_XPlus.maxAcceleration = maxAcceleration
		$HallThruster_YPlus.maxAcceleration = maxAcceleration
		$HallThruster_YMinus.maxAcceleration = maxAcceleration
		$HallThruster_ZPlus.maxAcceleration = maxAcceleration
		$HallThruster_ZMinus.maxAcceleration = maxAcceleration
	get:
		return maxAcceleration
		
@export var globalSpeedFilterCoeff:float = 1.0:
	set (newFilterCoeff):
		globalSpeedFilterCoeff = newFilterCoeff
		$HallThruster_XPlus.globalSpeedFilterCoeff = globalSpeedFilterCoeff
		$HallThruster_YPlus.globalSpeedFilterCoeff = globalSpeedFilterCoeff
		$HallThruster_YMinus.globalSpeedFilterCoeff = globalSpeedFilterCoeff
		$HallThruster_ZPlus.globalSpeedFilterCoeff = globalSpeedFilterCoeff
		$HallThruster_ZMinus.globalSpeedFilterCoeff = globalSpeedFilterCoeff
	get:
		return globalSpeedFilterCoeff

# Called when the node enters the scene tree for the first time.
func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(_delta):
#	print("_process, ", self.name)
#	pass
