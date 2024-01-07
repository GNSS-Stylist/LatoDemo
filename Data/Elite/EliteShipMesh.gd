@tool

# Can be used to create an Elite-ship from vertices (vertexArray of Vector3's)
# and list to those as EliteFace-instances (faceArray)

class_name EliteShipMesh

static func createMesh(vertexArray:Array, faceArray:Array):
	var mesh:ArrayMesh = ArrayMesh.new()

	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var centerPoints = PackedFloat32Array()
	
	for faceIndex in range(faceArray.size()):
		var uv = Vector2(faceArray[faceIndex].color1, faceArray[faceIndex].color2)
		var centerPoint:Vector3 = Vector3.ZERO
		
		if (faceArray[faceIndex].centerPoint == Vector3.ZERO):
			# If centerpoint is zero, calculate is as an average of the vertices
			for i in range(faceArray[faceIndex].vertices.size()):
				centerPoint += vertexArray[faceArray[faceIndex].vertices[i]]
			centerPoint /= faceArray[faceIndex].vertices.size()
		else:
			centerPoint = faceArray[faceIndex].centerPoint
		
		var normal = (vertexArray[faceArray[faceIndex].vertices[2]] - 
				vertexArray[faceArray[faceIndex].vertices[0]]).cross(
					vertexArray[faceArray[faceIndex].vertices[1]] -
					vertexArray[faceArray[faceIndex].vertices[0]]).normalized()

		for i in range(1, faceArray[faceIndex].vertices.size() - 1):
			# Create face as "triangle fan"
			vertices.push_back(vertexArray[faceArray[faceIndex].vertices[0]])
			vertices.push_back(vertexArray[faceArray[faceIndex].vertices[i]])
			vertices.push_back(vertexArray[faceArray[faceIndex].vertices[i + 1]])
			for iii in range(3):
				normals.push_back(normal)
				uvs.push_back(uv)
				centerPoints.push_back(centerPoint.x)
				centerPoints.push_back(centerPoint.y)
				centerPoints.push_back(centerPoint.z)
				centerPoints.push_back(faceIndex)

	var arrayMeshArrays = []
	arrayMeshArrays.resize(ArrayMesh.ARRAY_MAX)
	arrayMeshArrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arrayMeshArrays[ArrayMesh.ARRAY_NORMAL] = normals
	arrayMeshArrays[ArrayMesh.ARRAY_TEX_UV] = uvs
	arrayMeshArrays[ArrayMesh.ARRAY_CUSTOM0] = centerPoints

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrayMeshArrays, [], {}, 
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT))
	
	return mesh
