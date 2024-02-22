@tool
extends Node3D

const vertexArray = [
	Vector3(+0.00,  -0.10,  -0.75),		# 0: Nose
	Vector3(+0.00,  +0.15,  +0.20),		# 1: Top hump

	Vector3(-0.30,  +0.10,  +0.10),		# 2: Top left dent
	Vector3(-0.30,  -0.10,  +0.10),		# 3: Bottom left dent

	Vector3(-0.10,  +0.03,  +0.40),		# 4: Top left back
	Vector3(-0.10,  -0.10,  +0.40),		# 5: Bottom left back

	Vector3(+0.10,  +0.03,  +0.40),		# 6: Top right back
	Vector3(+0.10,  -0.10,  +0.40),		# 7: Bottom right back

	Vector3(+0.30,  +0.10,  +0.10),		# 8: Top right dent
	Vector3(+0.30,  -0.10,  +0.10),		# 9: Bottom right dent
	
	Vector3(-0.025, -0.06,  -0.60),		# 10: Left decal front
	Vector3(-0.20,  +0.10,  +0.03),		# 11: Left decal left back
	Vector3(-0.10,  +0.13,  +0.13),		# 12: Left decal right back

	Vector3(+0.025, -0.06,  -0.60),		# 13: Right decal front
	Vector3(+0.20,  +0.10,  +0.03),		# 14: Right decal right back
	Vector3(+0.10,  +0.13,  +0.13),		# 15: Right decal left back

	Vector3(-0.10,  -0.11,  -0.25),		# 16: Bottom decal front left
	Vector3(+0.10,  -0.11,  -0.25),		# 17: Bottom decal front right
	Vector3(+0.00,  -0.11,  +0.20),		# 18: Bottom decal back center

]

var faceArray = [
	# Top left:
	EliteFace.new([0, 1, 2], 0, 6, Vector3.ZERO),
	EliteFace.new([1, 4, 2], 0, 4, Vector3.ZERO),
	
	# Top right
	EliteFace.new([0, 8, 1], 0, 6, Vector3.ZERO),
	EliteFace.new([1, 8, 6], 0, 4, Vector3.ZERO),

	# Top back:
	EliteFace.new([1, 6, 4], 0, 6, Vector3.ZERO),

	# Left front side:
	EliteFace.new([0, 2, 3], 0, 4, Vector3.ZERO),

	# Left back side:
	EliteFace.new([2, 4, 5, 3], 1, 1, Vector3.ZERO),

	# Right front side:
	EliteFace.new([0, 9, 8], 0, 4, Vector3.ZERO),

	# Right back side:
	EliteFace.new([8, 9, 7, 6], 1, 1, Vector3.ZERO),

	# Back engine:
	EliteFace.new([4, 6, 7, 5], 16, 16, Vector3.ZERO),
	
	# Bottom plate:
	EliteFace.new([0, 3, 5, 7, 9], 2, 2, Vector3.ZERO),

	# Left top decal:
	EliteFace.new([10, 12, 11], 6, 6, Vector3.ZERO),

	# right top decal:
	EliteFace.new([13, 14, 15], 6, 6, Vector3.ZERO),

	# Bottom decal:
	EliteFace.new([16, 18, 17], 1, 1, Vector3.ZERO),
]

var animResetStashDone:bool = false

@export var trigStashToolData:bool = false:
	set(param):
		print("trigStashToolData setter called (FerDeLance): ", param)
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
		print("Stashing tool data (FerDeLance)")
		stashStorage.mainBodyMesh = mainBody.mesh
		mainBody.mesh = null

func stashPullToolData():
	var mainBody:MeshInstance3D = get_node_or_null("MainBody")

	if (mainBody):
		print("Stash pulling tool data (FerDeLance)")
		mainBody.mesh = stashStorage.mainBodyMesh

func _physics_process(_delta):
	# We are not really interested about collision detection here as the
	# CharacterBody is only used to detect laser hits.
	# Therefore just cloning transform from the "main object"
	
	$CharacterBody3D.global_transform = self.global_transform
