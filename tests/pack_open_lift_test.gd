# Godot EventSheets - every shipped pack opens as a sheet WITH its verbs.
#
# Opening a pack .gd the way the dock does (GDScriptImporter.import_external) must lift its
# published verbs into EventFunctions (the two-lane verb rows) rather than leaving them as
# annotation-shell code blocks - and the reopened sheet must compile back to the exact bytes.
# Measured 2026-08-17 before the fix: 38 of 91 packs opened with ZERO verbs (the FPS Controller,
# Save System, Storylet Weaver, ...) because a lifecycle handler after the verbs, an unknown
# codegen prefix, a class doc glued to the first verb, a Toggle over-match or one bad body each
# reverted the WHOLE file. This pins that none of it comes back.
#
# WHY THERE IS NO LIVE COUNT PINNED HERE. The claim this file exists to make is per pack - THIS
# pack opens with THESE verbs - and that is asserted once per pack inside the walk below, on every
# pack, every run. A fleet-wide total asserted with == is a different and much weaker claim, and it
# is one every concurrent pack pass has to come and edit before its own work can go green: the
# fleet grows by a pack whenever anyone ships one, so an equality on the size of the fleet is a
# merge conflict with a test name on it, and it goes stale the moment a pack lands. So the totals
# here are FLOORS at measured values, and the coverage question a total was standing in for - did
# the walk actually see the fleet, or did it quietly skip a folder - is answered by derivation
# instead: every pack folder walked must be one a builder in tools/pack_builders/ publishes into,
# read off the builders the same way tools/build_sample_behaviors.gd discovers them.
@tool
class_name PackOpenLiftTest
extends RefCounted

## Where the pack builders live - the same folder, and the same leading-underscore-is-a-helper
## rule, that tools/build_sample_behaviors.gd auto-discovers the fleet from.
const BUILDERS_DIR: String = "res://tools/pack_builders/"

## The OVERRIDE list, and only that: the three pack files that DO hold functions and still publish
## no verbs - two loaders whose functions are the host binding and _ready, and the quality preset's
## own reading of itself. Every other verbless pack is derived rather than listed: a file with no
## top-level function in it is a data asset, has nothing for the lifter to lift, and may declare no
## verbs - which is asked of it below without anybody adding its name here.
const NO_VERB_PACKS: Array[String] = [
	"loot_loader_behavior.gd", "skin_catalog_loader_behavior.gd", "quality_preset.gd",
]
## Verbs the lifter still cannot reproduce byte-exactly (one function each - an async loop guard,
## an @ace_param header, two Line of Sight helpers, one Drawing Canvas verb). Each stays a raw block
## while every OTHER verb in its file lifts. Shrink this list, never grow it.
const KNOWN_SHORT: Dictionary = {
	"drawing_canvas_behavior.gd": 1, "event_bus_addon.gd": 1, "line_of_sight_behavior.gd": 1,
	"line_of_sight_3d_behavior.gd": 1, "named_scenes_addon.gd": 1,
}


static func run() -> bool:
	var all_passed: bool = true
	var total_verbs: int = 0
	var lifted_verbs: int = 0
	var packs: int = 0
	var walked: Dictionary = {}
	for dir: String in DirAccess.get_directories_at("res://eventsheet_addons"):
		walked[dir] = true
		for file_name: String in DirAccess.get_files_at("res://eventsheet_addons/" + dir):
			if not file_name.ends_with(".gd"):
				continue
			var path: String = "res://eventsheet_addons/%s/%s" % [dir, file_name]
			var source: String = FileAccess.get_file_as_string(path)
			var declared: int = 0
			var has_functions: bool = false
			for line: String in source.split("\n"):
				if line == "## @ace_action" or line == "## @ace_condition" or line == "## @ace_expression":
					declared += 1
				elif line.begins_with("func ") or line.begins_with("static func "):
					has_functions = true
			var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
			packs += 1
			var exposed: int = 0
			for function: Variant in sheet.functions:
				if function is EventFunction and (function as EventFunction).expose_as_ace:
					exposed += 1
			total_verbs += declared
			lifted_verbs += exposed
			var allowed_short: int = int(KNOWN_SHORT.get(file_name, 0))
			all_passed = _check("%s opens with its verbs (%d of %d declared)" % [file_name, exposed, declared], exposed >= declared - allowed_short, true) and all_passed
			if not has_functions:
				all_passed = _check("%s publishes no verbs (a data asset - no functions at all)" % file_name, declared, 0) and all_passed
			elif NO_VERB_PACKS.has(file_name):
				all_passed = _check("%s publishes no verbs (loader / preset)" % file_name, declared, 0) and all_passed
			else:
				all_passed = _check("%s lifts at least one function" % file_name, sheet.functions.size() > 0, true) and all_passed
			var reopened: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
			all_passed = _check("%s reopened sheet compiles back byte-identically" % file_name, reopened == source, true) and all_passed
	# Did the walk see the fleet? Asked of the BUILDERS rather than of a number somebody typed: a
	# pack folder is compiler output, so every folder here has a builder that writes it, and a
	# folder nobody publishes into is either a pack whose builder was deleted or a stale tree.
	# Only this direction is pinned. The other one - a builder with no folder yet - is the state a
	# pack pass is legitimately IN while it works (the builder is written, the pack not built yet),
	# so asserting it would make this file fail on somebody else's half-finished work.
	var published: Dictionary = _folders_the_builders_publish()
	var unbuilt: PackedStringArray = PackedStringArray()
	for folder: String in walked:
		if not published.has(folder):
			unbuilt.append(folder)
	unbuilt.sort()
	all_passed = _check("every pack walked is one a pack builder publishes",
		", ".join(unbuilt), "") and all_passed
	all_passed = _check("the builders were readable at all", published.size() > 0, true) and all_passed
	# FLOORS, measured, never equalities - see the header. 121 packs, 1,713 declared verbs and
	# 1,264 lifted ones stood on 2026-09-04, the day the two equalities became floors. A number
	# below one of these is a pack or a verb that STOPPED being seen, which is the failure worth
	# a fleet-wide line; a number above it is somebody's new pack, which is not this file's news.
	all_passed = _check("the fleet is at least the 121 packs measured", packs >= 121, true) and all_passed
	all_passed = _check("fleet-wide verb lift is at least 1264 of the declared verbs (measured floor)", lifted_verbs >= 1264, true) and all_passed
	# The declared-verb total, as a floor for the same reason as the pack count: the number this
	# was once an equality on had grown by thirty-six recorded deltas, and every one of them was a
	# pass editing this line to say what its own pack had added. 1,713 is what the fleet declared
	# on 2026-09-04; a run under it means verbs stopped being declared where they were before.
	all_passed = _check("fleet-wide declared verbs are at least the 1713 measured",
		total_verbs >= 1713, true) and all_passed
	# The file that started it: the FPS Controller must open with every one of its verbs.
	var fps: EventSheetResource = GDScriptImporter.new().import_external("res://eventsheet_addons/fps_controller/fps_controller_behavior.gd")
	var fps_exposed: int = 0
	for function: Variant in fps.functions:
		if function is EventFunction and (function as EventFunction).expose_as_ace:
			fps_exposed += 1
	# Floors again, and for the third time the same reason: this pack gains verbs whenever somebody
	# works on the shooter vocabulary, and an equality here is that person editing this file before
	# their own suite can go green. 37 verbs over 44 lifted functions is what it opened with on
	# 2026-09-04; fewer means the whole-file degradation this test exists to catch is back.
	all_passed = _check("FPS Controller opens with at least the 37 verbs measured", fps_exposed >= 37, true) and all_passed
	all_passed = _check("FPS Controller's hidden helpers lift too (at least 44 functions)", fps.functions.size() >= 44, true) and all_passed
	return all_passed


## Every eventsheet_addons folder the pack builders write into, as folder name -> builder file.
## The builder set is the auto-discovered one (every *.gd in tools/pack_builders/ that is not a
## leading-underscore helper), and the folder is read out of the builder's own text, because the
## publish path is a literal in the call - which is what makes this cheap enough to be a test:
## nothing here loads a builder or runs a build.
static func _folders_the_builders_publish() -> Dictionary:
	var folders: Dictionary = {}
	var directory: DirAccess = DirAccess.open(BUILDERS_DIR)
	if directory == null:
		return folders
	var paths: RegEx = RegEx.create_from_string("res://eventsheet_addons/([a-z0-9_]+)/")
	for file_name: String in directory.get_files():
		if not file_name.ends_with(".gd") or file_name.begins_with("_"):
			continue
		var source: String = FileAccess.get_file_as_string(BUILDERS_DIR + file_name)
		for hit: RegExMatch in paths.search_all(source):
			folders[hit.get_string(1)] = file_name
	return folders


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] pack_open_lift_test: %s" % label)
		return true
	print("[FAIL] pack_open_lift_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
