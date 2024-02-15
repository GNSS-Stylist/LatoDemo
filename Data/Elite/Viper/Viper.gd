@tool
extends Node3D

const ship_length:float = 1.0
const ship_width:float = 1.0
const ship_height:float = 0.3

enum Coloring { RED, BLUE }

@export var coloring:Coloring:
	set(newColor):
		coloring = newColor
		$MainBody_Blue.visible = (coloring == Coloring.BLUE)
		$MainBody_Red.visible = (coloring == Coloring.RED)

const vertexArray = [
	Vector3(0, 0, -ship_length / 2),								# 0: Nose
	Vector3(0, ship_height / 2, 0),									# 1: Upper "center point"
	Vector3(0, - ship_height / 2, 0),								# 2: Lower "center point"
	Vector3(-ship_width / 2, 0, ship_length / 2),					# 3: Back left
	Vector3(ship_width / 2, 0, ship_length / 2),					# 4: Back right
	Vector3(-ship_width / 4, ship_height / 2, ship_length / 2),		# 5: Back left top dent
	Vector3(-ship_width / 4, -ship_height / 2, ship_length / 2),	# 6: Back left bottom dent
	Vector3(ship_width / 4, ship_height / 2, ship_length / 2),		# 7: Back right top dent
	Vector3(ship_width / 4, - ship_height / 2, ship_length / 2),	# 8: Back right bottom dent

	Vector3(-ship_width * 0.3, 0, ship_length / 2 + 0.01),					# 9: Left engine
	Vector3(-ship_width * 0.08, ship_height * 0.3, ship_length / 2 + 0.01),	# 10: Left engine
	Vector3(-ship_width * 0.08, -ship_height * 0.3, ship_length / 2 + 0.01),# 11: Left engine

	Vector3(ship_width * 0.3, 0, ship_length / 2 + 0.01),					# 12: Right engine
	Vector3(ship_width * 0.08, ship_height * 0.3, ship_length / 2 + 0.01),	# 13: Right engine
	Vector3(ship_width * 0.08, -ship_height * 0.3, ship_length / 2 + 0.01),	# 14: right engine
]

var faceArray_Blue = [
	# Top left:
	EliteFace.new([0, 1, 5, 3], 2, 2, Vector3.ZERO),
	
	# Top right:
	EliteFace.new([0, 4, 7, 1], 2, 2, Vector3.ZERO),

	# Top back:
	EliteFace.new([1, 7, 5], 3, 3, Vector3.ZERO),

	# Bottom left:
	EliteFace.new([0, 3, 6, 2], 1, 1, Vector3.ZERO),
	
	# Bottom right:
	EliteFace.new([0, 2, 8, 4], 1, 1, Vector3.ZERO),

	# Bottom back:
	EliteFace.new([2, 6, 8], 0, 1, Vector3.ZERO),

	# Back plate:
	EliteFace.new([3, 5, 7, 4, 8, 6], 0, 14, Vector3.ZERO),
	
	# Left engine:
	EliteFace.new([9,10,11], 16, 16, Vector3.ZERO),
	
	# Right engine:
	EliteFace.new([12,13,14], 16, 16, Vector3.ZERO),
]

var faceArray_Red = [
	# Top left:
	EliteFace.new([0, 1, 5, 3], 9, 9, Vector3.ZERO),
	
	# Top right:
	EliteFace.new([0, 4, 7, 1], 9, 9, Vector3.ZERO),

	# Top back:
	EliteFace.new([1, 7, 5], 9, 15, Vector3.ZERO),

	# Bottom left:
	EliteFace.new([0, 3, 6, 2], 12, 12, Vector3.ZERO),
	
	# Bottom right:
	EliteFace.new([0, 2, 8, 4], 12, 12, Vector3.ZERO),

	# Bottom back:
	EliteFace.new([2, 6, 8], 0, 12, Vector3.ZERO),

	# Back plate:
	EliteFace.new([3, 5, 7, 4, 8, 6], 0, 12, Vector3.ZERO),

	# Left engine:
	EliteFace.new([9,10,11], 16, 16, Vector3.ZERO),
	
	# Right engine:
	EliteFace.new([12,13,14], 16, 16, Vector3.ZERO),
]

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	$MainBody_Blue.mesh = EliteShipMesh.createMesh(vertexArray, faceArray_Blue)
	$MainBody_Red.mesh = EliteShipMesh.createMesh(vertexArray, faceArray_Red)

func _process(_delta):
	if (animResetStashDone):
		stashPullToolData()
		animResetStashDone = false

var animResetStashDone:bool = false

@export var trigStashToolData:bool = false:
	set(param):
		print("trigStashToolData setter called (Viper): ", param)
		if (!animResetStashDone && param):
			stashToolData()
			animResetStashDone = true
	get:
		return false

class StashData:
	var mainBodyMesh_Blue
	var mainBodyMesh_Red

var stashStorage:StashData = StashData.new()

func stashToolData():
	var mainBody_Blue:MeshInstance3D = get_node_or_null("MainBody_Blue")
	var mainBody_Red:MeshInstance3D = get_node_or_null("MainBody_Red")

	if (mainBody_Blue && mainBody_Red):
		print("Stashing tool data (Viper)")
		stashStorage.mainBodyMesh_Blue = mainBody_Blue.mesh
		stashStorage.mainBodyMesh_Red = mainBody_Red.mesh
		mainBody_Blue.mesh = null
		mainBody_Red.mesh = null

func stashPullToolData():
	var mainBody_Blue:MeshInstance3D = get_node_or_null("MainBody_Blue")
	var mainBody_Red:MeshInstance3D = get_node_or_null("MainBody_Red")

	if (mainBody_Blue && mainBody_Red):
		print("Stash pulling tool data (Viper)")
		mainBody_Blue.mesh = stashStorage.mainBodyMesh_Blue
		mainBody_Red.mesh = stashStorage.mainBodyMesh_Red

func _physics_process(_delta):
	# We are not really interested about collision detection here as the
	# CharacterBody is only used to detect laser hits.
	# Therefore just cloning transform from the "main object"
	
	$CharacterBody3D.global_transform = self.global_transform
