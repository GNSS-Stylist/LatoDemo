#@tool
extends Node

# "Godot's scene system, while powerful and flexible, has a drawback:
# there is no method for storing information
# (e.g. a player's score or inventory) that is needed by more than one scene.
# Source: https://docs.godotengine.org/en/3.3/getting_started/step_by_step/singletons_autoload.html

# -> Using Global.gd as a storage for globals
# I couldn't find a way to show variables exported from Global.gd to show
# in Godot editor's inspector so initializing them in GlobalInit.gd instead.
# this is quite ugly and maybe there is neater way(?)

# Not using @export as I couln't find a way to edit these in editor anyway...
#@export var replayTime:float = 0
#@export var lidarPointMaterial:Material
var replayTime_Lidar:float = 0
var replayTimeShift_Lidar:float = 0

# For animation:
var overrideReplayTime_WireFrames:bool = false
var replayTimeOverride_WireFrames:float = 0
var overrideReplayTime_AdditiveGeometries:bool = false
var replayTimeOverride_AdditiveGeometries:float = 0

var lidarPointMaterial:Material
var lidarLineMaterial:Material
var blockableGNSSSignalMaterial:Material

#var oscilloscopeCanvasShader:Shader
var oscilloscope3DShader:Shader
#var oscTestShader:Shader

var lidarPointVisibleTime:int = 100000
var lidarLineVisibleTime:int = 20000

var oscilloscopeSoundMasterPosition:int = 0

var soundData = []
var lowPassFilteredSoundAmplitudeData = []
var soundDataTexture:ImageTexture
var lowPassFilteredSoundDataTexture:ImageTexture

# Since shaders use only 32-bit floats,
# time needs to be shifted to get the resolution of it adequate
# This indicates the shift used (basically should be starting time of beamdata)
# TODO: Update this somewhere!
var scanTrackerShaderBaseTime:float = 2415057	# 2415057 from walkaround2

@onready var oscilloscopeDataStorage:OscilloscopeDataStorage = get_node("/root/Main/OscilloscopeDataStorage")

# Called when the node enters the scene tree for the first time.
func _ready():
	# Making sure that soundDataTexture is ready before using it
	await get_tree().process_frame

	# blockableGNSSSignalMaterial is shared between quite a lot instances.
	# Setting the shader params here so no need to set them in every instance.
	blockableGNSSSignalMaterial.set_shader_param("soundDataSampler", soundDataTexture)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var shiftedReplayTime = replayTime_Lidar - scanTrackerShaderBaseTime
	
	# This way to get a rounding error when converting from double to float
	# is super-ugly. However, it works.
	# Don't know how to "force-cast" to float-type (32-bit) in godot in a neater way...
	# This is used to get more precice times into shaders for super slo-mo.
	var fractionConvertFloat32Array = PackedFloat32Array()
	fractionConvertFloat32Array.push_back(shiftedReplayTime)
	var replayTimeRemainder = shiftedReplayTime - fractionConvertFloat32Array[0]
	
	lidarPointMaterial.set_shader_param("replayTime", shiftedReplayTime)
	lidarPointMaterial.set_shader_param("replayTimeRemainder", replayTimeRemainder)

	lidarLineMaterial.set_shader_param("replayTime", shiftedReplayTime)
	lidarLineMaterial.set_shader_param("replayTimeRemainder", replayTimeRemainder)
