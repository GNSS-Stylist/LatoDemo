@tool
extends SubViewport

@onready var mainNode:Node3D = get_parent()

var oldSize:Vector2i

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	pass

func _process(_delta):
	var currSize:Vector2i = mainNode.get_viewport().size

	if (Engine.is_editor_hint()):
		# main viewport size doesn't work on editor
		# -> Just use fullHD
		currSize = Vector2i(1920, 1080)

	if (currSize != oldSize):
		print("New scroller viewport size: ", currSize)
		self.size = currSize
		oldSize = currSize
