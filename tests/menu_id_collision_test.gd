# EventSheets test - no two items in one menu may share an id.
#
# The bug this exists for shipped three times in one merge. Each parcel appended its block to the
# View menu, each wrote "id 9801 is clear of every block above", and each was right when it was
# written. After the merge, Auto-apply while debugging, Arrange by and Follow Scene Selection all
# answered to 9801: a click on either check item ran BOTH handlers, `get_item_index(9801)` always
# found the first of the three, so one item's tick and tooltip were written onto another, and the
# View ▸ Minimap item (which shared 27 with the Patterns lens) was completely dead - a `match` takes
# its first arm, so clicking Minimap toggled Patterns.
#
# None of that is visible to a test that builds the dock and calls a handler, because every handler
# works perfectly; it is the ROUTING that is wrong. So this reads the menu source instead and holds
# one rule: within a single PopupMenu, a literal id appears once. Ids computed at runtime
# (`100 + index`, `mode`) are the submenus' own private ranges and are deliberately skipped - they
# are rebuilt from scratch on every open and never mix with a literal.
@tool
class_name MenuIdCollisionTest
extends RefCounted

## The files whose menus are pinned. menu_bar.gd is where the collisions happened; the row context
## menus next to it are built from named consts, which this same walk checks for reuse.
const MENU_FILES: Array[String] = [
	"res://addons/eventsheet/editor/dock/menu_bar.gd",
	"res://addons/eventsheet/editor/dock/context_menus.gd",
]

## The calls that put an item in a menu. `add_submenu_item` takes the submenu NAME before its id,
## which is why the id is matched as "the last literal argument" rather than by position.
const ADD_CALLS: Array[String] = [
	"add_item", "add_check_item", "add_radio_check_item", "add_submenu_item",
	"add_icon_item", "add_separator",
]


static func run() -> bool:
	var all_passed: bool = true
	var collisions: PackedStringArray = PackedStringArray()
	for path: String in MENU_FILES:
		for line: String in _collisions_in(path):
			collisions.append(line)
	all_passed = _check("no two items in one menu share an id", collisions,
		PackedStringArray()) and all_passed
	# The four ids the merge collided on, pinned by VALUE so a future append that reuses one of them
	# fails here with the name of the item it would have killed.
	var view_ids: Dictionary = _ids_by_label("res://addons/eventsheet/editor/dock/menu_bar.gd", "view_popup")
	all_passed = _check("View ▸ Patterns keeps 27", view_ids.get("Patterns"), 27) and all_passed
	all_passed = _check("View ▸ Minimap has its own id", view_ids.get("Minimap"), 46) and all_passed
	all_passed = _check("View ▸ Auto-apply while debugging keeps 9801",
		view_ids.get("Auto-apply while debugging"), 9801) and all_passed
	all_passed = _check("View ▸ Follow Scene Selection has its own id",
		view_ids.get("Follow Scene Selection"), 9805) and all_passed
	all_passed = _check("View ▸ Saved Views keeps 9802", view_ids.get("Saved Views"), 9802) and all_passed
	all_passed = _check("View ▸ Debugger… has its own id", view_ids.get("Debugger…"), 9806) and all_passed
	all_passed = _check("View ▸ Arrange by has its own id", view_ids.get("Arrange by"), 9807) and all_passed
	# Every id a handler in this file answers to must be an id some item in this file carries. A
	# handler on a number nothing adds is dead code that reads like a working feature. Scoped to the
	# whole file rather than to one menu, because the handlers are lambdas and the source cannot say
	# which popup a bare `10:` arm belongs to.
	var menu_source: String = "res://addons/eventsheet/editor/dock/menu_bar.gd"
	var added: Dictionary = {}
	for line: String in _lines(menu_source):
		var entry: Dictionary = _parse_add(line)
		if not entry.is_empty():
			added[int(entry["id"])] = true
	var orphans: PackedStringArray = PackedStringArray()
	for id: Variant in _dispatched_ids(menu_source):
		if not added.has(int(id)):
			orphans.append(str(id))
	all_passed = _check("no menu handler answers to an id no item carries", orphans,
		PackedStringArray()) and all_passed
	return all_passed


## Every duplicate literal id, as "<file>: <menu>.<id> used N times". One line per collision so a
## failure names the menu and the number rather than a count.
static func _collisions_in(path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}  # "<menu>|<id>" -> how many items carry it
	for line: String in _lines(path):
		var entry: Dictionary = _parse_add(line)
		if entry.is_empty():
			continue
		var key: String = "%s|%d" % [entry["menu"], entry["id"]]
		seen[key] = int(seen.get(key, 0)) + 1
	var keys: Array = seen.keys()
	keys.sort()
	for key: Variant in keys:
		if int(seen[key]) > 1:
			out.append("%s: %s used %d times" % [path.get_file(), str(key), int(seen[key])])
	return out


## label -> id, for one menu variable in one file.
static func _ids_by_label(path: String, menu: String) -> Dictionary:
	var out: Dictionary = {}
	for line: String in _lines(path):
		var entry: Dictionary = _parse_add(line)
		if entry.is_empty() or str(entry["menu"]) != menu:
			continue
		out[str(entry["label"])] = int(entry["id"])
	return out


## The literal ids a `match`/`if` arm in the file's id_pressed handlers answers to. Only the plain
## `<number>: _dock.…` and `if id == <number>` shapes, which is every arm the View menu uses.
static func _dispatched_ids(path: String) -> Array:
	var out: Array = []
	var arm := RegEx.new()
	arm.compile("^\\s*(\\d+):\\s*_dock\\.")
	var compare := RegEx.new()
	compare.compile("^\\s*if id ==? (\\d+):")
	for line: String in _lines(path):
		var hit: RegExMatch = arm.search(line)
		if hit == null:
			hit = compare.search(line)
		if hit != null:
			out.append(int(hit.get_string(1)))
	return out


## One `<menu>.add_*("Label", <literal id>)` line, or {} for anything else. A separator, an id-less
## call and a computed id all read as "not a literal item" and are skipped.
static func _parse_add(line: String) -> Dictionary:
	var call := RegEx.new()
	call.compile("(\\w+)\\.(add_\\w+)\\(\"([^\"]*)\"(?:,\\s*\"[^\"]*\")?,\\s*(-?\\d+)\\)")
	var hit: RegExMatch = call.search(line)
	if hit == null:
		return {}
	if not ADD_CALLS.has(hit.get_string(2)):
		return {}
	var id: int = int(hit.get_string(4))
	if id < 0:
		return {}  # the "No workspaces yet" placeholder, deliberately unreachable
	return {"menu": hit.get_string(1), "label": hit.get_string(3), "id": id}


static func _lines(path: String) -> PackedStringArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n")


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] menu_id_collision_test: %s" % label)
		return true
	print("[FAIL] menu_id_collision_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
