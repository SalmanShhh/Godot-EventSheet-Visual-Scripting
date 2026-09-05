# Godot EventSheets - the toolbar's Moment segment: where the buttons for a beat live.
#
# THE ONE THING THIS FILE IS ABOUT: a sheet row is a condition lane and an action lane and nothing
# else. Tuning a hit wants a Play button, a Stop, a Skip, a Restore and a strength - and none of
# them may be drawn inside a row. They belong where buttons already live, and for a selection that
# is the resting toolbar: a contextual segment that appears while a row about a beat is selected and
# goes away when the selection moves, exactly as the toolbar's other contextual controls do.
#
# WHAT COUNTS AS "about a beat": a row on a Feedback Player (the node that holds a list), a Moment
# row on either Juice behaviour, or a Moment block's head. The answer is derived from the row's own
# provider and verb rather than from a list of ids kept here, so a pack that grows another moment
# verb is covered by the same rule.
#
# ONE PREVIEW, TWO HOMES. Play does not run a second sampler: it drives the very strip the Feedback
# Player's Inspector draws, on the player this row is about, so the toolbar and the Inspector can
# never show two different pictures of one list. Nothing is written to the scene that is not put
# back - the strip captures the object's rest state before it moves anything.
#
# THE READING HALF IS PURE + STATIC (what a row is about, what the segment's buttons are called), so
# the suite pins every word without an editor, a viewport or a display server.
@tool
class_name EventSheetMomentSegment
extends RefCounted

## The providers a row about a beat comes from. The Feedback Player holds a list; the two Juice
## behaviours hold the Moment verbs.
const PLAYER_PROVIDER: String = "FeedbackPlayer"
const JUICE_PROVIDERS: PackedStringArray = ["JuiceBehavior", "Juice3DBehavior"]

## The block kind whose head the segment also answers for. Named as a string because a block kind is
## a registered id rather than a class - the same spelling the block registry knows it by.
const MOMENT_BLOCK_KIND: String = "moment"

## What a Juice verb has to start with to be a moment verb. A prefix rather than a list, so Play
## Moment, Play Moment And Wait, Revert Moment and whatever is added next are all covered without
## this file being edited again.
const MOMENT_VERB_PREFIX: String = "moment"

## The three kinds of subject the segment can be about, and the word it leads with for each.
const SUBJECT_PLAYER: String = "player"
const SUBJECT_MOMENT: String = "moment"
const SUBJECT_BLOCK: String = "block"

## The segment, in reading order: what it does, what it is called, the editor icon it wears when the
## running theme has one, and what the hover says. The icon is a WISH - a theme that does not carry
## the name leaves the button its words, which is the only safe way to ask for one.
const BUTTONS: Array = [
	["play", "Play", "Play", "Play this beat on the open scene, sampled in the editor."],
	["stop", "Stop", "Stop", "Stop the preview and put the object back the way it was."],
	["skip", "Skip", "DebugNext", "Jump to the last frame of the beat, the way Skip To End does."],
	["restore", "Restore", "Reload", "Put back every value the preview moved, without playing anything."],
	["inspector", "Open", "Edit", "Select the Feedback Player this row is about, so its list opens in the Inspector."]
]

## What the strength field offers. A beat is tuned between nothing and twice as much; the box takes
## anything, these are only the ends of its drag.
const STRENGTH_MIN: float = 0.0
const STRENGTH_MAX: float = 2.0
const STRENGTH_STEP: float = 0.05

var _dock: Control = null
var _segment: HBoxContainer = null
var _title: Label = null
var _strength: SpinBox = null
var _strip: Control = null
var _subject: Dictionary = {}

## The controls the segment shows and hides. The CONTAINER is not one of them: it stays on the strip
## for good, because the strip's resting/expanded sweep decides what is visible by container and a
## segment that hid itself would be shown again by the next chevron press. An empty container draws
## nothing, so hiding its contents is the same picture and survives the sweep.
var _parts: Array = []


func init(dock: Control) -> void:
	_dock = dock


## What the segment is about for one selected row, or {} for a row it has nothing to say about -
## which is every row in a sheet that never mentions a beat, so the segment is invisible by default
## and costs one dictionary read per selection.
##
## `row_resource` is the selected condition, action or trigger; `block_kind` is the kind id when the
## selection is a block's head row instead. PURE + STATIC.
static func subject_of(row_resource: Resource, block_kind: String = "") -> Dictionary:
	if block_kind.strip_edges().to_lower() == MOMENT_BLOCK_KIND:
		return {"kind": SUBJECT_BLOCK, "label": ""}
	if row_resource == null:
		return {}
	var provider: String = str(row_resource.get("provider_id"))
	var verb: String = str(row_resource.get("ace_id"))
	if provider == PLAYER_PROVIDER:
		return {"kind": SUBJECT_PLAYER, "label": ""}
	if JUICE_PROVIDERS.has(provider) and verb.begins_with(MOMENT_VERB_PREFIX):
		var params: Variant = row_resource.get("params")
		var named: String = ""
		if params is Dictionary:
			named = str((params as Dictionary).get("moment_name", "")).strip_edges().strip_escapes()
		return {"kind": SUBJECT_MOMENT, "label": named.trim_prefix("\"").trim_suffix("\"")}
	return {}


## The line the segment leads with: what it is about, in the fewest words that still say which.
## PURE + STATIC, so the suite pins the wording.
static func title_for(subject: Dictionary) -> String:
	match str(subject.get("kind", "")):
		SUBJECT_PLAYER:
			return "Feedbacks"
		SUBJECT_BLOCK:
			return "Moment"
		SUBJECT_MOMENT:
			var named: String = str(subject.get("label", ""))
			return "Moment" if named.is_empty() else "Moment: %s" % named
	return ""


## Builds the segment and adds it to the strip. It starts hidden, and every button keeps its words
## whether or not the running editor theme lends it an icon.
func build(toolbar: Node) -> Control:
	_segment = HBoxContainer.new()
	_segment.name = "EventSheetMomentSegment"
	_segment.add_theme_constant_override("separation", 3)
	_title = Label.new()
	_title.name = "EventSheetMomentSegmentTitle"
	_segment.add_child(_title)
	_parts.append(_title)
	for entry: Array in BUTTONS:
		var button: Button = Button.new()
		button.name = "EventSheetMomentSegment%s" % str(entry[0]).capitalize()
		button.text = str(entry[1])
		button.tooltip_text = str(entry[3])
		button.icon = EventSheetEditorIcons.icon(str(entry[2]))
		var pressed_kind: String = str(entry[0])
		button.pressed.connect(func() -> void: activate(pressed_kind))
		_segment.add_child(button)
		_parts.append(button)
	_strength = SpinBox.new()
	_strength.name = "EventSheetMomentSegmentStrength"
	_strength.min_value = STRENGTH_MIN
	_strength.max_value = STRENGTH_MAX
	_strength.step = STRENGTH_STEP
	_strength.value = 1.0
	# "at 1.0" rather than "strength 1.0": the box is narrow, and a prefix that has to be cut in half
	# to fit says less than the two characters that do.
	_strength.prefix = "at"
	_strength.custom_minimum_size = Vector2(88.0, 0.0)
	_strength.tooltip_text = "What the preview scales every amount in the beat by - the same number the play row asks for."
	_segment.add_child(_strength)
	_parts.append(_strength)
	for part: Control in _parts:
		part.visible = false
	if toolbar != null:
		toolbar.add_child(_segment)
	return _segment


## Show (or hide) the segment for the row that has just been selected. Called from the dock's one
## selection handler, so nothing else has to know the segment exists.
func follow(row_resource: Resource, block_kind: String = "") -> void:
	_subject = subject_of(row_resource, block_kind)
	if _segment == null:
		return
	for part: Control in _parts:
		part.visible = not _subject.is_empty()
	if _title != null:
		_title.text = title_for(_subject)


## One button, pressed. Answers whether it did anything, so the suite and the dock read the same
## verdict rather than watching the scene for a side effect.
func activate(kind: String) -> bool:
	var player: Node = _player()
	if player == null:
		return false
	if kind == "inspector":
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(player)
		EditorInterface.edit_node(player)
		return true
	var strip: Control = _strip_for(player)
	if strip == null or not strip.has_method(kind):
		return false
	if kind == "play" and _strength != null:
		player.set("strength", float(_strength.value))
	strip.call(kind)
	return true


## The Feedback Player this segment is about: the one selected in the Scene dock when that is one,
## else the first one in the open scene. Naming it that way rather than resolving it from the row
## keeps the segment honest - it says what it is about in the Scene dock's own terms, and a scene
## with no player in it simply leaves the buttons doing nothing.
func _player() -> Node:
	if not Engine.has_singleton("EditorInterface"):
		return null
	for node: Node in EditorInterface.get_selection().get_selected_nodes():
		if is_player(node):
			return node
	return first_player(EditorInterface.get_edited_scene_root())


## Whether a node is a Feedback Player, asked of the SCRIPT it carries rather than of a class name,
## because naming the pack's class here would compile it into every editor boot. PURE + STATIC.
static func is_player(node: Node) -> bool:
	if node == null:
		return false
	var script: Script = node.get_script() as Script
	return script != null and script.resource_path.get_file() == "feedback_player.gd"


## The first Feedback Player under a node, in tree order, or null. PURE + STATIC.
static func first_player(root: Node) -> Node:
	if root == null:
		return null
	if is_player(root):
		return root
	for child: Node in root.get_children():
		var found: Node = first_player(child)
		if found != null:
			return found
	return null


## The Inspector strip for one player, made once and kept. It is never added to the toolbar - it is
## the preview's machinery, not a picture - so it lives under the segment and draws nothing.
func _strip_for(player: Node) -> Control:
	if _strip != null and is_instance_valid(_strip) and _strip.get("_player") == player:
		return _strip
	if _strip != null and is_instance_valid(_strip):
		_strip.queue_free()
	_strip = load("res://addons/eventsheet/editor/inspector/feedback_player_strip.gd").new(player) as Control
	_strip.visible = false
	if _segment != null:
		_segment.add_child(_strip)
	return _strip
