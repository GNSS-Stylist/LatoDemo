@tool
extends Node3D

@export var scopeLength:float = 4096
var initDone:bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if ((!Global) ||(Engine.is_editor_hint() && Global.cleanTempToolData)):
		# @tool-scripts will generate changes that are saved into .tscn (scene)-files.
		# Clean them when requested
		
		print("Cleaning data generated by @tool, ", self.name)
		$Surface.material_override = null
		return

	return
	
	if (false):
		var newMaterial = ShaderMaterial.new()
		newMaterial.shader = Global.oscilloscope3DShader
		$Surface.material_override = newMaterial
	else:
		$Surface.material_override = Global.blockableGNSSSignalMaterial
	
#	initDone = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if ((!Global) ||(Engine.is_editor_hint() && Global.cleanTempToolData)):
		return

	return
	
	# No need for these here as material is shared
	if (Global.soundDataTexture != null) && (!initDone):
		$Surface.material_override.set_shader_parameter("soundDataSampler", Global.soundDataTexture)
		initDone = true

#	$Surface.material_override.set_shader_param("soundOffset", soundSampleOffset)
	$Surface.material_override.set_shader_parameter("soundPos", Global.oscilloscopeSoundMasterPosition)
	$Surface.material_override.set_shader_parameter("soundLength", scopeLength)
	$Surface.material_override.set_shader_parameter("startOrigin_Object", Vector3($Surface.mesh.size.x / 2, 0, 0) + $Surface.mesh.center_offset)
	$Surface.material_override.set_shader_parameter("endOrigin_Object", Vector3(-$Surface.mesh.size.x / 2, 0, 0) + $Surface.mesh.center_offset)
