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

class EliteFace:
	var vertices = []		# Vertices of the face as indices
	var color1:int			# First color to paint the face
	var color2:int			# Second color to paint the face
	var centerPoint:Vector3
	func _init(vertices_p:Array, color1_p:int, color2_p:int, centerPoint_p:Vector3):
		self.vertices = vertices_p
		self.color1 = color1_p
		self.color2 = color2_p
		self.centerPoint = centerPoint_p

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
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var centerPoints = PackedFloat32Array()
	
	for faceIndex in range(faceArray.size()):
		var uv = Vector2(faceArray[faceIndex].color1, faceArray[faceIndex].color2)
		var centerPoint:Vector3 = Vector3.ZERO
		
		if (faceArray[faceIndex].centerPoint == Vector3.ZERO):
			# If centerpoint is zero, calculate is as an average of the vertices
			for i in range(faceArray[faceIndex].vertices.size()):
				centerPoint += vertexArray[faceArray[faceIndex].vertices[i]]
			centerPoint /= faceArray[faceIndex].vertices.size()
		else:
			centerPoint = faceArray[faceIndex].centerPoint
		
		var normal = (vertexArray[faceArray[faceIndex].vertices[2]] - 
				vertexArray[faceArray[faceIndex].vertices[0]]).cross(
					vertexArray[faceArray[faceIndex].vertices[1]] -
					vertexArray[faceArray[faceIndex].vertices[0]]).normalized()

		for i in range(1, faceArray[faceIndex].vertices.size() - 1):
			# Create face as "triangle fan"
			vertices.push_back(vertexArray[faceArray[faceIndex].vertices[0]])
			vertices.push_back(vertexArray[faceArray[faceIndex].vertices[i]])
			vertices.push_back(vertexArray[faceArray[faceIndex].vertices[i + 1]])
			for iii in range(3):
				normals.push_back(normal)
				uvs.push_back(uv)
				centerPoints.push_back(centerPoint.x)
				centerPoints.push_back(centerPoint.y)
				centerPoints.push_back(centerPoint.z)
				centerPoints.push_back(faceIndex)

	var arrayMeshArrays = []
	arrayMeshArrays.resize(ArrayMesh.ARRAY_MAX)
	arrayMeshArrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arrayMeshArrays[ArrayMesh.ARRAY_NORMAL] = normals
	arrayMeshArrays[ArrayMesh.ARRAY_TEX_UV] = uvs
	arrayMeshArrays[ArrayMesh.ARRAY_CUSTOM0] = centerPoints

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrayMeshArrays, [], {}, 
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT))
	
	$MainBody.mesh = mesh
	
