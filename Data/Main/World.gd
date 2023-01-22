@tool
extends Node3D

@export var originShift:Vector3
@export var scalingOverride:float
@export var editorCameraNodePath:NodePath

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

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
			
	var distance:float = camera.global_transform.origin.length()
	
#	var scaling:float = 1.0 - (0.9999 * smoothstep(100, 400, distance))
#	var scaling:float = 1.0 / (20000.0 - (19999.0 * (1.0 - smoothstep(500, 3500, distance))))
	var scaling:float = 1.0 / (20000.0 - (19999.0 * (1.0 - smoothstep(100, 3900, distance))))
	
	if (scalingOverride != 0):
		scaling = scalingOverride
	
	if ((lastScaling != 1.0) || (scaling != 1.0) || self.transform.origin != scaling * originShift):
		# Physics seem to freeze if scaling is set on _process
		# Therefore do not set it all the time
		self.transform.basis =  Basis.IDENTITY.scaled(Vector3(scaling, scaling, scaling))
		self.transform.origin = scaling * originShift
	
	lastScaling = scaling
	
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
	
