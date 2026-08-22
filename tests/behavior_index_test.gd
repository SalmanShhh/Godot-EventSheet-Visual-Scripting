# Godot EventSheets - the Manual's behavior index ("Behaviors, by the name you know").
# One page keyed by the behavior names a reader arrives holding: each row says what the thing is
# here (a shipped pack, or the Godot node that already did the job) and what a hand-written version
# of it reads like on a sheet. Pins: the page id scheme, the entry keys and their values, the pack
# links resolving to real packs, the lookup and the search order, and the page's block shape.
@tool
class_name BehaviorIndexTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# The page ids, both halves of the scheme.
	all_passed = _check("the index page id",
		EventSheetDocReference.doc_id(EventSheetDocReference.KIND_BEHAVIOR_INDEX, ""),
		"reference:behaviors") and all_passed
	all_passed = _check("one behavior's page id",
		EventSheetDocReference.doc_id(EventSheetDocReference.KIND_BEHAVIOR_INDEX, "bullet"),
		"reference:behaviors/bullet") and all_passed
	all_passed = _check("the index page exists",
		EventSheetDocReference.has_page("reference:behaviors"), true) and all_passed
	all_passed = _check("a named behavior page exists",
		EventSheetDocReference.has_page("reference:behaviors/eight-direction"), true) and all_passed
	all_passed = _check("an invented behavior has no page",
		EventSheetDocReference.has_page("reference:behaviors/teleport"), false) and all_passed
	all_passed = _check("the page title",
		EventSheetDocReference.title_for(EventSheetDocReference.KIND_BEHAVIOR_INDEX, "bullet"),
		"Behaviors, by the name you know") and all_passed

	# The entries themselves, by value.
	var bullet: Dictionary = EventSheetDocBehaviorIndex.entry("bullet")
	all_passed = _check("the Bullet row's name", str(bullet.get("name", "")), "Bullet") and all_passed
	all_passed = _check("the Bullet row's pack", str(bullet.get("pack", "")), "bullet") and all_passed
	all_passed = _check("the Turret row points at the weapon pack",
		str(EventSheetDocBehaviorIndex.entry("turret").get("pack", "")), "weapon_kit") and all_passed
	all_passed = _check("the Platform row points at the platformer pack",
		str(EventSheetDocBehaviorIndex.entry("platform").get("pack", "")),
		"platformer_movement") and all_passed
	all_passed = _check("Solid has no pack to attach",
		str(EventSheetDocBehaviorIndex.entry("solid").get("pack", "")), "") and all_passed
	# Batch 14 gave the Pin pack the five modes that were missing, so the row that used to say
	# "no pack needed" now points at the pack that does the whole job.
	all_passed = _check("Pin points at the pin pack",
		str(EventSheetDocBehaviorIndex.entry("pin").get("pack", "")), "pin") and all_passed
	all_passed = _check("No save is the remembering pack's opt-out",
		str(EventSheetDocBehaviorIndex.entry("no-save").get("pack", "")), "save_system") and all_passed
	all_passed = _check("an unknown key answers with nothing",
		EventSheetDocBehaviorIndex.entry("teleport").is_empty(), true) and all_passed

	# Every row is complete, uniquely keyed, and names a pack that really ships.
	var seen: Dictionary = {}
	var complete: int = 0
	var duplicate_keys: int = 0
	var missing_packs: PackedStringArray = PackedStringArray()
	for behavior: Dictionary in EventSheetDocBehaviorIndex.entries():
		var key: String = str(behavior.get("key", ""))
		if seen.has(key):
			duplicate_keys += 1
		seen[key] = true
		if not key.is_empty() and not str(behavior.get("name", "")).is_empty() \
				and not str(behavior.get("here", "")).is_empty() \
				and not str(behavior.get("reading", "")).is_empty():
			complete += 1
		var pack: String = str(behavior.get("pack", ""))
		if not pack.is_empty() and not DirAccess.dir_exists_absolute(
				"res://eventsheet_addons".path_join(pack)):
			missing_packs.append(pack)
	all_passed = _check("every row is complete", complete,
		EventSheetDocBehaviorIndex.BEHAVIORS.size()) and all_passed
	all_passed = _check("no two rows share a key", duplicate_keys, 0) and all_passed
	all_passed = _check("every named pack ships", ",".join(missing_packs), "") and all_passed

	# The pack link is the pack's own reference page.
	all_passed = _check("a behavior links to its pack reference",
		EventSheetDocBehaviorIndex.pack_page_for("move-to"),
		"reference:pack/move_to") and all_passed
	all_passed = _check("a behavior with no pack links nowhere",
		EventSheetDocBehaviorIndex.pack_page_for("anchor"), "") and all_passed

	# Searching the index: the name itself beats the sentence that merely mentions it.
	var found: Array[Dictionary] = EventSheetDocBehaviorIndex.find("bullet")
	all_passed = _check("searching a behavior name answers with it first",
		str(found[0].get("key", "")) if not found.is_empty() else "", "bullet") and all_passed
	all_passed = _check("an empty query lists every behavior",
		EventSheetDocBehaviorIndex.find("").size(),
		EventSheetDocBehaviorIndex.BEHAVIORS.size()) and all_passed

	# The page's shape: title, lead, then one chapter per behavior.
	var blocks: Array[Dictionary] = EventSheetDocBehaviorIndex.blocks()
	all_passed = _check("the page opens with its title",
		str(blocks[0].get("text", "")), "Behaviors, by the name you know") and all_passed
	var chapters: int = 0
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) == "heading" and int(block.get("level", 0)) == 2:
			chapters += 1
	all_passed = _check("one chapter per behavior", chapters,
		EventSheetDocBehaviorIndex.BEHAVIORS.size()) and all_passed

	# The breadcrumb lands the reader in the index rather than in the glossary.
	var crumbs: PackedStringArray = EventSheetDocReference.breadcrumb("reference:behaviors/rotate",
		"Behaviors, by the name you know")
	all_passed = _check("the breadcrumb names the Manual then the index",
		"/".join(crumbs), "Manual/Behaviors, by the name you know") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] behavior_index_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
