@tool
extends Node3D

class_name  LaserBeamScene

#@export var timeOverride:float

const flyingSpeed:float = 1000
const beamLength:float = 100

var shootTime:float = 0
var hitDistance:float = 0		# Fly distance along shootDirection
var selfDestructDistance:float = 10000

var lastLeadingEdgeDistance = 0

@onready var beam:MeshInstance3D = $Beam
@onready var hitGlow:MeshInstance3D = $Beam/HitGlow
@onready var beamSound:SpaceSoundEmitter = $SpaceSoundEmitter_Beam
@onready var hitSound:SpaceSoundEmitter = $SpaceSoundEmitter_Hit
@onready var fireSound:SpaceSoundEmitter = $SpaceSoundEmitter_Fire

func shootFromNode(originNode:Node3D, albedo:Color, selfDestructDistance_p:float = 0, shootTime_p:float = 0):
	shoot(originNode.global_position, -originNode.global_transform.basis.z, albedo, selfDestructDistance_p, shootTime_p)

# Use origin/direction in global coordinates!
func shoot(origin_p:Vector3, direction_p:Vector3, albedo:Color, selfDestructDistance_p:float = 0, shootTime_p:float = 0):
	if (shootTime_p == 0):
		shootTime = Global.masterReplayTime
	else:
		shootTime = shootTime_p
		
	self.global_position = origin_p
	self.look_at(origin_p + direction_p)
	self.selfDestructDistance = selfDestructDistance_p
	hitDistance = 0
	lastLeadingEdgeDistance = 0
	beam.visible = false
	beam.set_instance_shader_parameter("albedo", albedo)

func reset():
	shootTime = 0
	hitDistance = 0
	beam.visible = false
	lastLeadingEdgeDistance = 0

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	reset()
	
var wasShot:bool = false

func _physics_process(_delta):
	if ((shootTime != 0) && (Global.masterReplayTime > shootTime)):
		var elapsed = Global.masterReplayTime - shootTime
		
		if (elapsed > 0):
			var leadingEdgeDistance = max(elapsed * flyingSpeed, 0)
			var trailingEdgeDistance = max(leadingEdgeDistance - beamLength, 0)
			
			if (!wasShot):
				fireSound.reset()
				fireSound.visible = true
			
#			sound.transform.origin.z = -(leadingEdgeDistance + trailingEdgeDistance) / 2
			beamSound.transform.origin.z = -(leadingEdgeDistance) / 2
			
			if ((hitDistance == 0) && (lastLeadingEdgeDistance > 10)):
				# TODO: Hitpoint should be updated continuously while hitting
				var space_state = get_world_3d().direct_space_state
				var params:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
				if (lastLeadingEdgeDistance > leadingEdgeDistance):
					params.from = self.global_position
				else:
					params.from = self.global_position - lastLeadingEdgeDistance * self.global_transform.basis.z
				params.to = self.global_position - leadingEdgeDistance * self.global_transform.basis.z
				var result = space_state.intersect_ray(params)
				if (!result.is_empty()):
					# Hit something, get distance along the fly path
					var hitPos:Vector3 = result.position
					hitDistance = (hitPos - self.global_position).dot(-self.global_transform.basis.z)
					hitSound.reset()
					fireSound.visible = false

			lastLeadingEdgeDistance = leadingEdgeDistance
				
			if ((selfDestructDistance != 0) && (leadingEdgeDistance > selfDestructDistance)):
				queue_free()
				beam.visible = false
			elif (hitDistance != 0):
				if (trailingEdgeDistance >= hitDistance):
					# Whole beam already past the hit
					beam.visible = false
				elif (leadingEdgeDistance > hitDistance):
					# Currently hitting
					hitSound.visible = true
					leadingEdgeDistance = hitDistance
					beam.visible = true
					hitGlow.visible = true
					hitGlow.position = self.global_position - hitDistance * self.global_transform.basis.z
				else:
					# Not yet hit (may get here when rewinding)
					beam.visible = true
					hitGlow.visible = false
			else:
				# Not yet hit
				beam.visible = true
				hitGlow.visible = false
			
			beam.set_instance_shader_parameter("leadingEdge", leadingEdgeDistance)
			beam.set_instance_shader_parameter("trailingEdge", trailingEdgeDistance)
			
			wasShot = true
			
		else:
			wasShot = false
			beam.visible = false
			fireSound.visible = false

	else:
		wasShot = false
		beam.visible = false
		hitSound.visible = false
		fireSound.visible = false

	beamSound.visible = beam.visible
