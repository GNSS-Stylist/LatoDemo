@tool
extends MeshInstance3D

@export var sourceMesh:Mesh

# Called when the node enters the scene tree for the first time.
func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	if ((!Global) ||(Engine.is_editor_hint() && Global.cleanTempToolData)):
		# @tool-scripts will generate changes that are saved into .tscn (scene)-files.
		# Clean them when requested
		
		print("Cleaning data generated by @tool, ", self.name)
		mesh = null
		return

	# This breaks indexed geometry into separate faces
	
	var newMesh = ArrayMesh.new()
	
	var sourceMeshArrays = []
	
#	sourceMeshArrays = self.mesh.get_mesh_arrays()
	sourceMeshArrays = sourceMesh.surface_get_arrays(0)

	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()

	for vertexIndex in range(0, sourceMeshArrays[Mesh.ARRAY_INDEX].size(), 3):
#			vertices.push_back(sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + i]] + Vector3(randf_range(-600000, 600000), randf_range(-600000, 600000), randf_range(-600000, 600000)))
		vertices.push_back(sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 0]])
		vertices.push_back(sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 1]])
		vertices.push_back(sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 2]])
#			uvs.push_back(sourceMeshArrays[Mesh.ARRAY_TEX_UV][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + i]])

		normals.push_back(sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 0]])
		normals.push_back(sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 1]])
		normals.push_back(sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 2]])

#		edgeIds.push_back(Color(0, 1, 0, 0))
#		edgeIds.push_back(Color(0, 0, 1, 0))
#		edgeIds.push_back(Color(0, 0, 0, 1))

	# Subdivision for "almost infinite zoomer":
	# Coordinates taken from a ply-file generated with MeshLab (with only one face left)
	var v1:Vector3 = Vector3(0, -0.178253, 0.0008850029563904904)
	var v2:Vector3 = Vector3(-0.16246, 0.089128, -0.0004179970436095637)
	var v3:Vector3 = Vector3(0.16246, 0.089128, -0.0004179970436095637)

	# Planet's origin
	var orig:Vector3 = Vector3(0, 0, -1)
	
	# "Subdivided triangles"
#	if false:
	for i in range(28):
		var newV1 = (v1 + v2) / 2
		var newV2 = (v2 + v3) / 2
		var newV3 = (v3 + v1) / 2

		vertices.push_back(v1)
		normals.push_back((v1-orig).normalized())
		vertices.push_back(newV1)
		normals.push_back((newV1-orig).normalized())
		vertices.push_back(newV3)
		normals.push_back((newV3-orig).normalized())

		vertices.push_back(v2)
		normals.push_back((v2-orig).normalized())
		vertices.push_back(newV2)
		normals.push_back((newV2-orig).normalized())
		vertices.push_back(newV1)
		normals.push_back((newV1-orig).normalized())

		vertices.push_back(v3)
		normals.push_back((v3-orig).normalized())
		vertices.push_back(newV3)
		normals.push_back((newV3-orig).normalized())
		vertices.push_back(newV2)
		normals.push_back((newV2-orig).normalized())

#		for ii in range(3):
#			normals.push_back(Vector3(0, 0, 1))
#			normals.push_back(Vector3(0, 0, 1))
#			normals.push_back(Vector3(0, 0, 1))

#			edgeIds.push_back(Color(0, 1, 0, 0))
#			edgeIds.push_back(Color(0, 0, 1, 0))
#			edgeIds.push_back(Color(0, 0, 0, 1))

		v1 = newV1
		v2 = newV2
		v3 = newV3
	
	if true:
		# Last triangle inside
		vertices.push_back(v1)
		normals.push_back((v1-orig).normalized())
		vertices.push_back(v2)
		normals.push_back((v2-orig).normalized())
		vertices.push_back(v3)
		normals.push_back((v3-orig).normalized())

	for vert in vertices:
		uvs.push_back(Vector2(vert.length(), 0))



	var vertexIndexes = PackedInt32Array()
	for i in range(vertices.size()):
		vertexIndexes.push_back(i)

	var destMeshArrays = []
	destMeshArrays.resize(Mesh.ARRAY_MAX)
	destMeshArrays[Mesh.ARRAY_VERTEX] = vertices
	destMeshArrays[Mesh.ARRAY_INDEX] = vertexIndexes
	destMeshArrays[Mesh.ARRAY_TEX_UV] = uvs
	destMeshArrays[Mesh.ARRAY_NORMAL] = normals

	newMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, destMeshArrays)
	
	var mdt:MeshDataTool = MeshDataTool.new()
	mdt.create_from_surface(newMesh, 0)
	newMesh.clear_surfaces()
	mdt.commit_to_surface(newMesh)
	mesh = newMesh

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if ((!Global) ||(Engine.is_editor_hint() && Global.cleanTempToolData)):
		return
	pass
#	material_override.set_shader_parameter("replayTime", tunePlayer.getFilteredPlaybackPosition())

class StashData:
	var mesh

func stashToolData():
	var stashStorage:StashData = StashData.new()
	stashStorage.mesh = mesh
	mesh = null
	return stashStorage

func stashPullToolData(stashStorage:StashData):
	mesh = stashStorage.mesh
