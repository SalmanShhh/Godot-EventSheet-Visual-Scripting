# The Doctor's front page: worst first, and what is new since the reader last looked.
#
# The page is the answer to the audit having grown sections faster than it grew a way to read them,
# so the things worth pinning are the ORDER, the IDENTITY of a finding, and the words the reader is
# given about both. All of it is pure and headless: the window draws this page, it does not decide it.
#
# What is pinned:
#   1. SEVERITY FIRST, then a fixed order inside each - two audits of an unchanged project read the
#      same, which is the only reason a reader can trust a mark that says "new".
#   2. THE IDENTITY IS THE FINDING, NOT ITS POSITION: a finding that moved is not new, a finding whose
#      message was reworded is not new, and the same warning about a different file IS.
#   3. THE SECTIONS, ordered by the worst thing in them, with counts and a section title derived from
#      the check id rather than looked up in a table nobody remembers to update.
#   4. THE SUMMARY LINE, in both of its spellings.
#   5. THE READING POSITION, written to a temporary file and read back - and the file cleaned up, so the
#      next test in the same process starts where this one found things.
@tool
class_name DoctorInboxTest
extends RefCounted

## A temporary reading position, so the test never touches the one the editor keeps.
const STORE_PATH := "user://eventsheets_doctor_seen_test.cfg"


static func run() -> bool:
	var ok: bool = true
	ok = _test_worst_first() and ok
	ok = _test_what_makes_a_finding_the_same_finding() and ok
	ok = _test_the_sections() and ok
	ok = _test_the_summary_line() and ok
	ok = _test_the_reading_position() and ok
	return ok


static func _findings() -> Array:
	return [
		_finding("info", "tidiness", "res://game/hud.gd", "A variable nobody reads.", "score"),
		_finding("error", "stale-output", "res://game/player.gd", "player.gd is stale.", ""),
		_finding("warning", "ship-default-identity", "res://project.godot", "Still the engine's icon.", "icon"),
		_finding("warning", "ship-export-preset", "res://export_presets.cfg", "Nothing to build from.", ""),
		_finding("error", "compile", "res://game/boss.gd", "Sheet no longer compiles.", ""),
	]


## Errors, then warnings, then notes - and inside each, check then file then message.
static func _test_worst_first() -> bool:
	var page: Array[Dictionary] = EventSheetDoctorInbox.triage(_findings(), PackedStringArray())
	var ok: bool = _check("the page is worst first", _column(page, "severity"),
		PackedStringArray(["error", "error", "warning", "warning", "info"]))
	ok = _check("and fixed inside each severity", _column(page, "check"),
		PackedStringArray(["compile", "stale-output", "ship-default-identity", "ship-export-preset",
			"tidiness"])) and ok
	ok = _check("with nothing read yet, everything is new", _new_marks(page),
		PackedStringArray(["new", "new", "new", "new", "new"])) and ok
	return ok


## The identity is what a finding is ABOUT. A page that moved is not a page of new things, and a
## check reworded overnight must not flood a reader with things they have already read.
static func _test_what_makes_a_finding_the_same_finding() -> bool:
	var first: Array[Dictionary] = EventSheetDoctorInbox.triage(_findings(), PackedStringArray())
	var seen: PackedStringArray = EventSheetDoctorInbox.identities_of(first)
	var ok: bool = _check("the identity names the check, the file and the subject",
		EventSheetDoctorInbox.identity(_finding("warning", "ship-default-identity",
			"res://project.godot", "Still the engine's icon.", "icon")),
		"ship-default-identity|res://project.godot|icon")
	# The same audit again: nothing is new, even though two findings were fixed above it.
	var fewer: Array = [
		_finding("warning", "ship-export-preset", "res://export_presets.cfg", "Nothing to build from.", ""),
		_finding("info", "tidiness", "res://game/hud.gd", "A variable nobody reads.", "score"),
	]
	ok = _check("a finding that moved up the page is not new",
		_new_marks(EventSheetDoctorInbox.triage(fewer, seen)),
		PackedStringArray(["seen", "seen"])) and ok
	var reworded: Array = [
		_finding("warning", "ship-export-preset", "res://export_presets.cfg",
			"There is no export preset in this project at all.", ""),
	]
	ok = _check("a finding whose words changed is not new either",
		_new_marks(EventSheetDoctorInbox.triage(reworded, seen)), PackedStringArray(["seen"])) and ok
	var elsewhere: Array = [
		_finding("warning", "ship-default-identity", "res://other.godot", "Still the engine's icon.", "icon"),
	]
	ok = _check("but the same warning about a different file is new",
		_new_marks(EventSheetDoctorInbox.triage(elsewhere, seen)), PackedStringArray(["new"])) and ok
	return ok


## The sections a reader scans before reading a word: what raised things, how much, and how much of
## it is new. Ordered by the worst thing in them, so the one to act on is at the top.
static func _test_the_sections() -> bool:
	var page: Array[Dictionary] = EventSheetDoctorInbox.triage(_findings(),
		PackedStringArray(["tidiness|res://game/hud.gd|score"]))
	var sections: Array[Dictionary] = EventSheetDoctorInbox.sections(page)
	var ok: bool = _check("sections are ordered by the worst thing in them",
		_column(sections, "id"), PackedStringArray(["compile", "stale-output",
			"ship-default-identity", "ship-export-preset", "tidiness"]))
	ok = _check("each is titled from its own id, with no table to remember",
		EventSheetDoctorInbox.label_for("ship-default-identity"), "Ship default identity") and ok
	ok = _check("a section counts what it holds", sections[0],
		{"id": "compile", "label": "Compile", "error": 1, "warning": 0, "info": 0, "new": 1}) and ok
	ok = _check("and the one thing already read is not counted as new", sections[4],
		{"id": "tidiness", "label": "Tidiness", "error": 0, "warning": 0, "info": 1, "new": 0}) and ok
	return ok


## The one line the status bar gets, in both of its spellings.
static func _test_the_summary_line() -> bool:
	var seen: PackedStringArray = EventSheetDoctorInbox.identities_of(
		EventSheetDoctorInbox.triage(_findings(), PackedStringArray()))
	var ok: bool = _check("a page with something new says how much",
		EventSheetDoctorInbox.summary_line(EventSheetDoctorInbox.triage(_findings(), PackedStringArray())),
		"Project Doctor: 2 error(s), 2 warning(s), 1 note(s). 5 new since you last looked.")
	ok = _check("a page a reader has already read says only what it holds",
		EventSheetDoctorInbox.summary_line(EventSheetDoctorInbox.triage(_findings(), seen)),
		"Project Doctor: 2 error(s), 2 warning(s), 1 note(s).") and ok
	return ok


## The reading position on disk. Written sorted, read back whole, and gone again afterwards - a test
## that left a file behind would make the next reader's page wrong in a way nothing would report.
static func _test_the_reading_position() -> bool:
	EventSheetDoctorInbox.forget_seen(STORE_PATH)
	var ok: bool = _check("nobody has looked yet",
		EventSheetDoctorInbox.load_seen(STORE_PATH), PackedStringArray())
	var page: Array[Dictionary] = EventSheetDoctorInbox.triage(_findings(), PackedStringArray())
	ok = _check("writing down what was read succeeds",
		EventSheetDoctorInbox.save_seen(EventSheetDoctorInbox.identities_of(page), STORE_PATH), true) and ok
	ok = _check("and it reads back sorted", EventSheetDoctorInbox.load_seen(STORE_PATH),
		PackedStringArray([
			"compile|res://game/boss.gd|",
			"ship-default-identity|res://project.godot|icon",
			"ship-export-preset|res://export_presets.cfg|",
			"stale-output|res://game/player.gd|",
			"tidiness|res://game/hud.gd|score",
		])) and ok
	EventSheetDoctorInbox.forget_seen(STORE_PATH)
	ok = _check("and forgetting it puts the reader back at everything-is-new",
		EventSheetDoctorInbox.load_seen(STORE_PATH), PackedStringArray()) and ok
	return ok


static func _finding(severity: String, check_id: String, path: String, message: String,
		subject: String) -> Dictionary:
	return {
		"severity": severity, "check": check_id, "path": path, "message": message,
		"subject": subject,
	}


static func _column(rows: Array, key: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for row: Dictionary in rows:
		out.append(str(row.get(key, "")))
	return out


static func _new_marks(page: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for finding: Dictionary in page:
		out.append("new" if bool(finding.get("is_new", false)) else "seen")
	return out


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doctor_inbox_test: %s" % label)
		return true
	print("[FAIL] doctor_inbox_test: %s" % label)
	print("  expected: ", expected)
	print("  actual:   ", actual)
	return false
