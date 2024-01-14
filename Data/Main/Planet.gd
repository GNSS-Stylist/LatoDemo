@tool
extends MeshInstance3D

@export var textureRotation_x:float
@export var textureRotation_y:float
@export var sourceMesh:Mesh

# Called when the node enters the scene tree for the first time.
func _ready():
	if (Global && Engine.is_editor_hint() && Global.cleanTempToolData):
		# @tool-scripts will generate changes that are saved into .tscn (scene)-files.
		# Clean them when requested
		
		print("Cleaning data generated by @tool, ", self.name)
		mesh = null
		self.material_override.set_shader_parameter("customDataSampler", null)
		return

	breakGeometry()
	
func breakGeometry():
	# This breaks indexed geometry into separate faces
	# Needed to get triangles flying separately when the world ends.
	
	var newMesh = ArrayMesh.new()
	
	var sourceMeshArrays = []
	
#	sourceMeshArrays = self.mesh.get_mesh_arrays()
	sourceMeshArrays = sourceMesh.surface_get_arrays(0)

	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()

	var centerPoints = PackedColorArray()
	
	var textureRotation:Basis = Basis.IDENTITY
	
	textureRotation = textureRotation.rotated(Vector3(0,1,0), textureRotation_y)
	textureRotation = textureRotation.rotated(Vector3(1,0,0), textureRotation_x)

	for vertexIndex in range(0, sourceMeshArrays[Mesh.ARRAY_INDEX].size(), 3):
#			vertices.push_back(sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + i]] + Vector3(randf_range(-600000, 600000), randf_range(-600000, 600000), randf_range(-600000, 600000)))
		var centerPointSum:Vector3 = Vector3(0,0,0)

		vertices.push_back(sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 0]])
		centerPointSum += sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 0]]
		vertices.push_back(sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 1]])
		centerPointSum += sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 1]]
		vertices.push_back(sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 2]])
		centerPointSum += sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 2]]
		
		var centerPoint = centerPointSum / 3

		centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))
#		centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))
#		centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))

#		uvs.push_back(Vector2(0, 0))
#		uvs.push_back(Vector2(1, 0))
#		uvs.push_back(Vector2(0, 1))
		
#		for i in range(3):
##			if ((abs(vertices[vertices.size() - 3 + i].x) > 0.0001) || (abs(vertices[vertices.size() - 3 + i].z - 1) > 0.0001)):
#			if (true):
#				var texVertex:Vector3 = vertices[vertices.size() - 3 + i]
#				texVertex.z += 1	# Origin shift
#
#				texVertex = textureRotation * texVertex
#
#				uvs.push_back(Vector2(
#						atan2(-texVertex.z, texVertex.x) / (2 * PI) + 0.5,
##						(vertices[vertices.size() - 3 + i].y + 1) / 2
#						-(asin(texVertex.y) + (PI / 2)) / PI
#				))
#			else:
#				# TODO: This makes poles textured wrong
#				# But well, maybe you aren't supposed to look at the dark side...
#				# (And texture wrapping doesn't work in x-direction either)
#
#				uvs.push_back(Vector2(0,0))
#				uvs.push_back(Vector2(0,0))

		normals.push_back(sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 0]])
		normals.push_back(sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 1]])
		normals.push_back(sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 2]])

	# Subdivision for the "baseplate" under the barn
	# Coordinates taken from a ply-file generated with MeshLab (with only one face left)
#	var v1:Vector3 = Vector3(0, -0.02226856078912326, 0.9997520248543541-1)
#	var v2:Vector3 = Vector3(-0.02064010660060742, 0.0111367199997513, 0.9997249419051035-1)
#	var v3:Vector3 = Vector3(0.02064010660060742, 0.0111367199997513, 0.9997249419051035-1)

	var v1:Vector3 = Vector3(0, -0.02226856078912326, 0)
	var v2:Vector3 = Vector3(-0.02064010660060742, 0.0111367199997513, 0)
	var v3:Vector3 = Vector3(0.02064010660060742, 0.0111367199997513, 0)

	# Planet's origin
	var orig:Vector3 = Vector3(0, 0, -1)

	# "Subdivided triangles"
	for i in range(23):
		var newV1 = (v1 + v2) / 2
		var newV2 = (v2 + v3) / 2
		var newV3 = (v3 + v1) / 2
		
		var centerPointSum:Vector3 = Vector3(0,0,0)

		vertices.push_back(v1)
		centerPointSum += v1
		normals.push_back((v1-orig).normalized())

		vertices.push_back(newV1)
		centerPointSum += newV1
		normals.push_back((newV1-orig).normalized())

		vertices.push_back(newV3)
		centerPointSum += newV3
		normals.push_back((newV3-orig).normalized())

		var centerPoint = centerPointSum / 3

		centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))
#		centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))
#		centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))

		centerPointSum = Vector3(0,0,0)

		vertices.push_back(v2)
		centerPointSum += v2
		normals.push_back((v2-orig).normalized())

		vertices.push_back(newV2)
		centerPointSum += newV2
		normals.push_back((newV2-orig).normalized())

		vertices.push_back(newV1)
		centerPointSum += newV1
		normals.push_back((newV1-orig).normalized())

		centerPoint = centerPointSum / 3

		centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))
#		centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))
#		centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))

		centerPointSum = Vector3(0,0,0)

		vertices.push_back(v3)
		centerPointSum += v3
		normals.push_back((v3-orig).normalized())

		vertices.push_back(newV3)
		centerPointSum += newV3
		normals.push_back((newV3-orig).normalized())

		vertices.push_back(newV2)
		centerPointSum += newV2
		normals.push_back((newV2-orig).normalized())

		centerPoint = centerPointSum / 3

		centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))
#		centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))
#		centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))

		v1 = newV1
		v2 = newV2
		v3 = newV3
	
	var centerPointSum = Vector3(0,0,0)
	# Last triangle inside
	vertices.push_back(v1)
	centerPointSum += v1
	normals.push_back((v1-orig).normalized())
	vertices.push_back(v2)
	centerPointSum += v2
	normals.push_back((v2-orig).normalized())
	vertices.push_back(v3)
	centerPointSum += v3
	normals.push_back((v3-orig).normalized())

	var centerPoint = centerPointSum / 3

	centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))
#	centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))
#	centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))

	# * 3 / 3 here comes from 3 values for each face (consisting of 3 points)
	var customDataImageHeight = nearest_po2(centerPoints.size() / 4096) + 1
	
	var customDataImage:Image = Image.create(4096, customDataImageHeight, false, Image.FORMAT_RGBF)

	for i in range(centerPoints.size()):
		customDataImage.set_pixel(i % 4096, i / 4096, centerPoints[i])

	for texVertex in vertices:
#			if ((abs(vertices[vertices.size() - 3 + i].x) > 0.0001) || (abs(vertices[vertices.size() - 3 + i].z - 1) > 0.0001)):
		if (true):
#			var texVertex:Vector3 = vertices[vertices.size() - 3 + i]
			texVertex.z += 1	# Origin shift

			texVertex = textureRotation * texVertex
				
			uvs.push_back(Vector2(
					atan2(-texVertex.z, texVertex.x) / (2 * PI) + 0.5,
#						(vertices[vertices.size() - 3 + i].y + 1) / 2
					1-(asin(texVertex.y) + (PI / 2)) / PI
			))
		else:
			# TODO: This makes poles textured wrong
			# But well, maybe you aren't supposed to look at the dark side...
			# (And texture wrapping doesn't work in x-direction either)
			
			uvs.push_back(Vector2(0,0))
			uvs.push_back(Vector2(0,0))


	var vertexIndexes = PackedInt32Array()
	for i in range(vertices.size()):
		vertexIndexes.push_back(i)



	var destMeshArrays = []
	destMeshArrays.resize(Mesh.ARRAY_MAX)
	destMeshArrays[Mesh.ARRAY_VERTEX] = vertices
	destMeshArrays[Mesh.ARRAY_INDEX] = vertexIndexes
	destMeshArrays[Mesh.ARRAY_TEX_UV] = uvs
	destMeshArrays[Mesh.ARRAY_NORMAL] = normals

	print(vertices.size())
	print(centerPoints.size())
	print(uvs.size())

	newMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, destMeshArrays)
	
	var mdt:MeshDataTool = MeshDataTool.new()
	mdt.create_from_surface(newMesh, 0)
	newMesh.clear_surfaces()
	mdt.commit_to_surface(newMesh)
	mesh = newMesh
	
	var customDataImageTexture = ImageTexture.create_from_image(customDataImage)
	
	material_override.set_shader_parameter("customDataSampler", customDataImageTexture)
	
	
	
	
	
	

#@export var forceBreakGeometry:bool = false

#func _process(delta):
# This is (was) just to make it possible to adjust texture orientation by an eye (and hand)
#	if (forceBreakGeometry):
#		breakGeometry()
#		forceBreakGeometry = false

class StashData:
	var mesh
	var customDataSampler

func stashToolData():
	var stashStorage:StashData = StashData.new()
	
	stashStorage.mesh = mesh
	stashStorage.customDataSampler = material_override.get_shader_parameter("customDataSampler")

	material_override.set_shader_parameter("customDataSampler", null)
	mesh = null
	
	# TODO: Add albedo texture when read runtime

	return stashStorage

func stashPullToolData(stashStorage:StashData):
	mesh = stashStorage.mesh
	material_override.set_shader_parameter("customDataSampler", stashStorage.customDataSampler)
