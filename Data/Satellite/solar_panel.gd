@tool
extends Node3D

@export var columns:int = 6
@export var rows:int = 15

# alphas are relative to flying time
@export var size0Time:float = 0
@export var size1Time:float = 0.3

# flyTime is relative to "total construction time" of the panel (0...1)
@export var flyTime:float = 0.2

@export var flyDistance_Min:float = 3
@export var flyDistance_Max:float = 5

@export var flyDirLimits_Min:Vector3 = Vector3(-1, -1, 0)
@export var flyDirLimits_Max:Vector3 = Vector3(1, 1, 1)

@export var maxInitialRotation:float = 6.28

@export var randomSeed:int

#@export var constructionFraction:float = 1

@export var constructionOrigin:Vector3

@export var rowsToSkip = []
@export var columnsToSkip = []

#var updateConstructionFractionReq:bool = false

@export var constructionFraction:float = 1:
	get:
		return constructionFraction
	set(newValue):
		if (newValue != constructionFraction):
#			updateConstructionFractionReq = true
			updateFraction(newValue)
		constructionFraction = newValue

class Cell:
	var node:SolarCell
	var frozen_Start:bool
	var frozen_End:bool
	var finalPos:Vector3
	var initialPos:Vector3
	var initialRotations:Vector3
	var rotationOrder:int	# EULER_ORDER_???
	var flyStartTime:float	# In relation to "total construction time" of the panel (0...1)
	var flyEndTime:float	# In relation to "total construction time" of the panel (0...1)

var solarCells = []

#@onready var rootNode = get_node("/root")
#@onready var boxScene = load("res://BasicCube.tscn")
@onready var solarCellScene:PackedScene = preload("res://Data/Satellite/solar_cell.tscn")

const cellDiameter:float = 0.1

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	var rng = RandomNumberGenerator.new()
	rng.seed = randomSeed
#	var totalCells:int = rows * columns
#	var cellIndex = 0

	var minDistance:float = 1e9
	var maxDistance:float = 0
	
	# Calculate by brute force (not cool) the minimum and maximum distances to cells
	# (This is used later for "construction order" of the panel (to make it look cool(er))
	for row in range(0, rows):
		for column in range(0, columns):
			var origin = Vector3(row * cellDiameter - (rows - 1) * cellDiameter / 2, 0, column * cellDiameter - (columns - 1) * cellDiameter / 2)
			var distance = constructionOrigin.distance_to(origin)
			minDistance = min(minDistance, distance)
			maxDistance = max(maxDistance, distance)

	for row in range(0, rows):
		if (rowsToSkip.has(row)):
			continue
		for column in range(0, columns):
			if (columnsToSkip.has(column)):
				continue
			var cellNode = solarCellScene.instantiate()
#			box.transform = get_node("ManipulatorMeshes/ManipulatorExtension").global_transform
			var origin = Vector3(row * cellDiameter - (rows - 1) * cellDiameter / 2, 0, column * cellDiameter - (columns - 1) * cellDiameter / 2)
			cellNode.transform = Transform3D(Basis.IDENTITY, origin)
			add_child(cellNode)
			var newCell:Cell = Cell.new()
			newCell.node = cellNode
			newCell.finalPos = origin

			var initialTranslation = Vector3(rng.randf_range(flyDirLimits_Min.x, flyDirLimits_Max.x), 
					rng.randf_range(flyDirLimits_Min.y, flyDirLimits_Max.y),
					rng.randf_range(flyDirLimits_Min.z, flyDirLimits_Max.z)).normalized() * rng.randf_range(flyDistance_Min, flyDistance_Max)
			newCell.initialPos = origin + initialTranslation
			
			newCell.initialRotations = Vector3(rng.randf() * maxInitialRotation, rng.randf() * maxInitialRotation, rng.randf() * maxInitialRotation)
			newCell.rotationOrder = rng.randi_range(0, EULER_ORDER_ZYX)

#			var cellIndex:int = (row * columns) + (column)
#			var cellIndex:int = (row * columns) + (column)

			var distance = constructionOrigin.distance_to(origin)
			newCell.flyStartTime = (distance - minDistance) / (maxDistance - minDistance) * (1 - flyTime)
			newCell.flyEndTime = newCell.flyStartTime + flyTime
			
			newCell.frozen_Start = false
			newCell.frozen_End = false

#			newCell.flyStartTime = float(cellIndex) / float(totalCells) * (1 - flyTime)
#			newCell.flyEndTime = newCell.flyStartTime + flyTime
			
#			newCell.flyStartTime = float(cellIndex) / float(totalCells)
#			newCell.flyEndTime = float(cellIndex + 1) / float(totalCells)
			
			solarCells.push_back(newCell)
	updateFraction(constructionFraction)

#func _process(_delta):
#	if updateConstructionFractionReq:
#		updateFraction(constructionFraction)
#		updateConstructionFractionReq = false
#	constructionFraction += _delta * 10
#	updateFraction()


func updateFraction(fraction):
#	for celll in solarCells:
#		var cell:Cell = celll	# Just to make automatic suggestions work (you can't use type info in for-loop?)
	for cell in solarCells:
		var cellFraction = clampf((fraction - cell.flyStartTime) / (cell.flyEndTime - cell.flyStartTime), 0, 1)
		
		if (((cellFraction <= 0) && (cell.frozen_Start)) ||
				((cellFraction >= 1) && (cell.frozen_End))):
			continue

		var smoothSteppedFraction = smoothstep(0, 1, cellFraction)
		var cellOrigin:Vector3 = cell.finalPos + (1 - smoothSteppedFraction) * (cell.initialPos - cell.finalPos)
		var cellBasis:Basis = Basis.from_euler(cell.initialRotations * (1 - smoothSteppedFraction), cell.rotationOrder)
		cellBasis *= smoothstep(size0Time, size1Time, cellFraction)
		cell.node.transform = Transform3D(cellBasis, cellOrigin)
		
#		var smoothSteppedAlpha = smoothstep(alpha0Time, alpha1Time, cellFraction)
		
#		smoothSteppedAlpha = cellFraction
		
#		cell.node.localBaseMaterial.albedo_color.a = smoothSteppedAlpha
#		cell.node.localCellMaterial.albedo_color.a = smoothSteppedAlpha

		cell.frozen_Start = (cellFraction <= 0)
		cell.frozen_End = (cellFraction >= 1)
