@tool
extends Node3D
class_name ShipTracker

@export var minRecMovement:float = 0.01		# world units (metres)
@export var minRecAngleChange:float = 0.01	# degrees
@export var minRecTimeDiff:float = 0.032	# seconds

@export var replayTimeOverride:float = 0			# 0 = use Global.masterReplayTime
@export var replayTimeShift:float = 0
@export var replayLaserShotColor:Color = Color(0, 5, 0)

@export var originInterpolationMethod:OriginInterpolationMethod = OriginInterpolationMethod.CUBIC
@export var quatInterpolationMethod:QuatInterpolationMethod = QuatInterpolationMethod.SLERP
@export var laserOriginShift:Vector3 = Vector3.ZERO

enum OriginInterpolationMethod { LAST_VALUE, NEXT_VALUE, NEAREST_VALUE, LINEAR, CUBIC }
enum QuatInterpolationMethod { LAST_VALUE, NEXT_VALUE, NEAREST_VALUE, SLERP, SLERPNI, SPERICAL_CUBIC }

class LOData:
	var origin:Vector3
	var quat:Quaternion
	
var lastRecordLocation:Vector3
var lastRecordOrientation:Quaternion = Quaternion.IDENTITY
var lastRecordTime:float = -1e12

var loData = {}	# Key = Time, value = LOData
var loDataKeys = []

var laserData = {}	# Key = Time, value = LOData
var laserDataKeys = []

enum WorkingMode {
	STOPPED,
	RECORDING,
	PLAYING
}

var workingMode:WorkingMode = WorkingMode.STOPPED

var nextReplayTimeIndex:int = 0

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	pass # Replace with function body.

func _process(_delta):
	match (workingMode):
		WorkingMode.RECORDING:
			transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
			if (((self.global_position.distance_to(lastRecordLocation) >= minRecMovement) ||
					(rad_to_deg(self.global_transform.basis.orthonormalized().get_rotation_quaternion().angle_to(lastRecordOrientation)) > minRecAngleChange)) &&
					absf(Global.masterReplayTime - lastRecordTime) >= minRecTimeDiff):
				var newData:LOData = LOData.new()
				newData.origin = self.global_position
				newData.quat = self.global_transform.basis.orthonormalized().get_rotation_quaternion()
				loData[Global.masterReplayTime] = newData
				
				lastRecordLocation = self.global_position
				lastRecordOrientation = self.global_transform.basis.orthonormalized().get_rotation_quaternion()
				lastRecordTime = Global.masterReplayTime

		WorkingMode.PLAYING:
			if (Global && (!loData.is_empty())):
				var currentReplayTime:float
				if (replayTimeOverride != 0):
					currentReplayTime = replayTimeOverride + replayTimeShift
				else:
					currentReplayTime = Global.masterReplayTime + replayTimeShift
				
				if nextReplayTimeIndex < loDataKeys.size():
					for _i in range(10):
						# Maybe this faster than using bsearch every time(?)
						# Run this some rounds to allow some hickups in screen update etc.
						if nextReplayTimeIndex < loDataKeys.size() and currentReplayTime >= loDataKeys[nextReplayTimeIndex]:
							# Typical case: monotonically increasing ReplayTime
							nextReplayTimeIndex += 1
							continue
						elif nextReplayTimeIndex > 0 and currentReplayTime < loDataKeys[nextReplayTimeIndex - 1]:
							# Another typical(ish?) case: monotonically decreasing ReplayTime
							nextReplayTimeIndex -= 1
							continue
						else:
							break
					
					if (nextReplayTimeIndex > 0 and nextReplayTimeIndex < loDataKeys.size() and 
						(currentReplayTime < loDataKeys[nextReplayTimeIndex - 1] or 
							currentReplayTime >= loDataKeys[nextReplayTimeIndex])):
						# ReplayTime changed too fast
						# -> Use bsearch to find the correct index
						nextReplayTimeIndex = loDataKeys.bsearch(currentReplayTime)
				elif currentReplayTime < loDataKeys[loDataKeys.size() - 1]:
					# "Rewind" while in the last item
					nextReplayTimeIndex = loDataKeys.bsearch(currentReplayTime)
				
				var nextReplayTimeValue:float

				if nextReplayTimeIndex < loDataKeys.size():
					nextReplayTimeValue = loDataKeys[nextReplayTimeIndex]
				else:
					nextReplayTimeValue = loDataKeys[loDataKeys.size() - 1]
					
				var origin:Vector3
				var quat:Quaternion
				
				if nextReplayTimeIndex <= 0:
					origin = loData[nextReplayTimeValue].origin
					quat = loData[nextReplayTimeValue].quat
				elif nextReplayTimeValue == currentReplayTime:
					origin = loData[nextReplayTimeValue].origin
					quat = loData[nextReplayTimeValue].quat
				elif nextReplayTimeIndex >= loDataKeys.size() - 1:
					origin = loData[loDataKeys[loDataKeys.size() -1]].origin
					quat = loData[loDataKeys[loDataKeys.size() -1]].quat
				else:
					var lastReplayTimeIndex:int = nextReplayTimeIndex - 1
					var lastReplayTimeValue:float = loDataKeys[lastReplayTimeIndex]
					var fraction:float = float(currentReplayTime - lastReplayTimeValue) / (nextReplayTimeValue - lastReplayTimeValue)
					var origin_a:Vector3 = loData[lastReplayTimeValue].origin
					var origin_b:Vector3 = loData[nextReplayTimeValue].origin
					var quat_a:Quaternion = loData[lastReplayTimeValue].quat
					var quat_b:Quaternion = loData[nextReplayTimeValue].quat

					if nextReplayTimeIndex == 1 or nextReplayTimeIndex == loDataKeys.size() - 1:
						# linear interpolation when cubic not possible
						origin = origin_a.lerp(origin_b, fraction)
						quat = quat_a.slerp(quat_b, fraction)
					else:

						match originInterpolationMethod:
							OriginInterpolationMethod.LAST_VALUE:
								origin = origin_a
							OriginInterpolationMethod.NEXT_VALUE:
								origin = origin_b
							OriginInterpolationMethod.NEAREST_VALUE:
								origin = origin_a if fraction < 0.5 else origin_b
							OriginInterpolationMethod.LINEAR:
								origin = origin_a.lerp(origin_b, fraction)
							OriginInterpolationMethod.CUBIC:
								var origin_pre_a:Vector3 = loData[loDataKeys[lastReplayTimeIndex - 1]].origin
								var origin_post_b:Vector3 = loData[loDataKeys[nextReplayTimeIndex + 1]].origin
								origin = origin_a.cubic_interpolate(origin_b, origin_pre_a, origin_post_b, fraction)
							_:
								origin = origin_a

						match quatInterpolationMethod:
							QuatInterpolationMethod.LAST_VALUE:
								quat = quat_a
							QuatInterpolationMethod.NEXT_VALUE:
								quat = quat_b
							QuatInterpolationMethod.NEAREST_VALUE:
								quat = quat_a if fraction < 0.5 else quat_b
							QuatInterpolationMethod.SLERP:
								quat = quat_a.slerp(quat_b, fraction)
							QuatInterpolationMethod.SLERPNI:
								# Causes some strange jitter
								quat = quat_a.slerpni(quat_b, fraction)
							QuatInterpolationMethod.SPERICAL_CUBIC:
								# Causes even stranger jitter
								var quat_pre_a:Quaternion = loData[loDataKeys[lastReplayTimeIndex - 1]].quat
								var quat_post_b:Quaternion = loData[loDataKeys[nextReplayTimeIndex + 1]].quat
								quat = quat_a.spherical_cubic_interpolate(quat_b, quat_pre_a, quat_post_b, fraction)
							_:
								quat = quat_a

			#	print("Original basis: ", basis)

			#	print("Original basis inverse: ", basis.inverse())
				
				transform = Transform3D(quat, origin)
			else:
				# Out of sight if no data (collision shape will cause problems
				# otherwise, like throwing the barn out of it's place)
				self.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1e9, 0))
		WorkingMode.STOPPED:
			# Out of sight if no data (collision shape will cause problems
			# otherwise, like throwing the barn out of it's place)
			if (loData.is_empty()):
				self.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1e9, 0))



func startRecording():
	workingMode = WorkingMode.RECORDING
	lastRecordTime = -1e12
	lastRecordLocation = Vector3(1e12, 1e12, 1e12)

func recordLaserShot():
	if (workingMode == WorkingMode.RECORDING):
		var shot:LOData = LOData.new()
		
		shot.origin = self.global_position
		shot.quat = self.global_transform.basis.orthonormalized().get_rotation_quaternion()
		
		laserData[Global.masterReplayTime] = shot
	
func recordLaserShotFromNode(shotNode:Node3D):
	if (workingMode == WorkingMode.RECORDING):
		var shot:LOData = LOData.new()
		
		shot.origin = shotNode.global_position
		shot.quat = shotNode.global_transform.basis.orthonormalized().get_rotation_quaternion()
		
		laserData[Global.masterReplayTime] = shot

func stopRecording():
	workingMode = WorkingMode.STOPPED
	loDataKeys = loData.keys()
	loDataKeys.sort()
	laserDataKeys = laserData.keys()
	laserDataKeys.sort()

# fileName="" -> use dialog
func saveToFile(fileName:String = ""):
	if (fileName == ""):
		$FileDialog_Save.show()
	else:
		var file = FileAccess.open_compressed(fileName, FileAccess.WRITE, FileAccess.COMPRESSION_DEFLATE)

		if (!file):
			print("Can't open file ", fileName)

		for itemIndex in range(0, loDataKeys.size()):
			var loItem:LOData = loData[loDataKeys[itemIndex]]
			file.store_8(0)	# data ident (ship location/orientation)
			file.store_float(loDataKeys[itemIndex])
			file.store_float(loItem.origin.x)
			file.store_float(loItem.origin.y)
			file.store_float(loItem.origin.z)
			file.store_float(loItem.quat.x)
			file.store_float(loItem.quat.y)
			file.store_float(loItem.quat.z)
			file.store_float(loItem.quat.w)

		for itemIndex in range(0, laserDataKeys.size()):
			var laserItem:LOData = laserData[laserDataKeys[itemIndex]]
			file.store_8(1)	# data ident (laser beams start location/orientation)
			file.store_float(laserDataKeys[itemIndex])
			file.store_float(laserItem.origin.x)
			file.store_float(laserItem.origin.y)
			file.store_float(laserItem.origin.z)
			file.store_float(laserItem.quat.x)
			file.store_float(laserItem.quat.y)
			file.store_float(laserItem.quat.z)
			file.store_float(laserItem.quat.w)
			
		file.close()

	
# fileName="" -> use dialog
func loadFromFile(fileName:String = ""):
	if (fileName == ""):
		$FileDialog_Load.show()
	else:
		clear()

		var shots = $LaserShots.get_children()
		for shot in shots:
			shot.queue_free()

		var file = FileAccess.open_compressed(fileName, FileAccess.READ, FileAccess.COMPRESSION_DEFLATE)
		if (!file):
			print("Can't open file ", fileName)

		while file.get_position() < file.get_length():
			var type:int = file.get_8()
			var time:float = file.get_float()
			match type:
				0:
					var newLOData:LOData = LOData.new();
					newLOData.origin = Vector3(file.get_float(), file.get_float(), file.get_float())
					newLOData.quat = Quaternion(file.get_float(), file.get_float(), file.get_float(),file.get_float())
					loData[time] = newLOData
				1:
					var newLaserData:LOData = LOData.new();
					newLaserData.origin = Vector3(file.get_float(), file.get_float(), file.get_float())
					newLaserData.quat = Quaternion(file.get_float(), file.get_float(), file.get_float(),file.get_float())
					laserData[time] = newLaserData
				_:
					print("Unknown datatype in ShipTrackerData file ", fileName, ", quitting")
					file.close()
					return

		loDataKeys = loData.keys()
		laserDataKeys = laserData.keys()
		file.close()
		
		# Just create laser beams right away. This could and should be done
		# on the fly but taking a shortcut here (because lazy). Sorry.
		
		var laserScene = load("res://Data/Elite/LaserBeam/LaserBeam.tscn")

		for shotIndex in range(laserDataKeys.size()):
			var time:float = laserDataKeys[shotIndex]
			var laserItem:LOData = laserData[time]
			
			var rootNode = $LaserShots
			var beam = laserScene.instantiate()
			rootNode.add_child(beam)
			var shotBasis = Basis(laserItem.quat)
			var shotOrigin = laserItem.origin + shotBasis * laserOriginShift
			beam.shoot(shotOrigin, -Basis(laserItem.quat).z.normalized(), replayLaserShotColor, 0, time)
#			beam.shoot(laserItem.origin, laserItem.direction, replayLaserShotColor, 0, time)

func play():
	workingMode = WorkingMode.PLAYING

func clear():
	loData.clear()
	loDataKeys.clear()
	laserData.clear()
	laserDataKeys.clear()

func _on_file_dialog_save_file_selected(path):
	saveToFile(path)

func _on_file_dialog_load_file_selected(path):
	loadFromFile(path)

func _on_file_dialog_load_visibility_changed():
	Global.processActionKeys = !$FileDialog_Load.visible

func _on_file_dialog_save_visibility_changed():
	Global.processActionKeys = !$FileDialog_Save.visible
