# Godot EventSheets - A PACK UPDATE IS A PROPOSAL.
#
# A pack is copied into the project on purpose, so an update has to answer a question nobody can
# answer from the files as they stand: which of these did the project change? The attach writes down
# the content hash of every file it landed, and everything below is what those hashes buy:
#
#   1. UNTOUCHED / YOURS is decided by BYTES, never by a date. A file that still hashes to what
#      arrived is untouched; anything else is yours - including a file that differs only in how its
#      lines end, because the honest answer to "did this change?" is the one the bytes give. That row
#      says so in words, which is a courtesy, not a reclassification.
#   2. A PACK WITH NO RECORD IS NOT A PACK WITH NO CHANGES. Every file goes under "yours", and the
#      default answer for every one of them is keep mine.
#   3. THE VOCABULARY SECTION IS A REGISTRY DIFF. What a version retires and adds is derived by
#      dumping both versions' descriptors and diffing the texts - never from prose, never from a
#      version number.
#   4. ASKING WRITES NOTHING. Planning an update leaves every byte of the pack exactly as it was.
#   5. TAKING IT BACKS UP FIRST. Every file about to be overwritten or removed goes into the ring
#      before the first new byte lands, and a "keep mine" answer is honoured to the byte.
#   6. AND THE RING HAS A DOOR. What it is holding for one pack is listed, and one entry is written
#      back as an UNDOABLE edit with a receipt - including a file the update removed altogether,
#      which is the case somebody comes looking for. The ring itself is never touched by any of it.
#
# EVERY FIXTURE IS UNDER user://. Nothing here touches eventsheet_addons/, so a crashed run cannot
# leave a stray pack in the tree for the drift gate to find.
@tool
class_name PackUpdateTest
extends RefCounted

## Where the fixture packs live. One folder per version, plus the "installed" one that gets edited.
const FIXTURE_ROOT: String = "user://eventforge_pack_update_fixture"
const PACK_DIR: String = "probe_pack"

## The pack's own script, v1 - one action, no forwarding address.
const PACK_V1: String = """@tool
extends Node


## @ace_action
## @ace_name("Wave")
func wave(times: int = 2) -> void:
	print(times)
"""

## v2 - the same action, now carrying an address, plus one the version adds. It says which version
## it is, which is what an update with no version told to it has to be able to read back.
const PACK_V2: String = """@tool
## @ace_version("2.1.0")
extends Node


## @ace_action
## @ace_name("Wave")
## @ace_succeeded_by(Core::Print, renames: times=text)
func wave(times: int = 2) -> void:
	print(times)


## @ace_action
## @ace_name("Wave Twice")
func wave_twice() -> void:
	print("twice")
"""

const GUIDE_V1: String = "# Probe pack\n\nWhat it does.\n"
const GUIDE_V2: String = "# Probe pack\n\nWhat it does, said better.\n"
const NOTES_V1: String = "one\ntwo\n"


static func run() -> bool:
	var ok: bool = _test_the_dump_format()
	ok = _test_the_dump_round_trips_its_escaping() and ok
	ok = _test_the_diff_between_two_dumps() and ok
	ok = _test_hash_classification() and ok
	ok = _test_the_vocabulary_section_is_a_registry_diff() and ok
	ok = _test_the_tri_list() and ok
	ok = _test_asking_writes_nothing() and ok
	ok = _test_taking_it_backs_up_first() and ok
	ok = _test_the_record_says_what_it_now_holds() and ok
	ok = _test_the_dry_run_answers_the_incoming_vocabulary() and ok
	ok = _test_the_ring_has_a_door() and ok
	ok = _test_a_ring_folder_is_many_to_one() and ok
	_clear_fixture()
	return ok


# ── 1. The dump ───────────────────────────────────────────────────────────────────────────────


## The format, pinned on a registry of two verbs. Eight tab-separated fields in a fixed order, sorted
## by key, one comment line at the top, and a template folded onto one line by escaping.
##
## The two parameter-detail fields are on the line because a default is not decoration: it lands in
## every freshly picked row and it decides whether a forwarding address has to answer that parameter
## at all. A dump listing parameter NAMES alone said "nothing changed" about a version that re-typed
## or re-defaulted every one of them.
static func _test_the_dump_format() -> bool:
	var registry: Dictionary = {
		"Probe::Wave": {
			"ace_type": ACEDefinition.ACEType.ACTION,
			"category": "Signals",
			"params": PackedStringArray(["times"]),
			"declared_types": {"times": "int"},
			"declared_defaults": {"times": "3"},
			"template": "wave({times})\n\tpass",
			"map": {},
		},
		"Probe::IsWaving": {
			"ace_type": ACEDefinition.ACEType.CONDITION,
			"category": "Signals",
			"params": PackedStringArray(),
			"template": "is_waving()",
			"map": {"id": "Probe::IsAnimating", "renames": {}, "defaults": {}},
		},
	}
	var expected: String = "\n".join(PackedStringArray([
		"# eventsheets registry dump 2",
		"Probe::IsWaving\tcondition\tSignals\t\t\t\tProbe::IsAnimating\tis_waving()",
		"Probe::Wave\taction\tSignals\ttimes\ttimes=int\ttimes=3\t\twave({times})\\n\\tpass",
		"",
	]))
	var ok: bool = _check("the dump is eight sorted fields per verb",
		EventForgeRegistryDump.text(registry), expected)
	# A DEFAULT THAT MOVES IS A CHANGE, which is the whole reason those two fields are on the line.
	var re_defaulted: Dictionary = registry.duplicate(true)
	(re_defaulted["Probe::Wave"] as Dictionary)["declared_defaults"] = {"times": "5"}
	ok = _check("re-defaulting a parameter is reported as a change",
		EventForgeRegistryDump.diff(expected,
			EventForgeRegistryDump.text(re_defaulted))["changed"],
		[{"key": "Probe::Wave", "fields": PackedStringArray(["param_defaults"])}]) and ok
	ok = _check("and it says which format it is",
		EventForgeRegistryDump.is_current_format(expected), true) and ok
	ok = _check("a text from another shape is not read at all",
		EventForgeRegistryDump.is_current_format("Probe::Wave\taction"), false) and ok
	return ok


## Escaping is reversible, including the case that catches a chain of replaces: a template holding
## the two characters a reader typed as a backslash and an n, which must not come back as a newline.
static func _test_the_dump_round_trips_its_escaping() -> bool:
	var template: String = "print(\"a\\nb\")\n\tqueue_free()\t# tabbed"
	var registry: Dictionary = {"P::A": {
		"ace_type": ACEDefinition.ACEType.EXPRESSION, "category": "", "params": PackedStringArray(["one", "two"]),
		"template": template, "map": {}}}
	var parsed: Dictionary = EventForgeRegistryDump.parse(EventForgeRegistryDump.text(registry))
	var ok: bool = _check("one verb comes back", parsed.size(), 1)
	ok = _check("its template survives every escape",
		str((parsed.get("P::A", {}) as Dictionary).get("template", "")), template) and ok
	ok = _check("its params survive as written",
		str((parsed.get("P::A", {}) as Dictionary).get("params", "")), "one,two") and ok
	ok = _check("and an expression is called an expression",
		str((parsed.get("P::A", {}) as Dictionary).get("type", "")), "expression") and ok
	return ok


## What a diff says, over the four things that can happen to a verb between two versions.
static func _test_the_diff_between_two_dumps() -> bool:
	var before: String = EventForgeRegistryDump.text({
		"P::Kept": _entry("k()", {}),
		"P::Moved": _entry("m()", {}),
		"P::Gone": _entry("g()", {}),
		"P::Reworded": _entry("r()", {}),
	})
	var after: String = EventForgeRegistryDump.text({
		"P::Kept": _entry("k()", {}),
		"P::Moved": _entry("m()", {"id": "P::Arrived", "renames": {}, "defaults": {}}),
		"P::Reworded": _entry("r(1)", {}),
		"P::Arrived": _entry("a()", {}),
	})
	var moved: Dictionary = EventForgeRegistryDump.diff(before, after)
	var ok: bool = _check("the diff is readable", bool(moved.get("readable", false)), true)
	ok = _check("a verb that gained an address is retired, and says where to",
		moved.get("retired", []), [
			{"key": "P::Gone", "successor": "", "gone": true},
			{"key": "P::Moved", "successor": "P::Arrived", "gone": false},
		]) and ok
	ok = _check("a verb the new version publishes and the old did not is added",
		moved.get("added", PackedStringArray()), PackedStringArray(["P::Arrived"])) and ok
	ok = _check("and a verb whose line moved names the field that moved",
		moved.get("changed", []), [
			{"key": "P::Moved", "fields": PackedStringArray(["successor"])},
			{"key": "P::Reworded", "fields": PackedStringArray(["template"])},
		]) and ok
	ok = _check("a dump this build cannot read is refused rather than answered",
		bool(EventForgeRegistryDump.diff("Probe::Wave\taction", after).get("readable", true)), false) and ok
	return ok


static func _entry(template: String, map: Dictionary) -> Dictionary:
	return {"ace_type": ACEDefinition.ACEType.ACTION, "category": "Probe",
		"params": PackedStringArray(), "template": template, "map": map}


# ── 2. What arrived, and what is yours ────────────────────────────────────────────────────────


## The whole of the classification, on a folder that is stamped and then edited four different ways.
static func _test_hash_classification() -> bool:
	var folder: String = _fresh_pack()
	var ok: bool = _check("before the attach stamps it, the pack has no record",
		EventSheetPackManifest.has_record(folder), false)
	ok = _check("and every file reads as unrecorded, never as untouched",
		_states(EventSheetPackManifest.classify(folder)),
		{"guide.md": "unrecorded", "notes.txt": "unrecorded", "probe_pack.gd": "unrecorded"}) and ok
	EventSheetPackManifest.stamp(folder, "1.0.0")
	ok = _check("stamped, every file is untouched",
		_states(EventSheetPackManifest.classify(folder)),
		{"guide.md": "untouched", "notes.txt": "untouched", "probe_pack.gd": "untouched"}) and ok
	# An edit, a line-ending-only rewrite, a file the record never saw, and one that has gone.
	_write(folder.path_join("guide.md"), GUIDE_V2)
	_write(folder.path_join("notes.txt"), NOTES_V1.replace("\n", "\r\n"))
	_write(folder.path_join("extra.md"), "mine\n")
	DirAccess.remove_absolute(folder.path_join("probe_pack.gd"))
	var rows: Array[Dictionary] = EventSheetPackManifest.classify(folder)
	ok = _check("an edited file is yours, and so is one only its line endings changed",
		_states(rows), {"extra.md": "yours", "guide.md": "yours", "notes.txt": "yours",
			"probe_pack.gd": "yours"}) and ok
	ok = _check("the line-ending case is named rather than hidden",
		_note(rows, "notes.txt"), EventSheetPackManifest.NOTE_LINE_ENDINGS) and ok
	ok = _check("a real edit carries no such excuse", _note(rows, "guide.md"), "") and ok
	ok = _check("a file the record never saw says so",
		_note(rows, "extra.md"), EventSheetPackManifest.NOTE_NOT_RECORDED) and ok
	ok = _check("and one that has left the folder is still listed",
		_note(rows, "probe_pack.gd"), EventSheetPackManifest.NOTE_MISSING) and ok
	ok = _check("the record itself is never one of the files it records",
		EventSheetPackManifest.files_of(folder).has(EventSheetPackManifest.MANIFEST_FILE), false) and ok
	return ok


# ── 3. What the new version does to the vocabulary ────────────────────────────────────────────


## The dialog's vocabulary section, over a real pack reflected twice: the version installed, and the
## version being offered. Neither answer comes from a version string or a release note.
static func _test_the_vocabulary_section_is_a_registry_diff() -> bool:
	var folder: String = _fresh_pack()
	EventSheetPackManifest.stamp(folder, "1.0.0")
	var incoming: Dictionary = {
		"probe_pack.gd": PACK_V2.to_utf8_buffer(),
		"guide.md": GUIDE_V2.to_utf8_buffer(),
		"notes.txt": NOTES_V1.to_utf8_buffer(),
	}
	var moved: Dictionary = EventSheetPackUpdate.vocabulary(folder, incoming)
	var ok: bool = _check("both versions were read", bool(moved.get("readable", false)), true)
	var retired: Array = moved.get("retired", [])
	ok = _check("the verb that gained an address is the one reported",
		retired.size(), 1) and ok
	if retired.size() == 1:
		ok = _check("and it is reported as moved rather than gone",
			bool((retired[0] as Dictionary).get("gone", true)), false) and ok
		ok = _check("with the address the annotation gives it",
			str((retired[0] as Dictionary).get("successor", "")), "Core::Print") and ok
	ok = _check("the action the version adds is listed once",
		PackedStringArray(moved.get("added", PackedStringArray())).size(), 1) and ok
	var lines: PackedStringArray = EventSheetPackUpdate.vocabulary_lines(moved)
	ok = _check("both facts reach the reader as two lines", lines.size(), 2) and ok
	if lines.size() == 2:
		ok = _check("and the retirement line promises the old rows still compile",
			lines[0].contains("old rows still compile the same"), true) and ok
	return ok


# ── 4. The tri-list ───────────────────────────────────────────────────────────────────────────


## What the update proposes, file by file, with one of the pack's files edited by hand first.
static func _test_the_tri_list() -> bool:
	var folder: String = _fresh_pack()
	EventSheetPackManifest.stamp(folder, "1.0.0")
	_write(folder.path_join("guide.md"), "# Probe pack\n\nMy own words.\n")
	var incoming: Dictionary = {
		"probe_pack.gd": PACK_V2.to_utf8_buffer(),
		"guide.md": GUIDE_V2.to_utf8_buffer(),
		"icon.svg": "<svg/>".to_utf8_buffer(),
	}
	var offered: Dictionary = EventSheetPackUpdate.plan(folder, incoming)
	var ok: bool = _check("the pack's record was found", bool(offered.get("unrecorded", true)), false)
	ok = _check("untouched files take the new version, and are listed rather than swept",
		_lines(offered.get("untouched", [])), PackedStringArray([
			"icon.svg - new in this version",
			"notes.txt - dropped by this version",
			"probe_pack.gd - this version rewrites it",
		])) and ok
	ok = _check("the one file you changed is the only question",
		_lines(offered.get("yours", [])),
		PackedStringArray(["guide.md - this version rewrites it"])) and ok
	ok = _check("and its default answer is to keep yours",
		EventSheetPackUpdate.default_choice((offered.get("yours", [])[0]) as Dictionary),
		EventSheetPackUpdate.CHOICE_KEEP_MINE) and ok
	ok = _check("an untouched file's default is to take the new version",
		EventSheetPackUpdate.default_choice((offered.get("untouched", [])[0]) as Dictionary),
		EventSheetPackUpdate.CHOICE_TAKE_NEW) and ok
	ok = _check("the summary says the shape of the decision",
		EventSheetPackUpdate.summary_text(offered),
		"3 file(s) are exactly as they arrived and take the new version. 1 you changed, each with its own answer below.") and ok
	# The same offer to a pack with no record at all: every file a question, nothing assumed.
	DirAccess.remove_absolute(EventSheetPackManifest.manifest_path(folder))
	var blind: Dictionary = EventSheetPackUpdate.plan(folder, incoming)
	ok = _check("with no record, nothing is untouched",
		(blind.get("untouched", []) as Array).size(), 1) and ok
	ok = _check("everything already here is a question",
		_lines(blind.get("yours", [])), PackedStringArray([
			"guide.md - this version rewrites it",
			"notes.txt - dropped by this version",
			"probe_pack.gd - this version rewrites it",
		])) and ok
	ok = _check("and the summary says why",
		EventSheetPackUpdate.summary_text(blind),
		"This pack carries no record of what arrived, so all 3 file(s) are listed as yours and nothing is taken unless you say so.") and ok
	return ok


## Working out the whole proposal - the plan, the classification and the vocabulary diff - leaves
## every byte of the pack exactly where it was.
static func _test_asking_writes_nothing() -> bool:
	var folder: String = _fresh_pack()
	EventSheetPackManifest.stamp(folder, "1.0.0")
	var before: Dictionary = _folder_hashes(folder)
	var incoming: Dictionary = {"probe_pack.gd": PACK_V2.to_utf8_buffer(),
		"guide.md": GUIDE_V2.to_utf8_buffer()}
	var offered: Dictionary = EventSheetPackUpdate.plan(folder, incoming)
	EventSheetPackUpdate.vocabulary(folder, incoming)
	EventSheetPackUpdateDialog.diff_text(folder.path_join("guide.md"), incoming["guide.md"])
	var ok: bool = _check("asking changed nothing on disk", _folder_hashes(folder), before)
	ok = _check("and the pack the question was about is still the one that was there",
		bool(offered.get("unrecorded", true)), false) and ok
	ok = _check("the reflected copy of the incoming version is not left behind",
		DirAccess.dir_exists_absolute(EventSheetPackUpdate.REFLECT_DIR), false) and ok
	return ok


# ── 5. Taking it ──────────────────────────────────────────────────────────────────────────────


## Apply: the ring first, then the writes, and a "keep mine" answer honoured to the byte.
static func _test_taking_it_backs_up_first() -> bool:
	var folder: String = _fresh_pack()
	EventSheetPackManifest.stamp(folder, "1.0.0")
	var mine: String = "# Probe pack\n\nMy own words.\n"
	_write(folder.path_join("guide.md"), mine)
	for stale: String in EventSheetBackups.list_backups(folder.path_join("probe_pack.gd")):
		DirAccess.remove_absolute(stale)
	var incoming: Dictionary = {"probe_pack.gd": PACK_V2.to_utf8_buffer(),
		"guide.md": GUIDE_V2.to_utf8_buffer()}
	var offered: Dictionary = EventSheetPackUpdate.plan(folder, incoming)
	var done: Dictionary = EventSheetPackUpdate.apply(folder, incoming, offered, {}, "2.0.0")
	var ok: bool = _check("the script this version rewrites took the new version",
		FileAccess.get_file_as_string(folder.path_join("probe_pack.gd")), PACK_V2)
	ok = _check("the file you had changed was kept, to the byte",
		FileAccess.get_file_as_string(folder.path_join("guide.md")), mine) and ok
	ok = _check("the file this version drops is gone",
		FileAccess.file_exists(folder.path_join("notes.txt")), false) and ok
	# The line NAMES the ring and the door onto it. "2 went into the backup ring" is a number a
	# reader has to trust; the folder they are in, and the button that lists them, are things they
	# can act on.
	ok = _check("what happened is said in four numbers, and where the old bytes went",
		EventSheetPackUpdateDialog.applied_text(done),
		"1 file(s) took the new version, 1 were removed, 1 of yours were kept. 2 went into the backup ring first. The previous bytes of those 2 file(s) are in the backup ring, under %s - Restore\u2026 on this pack's row lists them." % EventSheetBackups.BACKUPS_ROOT) and ok
	ok = _check("and an update that rang nothing says nothing about a ring",
		EventSheetPackUpdate.backup_note({"backed_up": 0}), "") and ok
	var ring: PackedStringArray = EventSheetBackups.list_backups(folder.path_join("probe_pack.gd"))
	ok = _check("the previous version of the script is in the ring", ring.size(), 1) and ok
	if ring.size() == 1:
		ok = _check("holding exactly the bytes that were there before",
			FileAccess.get_file_as_string(ring[0]), PACK_V1) and ok
	ok = _check("the record now describes the folder as this update left it",
		_states(EventSheetPackManifest.classify(folder)),
		{"guide.md": "untouched", "probe_pack.gd": "untouched"}) and ok
	ok = _check("and the version it arrived as is written down",
		str(EventSheetPackManifest.read(folder).get("version", "")), "2.0.0") and ok
	for stale: String in EventSheetBackups.list_backups(folder.path_join("probe_pack.gd")):
		DirAccess.remove_absolute(stale)
	for stale_guide: String in EventSheetBackups.list_backups(folder.path_join("guide.md")):
		DirAccess.remove_absolute(stale_guide)
	return ok


## THE RECORD SAYS WHAT THE FOLDER NOW HOLDS. The field exists so a LATER update can say what it is
## updating FROM, and the manager passed no version at all - so it was stamped blank and the second
## update of any pack was blind. Left empty it is read back off the folder once the writing is done,
## which is the only reading that can be right: an update has no version of its own until the files
## are on disk.
static func _test_the_record_says_what_it_now_holds() -> bool:
	var folder: String = _fresh_pack()
	EventSheetPackManifest.stamp(folder, "1.0.0")
	var incoming: Dictionary = {"probe_pack.gd": PACK_V2.to_utf8_buffer(),
		"guide.md": GUIDE_V2.to_utf8_buffer()}
	var ok: bool = _check("the version this folder declares is read off the folder itself",
		EventSheetPackUpdate.installed_version(folder), "")
	EventSheetPackUpdate.apply(folder, incoming,
		EventSheetPackUpdate.plan(folder, incoming), {})
	ok = _check("after the update the folder declares the new version",
		EventSheetPackUpdate.installed_version(folder), "2.1.0") and ok
	ok = _check("and that is what the record was stamped with, rather than a blank",
		str(EventSheetPackManifest.read(folder).get("version", "")), "2.1.0") and ok
	# A version handed in explicitly still wins - the attach path knows what it landed.
	EventSheetPackManifest.stamp(folder, "2.1.0")
	EventSheetPackUpdate.apply(folder, incoming,
		EventSheetPackUpdate.plan(folder, incoming), {}, "9.9.9")
	ok = _check("a version the caller does know is used as given",
		str(EventSheetPackManifest.read(folder).get("version", "")), "9.9.9") and ok
	for stale: String in EventSheetBackups.list_backups(folder.path_join("probe_pack.gd")):
		DirAccess.remove_absolute(stale)
	for stale_guide: String in EventSheetBackups.list_backups(folder.path_join("guide.md")):
		DirAccess.remove_absolute(stale_guide)
	return ok


## THE DRY RUN ANSWERS THE VOCABULARY THE UPDATE WOULD LEAVE. The button beside the vocabulary
## section promises "every row that would be rewritten", and the forwarding address it is about is
## the INCOMING version's - which does not exist in the packs the project has today, so a receipt
## drawn against those shows what the update would do only by accident.
static func _test_the_dry_run_answers_the_incoming_vocabulary() -> bool:
	var folder: String = _fresh_pack()
	var incoming: Dictionary = {"probe_pack.gd": PACK_V2.to_utf8_buffer()}
	var after: Dictionary = EventSheetPackUpdate.vocabulary_after(folder, incoming)
	var ok: bool = _check("the incoming version's own verb is in it",
		after.has("ProbePack::method:wave"), true)
	if not ok:
		print("  [why] keys were: %s" % str(after.keys()))
		return false
	ok = _check("carrying the address only the new version has",
		EventForgeSuccessors.normalize_map(
			(after["ProbePack::method:wave"] as Dictionary).get("map", {})),
		{"id": "Core::Print", "renames": {"times": "text"}, "defaults": {}}) and ok
	ok = _check("the verb the new version adds is in it too",
		after.has("ProbePack::method:wave_twice"), true) and ok
	ok = _check("and so is the installed vocabulary it is laid over",
		after.has("Core::GoToState"), true) and ok
	# The installed version carries no address, so the receipt drawn against TODAY's packs would
	# have nothing to say about the very row the dry run is about.
	ok = _check("which the vocabulary installed today does not",
		EventForgeSuccessors.catalog().has("ProbePack::method:wave"), false) and ok
	# And an archive holding no script for this pack answers nothing rather than a half-corpus.
	ok = _check("an archive with no script for this pack answers nothing",
		EventSheetPackUpdate.vocabulary_after(folder, {"guide.md": GUIDE_V2.to_utf8_buffer()}),
		{}) and ok
	return ok


## A RING FOLDER'S NAME IS MANY-TO-ONE, AND THE ENTRY INSIDE IS NOT.
##
## The folder is the file's whole path with its separators replaced by underscores, so a top-level
## `sub_guide.md` and a removed `sub/guide.md` land in the SAME folder. The ring lists a folder's
## entries by their sequence prefix alone, without asking which file each came from - so the row for
## one of those two could offer the other's bytes and then write them over it, which is the one thing
## a door that writes files must never do. Each entry carries the file's own name after the sequence,
## and that is what decides.
static func _test_a_ring_folder_is_many_to_one() -> bool:
	var folder: String = _fresh_pack()
	_write(folder.path_join("sub_guide.md"), "the file at the top of the pack
")
	var ring: String = EventSheetBackups.backup_dir_for(folder.path_join("sub_guide.md"))
	var crossed: String = EventSheetBackups.backup_dir_for(folder.path_join("sub/guide.md"))
	var ok: bool = _check("the two paths really do share one ring folder", ring, crossed)
	DirAccess.make_dir_recursive_absolute(ring)
	_write(ring.path_join("0001.guide.md"), "the deeper file's bytes
")
	_write(ring.path_join("0002.sub_guide.md"), "the top-level file's bytes
")
	var said: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetPackUpdate.restorable(folder):
		if str(entry.get("path", "")) == "sub_guide.md":
			said.append(str(entry.get("backup", "")).get_file())
	ok = _check("the row offers only the entry written from the file it is about", said,
		PackedStringArray(["0002.sub_guide.md"])) and ok
	DirAccess.remove_absolute(ring.path_join("0001.guide.md"))
	DirAccess.remove_absolute(ring.path_join("0002.sub_guide.md"))
	DirAccess.remove_absolute(ring)
	_clear_fixture()
	return ok
# ── the fixture ───────────────────────────────────────────────────────────────────────────────


## A clean v1 pack folder under user://, rebuilt from nothing on every call so no test can be
## answered by what the one before it left behind.
# ── 6. the door onto the ring ─────────────────────────────────────────────────────────────────


## WHAT THE RING IS HOLDING, AND ONE ENTRY PUT BACK - both by value, over a ring this test filled by
## running a real update.
##
## The interesting row is the file the update REMOVED. It is not in the folder any more, so nothing
## in the pack points at it and nothing but the ring remembers it existed; listing it, saying so, and
## writing it back are the whole reason this door exists. The other row is the ordinary one: a file
## the update overwrote, put back to the bytes it had before.
##
## And the standing promise, asked twice: the ring is exactly as big afterwards as it was before. A
## restore reads it and copies out of it; only a save or an update ever adds to it.
static func _test_the_ring_has_a_door() -> bool:
	var folder: String = _fresh_pack()
	EventSheetPackManifest.stamp(folder, "1.0.0")
	_clear_ring(folder)
	var incoming: Dictionary = {"probe_pack.gd": PACK_V2.to_utf8_buffer(),
		"guide.md": GUIDE_V2.to_utf8_buffer()}
	EventSheetPackUpdate.apply(folder, incoming,
		EventSheetPackUpdate.plan(folder, incoming), {}, "2.0.0")

	# THE LISTING. Files in path order, and each says what it is and whether the pack still has it.
	var listed: Array[Dictionary] = EventSheetPackUpdate.restorable(folder)
	var said: PackedStringArray = PackedStringArray()
	for entry: Dictionary in listed:
		said.append("%s %d byte(s)%s" % [str(entry.get("path", "")), int(entry.get("bytes", 0)),
			" - gone from the pack" if bool(entry.get("gone", false)) else ""])
	var ok: bool = _check("the ring lists every file it holds an earlier version of, in path order",
		said, PackedStringArray([
			"guide.md %d byte(s)" % GUIDE_V1.to_utf8_buffer().size(),
			"notes.txt %d byte(s) - gone from the pack" % NOTES_V1.to_utf8_buffer().size(),
			"probe_pack.gd %d byte(s)" % PACK_V1.to_utf8_buffer().size(),
		]))
	ok = _check("and the window says what it is about", EventSheetPackRestoreDialog.summary_text(
		folder, listed),
		"probe_pack - the backup ring is holding 3 earlier version(s) of 3 file(s). Choose one and it is written back over the file in the pack, as one edit you can undo.") and ok
	# The line a row reads, pinned over an entry written HERE, so the time in it is a value rather
	# than whatever the clock said while the fixture was being built.
	ok = _check("a row says the file, when that copy was taken and how big it is",
		EventSheetPackUpdate.restore_line({"path": "guide.md", "when": "2026-09-04T09:15:00",
			"bytes": 31, "gone": false}),
		"guide.md - 2026-09-04T09:15:00, 31 byte(s)") and ok
	ok = _check("and says so when the pack no longer has that file at all",
		EventSheetPackUpdate.restore_line({"path": "notes.txt", "when": "2026-09-04T09:15:00",
			"bytes": 8, "gone": true}),
		"notes.txt - 2026-09-04T09:15:00, 8 byte(s) (this file is not in the pack any more)") and ok

	var held: int = listed.size()
	var undo: EventSheetEditorTest.FakeEditorUndoRedoManager = EventSheetEditorTest.FakeEditorUndoRedoManager.new()

	# THE FILE THE UPDATE REMOVED, written back.
	var gone_entry: Dictionary = _entry_for(listed, "notes.txt")
	var receipt: Dictionary = EventSheetPackUpdate.restore(gone_entry, undo)
	ok = _check("the file the update removed is back, to the byte",
		FileAccess.get_file_as_string(folder.path_join("notes.txt")), NOTES_V1) and ok
	ok = _check("and the receipt says what happened and how to take it back",
		EventSheetPackUpdate.restore_text(receipt),
		"notes.txt is back in the pack, %d byte(s), from the backup ring. It was not in the folder at all until now. Ctrl+Z removes it again, and the ring is untouched." % NOTES_V1.to_utf8_buffer().size()) and ok
	undo.undo()
	ok = _check("one Ctrl+Z takes it away again, because there was nothing there before",
		FileAccess.file_exists(folder.path_join("notes.txt")), false) and ok

	# THE FILE THE UPDATE OVERWROTE, put back to the bytes it had.
	var overwritten: Dictionary = _entry_for(listed, "probe_pack.gd")
	var second: Dictionary = EventSheetPackUpdate.restore(overwritten, undo)
	ok = _check("the overwritten script is back to the bytes it had before the update",
		FileAccess.get_file_as_string(folder.path_join("probe_pack.gd")), PACK_V1) and ok
	ok = _check("with its own receipt", EventSheetPackUpdate.restore_text(second),
		"probe_pack.gd was put back from the backup ring, %d byte(s). Ctrl+Z writes the bytes that were there before, and the ring is untouched." % PACK_V1.to_utf8_buffer().size()) and ok
	undo.undo()
	ok = _check("and Ctrl+Z writes back exactly what the update had left",
		FileAccess.get_file_as_string(folder.path_join("probe_pack.gd")), PACK_V2) and ok

	# THE RING IS UNTOUCHED BY ANY OF IT.
	ok = _check("the ring holds exactly what it held before the door was opened",
		EventSheetPackUpdate.restorable(folder).size(), held) and ok
	# And an entry a later save has pruned out from under the window writes nothing at all.
	ok = _check("a backup that has gone since the list was drawn is refused in words",
		EventSheetPackUpdate.restore_text(EventSheetPackUpdate.restore(
			{"path": "guide.md", "folder": folder, "target": folder.path_join("guide.md"),
				"backup": "user://eventforge_no_such_backup"}, undo)),
		"That backup is not there any more - the ring keeps a fixed number of them, and a save since this list was drawn has pushed it out.") and ok
	ok = _check("and leaves the file exactly as it was",
		FileAccess.get_file_as_string(folder.path_join("guide.md")), GUIDE_V2) and ok
	ok = _test_the_two_roots(folder, listed, undo) and ok
	ok = _test_the_way_back_says_so(folder, undo) and ok
	_clear_ring(folder)
	return ok


## THE TWO ROOTS. `restore()` is a public static, so the dictionary handed to it is what decides
## which file gets written - which makes "the target is inside the pack folder the entry names, and
## the bytes come out of the backup ring" a thing to CHECK rather than a thing to assume. Both
## refusals are asked for by value, and both are asked with a real backup in hand so the refusal is
## the reason rather than the missing file.
static func _test_the_two_roots(folder: String, listed: Array[Dictionary],
		undo: EventSheetEditorTest.FakeEditorUndoRedoManager) -> bool:
	var real_backup: String = str(_entry_for(listed, "guide.md").get("backup", ""))
	var elsewhere: String = "user://_pack_update_outside_probe.txt"
	# The path this must NOT be written to is cleared first: `user://` outlives a run, so a leftover
	# from an earlier one would report a guard that fired as a guard that did not.
	DirAccess.remove_absolute(elsewhere)
	var ok: bool = _check("a target outside the pack folder is refused in words, and nothing is written",
		EventSheetPackUpdate.restore_text(EventSheetPackUpdate.restore(
			{"path": "guide.md", "folder": folder, "target": elsewhere,
				"backup": real_backup}, undo)),
		"Nothing was written. A restore only ever puts a file back inside the pack folder its own entry names, out of the backup ring, and %s is not that." % elsewhere)
	ok = _check("so the file it named was never made", FileAccess.file_exists(elsewhere), false) and ok
	# The other root, asked with the pack's own file as the source: bytes that did not come out of the
	# ring are not a restore, whatever they are.
	var inside: String = folder.path_join("guide.md")
	ok = _check("and bytes from outside the backup ring are refused the same way",
		EventSheetPackUpdate.restore_text(EventSheetPackUpdate.restore(
			{"path": "guide.md", "folder": folder, "target": inside,
				"backup": folder.path_join("probe_pack.gd")}, undo)),
		"Nothing was written. A restore only ever puts a file back inside the pack folder its own entry names, out of the backup ring, and %s is not that." % inside) and ok
	ok = _check("leaving that file exactly as it was",
		FileAccess.get_file_as_string(inside), GUIDE_V2) and ok
	# An entry that names no pack folder at all is the same refusal: there is nothing to be inside of.
	ok = _check("an entry naming no pack folder is refused rather than trusted",
		bool(EventSheetPackUpdate.restore({"path": "guide.md", "target": inside,
			"backup": real_backup}, undo).get("restored", false)), false) and ok
	return ok


## THE WAY BACK SAYS SO. A restore's Ctrl+Z writes a file that can be the pack's own `.gd` - the
## vocabulary itself - so it goes through the same three steps the press does: the sentence, the
## redrawn list, the registry. Pinned here as the sentence the door is handed, in both directions,
## plus the folder the write had to make being taken away with the file it was made for.
static func _test_the_way_back_says_so(folder: String,
		undo: EventSheetEditorTest.FakeEditorUndoRedoManager) -> bool:
	var said: PackedStringArray = PackedStringArray()
	EventSheetPackUpdate.announce_restore_undone_to(func(line: String) -> void: said.append(line))
	# The overwrite direction first, over the file the pack still has.
	var ring: Array[Dictionary] = EventSheetPackUpdate.restorable(folder)
	var overwritten: Dictionary = _entry_for(ring, "guide.md")
	EventSheetPackUpdate.restore(overwritten, undo)
	undo.undo()
	var ok: bool = _check("taking a restore back says so, rather than writing in silence",
		said, PackedStringArray(["That restore was taken back - guide.md is what it was before it, and the backup ring is untouched."]))
	# And the removal direction, into a folder the pack does not have - so the write has to make one.
	said.clear()
	var deep: String = folder.path_join("sub/deep.md")
	EventSheetPackUpdate.restore({"path": "sub/deep.md", "folder": folder, "target": deep,
		"backup": str(overwritten.get("backup", ""))}, undo)
	ok = _check("a restore into a folder the pack does not have makes the folder",
		DirAccess.dir_exists_absolute(folder.path_join("sub")), true) and ok
	undo.undo()
	ok = _check("and one Ctrl+Z takes the file away", FileAccess.file_exists(deep), false) and ok
	ok = _check("and the folder the write had to make with it",
		DirAccess.dir_exists_absolute(folder.path_join("sub")), false) and ok
	ok = _check("saying so in the same words", said,
		PackedStringArray(["That restore was taken back - deep.md is what it was before it, and the backup ring is untouched."])) and ok
	# A static handler outlives the test that set it, so it is put back the way it was found.
	EventSheetPackUpdate.announce_restore_undone_to(Callable())
	return ok


## One listed entry by the file it is about, or {} - the newest, which is what the list offers first.
static func _entry_for(listed: Array[Dictionary], relative: String) -> Dictionary:
	for entry: Dictionary in listed:
		if str(entry.get("path", "")) == relative:
			return entry
	return {}


## Empties this fixture pack's rings, so a run starts from a ring with nothing in it whatever the
## previous run left. The ring lives under `user://`, outside the project, and only these fixtures
## ever write to this pack's corner of it.
static func _clear_ring(folder: String) -> void:
	for relative: String in ["probe_pack.gd", "guide.md", "notes.txt"]:
		for stale: String in EventSheetBackups.list_backups(folder.path_join(relative)):
			DirAccess.remove_absolute(stale)


static func _fresh_pack() -> String:
	_clear_fixture()
	var folder: String = FIXTURE_ROOT.path_join(PACK_DIR)
	DirAccess.make_dir_recursive_absolute(folder)
	_write(folder.path_join("probe_pack.gd"), PACK_V1)
	_write(folder.path_join("guide.md"), GUIDE_V1)
	_write(folder.path_join("notes.txt"), NOTES_V1)
	return folder


static func _clear_fixture() -> void:
	var folder: String = FIXTURE_ROOT.path_join(PACK_DIR)
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)
	DirAccess.remove_absolute(FIXTURE_ROOT)


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


## {path: state} for a row list - the shape a failure prints readably.
static func _states(rows: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for row: Dictionary in rows:
		out[str(row.get("path", ""))] = str(row.get("state", ""))
	return out


static func _note(rows: Array[Dictionary], path: String) -> String:
	for row: Dictionary in rows:
		if str(row.get("path", "")) == path:
			return str(row.get("note", ""))
	return "<no row for %s>" % path


static func _lines(rows: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for row: Variant in rows:
		out.append(EventSheetPackUpdate.row_text(row as Dictionary))
	return out


static func _folder_hashes(folder: String) -> Dictionary:
	var out: Dictionary = {}
	for relative: String in EventSheetPackManifest.files_of(folder):
		out[relative] = EventSheetPackManifest.hash_file(folder.path_join(relative))
	return out


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		print("[PASS] pack_update_test: %s" % label)
		return true
	print("[FAIL] pack_update_test: %s (expected %s, got %s)" % [label, expected, got])
	return false
