# EventForge - every pack icon is drawn the way Godot draws its own node icons.
#
# 16 x 16, a clear ground (no tile), filled shapes in ONE ink that is a key of Godot's colour map (so a
# flagged import recolours it for the light theme), the ink of the family of the node the pack works
# on, one small dot in the bottom-right corner exactly when the pack declares a host, and no two
# packs sharing the same bytes.
#
# THE ALLOW-LIST ONLY SHRINKS. The packs below still wear their older icon because no drawing of them
# has been accepted yet. Each one must still BREAK a rule (so the list is honest), and the test fails
# the moment one passes: draw it, run tools/build_icons.gd, and delete its line here.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const STYLE := preload("res://tools/icon_style.gd")
const NAME: String = "godot_style_icons_test"
const ADDONS_DIR: String = "res://eventsheet_addons"

## Packs whose drawing is not accepted yet; they keep their older icon until it is. Every pack is drawn
## today, so it is empty, and the mechanism stays for the next pack that lands before its drawing.
const NOT_REDRAWN: PackedStringArray = []


static func run() -> bool:
	var ok: bool = true
	var seen: Dictionary = {}
	var packs: PackedStringArray = DirAccess.get_directories_at(ADDONS_DIR)
	packs.sort()
	for pack: String in packs:
		var path: String = "%s/%s/icon.svg" % [ADDONS_DIR, pack]
		if not FileAccess.file_exists(path):
			ok = SUPPORT.check(NAME, "%s has an icon" % pack, false, true) and ok
			continue
		var svg: String = FileAccess.get_file_as_string(path)
		var problems: PackedStringArray = problems_of(pack, svg, path)
		if NOT_REDRAWN.has(pack):
			ok = SUPPORT.check(NAME, "%s is on the allow-list and still breaks a rule (draw it and delete it from the list)" % pack,
				problems.is_empty(), false) and ok
			continue
		ok = SUPPORT.check(NAME, "%s is drawn in Godot's style" % pack, ", ".join(problems), "") and ok
		var digest: String = svg.md5_text()
		ok = SUPPORT.check(NAME, "%s draws a picture no other pack draws" % pack, str(seen.get(digest, "")), "") and ok
		seen[digest] = pack
	for pack: String in NOT_REDRAWN:
		ok = SUPPORT.check(NAME, "%s on the allow-list is a pack" % pack, packs.has(pack), true) and ok
	# The second icon a pack with 2D and 3D classes carries.
	var path_3d: String = "%s/vector_shapes/icon_3d.svg" % ADDONS_DIR
	ok = SUPPORT.check(NAME, "vector_shapes has a 3D icon", FileAccess.file_exists(path_3d), true) and ok
	if FileAccess.file_exists(path_3d):
		var svg_3d: String = FileAccess.get_file_as_string(path_3d)
		ok = SUPPORT.check(NAME, "the 3D icon of vector_shapes is drawn in Godot's style",
			", ".join(shape_problems("vector_shapes_3d", svg_3d, path_3d, STYLE.INK_3D, false)), "") and ok
		ok = SUPPORT.check(NAME, "the 3D icon is not the 2D one", svg_3d != FileAccess.get_file_as_string("%s/vector_shapes/icon.svg" % ADDONS_DIR), true) and ok
	return ok


## What is wrong with a pack icon, as short phrases ([] when it is in Godot's style).
static func problems_of(pack: String, svg: String, path: String) -> PackedStringArray:
	var host: String = host_of(pack)
	var base: String = host if not host.is_empty() else own_base_of(pack)
	var ink: String = STYLE.family_ink(base)
	if FileAccess.file_exists("%s/%s/icon_3d.svg" % [ADDONS_DIR, pack]):
		ink = STYLE.INK_2D
	return shape_problems(pack, svg, path, ink, not host.is_empty())


## The rules every icon keeps. `ink` is the one ink it must be drawn in, `dot` whether it wears the dot.
static func shape_problems(_owner: String, svg: String, path: String, ink: String, dot: bool) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if not (svg.contains("width=\"16\"") and svg.contains("height=\"16\"") and svg.contains("viewBox=\"0 0 16 16\"")):
		problems.append("not 16 x 16 on a 16 grid")
	if has_tile(svg):
		problems.append("a ground tile")
	if svg.contains("style=") or svg.contains("<style"):
		problems.append("colour outside attributes")
	var inks: PackedStringArray = inks_of(svg)
	if inks.size() != 1:
		problems.append("%d inks" % inks.size())
	elif not STYLE.INKS.has(inks[0]):
		problems.append("ink %s is not in Godot's map" % inks[0])
	elif inks[0] != ink:
		problems.append("ink %s is not the family's %s" % [inks[0], ink])
	if svg.contains(STYLE.DOT_PREFIX) != dot:
		problems.append("the behaviour dot is %s" % ("missing" if dot else "worn by a pack with no host"))
	var import_path: String = path + ".import"
	if not (FileAccess.file_exists(import_path) and FileAccess.get_file_as_string(import_path).contains(STYLE.IMPORT_FLAG)):
		problems.append("the import does not follow the editor theme")
	return problems


## A filled rect that covers 12 x 12 or more is a ground tile, whatever its colour.
static func has_tile(svg: String) -> bool:
	var rect: RegEx = RegEx.create_from_string("<rect[^>]*>")
	for found: RegExMatch in rect.search_all(svg):
		var tag: String = found.get_string(0)
		if tag.contains("fill=\"none\""):
			continue
		if _number(tag, "width") >= 12.0 and _number(tag, "height") >= 12.0:
			return true
	return false


static func _number(tag: String, attribute: String) -> float:
	var found: RegExMatch = RegEx.create_from_string(" %s=\"([0-9.]+)\"" % attribute).search(tag)
	return float(found.get_string(1)) if found != null else 0.0


## The inks an svg is drawn in, written as fill / stroke attributes, lower case, sorted, once each.
static func inks_of(svg: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for hit: RegExMatch in RegEx.create_from_string("(?:fill|stroke)=\"(#[0-9a-fA-F]{6})\"").search_all(svg):
		var ink: String = hit.get_string(1).to_lower()
		if not found.has(ink):
			found.append(ink)
	found.sort()
	return found


## The host a pack's behaviour declares (`var host: X = null`), read from its scripts.
static func host_of(pack: String) -> String:
	var pattern: RegEx = RegEx.create_from_string("(?m)^var host: ([A-Za-z_][A-Za-z0-9_]*) = null$")
	for source: String in _scripts(pack):
		var found: RegExMatch = pattern.search(source)
		if found != null:
			return found.get_string(1)
	return ""


## What a pack with no host works as: the engine class its first named class ends up extending.
static func own_base_of(pack: String) -> String:
	var parents: Dictionary = {}
	var first: String = ""
	for source: String in _scripts(pack):
		var named: RegExMatch = RegEx.create_from_string("(?m)^class_name\\s+(\\S+)").search(source)
		var base: RegExMatch = RegEx.create_from_string("(?m)^extends\\s+(\\S+)").search(source)
		if named != null and base != null:
			parents[named.get_string(1)] = base.get_string(1)
			if first.is_empty():
				first = named.get_string(1)
	var current: String = first
	for _step: int in range(16):
		if current.is_empty() or ClassDB.class_exists(current) or not parents.has(current):
			break
		current = str(parents[current])
	return current


static func _scripts(pack: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var names: PackedStringArray = DirAccess.get_files_at("%s/%s" % [ADDONS_DIR, pack])
	names.sort()
	for file_name: String in names:
		if file_name.ends_with(".gd"):
			out.append(FileAccess.get_file_as_string("%s/%s/%s" % [ADDONS_DIR, pack, file_name]))
	return out
