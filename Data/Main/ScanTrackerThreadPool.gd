@tool
extends Node

enum DRAWN_POINT_TYPES { all, onlyAccepted }
@export var drawnPointTypes:DRAWN_POINT_TYPES = DRAWN_POINT_TYPES.all

enum SHAPE {circle, cube, sphere}
@export var shape:SHAPE = SHAPE.circle

@export var billboardCirclePoints:int = 3

@export var pointSize:float = 0.005

@export var numOfWorkerThreads:int = 7

var LidarDataStorage = load("Data/Main/LidarDataStorage.gd")
var visiblePointTypes = [
	LidarDataStorage.LSItemType.ACCEPTED,
	LidarDataStorage.LSItemType.REJECTED_OUTSIDE_BOUNDING_SPHERE,
	LidarDataStorage.LSItemType.REJECTED_NOT_SCANNING,
	LidarDataStorage.LSItemType.REJECTED_OBJECT_NOT_ACTIVE,
	LidarDataStorage.LSItemType.REJECTED_ANGLE,

# No point drawing these (or actually these draw quite funny points inside the lidar itself :) )
#	LidarDataStorage.LSItemType.REJECTED_QUALITY_PRE: Color(1, 0, 0),
#	LidarDataStorage.LSItemType.REJECTED_QUALITY_POST: Color(1, 0, 0),

# Rejected for being too near points are only reflections from the camera
# not much of use here although they draw a nice "track"
#	LidarDataStorage.LSItemType.REJECTED_DISTANCE_NEAR: Color(1, 0, 0),
	LidarDataStorage.LSItemType.REJECTED_DISTANCE_FAR,
	LidarDataStorage.LSItemType.REJECTED_DISTANCE_DELTA,
	LidarDataStorage.LSItemType.REJECTED_SLOPE,
]

enum WORKERTHREADSTATE { idle, working, ready }

class ThreadData:
	var exitRequest:bool
	var state:WORKERTHREADSTATE
	var scanTrackerInstanceId_Points:int	# Instance id (="pointer") of ScanTracker_Points which data this thread is handling
	var scanTrackerInstanceId_Lines:int	# Instance id (="pointer") of ScanTracker_Lines which data this thread is handling
	var dataMutex:Mutex
	var wakeSemaphore:Semaphore
	var mesh_Points:Mesh	# Actually ArrayMesh
	var mesh_Lines:Mesh	# Actually ArrayMesh

@onready var dataStorage:LidarDataStorage = get_node("../LidarDataStorage")

var workerThreads = []
var workerThreadData = []	# Instances of ThreadData
#var textureIndexes = {}		# key = time (as in lidarDataStorage.beamData), value = index (/offset) in texture (in which index data for this time starts)

# Called when the node enters the scene tree for the first time.
func _ready():
#	var textureIndex = 0
#	for time in dataStorage.beamDataKeys:
#		textureIndexes[time] = textureIndex
#		textureIndex += dataStorage.beamData[time].size()
#	
#	print("textureIndex final value: ", textureIndex)


	
#	var dbg_Mesh = constructPointMeshArray(925000, 926000, getCircleMeshArrays(billboardCirclePoints, pointSize), getLidarLineMeshArrays())
	
	workerThreads.resize(numOfWorkerThreads)
	workerThreadData.resize(numOfWorkerThreads)
	
	for threadIndex in range(numOfWorkerThreads):
		workerThreads[threadIndex] = Thread.new()
		var threadData:ThreadData = ThreadData.new()
		threadData.exitRequest = false
		threadData.state = WORKERTHREADSTATE.idle
		threadData.scanTrackerInstanceId_Points = 0
		threadData.scanTrackerInstanceId_Lines = 0
		threadData.dataMutex = Mutex.new()
		threadData.wakeSemaphore = Semaphore.new()
		threadData.mesh_Points = null
		threadData.mesh_Lines = null
		workerThreadData[threadIndex] = threadData
		workerThreads[threadIndex].start(Callable(self, "threadCode").bind(threadIndex))

var dbg_AccumulatedDelta:float = 0
var dbg_Done:bool = false
var dbg_PointSetIndex:int = 0

var currentShaderBaseTime:float = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):

	currentShaderBaseTime = Global.scanTrackerShaderBaseTime

	for threadIndex in range(workerThreads.size()):
		workerThreadData[threadIndex].dataMutex.lock()
		var threadState:WORKERTHREADSTATE = workerThreadData[threadIndex].state
		
		if (threadState == WORKERTHREADSTATE.ready):
			workerThreadData[threadIndex].state = WORKERTHREADSTATE.idle
			var scanTrackerObject_Points = instance_from_id(workerThreadData[threadIndex].scanTrackerInstanceId_Points)
			var scanTrackerObject_Lines = instance_from_id(workerThreadData[threadIndex].scanTrackerInstanceId_Lines)
			scanTrackerObject_Points.mesh = workerThreadData[threadIndex].mesh_Points
			scanTrackerObject_Lines.mesh = workerThreadData[threadIndex].mesh_Lines
		
		workerThreadData[threadIndex].dataMutex.unlock()

	var workAdded = true
	var numofPointSets = get_node("../../Main").lidarPointSets.size()
	while ((dbg_PointSetIndex < numofPointSets) and (workAdded)):
		workAdded = false
		for threadIndex in range(workerThreads.size()):
			workerThreadData[threadIndex].dataMutex.lock()
			if (workerThreadData[threadIndex].state == WORKERTHREADSTATE.idle):
#				print("Adding work, index: ", dbg_PointSetIndex)
				workerThreadData[threadIndex].scanTrackerInstanceId_Points = get_node("../../Main").lidarPointSets[dbg_PointSetIndex].get_instance_id()
				workerThreadData[threadIndex].scanTrackerInstanceId_Lines = get_node("../../Main").lidarLineSets[dbg_PointSetIndex].get_instance_id()
				workerThreadData[threadIndex].state = WORKERTHREADSTATE.working
				workerThreadData[threadIndex].wakeSemaphore.post()
				workerThreadData[threadIndex].dataMutex.unlock()
				dbg_PointSetIndex += 1
				workAdded = true
				if (dbg_PointSetIndex == numofPointSets):
					print("Point sets precached.")
				break
			
			# For debugging:
#			createMesh(threadIndex)
			
			workerThreadData[threadIndex].dataMutex.unlock()
		
			
	if false:
#	if (!dbg_Done):
		for threadIndex in range(workerThreads.size()):
			workerThreadData[threadIndex].dataMutex.lock()
			workerThreadData[threadIndex].scanTrackerInstanceId = get_node("../../Main").lidarPointSets[threadIndex + 60].get_instance_id()
			workerThreadData[threadIndex].state = WORKERTHREADSTATE.working
			workerThreadData[threadIndex].dataMutex.unlock()
			workerThreadData[threadIndex].wakeSemaphore.post()
		dbg_Done = true
		
	pass
		

func _exit_tree():
	for threadIndex in range(workerThreads.size()):
		workerThreadData[threadIndex].dataMutex.lock()
		workerThreadData[threadIndex].exitRequest = true
		workerThreadData[threadIndex].dataMutex.unlock()
		workerThreadData[threadIndex].wakeSemaphore.post()

	for threadIndex in range(workerThreads.size()):
		workerThreads[threadIndex].wait_to_finish()

func threadCode(threadIndex:int):
	print("ScanTrackerThreadPool: Thread started, index: ", threadIndex)
	
	while (!workerThreadData[threadIndex].exitRequest):
		workerThreadData[threadIndex].wakeSemaphore.wait()
		
		workerThreadData[threadIndex].dataMutex.lock()
		if (workerThreadData[threadIndex].exitRequest):
			workerThreadData[threadIndex].dataMutex.unlock()
			break
		workerThreadData[threadIndex].dataMutex.unlock()
		
		var newMeshes = createMesh(threadIndex)

		workerThreadData[threadIndex].dataMutex.lock()
		workerThreadData[threadIndex].mesh_Points = newMeshes[0]
		workerThreadData[threadIndex].mesh_Lines = newMeshes[1]
		workerThreadData[threadIndex].state = WORKERTHREADSTATE.ready
		workerThreadData[threadIndex].dataMutex.unlock()
		
#		var scanTrackerObject = instance_from_id(workerThreadData[threadIndex].scanTrackerInstanceId)
#		scanTrackerObject.mesh = newMesh
		
		
	print("ScanTrackerThreadPool: Thread exited, index: ", threadIndex)

func createMesh(threadIndex:int):
#func createMesh():
	var scanTrackerObject = instance_from_id(workerThreadData[threadIndex].scanTrackerInstanceId_Points)
	var firstReplayTime:float = scanTrackerObject.firstReplayTimeToShow
	var lastReplayTime:float = scanTrackerObject.lastReplayTimeToShow

#	var elapsedStartTime:int = 0
	
	var shapeArray_Point = []
	match (shape):
		SHAPE.circle:
			shapeArray_Point = getCircleMeshArrays(billboardCirclePoints, pointSize)
		SHAPE.cube:
			var cubeMesh = BoxMesh.new()
			cubeMesh.set_size(Vector3(pointSize, pointSize, pointSize))
			shapeArray_Point = cubeMesh.get_mesh_arrays()
		SHAPE.sphere:
			var sphereMesh:SphereMesh = SphereMesh.new()
			sphereMesh.set_height(pointSize)
			sphereMesh.set_radius(pointSize / 2)
			sphereMesh.set_radial_segments(4)
			sphereMesh.set_rings(2)
			shapeArray_Point = sphereMesh.get_mesh_arrays()

	var shapeArray_Line = []
	shapeArray_Line = getLidarLineMeshArrays()

#	elapsedStartTime = Time.get_ticks_usec()
	var arrayMeshArrays = constructPointMeshArray(firstReplayTime, lastReplayTime, shapeArray_Point, shapeArray_Line)
#	elapsed = Time.get_ticks_usec() - elapsedStartTime
#	print("constructPointMeshArray-thread time: ", elapsed, " us")
	
#	print("constructPointMeshArray  ended")

	if (arrayMeshArrays[0][Mesh.ARRAY_VERTEX].is_empty()):
		print("if (arrayMeshArray[Mesh.ARRAY_VERTEX].is_empty())")
		return null
	
#	var customDataStartTime = Time.get_ticks_usec()
	
#	elapsedStartTime = Time.get_ticks_usec()

	var mesh_Points = ArrayMesh.new()

	mesh_Points.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrayMeshArrays[0], [], {}, 
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) |
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) |
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) |
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT))

	mesh_Points.surface_set_material((mesh_Points.get_surface_count() - 1), Global.lidarPointMaterial)
#	var elapsed = Time.get_ticks_usec() - elapsedStartTime
#	print("add_surface_from_arrays time: ", elapsed, " us")

	var mesh_Lines = ArrayMesh.new()

	mesh_Lines.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrayMeshArrays[1], [], {}, 
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) |
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) |
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) |
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)) # |
#			Mesh.ARRAY_FORMAT_INDEX)

	mesh_Lines.surface_set_material((mesh_Lines.get_surface_count() - 1), Global.lidarLineMaterial)

	return [mesh_Points, mesh_Lines]
	

#func constructPointMeshArray(firstReplayTime:int, lastReplayTime:int):
func constructPointMeshArray(firstReplayTime:float, lastReplayTime:float, shapeArray_Point, shapeArray_Line):
#	print("thread")
	
	var itemIndex = dataStorage.beamDataKeys.bsearch(firstReplayTime, true)
	var lastItemIndex = dataStorage.beamDataKeys.bsearch(lastReplayTime, false)
	
	var arrayMeshArray_Points = []
	arrayMeshArray_Points.resize(Mesh.ARRAY_MAX)

#	print("thread2")
	arrayMeshArray_Points[Mesh.ARRAY_VERTEX] = PackedVector3Array()
#	arrayMeshArray_Points[Mesh.ARRAY_INDEX] = PackedInt32Array()
	arrayMeshArray_Points[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	arrayMeshArray_Points[Mesh.ARRAY_TEX_UV2] = PackedVector2Array()
	arrayMeshArray_Points[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array()
	arrayMeshArray_Points[Mesh.ARRAY_CUSTOM1] = PackedFloat32Array()

	var arrayMeshArray_Lines = []
	arrayMeshArray_Lines.resize(Mesh.ARRAY_MAX)

	arrayMeshArray_Lines[Mesh.ARRAY_VERTEX] = PackedVector3Array()
#	arrayMeshArray_Lines[Mesh.ARRAY_INDEX] = PackedInt32Array()
	arrayMeshArray_Lines[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	arrayMeshArray_Lines[Mesh.ARRAY_TEX_UV2] = PackedVector2Array()
	arrayMeshArray_Lines[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array()
	arrayMeshArray_Lines[Mesh.ARRAY_CUSTOM1] = PackedFloat32Array()

	var arrayToAppend_Points = shapeArray_Point.duplicate(true)

	arrayToAppend_Points[Mesh.ARRAY_TEX_UV2] = PackedVector2Array()
	arrayToAppend_Points[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array()
	arrayToAppend_Points[Mesh.ARRAY_CUSTOM1] = PackedFloat32Array()

	arrayToAppend_Points[Mesh.ARRAY_TEX_UV2].resize(arrayToAppend_Points[Mesh.ARRAY_VERTEX].size())
	arrayToAppend_Points[Mesh.ARRAY_CUSTOM0].resize(arrayToAppend_Points[Mesh.ARRAY_VERTEX].size() * 4)
	arrayToAppend_Points[Mesh.ARRAY_CUSTOM1].resize(arrayToAppend_Points[Mesh.ARRAY_VERTEX].size() * 4)

	var arrayToAppend_Lines = shapeArray_Line.duplicate(true)

#	arrayToAppend_Lines[Mesh.ARRAY_TEX_UV2] = PackedVector2Array()
	arrayToAppend_Lines[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array()
	arrayToAppend_Lines[Mesh.ARRAY_CUSTOM1] = PackedFloat32Array()

#	arrayToAppend_Lines[Mesh.ARRAY_TEX_UV2].resize(arrayToAppend_Lines[Mesh.ARRAY_VERTEX].size())
	arrayToAppend_Lines[Mesh.ARRAY_CUSTOM0].resize(arrayToAppend_Lines[Mesh.ARRAY_VERTEX].size() * 4)
	arrayToAppend_Lines[Mesh.ARRAY_CUSTOM1].resize(arrayToAppend_Lines[Mesh.ARRAY_VERTEX].size() * 4)

	var numOfVerticesPerItem_Points:int = shapeArray_Point[Mesh.ARRAY_VERTEX].size()
#	var numOfIndexesPerItem_Points:int = shapeArray_Point[Mesh.ARRAY_INDEX].size()

	var numOfVerticesPerItem_Lines:int = shapeArray_Line[Mesh.ARRAY_VERTEX].size()
#	var numOfIndexesPerItem_Lines:int = shapeArray_Line[Mesh.ARRAY_INDEX].size()

	var lastRotationAngle:float = 0
	var minRotationAngleDiff:float = 0
#	var minRotationAngleDiff:float = 2 * (2.0 * PI / 360.0)

	# "Arbitrary" index of point/line (lidar hit/point, not gfx) in the mesh.
	# This can be used in shaders to show every nth point/line for example.
	# Stored in CUSTOM0 (= Color = Vec4)'s alpha
	var hitIndex:int = 0

	while ((itemIndex <= lastItemIndex) and (itemIndex < dataStorage.beamDataKeys.size())):
		var replayTime:int = dataStorage.beamDataKeys[itemIndex]
		var numOfSubItems = dataStorage.beamData[replayTime].size()
		for subItemIndex in range(numOfSubItems):
			var subItem = dataStorage.beamData[replayTime][subItemIndex]
			
			if (abs(subItem.rotation - lastRotationAngle) < minRotationAngleDiff):
				continue
			lastRotationAngle = subItem.rotation
			
			var interpolatedReplayTime:float = (replayTime + float(subItemIndex) / numOfSubItems)
			if ((drawnPointTypes == DRAWN_POINT_TYPES.all) or (subItem.type == LidarDataStorage.LSItemType.ACCEPTED)):
				if ((visiblePointTypes.has(subItem.type)) and (subItem.origin.distance_squared_to(subItem.hitPoint) > 0.15)):
					# <1 m limit to filter out reflections from a camera
					# (If you want to draw the path of the camera, lower the limit
					# to something like 0.001).

#					var indexShift_Points = arrayMeshArray_Points[Mesh.ARRAY_VERTEX].size()

					var hitPoint:Vector3 = subItem.hitPoint
					var origin:Vector3 = subItem.origin

					for i in range(numOfVerticesPerItem_Points):
						arrayToAppend_Points[Mesh.ARRAY_VERTEX][i] = shapeArray_Point[Mesh.ARRAY_VERTEX][i] + hitPoint
						# Note: Time used in shader is relative to currentShaderBaseTime to keep it as accurate as possible
						arrayToAppend_Points[Mesh.ARRAY_TEX_UV2][i] = Vector2(interpolatedReplayTime - currentShaderBaseTime, subItem.type)
						
						arrayToAppend_Points[Mesh.ARRAY_CUSTOM0][i * 4 + 0] = hitPoint.x
						arrayToAppend_Points[Mesh.ARRAY_CUSTOM0][i * 4 + 1] = hitPoint.y
						arrayToAppend_Points[Mesh.ARRAY_CUSTOM0][i * 4 + 2] = hitPoint.z
						arrayToAppend_Points[Mesh.ARRAY_CUSTOM0][i * 4 + 3] = hitIndex
						
						arrayToAppend_Points[Mesh.ARRAY_CUSTOM1][i * 4 + 0] = origin.x
						arrayToAppend_Points[Mesh.ARRAY_CUSTOM1][i * 4 + 1] = origin.y
						arrayToAppend_Points[Mesh.ARRAY_CUSTOM1][i * 4 + 2] = origin.z
						arrayToAppend_Points[Mesh.ARRAY_CUSTOM1][i * 4 + 3] = (hitPoint - origin).length()
					
#					for i in range(numOfIndexesPerItem_Points):
#						arrayToAppend_Points[Mesh.ARRAY_INDEX][i] = shapeArray_Point[Mesh.ARRAY_INDEX][i] + indexShift_Points

					for i in range(int(Mesh.ARRAY_MAX)):
						if (arrayToAppend_Points[i] != null and arrayMeshArray_Points[i] != null):
							arrayMeshArray_Points[i].append_array(arrayToAppend_Points[i])
						
					# Lines:

#					var indexShift_Lines = arrayMeshArray_Lines[Mesh.ARRAY_VERTEX].size()

					for i in range(numOfVerticesPerItem_Lines):
						arrayToAppend_Lines[Mesh.ARRAY_VERTEX][i] = shapeArray_Line[Mesh.ARRAY_VERTEX][i] + hitPoint
						# Note: Time used in shader is relative to currentShaderBaseTime to keep it as accurate as possible
						arrayToAppend_Lines[Mesh.ARRAY_TEX_UV2][i] = Vector2(interpolatedReplayTime - currentShaderBaseTime, (int(shapeArray_Line[Mesh.ARRAY_TEX_UV2][i].y) | subItem.type))
						
						arrayToAppend_Lines[Mesh.ARRAY_CUSTOM0][i * 4 + 0] = hitPoint.x
						arrayToAppend_Lines[Mesh.ARRAY_CUSTOM0][i * 4 + 1] = hitPoint.y
						arrayToAppend_Lines[Mesh.ARRAY_CUSTOM0][i * 4 + 2] = hitPoint.z
						arrayToAppend_Lines[Mesh.ARRAY_CUSTOM0][i * 4 + 3] = hitIndex
						
						arrayToAppend_Lines[Mesh.ARRAY_CUSTOM1][i * 4 + 0] = origin.x
						arrayToAppend_Lines[Mesh.ARRAY_CUSTOM1][i * 4 + 1] = origin.y
						arrayToAppend_Lines[Mesh.ARRAY_CUSTOM1][i * 4 + 2] = origin.z
						arrayToAppend_Lines[Mesh.ARRAY_CUSTOM1][i * 4 + 3] = (hitPoint - origin).length()
					
#					for i in range(numOfIndexesPerItem_Lines):
#						arrayToAppend_Lines[Mesh.ARRAY_INDEX][i] = shapeArray_Line[Mesh.ARRAY_INDEX][i] + indexShift_Lines

					for i in range(int(Mesh.ARRAY_MAX)):
						if (arrayToAppend_Lines[i] != null and arrayMeshArray_Lines[i] != null):
							arrayMeshArray_Lines[i].append_array(arrayToAppend_Lines[i])
			hitIndex += 1

		itemIndex += 1

	return [arrayMeshArray_Points, arrayMeshArray_Lines]
	
	

func getCircleMeshArrays(numOfEdgePoints:int, radius:float):
# TODO: Consider using triangle fan? (That in closer inspection is deprecated in DX V?, so maybe not?)
	if (numOfEdgePoints < 3):
		print ("getCircleMeshArrays: Invalid number of points")
		return []
	
	var vertexArray:PackedVector3Array = PackedVector3Array()
	var uvArray:PackedVector2Array = PackedVector2Array()

	var angleOffset = deg_to_rad(-120)

	for pointIndex in range(0, numOfEdgePoints):
		var angle:float = pointIndex * (2 * PI) / numOfEdgePoints + angleOffset
		var newPoint:Vector3 = Vector3(sin(angle), cos(angle), 0)
		newPoint *= radius
		vertexArray.push_back(newPoint)

#	var indexArray:PackedInt32Array = PackedInt32Array()

#	var numOfTriangles:int = numOfEdgePoints - 2
	
#	for triangleIndex in range(0, numOfTriangles):
#		indexArray.push_back(0)
#		indexArray.push_back(triangleIndex + 1)
#		indexArray.push_back(triangleIndex + 2)
	
	uvArray.push_back(Vector2(-sin(deg_to_rad(60)) * 2,   -1))
	uvArray.push_back(Vector2(0, sqrt(1 + pow((sin(deg_to_rad(60)) * 2), 2))))
	uvArray.push_back(Vector2(sin(deg_to_rad(60)) * 2,   -1))
	
	var meshArrays = []
	meshArrays.resize(Mesh.ARRAY_MAX)

	meshArrays[Mesh.ARRAY_VERTEX] = vertexArray
#	meshArrays[Mesh.ARRAY_INDEX] = indexArray
	meshArrays[Mesh.ARRAY_TEX_UV] = uvArray
	
	return meshArrays

func getLidarLineMeshArrays():
	# Vertices for
	var meshArrays = []
	meshArrays.resize(Mesh.ARRAY_MAX)

	var vertexArray:PackedVector3Array = PackedVector3Array()
	var uvArray:PackedVector2Array = PackedVector2Array()
	var uv2Array:PackedVector2Array = PackedVector2Array()

	# Point order is like this:
	# 0,  1&3 <- Lidar's end
	#   li
	#   ne
	# 2&5, 4 <- Hit's end

	# UV.x = 0...PI in width direction (sin is used for alpha in fragment shader
	# UV.y = 0...1 in length direction, 0 in lidar's end

	# Coordinates are calculated on the fly in vertex shader so vertex coords can be anything
	# Set them to somewhat sane values for debugging purposes anyway

	# UV2.y "bits" >= 8 indicate the "corner" of this point
	# (other "bits" are set later to indicate line type)

	# "Upper left":
	vertexArray.push_back(Vector3(-0.005, -0.005, 0))
	uvArray.push_back(Vector2(-0.5 * PI, 0.0));
	uv2Array.push_back(Vector2(0, int(0 << 4)))
	
	vertexArray.push_back(Vector3(0.005,  -0.005, 0))
	uvArray.push_back(Vector2(PI + 0.5 * PI, 0.0));
	uv2Array.push_back(Vector2(0, int(1 << 4)))
	
	vertexArray.push_back(Vector3(-0.005,  0.005, 0))
	uvArray.push_back(Vector2(-0.5 * PI, 1.0));
	uv2Array.push_back(Vector2(0, int(2 << 4)))
	
	# "Lower right":
	vertexArray.push_back(Vector3(0.005,  0.005, 0))
	uvArray.push_back(Vector2(PI + 0.5 * PI, 0.0));
	uv2Array.push_back(Vector2(0, int(3 << 4)))

	vertexArray.push_back(Vector3(-0.005, 0.005, 0))
	uvArray.push_back(Vector2(-0.5 * PI, 1.0));
	uv2Array.push_back(Vector2(0, int(4 << 4)))

	vertexArray.push_back(Vector3(0.005, -0.005, 0))
	uvArray.push_back(Vector2(PI + 0.5 * PI, 0.0));
	uv2Array.push_back(Vector2(0, int(5 << 4)))

	meshArrays[Mesh.ARRAY_VERTEX] = vertexArray
	meshArrays[Mesh.ARRAY_TEX_UV] = uvArray
	meshArrays[Mesh.ARRAY_TEX_UV2] = uv2Array

#	var indexArray:PackedInt32Array = PackedInt32Array()
#
#	# See comment above for point ordering
#	indexArray.push_back(0)
#	indexArray.push_back(1)
#	indexArray.push_back(2)
#
#	indexArray.push_back(1)
#	indexArray.push_back(3)
#	indexArray.push_back(2)
#
#	meshArrays[Mesh.ARRAY_INDEX] = indexArray
#	meshArrays[Mesh.ARRAY_INDEX] = null

	return meshArrays
