@tool
extends Node3D

@export var disintegrationFraction:float = 0

const upperLevelY:float = 0.15
const lowerLevelY:float = -0.15
const upperLevelRadius:float = 0.4
const lowerLevelRadius:float = 1
const engineLength:float = 1
const engineWidth:float = 0.05
const engineXDist:float = 0.4
const engineLevelY:float = lowerLevelY - 0.01

const numOfDebrisParticles:int = 5000
const maxNumOfDebrisParticlePoints:int = 3	# 3 is enough, you can't see the difference in low res...
const maxDebrisParticleSize:float = 0.2
const debrisFieldRandomSeed:int = 0

const debrisFieldUpperLevelY:float = upperLevelY
const debrisFieldLowerLevelY:float = lowerLevelY
const debrisFieldUpperLevelRadius:float = upperLevelRadius * 0.9	# Need some margin because octagon
const debrisFieldLowerLevelRadius:float = lowerLevelRadius * 0.9	# Need some margin because octagon

const engineVertexArray = [
	#Left:
	Vector3(-engineXDist - engineWidth / 2, engineLevelY, engineLength / 2),
	Vector3(-engineXDist + engineWidth / 2, engineLevelY, engineLength / 2),
	Vector3(-engineXDist + engineWidth / 2, engineLevelY, -engineLength / 2),
	Vector3(-engineXDist - engineWidth / 2, engineLevelY, -engineLength / 2),

	# Right:
	Vector3(engineXDist - engineWidth / 2, engineLevelY, engineLength / 2),
	Vector3(engineXDist + engineWidth / 2, engineLevelY, engineLength / 2),
	Vector3(engineXDist + engineWidth / 2, engineLevelY, -engineLength / 2),
	Vector3(engineXDist - engineWidth / 2, engineLevelY, -engineLength / 2),
]

const engineVertShift:int = 16

var engineFaceArray = [
	EliteFace.new([0 + engineVertShift, 1 + engineVertShift, 2 + engineVertShift, 3 + engineVertShift], 16, 16, Vector3(0, lowerLevelY, 0)),
	EliteFace.new([4 + engineVertShift, 5 + engineVertShift, 6 + engineVertShift, 7 + engineVertShift], 16, 16, Vector3(0, lowerLevelY, 0)),
]

var animResetStashDone:bool = false

@export var trigStashToolData:bool = false:
	set(param):
		print("trigStashToolData setter called (Thargoid): ", param)
		if (!animResetStashDone && param):
			stashToolData()
			animResetStashDone = true
	get:
		return false

func _ready():
	createMainBodyMesh()
	createDebrisField()
	# This is a workaround for bug
	# https://github.com/godotengine/godot/issues/86369
	# (Can't set custom aabb in inspector)
	# causing debris to disappear when flying through them.
	# Extra cull margin could also work but it crashed the editor:
	# https://github.com/godotengine/godot/issues/80504
	$MainBody.custom_aabb = AABB(Vector3(0,0,0), Vector3(100, 100, 100))
	$DebrisField.custom_aabb = AABB(Vector3(0,0,0), Vector3(100, 100, 100))

var lastDisintegrationFraction:float = 42
func _process(_delta):
	if (animResetStashDone):
		stashPullToolData()
		animResetStashDone = false

	if (disintegrationFraction != lastDisintegrationFraction):
		$MainBody.set_instance_shader_parameter("disintegrationFraction", disintegrationFraction)
		$DebrisField.set_instance_shader_parameter("disintegrationFraction", disintegrationFraction)
		$DebrisField.visible = disintegrationFraction != 0
		lastDisintegrationFraction = disintegrationFraction

func createMainBodyMesh():
	var mainBodyVertices:Array[Vector3] = []
	var mainBodyFaces:Array[EliteFace] = []

	for i in range(8):
		var rad = float(i) * 2.0 * PI / 8
		
		mainBodyVertices.append(Vector3(sin(rad) * upperLevelRadius, upperLevelY, cos(rad) * upperLevelRadius))
		mainBodyVertices.append(Vector3(sin(rad) * lowerLevelRadius, lowerLevelY, cos(rad) * lowerLevelRadius))

	# Top plate
	var upperPlateVerts:Array[int] = []
	for i in range(14, -2, -2):
		upperPlateVerts.append(i)
	mainBodyFaces.append(EliteFace.new(upperPlateVerts, 6, 6, Vector3.ZERO))

	# Bottom plate
	var lowerPlateVerts:Array[int] = []
	for i in range(1, 16, 2):
		lowerPlateVerts.append(i)
	mainBodyFaces.append(EliteFace.new(lowerPlateVerts, 4, 4, Vector3(0, lowerLevelY, 0)))

	# Side plates
	for i in range(0, 16, 2):
		mainBodyFaces.append(EliteFace.new(
				[
					i, 
					(((i + 2) % 16)),
					(((i + 3) % 16)), 
					i + 1
				],
				4 + ((i / 2) & 1), 4 + ((i / 2) & 1), Vector3.ZERO))

	mainBodyVertices.append_array(engineVertexArray)
	mainBodyFaces.append_array(engineFaceArray)

	$MainBody.mesh = EliteShipMesh.createMesh(mainBodyVertices, mainBodyFaces)

func createDebrisField():
	var debrisFieldVertices:Array[Vector3] = []
	var debrisFieldFaces:Array[EliteFace] = []
	
	myRandInit(debrisFieldRandomSeed)

	for debrisParticleIndex in range(numOfDebrisParticles):
		# Create particles in quite a dummy way. As these need to be
		# limited inside the MainBody, just randomize the vertices in xyz-space
		# and discard the face if any of it's verts are outside the body (some margins used).
		# This will give uniform distribution easy way.
		# numOfDebrisParticles will not be reached, but adjust it accordingly.
		
		var particleCenterPoint:Vector3 = Vector3(myRandf_range(-debrisFieldLowerLevelRadius, debrisFieldLowerLevelRadius),
				myRandf_range(debrisFieldLowerLevelY, debrisFieldUpperLevelY),
				myRandf_range(-debrisFieldLowerLevelRadius, debrisFieldLowerLevelRadius))

		var numOfVertices:int = 3 + myRandGetInt() % (maxNumOfDebrisParticlePoints - 2)
		
		# Replaced with non-typed array (Why? -> See beginning of this function)
		var particleFaceVerts:Array[int] = []
		var particleVertices:Array[Vector3] = []

		for subVertexIndex in range(numOfVertices):
			var vert = particleCenterPoint + Vector3(myRandf_range(-maxDebrisParticleSize, maxDebrisParticleSize), myRandf_range(-maxDebrisParticleSize, maxDebrisParticleSize), myRandf_range(-maxDebrisParticleSize, maxDebrisParticleSize))
			# Calculate max radius based on the Y-value
			var maxRadius:float = (debrisFieldLowerLevelRadius +
					((vert.y - debrisFieldLowerLevelY) / (debrisFieldUpperLevelY - debrisFieldLowerLevelY)) *
					(debrisFieldUpperLevelRadius - debrisFieldLowerLevelRadius))
			if ((Vector2(vert.x, vert.z).length() > maxRadius) ||
					vert.y < debrisFieldLowerLevelY || vert.y > debrisFieldUpperLevelY):
				particleVertices.clear()
				particleFaceVerts.clear()
				break

			particleVertices.append(vert)
			particleFaceVerts.append(debrisFieldVertices.size() + particleVertices.size() - 1)
		
		if (!particleFaceVerts.is_empty()):
			debrisFieldVertices.append_array(particleVertices)
			debrisFieldFaces.append(EliteFace.new(particleFaceVerts, myRandGetInt() % 17, myRandGetInt() & 17, Vector3.ZERO))

	$DebrisField.mesh = EliteShipMesh.createMesh(debrisFieldVertices, debrisFieldFaces)

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

class StashData:
	var mainBodyMesh
	var debrisMesh

var stashStorage:StashData = StashData.new()

func stashToolData():
	var mainBody:MeshInstance3D = get_node_or_null("MainBody")
	var debrisField:MeshInstance3D = get_node_or_null("DebrisField")

	if (mainBody && debrisField):
		print("Stashing tool data (Thargoid)")
		stashStorage.mainBodyMesh = mainBody.mesh
		stashStorage.debrisMesh = debrisField.mesh
		mainBody.mesh = null
		debrisField.mesh = null

func stashPullToolData():
	var mainBody:MeshInstance3D = get_node_or_null("MainBody")
	var debrisField:MeshInstance3D = get_node_or_null("DebrisField")

	if (mainBody && debrisField):
		print("Stash pulling tool data (Thargoid)")
		mainBody.mesh = stashStorage.mainBodyMesh
		debrisField.mesh = stashStorage.debrisMesh

func _physics_process(_delta):
	# We are not really interested about collision detection here as the
	# CharacterBody is only used to detect laser hits.
	# Therefore just cloning transform from the "main object"
	
	$CharacterBody3D.global_transform = self.global_transform
