## @ace_tags(ui, layout)
## @ace_category("Anchor")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/anchor/icon.svg")
class_name AnchorBehavior
extends Node
## Where a Control sits when the window changes size, said as a corner rather than as four numbers: anchor to top right, to the centre, to the full rect. Margins are set in pixels from the corner it is anchored to, the corner it is on can be asked about, and On Anchored fires whenever it moves.
##
## Changes on its parent: offset_left, offset_top, offset_right, offset_bottom.

## @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: Control = null

## The node this behavior acts on (Acts on, or else its parent). Required host: Control.
var host: Control = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as Control
	if host == null:
		push_warning("Anchor Behavior needs a Control: put it under one, or set Acts on.")

## @ace_trigger
## @ace_name("On Anchored")
signal anchored(corner: String)

# --- Choices (the stored words are the promise: saved scenes keep them) ---
## anchored_to: the top-left corner.
const ANCHORED_TO_TOP_LEFT := "top left"
## anchored_to: the top-right corner.
const ANCHORED_TO_TOP_RIGHT := "top right"
## anchored_to: the bottom-left corner.
const ANCHORED_TO_BOTTOM_LEFT := "bottom left"
## anchored_to: the bottom-right corner.
const ANCHORED_TO_BOTTOM_RIGHT := "bottom right"
## anchored_to: the middle of the parent.
const ANCHORED_TO_CENTRE := "centre"
## anchored_to: the whole parent.
const ANCHORED_TO_FULL_RECT := "full rect"
## anchored_to: across the top.
const ANCHORED_TO_TOP_EDGE := "top edge"
## anchored_to: across the bottom.
const ANCHORED_TO_BOTTOM_EDGE := "bottom edge"
## anchored_to: down the left side.
const ANCHORED_TO_LEFT_EDGE := "left edge"
## anchored_to: down the right side.
const ANCHORED_TO_RIGHT_EDGE := "right edge"

# --- Designer knobs (tune in the Inspector) ---
## The corner this Control is anchored to. Anchor To Preset writes it; the host is placed there again whenever its parent resizes.
@export_enum("top left", "top right", "bottom left", "bottom right", "centre", "full rect", "top edge", "bottom edge", "left edge", "right edge") var anchored_to: String = "top left"
## Keep the host's current size when it is anchored, instead of letting the preset stretch it. Off is Godot's own behaviour for the wide presets.
@export var keep_size: bool = true
## Re-apply the anchor whenever the parent changes size. Off pins it once and leaves it.
@export var follow_resizes: bool = true

## The Godot preset each corner word stands for. The words are the row's; the numbers are the engine's, and this table is the one place the two meet.
## @ace_hidden
const CORNER_PRESETS: Dictionary = {
	ANCHORED_TO_TOP_LEFT: Control.PRESET_TOP_LEFT,
	ANCHORED_TO_TOP_RIGHT: Control.PRESET_TOP_RIGHT,
	ANCHORED_TO_BOTTOM_LEFT: Control.PRESET_BOTTOM_LEFT,
	ANCHORED_TO_BOTTOM_RIGHT: Control.PRESET_BOTTOM_RIGHT,
	ANCHORED_TO_CENTRE: Control.PRESET_CENTER,
	ANCHORED_TO_FULL_RECT: Control.PRESET_FULL_RECT,
	ANCHORED_TO_TOP_EDGE: Control.PRESET_TOP_WIDE,
	ANCHORED_TO_BOTTOM_EDGE: Control.PRESET_BOTTOM_WIDE,
	ANCHORED_TO_LEFT_EDGE: Control.PRESET_LEFT_WIDE,
	ANCHORED_TO_RIGHT_EDGE: Control.PRESET_RIGHT_WIDE
}

func _ready() -> void:
	if host == null:
		return
	anchor_to(anchored_to)
	# A Control is placed by its PARENT, so the parent is what has to be listened to. Without
	# this the anchor is a one-off and a resized window leaves the host where it started.
	if follow_resizes and host.get_parent() is Control:
		host.get_parent().resized.connect(func() -> void: anchor_to(anchored_to))

## @ace_action
## @ace_featured
## @ace_name("Set Margins")
## @ace_category("Anchor")
## @ace_description("Sets the gap in pixels between the host and the corner it is anchored to - left, top, right, bottom.")
## @ace_display_template("Set margins [b]{left}[/b], [b]{top}[/b], [b]{right}[/b], [b]{bottom}[/b]")
## @ace_icon("res://eventsheet_addons/anchor/icon.svg")
## @ace_codegen_template("$AnchorBehavior.set_margins({left}, {top}, {right}, {bottom})")
func set_margins(left: float, top: float, right: float, bottom: float) -> void:
	if host == null:
		return
	host.offset_left = left
	host.offset_top = top
	host.offset_right = right
	host.offset_bottom = bottom

## @ace_action
## @ace_name("Set Keep Size")
## @ace_category("Anchor")
## @ace_description("Whether anchoring keeps the host's current size instead of letting the corner stretch it.")
## @ace_icon("res://eventsheet_addons/anchor/icon.svg")
## @ace_codegen_template("$AnchorBehavior.set_keep_size({enabled})")
func set_keep_size(enabled: bool) -> void:
	keep_size = enabled

## @ace_action
## @ace_name("Set Follow Resizes")
## @ace_category("Anchor")
## @ace_description("Whether the host is placed again every time its parent changes size.")
## @ace_icon("res://eventsheet_addons/anchor/icon.svg")
## @ace_codegen_template("$AnchorBehavior.set_follow_resizes({enabled})")
func set_follow_resizes(enabled: bool) -> void:
	follow_resizes = enabled

## Puts the host on a corner, an edge or the whole rectangle of its parent - the one
## action this behavior exists for.
## @ace_action
## @ace_name("Anchor To")
## @ace_param_options(corner top left=The top-left corner, top right=The top-right corner, bottom left=The bottom-left corner, bottom right=The bottom-right corner, centre=The middle, full rect=The whole parent, top edge=Across the top, bottom edge=Across the bottom, left edge=Down the left, right edge=Down the right)
## @ace_icon("res://eventsheet_addons/anchor/icon.svg")
## @ace_codegen_template("$AnchorBehavior.anchor_to("{corner}")")
func anchor_to(corner: String) -> void:
	if host == null or not CORNER_PRESETS.has(corner):
		return
	anchored_to = corner
	var mode: int = Control.PRESET_MODE_KEEP_SIZE if keep_size else Control.PRESET_MODE_MINSIZE
	host.set_anchors_and_offsets_preset(CORNER_PRESETS[corner], mode)
	anchored.emit(corner)

## True while the host is anchored to the given corner - what a row asks before moving it
## somewhere else.
## @ace_condition
## @ace_name("Is Anchored To")
## @ace_icon("res://eventsheet_addons/anchor/icon.svg")
## @ace_codegen_template("$AnchorBehavior.is_anchored_to({corner})")
func is_anchored_to(corner: String) -> bool:
	return anchored_to == corner

## The corner the host is anchored to right now, as its word - what a row shows or compares.
## @ace_expression
## @ace_name("Anchored Corner")
## @ace_icon("res://eventsheet_addons/anchor/icon.svg")
## @ace_codegen_template("$AnchorBehavior.anchored_corner()")
func anchored_corner() -> String:
	return anchored_to

# Anchor behavior: pin this Control to a corner, an edge or the whole rectangle of its parent, in one action. Anchor To Preset does the placing, Set Margins nudges it in pixels, Is Anchored To asks where it sits, and On Anchored fires when it moves. This pack is an event sheet - extend it by editing it.
