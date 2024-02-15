@tool
extends AudioStreamPlayer

var filteredPlaybackPosition:float = 0
var pausePosition:float = 0
var playbackSpeedDeltaMultiplier:float = 1

# Called when the node enters the scene tree for the first time.
func _ready():
#	print_debug("_ready\t",Time.get_ticks_msec(),"\t",self.get_path())
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# You apparently can't get accurate playback position using 
	filteredPlaybackPosition += delta * playbackSpeedDeltaMultiplier * self.pitch_scale
	if (playing):
		var newRawPlaybackPosition = get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		var posDiff = newRawPlaybackPosition - filteredPlaybackPosition
		
		if (abs(posDiff) > (0.05 * max(1.0, pitch_scale))):	# pitch_scale >1 seems to scale error also
			# Big difference -> hard sync
			print("Audio filtering hard sync. Diff: ", posDiff)
			filteredPlaybackPosition = newRawPlaybackPosition
			playbackSpeedDeltaMultiplier = 1.0
		else:
			playbackSpeedDeltaMultiplier = 1.0 + (posDiff * 0.1)

func getFilteredPlaybackPosition():
	if (playing):
		return min(filteredPlaybackPosition, self.stream.get_length())
	else:
		return pausePosition

func pause():
	pausePosition = get_playback_position()
	filteredPlaybackPosition = pausePosition
	super.stop()

func resume():
	filteredPlaybackPosition = pausePosition
	super.play(pausePosition)

func my_seek(position:float):
	if (playing):
		super.seek(position)
		filteredPlaybackPosition = position
	else:
		pausePosition = min(max(position, 0), stream.get_length())
		filteredPlaybackPosition = pausePosition
		
		
