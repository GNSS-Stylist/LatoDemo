extends Node3D

@export var eventHorizonRadius:float = 0.5
@export var gravity:float = 0.5
@export var radius:float = 0.5
@export var shader:Shader

# Called when the node enters the scene tree for the first time.
func _ready():
	$Visibles/DistorterMesh.material_override = ShaderMaterial.new()
	$Visibles/DistorterMesh.material_override.shader = shader

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	$Visibles/DistorterMesh.material_override.set_shader_param("eventHorizonRadius", eventHorizonRadius)
	$Visibles/DistorterMesh.material_override.set_shader_param("gravity", gravity)
	
	
	
	
	
	
	
	
	
	
	
	# This is needed due to unorthodox way to billboard
	# ( see shader )
	global_transform.basis = Basis.IDENTITY * radius * 2
	
	# Scale event horizon sphere
	$Visibles/EventHorizonSphere.basis = Basis.IDENTITY * (eventHorizonRadius / 2)
