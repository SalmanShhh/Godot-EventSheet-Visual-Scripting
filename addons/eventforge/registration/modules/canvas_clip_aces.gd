# EventForge module - drawing a node's children INSIDE its own shape, and the two rows that say so.
#
# `clip_children` is one property on every CanvasItem and it does something no arrangement of nodes
# can: whatever this node draws becomes the shape its children are allowed to draw inside. A mask
# without a mask texture, a progress bar that is really a sprite, a portrait cut to a frame, water
# that stops at the edge of the pool - all of them are this one field, and almost nobody finds it
# because it is spelled as a rendering enum rather than as something a game wants.
#
# TWO ROWS, because the field has two answers a reader means and one they do not. Clip My Children
# turns it on, and the dropdown is the only real decision: whether this node is DRAWN as well as
# being the shape (a frame you can see) or is only the shape (an invisible cookie cutter). Stop
# Clipping is the way back, and owns the third value on its own so that no line can be spelled by
# both rows - which is what keeps an opened file reading back as the row that wrote it.
#
# THE SHELF IS "Blend Modes", shared with the Blend Modes pack, on purpose: clipping, masking and
# blending are one question a reader has ("how do these two pictures meet"), and a vocabulary that
# answers it from two different sections is a vocabulary they have to already know to search.
@tool
class_name EventForgeCanvasClipACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker section these rows shelve under - the same words the Blend Modes pack's own verbs use,
## so the whole "how do two pictures meet" question is one place in the picker.
const CAT := "Blend Modes"

## The class the rows belong to. Every 2D node that draws anything is one, which is exactly the set
## of nodes the field exists on.
const HOST := "CanvasItem"

## The member both rows write, and the three values Godot spells it with. The two ON values are the
## dropdown of the first row; the OFF one is the whole of the second, so a written line is only ever
## claimed by one of them when a file is opened again.
const CLIP_MEMBER := "clip_children"
const CLIP_AND_DRAW := "CanvasItem.CLIP_CHILDREN_AND_DRAW"
const CLIP_ONLY := "CanvasItem.CLIP_CHILDREN_ONLY"
const CLIP_DISABLED := "CanvasItem.CLIP_CHILDREN_DISABLED"


static func get_descriptors() -> Array[ACEDescriptor]:
	return [_clip_row(), _stop_row()]


## `Clip my children, draw me too`. The row that turns this node into the shape its children are
## drawn inside.
static func _clip_row() -> ACEDescriptor:
	return F.act("ClipMyChildren", "Clip My Children", "%s = {mode}" % CLIP_MEMBER, CAT,
		"Clip my children, {mode}",
		"Makes whatever this node draws the SHAPE its children are allowed to draw inside - a portrait cut to a frame, a bar that fills a shape, water that stops at the edge of the pool. Choose whether this node is drawn as well as being the shape, or is only the shape.",
		HOST).param_built(_mode_param())


## `Stop clipping my children`. The way back, and the only row that writes the disabled value.
static func _stop_row() -> ACEDescriptor:
	return F.act("StopClipping", "Stop Clipping", "%s = %s" % [CLIP_MEMBER, CLIP_DISABLED], CAT,
		"Stop clipping my children",
		"Puts this node back to drawing normally: its children draw wherever they like again, and the node itself is drawn as it always was.",
		HOST)


## The one decision the clipping row has. `display_option_labels` is what makes the ROW read "Clip my
## children, draw me too" instead of naming the engine constant: the KEY is still the constant the
## template writes and every saved row holds (both frozen), and only the word a reader sees changes.
static func _mode_param() -> ACEParam:
	var parameter: ACEParam = F.make_param("mode", "String", CLIP_AND_DRAW, "Draw this node",
		"Whether this node is drawn as well as being the shape (a frame you can see), or is only the shape (an invisible cutter).",
		"", [
			{"key": CLIP_AND_DRAW, "label": "draw me too"},
			{"key": CLIP_ONLY, "label": "clip only"}
		])
	parameter.display_option_labels = true
	return parameter
