@tool
extends SubViewport

@onready var mainNode:Node3D = get_parent()

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
		
		
		
		
		
		
		
		
		
		# Calculate new lower resolution based on the y-res
		# (number of high-res pixels per low-res pixel)
		# Try to keep pixel per pixel-value always integer,
		# Otherwise scaling looks very ugly.
		# Handling x&y separately leads to scaling errors when window/display
		# is stretched enough in some direction.
		
#		return
		
#		var pixelsPerPixel:int = int(currSize.x / max(floor(currSize.x / 256), 1)
		
		
		
		
		
#		var newRes:Vector2i = Vector2i(int(currSize.x / floor(currSize.x / 320)),
#				int(currSize.y / floor(currSize.y / 180)))
				
#		var newPixSize:Vector2 = Vector2(currSize.x / newRes.x, currSize.y / newRes.y)
		
		# Need square pixels to keep objects at their right shapes
		
#		print("New elite viewport size: ", currSize, ", res: ", newRes, ", pixel size: ", newPixSize)
	#	self.size = newRes
	#	oldSize = currSize
