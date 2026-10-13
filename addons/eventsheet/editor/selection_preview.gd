@tool
extends RefCounted

# Godot EventSheets - the shell every selection-driven editor preview shares (the drawing gizmos and
# the behaviour gizmos). It follows EditorSelection.selection_changed rather than claiming nodes with
# a main-screen `_handles()`, which would pull Godot away from the EventSheet workspace whenever such
# a node was selected, and keeps at most ONE transient preview node: added with no owner, so it is
# never written to the scene file and is gone the instant the selection moves.
#
# A preview script extends this by path and answers `_preview_for()` for the one selected node.
# DELIBERATELY NO `class_name`: the previews load at editor boot, and this stays a plain file they
# reach by path.

var _editor_interface: EditorInterface = null
var _preview: Node = null


## Wires the preview to editor selection and previews the current selection. Called from the plugin's
## _enter_tree; a null interface (non-editor context) is a safe no-op.
func init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface
	if _editor_interface == null:
		return
	var selection: EditorSelection = _editor_interface.get_selection()
	if selection != null and not selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.connect(_on_selection_changed)
	_on_selection_changed()


## Drops any live preview and disconnects from selection, so a disabled plugin leaves the edited scene
## byte-identical to how it found it.
func teardown() -> void:
	_clear_preview()
	if _editor_interface != null:
		var selection: EditorSelection = _editor_interface.get_selection()
		if selection != null and selection.selection_changed.is_connected(_on_selection_changed):
			selection.selection_changed.disconnect(_on_selection_changed)
	_editor_interface = null


## Rebuilds the preview: exactly one selected node is offered to `_preview_for()`; every other
## selection just clears it.
func _on_selection_changed() -> void:
	_clear_preview()
	if _editor_interface == null:
		return
	var selected: Array[Node] = _editor_interface.get_selection().get_selected_nodes()
	if selected.size() == 1:
		_preview_for(selected[0])


## The one selected node, offered for a preview. Each preview script answers it.
func _preview_for(_node: Node) -> void:
	pass


## Puts `node` under `host` as the live preview, with no owner so it is never serialized.
func _show_preview(host: Node, node: Node) -> void:
	host.add_child(node)
	node.owner = null
	_preview = node


## Removes the live preview, if any.
func _clear_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		if _preview.get_parent() != null:
			_preview.get_parent().remove_child(_preview)
		_preview.queue_free()
	_preview = null
