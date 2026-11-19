# Godot EventSheets - the Doctor's Older Spellings note.
#
# A script keeps the spelling it was written in, and an untouched open and save never changes it. So a script
# written some time ago can still carry lines the editor would write differently today: a guard that wraps a
# plain number in a floor, annotation words written as two-hash comments. Nothing is wrong with them. This
# note only says so, once per script, and points at Sheet > Tidy This Script, which lists every line it would
# change before it writes anything.
#
# It reads text and nothing else: a script is looked at only when it holds one of the two shapes, and a line
# counts only when it has the whole shape. It never opens a file as a sheet (that is what Tidy does, when
# asked), so a line it counts can be one Tidy then leaves as it is. A note, never a warning, and a script
# the plugin ships is never named. Registered by path, with no class_name of its own.
@tool
extends "res://addons/eventforge/doctor_section.gd"

const CHECK_ID := "older-spellings"
const THIS_SCRIPT := "res://addons/eventforge/older_spellings_doctor.gd"
const LITERAL_FOLD := "res://addons/eventforge/compiler/literal_fold.gd"

static var _guard_re: RegEx = null


## Registers the section, replacing any earlier registration.
static func ensure_registered() -> void:
	EventSheetProjectDoctor.register_check(CHECK_ID, Callable(load(THIS_SCRIPT), "check"))


## The section, with the contract every registered check has: append findings, never write inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var turn: int = 0
	for script_path: String in own_paths(EventSheetProjectDoctor._project_scripts()):
		turn += 1
		await EventSheetProjectDoctor.breathe_every(turn)
		var source: String = EventSheetProjectDoctor.source_of(script_path)
		var counted: int = older_lines(source)
		if counted > 0:
			findings.append(report(script_path, counted))


## The finding for one script that holds `counted` lines in an older spelling: two short sentences.
static func report(script_path: String, counted: int) -> Dictionary:
	var message: String = EventSheetL10n.counted(
		"1 line uses an older spelling. Sheet > Tidy This Script lists it first.",
		"%d lines use an older spelling. Sheet > Tidy This Script lists them first.",
		counted)
	return _finding("info", CHECK_ID, script_path, message, script_path.get_file())


## How many lines of `source` are in an older spelling, by the cheap text test: a two-hash annotation line
## that reads the same with one hash, and a condition line that guards a plain float with a floor it already
## clears (`if t >= maxf(2.0, 0.001):`). Nothing is read as a sheet.
static func older_lines(source: String) -> int:
	var has_words: bool = source.contains("## @ace_")
	var has_guard: bool = source.contains("maxf(")
	if not has_words and not has_guard:
		return 0
	var counted: int = 0
	for line: String in source.split("\n"):
		if has_words and EventSheetAnnotationLine.hashed(line) != line:
			counted += 1
		elif has_guard and _is_floored_guard(line):
			counted += 1
	return counted


static func _is_floored_guard(line: String) -> bool:
	var stripped: String = line.strip_edges()
	if not (stripped.begins_with("if ") or stripped.begins_with("elif ") or stripped.begins_with("while ")) or not stripped.ends_with(":"):
		return false
	if _guard_re == null:
		_guard_re = RegEx.create_from_string("maxf\\((-?[0-9]+\\.[0-9]+), (-?[0-9]+\\.[0-9]+)\\)")
	var fold: GDScript = load(LITERAL_FOLD)
	var hits: Array[RegExMatch] = _guard_re.search_all(stripped)
	if hits.is_empty():
		return false
	for hit: RegExMatch in hits:
		if not fold.is_foldable_value(hit.get_string(1), hit.get_string(2)):
			return false
	return true
