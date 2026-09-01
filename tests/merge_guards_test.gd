# Godot EventSheets - the two things a merge can do to a sheet, and the guards in front of both.
#
# A merge is the one event that can put a sheet into a state nobody wrote. Two of those states are
# quiet enough to reach a running game: a file still holding marker lines, which is not GDScript at
# all, and two rows declaring the same baked local, which Godot refuses to parse. Both are pinned
# here, along with the mint that makes the second one rare in the first place.
#
# THE MINT CONSULTS THE PROJECT, and the exclusion is pinned as a VALUE rather than as a probability:
# the draw is seeded, the token it would have produced is put into the index in front of it, and the
# token it produces instead is the next one in the same sequence. That is the rule, observed.
#
# THE CONFLICT GUARD IS PINNED BY ITS BYTES. The promise is not that a blocked file looks a certain
# way - it is that opening and closing one leaves it exactly as it was, which is the same promise the
# whole plugin stands on, asked of the one kind of file that cannot round-trip at all.
#
# Nothing here writes inside res://. The fixtures live in `user://`, and the two that read the
# project read it without touching it.
@tool
class_name MergeGuardsTest
extends RefCounted

## The token the merged fixture doubles, and the one the re-mint hands back. Fixed rather than drawn,
## so the receipt below is a value and not a shape.
const DOUBLED_TOKEN := "a3f81c02"
const REMINTED_TOKEN := "b7c00001"

## Where the fixtures are written. `user://` so nothing under res:// is touched by a test.
const CONFLICTED_PATH := "user://eventforge_conflicted_fixture.gd"

## The line to commit, quoted here so the note and the test cannot drift apart.
const ATTRIBUTE_LINE := "*.gd text eol=lf"


static func run() -> bool:
	var ok: bool = _test_the_mint_consults_the_index()
	ok = _test_the_duplicate_is_named() and ok
	ok = _test_the_remint_is_one_token() and ok
	ok = _test_a_marker_file_opens_blocked() and ok
	ok = _test_the_bytes_survive() and ok
	ok = _test_the_endings_note() and ok
	ok = _test_sheets_are_written_with_unix_endings() and ok
	return ok


# ── 1. minting consults the index ─────────────────────────────────────────────────


## The exclusion, as a value. The draw is seeded so the next two tokens in the sequence are known;
## the FIRST is planted in the index as a token the project already holds; the mint must then hand
## back the SECOND, having skipped the one it would otherwise have produced.
##
## The index is restored to unbuilt afterwards, so the next mint in this process asks the project
## again rather than answering from a fixture's two tokens.
static func _test_the_mint_consults_the_index() -> bool:
	var kept: Dictionary = EventSheetDock._minted_uid_tokens.duplicate()
	EventSheetDock._minted_uid_tokens.clear()
	seed(20260901)
	var would_have_drawn: String = "%08x" % randi()
	var next_in_sequence: String = "%08x" % randi()
	var ok: bool = _check("the two draws are different tokens",
		would_have_drawn != next_in_sequence, true)

	# The project already holds the first one, so the mint has to skip it.
	seed(20260901)
	EventSheetLocalTokens.seed_index(PackedStringArray([would_have_drawn]))
	ok = _check("a token the project holds is taken",
		EventSheetLocalTokens.is_taken(would_have_drawn), true) and ok
	ok = _check("the mint skips it and draws the next one",
		EventSheetDock._fresh_uid_token(), next_in_sequence) and ok
	ok = _check("and records what it drew, so the next draw excludes that too",
		EventSheetLocalTokens.is_taken(next_in_sequence), true) and ok

	# And with nothing in the way, the seeded draw is simply the first token in the sequence - which
	# is what proves the skip above was the index and not the shuffle.
	seed(20260901)
	EventSheetLocalTokens.seed_index(PackedStringArray())
	EventSheetDock._minted_uid_tokens.clear()
	ok = _check("with an empty index the same seed draws the first one",
		EventSheetDock._fresh_uid_token(), would_have_drawn) and ok

	EventSheetLocalTokens.clear_index()
	EventSheetDock._minted_uid_tokens.clear()
	EventSheetDock._minted_uid_tokens.merge(kept)
	randomize()
	return ok


# ── 2. the duplicate, named ───────────────────────────────────────────────────────


## A file a merge brought two branches' rows into: the same baked local declared twice in one
## function. Named by token, by scope and by line, and NOT reported for the same token in two
## different bodies, which is two variables and nothing wrong.
static func _test_the_duplicate_is_named() -> bool:
	var declarations: Array[Dictionary] = EventSheetLocalTokens.declarations_in(_merged_source())
	var ok: bool = _check("every declaration is read, with its scope and its line",
		_flat(declarations), PackedStringArray([
			"__every_11110000|the class body|3",
			"__peer_a3f81c02|_ready|7",
			"__peer_a3f81c02|_ready|10",
			"__peer_a3f81c02|_on_host|14",
		]))
	var duplicates: Array[Dictionary] = EventSheetLocalTokens.duplicates_in(_merged_source())
	ok = _check("only the doubled scope is a duplicate", duplicates.size(), 1) and ok
	if duplicates.is_empty():
		return ok
	ok = _check("and it names the token, the scope and both lines",
		[str(duplicates[0]["name"]), str(duplicates[0]["scope"]),
			Array(duplicates[0]["lines"] as PackedInt32Array)],
		["__peer_%s" % DOUBLED_TOKEN, "_ready", [7, 10]]) and ok
	ok = _check("the words say it plainly first",
		EventSheetLocalTokens.duplicate_message(duplicates[0]).begins_with(
			"Two rows both declare __peer_%s in _ready (lines 7, 10)." % DOUBLED_TOKEN), true) and ok
	ok = _check("and a clean file has nothing to say",
		EventSheetLocalTokens.duplicates_in("extends Node\n\n\nfunc _ready() -> void:\n\tvar __peer_00000001 := 1\n"),
		([] as Array[Dictionary])) and ok
	return ok


# ── 3. the re-mint ────────────────────────────────────────────────────────────────


## The one-click repair: the row that was already there keeps the name it had, the row the merge
## brought in gets a name of its own, and every baked field of that row moves together. A row half
## re-minted would be worse than the duplicate, because it would compile.
static func _test_the_remint_is_one_token() -> bool:
	var sheet: EventSheetResource = _sheet_with_two_rows_sharing_a_token()
	var carriers: Array[Dictionary] = EventSheetLocalTokens.carriers(sheet, DOUBLED_TOKEN)
	var ok: bool = _check("both rows carry it, the stateful one across all four of its baked fields",
		carriers.size(), 5)
	ok = _check("and they are two rows",
		EventSheetLocalTokens.rows_carrying(sheet, DOUBLED_TOKEN).size(), 2) and ok

	var receipts: Array[Dictionary] = EventSheetLocalTokens.remint(sheet, DOUBLED_TOKEN,
		func() -> String: return REMINTED_TOKEN)
	ok = _check("one row is re-minted, not both", receipts.size(), 1) and ok
	if not receipts.is_empty():
		ok = _check("and the receipt is the name before and the name after",
			[str(receipts[0]["before"]), str(receipts[0]["after"]), int(receipts[0]["fields"])],
			["__peer_%s" % DOUBLED_TOKEN, "__peer_%s" % REMINTED_TOKEN, 4]) and ok
	var first: ACEAction = (sheet.events[0] as EventRow).actions[0] as ACEAction
	ok = _check("the row that was already there is untouched",
		first.codegen_template, _peer_template(DOUBLED_TOKEN)) and ok
	var second: ACECondition = (sheet.events[1] as EventRow).conditions[0] as ACECondition
	ok = _check("and the row the merge brought in moved every baked field together",
		[second.member_declaration, second.codegen_template, second.codegen_prelude,
			second.codegen_on_true],
		["var __peer_%s := 0.0" % REMINTED_TOKEN, "__peer_%s > 1.0" % REMINTED_TOKEN,
			"__peer_%s += delta" % REMINTED_TOKEN, "__peer_%s = 0.0" % REMINTED_TOKEN]) and ok
	ok = _check("re-minting again finds nothing, because there is no duplicate left",
		EventSheetLocalTokens.remint(sheet, DOUBLED_TOKEN,
			func() -> String: return "cccccccc"), ([] as Array[Dictionary])) and ok

	# And the door the inbox draws over the finding. The check id is the join between the section
	# that raises it and the chip that answers it, so it is pinned rather than assumed.
	var finding: Dictionary = {"check": EventSheetLocalTokens.CHECK_DUPLICATE_TOKEN,
		"subject": DOUBLED_TOKEN, "path": "res://player.gd"}
	ok = _check("the check id is the one the chip is offered against",
		EventSheetLocalTokens.CHECK_DUPLICATE_TOKEN, "duplicate-local-token") and ok
	ok = _check("and the finding offers exactly one door",
		_offered(finding), PackedStringArray(["remint_token|Re-mint one of them"])) and ok
	return ok


## What the inbox would draw on a finding, as "id|label" per chip.
static func _offered(finding: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for offer: Dictionary in EventSheetQuickFixes.fixes_for(finding):
		out.append("%s|%s" % [str(offer.get("id", "")), str(offer.get("label", ""))])
	return out


# ── 4. the conflict guard ─────────────────────────────────────────────────────────


## A file a merge has not finished with opens BLOCKED: read-only, with the marker lines it is blocked
## over recorded on it and named in the banner. The guard is textual, so a leftover half of a region
## blocks exactly as a whole one does - those were the files that used to open as ordinary sheets.
static func _test_a_marker_file_opens_blocked() -> bool:
	var source: String = _conflicted_source()
	var ok: bool = _check("every marker line is found, whichever of the four it is",
		Array(EventSheetConflictGuard.marker_line_numbers(source)), [5, 7, 9, 11])
	ok = _check("a stray closing marker blocks on its own",
		Array(EventSheetConflictGuard.marker_line_numbers(
			"extends Node\n>>>>>>> theirs\n")), [2]) and ok
	ok = _check("an indented row of equals signs is not a marker",
		EventSheetConflictGuard.blocks("extends Node\n\t# =======\n"), false) and ok
	ok = _check("and a clean file is not blocked",
		EventSheetConflictGuard.blocks("extends Node\n"), false) and ok
	ok = _check("the lines are read out in English",
		EventSheetConflictGuard.lines_phrase(PackedInt32Array([5, 7, 9, 11])),
		"lines 5, 7, 9 and 11") and ok

	var sheet: EventSheetResource = EventSheetConflictGuard.block(EventSheetResource.new(),
		EventSheetConflictGuard.marker_line_numbers(source))
	ok = _check("the blocked sheet is read-only and says why",
		[sheet.read_only, sheet.blocked_by_conflict(), Array(sheet.conflict_marker_lines)],
		[true, true, [5, 7, 9, 11]]) and ok
	ok = _check("the banner names the lines and points at the merge tool",
		EventSheetConflictGuard.banner_text("player.gd", sheet.conflict_marker_lines),
		"player.gd still has merge conflict markers on lines 5, 7, 9 and 11. It is not GDScript until they are gone, so it is open read-only here: nothing is lifted into rows, and Save is off. Finish the merge in the tool you started it in, then open it again.") and ok
	ok = _check("and an ordinary sheet is not blocked by any of it",
		EventSheetResource.new().blocked_by_conflict(), false) and ok
	return ok


## THE PROMISE: a conflicted file opened and closed is the file it was. Every question the guard asks
## of it is asked here in a row, and the bytes on disk are compared before and after.
static func _test_the_bytes_survive() -> bool:
	var before: String = _conflicted_source()
	var wrote: Error = _write(CONFLICTED_PATH, before)
	var ok: bool = _check("the fixture is written", wrote, OK)
	if wrote != OK:
		return ok
	ok = _check("the file on disk is blocked",
		EventSheetConflictGuard.blocks_file(CONFLICTED_PATH), true) and ok
	# Everything the open path does to such a file, in order: read it, find the markers, import the
	# raw rows, block the sheet. None of it is allowed to touch the file.
	var raw: EventSheetResource = GDScriptImporter.new().import_external(CONFLICTED_PATH, false)
	ok = _check("it still comes up as something to look at", raw != null, true) and ok
	if raw != null:
		EventSheetConflictGuard.block(raw,
			EventSheetConflictGuard.marker_line_numbers(FileAccess.get_file_as_string(CONFLICTED_PATH)))
		ok = _check("blocked, with no lift behind it", raw.blocked_by_conflict(), true) and ok
	ok = _check("and the file has not moved a byte",
		FileAccess.get_file_as_string(CONFLICTED_PATH), before) and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFLICTED_PATH))
	return ok


# ── 5. the line-ending note ───────────────────────────────────────────────────────


## The advisory note, over two fixtures: a checkout that pins how `.gd` files are stored says
## nothing, and one that leaves it to whatever each machine's git is set to gets the one line to
## commit. Read over TEXT rather than over the machine running the suite, so the rule is the same
## everywhere the suite runs.
static func _test_the_endings_note() -> bool:
	var pinned: String = "# how this project stores its files\n* text=auto eol=lf\n*.gd text eol=lf\n"
	var autocrlf_on: String = "[core]\n\trepositoryformatversion = 0\n\tautocrlf = true\n[remote \"origin\"]\n\turl = git@example.invalid:game.git\n"
	var ok: bool = _check("a pinned checkout says nothing, whatever git is set to",
		EventSheetLineEndings.note(pinned, autocrlf_on), "")
	ok = _check("and a pinned checkout is recognised as pinned",
		EventSheetLineEndings.attribute_pins_sheets(pinned), true) and ok
	ok = _check("`-text` pins it too", EventSheetLineEndings.attribute_pins_sheets("*.gd -text\n"),
		true) and ok
	ok = _check("a comment naming the attribute does not pin anything",
		EventSheetLineEndings.attribute_pins_sheets("# *.gd text eol=lf\n"), false) and ok
	ok = _check("the setting is read out of the config",
		EventSheetLineEndings.autocrlf_of(autocrlf_on), "true") and ok
	ok = _check("a config that does not set it says so",
		EventSheetLineEndings.autocrlf_of("[core]\n\tbare = false\n"), "") and ok
	ok = _check("and a setting under another section is not core's",
		EventSheetLineEndings.autocrlf_of("[core]\n\tbare = false\n[other]\n\tautocrlf = true\n"),
		"") and ok

	var misconfigured: String = EventSheetLineEndings.note("", autocrlf_on)
	ok = _check("an unpinned checkout with autocrlf on is told what is happening to it",
		misconfigured.begins_with("This checkout has core.autocrlf=true"), true) and ok
	ok = _check("and shown the one line to commit",
		misconfigured.ends_with(ATTRIBUTE_LINE), true) and ok
	var unpinned: String = EventSheetLineEndings.note("*.png binary\n", "")
	ok = _check("an unpinned checkout with the setting unset is told the next machine decides",
		unpinned.begins_with("Nothing in .gitattributes says how .gd files are stored"), true) and ok
	ok = _check("and shown the same one line", unpinned.ends_with(ATTRIBUTE_LINE), true) and ok
	ok = _check("the note is the line the module offers",
		EventSheetLineEndings.SHEET_ATTRIBUTE, ATTRIBUTE_LINE) and ok

	# And the reading of the project's own files works, which is the half a fixture cannot prove:
	# `.gitattributes` is a dot-file, and a reader that could not open it would report every project
	# as unpinned. This repository pins its own sheets, and that line is committed.
	ok = _check("the project's own attributes file is readable and pins .gd",
		EventSheetLineEndings.attribute_pins_sheets(
			FileAccess.get_file_as_string(EventSheetLineEndings.ATTRIBUTES_FILE)), true) and ok
	return ok


## The premise the note is about: a sheet compiles to Unix endings, on every platform. If this ever
## stopped being true the note would be advising people to pin the wrong thing.
static func _test_sheets_are_written_with_unix_endings() -> bool:
	var sheet: EventSheetResource = _sheet_with_two_rows_sharing_a_token()
	sheet.host_class = "Node"
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_endings_probe.gd").get("output", ""))
	var ok: bool = _check("the sheet compiles to something", output.length() > 20, true)
	return _check("and not one carriage return is in it", output.contains("\r"), false) and ok


# ── fixtures ──────────────────────────────────────────────────────────────────────


## A file two branches' rows landed in: one stateful member in the class body, the same baked local
## declared twice in `_ready`, and once more in another body where it is nobody's problem.
static func _merged_source() -> String:
	return "extends Node\n" \
		+ "\n" \
		+ "var __every_11110000 := 0.0\n" \
		+ "\n" \
		+ "\n" \
		+ "func _ready() -> void:\n" \
		+ "\tvar __peer_%s := ENetMultiplayerPeer.new()\n" % DOUBLED_TOKEN \
		+ "\t__peer_%s.create_server(7777, 4)\n" % DOUBLED_TOKEN \
		+ "\n" \
		+ "\tvar __peer_%s := ENetMultiplayerPeer.new()\n" % DOUBLED_TOKEN \
		+ "\n" \
		+ "\n" \
		+ "func _on_host() -> void:\n" \
		+ "\tvar __peer_%s := 1\n" % DOUBLED_TOKEN


## A file a merge left markers in - one whole region written with the base section a diff3 merge
## adds, so all four marker spellings are in it at once.
static func _conflicted_source() -> String:
	return "extends Node\n\n\nfunc _ready() -> void:\n" \
		+ "<<<<<<< HEAD\n\tspeed = 200\n||||||| base\n\tspeed = 100\n=======\n\tspeed = 300\n>>>>>>> theirs\n"


## Two rows carrying the same baked local: an action row that was already in the file, and a stateful
## condition row the merge brought in, whose token lives in four baked fields at once.
static func _sheet_with_two_rows_sharing_a_token() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	var already_there: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.ace_id = "HostGame"
	action.provider_id = "Multiplayer"
	action.codegen_template = _peer_template(DOUBLED_TOKEN)
	already_there.actions = [action]
	var arrived: EventRow = EventRow.new()
	var condition: ACECondition = ACECondition.new()
	condition.ace_id = "EverySeconds"
	condition.provider_id = "System"
	condition.member_declaration = "var __peer_%s := 0.0" % DOUBLED_TOKEN
	condition.codegen_template = "__peer_%s > 1.0" % DOUBLED_TOKEN
	condition.codegen_prelude = "__peer_%s += delta" % DOUBLED_TOKEN
	condition.codegen_on_true = "__peer_%s = 0.0" % DOUBLED_TOKEN
	arrived.conditions = [condition]
	sheet.events = [already_there, arrived]
	return sheet


static func _peer_template(token: String) -> String:
	return "var __peer_%s := ENetMultiplayerPeer.new()\n__peer_%s.create_server(7777, 4)" % [
		token, token]


## Declarations flattened to one comparable line each, so the assertion is a list of values rather
## than a walk of dictionaries.
static func _flat(declarations: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for entry: Dictionary in declarations:
		out.append("%s|%s|%d" % [str(entry["name"]), str(entry["scope"]), int(entry["line"])])
	return out


static func _write(path: String, text: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		print("[PASS] merge_guards_test: %s" % label)
		return true
	print("[FAIL] merge_guards_test: %s (expected %s, got %s)" % [label, expected, got])
	return false
