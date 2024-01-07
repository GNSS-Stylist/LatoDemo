@tool

# Defines one face of an Elite-ship using vertices.
# (faces can have more than 3 vertices)
# This is used to create a mesh with EliteShipMesh

class_name EliteFace

var vertices = []		# Vertices of the face as indices
var color1:int			# First color to paint the face
var color2:int			# Second color to paint the face
var centerPoint:Vector3
func _init(vertices_p:Array, color1_p:int, color2_p:int, centerPoint_p:Vector3):
	self.vertices = vertices_p
	self.color1 = color1_p
	self.color2 = color2_p
	self.centerPoint = centerPoint_p
