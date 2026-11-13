# Godot EventSheets - the words a process-mode write wears, by what the object is.
#
# Disabled stops a node's per-frame work (measured in a running game: a Timer stops counting, an
# AnimationPlayer stops advancing, a RigidBody2D stops falling, a Tween bound to the node stops), and
# the sheet says it the way a reader says it of that kind of thing: a behaviour or a class of the
# project is TURNED OFF and ON, a node that plays, counts or simulates is PAUSED and RESUMED, and
# anything else keeps the plain "Set disabled". Only the words change - the line written is the same -
# and a picked Pause Node row and a hand-written process_mode line read the same.
@tool
class_name ProcessWordsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "process_words_test"


static func run() -> bool:
	var passed: bool = _the_verbs()
	passed = _the_sentences() and passed
	passed = _the_lines_are_unchanged() and passed
	return passed


static func _the_verbs() -> bool:
	return SUPPORT.pins(NAME, [
		["a class of the project is turned off", EventSheetSentence.process_mode_verb("JetpackBehavior", "PROCESS_MODE_DISABLED"), "Turn off"],
		["and turned back on", EventSheetSentence.process_mode_verb("JetpackBehavior", "PROCESS_MODE_INHERIT"), "Turn on"],
		["a timer is paused", EventSheetSentence.process_mode_verb("Timer", "PROCESS_MODE_DISABLED"), "Pause"],
		["and resumed", EventSheetSentence.process_mode_verb("Timer", "PROCESS_MODE_INHERIT"), "Resume"],
		["an animation player is paused", EventSheetSentence.process_mode_verb("AnimationPlayer", "PROCESS_MODE_DISABLED"), "Pause"],
		["an animation tree is paused too", EventSheetSentence.process_mode_verb("AnimationTree", "PROCESS_MODE_DISABLED"), "Pause"],
		["a rigid body is paused", EventSheetSentence.process_mode_verb("RigidBody2D", "PROCESS_MODE_DISABLED"), "Pause"],
		["an audio player keeps the plain words: its sound does not stop", EventSheetSentence.process_mode_verb("AudioStreamPlayer", "PROCESS_MODE_DISABLED"), ""],
		["a character body keeps the plain words", EventSheetSentence.process_mode_verb("CharacterBody2D", "PROCESS_MODE_DISABLED"), ""],
		["a plain node keeps the plain words", EventSheetSentence.process_mode_verb("Node", "PROCESS_MODE_DISABLED"), ""],
		["an object of no known class keeps the plain words", EventSheetSentence.process_mode_verb("", "PROCESS_MODE_DISABLED"), ""],
		["the other three modes are not on and off", EventSheetSentence.process_mode_verb("Timer", "PROCESS_MODE_ALWAYS"), ""],
	])


const CONTEXT: Dictionary = {
	"self_object": "System",
	"script_object": "Player",
	"owner": "Player",
	"signals": {},
	"engine_properties": {"position": true, "visible": true},
	"object_classes": {"Player": "CharacterBody2D", "Jetpack": "JetpackBehavior", "Clock": "Timer", "Music": "AudioStreamPlayer"}
}


static func _read(code: String) -> String:
	var result: Dictionary = EventSheetSentence.statement(code, CONTEXT)
	if result.is_empty():
		return ""
	var text: String = ""
	for segment: Variant in (result.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return "%s ▸ %s" % [str(result.get("object", "")), text]


static func _the_sentences() -> bool:
	return SUPPORT.pins(NAME, [
		["a behaviour is turned off", _read("$Jetpack.process_mode = Node.PROCESS_MODE_DISABLED"), "Jetpack ▸ Turn off"],
		["a behaviour is turned on", _read("$Jetpack.process_mode = Node.PROCESS_MODE_INHERIT"), "Jetpack ▸ Turn on"],
		["a timer is paused", _read("$Clock.process_mode = Node.PROCESS_MODE_DISABLED"), "Clock ▸ Pause"],
		["a timer is resumed", _read("$Clock.process_mode = Node.PROCESS_MODE_INHERIT"), "Clock ▸ Resume"],
		["a character body keeps its words", _read("process_mode = PROCESS_MODE_DISABLED"), "Player ▸ Set disabled"],
		["a sound keeps its words", _read("$Music.process_mode = Node.PROCESS_MODE_DISABLED"), "Music ▸ Set disabled"],
		["the other modes keep theirs", _read("$Clock.process_mode = Node.PROCESS_MODE_ALWAYS"), "Clock ▸ Set always active"],
	])


## Words only: the rows write what they always wrote.
static func _the_lines_are_unchanged() -> bool:
	var pause: ACEDescriptor = ACERegistry.find_descriptor("Core", "NodePause")
	var resume: ACEDescriptor = ACERegistry.find_descriptor("Core", "NodeResume")
	return SUPPORT.pins(NAME, [
		["Pause Node writes Disabled", pause.codegen_template.contains("process_mode = Node.PROCESS_MODE_DISABLED"), true],
		["Unpause Node writes Inherit", resume.codegen_template.contains("process_mode = Node.PROCESS_MODE_INHERIT"), true],
	])
