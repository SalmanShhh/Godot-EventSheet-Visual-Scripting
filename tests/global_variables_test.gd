# Godot EventSheets - a global is declared once on an autoload and used everywhere.
#
# Pins the VALUES of the three answers: what an autoload DECLARES (read straight off its file, so a
# file nobody has opened still answers), what the folded "Global variables used here" folder SAYS,
# and what the writer WRITES - including the two things it must refuse, a name the autoload already
# has and an @export on a global (a global is not a per-instance designer knob).
@tool
class_name GlobalVariablesTest
extends RefCounted

const PROBE_PATH := "user://eventforge_global_variables_probe.gd"


static func run() -> bool:
	var ok: bool = true

	# ── What an autoload declares, read off its file ──
	var written: FileAccess = FileAccess.open(PROBE_PATH, FileAccess.WRITE)
	written.store_string("extends Node\n\n"
		+ "var Score: int = 0\n"
		+ "var Lives := 3\n"
		+ "var PlayerName: String = \"\"\n"
		+ "const MAX_LEVEL := 10\n"
		+ "static var runs := 0\n"
		+ "\n"
		+ "func add_score(amount: int) -> void:\n"
		+ "\tvar bonus := 5\n"
		+ "\tScore += amount + bonus\n")
	written.close()
	var declared: Array[Dictionary] = EventSheetGlobalVariables.declared_globals(PROBE_PATH)
	ok = _check("every member is read, and nothing from inside a function is",
		_names(declared), "Score, Lives, PlayerName, MAX_LEVEL, runs") and ok
	ok = _check("a declared type is kept", _entry(declared, "Score").get("type", ""), "int") and ok
	ok = _check("…and so is its value", _entry(declared, "Score").get("value", ""), "0") and ok
	ok = _check("a walrus declaration has no type but keeps its value",
		"%s|%s" % [_entry(declared, "Lives").get("type", ""), _entry(declared, "Lives").get("value", "")],
		"|3") and ok
	ok = _check("a text global keeps its quotes",
		_entry(declared, "PlayerName").get("value", ""), "\"\"") and ok

	# ── The hover the Object bar shows ──
	ok = _check("a global hovers with its value",
		EventSheetGlobalVariables.hover_text("Game", "Score", declared), "Game.Score = 0") and ok
	ok = _check("one the file does not declare hovers with its name alone",
		EventSheetGlobalVariables.hover_text("Game", "Nope", declared), "Game.Nope") and ok

	# ── The folder's note ──
	ok = _check("one source reads as one source",
		EventSheetGlobalVariables.used_here_note([
			{"autoload": "Game", "name": "Score"}, {"autoload": "Game", "name": "Lives"}]),
		"Score · Lives  (from Game)") and ok
	ok = _check("two sources both get named",
		EventSheetGlobalVariables.used_here_note([
			{"autoload": "Game", "name": "Score"}, {"autoload": "Save", "name": "Slot"}]),
		"Score · Slot  (from Game, Save)") and ok
	ok = _check("a file that touches none grows no folder",
		EventSheetGlobalVariables.used_here_note([]), "") and ok

	# ── The writer ──
	var target: EventSheetResource = EventSheetResource.new()
	target.host_class = "Node"
	ok = _check("a global is written",
		EventSheetGlobalVariables.write_global(target, "Score", "int", 0), true) and ok
	var placed: LocalVariable = target.events[0] as LocalVariable
	ok = _check("…as an ordinary member variable, by name",
		placed.name, "Score") and ok
	ok = _check("…with the type it was given", placed.type_name, "int") and ok
	ok = _check("…and its value", placed.default_value, 0) and ok
	ok = _check("a global is never an Inspector property - it is not a per-object knob",
		placed.exported, false) and ok
	ok = _check("a second global lands after the first, so the head stays one block",
		EventSheetGlobalVariables.write_global(target, "Lives", "int", 3), true) and ok
	ok = _check("…in that order",
		"%s, %s" % [(target.events[0] as LocalVariable).name, (target.events[1] as LocalVariable).name],
		"Score, Lives") and ok
	ok = _check("a name the file already declares is refused, never shadowed",
		EventSheetGlobalVariables.write_global(target, "Score", "float", 1.0), false) and ok
	ok = _check("and so is a nameless one",
		EventSheetGlobalVariables.write_global(target, "", "int", 0), false) and ok
	ok = _check("a missing sheet is refused rather than crashed on",
		EventSheetGlobalVariables.write_global(null, "Score", "int", 0), false) and ok

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))
	return ok


static func _names(entries: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		parts.append(str(entry.get("name", "")))
	return ", ".join(parts)


static func _entry(entries: Array[Dictionary], wanted: String) -> Dictionary:
	for entry: Dictionary in entries:
		if str(entry.get("name", "")) == wanted:
			return entry
	return {}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] global_variables_test: %s" % label)
		return true
	print("[FAIL] global_variables_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
