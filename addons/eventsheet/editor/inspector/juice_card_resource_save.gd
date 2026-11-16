# Godot EventSheets - saves a new resource a card is about to keep (editor-only, loaded by path).
#
# A card keeps the ADDRESS of a resource's file, never a copy inside the scene. So when Godot's own picker
# makes a new one (New Curve), the card asks where to save it first, writes it there, gives the file an id of
# its own so a rename or a move does not lose it, and then keeps that id as text. A Curve made this way starts
# as a straight fall from full to nothing, so it is a shape from the first moment and not an empty box.
@tool
extends RefCounted

## What a new curve file is called until the person says otherwise.
const DEFAULT_CURVE_FILE: String = "shake_curve.tres"


## Asks where to save `resource`, saves it, and calls `done` with the file's uid text, or with "" when the
## question was cancelled. Outside the editor there is no file dialog, so it answers "" at once.
static func ask(owner: Node, resource: Resource, done: Callable) -> void:
	if not ClassDB.can_instantiate("EditorFileDialog"):
		done.call("")
		return
	var dialog: EditorFileDialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", EventSheetL10n.translate("Resource files"))
	dialog.title = EventSheetL10n.translate("Save the new file where the card can find it")
	dialog.current_dir = "res://"
	dialog.current_file = DEFAULT_CURVE_FILE
	owner.add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		done.call(keep(resource, path))
		dialog.queue_free())
	dialog.canceled.connect(func() -> void:
		done.call("")
		dialog.queue_free())
	dialog.popup_file_dialog()


## Writes `resource` to `path`, gives the file a uid when it has none, and answers the uid text ("" when the
## file could not be written).
static func keep(resource: Resource, path: String) -> String:
	if resource is Curve and (resource as Curve).point_count == 0:
		(resource as Curve).add_point(Vector2(0.0, 1.0))
		(resource as Curve).add_point(Vector2(1.0, 0.0))
	if ResourceSaver.save(resource, path) != OK:
		return ""
	var id: int = ResourceLoader.get_resource_uid(path)
	if id == ResourceUID.INVALID_ID:
		id = ResourceUID.create_id()
		ResourceSaver.set_uid(path, id)
		if ResourceUID.has_id(id):
			ResourceUID.set_id(id, path)
		else:
			ResourceUID.add_id(id, path)
	resource.take_over_path(path)
	if Engine.is_editor_hint() and EditorInterface.get_resource_filesystem() != null:
		EditorInterface.get_resource_filesystem().update_file(path)
	return ResourceUID.id_to_text(id)
