extends Node3D

@export var scopeLength:float = 4096

var initDone:bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	var newMaterial = ShaderMaterial.new()
	newMaterial.shader = Global.oscilloscope3DShader
	$Surface.material_override = newMaterial
	
#	initDone = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if (Global.soundDataTexture != null) && (!initDone):
		$Surface.material_override.set_shader_param("soundDataSampler", Global.soundDataTexture)
		initDone = true

#	$Surface.material_override.set_shader_param("soundOffset", soundSampleOffset)
	$Surface.material_override.set_shader_param("soundPos", Global.oscilloscopeSoundMasterPosition)
	$Surface.material_override.set_shader_param("soundLength", scopeLength)
	$Surface.material_override.set_shader_param("startOrigin_Object", Vector3($Surface.mesh.size.x / 2, 0, 0) + $Surface.mesh.center_offset)
	$Surface.material_override.set_shader_param("endOrigin_Object", Vector3(-$Surface.mesh.size.x / 2, 0, 0) + $Surface.mesh.center_offset)
