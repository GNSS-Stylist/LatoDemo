@tool
extends Node3D

@export var scrollTextFilename:String
@export var createAheadMargin:float = 2
@export var destroyAfterMargin:float = 2
@export var scrollPos:float = -1000
@export var smoothMeshLowLimit:float = -1
@export var smoothMeshHighLimit:float = 1

# Cannot @export custom types. Therefore these are "split":
@export var styleNames:Array[String]
@export var styleBaseTextMeshes:Array[TextMesh]
@export var styleLineHeights:Array[float]
@export var styleDepths:Array[float]

var picPlateTexturesChanged:bool = false
@export var picPlateTextures:Array[Texture2D]:
	set(newArray):
		# Material is shared with ScrollerPicPlates so need to set this only once
		picPlateTextures = newArray

		# So setting these here doesn't work -> use a flag instead
#		$ScrollerPicPlate.disintegratedMesh.material_override.set_shader_parameter("albedoTextures", picPlateTextures)
#		$ScrollerPicPlate.solidMesh.material_override.set_shader_parameter("albedoTextures", picPlateTextures)
		picPlateTexturesChanged = true
	get:
		return picPlateTextures

var picPlateScreenCloneTextureChanged:bool = false
@export var picPlateScreenCloneTexture:Texture2D:
	set(newTexture):
		picPlateScreenCloneTexture = newTexture
	
		# So setting this here doesn't work -> use a flag instead
		picPlateScreenCloneTextureChanged = true
	get:
		return picPlateScreenCloneTexture

@export var dbgForceRegen:bool:
	set(force):
		if (force):
			if scrollTextFilename.length() > 0:
				# Try to load file at this phase only if defined.
				loadFile(scrollTextFilename)

			# Just clear all items in pool. They will be regenerated on next _process
			for i in range(scrollerTextLinePoolSize):
				var poolItem:ScrollerTextLinePoolItem = scrollerTextLinePool[i]
				poolItem.active = false
				poolItem.scrollerTextLineItem.textOverride = ""
				poolItem.scrollerTextLineItem.visible = false
				poolItem.scrollerTextLineItem.process_mode = Node.PROCESS_MODE_DISABLED
	get:
		return false

@export var disintegrationMinY_Appear:float = -1.5
@export var disintegrationMaxY_Appear:float = -1
@export var disintegrationMinY_Disappear:float = 0.5
@export var disintegrationMaxY_Disappear:float = 1

var ScrollerTextLine = preload("res://Data/Scroller/ScrollerTextLine.tscn")

const scrollerTextLinePoolSize:int = 20
var scrollerTextLinePool:Array[ScrollerTextLinePoolItem]

class SourceTextLine:
	var string:String
	var style:int
#	var posY:float
	var posX:float
#	var scalingXCenterPoint:float

class ScrollerTextLinePoolItem:
	var active:bool
	var yCoord:float
	var scrollerTextLineItem:ScrollerTextLine
	var textLine:SourceTextLine

var sourceTextLines = {}	# Key = yCoord, Value = SourceTextLine
var sourceTextLineKeys = []	# YCoords

func _process(delta):
	if (picPlateTexturesChanged):
		$ScrollerPicPlate1.disintegratedMesh.material_override.set_shader_parameter("albedoTextures", picPlateTextures)
		$ScrollerPicPlate1.solidMesh.material_override.set_shader_parameter("albedoTextures", picPlateTextures)
		picPlateTexturesChanged = false
		
	if (picPlateScreenCloneTextureChanged):
		$ScrollerPicPlate1.disintegratedMesh.material_override.set_shader_parameter("screenCloneAlbedoTexture", picPlateScreenCloneTexture)
		$ScrollerPicPlate1.solidMesh.material_override.set_shader_parameter("screenCloneAlbedoTexture", picPlateScreenCloneTexture)
		picPlateScreenCloneTextureChanged = false

	var highestYCoord:float = scrollPos - destroyAfterMargin
	var lowestYCoord:float = scrollPos + createAheadMargin
	
	# Hide and mark reusable obsolete lines
#	for poolItem in scrollerTextLinePool:
	for i in range(scrollerTextLinePoolSize):
		var poolItem:ScrollerTextLinePoolItem = scrollerTextLinePool[i]
		
		if (poolItem.active):
			if (((poolItem.yCoord < (scrollPos - destroyAfterMargin)) ||
					(poolItem.yCoord > (scrollPos + createAheadMargin)))):
				
				print("delete: ", i, ":", poolItem.textLine.string)		
				
				poolItem.active = false
				poolItem.scrollerTextLineItem.visible = false
				poolItem.scrollerTextLineItem.process_mode = Node.PROCESS_MODE_DISABLED
			else:
				highestYCoord = max(poolItem.yCoord, highestYCoord)
				lowestYCoord = min(poolItem.yCoord, lowestYCoord)
				
				# Switch to smooth mesh if it's not in "disintegrating state"
				var aabbY1:float = poolItem.scrollerTextLineItem.smoothMesh.get_aabb().position.y
				var aabbY2:float = poolItem.scrollerTextLineItem.smoothMesh.get_aabb().end.y
				
				#print(poolItem.scrollerTextLineItem.smoothMesh.get_aabb())
				
				if ((scrollPos + poolItem.scrollerTextLineItem.basePosY + aabbY1 > smoothMeshLowLimit) &&
						(scrollPos + poolItem.scrollerTextLineItem.basePosY + aabbY2 < smoothMeshHighLimit)):
					poolItem.scrollerTextLineItem.shownMesh = poolItem.scrollerTextLineItem.ShownMesh.SMOOTH
					#print("Smooth operator")
				else:
					poolItem.scrollerTextLineItem.shownMesh = poolItem.scrollerTextLineItem.ShownMesh.DISINTEGRATED

	if (highestYCoord < lowestYCoord):
		highestYCoord = lowestYCoord

	# "Recreate" new lines ("disappearing", not doing anything if not rewinding)
	var keyIndex:int = sourceTextLineKeys.bsearch(lowestYCoord) - 1
#	print("Disappearing, keyindex ", keyIndex)
	while (keyIndex >= 0):
		var yCoord = sourceTextLineKeys[keyIndex]
#		print("ycoord ", yCoord)
		if ((yCoord < (scrollPos - destroyAfterMargin)) ||
				(yCoord > (scrollPos + createAheadMargin))):
			break
		else:
			addScrollLine(sourceTextLines[sourceTextLineKeys[keyIndex]], sourceTextLineKeys[keyIndex])
		keyIndex -= 1

	# "Recreate" new lines ("forthcoming")
	keyIndex = sourceTextLineKeys.bsearch(highestYCoord, false)
#	print("Appearing, keyindex ", keyIndex)
	while (keyIndex < sourceTextLineKeys.size()):
		var yCoord = sourceTextLineKeys[keyIndex]
		if ((yCoord < (scrollPos - destroyAfterMargin)) ||
				(yCoord > (scrollPos + createAheadMargin))):
			break
		else:
			addScrollLine(sourceTextLines[sourceTextLineKeys[keyIndex]], sourceTextLineKeys[keyIndex])
		keyIndex += 1
	
	# Update scroll y position and appearing/disappearing limits (global uniforms)
	RenderingServer.global_shader_parameter_set("endScrollerYPos", scrollPos)
	RenderingServer.global_shader_parameter_set("endScrollerDisintegrationMinY_Appear", disintegrationMinY_Appear)
	RenderingServer.global_shader_parameter_set("endScrollerDisintegrationMaxY_Appear", disintegrationMaxY_Appear)
	RenderingServer.global_shader_parameter_set("endScrollerDisintegrationMinY_Disappear", disintegrationMinY_Disappear)
	RenderingServer.global_shader_parameter_set("endScrollerDisintegrationMaxY_Disappear", disintegrationMaxY_Disappear)
#	print ("endScrollerYPos: ", ProjectSettings.get_setting("shader_globals/endScrollerYPos"))


func addScrollLine(line:SourceTextLine, yCoord:float):
	# find unused item in the pool
	
	print("Adding scroll line ", line.string)
	
	for i in range(scrollerTextLinePoolSize):
		if (!scrollerTextLinePool[i].active):
			var poolItem:ScrollerTextLinePoolItem = scrollerTextLinePool[i]
			poolItem.yCoord = yCoord
			poolItem.textLine = line
			poolItem.active = true
			
			poolItem.scrollerTextLineItem.sourceTextMesh = styleBaseTextMeshes[line.style]
			poolItem.scrollerTextLineItem.textOverride = line.string
			poolItem.scrollerTextLineItem.transform.origin.x = line.posX
			poolItem.scrollerTextLineItem.depth = styleDepths[line.style]

			if (styleDepths[line.style] == 0):
				poolItem.scrollerTextLineItem.disintegrationMethod = MeshDisintegratorBase.DisintegrationMethod.PLANAR_2D
			else:
				poolItem.scrollerTextLineItem.disintegrationMethod = MeshDisintegratorBase.DisintegrationMethod.PLANAR_CUT

			poolItem.scrollerTextLineItem.basePosY = -yCoord
			
			poolItem.scrollerTextLineItem.visible = true
			poolItem.scrollerTextLineItem.process_mode = Node.PROCESS_MODE_INHERIT
			return

	print("Sroller text line overflow!!!")


func _ready():
	$ScrollerPicPlate1.disintegratedMesh.material_override.set_shader_parameter("albedoTextures", picPlateTextures)
	$ScrollerPicPlate1.solidMesh.material_override.set_shader_parameter("albedoTextures", picPlateTextures)

	if ((styleNames.size() != styleBaseTextMeshes.size()) ||
			(styleNames.size() != styleLineHeights.size()) ||
			(styleNames.size() != styleDepths.size())):
		print("Style definitions are broken in the scroller! Unable to load scrolltext...")
		return
	
	if scrollTextFilename.length() > 0:
		# Try to load file at this phase only if defined.
		loadFile(scrollTextFilename)
	
	for i in range(scrollerTextLinePoolSize):
		var newItem:ScrollerTextLinePoolItem = ScrollerTextLinePoolItem.new()
		newItem.active = false
		newItem.scrollerTextLineItem = ScrollerTextLine.instantiate()
		newItem.textLine = SourceTextLine.new()
		scrollerTextLinePool.push_back(newItem)
		add_child(newItem.scrollerTextLineItem)
	
	
func loadFile(fileName):
	sourceTextLines.clear()
	sourceTextLineKeys = []

	var file = FileAccess.open(fileName, FileAccess.READ)

	if (!file):
		print("Can't open file " + fileName)
		return
	var line:String
	var posX:float = 0
	var posY:float = 0
	var styleIndex = 0
	
	while not file.eof_reached():
		line = file.get_line()
		var lineUpperCase = line.to_upper()
		
		if (lineUpperCase.begins_with("!STYLE:\t")):
			var subStrings:PackedStringArray = lineUpperCase.split("\t")
			if (subStrings.size() < 2):
				print("ScrollText: Style definition not valid! Skipping...")
				continue
			
			styleIndex = 0
			
			var styleNameRequest = subStrings[1]
			
			while (styleIndex < styleNames.size()):
				if (styleNameRequest == styleNames[styleIndex]):
					break
				styleIndex += 1
			
			if (styleIndex == styleNames.size()):
				print("Style ", styleNameRequest, " not found. Using ", styleNames[0])
				styleIndex = 0
		
		elif (lineUpperCase.begins_with("!POSX:\t")):
			var subStrings:PackedStringArray = lineUpperCase.split("\t")
			posX = subStrings[1].to_float()
		
		else:
			var newSourceTextLine:SourceTextLine = SourceTextLine.new()
			newSourceTextLine.string = line
			newSourceTextLine.posX = posX
			newSourceTextLine.style = styleIndex
			sourceTextLines[posY] = newSourceTextLine

			posY += styleLineHeights[styleIndex]

	sourceTextLineKeys = sourceTextLines.keys()
