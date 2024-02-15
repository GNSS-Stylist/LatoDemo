#@tool
extends Node3D
class_name SolarCell

@export var baseMaterial:Material
@export var cellMaterial:Material

# This does not give "unique" materials(?)
#@onready var localBaseMaterial:Material = baseMaterial.duplicate()
#@onready var localCellMaterial:Material = cellMaterial.duplicate()

# Tried to make cells to gradually appear using alpha, but just couldn't get it working
# (Somehow failed to make materials unique for each cell).
# Dunno what went wrong, but replacing this with growing panels instead.
# (Could write a shader for this, but I'm too lazy just now...)

#var localBaseMaterial:Material
#var localCellMaterial:Material
#
#var localBaseColor:Color
#var localCellColor:Color

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
# Wondering these: Read above
#	localBaseMaterial = baseMaterial.duplicate(true)
#	localCellMaterial = cellMaterial.duplicate(true)

#	$Base.mesh.surface_set_material(0, localBaseMaterial)
#	$Cell.mesh.surface_set_material(0, localCellMaterial)

#	localBaseColor = Color(baseMaterial.albedo_color)
#	localBaseColor.r = randf()
#	localBaseColor.g = randf()
#	localBaseColor.b = randf()
#	localBaseMaterial.albedo_color = localBaseColor

	$Front.mesh.surface_set_material(0, cellMaterial)

#	$Back.mesh.surface_set_material(0, localBaseMaterial)
	$Back.mesh.surface_set_material(0, baseMaterial)
	$MinusX.mesh.surface_set_material(0, baseMaterial)
	$PlusX.mesh.surface_set_material(0, baseMaterial)
	$MinusZ.mesh.surface_set_material(0, baseMaterial)
	$PlusZ.mesh.surface_set_material(0, baseMaterial)
