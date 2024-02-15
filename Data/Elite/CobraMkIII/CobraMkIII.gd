@tool
extends Node3D

const vertexArray = [
	Vector3(+0.25, +0.0, -0.5),	# 0: Nose right
	Vector3(+0.95, +0.0, +0.3),	# 1: Outer 1 right
	Vector3(+1.0, +0.0, +0.5),	# 2: Outer 2 (back) right
	Vector3(+0.7, +0.15, +0.5),	# 3: Back top dent right

	Vector3(-0.25, +0.0, -0.5),	# 4: Nose left
	Vector3(-0.95, +0.0, +0.3),	# 5: Outer 1 left
	Vector3(-1.0, +0.0, +0.5),	# 6: Outer 2 (back) left
	Vector3(-0.7, +0.15, +0.5),	# 7: Back top dent left
	
	Vector3(+0.0, +0.2, +0.0),	# 8: Top center center
	Vector3(+0.0, +0.25, +0.5),	# 9: Top center back
	
	Vector3(+0.25, -0.15, +0.5),	# 10: Bottom back right
	Vector3(-0.25, -0.15, +0.5),	# 11: Bottom back left

	# Rear left triangle:
	Vector3(-0.7, 0.04, 0.51),	# 12
	Vector3(-0.6, 0.11, 0.51),	# 13
	Vector3(-0.6, -0.03, 0.51),	# 14

	# Rear right triangle:
	Vector3(0.7, 0.04, 0.51),	# 15
	Vector3(0.6, -0.03, 0.51),	# 16
	Vector3(0.6, 0.11, 0.51),	# 17
	
	# Rear right engine:
	Vector3(0.3, -0.05, 0.51),		# 18
	Vector3(0.07, -0.06, 0.51),		# 19
	Vector3(0.07, 0.14, 0.51),		# 20
	Vector3(0.3, 0.13, 0.51),		# 21

	# Rear left engine:
	Vector3(-0.3, -0.05, 0.51),		# 22
	Vector3(-0.07, -0.06, 0.51),	# 23
	Vector3(-0.07, 0.14, 0.51),		# 24
	Vector3(-0.3, 0.13, 0.51),		# 25
]

var faceArray = [
	# Top right:
	EliteFace.new([0, 1, 3], 2, 2, Vector3.ZERO),
	EliteFace.new([1, 2, 3], 1, 1, Vector3.ZERO),
	EliteFace.new([0, 3, 8], 3, 3, Vector3.ZERO),
	EliteFace.new([8, 3, 9], 1, 2, Vector3.ZERO),
	
	# Top left:
	EliteFace.new([4, 7, 5], 2, 2, Vector3.ZERO),
	EliteFace.new([5, 7, 6], 1, 1, Vector3.ZERO),
	EliteFace.new([4, 8, 7], 3, 3, Vector3.ZERO),
	EliteFace.new([8, 9, 7], 1, 2, Vector3.ZERO),

	# Top front:
	EliteFace.new([0, 8, 4], 15, 3, Vector3.ZERO),
	
	# Bottom center:
	EliteFace.new([4, 11, 10, 0], 1, 0, Vector3.ZERO),
	
	# Bottom left:
	EliteFace.new([4, 5, 11], 2, 0, Vector3.ZERO),
	EliteFace.new([5, 6, 11], 3, 0, Vector3.ZERO),

	# Bottom right:
	EliteFace.new([0, 10, 1], 2, 0, Vector3.ZERO),
	EliteFace.new([1, 10, 2], 3, 0, Vector3.ZERO),
	
	# Back:
	EliteFace.new([9, 3, 2, 10, 11, 6, 7], 14, 0, Vector3(0, 0.03, 0.5)),
	
	# Rear left triangle:
	EliteFace.new([12, 13, 14], 3, 3, Vector3(0, 0.03, 0.5)),
	
	# Rear right triangle:
	EliteFace.new([15, 16, 17], 3, 3, Vector3(0, 0.03, 0.5)),
	
	# Right engine:
	EliteFace.new([18, 19, 20, 21], 16, 16, Vector3(0, 0.03, 0.5)),

	# Left engine:
	EliteFace.new([25, 24, 23, 22], 16, 16, Vector3(0, 0.03, 0.5)),
]

var animResetStashDone:bool = false

@export var trigStashToolData:bool = false:
	set(param):
		print("trigStashToolData setter called (CobraMkIII): ", param)
		if (!animResetStashDone && param):
			stashToolData()
			animResetStashDone = true
	get:
		return false

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	$MainBody.mesh = EliteShipMesh.createMesh(vertexArray, faceArray)

func _process(_delta):
	if (animResetStashDone):
		stashPullToolData()
		animResetStashDone = false

class StashData:
	var mainBodyMesh

var stashStorage:StashData = StashData.new()

func stashToolData():
	var mainBody:MeshInstance3D = get_node_or_null("MainBody")

	if (mainBody):
		print("Stashing tool data (CobraMkIII)")
		stashStorage.mainBodyMesh = mainBody.mesh
		mainBody.mesh = null

func stashPullToolData():
	var mainBody:MeshInstance3D = get_node_or_null("MainBody")

	if (mainBody):
		print("Stash pulling tool data (CobraMkIII)")
		mainBody.mesh = stashStorage.mainBodyMesh

func _physics_process(_delta):
	# We are not really interested about collision detection here as the
	# CharacterBody is only used to detect laser hits.
	# Therefore just cloning transform from the "main object"
	
	$CharacterBody3D.global_transform = self.global_transform
