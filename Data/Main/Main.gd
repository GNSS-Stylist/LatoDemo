#@tool
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
#@onready var animationPlayer:AnimationPlayer = get_node("AnimationPlayer")

var syncedAnimationPlayers = []

var accumulatedDelta:float = 0

var firstRound = true

var animationCameraAnchorSpaces = []
var animationCameraAnchorSpaceNames = []
var animationCameraAnchorNodes = []
@export var animationCameraAnchorIndexA:int
@export var animationCameraAnchorIndexB:int
@export var animationCameraFraction:float

@export var dbgPlayStartPos:float

var demoStarted:bool = false
var demoStartRitualsDone:bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	syncedAnimationPlayers.push_back(get_node("AnimationPlayer_Camera"))
	
	for animationPlayer in syncedAnimationPlayers:
		animationPlayer.stop()

		# Let two frames pass to make sure the viewport is captured.
#	await get_tree().process_frame
#	await get_tree().process_frame

#	PhysicsServer3D.set_active(false)
	
#	$MeshInstance3D2.material_override.set_shader_param("texture_albedo", $ScopeTest.get_texture())
#	$MeshInstance3D_SoundTest.material_override.albedo_texture = $SubViewport.get_texture()
#	$MeshInstance3D_SoundImageDbg.material_override.albedo_texture = $OscilloscopeDataStorage.imageTexture
	$DebugThings/MeshInstance3D_SoundImageDbg.material_override.albedo_texture = $OscilloscopeDataStorage.lowPassFilteredAmplitudeImageTexture
	
#	Global.oscilloscopeMaterial.set_shader_param("soundDataSampler", $OscilloscopeDataStorage.imageTexture)
	Global.soundData = $OscilloscopeDataStorage.soundData
	Global.soundDataTexture = $OscilloscopeDataStorage.imageTexture
	Global.lowPassFilteredSoundAmplitudeData = $OscilloscopeDataStorage.lowPassFilteredAmplitudeData
	Global.lowPassFilteredSoundDataTexture = $OscilloscopeDataStorage.lowPassFilteredAmplitudeImageTexture
	
	animationCameraAnchorSpaces.push_back($CameraFlyingSpace_GlobalOrigin)
	animationCameraAnchorNodes.push_back($CameraFlyingSpace_GlobalOrigin/LocalOriginB)
	animationCameraAnchorSpaceNames.push_back("Global origin (B)")

	animationCameraAnchorSpaces.push_back($CameraFlyingSpace_Satellite_Angled)
	animationCameraAnchorNodes.push_back($CameraFlyingSpace_Satellite_Angled/LocalOrigin)
	animationCameraAnchorSpaceNames.push_back("Satellite, angled")

	animationCameraAnchorSpaces.push_back($World/CameraRig/CameraObject/DisplayCameraAnchor)
	animationCameraAnchorNodes.push_back($World/CameraRig/CameraObject/DisplayCameraAnchor)
	animationCameraAnchorSpaceNames.push_back("CameraRig display")

	animationCameraAnchorSpaces.push_back($World/CameraRig/CameraObject/CameraLensAnchor)
	animationCameraAnchorNodes.push_back($World/CameraRig/CameraObject/CameraLensAnchor)
	animationCameraAnchorSpaceNames.push_back("CameraRig lens")

	animationCameraAnchorSpaces.push_back($World/LidarRig/CameraFlyingSpace)
	animationCameraAnchorNodes.push_back($World/LidarRig/CameraFlyingSpace/LocalOrigin_LRig)
	animationCameraAnchorSpaceNames.push_back("Lidar rig")

	animationCameraAnchorSpaces.push_back($World/LidarRig/ForwardTube/Lidar/Rotator/CameraFlyingSpace)
	animationCameraAnchorNodes.push_back($World/LidarRig/ForwardTube/Lidar/Rotator/CameraFlyingSpace/LocalOrigin_Rotator)
	animationCameraAnchorSpaceNames.push_back("Lidar rotator")

	$DebugThings/Panel_CurrentCameraTransform/OptionButton_PosReference.clear()

	for i in range(animationCameraAnchorSpaceNames.size()):
		var outString = "%s (%d)" % [animationCameraAnchorSpaceNames[i], i]
		$DebugThings/Panel_CurrentCameraTransform/OptionButton_PosReference.add_item(outString, i)
	
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if (delta < 0):
		print("Negative delta: ", delta)
	
	if Input.is_action_just_pressed("immediate_exit"):
		OS.kill(OS.get_process_id())	# Immediate exit

	if (firstRound):
		if ((lidarDataStorage.beamDataKeys) and (!lidarDataStorage.beamDataKeys.is_empty())):
			var lidarDataStartTime:int = lidarDataStorage.beamDataKeys[0]
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
		firstRound = false
	
	if (demoStarted):
		if (!demoStartRitualsDone):
			for animationPlayer in syncedAnimationPlayers:
				animationPlayer.play()
				
			$MainTunePlayer.play(dbgPlayStartPos)
			demoStartRitualsDone = true;
	else:
		return

	accumulatedDelta += delta
	camSwitch(accumulatedDelta * 1000)
#	replayTime_float += delta * 1000 * (replaySpeed_float / 100)
#	Global.replayTime_Lidar = replayTime_float
	
	get_viewport().set_msaa(Viewport.MSAA_8X)
	
	# Testing audio sync:
#	$AnimationPlayer.seek($MainTunePlayer.filteredPlaybackPosition)
#	$AnimationPlayer.advance($MainTunePlayer.filteredPlaybackPosition - $AnimationPlayer.current_animation_position)
	
	var tunePlaybackPosition:float = tunePlayer.getFilteredPlaybackPosition()
#	var tunePlaybackPosition:float = tunePlayer.filteredPlaybackPosition
	
	for animationPlayer in syncedAnimationPlayers:
		if (absf(animationPlayer.current_animation_position - tunePlaybackPosition) > 0.1) && (tunePlayer.playing):
			# Animation playback position differs too much from the tune -> Hard sync
	#		print("anim hard resync: ", animationPlayer.current_animation_position - tunePlaybackPosition)
			animationPlayer.seek(tunePlaybackPosition)
			animationPlayer.playback_speed = tunePlayer.pitch_scale
		else:
			if (tunePlayer.playing):
				if (!animationPlayer.is_playing()):
					animationPlayer.play()
				var playbackSpeed = (tunePlayer.pitch_scale * 
					(1.0 + (tunePlaybackPosition - animationPlayer.current_animation_position) * 1.0))
				animationPlayer.playback_speed = playbackSpeed
	#			print(playbackSpeed)
			else:
				if (absf(animationPlayer.current_animation_position - tunePlaybackPosition) > 0.001):
					# seek doesn't seem to update things if not played for at least one frame
					# Bit hacky way to do this, but seems to work...
					animationPlayer.playback_speed = 0
					animationPlayer.play()
					animationPlayer.seek(tunePlaybackPosition)
				else:
					animationPlayer.stop(false)
	
	updateCameraCopyPasteFields()

#	Global.oscilloscopeMaterial.set_shader_param("soundPos", int(tunePlaybackPosition * 8000))
	
#	Global.oscilloscopeSoundMasterPosition = int(tunePlaybackPosition * 8000)
#	ProjectSettings.set_setting("Shader Globals/soundPos", Global.oscilloscopeSoundMasterPosition)
	
#	$AdditiveGeometry.get_active_material(0).set_shader_param("replayTime", replayTime_float)
#	$AdditiveGeometry.replayTime = replayTime_float
#	ScanTracker.replayTime = replayTime_float
	controlPlayback(delta)
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

func camSwitch(uptime):
	var oldCamera = get_viewport().get_camera_3d()
	var newCamera = null
	
	if Input.is_action_just_pressed("camera_first_person_global"):
		var firstPerson = get_node("FirstPersonFlyer")
		var flyCamera = get_node("FirstPersonFlyer/Head/FirstPersonCamera")
		firstPerson.set_LocationOrientation(get_viewport().get_camera_3d().get_global_transform())
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
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Yaw, "%1.3f" % -rad2deg(yawPitchRoll.y))
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Pitch, "%1.3f" % rad2deg(yawPitchRoll.x))
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Roll, "%1.3f" % rad2deg(yawPitchRoll.z))
	
	updateLineEditTextIfChanged($DebugThings/Panel_CurrentCameraTransform/LineEdit_Roll, "%1.3f" % rad2deg(yawPitchRoll.z))

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
	var tex = ImageTexture.new()
	tex.create_from_image(img)
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

func checkForPrematureExit():
	if ($Panel_Start/OptionButton_Ending.get_selected_id() == 2):
		OS.kill(OS.get_process_id())	# Immediate exit

func killMe():
	OS.kill(OS.get_process_id())	# Immediate exit
