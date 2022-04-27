extends MeshInstance3D

#enum STATE { 
#	not_initialized,		# setViewRange-function not called
#	idle,				# uptime not in range to cause any action
#	precaching_wait,	# uptime near the viewing range, waiting a thread from the thread pool to free
#	precaching,			# uptime near the viewing range, running a thread to gather the data needed/creating mesh
#	precached,			# uptime near the viewing range, mesh ready to be shown
#	visible_ready,		# mesh visible and constructed
#	visible_not_ready,	# mesh in view range but not constructed (precaching not fast enough or sudden change in uptime)
#	}
#
#var state:STATE = STATE.not_initialized

#var cubeSize = 0.01
#var tetrahedronSize = 0.01

var firstReplayTimeToShow:int = -1
var lastReplayTimeToShow:int = -1

var wasVisible:bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
#	self.material_override = Global.lidarPointMaterial

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if (mesh):
		if ((Global.replayTime_Lidar < (lastReplayTimeToShow + Global.lidarLineVisibleTime)) and
				(Global.replayTime_Lidar > firstReplayTimeToShow)):
			self.visible = true
#			get_active_material(0).set_shader_param("replayTime", Global.replayTime - Global.scanTrackerShaderBaseTime)
		else:
			self.visible = false


func setViewRange(firstReplayTimeToShow_p:int, lastReplayTimeToShow_p:int):
	firstReplayTimeToShow = firstReplayTimeToShow_p
	lastReplayTimeToShow = lastReplayTimeToShow_p

#	if ((firstReplayTimeToShow == -1) or (lastReplayTimeToShow == -1)):
#		state = STATE.not_initialized
#	else:
#		state = STATE.idle
