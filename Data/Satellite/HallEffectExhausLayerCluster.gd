@tool
extends Node3D

@export var numOfLayers:int = 8
@export var scalingLowLimit:float = 0.1
@export var scalingHighLimit:float = 1.0

@export var material:Material:
	get:
		return material
	set(newMaterial):
		material = newMaterial
		for i in range(min(numOfLayers, exhaustLayers.size())):
			exhaustLayers[i].material = newMaterial

@onready var HallThrusterExhaustLayer = preload("res://Data/Satellite/HallThrusterExhaustLayer.tscn")

var exhaustLayers = []

# Called when the node enters the scene tree for the first time.
func _ready():
	exhaustLayers.resize(numOfLayers)
	for i in range(numOfLayers):
		var newLayer = HallThrusterExhaustLayer.instantiate()
#		newLayer.transform.basis.y = scalingLowLimit + i * (scalingHighLimit - scalingLowLimit) / (numOfLayers - 1)
		newLayer.transform = newLayer.transform.scaled(Vector3(1, scalingLowLimit + i * (scalingHighLimit - scalingLowLimit) / (numOfLayers - 1), 1))
		newLayer.material = material
		exhaustLayers[i] = newLayer
		self.add_child(newLayer)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	print("_process, ", self.name)

#	pass
