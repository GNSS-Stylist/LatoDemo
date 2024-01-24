@tool
extends SubViewport

@onready var mainNode:Node3D = get_parent().get_parent()

var oldSize:Vector2i

func _process(delta):
	var currSize:Vector2i = mainNode.get_viewport().size

	if (Engine.is_editor_hint()):
		# main viewport size doesn't work on editor
		# -> Just use 320 * 180
		currSize = Vector2i(320, 180)

	if (currSize != oldSize):
		var newYRes = 320 * currSize.y / currSize.x
		var newRes:Vector2i = Vector2i(320, newYRes)
		print("New elite viewport size: ", newRes)
		RenderingServer.global_shader_parameter_set("eliteOverlayResolution", Vector2(newRes))
		self.size = newRes
		oldSize = currSize

