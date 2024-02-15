@tool
extends MeshInstance3D

var initDone:bool = false

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	pass # Replace with function body.

func _process(_delta):
	if (!Global):
		return

	if (Global.lowPassFilteredSoundDataTexture != null) && (!initDone):
		self.material_override.set_shader_parameter("soundDataSampler", Global.lowPassFilteredSoundDataTexture)
		initDone = true
		
	self.material_override.set_shader_parameter("soundPos", Global.masterReplayTime * 8000)
	
class StashData:
	var haloSoundDataSampler

func stashToolData():
	var stashStorage:StashData = StashData.new()
	print("Stashing tool data (Wormhole)")
	stashStorage.haloSoundDataSampler = self.material_override.get_shader_parameter("soundDataSampler")
	self.material_override.set_shader_parameter("soundDataSampler", null)
	return stashStorage

func stashPullToolData(stashStorage:StashData):
	print("Stash pulling tool data (Wormhole)")
	self.material_override.set_shader_parameter("soundDataSampler", stashStorage.haloSoundDataSampler)
