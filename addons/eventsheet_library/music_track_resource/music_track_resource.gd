## @ace_version(1.0.0)
@icon("res://eventsheet_addons/music_track_resource/icon.svg")
class_name MusicTrackResource
extends Resource
## One song of a game as a file: the stream, the layers that fade in over it, the tempo the beat triggers count on, and where the loop goes back to. Play it with the Music director's Play row. It is your file - rename it, retune it in the Inspector, share it.

# @inspector_header Track #7c9cf5
# @inspector_info The stream is the song. Layers are extra streams that ride on top of it, silent until a Fade Layer row brings one up.
## What the track answers to. The Play row looks a name up as a file in the director's Music Folder, so a file called forest.tres is played by Play "forest" with nothing else set up, and this name is what Current Track reads back.
@export var track_name: String = ""
## The song itself. Set the file's own loop in the Import panel if you want it to repeat.
@export var stream: AudioStream = null
## The extra streams that ride on top of the song, by name: {"drums": the drums stream, "strings": the strings stream}. They all start silent; Fade Layer brings one up. Every layer must be the same length as the song, because they are played as one synchronized stream.
@export var layers: Dictionary = {}
# @inspector_header Beat #e8a33d
## The tempo in beats per minute. On Beat, On Bar, Beat Number and the rest are all counted from this.
@export_range(1, 400, 0.1) var bpm: float = 120.0
## Seconds from the start of the file to the first beat, for a song that does not begin exactly on one.
@export var beat_offset: float = 0.0
## How many beats a bar holds - 4 for most music, 3 for a waltz. On Bar and Position In Bars read it.
@export_range(1, 32, 1) var beats_per_bar: int = 4
# @inspector_header Loop #5fb37a
## Seconds into the file where the loop starts. A song is played from its beginning the first time it is asked for and from here every time after, so an intro is heard whole when the level opens and skipped when the song comes back.
@export var loop_from: float = 0.0
## Seconds into the file where the loop ends. Set it past Loop From and the director sends the song back to Loop From when it gets there; leave it at 0 and the file plays to its end, looping only if the stream itself is set to in the Import panel.
@export var loop_to: float = 0.0
