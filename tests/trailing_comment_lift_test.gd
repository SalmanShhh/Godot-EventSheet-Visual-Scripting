# A `#` note at the end of a line stays with its line: on a statement it is the action's comment, on a
# declaration it is the variable's note, on an `if` line it is the condition's. The spacing before the `#`
# is kept as written, and the file saves back byte for byte.
@tool
class_name TrailingCommentLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "trailing_comment_lift_test"
const SOURCE := """extends Node2D

const MOTION_SPEED = 160 # Pixels/second.
var screen_size: Vector2 # Size of the game window.
@export var speed = 400	# How fast.


func _ready() -> void:
	hide() # one space
	show()  # two spaces
	if alive: # player only
		queue_free()
	elif other:  # the second
		hide()
"""


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE)
	var variables: Dictionary = {}
	for row: Variant in sheet.events:
		if row is LocalVariable:
			variables[(row as LocalVariable).name] = row
	var motion: LocalVariable = variables.get("MOTION_SPEED") as LocalVariable
	ok = SUPPORT.check(NAME, "a noted constant opens as a variable row", motion != null, true) and ok
	ok = SUPPORT.check(NAME, "the note rides on the row", motion.trailing_comment if motion != null else "", "Pixels/second.") and ok
	var screen: LocalVariable = variables.get("screen_size") as LocalVariable
	ok = SUPPORT.check(NAME, "a declaration with no value and a note opens as a row", screen != null, true) and ok
	ok = SUPPORT.check(NAME, "the spacing before the # is kept", screen.trailing_marker if screen != null else "", " # ") and ok
	var speed: LocalVariable = variables.get("speed") as LocalVariable
	ok = SUPPORT.check(NAME, "a tab before the # is kept", speed.trailing_marker if speed != null else "", "\t# ") and ok
	var actions: Array = []
	var conditions: Array = []
	for row: Variant in sheet.events:
		if row is EventRow:
			actions.append_array((row as EventRow).actions)
			conditions.append_array((row as EventRow).conditions)
	var comments: PackedStringArray = PackedStringArray()
	for action: Variant in actions:
		if action is ACEAction:
			comments.append((action as ACEAction).comment)
	ok = SUPPORT.check(NAME, "statement notes become action comments", comments.slice(0, 2), PackedStringArray(["one space", "two spaces"])) and ok
	var condition_notes: PackedStringArray = PackedStringArray()
	for condition: Variant in conditions:
		if condition is ACECondition and not (condition as ACECondition).comment.is_empty():
			condition_notes.append((condition as ACECondition).comment)
	ok = SUPPORT.check(NAME, "the notes on if and elif lines become condition notes", condition_notes, PackedStringArray(["player only", "the second"])) and ok
	ok = SUPPORT.check(NAME, "the file is written back byte for byte", SUPPORT.reemit(SOURCE, "user://trailing_comment_out.gd"), SOURCE) and ok
	return ok
