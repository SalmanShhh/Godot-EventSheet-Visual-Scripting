# EventSheet - EventSheetSceneSelectionLink: the Scene dock and the sheet follow each other.
#
# In another event-sheet editor the layout and the sheet share ONE selection: click the enemy on
# the layout and the sheet is already talking about the enemy. Godot has the Scene dock, and until
# now the two surfaces did not know each other was there. This is the bridge, in both directions:
#
#   Scene dock -> sheet   selecting a node highlights its entry on the Object bar and offers
#                         "Filter events to <node>" (the Filter lens the sheet already has)
#   sheet -> Scene dock   selecting a row selects the node that row is about, so the Scene dock and
#                         the 2D view land on it
#
# THE PING-PONG is the whole difficulty and the reason this is its own class. Each half of the
# bridge causes the other's trigger: selecting the node changes the sheet selection, which selects
# the node, which changes the sheet selection. A guard flag held for the duration of one crossing
# is what makes two-way follow possible at all - without it the two surfaces fight, and the reader
# watches their selection jitter. `is_crossing()` is public so a test can pin that the guard is
# what stops it, rather than pinning the absence of a symptom.
#
# The follow is a SETTING (eventsheets/editor/follow_scene_selection, on by default). Somebody
# working on one row while clicking around a scene wants it off, and that is a reasonable thing to
# want.
#
# The routing halves are static and pure over their inputs - an object census and a row - so the
# suite pins which node a row is about, and which Object-bar entry a node is, without an editor.
@tool
class_name EventSheetSceneSelectionLink
extends RefCounted

## The project setting that turns the follow off. Registered with the rest in EventSheetSettings.
const FOLLOW_SETTING := "eventsheets/editor/follow_scene_selection"

## The offer the status line makes when a scene selection lands on an object this sheet talks
## about. A sentence rather than a silent filter: the reader chose a node in another dock, and
## rewriting what their sheet shows because of it would be the sheet taking a liberty.
const FILTER_OFFER := "Filter events to %s"

var _dock: Control = null
var _selection: EditorSelection = null
## True while one side of the bridge is driving the other, for the crossings that answer back
## synchronously.
var _crossing: bool = false
## The object this side just selected in the Scene dock, remembered until the answering
## selection_changed arrives. A plain bool cannot carry this: EditorSelection emits its change
## DEFERRED, so the flag is already down by the time the echo lands, and the echo is exactly the
## event that would drive the sheet back. Naming the object we caused makes the echo recognisable
## however late it arrives.
var _driven_label: String = ""


func _init(dock: Control) -> void:
	_dock = dock


## Starts following. Safe to call twice (the connect is guarded), and a no-op outside the editor,
## where there is no selection to follow.
func init_selection(selection: EditorSelection) -> void:
	_selection = selection
	if _selection == null:
		return
	if not _selection.selection_changed.is_connected(_on_scene_selection_changed):
		_selection.selection_changed.connect(_on_scene_selection_changed)


## Stops following. Called from the dock's teardown - a connection outliving the dock would call
## into a freed Control on the next click in the Scene dock.
func teardown() -> void:
	if _selection != null and _selection.selection_changed.is_connected(_on_scene_selection_changed):
		_selection.selection_changed.disconnect(_on_scene_selection_changed)
	_selection = null


## True while one side is driving the other. The guard, exposed so the suite can pin it.
func is_crossing() -> bool:
	return _crossing or not _driven_label.is_empty()


## The object this side last selected in the Scene dock and is still expecting the echo of, or ""
## when nothing is outstanding.
func driven_label() -> String:
	return _driven_label


## Is the follow switched on? Reads the project setting each time rather than caching it, so
## turning it off takes effect on the next click instead of on the next editor start.
static func follow_enabled() -> bool:
	if not ProjectSettings.has_setting(FOLLOW_SETTING):
		return true
	return bool(ProjectSettings.get_setting(FOLLOW_SETTING, true))


## Which Object-bar entry a selected node IS, or "" when this sheet does not talk about it. The
## node's own name wins over its class, because that is the label the Object bar shows when the
## sheet knows the node by name; the class is the fallback for a sheet that talks about the KIND
## of thing rather than about one instance of it.
##
## Pure over the census (EventSheetViewportReadingRows.object_census), so the suite pins the
## routing against a fixture rather than against whatever scene is open.
static func object_label_for_node(census: Array, node_name: String,
		node_class: String) -> String:
	var name_wanted: String = node_name.strip_edges()
	var class_wanted: String = node_class.strip_edges()
	var by_class: String = ""
	for entry: Variant in census:
		var label: String = str((entry as Dictionary).get("label", ""))
		if label.is_empty():
			continue
		if label == name_wanted:
			return label
		if by_class.is_empty() and label == class_wanted:
			by_class = label
	return by_class


## Which node a selected ROW is about, as the object label the row's spans carry. Empty for a row
## that is about nothing in particular (a comment, a group bar, a blank event) - and an empty
## answer is a no-op rather than a selection change, because clearing the Scene dock's selection
## because somebody clicked a comment would be the sheet taking a liberty.
static func object_label_for_row(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	for span: SemanticSpan in row_data.spans:
		if not (span.metadata is Dictionary):
			continue
		var label: String = str((span.metadata as Dictionary).get("object_label", ""))
		if not label.is_empty():
			return label
	return ""


## Scene dock -> sheet. Highlights the object on the Object bar and offers the filter; it never
## applies the filter itself, because the reader clicked in another dock and did not ask this one
## to hide anything.
func _on_scene_selection_changed() -> void:
	if _crossing or _dock == null or not follow_enabled():
		return
	if _selection == null:
		return
	var nodes: Array[Node] = _selection.get_selected_nodes()
	if nodes.size() != 1:
		return
	_crossing = true
	follow_node(nodes[0].name, nodes[0].get_class())
	_crossing = false


## The Scene-dock half, split out so the suite can drive it without an EditorSelection.
func follow_node(node_name: String, node_class: String) -> void:
	if _dock == null or _dock._current_sheet == null:
		return
	var label: String = object_label_for_node(
		EventSheetViewportReadingRows.object_census(_dock._current_sheet), node_name, node_class)
	if label.is_empty():
		return
	# The echo of our own selection: this side caused it, so it says nothing the reader did.
	if label == _driven_label:
		_driven_label = ""
		return
	if _dock._objects_panel != null:
		_dock._objects_panel.highlight_object(label)
	_dock._set_status(EventSheetL10n.translate(FILTER_OFFER) % label)


## Sheet -> Scene dock. Selects the node the row is about, so the Scene dock and the 2D view land
## where the reader's eye already is.
func follow_row(row_data: EventRowData) -> void:
	if _crossing or _dock == null or not follow_enabled():
		return
	var label: String = object_label_for_row(row_data)
	if label.is_empty():
		return
	_crossing = true
	_driven_label = label
	_dock.select_object_in_scene(label)
	_crossing = false
