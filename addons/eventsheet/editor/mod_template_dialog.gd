@tool
class_name EventSheetModTemplateDialog
extends RefCounted

# The door onto Export Mod Template: the starter mod folder a game hands its modders.
#
# It is a THIN SHELL. Everything it does is EventSheetModTemplateTool, which touches no editor at
# all; this file is the fields, the strip that says what the tool will and will not write, and the
# receipt afterwards. Nothing is written until the button is pressed.

const TITLE := "Export Mod Template"


var _dialog: ConfirmationDialog = null
var _form: EventSheetFieldForm = null
var _parent: Node = null


## Opens the door. `folder` prefills where the template goes, for a caller that already knows.
func open(parent: Node, folder: String = "") -> void:
	_parent = parent
	_build(folder)
	_dialog.popup_centered(Vector2i(560, 460))


func _build(folder: String) -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = ConfirmationDialog.new()
	_dialog.title = TITLE
	_dialog.ok_button_text = "Write template"
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	_form = EventSheetPopupUI.form(content, _specs(folder), "mod template")
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip(
		"What this writes", _help_body(), "", "")
	content.add_child(strip)
	_follow_fields(strip)
	_dialog.add_child(EventSheetPopupUI.titled_card(
		"The folder a modder copies, with its manifest already filled in", content))
	_dialog.confirmed.connect(_on_confirmed)
	# The dialog parents to the editor base control (outside the dock's translation domain), so it
	# claims the plugin domain itself and its strings auto-translate.
	EventSheetL10n.apply_to(_dialog)
	_parent.add_child(_dialog)


## The fields, in the order somebody fills them: where it goes, then the five the manifest holds,
## then the two choices about what else lands beside it.
func _specs(folder: String) -> Array[EventSheetFieldSpec]:
	var specs: Array[EventSheetFieldSpec] = []
	specs.append(EventSheetPopupUI.path_field("folder", "Template folder")
		.default(folder if not folder.is_empty() else "res://mod_template")
		.placeholder("res://mod_template")
		.tooltip("Where the template is written. Keep it out of the folder the game loads mods from - it is the example, not a mod."))
	specs.append(EventSheetPopupUI.text_field("name", "Mod name")
		.default("Example Mod")
		.tooltip("What a mod list calls it. A modder renames this first; blank means the folder's own name is used."))
	specs.append(EventSheetPopupUI.text_field("version", "Version")
		.default("1.0")
		.tooltip("The mod's own version, in whatever spelling its author uses. Nothing here compares two of them."))
	specs.append(EventSheetPopupUI.text_field("author", "Author")
		.default("Your name here")
		.tooltip("The credit line beside the name."))
	specs.append(EventSheetPopupUI.text_field("replaces", "Replaces")
		.default("nothing yet")
		.tooltip("What the mod replaces, in the author's own words. Nothing reads it: it is the sentence a player reads before switching two mods on together."))
	specs.append(EventSheetPopupUI.text_field("content", "Content folder")
		.default(EventSheetModTemplateTool.DEFAULT_CONTENT_FOLDER)
		.tooltip("The subfolder the template suggests for a mod's data assets, made empty beside the manifest. Leave it blank for no suggestion."))
	specs.append(EventSheetPopupUI.check_field("scripts", "Carries code")
		.default(false)
		.tooltip("Ticks the manifest's scripts flag. A data-only load refuses such a mod - and it checks the mod's actual files as well, so leaving this off hides nothing."))
	specs.append(EventSheetPopupUI.check_field("resource", "Also save a mod.tres")
		.default(true)
		.tooltip("Saves the same five fields as a ModManifest resource beside the JSON, for a modder who works inside Godot. Needs the ModManifest the Mods pack ships."))
	return specs


## Every field says what it is for as it is reached, and the foot says what the button will write
## with what is typed NOW. A strip nothing is wired to describes the dialog's opening state for
## ever, which reads as an explanation and is really a decoration - so the heading and the words
## come from each field's own label and tooltip, and there is one place a field's wording lives.
func _follow_fields(strip: EventSheetPopupUI.HelpStrip) -> void:
	for field_id: String in _form.field_ids():
		var spec: EventSheetFieldSpec = _form.spec(field_id)
		var control: Control = _form.control(field_id)
		if spec == null or control == null:
			continue
		strip.follow(control, spec.label, spec.tooltip_text)
		var reread: Callable = func() -> void: _refresh_reading(strip)
		control.focus_entered.connect(reread)
		control.mouse_entered.connect(reread)
	_refresh_reading(strip)


## The two reading lines: the mod this writes, as one sentence, and the manifest file it writes it
## into. Read off the form each time, so a reader who has just renamed the folder sees that folder.
func _refresh_reading(strip: EventSheetPopupUI.HelpStrip) -> void:
	var values: Dictionary = _form.values()
	var folder: String = str(values.get("folder", "")).rstrip("/")
	var carries: String = "carrying code" if bool(values.get("scripts", false)) else "data only"
	strip.set_reading("Write %s %s into %s, %s" % [str(values.get("name", "")),
		str(values.get("version", "")), folder, carries],
		"%s/mod.json%s" % [folder, " + mod.tres" if bool(values.get("resource", true)) else ""])


## What lands on disk, said before the button rather than discovered after it.
func _help_body() -> String:
	return "Three things go into the folder: mod.json with these fields in it, a README saying what each field means and what a mod carrying code costs the player who runs it, and an empty content folder. Nothing is written over: a folder that already holds a manifest is refused whole, because it is already somebody's mod."


func _on_confirmed() -> void:
	var values: Dictionary = _form.values()
	var receipt: Dictionary = EventSheetModTemplateTool.export_template(
		str(values.get("folder", "")), values, str(values.get("content", "")),
		bool(values.get("resource", true)))
	EventSheets.set_status(EventSheetModTemplateTool.receipt_words(receipt),
		not str(receipt.get("problem", "")).is_empty())
	EventSheets.refresh()
