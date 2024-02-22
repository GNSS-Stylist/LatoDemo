extends Panel

@onready var node_Keys:CanvasItem = get_node("../Panel_Keys")
@onready var chkBox_ShowKeys:CheckBox = $CheckBox_ShowKeys

@onready var node_CurrentCameraTransform:CanvasItem = get_node("../Panel_CurrentCameraTransform")
@onready var chkBox_ShowCurrentCameraTransform:CheckBox = $CheckBox_ShowCurrentCameraTransform

@onready var node_StatusBar:CanvasItem = get_node("../Panel_Bottom")
@onready var chkBox_ShowStatusBar:CheckBox = $CheckBox_ShowStatusBar

@onready var chkBox_ShowDebugShips:CheckBox = $CheckBox_ShowDebugShips
var debugShipsWereVisible:bool = false

@onready var chkBox_ProcessActionKeys = $CheckBox_ProcessActionKeys

@onready var OptionButton_TrackReplayerShip:OptionButton = $OptionButton_TrackReplayerShip
var lastTrackReplayerShip = 0

func _ready():
	if (!Engine.is_editor_hint()):
		# Clearing these when running the demo as these may be set
		# on the editor for debugging purposes
		setEliteDebugShipVisibility(false)
		setEliteTrackReplayerShip(0)

func _process(delta):
	if (Input.is_action_just_pressed("show_help")):
		self.visible = !self.visible
		if (self.visible):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	chkBox_ProcessActionKeys.set_pressed_no_signal(Global.processActionKeys)
	
	node_Keys.visible = chkBox_ShowKeys.button_pressed
	node_CurrentCameraTransform.visible = chkBox_ShowCurrentCameraTransform.button_pressed
	node_StatusBar.visible = chkBox_ShowStatusBar.button_pressed
	
	if (chkBox_ShowDebugShips.button_pressed != debugShipsWereVisible):
		debugShipsWereVisible = chkBox_ShowDebugShips.button_pressed
		setEliteDebugShipVisibility(chkBox_ShowDebugShips.button_pressed)
	
	if (OptionButton_TrackReplayerShip.get_selected_id() != lastTrackReplayerShip):
		lastTrackReplayerShip = OptionButton_TrackReplayerShip.get_selected_id()
		setEliteTrackReplayerShip(OptionButton_TrackReplayerShip.get_selected_id())
	
func setEliteDebugShipVisibility(visible_p:bool):
	get_node("../../Elite/ShipDrawMeshes/CobraMKIII/DebugCobra").visible = visible_p
	get_node("../../Elite/ShipDrawMeshes/Python/DebugPython").visible = visible_p
	get_node("../../Elite/ShipDrawMeshes/Thargoid/DebugThargoid").visible = visible_p
	get_node("../../Elite/ShipDrawMeshes/Viper/DebugViper").visible = visible_p
	get_node("../../Elite/ShipDrawMeshes/FerDeLance/DebugFerDeLance").visible = visible_p

func setEliteTrackReplayerShip(ship:int):
	get_node("../../Elite/DebugShipTrackReplayer/CobraMkIII").visible = false
	get_node("../../Elite/DebugShipTrackReplayer/Python").visible = false
	get_node("../../Elite/DebugShipTrackReplayer/Viper").visible = false
	get_node("../../Elite/DebugShipTrackReplayer/Thargoid").visible = false
	get_node("../../Elite/DebugShipTrackReplayer/FerDeLance").visible = false
	get_node("../../Elite/DebugShipTrackReplayer").visible = true

	match (ship):
		[0, _]:
			get_node("../../Elite/DebugShipTrackReplayer").visible = false
		1:
			get_node("../../Elite/DebugShipTrackReplayer/CobraMkIII").visible = true
		2:
			get_node("../../Elite/DebugShipTrackReplayer/Python").visible = true
		3:
			get_node("../../Elite/DebugShipTrackReplayer/Viper").visible = true
		4:
			get_node("../../Elite/DebugShipTrackReplayer/Thargoid").visible = true
		5:
			get_node("../../Elite/DebugShipTrackReplayer/FerDeLance").visible = true

func _on_button_close_pressed():
	visible = false

func _on_check_box_process_action_keys_toggled(button_pressed):
	Global.processActionKeys = button_pressed
