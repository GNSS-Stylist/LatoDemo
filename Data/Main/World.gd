@tool
extends Node3D

@export var originShift:Vector3
@export var scalingOverride:float
@export var inverseScalingOverride:float
@export var editorCameraNodePath:NodePath

# These are to fake infinite distance to the world (planet at these distances)
# (relative translation to the followed node will be kept same)
@export var relativeFollowNode:NodePath
@export var relativeFollowTranslation:Vector3
@export var followRelativePosition:bool

# Called when the node enters the scene tree for the first time.
func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	pass
	
#var lastReportTimer:float
var lastScaling:float = 1.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if ((!Global) ||(Engine.is_editor_hint() && Global.cleanTempToolData)):
		return

	var camera:Camera3D

	if (Engine.is_editor_hint()):
		camera = get_node(editorCameraNodePath)
	else:
		camera = get_viewport().get_camera_3d()
			
	var distance:float = (self.global_transform.origin - camera.global_transform.origin).length()
	
#	var scaling:float = 1.0 - (0.9999 * smoothstep(100, 400, distance))
#	var scaling:float = 1.0 / (20000.0 - (19999.0 * (1.0 - smoothstep(500, 3500, distance))))
	var scaling:float = 1.0 / (20000.0 - (19999.0 * (1.0 - smoothstep(100, 3900, distance))))
	
	if (scalingOverride != 0):
		# Godot rounds floats to 0.001 precision in the editor so to be able to feed 
		# meaningful values here, we need to scale this...
		# So now 10k means that the planet looks correct when looked at from the distance of the satellite
		# and 1 when on the surface of the planet.
		scaling = scalingOverride * 0.0001
	elif (inverseScalingOverride != 0):
		scaling = 1.0 / inverseScalingOverride
	
	if ((lastScaling != 1.0) || (scaling != 1.0) || self.transform.origin != scaling * originShift):
		# Physics seem to freeze if scaling is set on _process
		# Therefore do not set it all the time
		self.transform.basis =  Basis.IDENTITY.scaled(Vector3(scaling, scaling, scaling))
		self.transform.origin = scaling * originShift
	
	lastScaling = scaling
	
	if (followRelativePosition):
		self.transform.origin += get_node(relativeFollowNode).global_transform.origin + relativeFollowTranslation
	
#	lastReportTimer += delta
#	if (lastReportTimer > 1):
#		print("                                       distance: ", distance, "scaling: ", scaling)
#		lastReportTimer -= 1

func _physics_process(_delta):
	var camera:Camera3D

	if (Engine.is_editor_hint()):
		camera = get_node(editorCameraNodePath)
	else:
		camera = get_viewport().get_camera_3d()

	var distance:float = camera.global_transform.origin.length()
	if ((transform.basis.get_scale().x < 0.999) || 
			(transform.basis.get_scale().y < 0.999) ||
			(transform.basis.get_scale().z < 0.999) ||
			(distance > 99)):
		# Not sure how physics work when things are scaled -> disable
		$AdditiveGeometries/Barn.freeze = true
#		PhysicsServer3D.set_active(false)
	else:
		$AdditiveGeometries/Barn.freeze = false
#		PhysicsServer3D.set_active(true)
	
