@tool
class_name AdditiveGeometryStorage
extends Node

@export var baseFileName:String = "D:/GNSSStylusData/Temp/ConstructiveObject/Out"
@export var loadTextureData:bool = false

var fileVertices = PackedVector3Array()
var fileNormals = PackedVector3Array()
var fileVertexIndexes = PackedInt32Array()
var fileTextureIndexes = PackedInt32Array()
var fileTextureCoords = PackedVector2Array()
#var fileFaces = PoolIntArray()
#var fileFaceSync = PoolIntArray()
var faceSync = {}	# Key = uptime, value = array of face indexes
var faceSyncKeys = []	# Keys (array) of the dictionary above

# Called when the node enters the scene tree for the first time.
func _ready():
	var elapsedStartTime = Time.get_ticks_usec()
	
	loadFiles()

	var elapsed = Time.get_ticks_usec() - elapsedStartTime
	print("Additive geometry (", baseFileName, ") multithreaded load time: ", elapsed, " us")
	
	return

func loadFiles():
	clearData()

	var vertexThread = Thread.new()
	vertexThread.start(Callable(self, "loadVerticesThread").bind(baseFileName + ".vertices"))

	var normalsThread = Thread.new()
	normalsThread.start(Callable(self, "loadNormalsThread").bind(baseFileName + ".normals"))

	var vertexIndexesThread = Thread.new()
	vertexIndexesThread.start(Callable(self, "loadVertexIndexesThread").bind(baseFileName + ".vertexindexes"))

	var textureIndexesThread
	var texCoordsThread
	if (loadTextureData):
		textureIndexesThread = Thread.new()
		textureIndexesThread.start(Callable(self, "loadTextureIndexesThread").bind(baseFileName + ".texcoordindexes"))

		texCoordsThread = Thread.new()
		texCoordsThread.start(Callable(self, "loadTexCoordsThread").bind(baseFileName + ".texcoords"))

	var faceSyncThread = Thread.new()
	faceSyncThread.start(Callable(self, "loadFaceSyncThread").bind(baseFileName + ".facesync"))

	var success:bool = true
	
	success = success && vertexThread.wait_to_finish()
	success = success && normalsThread.wait_to_finish()
	success = success && vertexIndexesThread.wait_to_finish()
	if (loadTextureData):
		success = success && textureIndexesThread.wait_to_finish()
		success = success && texCoordsThread.wait_to_finish()
	success = success && faceSyncThread.wait_to_finish()
	
	if (!success):
		# Something went wrong, clear all to prevent strange problems
		clearData()
		return false
	
	return true

func clearData():
	fileVertices = PackedVector3Array()
	fileNormals = PackedVector3Array()
	fileVertexIndexes = PackedInt32Array()
	fileTextureIndexes = PackedInt32Array()
	fileTextureCoords = PackedVector2Array()
	faceSync = {}	# Key = uptime, value = array of face indexes
	faceSyncKeys = []	# Keys (array) of the dictionary above

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
		
	while not vertexFile.eof_reached():
		var vec = Vector3(vertexFile.get_float(), vertexFile.get_float(), vertexFile.get_float())
		fileVertices.push_back(vec)
	
	return true

func loadNormalsThread(fileName):
	var normalFile = FileAccess.open(fileName, FileAccess.READ)
	if (!normalFile):
		print("Can't open file ", fileName)
		return false
		
	while not normalFile.eof_reached():
		var vec = Vector3(normalFile.get_float(), normalFile.get_float(), normalFile.get_float())
		fileNormals.push_back(vec)

	return true

func loadTexCoordsThread(fileName):
	var texCoordsFile = FileAccess.open(fileName, FileAccess.READ)
	if (!texCoordsFile):
		print("Can't open file ", fileName)
		return false
		
	while not texCoordsFile.eof_reached():
		var vec = Vector2(texCoordsFile.get_float(), texCoordsFile.get_float())
		fileTextureCoords.push_back(vec)

	return true

func loadVertexIndexesThread(fileName):
	var textureIndexFile = FileAccess.open(fileName, FileAccess.READ)
	if (!textureIndexFile):
		print("Can't open file ", fileName)
		return
	
	while not textureIndexFile.eof_reached():
		var face:int = textureIndexFile.get_32()
		fileVertexIndexes.push_back(face)

	return true

func loadTextureIndexesThread(fileName):
	var textureIndexFile = FileAccess.open(fileName, FileAccess.READ)
	if (!textureIndexFile):
		print("Can't open file ", fileName)
		return
	
	while not textureIndexFile.eof_reached():
		var face:int = textureIndexFile.get_32()
		fileTextureIndexes.push_back(face)

	return true

func loadFaceSyncThread(fileName):
	var faceSyncFile = FileAccess.open(fileName, FileAccess.READ)
	if (!faceSyncFile):
		print("Can't open file ", fileName)
		return

	var oldUptime:int = -1
	var syncFaces = []
	faceSyncFile.seek(0)
	
	while not faceSyncFile.eof_reached():
		var uptime = faceSyncFile.get_32()
		var faceIndex = faceSyncFile.get_32()
		
		if (uptime != oldUptime) and (not syncFaces.is_empty()):
			faceSync[oldUptime] = syncFaces.duplicate()
			syncFaces.clear()
		oldUptime = uptime
		
		syncFaces.append(faceIndex)

	if ((not syncFaces.is_empty()) and (oldUptime != -1)):
		faceSync[oldUptime] = syncFaces.duplicate()
		
#		var value:int = faceSyncFile.get_32()
#		fileFaceSync.push_back(value)

	faceSyncKeys = faceSync.keys()

	return true

func getNumOfVertices():
	return fileVertexIndexes.size()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
