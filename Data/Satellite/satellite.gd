@tool
extends Node3D

@export var useCommonAntennaRodAngle:bool = true:
	get:
		return useCommonAntennaRodAngle
	set(newUseCommonAntennaRodAngle):
		useCommonAntennaRodAngle = newUseCommonAntennaRodAngle
		
@export var commonAntennaRodAngle:float = 10:
	get:
		return commonAntennaRodAngle
	set(newCommonAntennaRodAngle):
		commonAntennaRodAngle = newCommonAntennaRodAngle

@export var antennaBaseAngle:float:
	get:
		return antennaBaseAngle
	set(newAntennaBaseAngle):
		antennaBaseAngle = newAntennaBaseAngle
#		$Antenna1.baseAngle = antennaBaseAngle

@export var commonAntennaBaseLocalTranslation:Vector3:
	get:
		return commonAntennaBaseLocalTranslation
	set(newCommonAntennaBaseLocalTranslation):
		commonAntennaBaseLocalTranslation = newCommonAntennaBaseLocalTranslation
#		$Antenna1.localTranslation = commonAntennaBaseLocalTranslation

@export var bodyMorphFraction:float
@export var exoFrameFraction:float
@export var solarPanelFraction:float
@export var scopeActive:bool
@export var scopeLightEnergy:float = 1
@export var haloAlbedo:Color = Color(0, 1, 0, 1)

# This is added due to bug:
# https://github.com/godotengine/godot/issues/57543
# Order is YXZ
@export var useRotationOverride:bool = true
@export var rotationOverride:Vector3 = Vector3(0,0,0)

@onready var tunePlayer:AudioStreamPlayer = get_node("/root/Main/MainTunePlayer")

var initDone:bool = false

func _ready():
	$AnimationPlayer_BodyMorph.current_animation = "Morph"
	$AnimationPlayer_ExoFrames.current_animation = "ExoFramesFlying"
	$AnimationPlayer_SolarPanel.current_animation = "SolarPanelConstruction"

func _process(_delta):
	if (!Engine.is_editor_hint() && Global.lowPassFilteredSoundDataTexture != null) && (!initDone):
		$SoundHalo.material_override.set_shader_param("soundDataSampler", Global.lowPassFilteredSoundDataTexture)
		initDone = true

	# Animations seem to loop around if not clamped:
	$AnimationPlayer_BodyMorph.seek(clamp(bodyMorphFraction, 0, 1))
	$AnimationPlayer_ExoFrames.seek(clamp(exoFrameFraction, 0, 1))
	$AnimationPlayer_SolarPanel.seek(clamp(solarPanelFraction, 0, 1))

	if (useCommonAntennaRodAngle):
		$Antenna1.antennaRodAngle = commonAntennaRodAngle
		$Antenna2.antennaRodAngle = commonAntennaRodAngle
		$Antenna3.antennaRodAngle = commonAntennaRodAngle
		$Antenna4.antennaRodAngle = commonAntennaRodAngle
	
		$Antenna1.baseAngle = antennaBaseAngle
		$Antenna2.baseAngle = antennaBaseAngle
		$Antenna3.baseAngle = antennaBaseAngle
		$Antenna4.baseAngle = antennaBaseAngle

		$Antenna1.localTranslation = commonAntennaBaseLocalTranslation
		$Antenna2.localTranslation = commonAntennaBaseLocalTranslation
		$Antenna3.localTranslation = commonAntennaBaseLocalTranslation
		$Antenna4.localTranslation = commonAntennaBaseLocalTranslation

	$Frame_Lower/DishAntenna/ScopeLight.visible = scopeActive
	$Frame_Lower/DishAntenna/DbgSignal/BlockableGNSSSignal.visible = scopeActive

	if (scopeActive && tunePlayer && Global.soundData):
		var tunePlaybackPosition:float = tunePlayer.getFilteredPlaybackPosition()
#		$Frame_Lower/DishAntenna/ScopeLight.light_energy = abs((Global.soundData[tunePlaybackPosition * 8000] - 128.0) / 128.0) * scopeLightEnergy
		$Frame_Lower/DishAntenna/ScopeLight.light_energy = Global.lowPassFilteredSoundAmplitudeData[tunePlaybackPosition * 8000] * scopeLightEnergy
		$SoundHalo.material_override.set_shader_param("soundPos", tunePlaybackPosition * 8000)
	$SoundHalo.material_override.set_shader_param("baseAlbedo", haloAlbedo)

	if (useRotationOverride):
		var newBasis = Basis.IDENTITY.rotated(Vector3.UP, deg2rad(rotationOverride.y)).rotated(Vector3.RIGHT, deg2rad(rotationOverride.x)).rotated(Vector3. BACK, deg2rad(rotationOverride.z))
		
		# TODO: This scaling should actually be outside this if, maybe...
		# And then found out that actually satellite doesn't want to be scaled.
		# Scaling causes FPS to drop to 10 (from >100)
		# So just leave it be. Works with World though. What's different here? Lighting?
		if (false):
			var camera:Camera3D = get_viewport().get_camera_3d()
			var distance:float = (global_transform.origin - camera.global_transform.origin).length()
			
		#	var scaling:float = 1.0 - (0.9999 * smoothstep(100, 400, distance))
		#	var scaling:float = 1.0 / (20000.0 - (19999.0 * (1.0 - smoothstep(500, 3500, distance))))
			var scaling:float = 1.0 / (20000.0 - (19999.0 * (1.0 - smoothstep(100, 3900, distance))))
			
			
			self.transform.basis =  newBasis.scaled(Vector3(scaling, scaling, scaling))
		else:
			self.transform.basis =  newBasis
