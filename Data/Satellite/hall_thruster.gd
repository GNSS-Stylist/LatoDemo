#@tool
extends Node3D

@export var maxAcceleration:float = 1
@export var exhaustMaterial:Material
@export var exhaustAlphaOverride:float = -1
@export var globalSpeedFilterCoeff:float = 1.0

const lightIntensityMultiplier:float = 10

var prevGlobalTranslation:Vector3

var instanceExhaustMaterial:StandardMaterial3D

func _ready():
	instanceExhaustMaterial = exhaustMaterial.duplicate()
	$HallEffectExhausLayerCluster.material = instanceExhaustMaterial

var filteredVelocityAlongLocalYAxis:float = 0

func _process(delta):
	# I just couldn't get delta-independent handling/filtering work
	# -> Therefore this super-ugly "constant(ish) delta"-solution.
	# (There was severe flickering without this)

#	accumulatedDelta += delta
#	if (accumulatedDelta < 0.1):
#		return
#	delta = accumulatedDelta
#	accumulatedDelta = 0
	
	var globalTranslation:Vector3 = global_transform.origin
	var globalVelocity:Vector3 = (globalTranslation - prevGlobalTranslation) * (1 / delta)
	
	var instantaneousVelocityAlongLocalYAxis = global_transform.basis.y.dot(globalVelocity)
	
	var timeCorrectedFilterCoeff = pow(globalSpeedFilterCoeff, delta)

	var lastFilteredVelocityAlongLocalYAxis = filteredVelocityAlongLocalYAxis

	filteredVelocityAlongLocalYAxis = (timeCorrectedFilterCoeff * filteredVelocityAlongLocalYAxis +
			(1.0 - timeCorrectedFilterCoeff) * instantaneousVelocityAlongLocalYAxis)
	
	prevGlobalTranslation = globalTranslation

	var accelerationAlongLocalYAxis = -(filteredVelocityAlongLocalYAxis - lastFilteredVelocityAlongLocalYAxis)
	
	var relativeAcceleration = accelerationAlongLocalYAxis / maxAcceleration
		
	if (exhaustAlphaOverride < 0):
		instanceExhaustMaterial.albedo_color.a = clampf(relativeAcceleration, 0, 1)
	else:
		instanceExhaustMaterial.albedo_color.a = exhaustAlphaOverride
		
	$OmniLight3D.light_energy = max(relativeAcceleration * lightIntensityMultiplier, 0)
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
	
	
	
