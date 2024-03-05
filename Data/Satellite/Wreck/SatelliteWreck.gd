@tool
extends Node3D

@export var scopeLightEnergy:float = 1
@export var scopeLightColor:Color = Color(0, 1, 0)
@export var randomDebrisMaxLinearVelocity:Vector3 = Vector3(0.03, 0.03, 0.03)
@export var randomDebrisMaxAngularVelocity:Vector3 = Vector3(0.1, 0.1, 0.1)
@export var randomDebrisMaxPos:Vector3 = Vector3(3, 3, 3)

@export var debrisVisible:bool
@export var debrisActive:bool

@export var mainWreckRotation:float = 0:
	set(newRotation):
		# Physics running in another thread
		mainWreckRotationMutex.lock()
		mainWreckRotation = newRotation
		mainWreckRotationMutex.unlock()
	get:
		return mainWreckRotation

@export var randomDebrisSeed:int = 0

@export var regenDebrisIfNeeded:bool = false:
	set(trig):
		print("Triggered")
		if (physicsProcessCalledAfterRegeneratingDebris && trig):
			# Only regenerate debris if physics process was run after
			# last generation. This is to prevent regenerating them unnecessarily on the
			# fly, causing a stutter (they are generated on originally on _ready)
			# This was added to be able to rewind
			regeneratePredefinedDebris()
			regenerateRandomDebris()
			physicsProcessCalledAfterRegeneratingDebris = false
			regenDebrisIfNeeded = trig
			print("Wreck: (Re)generating debris")
	get:
		return regenDebrisIfNeeded

@export var dbg_RegenDebris_Force:bool = false:
	set(trig):
		if (trig):
			regeneratePredefinedDebris()
			regenerateRandomDebris()
			physicsProcessCalledAfterRegeneratingDebris = false
	get:
		return 0

var RigidBodySolarCell = preload("res://Data/Satellite/Wreck/RigidBodySolarCell.tscn")
#var DebrisField = preload("res://Data/Satellite/Wreck/DebrisField.tscn")

@onready var mainWreck = get_node("MainWreck")
@onready var scopeLight = get_node("MainWreck/DishAntenna/ScopeLight")

var mainWreckRotationMutex:Mutex = Mutex.new()
var physicsProcessCalledAfterRegeneratingDebris:bool = false

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	regeneratePredefinedDebris()
	regenerateRandomDebris()
	physicsProcessCalledAfterRegeneratingDebris = false

	mainWreck.rotation_degrees = Vector3(0, mainWreckRotation, -45)
	oldRotation = mainWreckRotation

#	myRandInit(2314234)
	
#	for i in range(150):
#		var newSolarCell = RigidBodySolarCell.instantiate()
#		newSolarCell.transform = Transform3D(Basis(Vector3(myRandf(), myRandf(), myRandf()), Vector3(myRandf(), myRandf(), myRandf()), Vector3(myRandf(), myRandf(), myRandf())).orthonormalized(), Vector3(myRandf_range(-3, 3), myRandf_range(-1, 1), myRandf_range(-3, 3)))
#		newSolarCell.linear_velocity = Vector3(myRandf_range(-0.1, 0.1), myRandf_range(-0.1, 0.1), myRandf_range(-0.1, 0.1))
#		newSolarCell.angular_velocity = Vector3(myRandf_range(-0.1, 0.1), myRandf_range(-0.1, 0.1), myRandf_range(-0.1, 0.1))
#		$Debris.add_child(newSolarCell)

func _process(_delta):
	if ((!Global) ||(Engine.is_editor_hint() && Global.cleanTempToolData)):
		return

	scopeLight.visible = true
	scopeLight.light_energy = Global.lowPassFilteredSoundAmplitudeData[min(Global.masterReplayTime * 8000, Global.lowPassFilteredSoundAmplitudeData.size()-1)] * scopeLightEnergy
	scopeLight.light_color = scopeLightColor
	

var oldRotation:float = 0
func _physics_process(_delta):
	mainWreckRotationMutex.lock()
	var newRotation = mainWreckRotation
	mainWreckRotationMutex.unlock()

	if (newRotation != oldRotation):
		mainWreck.rotation_degrees = Vector3(0, newRotation, -45)
		oldRotation = newRotation
	
	if (!Engine.is_editor_hint() && debrisActive && Global.demoState == Global.DemoState.DS_RUNNING):
#		print("Wreck physics_process called, enabled")
		physicsProcessCalledAfterRegeneratingDebris = true
	
	var predefinedDebris:Node3D = get_node_or_null("PredefinedDebris")
	var randomDebris:Node3D = get_node_or_null("RandomDebris")
	if (predefinedDebris && randomDebris):
		predefinedDebris.visible = debrisVisible
		randomDebris.visible = debrisVisible
		if (debrisActive && Global.demoState == Global.DemoState.DS_RUNNING):
			predefinedDebris.process_mode = Node.PROCESS_MODE_INHERIT
			randomDebris.process_mode = Node.PROCESS_MODE_INHERIT
		else:
			predefinedDebris.process_mode = Node.PROCESS_MODE_DISABLED
			randomDebris.process_mode = Node.PROCESS_MODE_DISABLED

func regeneratePredefinedDebris():
	var predefinedDebris:Node3D = get_node_or_null("PredefinedDebris")
	
	if (predefinedDebris):
		self.remove_child(predefinedDebris)
		predefinedDebris.queue_free()
	
#	predefinedDebris = DebrisField.instantiate()
	var debrisScene = load("res://Data/Satellite/Wreck/DebrisField.tscn")
	predefinedDebris = debrisScene.instantiate()
	
	predefinedDebris.name = "PredefinedDebris"
#	predefinedDebris.transform.basis = Basis.IDENTITY.rotated(Vector3(1,0,0), deg_to_rad(45))
	
	self.add_child(predefinedDebris)

func regenerateRandomDebris():
	myRandInit(randomDebrisSeed)

	var randomDebris = get_node_or_null("RandomDebris")

	if (randomDebris):
		self.remove_child(randomDebris)
		randomDebris.queue_free()

	randomDebris = Node3D.new()
	randomDebris.name = "RandomDebris"

	# This is used to make limits work on the main body's rotation plane
	# (45 deg rotated around x-axis):
	var originTransform:Transform3D = Transform3D.IDENTITY.rotated(Vector3(0, 0, 1), deg_to_rad(-45))

	for i in range(300):
		var newSolarCell = RigidBodySolarCell.instantiate()
		var newBasis = Basis(Vector3(myRandf(), myRandf(), myRandf()), Vector3(myRandf(), myRandf(), myRandf()), Vector3(myRandf(), myRandf(), myRandf())).orthonormalized()
		var newOrigin = originTransform * Vector3(myRandf_range(-randomDebrisMaxPos.x, randomDebrisMaxPos.x), myRandf_range(-randomDebrisMaxPos.y, randomDebrisMaxPos.y), myRandf_range(-randomDebrisMaxPos.z, randomDebrisMaxPos.z))
		newSolarCell.transform = Transform3D(newBasis, newOrigin)
		newSolarCell.linear_velocity = Vector3(myRandf_range(-randomDebrisMaxLinearVelocity.x, randomDebrisMaxLinearVelocity.x), myRandf_range(-randomDebrisMaxLinearVelocity.y, randomDebrisMaxLinearVelocity.y), myRandf_range(-randomDebrisMaxLinearVelocity.z, randomDebrisMaxLinearVelocity.z))
		newSolarCell.angular_velocity = Vector3(myRandf_range(-randomDebrisMaxAngularVelocity.x, randomDebrisMaxAngularVelocity.x), myRandf_range(-randomDebrisMaxAngularVelocity.y, randomDebrisMaxAngularVelocity.y), myRandf_range(-randomDebrisMaxAngularVelocity.z, randomDebrisMaxAngularVelocity.z))
		randomDebris.add_child(newSolarCell)

	self.add_child(randomDebris)

# As Godot doesn't provide reproducible random numbers (across versions),
# let's introduce our own. No need for high quality here.
# Source: https://en.wikipedia.org/wiki/Linear_congruential_generator
# or: Numerical Recipes from the "quick and dirty generators" list, 
# Chapter 7.1, Eq. 7.1.6 parameters from Knuth and H. W. Lewis

var randVal:int = 0

func myRandInit(seed_p:int):
	randVal = seed_p & 0xFFFFFFFF

func myRandGetInt() -> int:
	randVal = (randVal * 1664525 + 1013904223) & 0xFFFFFFFF;
	return randVal

func myRandf() -> float:
	var u:int = myRandGetInt()
	return u / float(4294967296)

func myRandf_range(minVal:float, maxVal:float) -> float:
	var rand01 = myRandf()
	return minVal + rand01 * (maxVal - minVal)
