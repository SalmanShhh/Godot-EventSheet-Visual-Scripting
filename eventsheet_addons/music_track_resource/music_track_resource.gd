## @ace_version(1.0.0)
@icon("res://eventsheet_addons/music_track_resource/icon.svg")
class_name MusicTrackResource
extends Resource
## One song of a game as a file: the stream, the layers that fade in over it, the tempo the beat triggers count on, and where the loop goes back to. Play it with the Music director's Play row. It is your file - rename it, retune it in the Inspector, share it.

# @inspector_header Track #7c9cf5
# @inspector_info The stream is the song. Layers are extra streams that ride on top of it, silent until a Fade Layer row brings one up.
## Name this track is played by.
@export var track_name: String = ""
## The song itself. Set the file's own loop in the Import panel if you want it to repeat.
@export var stream: AudioStream = null
## Extra streams over the song by name; all start silent and match its length.
@export var layers: Dictionary = {}
# @inspector_header Beat #e8a33d
## The tempo in beats per minute. On Beat, On Bar, Beat Number and the rest are all counted from this.
@export_range(1, 400, 0.1) var bpm: float = 120.0
## Seconds from the start of the file to the first beat, for a song that does not begin exactly on one.
@export var beat_offset: float = 0.0
## How many beats a bar holds - 4 for most music, 3 for a waltz. On Bar and Position In Bars read it.
@export_range(1, 32, 1) var beats_per_bar: int = 4
# @inspector_header Loop #5fb37a
## Seconds into the file where the loop starts.
@export var loop_from: float = 0.0
## Seconds into the file where the loop ends; 0 plays to the end.
@export var loop_to: float = 0.0
