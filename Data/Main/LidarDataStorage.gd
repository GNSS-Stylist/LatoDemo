@tool
class_name LidarDataStorage

extends Node

enum LSItemType { 
	ACCEPTED, 
	REJECTED_OUTSIDE_BOUNDING_SPHERE, 
	REJECTED_NOT_SCANNING, 
	REJECTED_OBJECT_NOT_ACTIVE, 
	REJECTED_ANGLE, 
	REJECTED_QUALITY_PRE, 
	REJECTED_QUALITY_POST, 
	REJECTED_DISTANCE_NEAR, 
	REJECTED_DISTANCE_FAR, 
	REJECTED_DISTANCE_DELTA, 
	REJECTED_SLOPE,
	
	REJECTED_UNKNOWN }

enum CompressionMode {
	NO_COMPRESSION,
	DEFLATE,
	GZIP,
	RAW,
	RAW_DEFLATE
}

@export var lsFilename:String = ""
@export var compressionMode:CompressionMode = CompressionMode.NO_COMPRESSION
@export var numOfRawFileDataReadingThreads:int = 4

var beamData = {}	# Key = time, value = array of BeamItems (class below)
var beamDataKeys

# Reading thread-specifics (raw file):
var beamDataMutex:Mutex
var beamRawFileData:PackedByteArray
const rawItemByteSize:int = 37

var numberOfPoints:int = 0
var loadFileTime:int = 0

class BeamItem:
	var type:int	#LSItemType
	var rotation:float
	var origin:Vector3
	var hitPoint:Vector3
	func _init(type_p:int, rotation_p:float, origin_p:Vector3, hitPoint_p:Vector3):
		self.type = type_p
		self.rotation = rotation_p
		self.origin = origin_p
		self.hitPoint = hitPoint_p

class ReadingThreadData:
	var firstItem:int
	var lastItem:int
	var numberOfPoints:int

# Called when the node enters the scene tree for the first time.
func _ready():
	beamDataMutex = Mutex.new()
	if lsFilename.length() > 0:
		# Try to load file at this phase only if defined.
		loadFile(lsFilename, compressionMode)
		
func clearData():
	beamData.clear()
	beamDataKeys = []

func loadFile(fileName, compression):
	var funcStartTime = Time.get_ticks_msec()
	clearData()
	var lineNumber:int = 0

	var file = null
	
	match compression:
		CompressionMode.NO_COMPRESSION, CompressionMode.RAW:
			file = FileAccess.open(fileName, FileAccess.READ)
		CompressionMode.DEFLATE, CompressionMode.RAW_DEFLATE:
			file = FileAccess.open_compressed(fileName, FileAccess.READ, FileAccess.COMPRESSION_DEFLATE)
		CompressionMode.GZIP:
			file = FileAccess.open_compressed(fileName, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
			
	if (!file):
		print("Can't open file ", fileName)
		return

	if ((compression == CompressionMode.NO_COMPRESSION) or
			(compression == CompressionMode.DEFLATE) or 
			(compression == CompressionMode.GZIP)):
		# These are only for text mode file
		
		if false:
			# Create compressed file. This was added because github has a hard limit
			# of 100 MB for a single file and this LidarScript is over the limit.
			# After several tries and banging my head to a wall I couldn't get 
			# "external" compression working. So create a compressed file 
			# using godot's own compression method instead.
			var compressedFile = FileAccess.open_compressed(fileName + ".godot_compressed", FileAccess.WRITE, FileAccess.COMPRESSION_DEFLATE)
			while not file.eof_reached():
				var line = file.get_line()
				compressedFile.store_line(line)
			compressedFile.close()
			return
			
		# Use this to get uncompressed file back
		if false:
			var uncompressedFile = FileAccess.open(fileName + ".uncompressed", FileAccess.WRITE)
			while not file.eof_reached():
				var line = file.get_line()
				uncompressedFile.store_line(line)
			uncompressedFile.close()
			return
			
		var line
		while not file.eof_reached():
			lineNumber += 1
			line = file.get_line()
			var subStrings = line.split("\t")
			if subStrings.size() < 2:
				continue
			
			if subStrings[0] == "META":
				if subStrings[1] == "END":
					break
				# TODO: Add some sanity checks here.
				# (now just skipping all checks...)
		lineNumber += 1
		line = file.get_line()
		if line != "Uptime\tType\tDescr/subtype\tRotAngle\tOrigin_X\tOrigin_Y\tOrigin_Z\tHit_X\tHit_Y\tHit_Z":
			print("Invalid header line in ", lsFilename)
			return

	var oldUptime:int = -1
	var itemArray = []

	if ((compression == CompressionMode.RAW) or
			(compression == CompressionMode.RAW_DEFLATE)):
		var fileSize:int = file.get_length()
		beamRawFileData = file.get_buffer(fileSize)
		var totalItems:int = int(fileSize / rawItemByteSize)
		
		if (fileSize > 1e5):
			var beamDataReadingThreads = []
			beamDataReadingThreads.resize(numOfRawFileDataReadingThreads)
			var beamDataReadingThreadData = []
			beamDataReadingThreadData.resize(numOfRawFileDataReadingThreads)
			
			var itemsPerThread:int = totalItems / numOfRawFileDataReadingThreads
			
			var currentItemIndex:int = 0

			for threadIndex in range(0, numOfRawFileDataReadingThreads):
				var threadData:ReadingThreadData = ReadingThreadData.new()
				threadData.firstItem = currentItemIndex
				currentItemIndex += itemsPerThread
				
				while ((currentItemIndex < totalItems - 1) and
						((beamRawFileData.decode_u64(currentItemIndex * rawItemByteSize) == (beamRawFileData.decode_u64((currentItemIndex + 1) * rawItemByteSize))))):
					# Prevent overlapping uptimes between threads
					# (adjust lastItem to one after which uptime changes)
					currentItemIndex += 1
				
				threadData.lastItem = currentItemIndex
				threadData.numberOfPoints = 0	# Is this needed?
				if (threadIndex == (numOfRawFileDataReadingThreads - 1)):
					threadData.lastItem = totalItems - 1
				beamDataReadingThreads[threadIndex] = Thread.new()
				beamDataReadingThreadData[threadIndex] = threadData
				beamDataReadingThreads[threadIndex].start(Callable(self, "rawDataReadThread").bind(beamDataReadingThreadData[threadIndex]))
				currentItemIndex += 1
				
			for threadIndex in range(0, numOfRawFileDataReadingThreads):
				var threadData:ReadingThreadData = beamDataReadingThreads[threadIndex].wait_to_finish()
				numberOfPoints += threadData.numberOfPoints
		
		else:
			var threadData:ReadingThreadData = ReadingThreadData.new()
			threadData.firstItem = 0
			threadData.lastItem = fileSize / rawItemByteSize - 1
			rawDataReadThread(threadData)
			numberOfPoints = threadData.numberOfPoints
				
	else:
		while not file.eof_reached():
			lineNumber += 1
	#		if (lineNumber % 1000) == 0:
	#			print("Reading lidar script, line: ", lineNumber)
			var line = file.get_line()
			var subStrings = line.split("\t")
			if (subStrings.size() >= 2):
				var newUpTime = subStrings[0].to_int()
				
				if ((oldUptime != newUpTime) and (not itemArray.is_empty())):
					beamData[oldUptime] = itemArray.duplicate()
					itemArray.clear()
				oldUptime = newUpTime
				
				match subStrings[1]:
					"L":
						if (subStrings.size() != 10):
							print("Invalid line ", lineNumber, " in LidarScript file ", lsFilename, ". Terminating interpretation.")
							return
							
						var type = LSItemType.REJECTED_UNKNOWN
						match subStrings[2]:
							"H":
								type = LSItemType.ACCEPTED
							"M":
								type = LSItemType.REJECTED_OUTSIDE_BOUNDING_SPHERE
							"NS":
								type = LSItemType.REJECTED_NOT_SCANNING
							"NO":
								type = LSItemType.REJECTED_OBJECT_NOT_ACTIVE
							"FA":
								type = LSItemType.REJECTED_ANGLE
							"FQ1":
								type = LSItemType.REJECTED_QUALITY_PRE
							"FQ2":
								type = LSItemType.REJECTED_QUALITY_POST
							"FDN":
								type = LSItemType.REJECTED_DISTANCE_NEAR
							"FDF":
								type = LSItemType.REJECTED_DISTANCE_FAR
							"FDD":
								type = LSItemType.REJECTED_DISTANCE_DELTA
							"FS":
								type = LSItemType.REJECTED_SLOPE
							"F?":
								type = LSItemType.REJECTED_UNKNOWN
						
						var rotation:float = subStrings[3].to_float()
						var origin = Vector3(subStrings[4].to_float(), subStrings[5].to_float(), subStrings[6].to_float())
						var hitPoint = Vector3(subStrings[7].to_float(), subStrings[8].to_float(), subStrings[9].to_float())
				
						itemArray.append(BeamItem.new(type, rotation, origin, hitPoint))
						numberOfPoints += 1
						
					# TODO: Add other types here (below) if/when needed
					# Probably place them in different dictionaries?
					#"OBJECTNAME"
					#"STARTOBJECT"
					#"ENDOBJECT"
					#"STARTSCAN"
					#"ENDSCAN"

	if ((!itemArray.is_empty()) and (oldUptime != -1) and (oldUptime != 0)):
		beamData[oldUptime] = itemArray.duplicate()

	beamDataKeys = beamData.keys()

	# Keys need to be sorted as the dictionary's keys are not
	# (they are inserted in several threads)
#	var sortStartTime = Time.get_ticks_msec()
	beamDataKeys.sort()
#	var _sortTime = Time.get_ticks_msec() - sortStartTime
	
	if (false):
		# Create "raw" file that is faster to read
		
		var rawFile = null

		if (true):
			# For non-compressed raw:
			rawFile = FileAccess.open(fileName + ".raw.non-compressed.skiptest", FileAccess.WRITE)
		else:
			# For compressed raw:
			rawFile = FileAccess.open_compressed(fileName + ".raw.godot_compressed", FileAccess.WRITE, FileAccess.COMPRESSION_DEFLATE)
		
		# Only write every n:th (or "skipth") item 
		var skip = 5
		var totalItemIndex:int = 0

		for itemIndex in range(0, beamDataKeys.size()):
			var uptime = beamDataKeys[itemIndex]
			for subItem in beamData[uptime]:
				if (totalItemIndex % skip == 0):
					rawFile.store_64(uptime)
					rawFile.store_8(subItem.type)
					rawFile.store_float(subItem.rotation)
					rawFile.store_float(subItem.origin.x)
					rawFile.store_float(subItem.origin.y)
					rawFile.store_float(subItem.origin.z)
					rawFile.store_float(subItem.hitPoint.x)
					rawFile.store_float(subItem.hitPoint.y)
					rawFile.store_float(subItem.hitPoint.z)
				totalItemIndex += 1
		
		rawFile.close()
		
	loadFileTime = Time.get_ticks_msec() - funcStartTime
	print("Lidarscript load time: ", loadFileTime)
	print("Number of points: ", numberOfPoints)
	if (!beamDataKeys.is_empty()):
		print("Start time: ", beamDataKeys[0])
	return	# Just for setting a breakpoint

func rawDataReadThread(threadData:ReadingThreadData):
	var index:int = threadData.firstItem * rawItemByteSize
	var lastIndex:int = threadData.lastItem * rawItemByteSize + (rawItemByteSize - 1)
	var localNumberOfPoints:int = 0
	var oldUptime:int = -1
	var itemArray = []
			
	while index <= lastIndex:
		var newUpTime = beamRawFileData.decode_u64(index)
		var type = beamRawFileData.decode_u8(index+8)
		var rotation = beamRawFileData.decode_float(index+9)
		var origin = Vector3(beamRawFileData.decode_float(index+13), beamRawFileData.decode_float(index+17), beamRawFileData.decode_float(index+21))
		var hitPoint = Vector3(beamRawFileData.decode_float(index+25), beamRawFileData.decode_float(index+29), beamRawFileData.decode_float(index+33))

		if ((oldUptime != 0) and (oldUptime != newUpTime) and (!itemArray.is_empty())):
			var duplicateItemArray = itemArray.duplicate()	# To prevent duplicating inside mutexed section
			beamDataMutex.lock()

# The ranges of these threads are arranged so that there should never
# be overlapping times. Therefore the check below is disabled
# to make reading as fast as possible. Re-enable if needed.
#			if (!beamData.has(oldUptime)):
#				beamData[oldUptime] = itemArray.duplicate()
#			else:
#				beamData[oldUptime].append_array(itemArray.duplicate())

			beamData[oldUptime] = duplicateItemArray

			beamDataMutex.unlock()
			itemArray.clear()
		oldUptime = newUpTime

		itemArray.append(BeamItem.new(type, rotation, origin, hitPoint))
		localNumberOfPoints += 1
		index += rawItemByteSize

	if ((!itemArray.is_empty()) and (oldUptime != -1) and (oldUptime != 0)):
		beamDataMutex.lock()

		if (!beamData.has(oldUptime)):
			beamData[oldUptime] = itemArray.duplicate()
		else:
			beamData[oldUptime].append_array(itemArray.duplicate())

		beamDataMutex.unlock()
	
	threadData.numberOfPoints = localNumberOfPoints
	
	return threadData
