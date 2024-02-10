@tool
class_name AdditiveGeometryStorage
extends Node

enum LoadOnReadyBehavior { SYNCHRONOUS, ASYNCHRONOUS }

@export var baseFileName:String = ""
@export var loadTextureData:bool = false
@export var loadOnReady:bool = false	# Force synchronous loading in _ready
@export var loadOnReadyBehavior:LoadOnReadyBehavior = LoadOnReadyBehavior.ASYNCHRONOUS

signal loadingCompleted

var fileVertices = PackedVector3Array()
var fileNormals = PackedVector3Array()
var fileVertexIndexes = PackedInt32Array()
var fileTextureIndexes = PackedInt32Array()
var fileTextureCoords = PackedVector2Array()

var faceSync = {}	# Key = uptime, value = array of face indexes
var faceSyncKeys = []	# Keys (array) of the dictionary above

var loadFraction_Vertices:float
var loadFraction_Normals:float
var loadFraction_VertexIndexes:float
var loadFraction_TextureIndexes:float
var loadFraction_TextureCoords:float
var loadFraction_FaceSync:float

var loadFractionMutex:Mutex = Mutex.new()

const subFractionDelta:float = 0.1

var vertexThread:Thread = Thread.new()
var normalsThread:Thread = Thread.new()
var vertexIndexesThread:Thread = Thread.new()
var textureIndexesThread:Thread = Thread.new()
var texCoordsThread:Thread = Thread.new()
var faceSyncThread:Thread = Thread.new()

var loadingElapsedStartTime:int

# Called when the node enters the scene tree for the first time.
func _ready():
	if (loadOnReady):
		if (loadOnReadyBehavior == LoadOnReadyBehavior.SYNCHRONOUS):
			var elapsedStartTime = Time.get_ticks_msec()
			loadFilesSynchronously()
			var elapsed = Time.get_ticks_msec() - elapsedStartTime
			print("Additive geometry (", baseFileName, ") multithreaded (synchronous) load time: ", elapsed, " ms")
		elif(loadOnReadyBehavior == LoadOnReadyBehavior.ASYNCHRONOUS):
			startAsyncLoading()
			
func loadFilesSynchronously():
	startAsyncLoading()

	var success:bool = true
	
	success = success && vertexThread.wait_to_finish()
	success = success && normalsThread.wait_to_finish()
	success = success && vertexIndexesThread.wait_to_finish()
	if (loadTextureData):
		success = success && textureIndexesThread.wait_to_finish()
		success = success && texCoordsThread.wait_to_finish()
	success = success && faceSyncThread.wait_to_finish()
	
	loadingCompletedSignaled = true	# Prevent signaling after synchronous loading

	if (!success):
		# Something went wrong, clear all to prevent strange problems
		clearData()
		return false
	
	return true

func startAsyncLoading():
	loadingElapsedStartTime = Time.get_ticks_msec()

	clearData()

	vertexThread.start(Callable(self, "loadVerticesThread").bind(baseFileName + ".vertices"), Thread.PRIORITY_LOW)
	normalsThread.start(Callable(self, "loadNormalsThread").bind(baseFileName + ".normals"), Thread.PRIORITY_LOW)
	vertexIndexesThread.start(Callable(self, "loadVertexIndexesThread").bind(baseFileName + ".vertexindexes"), Thread.PRIORITY_LOW)

	if (loadTextureData):
		textureIndexesThread.start(Callable(self, "loadTextureIndexesThread").bind(baseFileName + ".texcoordindexes"), Thread.PRIORITY_LOW)
		texCoordsThread.start(Callable(self, "loadTexCoordsThread").bind(baseFileName + ".texcoords"), Thread.PRIORITY_LOW)

	faceSyncThread.start(Callable(self, "loadFaceSyncThread").bind(baseFileName + ".facesync"), Thread.PRIORITY_LOW)

# Returns 0...1, 1 = completed
func getLoadingProgress() -> float:
	var totalMax:float = 4
	var fractionSum:float = 0
	
	loadFractionMutex.lock()
	fractionSum += loadFraction_Vertices
	fractionSum += loadFraction_Normals
	fractionSum += loadFraction_VertexIndexes
	if (loadTextureData):
		totalMax += 2
		fractionSum += loadFraction_TextureIndexes
		fractionSum += loadFraction_TextureCoords
	fractionSum += loadFraction_FaceSync
	loadFractionMutex.unlock()

	var totalFraction = fractionSum / totalMax
	
	if (totalFraction >= 1):
		var anyThreadAlive:bool = false
		anyThreadAlive = anyThreadAlive || vertexThread.is_alive()
		anyThreadAlive = anyThreadAlive || normalsThread.is_alive()
		anyThreadAlive = anyThreadAlive || vertexIndexesThread.is_alive()
		if (loadTextureData):
			anyThreadAlive = anyThreadAlive || textureIndexesThread.is_alive()
			anyThreadAlive = anyThreadAlive || texCoordsThread.is_alive()
		anyThreadAlive = anyThreadAlive || faceSyncThread.is_alive()

		if (anyThreadAlive):
			# This is just to make sure all threads have finished
			# their work before returning 1 (loading done completely)
			totalFraction = 0.99
	
	return totalFraction

func clearData():
	fileVertices = PackedVector3Array()
	fileNormals = PackedVector3Array()
	fileVertexIndexes = PackedInt32Array()
	fileTextureIndexes = PackedInt32Array()
	fileTextureCoords = PackedVector2Array()
	faceSync = {}	# Key = uptime, value = array of face indexes
	faceSyncKeys = []	# Keys (array) of the dictionary above

	loadFraction_Vertices = 0
	loadFraction_Normals = 0
	loadFraction_VertexIndexes = 0
	loadFraction_TextureIndexes = 0
	loadFraction_TextureCoords = 0
	loadFraction_FaceSync = 0

#	fileVertices.resize(0)
#	fileNormals.resize(0)
#	fileFaces.resize(0)
#	faceSync.clear()
#	faceSyncKeys.resize(0)

func loadVerticesThread(fileName):
	var vertexFile = FileAccess.open(fileName, FileAccess.READ)
	if (!vertexFile):
		print("Can't open file ", fileName)
		return false
		
	loadFractionMutex.lock()
	loadFraction_Vertices = 0
	loadFractionMutex.unlock()
	
	var fileLength:int = vertexFile.get_length()
		
	while not vertexFile.eof_reached():
		var vec = Vector3(vertexFile.get_float(), vertexFile.get_float(), vertexFile.get_float())
		fileVertices.push_back(vec)
		
		var newLoadFraction:float = float(vertexFile.get_position()) / fileLength
		if (abs(newLoadFraction - loadFraction_Vertices) > subFractionDelta):
			loadFractionMutex.lock()
			loadFraction_Vertices = newLoadFraction
			loadFractionMutex.unlock()
	
	loadFractionMutex.lock()
	loadFraction_Vertices = 1
	loadFractionMutex.unlock()

	return true

func loadNormalsThread(fileName):
	var normalFile = FileAccess.open(fileName, FileAccess.READ)
	if (!normalFile):
		print("Can't open file ", fileName)
		return false
		
	loadFractionMutex.lock()
	loadFraction_Normals = 0
	loadFractionMutex.unlock()

	var fileLength:int = normalFile.get_length()

	while not normalFile.eof_reached():
		var vec = Vector3(normalFile.get_float(), normalFile.get_float(), normalFile.get_float())
		fileNormals.push_back(vec)

		var newLoadFraction:float = float(normalFile.get_position()) / fileLength
		if (abs(newLoadFraction - loadFraction_Normals) > subFractionDelta):
			loadFractionMutex.lock()
			loadFraction_Normals = newLoadFraction
			loadFractionMutex.unlock()

	loadFractionMutex.lock()
	loadFraction_Normals = 1
	loadFractionMutex.unlock()

	return true

func loadTexCoordsThread(fileName):
	var texCoordsFile = FileAccess.open(fileName, FileAccess.READ)
	if (!texCoordsFile):
		print("Can't open file ", fileName)
		return false
		
	loadFractionMutex.lock()
	loadFraction_TextureCoords = 0
	loadFractionMutex.unlock()

	var fileLength:int = texCoordsFile.get_length()

	while not texCoordsFile.eof_reached():
		var vec = Vector2(texCoordsFile.get_float(), texCoordsFile.get_float())
		fileTextureCoords.push_back(vec)

		var newLoadFraction:float = float(texCoordsFile.get_position()) / fileLength
		if (abs(newLoadFraction - loadFraction_TextureCoords) > subFractionDelta):
			loadFractionMutex.lock()
			loadFraction_TextureCoords = newLoadFraction
			loadFractionMutex.unlock()

	loadFractionMutex.lock()
	loadFraction_TextureCoords = 1
	loadFractionMutex.unlock()

	return true

func loadVertexIndexesThread(fileName):
	var vertexIndexFile = FileAccess.open(fileName, FileAccess.READ)
	if (!vertexIndexFile):
		print("Can't open file ", fileName)
		return
	
	loadFractionMutex.lock()
	loadFraction_VertexIndexes = 0
	loadFractionMutex.unlock()
	
	var fileLength:int = vertexIndexFile.get_length()

	while not vertexIndexFile.eof_reached():
		var face:int = vertexIndexFile.get_32()
		fileVertexIndexes.push_back(face)

		var newLoadFraction:float = float(vertexIndexFile.get_position()) / fileLength
		if (abs(newLoadFraction - loadFraction_VertexIndexes) > subFractionDelta):
			loadFractionMutex.lock()
			loadFraction_VertexIndexes = newLoadFraction
			loadFractionMutex.unlock()
	
	loadFractionMutex.lock()
	loadFraction_VertexIndexes = 1
	loadFractionMutex.unlock()

	return true

func loadTextureIndexesThread(fileName):
	var textureIndexFile = FileAccess.open(fileName, FileAccess.READ)
	if (!textureIndexFile):
		print("Can't open file ", fileName)
		return
	
	loadFractionMutex.lock()
	loadFraction_TextureIndexes = 0
	loadFractionMutex.unlock()
	
	var fileLength:int = textureIndexFile.get_length()
		
	while not textureIndexFile.eof_reached():
		var face:int = textureIndexFile.get_32()
		fileTextureIndexes.push_back(face)

		var newLoadFraction:float = float(textureIndexFile.get_position()) / fileLength
		if (abs(newLoadFraction - loadFraction_TextureIndexes) > subFractionDelta):
			loadFractionMutex.lock()
			loadFraction_TextureIndexes = newLoadFraction
			loadFractionMutex.unlock()

	loadFractionMutex.lock()
	loadFraction_TextureIndexes = 1
	loadFractionMutex.unlock()

	return true

func loadFaceSyncThread(fileName):
	var faceSyncFile = FileAccess.open(fileName, FileAccess.READ)
	if (!faceSyncFile):
		print("Can't open file ", fileName)
		return

	var oldUptime:int = -1
	var syncFaces = []
	faceSyncFile.seek(0)
	
	loadFractionMutex.lock()
	loadFraction_FaceSync = 0
	loadFractionMutex.unlock()
	
	var fileLength:int = faceSyncFile.get_length()

	while not faceSyncFile.eof_reached():
		var uptime = faceSyncFile.get_32()
		var faceIndex = faceSyncFile.get_32()
		
		if (uptime != oldUptime) and (not syncFaces.is_empty()):
			faceSync[oldUptime] = syncFaces.duplicate()
			syncFaces.clear()
		oldUptime = uptime
		
		syncFaces.append(faceIndex)

	var newLoadFraction:float = float(faceSyncFile.get_position()) / fileLength
	if (abs(newLoadFraction - loadFraction_FaceSync) > subFractionDelta):
		loadFractionMutex.lock()
		loadFraction_FaceSync = newLoadFraction
		loadFractionMutex.unlock()

	if ((not syncFaces.is_empty()) and (oldUptime != -1)):
		faceSync[oldUptime] = syncFaces.duplicate()
		
#		var value:int = faceSyncFile.get_32()
#		fileFaceSync.push_back(value)

	faceSyncKeys = faceSync.keys()

	loadFractionMutex.lock()
	loadFraction_FaceSync = 1
	loadFractionMutex.unlock()

	return true

func getNumOfVertices():
	return fileVertexIndexes.size()

var loadingCompletedSignaled:bool = false

var processCallCount:int = 0

func _process(_delta):
	processCallCount += 1
	var loadingProgress:float = getLoadingProgress()
	
	if ((loadingProgress == 1) && (!loadingCompletedSignaled)):
		loadingCompleted.emit()
		loadingCompletedSignaled = true
		var elapsed = Time.get_ticks_msec() - loadingElapsedStartTime
		print("Additive geometry (", baseFileName, ") multithreaded load time: ", elapsed, " ms, _process call count: ", processCallCount)
#		print("Additive geometry (", baseFileName, ") loading complete signaled")

	elif (loadingProgress < 1):
		loadingCompletedSignaled = false

func waitThreadExit(threadToWait:Thread):
	if (threadToWait.is_started()):
		threadToWait.wait_to_finish()

func _exit_tree():
	print("Exit tree (AdditiveGeometryStorage)")
	
	waitThreadExit(vertexThread)
	waitThreadExit(normalsThread)
	waitThreadExit(vertexIndexesThread)
	waitThreadExit(textureIndexesThread)
	waitThreadExit(texCoordsThread)
	waitThreadExit(faceSyncThread)
