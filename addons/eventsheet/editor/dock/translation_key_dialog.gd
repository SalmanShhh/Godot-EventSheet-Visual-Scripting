@tool
class_name EventSheetTranslationKeyDialog
extends RefCounted
# "The source string IS the key" - the offer that follows editing a globe-marked value.
#
# The guide endorses sentences-as-keys, and that style has one sharp edge: editing a marked string
# silently orphans every translation of it. Every finished locale column stops matching at once, the
# lookup misses, tr() returns its argument, and the game quietly reads English again - no error, no
# warning, nothing in the Output panel.
#
# Variables already solved this exact shape with Rename Everywhere…, which walks the project and
# fixes every reference. This is its text twin: committing a change to a globe-marked value offers
# to update the key in the catalogs too, naming which files and which languages change BEFORE
# anything is touched. Declining is a real answer - the orphan report in the Translation Studio then
# names the key nobody says any more, so a rewrite is never silently lost either way.
#
# TWO REFUSALS, BOTH OUT LOUD. A rename onto a key the catalog ALREADY holds is refused rather than
# merged (two sentences would become one, and one translator's work would vanish), and a value that
# is not the canonical marked form is not a key at all. The plan/apply pair lives in
# EventSheetTranslationScan; this is the form around it.

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _message_label: Label = null
var _old_key: String = ""
var _new_key: String = ""
var _plan: Dictionary = {}
## The last refusal this offer spoke, kept so the suite can assert the words the user was given
## rather than the absence of a popup - "it returned false" is what silence and refusal share.
var last_refusal: String = ""


func init(dock: Control) -> void:
	_dock = dock


## Every catalog the offer should walk. The Studio's own file first, then anything the project
## registers - the same files the coverage report reads, so the two can never disagree.
func catalog_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	if _dock != null and _dock.get("_translation_studio") != null:
		var studio_path: String = str(_dock._translation_studio.catalog_path())
		if FileAccess.file_exists(studio_path):
			paths.append(studio_path)
	for path: String in EventSheetGameCatalog.registered_translations():
		if path.get_extension().to_lower() == "csv" and not paths.has(path):
			paths.append(path)
	return paths


## The keys a params edit moved: {old, new} for a value that WAS a marked string and now is a
## different marked string. Anything else (an unmarked value, a value that only gained or lost its
## globe, an unchanged one) is not a key rename and answers {}.
static func renamed_key(before: Variant, after: Variant) -> Dictionary:
	var old_parts: Dictionary = ACEParamsDialog.translatable_parts(str(before))
	var new_parts: Dictionary = ACEParamsDialog.translatable_parts(str(after))
	if not bool(old_parts.get("translatable", false)) or not bool(new_parts.get("translatable", false)):
		return {}
	var old_key: String = str(old_parts.get("text", ""))
	var new_key: String = str(new_parts.get("text", ""))
	if old_key.is_empty() or new_key.is_empty() or old_key == new_key:
		return {}
	return {"old": old_key, "new": new_key}


## The first key rename across a whole params commit - the params dialog writes one value at a time
## per field, and one edit is one offer.
static func renamed_key_in(before: Dictionary, after: Dictionary) -> Dictionary:
	for key: Variant in after.keys():
		if not before.has(key):
			continue
		var moved: Dictionary = renamed_key(before[key], after[key])
		if not moved.is_empty():
			return moved
	return {}


## Offers the rename. Returns true when there is something to offer (a catalog really holds the old
## key) - a project with no catalogs never sees a popup, which is why this can hang off every edit.
func offer(old_key: String, new_key: String) -> bool:
	_old_key = old_key
	_new_key = new_key
	last_refusal = ""
	_plan = EventSheetTranslationScan.rename_plan(old_key, new_key, catalog_paths())
	if (_plan.get("files", []) as Array).is_empty():
		# A REFUSAL IS NOT A NON-EVENT. "No catalog holds this key" is silence on purpose, but a
		# rename onto a key the catalog already holds is the one case the design calls dangerous -
		# the edit lands, the old key becomes an orphan carrying every finished translation, and
		# saying nothing is how that goes unnoticed. rename_plan words it; this is where it is heard.
		var blocked: String = str(_plan.get("blocked", ""))
		if not blocked.is_empty():
			last_refusal = "%s The row now says the new sentence, and the old key keeps its translations - Translation Studio ▸ Notes ▸ Find Orphans lists it." % blocked
			if _dock != null:
				_dock._set_status(last_refusal, true)
		return false
	_build_dialog()
	_message_label.text = "%s\n\nDecline and the old key stays in your catalogs as an orphan - Translation Studio ▸ Notes ▸ Find Orphans lists it." % \
		EventSheetTranslationScan.rename_sentence(_plan, old_key)
	_dialog.title = "Rename the translation key too?"
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(520, 220))
	return true


## Rewrites the key in every catalog the plan named. Separate from `offer` so the suite drives the
## commit without a popup, exactly as the button does.
func confirm() -> Dictionary:
	var outcome: Dictionary = EventSheetTranslationScan.apply_rename(_old_key, _new_key, _plan)
	if _dock != null:
		_dock._set_status(str(outcome.get("message", "")), not bool(outcome.get("ok", false)))
	return outcome


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.ok_button_text = "Update the catalogs"
	_dialog.cancel_button_text = "Leave them"
	_dialog.confirmed.connect(func() -> void: confirm())
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	_message_label = EventSheetPopupUI.hint_label("")
	content.add_child(EventSheetPopupUI.titled_card("Every translation of this sentence", _message_label))
	_dialog.add_child(EventSheetPopupUI.margined(content))
	EventSheetL10n.apply_to(_dialog)
	_dock.add_child(_dialog)
