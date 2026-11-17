# Godot EventSheets - the question asked before something is replaced
#
# One small window for every place the plugin is about to overwrite a file it did not just make:
# two plain sentences naming what will be replaced and where the old version is kept, and two
# buttons. Built with the popup kit so it looks like every other window. Loaded by path from the
# doors that ask, so the editor's first open does not compile it.
@tool
extends RefCounted


## Asks the question and calls `on_yes` only if the reader agrees. `sentences` is what the window
## says (two short sentences at most). Returns the window so a test or a proof can reach its buttons.
## `host` is any node in the tree; when it is null the editor's own base control is used.
static func ask(host: Node, title: String, sentences: String, ok_text: String, on_yes: Callable) -> ConfirmationDialog:
	var anchor: Node = host
	if anchor == null and Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		anchor = (Engine.get_singleton("EditorInterface") as Object).call("get_base_control") as Node
	if anchor == null:
		return null
	var parts: Dictionary = EventSheetPopupUI.panel_window(title, Vector2i(EventSheetPalette.scaled(420), 0),
		anchor, ok_text, Callable(), true)
	var window: ConfirmationDialog = parts["window"]
	window.cancel_button_text = EventSheetL10n.translate("Cancel")
	(parts["box"] as VBoxContainer).add_child(EventSheetPopupUI.panel_section(EventSheetPopupUI.hint_label(sentences)))
	window.confirmed.connect(func() -> void:
		on_yes.call()
		window.queue_free())
	window.canceled.connect(window.queue_free)
	window.close_requested.connect(window.queue_free)
	EventSheetPopupUI.popup_fitted(window)
	return window
