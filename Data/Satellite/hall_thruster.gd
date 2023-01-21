@tool
extends Node3D

@export var maxAcceleration:float = 1
@export var exhaustMaterial:Material
@export var exhaustAlphaOverride:float = -1
@export var globalSpeedFilterCoeff:float = 1.0

const lightIntensityMultiplier:float = 10

var prevGlobalTranslation:Vector3
var prevVelocityAlongLocalYAxis:float = 0
var prevAccelerationAlongLocalYAxis:float = 0
var filteredAccelerationAlongLocalYAxis:float = 0

var instanceExhaustMaterial:Material

func _ready():
	instanceExhaustMaterial = exhaustMaterial.duplicate()
	$HallEffectExhaustLayerCluster.material = instanceExhaustMaterial

#var filteredVelocityAlongLocalYAxis:float = 0

func _process(delta):
#	print("_process, ", self.name)

	
	# I just couldn't get delta-independent handling/filtering work
	# -> Therefore this super-ugly "constant(ish) delta"-solution.
	# (There was severe flickering without this)

#	accumulatedDelta += delta
#	if (accumulatedDelta < 0.1):
#		return
#	delta = accumulatedDelta
#	accumulatedDelta = 0
	
	var globalTranslation:Vector3 = global_transform.origin
	var globalVelocity:Vector3 = (globalTranslation - prevGlobalTranslation) / delta
	prevGlobalTranslation = globalTranslation
	
	var velocityAlongLocalYAxis:float = global_transform.basis.y.dot(globalVelocity)
	
	var accelerationAlongLocalYAxis:float = clampf(velocityAlongLocalYAxis - prevVelocityAlongLocalYAxis, -10, 10)

	var timeCorrectedFilterCoeff:float = pow(globalSpeedFilterCoeff, delta)

	filteredAccelerationAlongLocalYAxis = (accelerationAlongLocalYAxis * (1 - timeCorrectedFilterCoeff) +
			filteredAccelerationAlongLocalYAxis * timeCorrectedFilterCoeff)

		
	if (exhaustAlphaOverride < 0):
		instanceExhaustMaterial.albedo_color.a = clampf(filteredAccelerationAlongLocalYAxis * maxAcceleration, 0, 1)
	else:
		instanceExhaustMaterial.albedo_color.a = exhaustAlphaOverride
	
	var lightEnergy = max(filteredAccelerationAlongLocalYAxis * lightIntensityMultiplier, 0)
	
	if (lightEnergy < 0.01):
		$OmniLight3D.light_energy = 0
		$OmniLight3D.visible = false
	else:
		$OmniLight3D.light_energy = lightEnergy
		$OmniLight3D.visible = true
#	mat.albedo_color.a = 0.1

#	print (clampf(relativeAcceleration, 0, 1))




















var filteredGlobalSpeed:Vector3
var accumulatedDelta:float = 0

func _processoraatio(delta):
	# I just couldn't get delta-independent handling/filtering work
	# -> Therefore this super-ugly "constant(ish) delta"-solution.
	# (There was severe flickering without this)
	accumulatedDelta += delta
	if (accumulatedDelta < 0.1):
		return
		
	delta = accumulatedDelta
	accumulatedDelta = 0
	
	var globalTranslation:Vector3 = global_transform.origin
	var globalSpeed:Vector3 = (globalTranslation - prevGlobalTranslation) * (1 / delta)
	
	var lastFilteredGlobalSpeed:Vector3 = filteredGlobalSpeed
	
	var timeCorrectedFilterCoeff = pow(globalSpeedFilterCoeff, delta)

	filteredGlobalSpeed = ((1.0 - timeCorrectedFilterCoeff) * filteredGlobalSpeed +
			timeCorrectedFilterCoeff * globalSpeed)
	
	var globalAcceleration:Vector3 = filteredGlobalSpeed - lastFilteredGlobalSpeed

	prevGlobalTranslation = globalTranslation

	var globalUnitY:Vector3 = global_transform.basis.y.normalized()
	var accelerationOnLocalYAxis = -globalAcceleration.dot(globalUnitY)
	
	var relativeAcceleration = accelerationOnLocalYAxis / maxAcceleration
		
	if (exhaustAlphaOverride < 0):
		instanceExhaustMaterial.albedo_color.a = clampf(relativeAcceleration, 0, 1)
	else:
		instanceExhaustMaterial.albedo_color.a = exhaustAlphaOverride
		
	$OmniLight3D.light_energy = max(accelerationOnLocalYAxis * lightIntensityMultiplier, 0)
#	mat.albedo_color.a = 0.1

#	print (clampf(relativeAcceleration, 0, 1))
	
	
	
