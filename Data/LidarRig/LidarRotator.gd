#@tool
extends Node3D

# @onready doesn't work with @tool in this case(?)
@onready var dataStorage = get_node("/root/Main/LidarDataStorage")
#var dataStorage = get_node("/root/Main/LidarDataStorage")

# Time to wait after valid lidar data before starting to rotate the lidar by itself:
@export var idleRotationWaitTime:int = 1000

# Rotation speed of lidar when no data has come in the time defined above
@export var idleRotationSpeed:float = 20.0
@export var idleObeyPause:bool = false

@export var eyeColors = PackedColorArray()
@export var eyeFallbackColor:Color

var lastDataTime = 0
var lastDataTimeRotation:float = 0

var pauseStartUptime:int = 0
var totalPauseTime:int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
#var dbg_LastItemIndex:int = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var currentReplayTime:float = Global.replayTime_Lidar
	var itemIndex:int = 0
	
	# See @onready comment above...
#	var dataStorage = get_node("/root/Main/LidarDataStorage")

	if (dataStorage.beamData.size() > 0):
		itemIndex = dataStorage.beamDataKeys.bsearch(floor(currentReplayTime), true)
	
	if (dataStorage.beamData.size() > 0) and (itemIndex == dataStorage.beamDataKeys.size() - 1):
		var subItem = dataStorage.beamData[dataStorage.beamDataKeys[itemIndex]].back()
		lastDataTimeRotation = subItem.rotation
		self.rotation = Vector3(0, -subItem.rotation, 0)
		lastDataTime = Time.get_ticks_msec()
	elif (dataStorage.beamData.size() > 0) and (itemIndex < dataStorage.beamDataKeys.size()):
		var rotation_Low:float = dataStorage.beamData[dataStorage.beamDataKeys[itemIndex]].front().rotation
		var rotation_High:float = dataStorage.beamData[dataStorage.beamDataKeys[itemIndex+1]].front().rotation

#		if (itemIndex != dbg_LastItemIndex):
#			print("Item changed, Rots: ", rotation_Low, ", ", rotation_High)
#			dbg_LastItemIndex = itemIndex

		lastDataTimeRotation = rotation_High
		var fraction:float = (currentReplayTime - dataStorage.beamDataKeys[itemIndex]) / (float(dataStorage.beamDataKeys[itemIndex+1]) - float(dataStorage.beamDataKeys[itemIndex]))

		if (rotation_High < rotation_Low):
			rotation_High += PI * 2
		self.rotation = Vector3(0, -(rotation_Low + (rotation_High - rotation_Low) * fraction), 0)

		var subItemWhatever = fraction * dataStorage.beamData[dataStorage.beamDataKeys[itemIndex]].size()
		var subItemIndex:int = int(max(0, floor(subItemWhatever)))
		var subItemFraction = clamp(subItemWhatever - subItemIndex, 0, 1)
		
		var eyeColorItem_Low
		var eyeColorItem_High
		
		if (subItemIndex < dataStorage.beamData[dataStorage.beamDataKeys[itemIndex]].size() - 1):
			eyeColorItem_Low = dataStorage.beamData[dataStorage.beamDataKeys[itemIndex]][subItemIndex]
			eyeColorItem_High = dataStorage.beamData[dataStorage.beamDataKeys[itemIndex]][subItemIndex + 1]
		else:
			eyeColorItem_Low = dataStorage.beamData[dataStorage.beamDataKeys[itemIndex]].back()
			eyeColorItem_High = dataStorage.beamData[dataStorage.beamDataKeys[itemIndex + 1]].front()

		var eyeColor_Low:Color
		var eyeColor_High:Color
		
		if (eyeColorItem_Low.type < eyeColors.size()):
			eyeColor_Low = eyeColors[eyeColorItem_Low.type]
		else:
			eyeColor_Low = eyeFallbackColor

		if (eyeColorItem_High.type < eyeColors.size()):
			eyeColor_High = eyeColors[eyeColorItem_High.type]
		else:
			eyeColor_High = eyeFallbackColor

		var eyeColor = eyeColor_Low.lerp(eyeColor_High, subItemFraction)
		
		$Eye.get_active_material(0).set_albedo(eyeColor)

		lastDataTime = Time.get_ticks_msec()
#	elif Time.get_ticks_msec() - lastDataTime > idleRotationWaitTime:
#		if get_tree().paused and idleObeyPause:
#			if pauseStartUptime == 0:
#				pauseStartUptime = Time.get_ticks_msec()
#			return
#		elif pauseStartUptime != 0:
#			totalPauseTime += Time.get_ticks_msec() - pauseStartUptime
#			pauseStartUptime = 0
#		var replaySpeed:float = get_node("/root/Main/Panel_UIControls/SpinBox_ReplaySpeed").value
#		var timediff:int = Time.get_ticks_msec() - lastDataTime - idleRotationWaitTime - totalPauseTime
#		var rotationSubRound = (int(timediff * replaySpeed * idleRotationSpeed)) % 1000
#		var rotationAngle:float = lastDataTimeRotation + (rotationSubRound / 1000.0 * (2.0 * PI))
#		self.rotation = Vector3(0, -rotationAngle, 0)
	
	
