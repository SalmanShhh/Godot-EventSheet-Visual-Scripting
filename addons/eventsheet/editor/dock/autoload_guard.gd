@tool
extends RefCounted

# A global (an autoload) is a name in Project Settings that the project's own code may already use. The
# plugin adds one in a few places, and none of them may take over a name that already points somewhere
# else: this is the one question they all ask first, and the one small window that puts the choice to
# the person - use another name, or leave it alone.
#
# Loaded by path by the doors that write a global; it has no class_name, so nothing that names it
# compiles it.


## Where the global named `autoload_name` points now when that is NOT `target` ("" when there is no such
## global, or it already points at `target`). The leading "*" that makes a name global is not part of it.
static func held_elsewhere(autoload_name: String, target: String) -> String:
	var key: String = "autoload/%s" % autoload_name
	if not ProjectSettings.has_setting(key):
		return ""
	var held: String = str(ProjectSettings.get_setting(key)).trim_prefix("*")
	return "" if held == target.trim_prefix("*") else held


## The first of `base`, `base2`, `base3`... that no global uses.
static func free_name(base: String) -> String:
	var attempt: int = 1
	while attempt < 100:
		var candidate: String = base if attempt == 1 else "%s%d" % [base, attempt]
		if not ProjectSettings.has_setting("autoload/%s" % candidate):
			return candidate
		attempt += 1
	return base


## The sentence that names the clash, for a status line or a window.
static func clash_words(autoload_name: String, held: String) -> String:
	return EventSheetL10n.translate("There is already a global named %s that loads %s, and it is not replaced.") % [autoload_name, held]


## Asks what to do about a clash: a small window of two sentences with the name to use instead, and a
## Cancel. `on_name` is called with the name the person confirms (never the one that clashes). Nothing is
## written here.
static func ask(host: Node, autoload_name: String, held: String, on_name: Callable) -> Window:
	var parts: Dictionary = EventSheetPopupUI.panel_window(EventSheetL10n.translate("That global name is taken"),
		Vector2i(EventSheetPalette.scaled(520), 0), host, EventSheetL10n.translate("Use this name"))
	var window: ConfirmationDialog = parts["window"]
	var box: VBoxContainer = parts["box"]
	box.add_child(EventSheetPopupUI.hint_label("%s %s" % [clash_words(autoload_name, held),
		EventSheetL10n.translate("Choose another name for the new global, or cancel and nothing changes.")]))
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = free_name(autoload_name)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name"), name_edit))
	var note: EventSheetPopupUI.StateNote = EventSheetPopupUI.StateNote.new()
	box.add_child(note)
	window.confirmed.connect(func() -> void:
		var chosen: String = name_edit.text.strip_edges()
		if chosen.is_empty() or not EventSheetIdentifierRules.is_valid(chosen) or ProjectSettings.has_setting("autoload/%s" % chosen):
			# Kept open would need a second look at the field; the plain way is to ask again with a free name.
			ask(host, autoload_name, held, on_name)
		else:
			on_name.call(chosen))
	window.canceled.connect(window.queue_free)
	window.confirmed.connect(window.queue_free)
	window.popup_centered()
	return window
