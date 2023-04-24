@tool
extends Node3D

@export var scrollTextFilename:String
@export var createAheadMargin:float = 2
@export var destroyAfterMargin:float = 2
@export var scrollPos:float = -1

# Cannot @export custom types. Therefore these are "split":
@export var styleNames:Array[String]
@export var styleBaseTextMeshes:Array[TextMesh]
@export var styleLineHeights:Array[float]

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
	var highestYCoord:float = scrollPos - destroyAfterMargin
	var lowestYCoord:float = scrollPos + createAheadMargin
	
	# Hide and mark reusable obsolete lines
	for i in range(scrollerTextLinePoolSize):
		var poolItem:ScrollerTextLinePoolItem = scrollerTextLinePool[i]
		
		if (poolItem.active):
			if (((poolItem.yCoord < (scrollPos - destroyAfterMargin)) ||
					(poolItem.yCoord > (scrollPos + createAheadMargin)))):
				
				print("delete: ", poolItem.textLine.string)		
				
				poolItem.active = false
				poolItem.scrollerTextLineItem.visible = false
				poolItem.scrollerTextLineItem.process_mode = Node.PROCESS_MODE_DISABLED
			else:
				highestYCoord = max(poolItem.yCoord, highestYCoord)
				lowestYCoord = min(poolItem.yCoord, lowestYCoord)
	
	# "Recreate" new lines ("disappearing", not doing anything if not rewinding)
	var keyIndex:int = sourceTextLineKeys.bsearch(lowestYCoord) - 1
#	print("keyindex ", keyIndex)
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
	while (keyIndex < sourceTextLineKeys.size()):
		var yCoord = sourceTextLineKeys[keyIndex]
		if ((yCoord < (scrollPos - destroyAfterMargin)) ||
				(yCoord > (scrollPos + createAheadMargin))):
			break
		else:
			addScrollLine(sourceTextLines[sourceTextLineKeys[keyIndex]], sourceTextLineKeys[keyIndex])
		keyIndex += 1
	
	# Update scroll y position (global uniform)
	# Not working...:
	#ProjectSettings.set_setting("shader_globals/endScrollerYPos", scrollPos)
	RenderingServer.global_shader_parameter_set("endScrollerYPos", scrollPos)
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
			poolItem.scrollerTextLineItem.disintegratedMesh.set_instance_shader_parameter("basePosY", -yCoord)
			
			poolItem.scrollerTextLineItem.visible = true
			poolItem.scrollerTextLineItem.process_mode = Node.PROCESS_MODE_INHERIT
			return

	print("Sroller text line overflow!!!")


func _ready():
	if ((styleNames.size() != styleBaseTextMeshes.size()) ||
			(styleNames.size() != styleLineHeights.size())):
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
			var subStrings:Array[String] = lineUpperCase.split("\t")
			posX = subStrings[1].to_float()
		
		else:
			var newSourceTextLine:SourceTextLine = SourceTextLine.new()
			newSourceTextLine.string = line
			newSourceTextLine.posX = posX
			newSourceTextLine.style = styleIndex
			sourceTextLines[posY] = newSourceTextLine

			posY += styleLineHeights[styleIndex]

	sourceTextLineKeys = sourceTextLines.keys()
