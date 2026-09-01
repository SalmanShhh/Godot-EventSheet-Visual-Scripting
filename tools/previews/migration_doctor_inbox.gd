# Godot EventSheets - the Doctor's Migration section over a staged project (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The rows are drawn by the Project Doctor window's OWN inbox filler, so what is photographed is the
# page a reader gets rather than a lookalike of it.
#
# THE PROJECT IS STAGED rather than borrowed: this repository's own sheets are all written in the
# spelling the vocabulary uses today, which is exactly the state that produces a page with nothing on
# it. These two sheets are what a project that has been around a while looks like - most rows migrate
# without asking anybody anything, one holds a verb the vocabulary no longer has at all.
#
# Nothing is written under res://: the sheets live in user:// and are deleted once the picture is
# taken.
@tool
extends RefCounted

const PREVIEW_NAME: String = "migration-doctor-inbox"
const PREVIEW_SIZE: Vector2i = Vector2i(1280, 520)

const STAGED_DIR: String = "user://migration_preview_project"
const OLD_PROVIDER: String = "InputBindings"


static func build(host: Window) -> Control:
	var paths: PackedStringArray = _stage()
	var known: Dictionary = _vocabulary()
	var findings: Array[Dictionary] = EventSheetMigrationDoctor.report(paths, known)
	findings.append_array(EventSheetMigrationDoctor.sheet_lines(
		EventSheetMigrationDoctor.rows(paths, known)))
	_unstage(paths)
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.columns = 4
	tree.set_column_title(0, "New")
	tree.set_column_title(1, "Section")
	tree.set_column_title(2, "Where")
	tree.set_column_title(3, "Finding")
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 40)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 190)
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(2, 220)
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Triaged against an EMPTY read, so every line wears its "new since you last looked" mark: the
	# picture is of a page somebody is opening for the first time.
	EventSheetProjectDoctorPanel.fill_inbox(tree, tree.create_item(),
		EventSheetDoctorInbox.triage(findings, PackedStringArray()))
	var page: VBoxContainer = EventSheetPopupUI.form_box()
	var card: PanelContainer = EventSheetPopupUI.titled_card("Inbox", tree)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(card)
	# The one chip a per-sheet line offers, drawn the way the panel draws it: a way in to that
	# sheet's own receipt, never a rewrite from the report.
	var chips: HBoxContainer = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	for offer: Dictionary in EventSheetQuickFixes.fixes_for({
			"check": EventSheetMigrationDoctor.CHECK_SHEET,
			"path": STAGED_DIR.path_join("options_screen.tres")}):
		var chip: Button = Button.new()
		chip.text = "%s %s" % [EventSheetL10n.translate("Fix:"), str(offer.get("label", ""))]
		chips.add_child(chip)
	page.add_child(chips)
	var body: MarginContainer = EventSheetPopupUI.margined(page)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(body)
	return body


## The vocabulary the staged sheets were written against: everything installed, plus the verb that
## used to be here and the address it carries.
static func _vocabulary() -> Dictionary:
	var known: Dictionary = EventForgeSuccessors.catalog().duplicate()
	known["%s::ClearBinding" % OLD_PROVIDER] = {
		"key": "%s::ClearBinding" % OLD_PROVIDER, "name": "Clear binding",
		"template": "InputMap.action_erase_events({control})",
		"display_template": "Clear the bindings for {control}",
		"needs_baking": false, "ace_type": ACEDefinition.ACEType.ACTION,
		"params": PackedStringArray(["control"]),
		"declared_defaults": {"control": "\"ui_accept\""},
		"answered_by_default": PackedStringArray(["control"]),
		"map": {"id": "Core::ActionEraseEvents", "renames": {"control": "action"}, "defaults": {}},
	}
	return known


## Writes the staged sheets and hands back their paths, sorted - the order the section reads them in.
static func _stage() -> PackedStringArray:
	DirAccess.make_dir_recursive_absolute(STAGED_DIR)
	var paths: PackedStringArray = PackedStringArray()
	paths.append(_write("options_screen.tres", [
		_old_row("\"jump\""), _old_row("\"fire\""), _old_row("\"crouch\""), _gone_row()]))
	paths.append(_write("title_screen.tres", [_old_row("\"start\""), _old_row("\"quit\"")]))
	paths.sort()
	return paths


static func _write(file_name: String, rows: Array) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	for row: Variant in rows:
		event.actions.append(row as Resource)
	sheet.events.append(event)
	var path: String = STAGED_DIR.path_join(file_name)
	ResourceSaver.save(sheet, path)
	return path


static func _old_row(control: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = OLD_PROVIDER
	action.ace_id = "ClearBinding"
	action.codegen_template = "InputMap.action_erase_events({control})"
	action.display_text = "Clear the bindings for {control}"
	action.params = {"control": control}
	return action


## The row that asks somebody a question: a verb from a pack this project no longer installs.
static func _gone_row() -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "LightFlicker"
	action.ace_id = "FlickerLight"
	action.codegen_template = "flicker({light}, {amount})"
	action.display_text = "Flicker {light} by {amount}"
	action.params = {"light": "$Lamp", "amount": "0.4"}
	return action


static func _unstage(paths: PackedStringArray) -> void:
	for path: String in paths:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(STAGED_DIR)
