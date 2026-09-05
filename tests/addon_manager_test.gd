# EventForge - the pack catalog, the Add behavior dialog's core, and the quick fixes.
#
# Three things a reader now does from the sheet, pinned at the layer that has no window in it:
#   the list of installed packs (the Addon manager's table and the Add behavior dialog's shelves
#   both read it), the two ways a pack joins an object, and which Doctor findings offer a
#   one-step fix.
#
# The import path is pinned on its REFUSAL rather than on a successful unpack, because the thing
# that matters about importing someone else's archive is that it cannot write outside the packs
# folder.
@tool
class_name AddonManagerTest
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
	all_passed = _check("...and every installed pack starts switched on",
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

	# Switching one off is what takes its actions out of the picker: the scanner asks this.
	all_passed = _check("a path under a switched-on pack is scanned",
		EventSheetPackCatalog.is_disabled_path("res://eventsheet_addons/health/health_behavior.gd"), false) and all_passed
	all_passed = _check("a path outside the packs folder is never a pack's",
		EventSheetPackCatalog.is_disabled_path("res://player.gd"), false) and all_passed

	# The pack's knobs, read from its own source rather than from an instance.
	var knobs: Array[Dictionary] = EventSheetAddBehavior.exported_properties("res://eventsheet_addons/health/health_behavior.gd")
	all_passed = _check("a pack publishes its @export knobs to the Add behavior dialog",
		knobs.size() > 0, true) and all_passed
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

	# Importing someone else's archive: the refusal is the assertion that matters.
	all_passed = _check("a plain pack folder entry is safe to unpack",
		EventSheetAddonManagerDialog.is_safe_entry("my_pack/my_pack.gd"), true) and all_passed
	all_passed = _check("an entry stepping out of the packs folder is refused",
		EventSheetAddonManagerDialog.is_safe_entry("../../project.godot"), false) and all_passed
	all_passed = _check("an absolute entry is refused",
		EventSheetAddonManagerDialog.is_safe_entry("/etc/passwd"), false) and all_passed
	all_passed = _check("a drive-letter entry is refused",
		EventSheetAddonManagerDialog.is_safe_entry("C:/somewhere/else.gd"), false) and all_passed
	# THE COLON IS REFUSED WHEREVER IT IS, not only in front. On Windows a name carrying one opens an
	# ALTERNATE DATA STREAM on the file beside it - content that lands on disk and that no folder
	# listing ever shows - and a colon in the middle of a path is a drive-relative name (`C:pack.gd`
	# means "the current folder of drive C"). Neither is a file name, and the guard already refused
	# both by construction; these say so out loud, because a later guard written for `..` alone would
	# have let them through.
	all_passed = _check("an alternate-data-stream name is refused",
		EventSheetAddonManagerDialog.is_safe_entry("readme.txt:payload"), false) and all_passed
	all_passed = _check("and a colon anywhere further in is refused too",
		EventSheetAddonManagerDialog.is_safe_entry("my_pack/inner:stream.gd"), false) and all_passed
	all_passed = _check("a step out written with backslashes is refused",
		EventSheetAddonManagerDialog.is_safe_entry("..\\..\\project.godot"), false) and all_passed
	all_passed = _check("and a leading backslash is refused",
		EventSheetAddonManagerDialog.is_safe_entry("\\etc\\passwd"), false) and all_passed
	all_passed = _check("a pack that reads shows no score",
		EventSheetAddonManagerDialog.reading_badge_text({"reads_percent": 100}), "") and all_passed
	all_passed = _check("a pack that does not carries it",
		EventSheetAddonManagerDialog.reading_badge_text({"reads_percent": 94}), "reads 94%") and all_passed

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
	all_passed = _check("a switched-off pack still in use offers to switch it back on",
		str(EventSheetQuickFixes.fixes_for({"check": "disabled-pack-in-use", "subject": "health"})[0].get("label", "")),
		"Switch health back on") and all_passed
	all_passed = _check("an unnamed fix is refused rather than half-applied",
		bool(EventSheetQuickFixes.apply("not_a_fix", {}, {}).get("ok", true)), false) and all_passed

	# THE WAY BACK OUT OF AN UPDATE TELLS THE REGISTRY, like the update door beside it. The file a
	# restore puts back can be the pack's own .gd, whose @ace_* annotations ARE the vocabulary - which
	# is the case this door exists for - so a restore that only redrew the manager's own table left
	# the picker offering the words of a version no longer on disk.
	all_passed = _test_a_restore_tells_the_registry() and all_passed
	return all_passed


static func _test_a_restore_tells_the_registry() -> bool:
	var manager: EventSheetAddonManagerDialog = EventSheetAddonManagerDialog.new()
	var told: Array[int] = [0]
	manager.configure(func() -> void: told[0] += 1, Callable(), Callable())
	var said: String = manager.open_restore("eventforge_no_such_pack_here")
	var ok: bool = _check("a pack whose ring holds nothing says so instead of opening a blank page",
		said.begins_with("The backup ring is holding nothing for"), true)
	ok = _check("nothing has been put back, so nothing has been said yet", told[0], 0) and ok
	manager._restore_dialog._on_restored.call("guide.md put back, 31 byte(s).")
	ok = _check("and a restore tells the registry the vocabulary may have moved",
		told[0], 1) and ok
	manager.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("addon_manager_test", label, actual, expected)
