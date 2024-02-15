@tool
extends Node3D

const MeshDisintegrator = preload("res://Data/MeshDisintegrator/MeshDisintegrator.gd")

@onready var meshDisintegrator:MeshDisintegrator = get_node("MeshDisintegrator")
@onready var greatAnimationPlayer:AnimationPlayer = get_node("GreatAnimationPlayer")

@export var text:String:
	set(newText):
		if ((meshDisintegrator) && (text != newText)):
			meshDisintegrator.textOverride = newText
			text = newText
	get:
		return text

@export var progress:float = 0:
	set(newProgress):
		if (greatAnimationPlayer && (newProgress != progress)):
			greatAnimationPlayer.seek(newProgress)
			progress = newProgress
	get:
		return progress

@export var randomSeed:int = 0

func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	greatAnimationPlayer.play("GreatText")
	meshDisintegrator.randomSeed = randomSeed
	meshDisintegrator.textOverride = text
