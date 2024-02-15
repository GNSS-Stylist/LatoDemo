@tool
class_name MeshDisintegratorBase
extends Node3D

enum DisintegrationMethod { PLANAR_2D, PLANAR_CUT }

@export var sourceTextMesh:Mesh

# If defined, will be used for smooth mesh
@export var sourceTextMesh_Smooth:Mesh

@export var maxEdgeLength:float = 1
@export var randomSeed:int = 0
@export var disintegrationMethod:DisintegrationMethod = DisintegrationMethod.PLANAR_2D
@export var depth:float = 0
@export var forceUpdate:bool = false:
	set(_strobe):
		workerThreadMutex.lock()
		workerThreadForceUpdate = true;
		workerThreadSemaphore.post()
		workerThreadMutex.unlock()
	get:
		return false

@export_multiline var textOverride:String = "":
	set(newString):
		if (newString.is_empty()):
			# No point asking the thread to do this job.
			# Also asking it to do so probably caused a lot of crashes when saving the scene. This was very likely
			# likely caused by thread setting the mesh _while_ saving of the scene was in progress
			# (due to animation reset track).
			workerThreadMutex.lock()
			disintegratedMesh.mesh = null
			smoothMesh.mesh = null
			workerThreadLastText = ""
			textOverride = newString
			workerThreadMutex.unlock()
		else:
			workerThreadMutex.lock()
			textOverride = newString
			workerThreadSemaphore.post()
			workerThreadMutex.unlock()
#		breakGeometry()
	get:
		return textOverride
		
@export var albedo:Color:
	set(newAlbedo):
		albedo = newAlbedo
		if (disintegratedMesh):
			disintegratedMesh.set_instance_shader_parameter("albedo", newAlbedo)
		if (smoothMesh):
			smoothMesh.set_instance_shader_parameter("albedo", newAlbedo)
	get:
		return albedo
		
var workerThread:Thread = Thread.new()
var workerThreadMutex:Mutex = Mutex.new()
var workerThreadExitRequest:bool = false
var workerThreadSemaphore:Semaphore = Semaphore.new()
var workerThreadForceUpdate:bool = false
var workerThreadLastText:String = ""

@onready var disintegratedMesh:MeshInstance3D = get_node("DisintegratedMesh")
@onready var smoothMesh:MeshInstance3D = get_node("SmoothMesh")

# Called when the node enters the scene tree for the first time.
func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
#	breakGeometry()
	workerThread.start(Callable(self, "threadCode"))
	workerThreadMutex.lock()
	if (textOverride.is_empty()):
		disintegratedMesh.mesh = null
		smoothMesh.mesh = null
		workerThreadLastText = ""
	else:
		workerThreadForceUpdate = true;
		workerThreadSemaphore.post()
	workerThreadMutex.unlock()

	# Setter can be called before meshes are initialized.
	# Therefore setting instance shader parameters also here.
	# (Otherwise they will not get initialized if the value isn't changed)
	if (disintegratedMesh):
		disintegratedMesh.set_instance_shader_parameter("albedo", albedo)
	if (smoothMesh):
		smoothMesh.set_instance_shader_parameter("albedo", albedo)

func _exit_tree():
	if (workerThread.is_alive()):
		workerThreadMutex.lock()
		workerThreadExitRequest = true;
		workerThreadSemaphore.post()
		workerThreadMutex.unlock()
		workerThread.wait_to_finish()

func threadCode():
	print("InstanceMeshDisintegrator: Worker thread started")
	
	while (!workerThreadExitRequest):
		workerThreadSemaphore.wait()
		
		workerThreadMutex.lock()
		if (workerThreadExitRequest):
			workerThreadMutex.unlock()
			break
			
		var newText = textOverride
			
		if ((newText != workerThreadLastText) || (workerThreadForceUpdate)):
			workerThreadLastText = newText
			workerThreadForceUpdate = false
			var elapsedStartTime:int = Time.get_ticks_msec()
			var newSmoothMesh:Mesh
			if (sourceTextMesh_Smooth):
				newSmoothMesh = sourceTextMesh_Smooth.duplicate(true)
			else:
				newSmoothMesh = sourceTextMesh.duplicate(true)
			if (newSmoothMesh is TextMesh):
				newSmoothMesh.text = ""
				newSmoothMesh.depth = depth
				newSmoothMesh.text = newText
			
			var switchMesh = func(newMesh:Mesh): smoothMesh.mesh = newMesh
			# See long explanation about call_deferred from disintegratedMesh handling...
			switchMesh.call_deferred(newSmoothMesh)
			#smoothMesh.mesh = newSmoothMesh
			
			var baseMesh:Mesh = sourceTextMesh.duplicate(true)
			if (baseMesh is TextMesh):
				baseMesh.text = newText
			var faceCount
#			match (disintegrationMethod):
#				DisintegrationMethod.PLANAR_2D:
			faceCount = breakGeometry(baseMesh)
#				DisintegrationMethod.PLANAR_CUT:
#					faceCount = breakGeometry_PlanarCut(baseMesh)
					
			var elapsedTime = Time.get_ticks_msec() - elapsedStartTime
			
			print("Breaking text \"", newText, "\" took ", elapsedTime, " ms. Faces: ", faceCount)
		
		workerThreadMutex.unlock()

#		var newMeshes = createMesh(threadIndex)

#		workerThreadData[threadIndex].dataMutex.lock()
#		workerThreadData[threadIndex].mesh_Points = newMeshes[0]
#		workerThreadData[threadIndex].mesh_Lines = newMeshes[1]
#		workerThreadData[threadIndex].state = WORKERTHREADSTATE.ready
#		workerThreadData[threadIndex].dataMutex.unlock()
		
		
	print("InstanceMeshDisintegrator: Worker thread exited")


func breakGeometry(sourceMesh:Mesh):
	var randomizer:RandomNumberGenerator = RandomNumberGenerator.new()
	randomizer.seed = randomSeed

	var sourceMeshArrays = []
	
#	sourceMeshArrays = self.mesh.get_mesh_arrays()
	sourceMeshArrays = sourceMesh.surface_get_arrays(0)
	
	var vertices = PackedVector3Array()
#	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()

	var centerPointCustomData = PackedFloat32Array()
	
	var faceCount:int = 0
	var shapeCount:int = 0
	
	for vertexIndex in range(0, sourceMeshArrays[Mesh.ARRAY_INDEX].size(), 3):
		var sourceTri = [sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 0]],
				sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 1]],
				sourceMeshArrays[Mesh.ARRAY_VERTEX][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 2]]]

		var splitTris = subSplit(sourceTri, maxEdgeLength, randomizer)
		
		for splitVertexIndex in range(0, splitTris.size(), 3):
			
			var centerPoint:Vector3
			
			var centerPointCount:int
			
			match (disintegrationMethod):
				DisintegrationMethod.PLANAR_2D:
					var v1:Vector3 = splitTris[splitVertexIndex + 0]
					var v2:Vector3 = splitTris[splitVertexIndex + 1]
					var v3:Vector3 = splitTris[splitVertexIndex + 2]

					vertices.push_back(v1)
					vertices.push_back(v2)
					vertices.push_back(v3)
					
					centerPointCount = 1 * 3
					
					var centerPointSum:Vector3 = Vector3(0,0,0)
					centerPointSum += v1
					centerPointSum += v2
					centerPointSum += v3
					centerPoint = centerPointSum / 3
					
					normals.push_back(sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 0]])
					normals.push_back(sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 1]])
					normals.push_back(sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 2]])
					
					faceCount += 1

				DisintegrationMethod.PLANAR_CUT:
					var v1:Vector3 = splitTris[splitVertexIndex + 0]
					var v2:Vector3 = splitTris[splitVertexIndex + 1]
					var v3:Vector3 = splitTris[splitVertexIndex + 2]

					var centerPointSum:Vector3 = Vector3(0,0,0)
					centerPointSum += v1
					centerPointSum += v2
					centerPointSum += v3
					centerPoint = centerPointSum / 3

					var normal = (v3 - v1).cross(v2-v1).normalized()
					var displacement = depth * 0.5 * normal

					var v1b:Vector3 = v1 - displacement
					var v2b:Vector3 = v2 - displacement
					var v3b:Vector3 = v3 - displacement

					v1 += displacement
					v2 += displacement
					v3 += displacement
					
					# Front Face:
					vertices.push_back(v1)
					vertices.push_back(v2)
					vertices.push_back(v3)

					normals.push_back(sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 0]])
					normals.push_back(sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 1]])
					normals.push_back(sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 2]])

					# Back face:
					vertices.push_back(v1b)
					vertices.push_back(v3b)
					vertices.push_back(v2b)
				
					normals.push_back(-sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 0]])
					normals.push_back(-sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 1]])
					normals.push_back(-sourceMeshArrays[Mesh.ARRAY_NORMAL][sourceMeshArrays[Mesh.ARRAY_INDEX][vertexIndex + 2]])

					# Sides:
					# "A":
					vertices.push_back(v1)
					vertices.push_back(v1b)
					vertices.push_back(v2)
					
					normal = (v2 - v1).cross(v1b - v1).normalized()
					
					normals.push_back(normal)
					normals.push_back(normal)
					normals.push_back(normal)

					vertices.push_back(v2)
					vertices.push_back(v1b)
					vertices.push_back(v2b)
					
					normals.push_back(normal)
					normals.push_back(normal)
					normals.push_back(normal)
				
					# "B":
					vertices.push_back(v2)
					vertices.push_back(v2b)
					vertices.push_back(v3)
					
					normal = (v3 - v2).cross(v2b - v2).normalized()
					
					normals.push_back(normal)
					normals.push_back(normal)
					normals.push_back(normal)

					vertices.push_back(v3)
					vertices.push_back(v2b)
					vertices.push_back(v3b)
					
					normals.push_back(normal)
					normals.push_back(normal)
					normals.push_back(normal)

					# "C":
					vertices.push_back(v3)
					vertices.push_back(v3b)
					vertices.push_back(v1)
					
					normal = (v1 - v3).cross(v3b - v3).normalized()
					
					normals.push_back(normal)
					normals.push_back(normal)
					normals.push_back(normal)

					vertices.push_back(v1)
					vertices.push_back(v3b)
					vertices.push_back(v1b)
					
					normals.push_back(normal)
					normals.push_back(normal)
					normals.push_back(normal)

					centerPointCount = 8 * 3
					
					faceCount += 8

#			centerPoints.push_back(Color(centerPoint.x, centerPoint.y, centerPoint.z, 0))
			for i in range(centerPointCount):
				# Same center for all vertices of this triangle
				# I first tried to use sampler for this as now every vertex has it's own center stored.
				# Samplers, however could not be instance uniforms, so easier this way.
				centerPointCustomData.push_back(centerPoint.x)
				centerPointCustomData.push_back(centerPoint.y)
				centerPointCustomData.push_back(centerPoint.z)
				centerPointCustomData.push_back(shapeCount)

			shapeCount += 1
	
	var vertexIndexes = PackedInt32Array()
	for i in range(vertices.size()):
		vertexIndexes.push_back(i)



	var destMeshArrays = []
	destMeshArrays.resize(Mesh.ARRAY_MAX)
	destMeshArrays[Mesh.ARRAY_VERTEX] = vertices
	destMeshArrays[Mesh.ARRAY_INDEX] = vertexIndexes
#	destMeshArrays[Mesh.ARRAY_TEX_UV] = uvs
	destMeshArrays[Mesh.ARRAY_NORMAL] = normals
	destMeshArrays[Mesh.ARRAY_CUSTOM0] = centerPointCustomData

#	print("Text faces: ", faceCount)
#	print(centerPoints.size())

	var newMesh:ArrayMesh = ArrayMesh.new()

#	newMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sourceMeshArrays)

	@warning_ignore("int_as_enum_without_cast")
	@warning_ignore("int_as_enum_without_match")
	newMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, destMeshArrays, [], {}, 
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT))

	# This is a workaround for bug
	# https://github.com/godotengine/godot/issues/86369
	# (Can't set custom aabb in inspector)
	# causing "death"-text to disappear momentarily when turning camera to the planet
	newMesh.custom_aabb = AABB(Vector3(0,0,0), Vector3(100, 100, 100))

	# There was some weird behavior (locking) when setting the mesh here.
	# So maybe it has something to do with threading -> Set it in the main thread instead
	# Update: Locking was maybe caused by something else, so "reverting" this
	# Update2: Going back to "deferred", since there was strange occasional crashes
	# (at the same time I also changed the sourceTextMesh.duplicates to duplicate 
	# also subresources, so not sure if that was the actual reason for crashes
	# (based on the strange font-signal error prints it probably was, though...)).
	
	var switchMesh = func(newMesh:Mesh): disintegratedMesh.mesh = newMesh
	switchMesh.call_deferred(newMesh)
#	disintegratedMesh.mesh = newMesh
	
	return faceCount

func subSplit(vecs:Array, limit_Squared:float, randomizer:RandomNumberGenerator) -> Array:
	var maxLengthSquared:float = 0
	var maxLengthIndex:int = 0

	for i in range(3):
		var distSquared:float = vecs[i % 3].distance_squared_to(vecs[(i + 1) % 3])
		
		if (distSquared > maxLengthSquared):
			maxLengthSquared = distSquared
			maxLengthIndex = i
	
	var ret = []

	if (maxLengthSquared > limit_Squared):
		var newTri1 = []
		var newTri2 = []

		match maxLengthIndex:
			0:
				var splitPoint = vecs[0] + ((vecs[1] - vecs[0]) * randomizer.randf_range(0.25, 0.75))
				newTri1 = [vecs[0], splitPoint, vecs[2]]
				newTri2 = [splitPoint, vecs[1], vecs[2]]
			1:
				var splitPoint = vecs[1] + ((vecs[2] - vecs[1]) * randomizer.randf_range(0.25, 0.75))
				newTri1 = [vecs[0], vecs[1], splitPoint]
				newTri2 = [vecs[0], splitPoint, vecs[2]]
			2:
				var splitPoint = vecs[2] + ((vecs[0] - vecs[2]) * randomizer.randf_range(0.25, 0.75))
				newTri1 = [vecs[0], vecs[1], splitPoint]
				newTri2 = [vecs[1], vecs[2], splitPoint]
				
		ret = subSplit(newTri1, limit_Squared, randomizer) + subSplit(newTri2, limit_Squared, randomizer)

	else:
		ret = vecs.duplicate()

	return ret

class StashData:
	var smoothMesh
	var disintegratedMesh

func stashToolData():
	print("Stash deathText")
	var stashStorage:StashData = StashData.new()
	stashStorage.smoothMesh = $SmoothMesh.mesh
	stashStorage.disintegratedMesh = $DisintegratedMesh.mesh
	
	$SmoothMesh.mesh = null
	$DisintegratedMesh.mesh = null
	return stashStorage

func stashPullToolData(stashStorage:StashData):
	print("Stashpull deathText")
	$SmoothMesh.mesh = stashStorage.smoothMesh
	$DisintegratedMesh.mesh = stashStorage.disintegratedMesh
