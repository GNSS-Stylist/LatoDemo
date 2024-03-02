extends AudioStreamPlayer3D

class_name SpaceSoundEmitter

@export var speedOfSound:float = 3000
@export var sustainVolume:float = 10
@export var attackTime:float = 0.1
@export var attackStartVolume = -50
@export var decayTime:float = 0.2
@export var decayEndVolume = -50
@export var enabled:bool = true
@export var basePitch:float = 1.0
@export var distanceChangeFilterCoeff:float = 0.01

func _ready():
	pass # Replace with function body.

var attackElapsed:float = 0
var decayElapsed:float = 0
var lastCameraDistance:float = 0

enum EnvelopeState
{
	NONE,
	ATTACK,
	SUSTAIN,
	PAUSED,
	DECAY,
}

var state:EnvelopeState = EnvelopeState.NONE

var distanceChangeFilterStorage:float = 0

func _physics_process(delta):
	var currentCameraDistance:float = self.global_position.distance_to(get_viewport().get_camera_3d().global_position)
#	var distanceChangeInstantaneousSpeed = clamp((currentCameraDistance - lastCameraDistance) / delta, -speedOfSound, speedOfSound)
	var distanceChangeInstantaneousSpeed = (currentCameraDistance - lastCameraDistance) / delta

	if (absf(distanceChangeInstantaneousSpeed) >= speedOfSound):
		distanceChangeInstantaneousSpeed = 0

	var filterCoeff = pow(distanceChangeFilterCoeff, delta)

	var distanceChangeSpeed = (distanceChangeFilterStorage * filterCoeff +
		(1.0 - filterCoeff) * distanceChangeInstantaneousSpeed)
	
	distanceChangeFilterStorage = distanceChangeSpeed
	
	if (enabled):
#		if (distanceChangeSpeed <= -speedOfSound):
			# Approaching faster than the speed of sound
			# As in reality this would generate a mach cone and delayed sonic boom,
			# just limit pitch_scale to some value.
			# (now limited earlier so no need for this...)
#			pitch_scale = 5 * basePitch
#		else:
		var newPitch = speedOfSound / (speedOfSound + distanceChangeSpeed)
		pitch_scale = clamp(newPitch, 0.1, 5.0) * basePitch
#			print (pitch_scale)
	else:
		state = EnvelopeState.NONE
		
	var tempVolume:float = -100
	
	match (state):
		EnvelopeState.NONE:
			if (self.is_visible_in_tree() && enabled):
				# Initialize things, play will start on the next _physics_process
				attackElapsed = 0
				tempVolume = attackStartVolume
				stream_paused = false
				state = EnvelopeState.ATTACK
				play()
			else:
				tempVolume = -100
				stop()
		
		EnvelopeState.ATTACK:
			if (self.is_visible_in_tree()):
				if (attackElapsed >= attackTime):
					state = EnvelopeState.SUSTAIN
					tempVolume = sustainVolume
				else:
					tempVolume = attackStartVolume + ((sustainVolume - attackStartVolume) * attackElapsed / attackTime)
			else:
				tempVolume = attackStartVolume + ((sustainVolume - attackStartVolume) * attackElapsed / attackTime)
				state = EnvelopeState.DECAY
				decayElapsed = decayTime * (1.0 - (attackElapsed / attackTime))
			
			attackElapsed += delta
		
		EnvelopeState.SUSTAIN:
			if (self.is_visible_in_tree()):
				tempVolume = sustainVolume
			else:
				tempVolume = sustainVolume
				decayElapsed = 0
				state = EnvelopeState.DECAY
		
		EnvelopeState.DECAY:
			if (self.is_visible_in_tree()):
				attackElapsed = attackTime * (1.0 - (decayElapsed / decayTime))
				state = EnvelopeState.ATTACK
			else:
				if (decayElapsed >= decayTime):
					state = EnvelopeState.NONE
					tempVolume = -100
				else:
					tempVolume = sustainVolume - (sustainVolume - decayEndVolume) * (decayElapsed / decayTime)
			
			decayElapsed += delta
				
	
	if (Global.muted):
		tempVolume = -100
	
	volume_db = tempVolume

	lastCameraDistance = currentCameraDistance
