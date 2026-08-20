# S11 / S12 / S13 / S14 - the sprite, UI, sound and juice readings, and the pattern each of them
# claims.
#
# Every check pins the exact TEXT a row shows, and the pattern id the reading hands to the registry.
@tool
class_name SpriteSoundJuiceReadingTest
extends RefCounted

## The objects these scripts declare, the way an opened file's head declares them.
static var CONTEXT: Dictionary = {
	"self_object": "System",
	"script_object": "Player",
	"self_class": "CharacterBody2D",
	"object_classes": {
		"sprite": "Sprite2D",
		"anim": "AnimationPlayer",
		"anim_tree": "AnimationTree",
		"sfx": "AudioStreamPlayer",
		"music": "AudioStreamPlayer",
		"camera": "Camera2D",
		"resume_button": "Button",
		"game_over": "AcceptDialog"
	}
}


static func run() -> bool:
	var passed: bool = true
	passed = _check_sprite_words() and passed
	passed = _check_ui_words() and passed
	passed = _check_sound_words() and passed
	passed = _check_juice_words() and passed
	passed = _check_patterns() and passed
	passed = _check_refusals() and passed
	return passed


## S11 - mirrored, flipped, frame, speed, image, blend and travel.
static func _check_sprite_words() -> bool:
	var passed: bool = _pin("a mirror driven by a test says the test",
		_reading("sprite.flip_h = dir < 0"), "sprite ▸ Set mirrored when dir < 0")
	passed = _pin("a plain mirror is still the plain verb",
		_reading("sprite.flip_h = true"), "sprite ▸ Set mirrored") and passed
	passed = _pin("a vertical flip reads as flipped",
		_reading("sprite.flip_v = true"), "sprite ▸ Set flipped") and passed
	passed = _pin("a frame write is an animation frame",
		_reading("sprite.frame = 3"), "sprite ▸ Set animation frame to 3") and passed
	passed = _pin("a speed scale is the animation's speed",
		_reading("anim.speed_scale = 2.0"), "anim ▸ Set animation speed to 2") and passed
	passed = _pin("a texture write names the file",
		_reading("sprite.texture = load(\"res://hero.png\")"), "sprite ▸ Set image to hero.png") and passed
	# X7 re-homed both of these: an AnimationTree is not an object a reader points at, it is HOW one
	# object animates, so its rows wear the object's own name and its Animation aspect - and a blend
	# tree's playback reads in the State Machine behavior's words rather than in Godot's `travel`.
	passed = _pin("an animation tree parameter is a blend",
		_reading("anim_tree.set(\"parameters/blend_position\", dir)"),
		"Player ▸ Animation ▸ Set blend blend position to dir") and passed
	passed = _pin("a state machine travels",
		_reading("anim_tree[\"parameters/playback\"].travel(\"Hurt\")"),
		"Player ▸ Animation ▸ Go to state \"Hurt\"") and passed
	passed = _pin("an animation player answers is playing",
		_condition_reading("anim.is_playing()"), "anim ▸ Is playing") and passed
	return passed


## S12 - focus, dialogs and the master volume.
static func _check_ui_words() -> bool:
	var passed: bool = _pin("grabbing focus is setting it",
		_reading("resume_button.grab_focus()"), "resume_button ▸ Set focus")
	passed = _pin("a centred popup is a dialog",
		_reading("game_over.popup_centered()"), "game_over ▸ Open centered") and passed
	passed = _pin("the master bus reads as the master volume, 0 to 1",
		_reading("AudioServer.set_bus_volume_db(0, linear_to_db(v))"),
		"Audio ▸ Set master volume to v (0 to 1)") and passed
	passed = _pin("a named bus says its name",
		_reading("AudioServer.set_bus_volume_db(AudioServer.get_bus_index(\"SFX\"), linear_to_db(0.5))"),
		"Audio ▸ Set SFX volume to 50%") and passed
	return passed


## S13 - the sound, its pitch, its bus, its volume and where it plays from.
static func _check_sound_words() -> bool:
	var passed: bool = _pin("a stream write names the sound file",
		_reading("sfx.stream = preload(\"res://jump.wav\")"), "sfx ▸ Set sound to jump.wav")
	passed = _pin("a pitch scale is the pitch",
		_reading("sfx.pitch_scale = randf_range(0.9, 1.1)"),
		"sfx ▸ Set pitch to random number 0.9 to 1.1") and passed
	passed = _pin("a bus write names the bus",
		_reading("sfx.bus = \"SFX\""), "sfx ▸ Set bus to SFX") and passed
	passed = _pin("a linear volume reads as a percentage",
		_reading("music.volume_db = linear_to_db(0.5)"), "music ▸ Set volume to 50%") and passed
	passed = _pin("a decibel volume keeps its unit",
		_reading("music.volume_db = -6.0"), "music ▸ Set volume to -6 dB") and passed
	passed = _pin("a seek reads in seconds",
		_reading("music.seek(12.0)"), "music ▸ Seek to 12 seconds") and passed
	passed = _pin("the play belongs to the player it acts on",
		_reading("sfx.play()"), "sfx ▸ Play sound") and passed
	passed = _pin("an audio player answers is playing",
		_condition_reading("sfx.playing"), "sfx ▸ Is playing") and passed
	return passed


## S14 - the five most copied juice snippets, in the behaviors' words.
static func _check_juice_words() -> bool:
	var passed: bool = _pin("a random camera offset is a shake",
		_reading("camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))"),
		"camera ▸ Shake by s random offset this tick")
	passed = _pin("a base plus a sine is a bob",
		_reading("position.y = base_y + sin(t * 3.0) * 8.0"),
		"Player ▸ Bob y sine · magnitude 8 · 3 per second") and passed
	passed = _pin("a lerp back to one eases the size back",
		_reading("scale = scale.lerp(Vector2.ONE, 10 * delta)"),
		"Player ▸ Ease size back to normal at 10 per second") and passed
	return passed


## Every reading names the pattern it recognised, with the source line as its evidence.
static func _check_patterns() -> bool:
	var passed: bool = _pin("a sprite line claims the sprite pattern",
		_pattern("sprite.frame = 3"), "sprite_animation")
	passed = _pin("a focus line claims the UI pattern",
		_pattern("resume_button.grab_focus()"), "ui") and passed
	passed = _pin("a sound line claims the sound pattern",
		_pattern("sfx.bus = \"SFX\""), "sound") and passed
	passed = _pin("a shake claims the juice pattern",
		_pattern("camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))"), "juice") and passed
	passed = _pin("a shake offers the behavior that could replace it",
		str(EventSheetSentence.statement(
			"camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))", CONTEXT).get("adoptable", "")),
		"juice") and passed
	passed = _pin("the evidence is the line the reading came from",
		", ".join(EventSheetSentence.statement("sprite.frame = 3", CONTEXT).get(
			"evidence", PackedStringArray()) as PackedStringArray), "sprite.frame = 3") and passed
	return passed


## The shapes these readings must NOT claim: an almost-right sentence is worse than the code it
## replaced.
static func _check_refusals() -> bool:
	var passed: bool = _pin("a frame on an unknown object keeps the plain set",
		_reading("thing.frame = 3"), "thing ▸ Set frame to 3")
	passed = _pin("a lopsided shake is not a shake",
		_reading("camera.offset = Vector2(randf_range(-s, s), randf_range(-big, big))"),
		"camera ▸ Set offset to (random number -s to s, random number -big to big)") and passed
	passed = _pin("a lerp somewhere other than normal size is not the ease",
		_reading("scale = scale.lerp(Vector2(2, 2), 10 * delta)"),
		"System ▸ Set scale to scale.lerp((2, 2), 10 * dt)") and passed
	passed = _pin("a mirror set from another flag stays a plain write",
		_reading("sprite.flip_h = muted"), "sprite ▸ Set flip_h to muted") and passed
	passed = _pin("a pitch on something that makes no sound is a plain write",
		_reading("thing.pitch_scale = 2.0"), "thing ▸ Set pitch_scale to 2") and passed
	return passed


static func _reading(code: String) -> String:
	var reading: Dictionary = EventSheetSentence.statement(code, CONTEXT)
	if reading.is_empty():
		return "(no reading)"
	return "%s ▸ %s" % [str(reading.get("object", "")), _segments_text(reading)]


static func _condition_reading(code: String) -> String:
	var reading: Dictionary = EventSheetSentence.condition(code, CONTEXT)
	if reading.is_empty():
		return "(no reading)"
	return "%s ▸ %s" % [str(reading.get("object", "")), _segments_text(reading)]


static func _pattern(code: String) -> String:
	var reading: Dictionary = EventSheetSentence.statement(code, CONTEXT)
	if reading.is_empty():
		reading = EventSheetSentence.condition(code, CONTEXT)
	return str(reading.get("pattern", ""))


static func _segments_text(reading: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in reading.get("segments", []):
		parts.append(str((entry as Dictionary).get("text", "")))
	return "".join(parts)


static func _pin(label: String, actual: String, expected: String) -> bool:
	if actual == expected:
		print("[PASS] sprite_sound_juice_reading_test: %s" % label)
		return true
	print("[FAIL] sprite_sound_juice_reading_test: %s -> %s (expected %s)" % [label, actual, expected])
	return false
