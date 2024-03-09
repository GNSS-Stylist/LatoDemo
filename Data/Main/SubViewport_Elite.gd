@tool
extends SubViewport

@onready var mainNode:Node3D = get_parent().get_parent()

const HorizontalResolution:int = 480

var oldSize:Vector2i

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	pass

func _process(_delta):
	var currSize:Vector2i = mainNode.get_viewport().size

	if (Engine.is_editor_hint()):
		# main viewport size doesn't work on editor
		# -> Just use HorizontalResolution * 6 / 9
		currSize = Vector2i(HorizontalResolution, HorizontalResolution * 9 / 16)

	if (currSize != oldSize):
		var newYRes = HorizontalResolution * currSize.y / currSize.x
		var newRes:Vector2i = Vector2i(HorizontalResolution, newYRes)
		print("New elite viewport size: ", newRes)
		RenderingServer.global_shader_parameter_set("eliteOverlayResolution", Vector2(newRes))
		self.size = newRes
		oldSize = currSize

