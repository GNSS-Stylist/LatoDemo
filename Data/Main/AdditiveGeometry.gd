#@tool
extends MeshInstance3D

#@export var replayTime:float = 0
@export var generatedFlyingDistance:float = 5.0

@export var meshMaterial:Material
@export var wireframeMaterial:Material

@export var readTextureData:bool = true
@export var additiveGeometryStorageNodePath:String = "/root/Main/AdditiveGeometryStorage"
@export var lidarDataStorageNodePath:String = "/root/Main/LidarDataStorage"
@export var forcedShaderBaseTime:float = 0

@export var overrideReplayTime_WireFrame_Local:bool = 0
@export var localReplayTimeOverride_WireFrame:float = 0

@export var overrideReplayTime_AdditiveGeometry_Local:bool = 0
@export var localReplayTimeOverride_AdditiveGeometry:float = 0

var additiveGeometryStorage:AdditiveGeometryStorage
var lidarDataStorage:LidarDataStorage

var shaderBaseTimeInUse:float = 0

class WireframeLine:
	var startPointIndex:int
	var endPointIndex:int
	var minShotTime:float
	var maxShotTime:float
	func _init(startPointIndex_p:int, endPointIndex_p:int, minShotTime_p:float, maxShotTime_p:float):
		self.startPointIndex = startPointIndex_p
		self.endPointIndex = endPointIndex_p
		self.minShotTime = minShotTime_p
		self.maxShotTime = maxShotTime_p

# Called when the node enters the scene tree for the first time.
func _ready():
	additiveGeometryStorage = get_node(additiveGeometryStorageNodePath)
	lidarDataStorage = get_node(lidarDataStorageNodePath)

	var elapsedStartTime = Time.get_ticks_usec()
	
	# Lidar's position when this vertex (of a face) was "shot":
	# Not actually centroid since face is zero-sized here
	var faceCentroidStartOrigins = PackedColorArray()

	# Final centroid of the vertex's face:
	var faceCentroidFinalOrigins = PackedColorArray()

	# Vertex's "flat-face"-normals:
	var faceNormals = PackedColorArray()
	
	# Vertex (unmodified) normals, read from a file:
	var vertexNormals = PackedVector3Array()
	
	# Vertices (unmodified, non-indexed):
	var vertices = PackedVector3Array()
	
	# Just a helper for later processing:
	# (to be able to differentiate between vertices with the same coords)
	var vertexIndexes = PackedInt32Array()
	
	# UV is used for texture (as expected?)
	var uv = PackedVector2Array()
	
	# x here is used as times (unmodified) when faces/vertices were "shot", read from a file.
	# Other fields are used to draw edges.
	var shotTimesAndEdgeIds = PackedColorArray()
	
	if ((!additiveGeometryStorage.faceSyncKeys.is_empty()) && (forcedShaderBaseTime == 0.0)):
		shaderBaseTimeInUse = additiveGeometryStorage.faceSyncKeys[0]
	else:
		shaderBaseTimeInUse = forcedShaderBaseTime
	
	for currentFaceSyncItemIndex in range(0, additiveGeometryStorage.faceSyncKeys.size()):
		var currentFaceSyncItemTime:int = additiveGeometryStorage.faceSyncKeys[currentFaceSyncItemIndex]
		var originFromLidar:Vector3
		var originFromLidarKnown:bool = false
		
		# Try to find origin from lidar data
		
		if (lidarDataStorage.beamData.has(currentFaceSyncItemTime)):
			# Although there is more items in the array, we here rely that
			# the first one represents them all good enough
			# (they are all 1 ms apart at most anyway)
			
			originFromLidar = lidarDataStorage.beamData.get(currentFaceSyncItemTime)[0].origin
			originFromLidarKnown = true
		
		for subItem in additiveGeometryStorage.faceSync[currentFaceSyncItemTime]:
			vertexIndexes.push_back(additiveGeometryStorage.fileVertexIndexes[subItem * 3 + 0])
			vertexIndexes.push_back(additiveGeometryStorage.fileVertexIndexes[subItem * 3 + 1])
			vertexIndexes.push_back(additiveGeometryStorage.fileVertexIndexes[subItem * 3 + 2])
			
			#var faceVerts = []
			var faceVerts_0 = additiveGeometryStorage.fileVertices[additiveGeometryStorage.fileVertexIndexes[subItem * 3 + 0]]
			var faceVerts_1 = additiveGeometryStorage.fileVertices[additiveGeometryStorage.fileVertexIndexes[subItem * 3 + 1]]
			var faceVerts_2 = additiveGeometryStorage.fileVertices[additiveGeometryStorage.fileVertexIndexes[subItem * 3 + 2]]

			vertices.push_back(faceVerts_0)
			vertices.push_back(faceVerts_1)
			vertices.push_back(faceVerts_2)

			var faceNormal = ((faceVerts_2 - faceVerts_0).cross(faceVerts_1 - faceVerts_0)).normalized()
			var faceNormal_Color:Color = Color(faceNormal.x, faceNormal.y, faceNormal.z)
			faceNormals.push_back(faceNormal_Color)
			faceNormals.push_back(faceNormal_Color)
			faceNormals.push_back(faceNormal_Color)

			vertexNormals.push_back(additiveGeometryStorage.fileNormals[additiveGeometryStorage.fileVertexIndexes[subItem * 3 + 0]])
			vertexNormals.push_back(additiveGeometryStorage.fileNormals[additiveGeometryStorage.fileVertexIndexes[subItem * 3 + 1]])
			vertexNormals.push_back(additiveGeometryStorage.fileNormals[additiveGeometryStorage.fileVertexIndexes[subItem * 3 + 2]])
			
			if (readTextureData):
				uv.push_back(additiveGeometryStorage.fileTextureCoords[additiveGeometryStorage.fileTextureIndexes[subItem * 3 + 0]])
				uv.push_back(additiveGeometryStorage.fileTextureCoords[additiveGeometryStorage.fileTextureIndexes[subItem * 3 + 1]])
				uv.push_back(additiveGeometryStorage.fileTextureCoords[additiveGeometryStorage.fileTextureIndexes[subItem * 3 + 2]])
			else:
				# These are quite arbitrary, but they shouldn't even be used...
				uv.push_back(Vector2(0, 0))
				uv.push_back(Vector2(1, 0))
				uv.push_back(Vector2(0, 1))

			var medianOrigin = (faceVerts_0 + faceVerts_1 + faceVerts_2) / 3
			var medianOrigin_Color:Color = Color(medianOrigin.x, medianOrigin.y, medianOrigin.z)
			faceCentroidFinalOrigins.push_back(medianOrigin_Color)
			faceCentroidFinalOrigins.push_back(medianOrigin_Color)
			faceCentroidFinalOrigins.push_back(medianOrigin_Color)

			var startOrigin:Vector3

			if originFromLidarKnown:
				startOrigin = originFromLidar
			else:
				startOrigin = medianOrigin + faceNormal * generatedFlyingDistance
			
			var startOrigin_Color:Color = Color(startOrigin.x, startOrigin.y, startOrigin.z)
			faceCentroidStartOrigins.push_back(startOrigin_Color)
			faceCentroidStartOrigins.push_back(startOrigin_Color)
			faceCentroidStartOrigins.push_back(startOrigin_Color)
			
			# UV2 used to feed the time and distance from one edge in y
			var shotTime:float = currentFaceSyncItemTime - shaderBaseTimeInUse
			
			shotTimesAndEdgeIds.push_back(Color(shotTime, 1, 0, 0))
			shotTimesAndEdgeIds.push_back(Color(shotTime, 0, 1, 0))
			shotTimesAndEdgeIds.push_back(Color(shotTime, 0, 0, 1))

	var arrayMeshArrays_MainMesh = []
	arrayMeshArrays_MainMesh.resize(ArrayMesh.ARRAY_MAX)

	arrayMeshArrays_MainMesh[ArrayMesh.ARRAY_VERTEX] = vertices
	arrayMeshArrays_MainMesh[ArrayMesh.ARRAY_NORMAL] = vertexNormals
	
	arrayMeshArrays_MainMesh[ArrayMesh.ARRAY_TEX_UV] = uv

#	arrayMeshArrays_MainMesh[ArrayMesh.ARRAY_TEX_UV2] = UV2
	
	arrayMeshArrays_MainMesh[ArrayMesh.ARRAY_CUSTOM0] = faceCentroidStartOrigins
	arrayMeshArrays_MainMesh[ArrayMesh.ARRAY_CUSTOM1] = faceCentroidFinalOrigins
	arrayMeshArrays_MainMesh[ArrayMesh.ARRAY_CUSTOM2] = faceNormals
	arrayMeshArrays_MainMesh[ArrayMesh.ARRAY_CUSTOM3] = shotTimesAndEdgeIds

	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrayMeshArrays_MainMesh, [], {}, 
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) |
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) |
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) |
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT))
			
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrayMeshArrays_MainMesh, [], {}, 
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) |
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) |
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) |
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT))

	mesh.surface_set_material((mesh.get_surface_count() - 2), wireframeMaterial)
	mesh.surface_set_material((mesh.get_surface_count() - 1), meshMaterial)

	var elapsed = Time.get_ticks_usec() - elapsedStartTime
	print("Additive geometry mesh creation time: ", elapsed, " us")



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if (mesh):
		if (overrideReplayTime_WireFrame_Local):
			get_active_material(0).set_shader_param("replayTime", localReplayTimeOverride_WireFrame - shaderBaseTimeInUse)
		elif (Global.overrideReplayTime_WireFrames):
			get_active_material(0).set_shader_param("replayTime", Global.replayTimeOverride_WireFrames - shaderBaseTimeInUse)
		else:
			get_active_material(0).set_shader_param("replayTime", Global.replayTime_Lidar - shaderBaseTimeInUse)

		if (overrideReplayTime_AdditiveGeometry_Local):
			get_active_material(1).set_shader_param("replayTime", localReplayTimeOverride_AdditiveGeometry - shaderBaseTimeInUse)
		elif (Global.overrideReplayTime_AdditiveGeometries):
			get_active_material(1).set_shader_param("replayTime", Global.replayTimeOverride_AdditiveGeometries - shaderBaseTimeInUse)
		else:
			get_active_material(1).set_shader_param("replayTime", Global.replayTime_Lidar - shaderBaseTimeInUse)
