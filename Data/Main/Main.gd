@tool
extends Node3D

# Variables for interpolating camera
# (flying from one camera to another when switching camera)
const camera_InterpolationTime_Fast = 500
const camera_InterpolationTime_Slow = 2000
var camera_Interpolating:bool = false
var camera_InterpolationFraction:float = 0
var camera_InterpolationTime:int = 2000
var camera_InterpolateFrom:Camera3D
var camera_InterpolateTo:Camera3D
var camera_InterpolationStartTime:int = 0

# TODO: Update time
#var replayTime_int:int = 0;
#@export var replayTime_float:float = 0
#@export var replaySpeed_float:float = 1

const lidarPointSetMaxDuration:int = 1000
var lidarPointSets = []
var lidarLineSets = []

@onready var ScanTracker_Points = load("Data/Main/ScanTracker_Points.gd")
@onready var ScanTracker_Lines = load("Data/Main/ScanTracker_Lines.gd")

@onready var lidarDataStorage = get_node("LidarDataStorage")
@onready var Oscilloscope3D = preload("res://Data/Oscilloscope/Oscilloscope3D.tscn")

@onready var tunePlayer:AudioStreamPlayer = get_node("MainTunePlayer")
@onready var deathRaySurface = get_node("World/LOScriptReplayer_MainBlackHole/MainBlackHole/DeathRayParent/DeathRay/Surface")
#@onready var animationPlayer:AnimationPlayer = get_node("AnimationPlayer")

@onready var mainAnimationPlayer:AnimationPlayer = get_node("MainAnimationPlayer")
@onready var subAnimationSelector:AnimationPlayer = get_node("SubAnimationSelector")

#var syncedAnimationPlayers = []

var accumulatedDelta:float = 0

var firstRound = true

var animationCameraAnchorSpaces = []
var animationCameraAnchorSpaceNames = []
var animationCameraAnchorNodes = []
@export var animationCameraAnchorIndexA:int
@export var animationCameraAnchorIndexB:int
@export var animationCameraFraction:float

@export var dbgPlayStartPos:float
@export var animationPosition:float
@export var dbgAnimJump:float = 0
@export var lidarPreCutTime:int = 0

enum StashCommand {NONE, STASH, STASH_PULL}
@export var stashCommand:StashCommand = StashCommand.NONE

var animResetStashDone:bool = false

@export var trigStashToolData:bool = false:
	set(param):
		print("trigStashToolData setter called (main): ", param)
		if (!animResetStashDone && param):
			stashToolData()
			animResetStashDone = true
	get:
		return false

@export var animChangeReq:String = ""
var lastActiveAnim:String = ""

@export var animDbgPrint:String = "":
	set(dbgString):
		print("anim debug: ", dbgString)
		if (dbgString != animDbgPrint):
			animDbgPrint = dbgString
	get:
		return animDbgPrint

var demoStarted:bool = false
var demoStartRitualsDone:bool = false

#@export var cleanTempToolData:bool:
#	set(_dummy):
#		if (_dummy):
#			print("Cleaning temp tool data (main)...")
#			$DebugThings/MeshInstance3D_SoundImageDbg.material_override.albedo_texture = null

# Called when the node enters the scene tree for the first time.
func _ready():
	if ((!Global) ||(Engine.is_editor_hint() && Global.cleanTempToolData)):
		# @tool-scripts will generate changes that are saved into .tscn (scene)-files.
		# Clean them when requested
		
		print("Cleaning data generated by @tool, ", self.name)
		$DebugThings/MeshInstance3D_SoundImageDbg.material_override.albedo_texture = null
		deathRaySurface.material_override.set_shader_parameter("soundDataSamplerA", null)
		deathRaySurface.material_override.set_shader_parameter("soundDataSamplerB", null)

		return
		
	mainAnimationPlayer.stop()
	subAnimationSelector.current_animation = "EndOfTheWorld"

		# Let two frames pass to make sure the viewport is captured.
#	await get_tree().process_frame
#	await get_tree().process_frame

#	PhysicsServer3D.set_active(false)
	
#	$MeshInstance3D2.material_override.set_shader_param("texture_albedo", $ScopeTest.get_texture())
#	$MeshInstance3D_SoundTest.material_override.albedo_texture = $SubViewport.get_texture()
#	$MeshInstance3D_SoundImageDbg.material_override.albedo_texture = $OscilloscopeDataStorage.imageTexture
	$DebugThings/MeshInstance3D_SoundImageDbg.material_override.albedo_texture = $OscilloscopeDataStorage.lowPassFilteredAmplitudeImageTexture
	deathRaySurface.material_override.set_shader_parameter("soundDataSamplerA", $OscilloscopeDataStorage.imageTexture)
	deathRaySurface.material_override.set_shader_parameter("soundDataSamplerB", $EKGScopeDataStorage.imageTexture)

#	Global.oscilloscopeMaterial.set_shader_param("soundDataSampler", $OscilloscopeDataStorage.imageTexture)
	Global.soundData = $OscilloscopeDataStorage.soundData
	Global.soundDataTexture = $OscilloscopeDataStorage.imageTexture
	Global.lowPassFilteredSoundAmplitudeData = $OscilloscopeDataStorage.lowPassFilteredAmplitudeData
	Global.lowPassFilteredSoundDataTexture = $OscilloscopeDataStorage.lowPassFilteredAmplitudeImageTexture
	
	# 0:
	animationCameraAnchorSpaces.push_back($CameraFlyingSpace_GlobalOrigin)
	animationCameraAnchorNodes.push_back($CameraFlyingSpace_GlobalOrigin/LocalOriginB)
	animationCameraAnchorSpaceNames.push_back("Global origin (B)")
	
	# 1:
	animationCameraAnchorSpaces.push_back($CameraFlyingSpace_Satellite_Angled)
#	animationCameraAnchorNodes.push_back($CameraFlyingSpace_Satellite_Angled/LocalOrigin)
	animationCameraAnchorNodes.push_back($CameraFlyingSpace_Satellite_Angled/Path_Satellite/PathFollow_Satellite/LocalOrigin)
	animationCameraAnchorSpaceNames.push_back("Satellite, angled")

	# 2:
	animationCameraAnchorSpaces.push_back($World/CameraRig/CameraObject/DisplayCameraAnchor)
	animationCameraAnchorNodes.push_back($World/CameraRig/CameraObject/DisplayCameraAnchor)
	animationCameraAnchorSpaceNames.push_back("CameraRig display")

	# 3:
	animationCameraAnchorSpaces.push_back($World/CameraRig/CameraObject/CameraLensAnchor)
	animationCameraAnchorNodes.push_back($World/CameraRig/CameraObject/CameraLensAnchor)
	animationCameraAnchorSpaceNames.push_back("CameraRig lens")

	# 4:
	animationCameraAnchorSpaces.push_back($World/LidarRig/CameraFlyingSpace)
	animationCameraAnchorNodes.push_back($World/LidarRig/CameraFlyingSpace/LocalOrigin_LRig)
	animationCameraAnchorSpaceNames.push_back("Lidar rig")

	# 5:
	animationCameraAnchorSpaces.push_back($CameraFlyingSpace_Descent)
	animationCameraAnchorNodes.push_back($CameraFlyingSpace_Descent/Descender)
	animationCameraAnchorSpaceNames.push_back("Descender")

	# 6:
	animationCameraAnchorSpaces.push_back($MainPaths/Path_Barn1_Cam)
	animationCameraAnchorNodes.push_back($MainPaths/Path_Barn1_Cam/PathFollow_Barn1_Cam/Path_Barn1_Orientator)
	animationCameraAnchorSpaceNames.push_back("Path_Barn1")

	# 7:
	animationCameraAnchorSpaces.push_back($CameraFlyingSpace_Ascend)
	animationCameraAnchorNodes.push_back($CameraFlyingSpace_Ascend/Ascender/AscenderCamera)
	animationCameraAnchorSpaceNames.push_back("Ascender")

	# 8:
	animationCameraAnchorSpaces.push_back($CameraFlyingSpace_Satellite_Angled)
	animationCameraAnchorNodes.push_back($CameraFlyingSpace_Satellite_Angled/Flybyer/FlybyerCamera)
	animationCameraAnchorSpaceNames.push_back("Satellite flybyer")

	# 9:
	animationCameraAnchorSpaces.push_back($FlyingSpace_Station_Angled_NotRotating)
	animationCameraAnchorNodes.push_back($FlyingSpace_Station_Angled_NotRotating/Path_StationFlyby/PathFollow_StationFlyby/PathFollow_StationFlyby_Orientator)
	animationCameraAnchorSpaceNames.push_back("Station flybyer")

	# 10:
	animationCameraAnchorSpaces.push_back($FlyingSpace_Station_Angled_NotRotating)
	animationCameraAnchorNodes.push_back($FlyingSpace_Station_Angled_NotRotating/Path_CobraFollow/PathFollow_CobraFollow/PathFollow_CobraFollow_Orientator)
	animationCameraAnchorSpaceNames.push_back("Cobra follow")

	$DebugThings/Panel_CurrentCameraTransform/OptionButton_PosReference.clear()

	for i in range(animationCameraAnchorSpaceNames.size()):
		var outString = "%s (%d)" % [animationCameraAnchorSpaceNames[i], i]
		$DebugThings/Panel_CurrentCameraTransform/OptionButton_PosReference.add_item(outString, i)
	
	$AnimatedCamera.current = true;

#	$MeshInstance_DbgShit.material_override = $OscilloscopeDataStorage.scopeBlockMaterials[0]
#	$MeshInstance_DbgShit2.material_override = $OscilloscopeDataStorage.scopeBlockMaterials[1]

#	$Hittimittari.material_override = $OscilloscopeDataStorage.scopeBlockMaterials[0]
	
#	var buffer:PackedByteArray = $AudioStreamPlayer.stream.data
#	print("mp data size: ", buffer.size())
#	pass # Replace with function body.

#	for i in range(6 * 20):
#		var newOsc = Oscilloscope3D.instantiate()
#		newOsc.scopeLength = 40960
#		newOsc.translate(Vector3(50, i, 0))
#		self.add_child(newOsc)
	
#	var newKey = Vector3(0,0,0)
#	$AnimationPlayer.get_animation("Camera").track_insert_key(0, 0.5, newKey)


func animChangeCheck(delta: float) -> bool:
	if ((!animChangeReq.is_empty()) && 
			(animChangeReq != lastActiveAnim)):

		var wasPlaying = mainAnimationPlayer.is_playing()
		print("Animation change request: ", animChangeReq)
		var animPos:float = animationPosition
#		if (!mainAnimationPlayer.current_animation.is_empty()):
#			animPos= mainAnimationPlayer.current_animation_position

#		if (lastActiveAnim.is_empty()):
#			mainAnimationPlayer.current_animation = animChangeReq
#		else:
#			mainAnimationPlayer.set_blend_time(lastActiveAnim, animChangeReq, -1)

#		mainAnimationPlayer.current_animation = animChangeReq

		var initAnimName = animChangeReq + "_INIT"
		
		if (mainAnimationPlayer.has_animation(initAnimName)):
			print("Playing init animation: " + initAnimName)
			mainAnimationPlayer.play(initAnimName)
			mainAnimationPlayer.advance(0)

		mainAnimationPlayer.play(animChangeReq)
		lastActiveAnim = animChangeReq
		
		mainAnimationPlayer.seek(animPos + delta, false)
		if (!wasPlaying):
			mainAnimationPlayer.pause()
			
		return true
	return false


func _process(delta):
	if ((!Global) ||(Engine.is_editor_hint() && Global.cleanTempToolData)):
		#print("Clean (dbg, main)")
		return
	
#	print($AnimatedCamera.global_transform.origin)
	
	if (animResetStashDone && $MainAnimationPlayer.current_animation_position > 0.1):
		# Time limit to prevent unstashing while showing RESET animation on the editor
		# (current_animation only works while playing)
		stashPullToolData()
		animResetStashDone = false

	if (stashCommand == StashCommand.STASH):
		stashToolData()
	elif (stashCommand == StashCommand.STASH_PULL):
		stashPullToolData()
	stashCommand = StashCommand.NONE

	if (delta < 0):
		print("Negative delta: ", delta)
	
#	if (delta > 0.02):
#		print("Main: delta > 20 ms (", delta, ")")
	
	if (!Engine.is_editor_hint()) && Input.is_action_just_pressed("immediate_exit"):
		OS.kill(OS.get_process_id())	# Immediate exit

	if (firstRound):
		if ((lidarDataStorage.beamDataKeys) and (!lidarDataStorage.beamDataKeys.is_empty())):
			var lidarDataStartTime:int = max(lidarDataStorage.beamDataKeys[0], lidarPreCutTime)
			var lidarDataEndTime:int = lidarDataStorage.beamDataKeys[lidarDataStorage.beamDataKeys.size()-1]
	#		var lidarDataStartTime:int = 930001
	#		var lidarDataEndTime:int = 960001
			
			var pointsetFirstTime:int = lidarDataStartTime
			
			while (pointsetFirstTime <= lidarDataStartTime + ((lidarDataEndTime - lidarDataStartTime) / 1)):
				var pointSetLastTime = pointsetFirstTime + lidarPointSetMaxDuration
				if (pointSetLastTime > lidarDataEndTime):
					pointSetLastTime = lidarDataEndTime
				var newPointset = ScanTracker_Points.new()
				newPointset.setViewRange(pointsetFirstTime, pointSetLastTime)
				lidarPointSets.append(newPointset)
				$World/LidarPointSets.add_child(newPointset)

				var newLineset = ScanTracker_Lines.new()
				newLineset.setViewRange(pointsetFirstTime, pointSetLastTime)
				lidarLineSets.append(newLineset)
				$World/LidarLineSets.add_child(newLineset)

				pointsetFirstTime = pointSetLastTime + 1
		
#		get_viewport().msaa_3d = Viewport.MSAA_8X

		if (!Engine.is_editor_hint()):
			animChangeReq = "SatMorph"
		
		firstRound = false
	
	subAnimationSelector.seek(animationPosition, true)
	
	var subAnimChanged = animChangeCheck(delta)

	if (demoStarted):
		if (!demoStartRitualsDone):
			mainAnimationPlayer.play()
				
			$MainTunePlayer.play(dbgPlayStartPos)
			demoStartRitualsDone = true;
			
			if ($Panel_Start/OptionButton_Ending.get_selected_id() == 1):
				subAnimationSelector.current_animation = "EndOfTheWorld"
			else:
				subAnimationSelector.current_animation = "PartyOn"
		

	if (!Engine.is_editor_hint()):
		accumulatedDelta += delta
		camSwitch(accumulatedDelta * 1000)
	#	replayTime_float += delta * 1000 * (replaySpeed_float / 100)
	#	Global.replayTime_Lidar = replayTime_float
		
		
		# Testing audio sync:
	#	$AnimationPlayer.seek($MainTunePlayer.filteredPlaybackPosition)
	#	$AnimationPlayer.advance($MainTunePlayer.filteredPlaybackPosition - $AnimationPlayer.current_animation_position)
	
	var tunePlaybackPosition:float = tunePlayer.getFilteredPlaybackPosition()
	
	if Engine.is_editor_hint():
		# Apparently you can not get animation position from a paused animation
		# Added a new track just for position as a workaround
#		if (masterAnimationPlayer.current_animation == ""):
#			Global.masterReplayTime = 0
#		else:
#			Global.masterReplayTime = masterAnimationPlayer.current_animation_position

		Global.masterReplayTime = animationPosition
			
#		print("is_playing: ", animationPlayer.is_playing())
#		print("pos: ", animationPlayer.current_animation_position)
#		print("playing speed: ", animationPlayer.get_playing_speed())

		if (mainAnimationPlayer.is_playing() && mainAnimationPlayer.get_playing_speed() > 0.1):
			if (tunePlayer.playing):
				if (absf(Global.masterReplayTime - tunePlaybackPosition) > 0.1):
					tunePlayer.my_seek(Global.masterReplayTime)
				else:
					tunePlayer.pitch_scale = (mainAnimationPlayer.get_playing_speed() * 
						(1.0 + (Global.masterReplayTime - tunePlaybackPosition) * 1.0))
					
			else:
				tunePlayer.my_seek(Global.masterReplayTime)
				tunePlayer.resume()
		else:
			tunePlayer.pause()
			
		if (dbgAnimJump != 0):
			if (!subAnimChanged):
				mainAnimationPlayer.seek(mainAnimationPlayer.current_animation_position - dbgAnimJump)
			dbgAnimJump = 0
	
	else:
		Global.masterReplayTime = tunePlaybackPosition
#		for animationPlayer in syncedAnimationPlayers:
		if (absf(mainAnimationPlayer.current_animation_position - tunePlaybackPosition) > 0.1) && (tunePlayer.playing):
			# Animation playback position differs too much from the tune -> Hard sync
			print("anim hard resync: ", mainAnimationPlayer.current_animation_position - tunePlaybackPosition)
			mainAnimationPlayer.seek(tunePlaybackPosition)
			mainAnimationPlayer.speed_scale = tunePlayer.pitch_scale
#				mainAnimationPlayer.playback_speed = tunePlayer.pitch_scale
		else:
			if (tunePlayer.playing):
				if (!mainAnimationPlayer.is_playing()):
					mainAnimationPlayer.play()
				var playbackSpeed = (tunePlayer.pitch_scale * 
					(1.0 + (tunePlaybackPosition - mainAnimationPlayer.current_animation_position) * 1.0))
				mainAnimationPlayer.speed_scale = playbackSpeed
#					mainAnimationPlayer.playback_speed = playbackSpeed
	#			print(playbackSpeed)
			else:
				if (absf(mainAnimationPlayer.current_animation_position - tunePlaybackPosition) > 0.001):
					# seek doesn't seem to update things if not played for at least one frame
					# Bit hacky way to do this, but seems to work...
					mainAnimationPlayer.speed_scale = 0
#						mainAnimationPlayer.playback_speed = 0
					mainAnimationPlayer.play()
					mainAnimationPlayer.seek(tunePlaybackPosition)
				else:
					mainAnimationPlayer.pause()
#						mainAnimationPlayer.stop(false)
		
		if (dbgAnimJump != 0):
			if (!subAnimChanged):
				tunePlayer.my_seek(tunePlayer.getFilteredPlaybackPosition() - dbgAnimJump)
			dbgAnimJump = 0

	RenderingServer.global_shader_parameter_set("masterReplayTime", Global.masterReplayTime)

	if (!Engine.is_editor_hint()):
		updateCameraCopyPasteFields()

#	Global.oscilloscopeMaterial.set_shader_param("soundPos", int(tunePlaybackPosition * 8000))
	
#	Global.oscilloscopeSoundMasterPosition = int(tunePlaybackPosition * 8000)
#	ProjectSettings.set_setting("Shader Globals/soundPos", Global.oscilloscopeSoundMasterPosition)
	
#	$AdditiveGeometry.get_active_material(0).set_shader_param("replayTime", replayTime_float)
#	$AdditiveGeometry.replayTime = replayTime_float
#	ScanTracker.replayTime = replayTime_float
		controlPlayback(delta)
	
	# Can't get a shader parameter here (commented out section)
	# due to https://github.com/godotengine/godot/issues/44454
	# -> Using hardcoded value (ugly...)
	deathRaySurface.material_override.set_shader_parameter("soundPosA", Global.deathRaySoundMasterPosition - 2000000)	#deathRaySurface.material_override.get_shader_parameter("soundOffsetA"))

	handleAnimatedCamera()
	
	
	
func handleAnimatedCamera():
	var originA:Vector3 = animationCameraAnchorNodes[animationCameraAnchorIndexA].global_transform.origin
	var originB:Vector3 = animationCameraAnchorNodes[animationCameraAnchorIndexB].global_transform.origin
	var orientationA:Quaternion = animationCameraAnchorNodes[animationCameraAnchorIndexA].global_transform.basis.orthonormalized()
	var orientationB:Quaternion = animationCameraAnchorNodes[animationCameraAnchorIndexB].global_transform.basis.orthonormalized()

	var interpolatedOrigin = originA.lerp(originB, animationCameraFraction)
	var interpolatedOrientation = orientationA.slerp(orientationB, animationCameraFraction)
	
	$AnimatedCamera.global_transform = Transform3D(interpolatedOrientation, interpolatedOrigin)

func controlPlayback(delta:float):
	if Input.is_action_just_pressed("forward_1s"):
		tunePlayer.my_seek(tunePlayer.getFilteredPlaybackPosition() + 1)
	if Input.is_action_just_pressed("backward_1s"):
		tunePlayer.my_seek(tunePlayer.getFilteredPlaybackPosition() - 1)
	if Input.is_action_just_pressed("forward_5s"):
		tunePlayer.my_seek(tunePlayer.getFilteredPlaybackPosition() + 5)
	if Input.is_action_just_pressed("backward_5s"):
		tunePlayer.my_seek(tunePlayer.getFilteredPlaybackPosition() - 5)
	if Input.is_action_just_pressed("restart_playback"):
		tunePlayer.my_seek(0)
	if Input.is_action_just_pressed("animation_jump_to_bookmark"):
		tunePlayer.my_seek(290)

	if Input.is_action_just_pressed("playback_speed_100_pros"):
		tunePlayer.pitch_scale = 1
	if Input.is_action_just_pressed("playback_speed_50_pros"):
		tunePlayer.pitch_scale = 0.5
	if Input.is_action_just_pressed("playback_speed_25_pros"):
		tunePlayer.pitch_scale = 0.25
	if Input.is_action_just_pressed("playback_speed_12_pros"):
		tunePlayer.pitch_scale = 0.125
	if Input.is_action_just_pressed("playback_speed_5_pros"):
		tunePlayer.pitch_scale = 0.05
	if Input.is_action_just_pressed("playback_speed_200_pros"):
		tunePlayer.pitch_scale = 2
	if Input.is_action_just_pressed("playback_speed_400_pros"):
		tunePlayer.pitch_scale = 4
	if Input.is_action_just_pressed("playback_speed_800_pros"):
		tunePlayer.pitch_scale = 8

	if Input.is_action_just_pressed("pause"):
		if (tunePlayer.playing):
			tunePlayer.pause()
			if ((tunePlayer.getFilteredPlaybackPosition() > 13.36) &&
				(tunePlayer.getFilteredPlaybackPosition() < 13.38)):
				$World/Paasiaismuna.visible = true
		else:
			tunePlayer.resume()

	if Input.is_action_just_pressed("mute"):
		if (tunePlayer.volume_db < -20):
			tunePlayer.volume_db = 0
		else:
			tunePlayer.volume_db = -80
	
	if Input.is_action_pressed("play_forward_non_locked"):
		tunePlayer.my_seek(tunePlayer.getFilteredPlaybackPosition() + delta)
			
	if Input.is_action_pressed("play_backward_non_locked"):
		tunePlayer.my_seek(tunePlayer.getFilteredPlaybackPosition() - delta)
	
	if Input.is_action_just_pressed("debug_load_recorded_track"):
		$Elite/DebugShipTrackReplayer.loadFromFile()
		$Elite/DebugShipTrackReplayer.play()

func camSwitch(uptime):
	var oldCamera = get_viewport().get_camera_3d()
	var newCamera = null
	
	if Input.is_action_just_pressed("camera_first_person_global"):
		var firstPerson = get_node("FirstPersonFlyer")
		var flyCamera = get_node("FirstPersonFlyer/Head/FirstPersonCamera")
		firstPerson.set_LocationOrientation(self.transform.affine_inverse() * get_viewport().get_camera_3d().get_global_transform())
		newCamera = flyCamera
		camera_InterpolationTime = camera_InterpolationTime_Fast
		
	if Input.is_action_just_pressed("camera_origin"):
		newCamera = get_node("Camera_Origin")
		camera_InterpolationTime = camera_InterpolationTime_Fast
		
	if Input.is_action_just_pressed("camera_satellite"):
		newCamera = get_node("Camera_Satellite")
		camera_InterpolationTime = camera_InterpolationTime_Fast
		
	if Input.is_action_just_pressed("camera_demo"):
		newCamera = get_node("AnimatedCamera")
		camera_InterpolationTime = camera_InterpolationTime_Fast
		
	if Input.is_action_just_pressed("camera_camerarig"):
		newCamera = get_node("World/CameraRig/CameraObject/CameraLensAnchor/DevCamera")
		camera_InterpolationTime = camera_InterpolationTime_Fast
		
		
		
		
		
		
		
		
		
	if false:	
			
		if Input.is_action_just_pressed("camera_first_person_van"):
			var cameraRig = get_node("LOSolver_VanScanner")
			var firstPerson = get_node("LOSolver_VanScanner/FirstPerson")
			var flyCamera = get_node("LOSolver_VanScanner/FirstPerson/Head/FirstPersonCamera")
			var sourceCameraGlobal = get_viewport().get_camera().get_global_transform()
			var rigGlobal = cameraRig.get_global_transform()
			var newTransform = rigGlobal.inverse() * sourceCameraGlobal
			firstPerson.set_LocationOrientation(newTransform)
			newCamera = flyCamera
			camera_InterpolationTime = camera_InterpolationTime_Fast
		if Input.is_action_just_pressed("camera_follow_van"):
			newCamera = get_node("LOSolver_VanScanner/BackCamera")
			camera_InterpolationTime = camera_InterpolationTime_Slow
		if Input.is_action_just_pressed("camera_camerarig"):
			newCamera = get_node("LOSolver_CameraEye/RigCamera")
			camera_InterpolationTime = camera_InterpolationTime_Slow
		if Input.is_action_just_pressed("camera_lidarrig_down"):
			# This camera doesn't have a separate LOScript
			newCamera = get_node("LOSolver_VanScanner/LidarAndCameraRig/Camera/CameraBody/RigCamera")
			camera_InterpolationTime = camera_InterpolationTime_Slow
		if Input.is_action_just_pressed("camera_first_person_car"):
			var cameraRig = get_node("LOSolver_CameraRigAndCar")
			var firstPerson = get_node("LOSolver_CameraRigAndCar/FirstPerson")
			var flyCamera = get_node("LOSolver_CameraRigAndCar/FirstPerson/Head/FirstPersonCamera")
			var sourceCameraGlobal = get_viewport().get_camera().get_global_transform()
			var rigGlobal = cameraRig.get_global_transform()
			var newTransform = rigGlobal.inverse() * sourceCameraGlobal
			firstPerson.set_LocationOrientation(newTransform)
			newCamera = flyCamera
			camera_InterpolationTime = camera_InterpolationTime_Fast
		if Input.is_action_just_pressed("camera_start_still"):
			newCamera = get_node("StartStillCamera")
			camera_InterpolationTime = camera_InterpolationTime_Slow

		if Input.is_action_just_pressed("camera_memory_store"):
			var memCamera = get_node("MemoryCamera")
			var sourceCamera = get_viewport().get_camera()
			var sourceCameraGlobal = get_viewport().get_camera().get_global_transform()
			memCamera.global_transform = sourceCameraGlobal
			memCamera.near = sourceCamera.near
			memCamera.far = sourceCamera.far
			memCamera.fov = sourceCamera.fov
		if Input.is_action_just_pressed("camera_memory_recall"):
			newCamera = get_node("MemoryCamera")
			camera_InterpolationTime = camera_InterpolationTime_Slow













	if (newCamera):
		if (newCamera == oldCamera):
			# Nothing to do really
			newCamera.current = true
			camera_Interpolating = false
		elif (camera_Interpolating):
			# Quick change on double press
			newCamera.current = true
			camera_Interpolating = false
		else:
			# Otherwise start interpolating
			camera_InterpolateFrom = oldCamera
			camera_InterpolateTo = newCamera
			camera_InterpolationStartTime = uptime
			camera_Interpolating = true
	
	if (camera_Interpolating):
		var currentFraction:float = smoothstep(camera_InterpolationStartTime, camera_InterpolationStartTime + camera_InterpolationTime, uptime)
		if (currentFraction >= 1):
			camera_InterpolateTo.current = true
			camera_Interpolating = false
		else:
			var currentPosition:Vector3 = camera_InterpolateFrom.global_transform.origin.lerp(camera_InterpolateTo.global_transform.origin, currentFraction)
			# Use quaternion slerp for smooth interpolation of rotation
			var currentOrientation:Quaternion = camera_InterpolateFrom.global_transform.basis.slerp(camera_InterpolateTo.global_transform.basis, currentFraction)
			var currentNear = camera_InterpolateFrom.near + (camera_InterpolateTo.near - camera_InterpolateFrom.near) * currentFraction
			var currentFar = camera_InterpolateFrom.far + (camera_InterpolateTo.far - camera_InterpolateFrom.far) * currentFraction
			var currentFov = camera_InterpolateFrom.fov + (camera_InterpolateTo.fov - camera_InterpolateFrom.fov) * currentFraction
			$CameraSwitchCamera.global_transform = Transform3D(currentOrientation, currentPosition)
			$CameraSwitchCamera.near = currentNear
			$CameraSwitchCamera.far = currentFar
			$CameraSwitchCamera.fov = currentFov
			$CameraSwitchCamera.current = true

func updateLineEditTextIfChanged(lineEdit, newText):
	if (lineEdit.text != newText):
		lineEdit.text = newText

var lastLidarTime:float = 0

func updateCameraCopyPasteFields():
	if (!($DebugThings.visible)):
		return
	
	updateLineEditTextIfChanged($DebugThings/Panel_Bottom/LineEdit_Time, "%1.2f" % $MainTunePlayer.getFilteredPlaybackPosition())

	var posReferenceIndex = $DebugThings/Panel_CurrentCameraTransform/OptionButton_PosReference.selected

	var tempTransform:Transform3D = animationCameraAnchorSpaces[posReferenceIndex].global_transform
	
	var posTransform = Transform3D(tempTransform.basis, tempTransform.origin).affine_inverse()

	var currentCamera = get_viewport().get_camera_3d()
	
	var cameraPosTransformed = posTransform * currentCamera.global_transform
	
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Pos_x, "%1.3f" % cameraPosTransformed.origin.x)
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Pos_y, "%1.3f" % cameraPosTransformed.origin.y)
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Pos_z, "%1.3f" % cameraPosTransformed.origin.z)

	updateLineEditTextIfChanged($DebugThings/Panel_Bottom/LineEdit_Dist, "%1.3f" % currentCamera.global_transform.origin.length())
	updateLineEditTextIfChanged($DebugThings/Panel_Bottom/LineEdit_FPS, "%1.0f" % Engine.get_frames_per_second())
	
	var cameraQuat:Quaternion = Quaternion(cameraPosTransformed.basis.orthonormalized())
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Quat_x, "%1.3f" % cameraQuat.x)
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Quat_y, "%1.3f" % cameraQuat.y)
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Quat_z, "%1.3f" % cameraQuat.z)
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Quat_w, "%1.3f" % cameraQuat.w)

	var yawPitchRoll:Vector3 = cameraPosTransformed.basis.orthonormalized().get_euler()
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Yaw, "%1.3f" % -rad_to_deg(yawPitchRoll.y))
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Pitch, "%1.3f" % rad_to_deg(yawPitchRoll.x))
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Roll, "%1.3f" % rad_to_deg(yawPitchRoll.z))
	
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Roll, "%1.3f" % rad_to_deg(yawPitchRoll.z))

	updateLineEditTextIfChanged($DebugThings/Panel_Bottom/LineEdit_LidarTime, "%1.3f" % $GlobalInit.replayTime_Lidar)

func _on_spin_box_lidar_time_override_value_changed(value):
	$GlobalInit.replayTime_Lidar = value

func _on_spin_box_time_override_value_changed(value):
	$MainTunePlayer.my_seek(value)

func captureViewport():
	# Retrieve the captured Image using get_data().
	var img = get_viewport().get_texture().get_image()
	# Flip on the Y axis.
	# You can also set "V Flip" to true if not on the root Viewport.
	#img.flip_y()
	# Convert Image to ImageTexture.
	var tex:ImageTexture = ImageTexture.create_from_image(img)
	# Set sprite texture.
	$World/CameraRig/CameraObject/DisplayPic_ScreenCapture.get_active_material(0).albedo_texture = tex


func _on_button_die_pressed():
	OS.kill(OS.get_process_id())	# Immediate exit

func _on_button_demo_pressed():
	$Panel_Start.visible = false
	if ($Panel_Start/CheckBox_Fullscreen.button_pressed):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
#		OS.window_fullscreen = true
	demoStarted = true

func killMe():
	OS.kill(OS.get_process_id())	# Immediate exit
	
func _exit_tree():
	print("Exit tree (Main)")

#func cleanTempToolData():
#	print("Cleaning temp tool data (main)...")
#	$DebugThings/MeshInstance3D_SoundImageDbg.material_override.albedo_texture = null

class Stash:
	var valid:bool = false
	var globalData
	var barnData
	var groundData
	var latoTextData
	var soundImageDebugTexture
	var deathRaySamplerA
	var deathRaySamplerB
	var planetCrustData
	var jellyPlanetData
	var syncHelpScopeData
	var deathTextData
#	var blackHoleData = [3]

var stashStorage:Stash = Stash.new()

func stashToolData():
	print("Stashing data...")
	var barnMesh = get_node_or_null("World/AdditiveGeometries/Barn/BarnMesh")
	var groundMesh = get_node_or_null("World/AdditiveGeometries/Ground")
	var latoTextMesh = get_node_or_null("World/AdditiveGeometries/LatoText")
	var soundImageDbg = get_node_or_null("DebugThings/MeshInstance3D_SoundImageDbg")
	var planetCrust = get_node_or_null("World/Planet/Crust")
	var jellyPlanet = get_node_or_null("World/JellyPlanet")
	var syncHelpScope = get_node_or_null("AnimatedCamera/SyncHelpScope")
	var deathText = get_node_or_null("CameraFlyingSpace_Ascend/DeathText")

	if (Global && barnMesh && groundMesh && latoTextMesh && 
			soundImageDbg && planetCrust && jellyPlanet &&
			syncHelpScope && deathText):
				
		stashStorage.globalData = Global.stashToolData()
		stashStorage.barnData = barnMesh.stashToolData()
		stashStorage.groundData = groundMesh.stashToolData()
		stashStorage.latoTextData = latoTextMesh.stashToolData()
		
		stashStorage.soundImageDebugTexture = soundImageDbg.material_override.albedo_texture
		soundImageDbg.material_override.albedo_texture = null
		
		stashStorage.deathRaySamplerA = deathRaySurface.material_override.get_shader_parameter("soundDataSamplerA")
		deathRaySurface.material_override.set_shader_parameter("soundDataSamplerA", null)

		stashStorage.deathRaySamplerB = deathRaySurface.material_override.get_shader_parameter("soundDataSamplerB")
		deathRaySurface.material_override.set_shader_parameter("soundDataSamplerB", null)
		
		stashStorage.planetCrustData = planetCrust.stashToolData()
		stashStorage.jellyPlanetData = jellyPlanet.stashToolData()
		stashStorage.syncHelpScopeData = syncHelpScope.stashToolData()
		
		stashStorage.deathTextData = deathText.stashToolData()

		stashStorage.valid = true

	
func stashPullToolData():
	if (stashStorage.valid):
		print("Unstashing data...")
		var barnMesh = get_node_or_null("World/AdditiveGeometries/Barn/BarnMesh")
		var groundMesh = get_node_or_null("World/AdditiveGeometries/Ground")
		var latoTextMesh = get_node_or_null("World/AdditiveGeometries/LatoText")
		var soundImageDbg = get_node_or_null("DebugThings/MeshInstance3D_SoundImageDbg")
		var planetCrust = get_node_or_null("World/Planet/Crust")
		var jellyPlanet = get_node_or_null("World/JellyPlanet")
		var syncHelpScope = get_node_or_null("AnimatedCamera/SyncHelpScope")
		var deathText = get_node_or_null("CameraFlyingSpace_Ascend/DeathText")

		if (Global && barnMesh && groundMesh && latoTextMesh && 
				soundImageDbg && planetCrust && jellyPlanet &&
				syncHelpScope && deathText):
					
			Global.stashPullToolData(stashStorage.globalData)
			barnMesh.stashPullToolData(stashStorage.barnData)
			groundMesh.stashPullToolData(stashStorage.groundData)
			latoTextMesh.stashPullToolData(stashStorage.latoTextData)
			soundImageDbg.material_override.albedo_texture = stashStorage.soundImageDebugTexture
			deathRaySurface.material_override.set_shader_parameter("soundDataSamplerA", stashStorage.deathRaySamplerA)
			deathRaySurface.material_override.set_shader_parameter("soundDataSamplerB", stashStorage.deathRaySamplerB)
			planetCrust.stashPullToolData(stashStorage.planetCrustData)
			jellyPlanet.stashPullToolData(stashStorage.jellyPlanetData)
			syncHelpScope.stashPullToolData(stashStorage.syncHelpScopeData)
			deathText.stashPullToolData(stashStorage.deathTextData)
	else:
		print("Stash data not valid")
	
var dbgRewindMarker:float

func dbgAnimSetMarker():
	dbgRewindMarker = mainAnimationPlayer.current_animation_position
	
func dbgAnimGoMarker():
	mainAnimationPlayer.seek(dbgRewindMarker)

func resetFuncTest():
	print("resetFuncTest called")
	
func setScrollerPicPlateScreenCloneTexture():
	# Add "recursive" screen texture to scroller pic plate
	# (This doesn't work on editor)
	$SubViewport_Scroller/ScrollerMainNode/Scroller.picPlateScreenCloneTexture = get_viewport().get_texture()
#	print("picPlateScreenCloneTexture set")

func clearScrollerPicPlateScreenCloneTexture():
	# Clear "recursive" screen texture to scroller pic plate
	# (Added because I have no idea if the texture is updated all the 
	# time in memory with all mipmaps and stuff)

	$SubViewport_Scroller/ScrollerMainNode/Scroller.picPlateScreenCloneTexture = null
#	print("picPlateScreenCloneTexture cleared")
