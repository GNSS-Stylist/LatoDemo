@tool
extends Node3D

const noseLength:float = 1.3
const shipWidth:float = 1.0
const shipHeight:float = 0.5
const tailLength:float = 0.5
const tailWidth:float = 0.4
const tailHeight:float = 0.25
const centerPartLength:float = 0.4

enum Coloring { GREEN, RED }

@export var coloring:Coloring = Coloring.GREEN:
	set(newColor):
		coloring = newColor
		$MainBody_Green.visible = (coloring == Coloring.GREEN)
		$MainBody_Red.visible = (coloring == Coloring.RED)

const vertexArray = [
	Vector3(0, 0, -noseLength),									# 0: Nose
	Vector3(0, shipHeight / 2, -centerPartLength / 2),			# 1: Upper "first dent"
	Vector3(0, -shipHeight / 2, -centerPartLength / 2),			# 2: Lower "first dent"
	Vector3(0, shipHeight / 2, centerPartLength / 2),			# 3: Upper "second dent"
	Vector3(0, -shipHeight / 2, centerPartLength / 2),			# 4: Lower "second dent"
	Vector3(0, tailHeight / 2, tailLength),						# 5: Upper center tail
	Vector3(0, -tailHeight / 2, tailLength),					# 6: Lower center tail
	Vector3(-shipWidth / 2, 0, 0),								# 7: Left center dent
	Vector3(-tailWidth / 2, 0, tailLength),						# 8: Left center dent
	Vector3(shipWidth / 2, 0, 0),								# 9: Right center dent
	Vector3(tailWidth / 2, 0, tailLength),						# 10: Right center dent
]

var faceArray_Green = [
	# Front upper left:
	EliteFace.new([0, 1, 7], 6, 6, Vector3.ZERO),
	
	# Front upper right:
	EliteFace.new([0, 9, 1], 5, 5, Vector3.ZERO),

	# Center upper left:
	EliteFace.new([7, 1, 3], 5, 5, Vector3.ZERO),

	# Center upper right:
	EliteFace.new([1, 9, 3], 6, 6, Vector3.ZERO),
	
	# Tail upper left:
	EliteFace.new([7, 3, 5, 8], 2, 2, Vector3.ZERO),

	# Tail upper right:
	EliteFace.new([3, 9, 10, 5], 1, 1, Vector3.ZERO),



	# Front lower left:
	EliteFace.new([0, 7, 2], 0, 5, Vector3.ZERO),
	
	# Front lower right:
	EliteFace.new([0, 2, 9], 0, 6, Vector3.ZERO),

	# Center lower left:
	EliteFace.new([7, 4, 2], 0, 6, Vector3.ZERO),

	# Center lower right:
	EliteFace.new([2, 4, 9], 0, 5, Vector3.ZERO),
	
	# Tail lower left:
	EliteFace.new([4, 7, 8, 6], 0, 1, Vector3.ZERO),

	# Tail lower right:
	EliteFace.new([4, 6, 10, 9], 0, 2, Vector3.ZERO),

	# Tail engine:
	EliteFace.new([8, 5, 10, 6], 16, 16, Vector3.ZERO),
]

var faceArray_Red = [
	# Front upper left:
	EliteFace.new([0, 1, 7], 9, 15, Vector3.ZERO),
	
	# Front upper right:
	EliteFace.new([0, 9, 1], 9, 9, Vector3.ZERO),

	# Center upper left:
	EliteFace.new([7, 1, 3], 9, 9, Vector3.ZERO),

	# Center upper right:
	EliteFace.new([1, 9, 3], 9, 15, Vector3.ZERO),
	
	# Tail upper left:
	EliteFace.new([7, 3, 5, 8], 9, 15, Vector3.ZERO),

	# Tail upper right:
	EliteFace.new([3, 9, 10, 5], 9, 9, Vector3.ZERO),



	# Front lower left:
	EliteFace.new([0, 7, 2], 12, 12, Vector3.ZERO),
	
	# Front lower right:
	EliteFace.new([0, 2, 9], 12, 0, Vector3.ZERO),

	# Center lower left:
	EliteFace.new([7, 4, 2], 12, 0, Vector3.ZERO),

	# Center lower right:
	EliteFace.new([2, 4, 9], 12, 12, Vector3.ZERO),
	
	# Tail lower left:
	EliteFace.new([4, 7, 8, 6], 12, 12, Vector3.ZERO),

	# Tail lower right:
	EliteFace.new([4, 6, 10, 9], 12, 0, Vector3.ZERO),

	# Tail engine:
	EliteFace.new([8, 5, 10, 6], 16, 16, Vector3.ZERO),
]

func _ready():
	$MainBody_Green.mesh = EliteShipMesh.createMesh(vertexArray, faceArray_Green)
	$MainBody_Red.mesh = EliteShipMesh.createMesh(vertexArray, faceArray_Red)

func _process(delta):
	if (animResetStashDone):
		stashPullToolData()
		animResetStashDone = false

var animResetStashDone:bool = false

@export var trigStashToolData:bool = false:
	set(param):
		print("trigStashToolData setter called (Python): ", param)
		if (!animResetStashDone && param):
			stashToolData()
			animResetStashDone = true
	get:
		return false

class StashData:
	var mainBodyMesh_Green
	var mainBodyMesh_Red

var stashStorage:StashData = StashData.new()

func stashToolData():
	var mainBody_Green:MeshInstance3D = get_node_or_null("MainBody_Green")
	var mainBody_Red:MeshInstance3D = get_node_or_null("MainBody_Red")

	if (mainBody_Green && mainBody_Red):
		print("Stashing tool data (Python)")
		stashStorage.mainBodyMesh_Green = mainBody_Green.mesh
		stashStorage.mainBodyMesh_Red = mainBody_Red.mesh
		mainBody_Green.mesh = null
		mainBody_Red.mesh = null

func stashPullToolData():
	var mainBody_Green:MeshInstance3D = get_node_or_null("MainBody_Green")
	var mainBody_Red:MeshInstance3D = get_node_or_null("MainBody_Red")

	if (mainBody_Green && mainBody_Red):
		print("Stash pulling tool data (Python)")
		mainBody_Green.mesh = stashStorage.mainBodyMesh_Green
		mainBody_Red.mesh = stashStorage.mainBodyMesh_Red
