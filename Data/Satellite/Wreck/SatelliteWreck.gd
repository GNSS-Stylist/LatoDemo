@tool
extends Node3D

@export var scopeLightEnergy:float = 1
@export var scopeLightColor:Color = Color(0, 1, 0)

var mainWreckRotationMutex:Mutex = Mutex.new()
@export var mainWreckRotation:float = 0:
	set(newRotation):
		# Physics running in another thread
		mainWreckRotationMutex.lock()
		mainWreckRotation = newRotation
		mainWreckRotationMutex.unlock()
	get:
		return mainWreckRotation

func _process(delta):
	if ((!Global) ||(Engine.is_editor_hint() && Global.cleanTempToolData)):
		return

	$MainWreck/DishAntenna/ScopeLight.visible = true
	$MainWreck/DishAntenna/ScopeLight.light_energy = Global.lowPassFilteredSoundAmplitudeData[Global.masterReplayTime * 8000] * scopeLightEnergy
	$MainWreck/DishAntenna/ScopeLight.light_color = scopeLightColor

var oldRotation:float = 0
func _physics_process(delta):
	mainWreckRotationMutex.lock()
	var newRotation = mainWreckRotation
	mainWreckRotationMutex.unlock()

	if (newRotation != oldRotation):
		$MainWreck.rotation_degrees = Vector3(0, newRotation, 0)
		oldRotation = newRotation
