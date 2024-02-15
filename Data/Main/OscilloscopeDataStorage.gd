@tool
class_name OscilloscopeDataStorage

extends Node

@export var dataFileName:String=""
@export var lowPassFilterCoeff:float = 0

@export var preSilenceLength: int = 0
@export var preSilenceLevel:int = 128

@export var postSilenceLength = 0
@export var postSilenceLevel:int = 128

enum CompressionMode {
	NO_COMPRESSION,
	DEFLATE,
	GZIP,
	RAW,
	RAW_DEFLATE
}

var soundData:PackedByteArray
var imageTexture:ImageTexture

var lowPassFilteredAmplitudeData:PackedFloat32Array
var lowPassFilteredAmplitudeImageTexture:ImageTexture

# Called when the node enters the scene tree for the first time.
func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	readFileData(dataFileName)

func readFileData(fileName:String, compression=CompressionMode.NO_COMPRESSION):
	var file = null
	
	match compression:
		CompressionMode.NO_COMPRESSION, CompressionMode.RAW:
			file = FileAccess.open(fileName, FileAccess.READ)
		CompressionMode.DEFLATE, CompressionMode.RAW_DEFLATE:
			file = FileAccess.open_compressed(fileName, FileAccess.READ, FileAccess.COMPRESSION_DEFLATE)
		CompressionMode.GZIP:
			file = FileAccess.open_compressed(fileName, FileAccess.READ, FileAccess.COMPRESSION_GZIP)

	if !file:
		print("Can't open raw sound data file ", fileName)
		return
		
	var fileSize:int = file.get_length()
	var fileData:PackedByteArray = file.get_buffer(fileSize)
	
	# Pre and post data mostly added for ekg
	var soundData_pre:PackedByteArray = PackedByteArray()
	soundData_pre.resize(preSilenceLength)
	soundData_pre.fill(preSilenceLevel)

	var soundData_post:PackedByteArray = PackedByteArray()
	soundData_post.resize(postSilenceLength)
	soundData_post.fill(postSilenceLevel)

	soundData = PackedByteArray()
	
	soundData.append_array(soundData_pre)
	soundData.append_array(fileData)
	soundData.append_array(soundData_post)

	# Data needs padding
	# (and still doesn't work because isampler doesn't seem to work(?))
	#fileData.resize(4096 * 512)

	#byte-values not working(?), replaced with floats
	# (see https://godotengine.org/qa/104044/format_r8-uniform-sampler2d-texture-correctly-within-shader )
	
	# Find out next power of 2 image height
	# (surpisingly Godot has a ready-made function for this!)
	var imageHeight = nearest_po2(int((soundData.size() / 4096) + 1))
	
	# 4096 * 512 image gives 2097152 samples which is just over 4 minutes in 8 ksps
	# Old, non static way:
	#var dataImage:Image = Image.new()
	#dataImage.create(4096, imageHeight, false, Image.FORMAT_RF)
	var dataImage:Image = Image.create(4096, imageHeight, false, Image.FORMAT_RF)

	#old, non-static:
	#	var lpFilteredDataImage:Image = Image.new()
	#	lpFilteredDataImage.create(4096, imageHeight, false, Image.FORMAT_RF)

	var lpFilteredDataImage:Image = Image.create(4096, imageHeight, false, Image.FORMAT_RF)

	lowPassFilteredAmplitudeData.resize(soundData.size())

	var lpFilteredSoundLevel:float = 0

	var maxIndex = min(soundData.size(), dataImage.get_height() * dataImage.get_width())
	for i in range(maxIndex):
		var level0to1:float = float(soundData[i]) / 255.0
#		var level0to1:float = 0.5
		dataImage.set_pixel(i % 4096, i / 4096, Color(level0to1, 0, 0))
#		dataImage.set_pixel(i % 4096, i / 4096, Color(float(i)/4096.0, 0, 0))
		lpFilteredSoundLevel = lpFilteredSoundLevel * lowPassFilterCoeff + (1 - lowPassFilterCoeff) * absf((level0to1 -  0.5) * 2)
		lowPassFilteredAmplitudeData[i] = clamp(lpFilteredSoundLevel, 0, 1)
		lpFilteredDataImage.set_pixel(i % 4096, i / 4096, Color(lpFilteredSoundLevel, 0, 0))
	
#	for x in range(4096):
#		for y in range(1024):
#			dataImage.set_pixel(x, y, Color(x/1024.0, y/1024.0, 1.0))
	
#	imageTexture = ImageTexture.new()
#	imageTexture.create_from_image(dataImage)

	imageTexture = ImageTexture.create_from_image(dataImage)

#	lowPassFilteredAmplitudeImageTexture = ImageTexture.new()
#	lowPassFilteredAmplitudeImageTexture.create_from_image(lpFilteredDataImage)
	
	lowPassFilteredAmplitudeImageTexture = ImageTexture.create_from_image(lpFilteredDataImage)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(_delta):
#	pass
