@tool
extends Node3D

@export var solarPanelFraction:float

func _ready():
	$AnimationPlayer_SolarPanel.current_animation = "SolarPanelConstruction"

func _process(_delta):
	if ((!Global) ||(Engine.is_editor_hint() && Global.cleanTempToolData)):
		return

	if ($AnimationPlayer_SolarPanel.current_animation_position != clamp(solarPanelFraction, 0, 1)):
		$AnimationPlayer_SolarPanel.seek(clamp(solarPanelFraction, 0, 1))
