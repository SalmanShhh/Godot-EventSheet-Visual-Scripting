# One-shot audit: every behaviour pack's .gd must re-import as an event sheet and recompile to EXACTLY
# itself (the .gd IS the source of truth - there is no .tres). This is the lossless round-trip gate for
# all bundled packs: open .gd -> import_external -> recompile -> byte-identical to the shipped .gd.
@tool
extends SceneTree


## The pack-count measurement, reused rather than re-derived, for the `builders=` figure printed
## beside `audited=`. The two count different populations on purpose: `audited` is the pack scripts
## found ON DISK (folder packs plus the root single-file ones), `builders` is how many files in
## `tools/pack_builders/` publish a pack folder at all. They are not expected to be equal, and
## neither is a gate - the number is here so a tree whose builders and shipped folders have drifted
## apart says so in the audit's own output instead of only at the next full regeneration.
const MEASURE := preload("res://tools/measure_packs.gd")


func _init() -> void:
	var packs_dir: DirAccess = DirAccess.open("res://eventsheet_addons")
	packs_dir.list_dir_begin()
	var entry: String = packs_dir.get_next()
	var audited: int = 0
	var drifted: int = 0
	var failed: int = 0  # parse failures + missing pack scripts
	var verify_path: String = "user://_eventforge_audit_verify.gd"
	while not entry.is_empty():
		if packs_dir.current_is_dir() and not entry.begins_with("."):
			var folder: String = "res://eventsheet_addons/%s" % entry
			var script_path: String = _find_pack_script(folder)
			if script_path.is_empty():
				print("MISSING PACK SCRIPT: %s" % entry)
				failed += 1
			else:
				audited += 1
				var verdict: Dictionary = _audit_script(entry, script_path, verify_path)
				drifted += 1 if bool(verdict.get("drift", false)) else 0
				failed += 1 if bool(verdict.get("parse_fail", false)) else 0
		elif entry.ends_with(".gd"):
			# Root-level single-file packs (demo_health_addon.gd, demo_note_block.gd) hold the
			# same covenant as folder packs - the folder-only walk silently skipped them.
			audited += 1
			var root_verdict: Dictionary = _audit_script(entry, "res://eventsheet_addons/%s" % entry, verify_path)
			drifted += 1 if bool(root_verdict.get("drift", false)) else 0
			failed += 1 if bool(root_verdict.get("parse_fail", false)) else 0
		entry = packs_dir.get_next()
	if FileAccess.file_exists(verify_path):
		DirAccess.remove_absolute(verify_path)
	print("audited=%d drifted=%d builders=%d" % [audited, drifted,
		MEASURE.publishing_builders(MEASURE.BUILDERS_DIR)])
	# The spellings the packs TEACH the reader (`## @ace_lift_example`) are held to the same promise
	# their verbs are: every entry generates its own fixture line, is claimed by itself, and re-emits
	# byte for byte - and no pack may shadow a built-in spelling. An entry that cannot do that never
	# ships, so this is an error here rather than a surprise in somebody's opened file.
	var spelling_problems: PackedStringArray = EventForgePackSpellings.problems()
	for problem: String in spelling_problems:
		print("SPELLING: %s" % problem)
	# A near-collision is not an error - two packs may both know a line, and the first in folder
	# order claims it. Printed so the pack that loses hears about it here too, not only in the Doctor.
	for advisory: String in EventForgePackSpellings.advisories():
		print("SPELLING NOTE: %s" % advisory)
	print("spellings=%d problems=%d" % [EventForgePackSpellings.entries().size(),
		spelling_problems.size()])
	# And the FORWARDING ADDRESSES the vocabulary carries, held to the same standard: a verb
	# succeeded by one nobody has, a chain that comes back to itself, a rename naming a parameter
	# neither side has, or a successor parameter nothing answers. All four are build errors here
	# rather than a loop or a blank cell somebody meets with a sheet open.
	var catalog: Dictionary = EventForgeSuccessors.catalog()
	var successor_problems: PackedStringArray = EventForgeSuccessors.problems(catalog)
	for problem: String in successor_problems:
		print("SUCCESSOR: %s" % problem)
	print("successors=%d problems=%d" % [_successor_count(catalog), successor_problems.size()])
	# A red gate must FAIL the invocation: anything checking only the exit code (CI, shell
	# chains) used to see success even when packs drifted or failed to parse.
	quit(1 if drifted > 0 or failed > 0 or not spelling_problems.is_empty() \
		or not successor_problems.is_empty() else 0)


## How many verbs in the vocabulary carry a forwarding address at all - printed beside the problem
## count so a gate that stops finding any of them says so instead of reading green.
func _successor_count(catalog: Dictionary) -> int:
	var carried: int = 0
	for key: Variant in catalog.keys():
		if not EventForgeSuccessors.normalize_map((catalog[key] as Dictionary).get("map", {})).is_empty():
			carried += 1
	return carried


## One pack script's round-trip + parse verdict. The .gd is both the sheet and the runtime
## script: import it as a sheet, recompile, and confirm the output matches the file on disk.
## Compiles to a throwaway user:// path so the real pack is never rewritten by the audit.
func _audit_script(label: String, script_path: String, verify_path: String) -> Dictionary:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(script_path)
	var output: String = str(SheetCompiler.compile(sheet, verify_path).get("output", ""))
	var shipped: String = FileAccess.get_file_as_string(script_path)
	var verdict: Dictionary = {"drift": output != shipped, "parse_fail": not script_compiles(script_path)}
	if bool(verdict["drift"]):
		print("DRIFT: %s (recompile differs from shipped .gd)" % label)
	if bool(verdict["parse_fail"]):
		print("PARSE FAIL %s" % script_path)
	return verdict


## Whether the script at `script_path` actually COMPILES - the question this gate means by "parses".
##
## `load()` cannot answer it: in Godot 4 a script whose source has a parse error still comes back as
## a non-null GDScript (an empty, invalid one), so a `load(path) == null` check reported a pack that
## does not compile as healthy and the red exit never fired. The script's own `reload()` verdict is
## the honest answer, and it is the spelling the rest of the plugin already lints with. It runs on
## the LOADED resource rather than on a fresh GDScript built from the source text, because a fresh
## one would false-positive on "hides a global class" - the pack's class_name is registered to this
## very path already. A parse error prints itself here, which is the diagnostic a red gate wants.
static func script_compiles(script_path: String) -> bool:
	var loaded: Variant = load(script_path)
	if not (loaded is GDScript):
		return false
	return (loaded as GDScript).reload(true) == OK


## The single sheet script a pack folder ships (e.g. spring_behavior.gd, save_system_addon.gd). Skips
## .gd.uid (ends with .uid, not .gd) and any non-script files.
static func _find_pack_script(folder: String) -> String:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var inner: String = dir.get_next()
	while not inner.is_empty():
		if inner.ends_with(".gd"):
			return "%s/%s" % [folder, inner]
		inner = dir.get_next()
	return ""
