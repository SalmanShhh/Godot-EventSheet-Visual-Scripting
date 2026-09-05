# Pack builder - music_track_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## MusicTrackResource: one song of a game as a file.
##
## A track is not just an audio file. It is the file, plus the layers that come up as the danger
## rises, plus the tempo the rest of the game listens for, plus where the loop goes back to. Every
## game keeps those four facts somewhere - in a dictionary in a script, in four exported variables
## on a node, or in somebody's head - and every game keeps them somewhere different.
##
## A track is those facts written down ONCE, in a file the game owns. The Music director plays one
## with a single row - Play "forest" - and reads its tempo for the beat triggers, so a rhythm lane
## needs no numbers typed into it anywhere.
##
## THE PACK SHIPS NO TRACKS. There is no dropdown of named songs in the editor and the plugin has
## no idea which music a game holds: a track is an ordinary resource file, made where you keep your
## music, named whatever you name it, and edited in the Inspector like anything else.
##
## The layers are a plain Dictionary of name to stream rather than a resource class per layer,
## because a layer is data a person reads and edits: `{"drums": preload("res://music/drums.ogg")}`
## says the whole of one layer in a form that survives being copied into a message. The director
## builds them into ONE AudioStreamSynchronized when the track starts, which is what stops them
## drifting apart after a pause.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "MusicTrackResource"
	sheet.class_description = "One song of a game as a file: the stream, the layers that fade in over it, the tempo the beat triggers count on, and where the loop goes back to. Play it with the Music director's Play row. It is your file - rename it, retune it in the Inspector, share it."
	sheet.variables = {
		"track_name": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "What the track answers to. The Play row looks a name up as a file in the director's Music Folder, so a file called forest.tres is played by Play \"forest\" with nothing else set up, and this name is what Current Track reads back.",
				"header": "Track", "header_color": "#7c9cf5",
				"info": "The stream is the song. Layers are extra streams that ride on top of it, silent until a Fade Layer row brings one up."}},
		"stream": {"type": "AudioStream", "default": null, "exported": true,
			"attributes": {"tooltip": "The song itself. Set the file's own loop in the Import panel if you want it to repeat."}},
		"layers": {"type": "Dictionary", "default": {}, "exported": true,
			"attributes": {"tooltip": "The extra streams that ride on top of the song, by name: {\"drums\": the drums stream, \"strings\": the strings stream}. They all start silent; Fade Layer brings one up. Every layer must be the same length as the song, because they are played as one synchronized stream."}},
		"bpm": {"type": "float", "default": 120.0, "exported": true,
			"attributes": {"tooltip": "The tempo in beats per minute. On Beat, On Bar, Beat Number and the rest are all counted from this.",
				"header": "Beat", "header_color": "#e8a33d",
				"range": {"min": "1", "max": "400", "step": "0.1"}}},
		"beat_offset": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Seconds from the start of the file to the first beat, for a song that does not begin exactly on one."}},
		"beats_per_bar": {"type": "int", "default": 4, "exported": true,
			"attributes": {"tooltip": "How many beats a bar holds - 4 for most music, 3 for a waltz. On Bar and Position In Bars read it.", "range": {"min": "1", "max": "32", "step": "1"}}},
		"loop_from": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Seconds into the file where the loop starts. A song is played from its beginning the first time it is asked for and from here every time after, so an intro is heard whole when the level opens and skipped when the song comes back.",
				"header": "Loop", "header_color": "#5fb37a"}},
		"loop_to": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Seconds into the file where the loop ends. Set it past Loop From and the director sends the song back to Loop From when it gets there; leave it at 0 and the file plays to its end, looping only if the stream itself is set to in the Import panel."}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/music_track_resource/music_track_resource")
