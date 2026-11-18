extends Node

enum Mood { CALM, ALERT, PANIC }

signal cue_played(cue: String)

const JumpSfx := preload("res://tools/doc_shots/fixtures/sfx/jump.wav")
const LandSfx := preload("res://tools/doc_shots/fixtures/sfx/land.wav")

var mood: Mood = Mood.CALM


#region Setup
func _ready() -> void:
	mood = Mood.CALM
#endregion
