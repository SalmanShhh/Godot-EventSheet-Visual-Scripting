@tool
class_name EventSheetChunkToolsDialog
extends RefCounted

# The two doors onto the chunk tools: Split Scene Into Chunks, and Merge Chunks. One dialog in two
# modes, because the two are the same five facts read in opposite directions - a scene, a cell
# size, a folder - and a reader who has used one already knows the other.
#
# It is a THIN SHELL. Everything it does is EventSheetChunkTools, which touches no editor at all;
# this file is the fields, the help strip that says what the tool will and will not move, and the
# receipt afterwards. Nothing is written until the button is pressed, and the scene it reads is
# never touched either way.

## The biggest a cell may be, in the scene's own units. A SpinBox tops out at 100 unless it is
## told otherwise, which would silently clamp a 1024-pixel chunk to a hundredth of itself.
const MOST_UNITS := 65536.0

const SPLIT_TITLE := "Split Scene Into Chunks"
const MERGE_TITLE := "Merge Chunks"

var _dialog: ConfirmationDialog = null
var _form: EventSheetFieldForm = null
var _splitting: bool = true
var _parent: Node = null


## Opens the Split door: a scene in, a folder of chunk scenes out.
func open_split(parent: Node, scene_path: String = "") -> void:
	_splitting = true
	_open(parent, scene_path)


## Opens the Merge door: a folder of chunk scenes in, one scene out.
func open_merge(parent: Node, scene_path: String = "") -> void:
	_splitting = false
	_open(parent, scene_path)


func _open(parent: Node, scene_path: String) -> void:
	_parent = parent
	_build(scene_path)
	_dialog.popup_centered(Vector2i(520, 400))


func _build(scene_path: String) -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = ConfirmationDialog.new()
	_dialog.title = SPLIT_TITLE if _splitting else MERGE_TITLE
	_dialog.ok_button_text = "Split" if _splitting else "Merge"
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	_form = EventSheetPopupUI.form(content, _specs(scene_path),
		"chunk tools" if _splitting else "chunk merge")
	content.add_child(EventSheetPopupUI.help_strip(
		"What this moves", _help_body(), "", ""))
	_dialog.add_child(EventSheetPopupUI.titled_card(
		"A scene in, a folder of chunk scenes out" if _splitting
		else "A folder of chunk scenes in, one scene out", content))
	_dialog.confirmed.connect(_on_confirmed)
	# The dialog parents to the editor base control (outside the dock's translation domain), so it
	# claims the plugin domain itself and its strings auto-translate.
	EventSheetL10n.apply_to(_dialog)
	_parent.add_child(_dialog)


## The fields, in the order somebody fills them: what is being read, how big a cell is, and where
## the result goes.
func _specs(scene_path: String) -> Array[EventSheetFieldSpec]:
	var specs: Array[EventSheetFieldSpec] = []
	if _splitting:
		specs.append(EventSheetPopupUI.path_field("scene", "Scene").default(scene_path)
			.placeholder("res://world/world.tscn")
			.tooltip("The scene to read. It is never changed - the chunks are written beside it."))
	specs.append(EventSheetPopupUI.path_field("folder", "Chunk folder").default("res://world/chunks")
		.tooltip("The folder of chunk scenes: written by Split, read by Merge, and by the Streamer's own Stream Chunks Around."))
	if not _splitting:
		specs.append(EventSheetPopupUI.path_field("scene", "Into scene").default("res://world/world.tscn")
			.tooltip("The one scene the chunks are put back together into."))
	specs.append(EventSheetPopupUI.number_field("width", "Cell width")
		.default(1024.0).at_least(1.0).at_most(MOST_UNITS)
		.tooltip("How wide one chunk is, in the scene's own units. Match the Streamer's Cell Size."))
	specs.append(EventSheetPopupUI.number_field("height", "Cell height")
		.default(1024.0).at_least(1.0).at_most(MOST_UNITS)
		.tooltip("How tall one chunk is. Ignored on a 2D scene, and on a 3D one until height is a cell axis."))
	specs.append(EventSheetPopupUI.number_field("depth", "Cell depth")
		.default(1024.0).at_least(1.0).at_most(MOST_UNITS)
		.tooltip("How deep one chunk is. A 2D scene's depth axis is its own y."))
	if _splitting:
		specs.append(EventSheetPopupUI.text_field("prefix", "Name prefix")
			.default(EventSheetChunkTools.DEFAULT_PREFIX)
			.tooltip("The words before the cell numbers: chunk_3_-2.tscn. Do not end it with a number - the numbers at the end of the name ARE the address."))
	specs.append(EventSheetPopupUI.check_field("stacked", "Height is a cell axis")
		.default(false)
		.tooltip("Off, the grid is flat and every cell's height is 0 - what an open world wants. On, cells stack, for a station, a cave or a tower."))
	return specs


## What the tool will and will not do, said before it is run rather than discovered afterwards.
func _help_body() -> String:
	if _splitting:
		return "Each DIRECT CHILD of the scene's root moves into the chunk its own position falls in, re-based to that cell's origin. A child with no position - a Control, a Timer, an audio player - has no cell, so it stays where it is and is named in the receipt. A tilemap is one node holding a whole world of cells: splitting it would mean rewriting its data, so it is left alone."
	return "Every scene in the folder named like a cell is opened, its children moved back to where the cell puts them, and the result saved as one scene. The chunk scenes are not changed, so a merge is always reversible by splitting again."


func _on_confirmed() -> void:
	var values: Dictionary = _form.values()
	var cell_size: Vector3 = Vector3(float(values.get("width", 1024.0)),
		float(values.get("height", 1024.0)), float(values.get("depth", 1024.0)))
	var flat: bool = not bool(values.get("stacked", false))
	var folder: String = str(values.get("folder", ""))
	var scene_path: String = str(values.get("scene", ""))
	var receipt: Dictionary = EventSheetChunkTools.split_scene(scene_path, cell_size, folder,
		str(values.get("prefix", EventSheetChunkTools.DEFAULT_PREFIX)), flat) if _splitting \
		else EventSheetChunkTools.merge_chunks(folder, cell_size, scene_path)
	EventSheets.set_status(receipt_words(receipt, _splitting),
		not str(receipt.get("problem", "")).is_empty())
	EventSheets.refresh()


## The receipt as one sentence. Static and pure, so what the status bar says is pinned by a test
## rather than only ever read off a screenshot.
static func receipt_words(receipt: Dictionary, was_split: bool) -> String:
	var problem: String = str(receipt.get("problem", ""))
	if not problem.is_empty():
		return problem
	if not was_split:
		return "Merged %d chunk(s) into %s." % [int(receipt.get("cells", 0)),
			str(receipt.get("written", ""))]
	var words: String = "Wrote %d chunk scene(s)." % int(receipt.get("cells", 0))
	var left_behind: PackedStringArray = receipt.get("left_behind", PackedStringArray())
	if not left_behind.is_empty():
		words += " %d child(ren) had no place in the world and stayed put: %s." % [
			left_behind.size(), ", ".join(left_behind)]
	return words
