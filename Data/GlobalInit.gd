@tool
extends Node

# "Godot's scene system, while powerful and flexible, has a drawback:
# there is no method for storing information
# (e.g. a player's score or inventory) that is needed by more than one scene.
# Source: https://docs.godotengine.org/en/3.3/getting_started/step_by_step/singletons_autoload.html

# -> Using Global.gd as a storage for globals
# I couldn't find a way to show variables exported from Global.gd to show
# in Godot editor's inspector so initializing them here instead.
# this is quite ugly and maybe there is neater way(?)

@export var lidarPointMaterial:Material
@export var lidarLineMaterial:Material
@export var blockableGNSSSignalMaterial:Material

@export var oscilloscope3DShader:Shader

@export var replayTime_Lidar:float = 0
# For animation:
@export var overrideReplayTime_WireFrames:bool = false
@export var replayTimeOverride_WireFrames:float = 0
@export var overrideReplayTime_AdditiveGeometries:bool = false
@export var replayTimeOverride_AdditiveGeometries:float = 0

@export var replayTimeShift_Lidar:float = 2415000

#@export var scopeLineWidthLow:float = 0.025		# Smoothstep low value
#@export var scopeLineWidthHigh:float = 0.075	# Smoothstep high value
#@export var scopeHeight:float = 2
#@export var scopeSoundPos:float = 0.0
#@export var scopeSoundOffset:float = -409600	# Offset to soundPos
#@export var scopeSoundLength:float = 409600	# Length (time) of the scope in samples
#@export var scopeBaseAlbedo:Color = Color(0.5, 2, 0.5, 1.0);

@export var scopeAutoSoundPosAdjustFractionByCurrentCamera:float = 0

#@onready var tunePlayer:AudioStreamPlayer = get_node("/root/Main/MainTunePlayer")

@export var scopeAutoSoundPosAdjustStartRefPointNodePath:NodePath	# = get_node("/root/Main/World/LidarRig/ScopeAutoSoundPosAdjustEndRefPoint")
@export var scopeAutoSoundPosAdjustEndRefPointNodePath:NodePath	# = get_node("/root/Main/ScopeAutoSoundPosAdjustStartRefPoint")

@export var editorCameraNodePath:NodePath	# = get_node("/root/Main/InterpolatedCamera")

var scopeAutoSoundPosAdjustStartRefPointNode
var scopeAutoSoundPosAdjustEndRefPointNode

var editorCameraNode:Node3D

# Called when the node enters the scene tree for the first time.
func _ready():
	scopeAutoSoundPosAdjustStartRefPointNode = get_node(scopeAutoSoundPosAdjustStartRefPointNodePath)
	scopeAutoSoundPosAdjustEndRefPointNode = get_node(scopeAutoSoundPosAdjustEndRefPointNodePath)
	editorCameraNode = get_node(editorCameraNodePath)
	
	if (!Global):
		return
	
	Global.lidarPointMaterial = lidarPointMaterial
	Global.lidarLineMaterial = lidarLineMaterial

#	blockableGNSSSignalMaterial.set_shader_param("startOrigin_Object", Vector3($Surface.mesh.size.x / 2, 0, 0) + $Surface.mesh.center_offset)
#	blockableGNSSSignalMaterial.set_shader_param("endOrigin_Object", Vector3(-$Surface.mesh.size.x / 2, 0, 0) + $Surface.mesh.center_offset)
	Global.blockableGNSSSignalMaterial = blockableGNSSSignalMaterial

#	Global.oscilloscopeCanvasShader = oscilloscopeCanvasShader
	Global.oscilloscope3DShader = oscilloscope3DShader
#	Global.oscTestShader = oscTestShader

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if ((!Global) || (Engine.is_editor_hint() && Global.cleanTempToolData)):
		return

	Global.replayTime_Lidar = replayTime_Lidar + replayTimeShift_Lidar
	Global.replayTimeShift_Lidar = replayTimeShift_Lidar

	Global.replayTimeOverride_WireFrames = replayTimeOverride_WireFrames + replayTimeShift_Lidar
	Global.overrideReplayTime_WireFrames = overrideReplayTime_WireFrames

	Global.replayTimeOverride_AdditiveGeometries = replayTimeOverride_AdditiveGeometries + replayTimeShift_Lidar
	Global.overrideReplayTime_AdditiveGeometries = overrideReplayTime_AdditiveGeometries

#	blockableGNSSSignalMaterial.set_shader_param("lineWidthLow", scopeLineWidthLow)
#	blockableGNSSSignalMaterial.set_shader_param("lineWidthHigh", scopeLineWidthHigh)
#	blockableGNSSSignalMaterial.set_shader_param("scopeHeight", scopeHeight)
#	blockableGNSSSignalMaterial.set_shader_param("soundOffset", scopeSoundOffset)
#	blockableGNSSSignalMaterial.set_shader_param("soundLength", scopeSoundLength)
#	blockableGNSSSignalMaterial.set_shader_param("baseAlbedo", scopeBaseAlbedo)

	var currentCamera
	
	if (Engine.is_editor_hint()):
		currentCamera = editorCameraNode
	else:
		currentCamera = get_viewport().get_camera_3d()

	var currentCameraOrigin:Vector3
	
	if (currentCamera):
		currentCameraOrigin = currentCamera.global_transform.origin
	
	if scopeAutoSoundPosAdjustStartRefPointNode && scopeAutoSoundPosAdjustEndRefPointNode:
		var startPointOrigin:Vector3 = scopeAutoSoundPosAdjustStartRefPointNode.global_transform.origin
		var endPointOrigin:Vector3 = scopeAutoSoundPosAdjustEndRefPointNode.global_transform.origin
		
		var proj = ((currentCameraOrigin - startPointOrigin).dot(endPointOrigin - startPointOrigin)) / (endPointOrigin - startPointOrigin).length_squared()
#		print (proj)
		var adjustment = clamp((1 - proj), 0, 1) * blockableGNSSSignalMaterial.get_shader_parameter("soundLength") * scopeAutoSoundPosAdjustFractionByCurrentCamera
#		print (adjustment)

#		var tunePlaybackPosition:float = tunePlayer.getFilteredPlaybackPosition()
#		var tunePlaybackPosition:float = tunePlayer.getFilteredPlaybackPosition()
		var oscilloscopeSoundMasterPosition = int((Global.masterReplayTime) * 8000 + adjustment)
		Global.oscilloscopeSoundMasterPosition = oscilloscopeSoundMasterPosition
		Global.blockableGNSSSignalMaterial.set_shader_parameter("soundPos", oscilloscopeSoundMasterPosition)
#		print("Global.masterReplayTime: ", Global.masterReplayTime)
#		print("Global.oscilloscopeSoundMasterPosition: ", Global.oscilloscopeSoundMasterPosition)

#	blockableGNSSSignalMaterial.set_shader_param("",#var scopeSoundPos:float = 0.0
