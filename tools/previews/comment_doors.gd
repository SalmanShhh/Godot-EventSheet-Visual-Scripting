# Godot EventSheets - the nouns in a comment that the project can prove (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# NOTHING is drawn by hand: a real viewport is given a real sheet and a real scene, and every
# underline in the picture is one the row builder found in the project's own indexes and the renderer
# measured against the line it drew.
#
# The picture is the rule in both directions. `%HealthBar` is a node of the scene and `Patrol` is a
# state this object declares, so both wear a hairline and both go somewhere. `retreat` is spelled
# exactly like a state name and is not one, so it stays grey prose with no mark and no message - the
# whole point being that a door is evidence rather than a guess.
@tool
extends RefCounted

const PREVIEW_NAME: String = "comment-doors"
const PREVIEW_SIZE: Vector2i = Vector2i(1560, 400)

## The documentation note: two proven names and one word that only looks like one.
const DOCUMENTED: String = "%HealthBar drives this. Patrol is where it starts; retreat is a word, not a state."

## And the private note beside it, to show the other spelling gets the same doors.
const PRIVATE: String = "begin_chase does the rest"


static func build(host: Window) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The scene the node index is read from. A preview has no edited scene, so the same injection
	# point the completion seam offers its tests is used here; it is parented into the picture so it
	# is torn down with it.
	var scene_root: Node = _scene()
	column.add_child(scene_root)
	EventSheetCompletions.clear_cache()
	EventSheetCommentDoors.clear_cache()
	EventSheetCompletions.scene_root_override = scene_root
	column.add_child(_sheet_card("A note whose nouns the project can prove"))
	column.add_child(EventSheetPopupUI.hint_label(
		"%HealthBar is a node of the scene and Patrol is a state this object declares, so each one "
		+ "is underlined and each one goes there. \"retreat\" matches nothing the project has, so it "
		+ "stays prose. The comment itself is unchanged: the file still holds the same # line.", 1460.0))
	host.add_child(column)
	return column


## The sheet, read-only, in a real canvas at a fixed height - the same shape every other sheet
## preview uses, for the same reason: a canvas given a container's whole appetite takes all of it.
static func _sheet_card(title: String) -> Control:
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	var sheet: EventSheetResource = _sheet()
	sheet.editor_style = style
	sheet.read_only = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	var window: Control = Control.new()
	window.custom_minimum_size = Vector2(0.0, 230.0)
	window.clip_contents = true
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(viewport)
	return EventSheetPopupUI.titled_card(title, window)


## The object being read: three declared states, one published function, and the two notes.
static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Enemy"
	sheet.host_class = "CharacterBody2D"
	var states: EnumRow = EnumRow.new()
	states.enum_name = EventSheetStateFacts.ENUM_NAME
	states.members = PackedStringArray(["PATROL", "CHASE", "GAVE_UP"])
	sheet.events.append(states)
	var documented: CommentRow = CommentRow.new()
	documented.text = DOCUMENTED
	documented.source_marker = CommentRow.DOC_MARKER
	sheet.events.append(documented)
	var private_note: CommentRow = CommentRow.new()
	private_note.text = PRIVATE
	sheet.events.append(private_note)
	var published: EventFunction = EventFunction.new()
	published.function_name = "begin_chase"
	sheet.functions.append(published)
	return sheet


## The scene behind the sheet: one uniquely named node, which is the spelling the note uses.
static func _scene() -> Node:
	var root := Node.new()
	root.name = "Enemy"
	var bar := Node.new()
	bar.name = "HealthBar"
	root.add_child(bar)
	bar.owner = root
	bar.unique_name_in_owner = true
	return root
