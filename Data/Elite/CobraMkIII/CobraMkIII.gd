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
	Vector3(-0.3, -0.05, 0.51),	# 22
	Vector3(-0.07, -0.06, 0.51),		# 23
	Vector3(-0.07, 0.14, 0.51),		# 24
	Vector3(-0.3, 0.13, 0.51),		# 25
	

]

class eliteTriangle:
	var vertices:Vector3i	# Vertices of the face as indices
	var color1:int			# First color to paint the face
	var color2:int			# Second color to paint the face
	func _init(vertices_p:Vector3i, color1_p:int, color2_p:int):
		self.vertices = vertices_p
		self.color1 = color1_p
		self.color2 = color2_p

var faceArray = [
	# Top right:
	eliteTriangle.new(Vector3i(0, 1, 3), 2, 2),
	eliteTriangle.new(Vector3i(1, 2, 3), 1, 1),
	eliteTriangle.new(Vector3i(0, 3, 8), 3, 3),
	eliteTriangle.new(Vector3i(8, 3, 9), 1, 2),
	
	# Top left:
	eliteTriangle.new(Vector3i(4, 7, 5), 2, 2),
	eliteTriangle.new(Vector3i(5, 7, 6), 1, 1),
	eliteTriangle.new(Vector3i(4, 8, 7), 3, 3),
	eliteTriangle.new(Vector3i(8, 9, 7), 1, 2),

	# Top front:
	eliteTriangle.new(Vector3i(0, 8, 4), 15, 3),
	
	# Bottom center:
	eliteTriangle.new(Vector3i(4, 11, 0), 1, 0),
	eliteTriangle.new(Vector3i(0, 11, 10), 1, 0),
	
	# Bottom left:
	eliteTriangle.new(Vector3i(4, 5, 11), 2, 0),
	eliteTriangle.new(Vector3i(5, 6, 11), 3, 0),

	# Bottom right:
	eliteTriangle.new(Vector3i(0, 10, 1), 2, 0),
	eliteTriangle.new(Vector3i(1, 10, 2), 3, 0),
	
	# Back:
	eliteTriangle.new(Vector3i(9, 3, 2), 14, 0),
	eliteTriangle.new(Vector3i(9, 2, 10), 14, 0),
	eliteTriangle.new(Vector3i(9, 10, 11), 14, 0),
	eliteTriangle.new(Vector3i(9, 11, 6), 14, 0),
	eliteTriangle.new(Vector3i(9, 6, 7), 14, 0),
	
	# Rear left triangle:
	eliteTriangle.new(Vector3i(12, 13, 14), 3, 3),
	
	# Rear right triangle:
	eliteTriangle.new(Vector3i(15, 16, 17), 3, 3),
	
	# Right engine:
	eliteTriangle.new(Vector3i(18, 19, 20), 16, 16),
	eliteTriangle.new(Vector3i(18, 20, 21), 16, 16),

	# Left engine:
	eliteTriangle.new(Vector3i(22, 24, 23), 16, 16),
	eliteTriangle.new(Vector3i(22, 25, 24), 16, 16),

]

#@export var dbg_regenMesh:bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	generateMesh()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	if (dbg_regenMesh):
#		generateMesh()
#		dbg_regenMesh = false
#		print("mesh regenerated")

func generateMesh():
	var mesh:ArrayMesh = ArrayMesh.new()

	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	
	for i in range(faceArray.size()):
		vertices.push_back(vertexArray[faceArray[i].vertices.x])
		vertices.push_back(vertexArray[faceArray[i].vertices.y])
		vertices.push_back(vertexArray[faceArray[i].vertices.z])
		var uv = Vector2(faceArray[i].color1, faceArray[i].color2)
		uvs.push_back(uv)
		uvs.push_back(uv)
		uvs.push_back(uv)

	var arrayMeshArrays = []
	arrayMeshArrays.resize(ArrayMesh.ARRAY_MAX)
	arrayMeshArrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arrayMeshArrays[ArrayMesh.ARRAY_TEX_UV] = uvs

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrayMeshArrays)
	
	$MainBody.mesh = mesh
	
