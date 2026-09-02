@tool
class_name EventSheetEditorSettings
extends RefCounted

# THE ONE DOOR TO EditorSettings, opened without naming the editor-only class.
#
# `EditorSettings` and `EditorInterface` exist only in an editor build. A released game that
# carries this plugin's scripts must still PARSE them, so naming either class in a `var` type or
# a static call is a load error waiting in an export. Every caller therefore goes through the
# singleton by name and talks to the result through `call`, which is what the palette does too.
#
# The guard is three questions, and all three have to be asked in this order: is this an editor
# run at all, does the singleton exist, and does it answer to `get_editor_settings`. A build that
# fails any of them gets null back, and every caller here already treats null as "no stored
# preference" rather than an error.
#
# Eight dock helpers each kept their own copy of those three questions. One drifted (it named the
# class directly), which is exactly the drift a copied guard invites, so the guard lives here now
# and the copies are gone.


## The running editor's `EditorSettings`, or null outside the editor. Typed `Object` on purpose:
## the real type is editor-only, and naming it here would be the load error this seam exists to
## avoid. Call into it by name - `settings.call("get_project_metadata", ...)`.
static func current() -> Object:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_settings"):
		return null
	return editor_interface.call("get_editor_settings")


## The bool stored under "eventsheets"/`key` in the project's editor metadata, or null when nobody
## has chosen yet. The default handed to Godot is "" rather than null on purpose: reading a missing
## key with a null default prints an editor ERROR, and "" is a sentinel no caller can mistake for a
## choice. Only a stored bool counts as one, so a value of some other type reads as "not chosen".
static func stored_flag(key: String) -> Variant:
	var settings: Object = current()
	if settings == null:
		return null
	var stored: Variant = settings.call("get_project_metadata", "eventsheets", key, "")
	return stored if stored is bool else null
