@tool
extends Node3D

#@export var timeOverride:float

const flyingSpeed:float = 10
const beamLength:float = 10

var shootTime:float = 0
var hitDistance:float = 0		# Fly distance along shootDirection
var selfDestructDistance:float = 10000

var lastLeadingEdgeDistance = 0

@onready var beam:MeshInstance3D = $Beam

# Use origin/direction in global coordinates!
func shoot(origin_p:Vector3, direction_p:Vector3, selfDestructDistance_p:float = 0):
	shootTime = Global.masterReplayTime
	self.global_position = origin_p
	self.look_at(origin_p + direction_p)
	self.selfDestructDistance = selfDestructDistance_p
	hitDistance = 0
	lastLeadingEdgeDistance = 0
	beam.visible = false

func reset():
	shootTime = 0
	hitDistance = 0
	beam.visible = false
	lastLeadingEdgeDistance = 0

func _ready():
	reset()

func _physics_process(delta):
	if ((shootTime != 0) && (Global.masterReplayTime > shootTime)):
		var elapsed = Global.masterReplayTime - shootTime
		
		if (elapsed > 0):
			var leadingEdgeDistance = clamp(elapsed * flyingSpeed, 0, 10000)
			var trailingEdgeDistance = clamp(leadingEdgeDistance - beamLength, 0, 10000)
			
			if ((hitDistance == 0) && (lastLeadingEdgeDistance > 10)):
				var space_state = get_world_3d().direct_space_state
				var params:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
				params.from = self.global_position + lastLeadingEdgeDistance * (-self.global_transform.basis.z)
				params.to = self.global_position + leadingEdgeDistance * (-self.global_transform.basis.z)
				var result = space_state.intersect_ray(params)
				if (!result.is_empty()):
					# Hit something, get distance along the fly path
					var hitPos:Vector3 = result.position
					hitDistance = (hitPos - self.global_position).dot(-self.global_transform.basis.z)

			lastLeadingEdgeDistance = leadingEdgeDistance
				
			if (hitDistance != 0):
				if (trailingEdgeDistance >= hitDistance):
					# Whole beam already past the hit
					beam.visible = false
				elif (leadingEdgeDistance > hitDistance):
					# Currently hitting
					leadingEdgeDistance = hitDistance
					beam.visible = true
				else:
					# Not yet hit (may get here when rewinding)
					beam.visible = true
			else:
				# Not yet hit
				beam.visible = true
			
			beam.set_instance_shader_parameter("leadingEdge", leadingEdgeDistance)
			beam.set_instance_shader_parameter("trailingEdge", trailingEdgeDistance)
			
			if ((selfDestructDistance != 0) && (leadingEdgeDistance > selfDestructDistance)):
				queue_free()

		else:
			beam.visible = false
	else:
		beam.visible = false
		
