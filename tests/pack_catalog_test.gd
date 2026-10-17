# EventForge - the pack catalog, the Add behavior dialog's core, and the quick fixes.
#
# A pack is a folder of ordinary scripts under eventsheet_addons/: it is installed by being there
# and removed by deleting the folder. Pinned here at the layer that has no window in it:
#   the list of installed packs (the Add behavior dialog's shelves read it), the two ways a pack
#   joins an object, which Doctor findings offer a one-step fix, and that the old way of switching
#   a pack off is gone - the scanner ignores the setting, the Doctor notes it once, and no menu or
#   palette entry offers a window for managing packs.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true
	var packs: Array[Dictionary] = EventSheetPackCatalog.packs()
	all_passed = _check("the catalog finds the shipped packs", packs.size() > 50, true) and all_passed
	var health: Dictionary = EventSheetPackCatalog.describe("health")
	all_passed = _check("a pack is described by its own file - the script it publishes from",
		str(health.get("path", "")), "res://eventsheet_addons/health/health_behavior.gd") and all_passed
	all_passed = _check("...its shelf comes from its own @ace_category",
		str(health.get("category", "")), "Health") and all_passed
	all_passed = _check("...its version from its own @ace_version",
		str(health.get("version", "")), "1.0.0") and all_passed
	all_passed = _check("...and every installed pack is in use",
		bool(health.get("enabled", false)), true) and all_passed
	all_passed = _check("a pack with no @ace_inline_capable is attachable only",
		bool(health.get("inline_capable", true)), false) and all_passed

	all_passed = _check("the search reads a pack's name, pitch and folder",
		EventSheetPackCatalog.filtered([
			{"name": "Platformer", "pitch": "jump, run, coyote", "dir": "platformer_movement", "category": "Movement"},
			{"name": "Health", "pitch": "damage and death", "dir": "health", "category": "Health"},
		], "", "coyote").size(), 1) and all_passed
	all_passed = _check("a shelf shows only its own packs",
		EventSheetPackCatalog.filtered([
			{"name": "Platformer", "pitch": "", "dir": "a", "category": "Movement"},
			{"name": "Health", "pitch": "", "dir": "b", "category": "Health"},
		], "Health", "").size(), 1) and all_passed
	all_passed = _check("a pack that declares no shelf lands on Other",
		EventSheetPackCatalog.categories([{"name": "X", "dir": "x", "category": ""}]),
		PackedStringArray(["Other"])) and all_passed

	all_passed = _test_the_old_switch_is_ignored() and all_passed
	all_passed = _test_no_door_names_a_pack_manager() and all_passed

	# The pack's knobs, read from its own source rather than from an instance.
	var knobs: Array[Dictionary] = EventSheetAddBehavior.exported_properties("res://eventsheet_addons/health/health_behavior.gd")
	all_passed = _check("a pack publishes its @export knobs to the Add behavior dialog",
		knobs.size() > 0, true) and all_passed
	all_passed = _check("a knob is labelled with its own name, as the pack wrote it",
		str(knobs[0].get("name", "")) if not knobs.is_empty() else "", "max_health") and all_passed
	# The card highlight follows the pack's FOLDER, so a name that begins another pack's name never
	# lights both up.
	var behavior_dialog: EventSheetAddBehaviorDialog = EventSheetAddBehaviorDialog.new()
	var two_packs: Array[Dictionary] = [
		{"name": "Platformer", "dir": "platformer", "category": "Movement"},
		{"name": "Platformer Pathfinding", "dir": "platformer_pathfinding", "category": "Movement"},
	]
	behavior_dialog._packs = two_packs
	behavior_dialog._selected_dir = "platformer"
	behavior_dialog._rebuild_list()
	behavior_dialog._rebuild_list_selection()
	var lit: PackedStringArray = PackedStringArray()
	for tile: Button in behavior_dialog.tiles():
		if tile.button_pressed:
			lit.append(str(tile.get_meta("pack_dir")))
	all_passed = _check("picking Platformer lights Platformer alone", lit, PackedStringArray(["platformer"])) and all_passed
	behavior_dialog._selected_dir = "platformer_pathfinding"
	behavior_dialog._rebuild_list_selection()
	lit.clear()
	for tile: Button in behavior_dialog.tiles():
		if tile.button_pressed:
			lit.append(str(tile.get_meta("pack_dir")))
	all_passed = _check("...and the longer name alone when it is the pick", lit,
		PackedStringArray(["platformer_pathfinding"])) and all_passed
	# A card a pack listed as switched off in an older project is an ordinary card now.
	var listed_off: Array[Dictionary] = [{"name": "Health", "dir": "health", "category": "Health", "enabled": false}]
	behavior_dialog._packs = listed_off
	behavior_dialog._rebuild_list()
	var greyed: Array = []
	for tile: Button in behavior_dialog.tiles():
		greyed.append(tile.disabled)
	all_passed = _check("no pack tile is ever greyed out as switched off", greyed, [false]) and all_passed
	behavior_dialog.free()
	all_passed = _check("a field's text becomes the value the property wants",
		EventSheetAddBehavior.parse_value("200", "float"), 200.0) and all_passed
	all_passed = _check("...including a flag", EventSheetAddBehavior.parse_value("true", "bool"), true) and all_passed
	all_passed = _check("...and a quoted string",
		EventSheetAddBehavior.parse_value("\"idle\"", "String"), "idle") and all_passed
	all_passed = _check("adding to nothing says what to do first",
		str(EventSheetAddBehavior.attach_node({"name": "Health"}, null, {}).get("message", "")),
		"Pick the object to add the behavior to first.") and all_passed
	all_passed = _check("a pack that does not declare it can be written in refuses to be",
		bool(EventSheetAddBehavior.write_into_sheet({"name": "Health", "inline_capable": false},
			EventSheetResource.new(), {}).get("ok", true)), false) and all_passed

	# The one-step fixes: which finding offers what, in the words the chip shows.
	var unknown_control: Dictionary = {"check": "unknown-input-action", "subject": "dash", "path": "res://player.gd"}
	var offered: Array[Dictionary] = EventSheetQuickFixes.fixes_for(unknown_control)
	all_passed = _check("an unknown control offers two answers", offered.size(), 2) and all_passed
	all_passed = _check("the first names the control it would add",
		str(offered[0].get("label", "")), "Add \"dash\" to the Input Map") and all_passed
	all_passed = _check("the second offers the ones that exist",
		str(offered[1].get("label", "")), "Pick an existing action…") and all_passed
	all_passed = _check("a finding with no one-step answer offers none",
		EventSheetQuickFixes.fixes_for({"check": "generated-output-drift"}).size(), 0) and all_passed
	all_passed = _check("...and says so when asked",
		EventSheetQuickFixes.has_fix({"check": "generated-output-drift"}), false) and all_passed
	all_passed = _check("the old-setting note offers no switch to flip",
		EventSheetQuickFixes.fixes_for({"check": "old-disabled-packs-setting", "subject": "health"}).size(), 0) and all_passed
	all_passed = _check("an unnamed fix is refused rather than half-applied",
		bool(EventSheetQuickFixes.apply("not_a_fix", {}, {}).get("ok", true)), false) and all_passed

	# The Doctor's fix rows are the only door a fix has: a built-in fix and an extension's own fix
	# both become one.
	var ids_of: Callable = func(finding: Dictionary) -> Array:
		return EventSheetProjectDoctorPanel.offers_for(finding).map(func(offer: Dictionary) -> String:
			return str(offer.get("id", "")))
	all_passed = SUPPORT.pins("pack_catalog_test", [
		["a finding's one built-in fix is offered",
			ids_of.call({"check": "raw-call-has-action", "path": "res://player.gd"}), ["convert_raw_call"]],
		["a finding with several fixes offers each", ids_of.call(unknown_control),
			["add_input_action", "pick_input_action"]],
		["a finding with no fix offers none", ids_of.call({"check": "generated-output-drift"}), []],
		["an extension's own fix is offered too", ids_of.call(
			{"check": "an-extension-check", "fix": func(_finding: Dictionary) -> void: pass}), [""]],
	]) and all_passed
	return all_passed


## An older project may still carry the setting that used to switch a pack off. The scanner no
## longer reads it, so the pack it lists stays in the picker; the Doctor says so once, quietly.
static func _test_the_old_switch_is_ignored() -> bool:
	var setting: String = EventSheetPackCatalog.DISABLED_SETTING
	var had: bool = ProjectSettings.has_setting(setting)
	var before: Variant = ProjectSettings.get_setting(setting) if had else null
	var quiet: Array[Dictionary] = []
	ProjectSettings.set_setting(setting, null)
	EventSheetProjectDoctor.check_old_disabled_packs_setting(quiet)
	ProjectSettings.set_setting(setting, PackedStringArray(["health"]))
	var scripts: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	var noted: Array[Dictionary] = []
	EventSheetProjectDoctor.check_old_disabled_packs_setting(noted)
	var rows: Array = [
		["the scanner still lists a pack the old setting names",
			scripts.has("res://eventsheet_addons/health/health_behavior.gd"), true],
		["the catalog reports no pack switched off", EventSheetPackCatalog.disabled_packs(), PackedStringArray()],
		["...and no path as belonging to one",
			EventSheetPackCatalog.is_disabled_path("res://eventsheet_addons/health/health_behavior.gd"), false],
		["...every pack answers as in use", EventSheetPackCatalog.is_enabled("health"), true],
		["the old setting's own value is still readable for the Doctor",
			EventSheetPackCatalog.legacy_disabled_setting(), PackedStringArray(["health"])],
		["the Doctor notes the old setting once", noted.size(), 1],
		["...as a quiet note", str(noted[0].get("severity", "")) if not noted.is_empty() else "", "info"],
		["...under its own check", str(noted[0].get("check", "")) if not noted.is_empty() else "",
			"old-disabled-packs-setting"],
		["...saying what to do instead", str(noted[0].get("message", "")) if not noted.is_empty() else "",
			"This project still has the old disabled-packs setting (eventsheets/addons/disabled_packs, listing health). It is ignored now, so those packs are back in the picker. To remove a pack, delete its folder under eventsheet_addons/ instead, then delete the setting."],
		["a project without the setting hears nothing", quiet.size(), 0],
	]
	# set_enabled is a harmless no-op now: it must not write the setting back.
	EventSheetPackCatalog.set_enabled("health", true)
	rows.append(["switching a pack on through the old call changes nothing",
		EventSheetPackCatalog.legacy_disabled_setting(), PackedStringArray(["health"])])
	ProjectSettings.set_setting(setting, before)
	return SUPPORT.pins("pack_catalog_test", rows)


## No menu item and no palette command offers a window for managing packs: the packs are folders,
## and the FileSystem dock is where a folder is seen.
static func _test_no_door_names_a_pack_manager() -> bool:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	editor.setup(EventSheetResource.new())
	var items: PackedStringArray = PackedStringArray()
	var tooltips: PackedStringArray = PackedStringArray()
	_collect_menu_items(editor, items, tooltips)
	var palette: PackedStringArray = PackedStringArray()
	for command: Dictionary in editor._command_palette_commands():
		palette.append(str(command.get("title", "")))
	var named: PackedStringArray = PackedStringArray()
	for text: String in items + palette:
		var lowered: String = text.to_lower()
		if lowered.contains("addon manager") or lowered.contains("installed packs") 				or lowered.contains("manage packs"):
			named.append(text)
	# A tooltip may say "installed packs" in passing; what it must not do is describe the manager's
	# chores, which is how a stale one outlived its removed item.
	for text: String in tooltips:
		var lowered: String = text.to_lower()
		if lowered.contains("addon manager") or lowered.contains("enable or disable") 				or lowered.contains("check for updates") or lowered.contains("import a pack"):
			named.append(text)
	var ok: bool = SUPPORT.pins("pack_catalog_test", [
		# The walk must have reached the real Tools menu, or "nothing named" would prove nothing.
		["the walk reads the Tools menu", items.has("Lift Workbench…"), true],
		["the walk reads the Tools menu's tooltips", tooltips.size() > 0, true],
		["no menu item, tooltip or palette command names a pack manager", named, PackedStringArray()],
		["the dock has no manager door left", editor.has_method("open_addon_manager"), false],
	])
	editor.free()
	return ok


static func _collect_menu_items(node: Node, into: PackedStringArray, tooltips: PackedStringArray) -> void:
	if node is PopupMenu:
		var menu: PopupMenu = node as PopupMenu
		for index: int in range(menu.item_count):
			into.append(menu.get_item_text(index))
			var tooltip: String = menu.get_item_tooltip(index)
			if not tooltip.is_empty():
				tooltips.append(tooltip)
	for child: Node in node.get_children(true):
		_collect_menu_items(child, into, tooltips)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("pack_catalog_test", label, actual, expected)
