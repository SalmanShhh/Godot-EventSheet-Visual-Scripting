# Godot EventSheets - the Doctor's Ship It section.
#
# Every other section of the audit is about whether the game WORKS. This one is about whether it can
# leave the building, and it exists because the things that stop a game shipping are never the things
# anybody is looking at:
#
#   NO EXPORT PRESET      there is nothing to build a release from. The project runs perfectly and
#                         has no answer at all to "send me a build".
#   CONSOLE IN A RELEASE   a log line an exported game still runs. Harmless the first time, a scrolling
#                         wall on a player's machine by the tenth, and the one-step answer is a verb
#                         that already ships - Log (Debug Builds Only) compiles the line out.
#   STILL THE GODOT ICON   the window says nothing and the taskbar shows the engine's own logo. It is
#                         the single most visible unfinished thing about a first release.
#   A LANGUAGE THAT IS SHORT   a catalog missing keys the game asks for. The player sees the raw key.
#                         The missing keys come back as a ready-to-fill translation CSV rather than as
#                         a paragraph, because a list of forty keys is a FILE, not a sentence.
#   THE FRAME, WHERE IT WAS MEASURED   what the last stored profiler run says the rows cost per frame,
#                         against the 16.7 ms a 60 fps frame has. Silent with no stored run: a claim
#                         about speed with nothing measured behind it is worse than no claim.
#   WHAT GETS SAVED       the plain list of what this project writes to a slot. Not a warning - a page,
#                         so "does my save keep the coins" is answered by reading rather than by
#                         guessing.
#
# EVERY CHECK IS A PURE FUNCTION OVER ITS OWN INPUT, and the gathering is separate. That is what lets
# the tests pin the exact WORDS a reader meets - a count of findings tells nobody which finding moved -
# and it is also what keeps the section honest about cost: the project's scripts are read once, from
# the listing the rest of the audit already shares, and every check reads that one corpus.
#
# NOTHING IS STORED and nothing is written inside res://: every answer is derived on each ask, so a
# fixed project stops reporting with no state to clean up. The frame-budget check deliberately never
# LOADS the stored run either - it reports only a run some other reader already brought into memory,
# because a section that pulled a file into a process-wide cache would change what every later reader
# sees.
@tool
class_name EventSheetShipItDoctor
extends EventSheetDoctorSection

## The id the section is registered under. Frozen alongside the wording: the tests and the panel
## address a finding by these.
const CHECK_ID := "ship-it"
const CHECK_EXPORT_PRESET := "ship-export-preset"
const CHECK_DEBUG_ROWS := "ship-debug-rows"
const CHECK_IDENTITY := "ship-default-identity"
const CHECK_TRANSLATION := "ship-translation-coverage"
const CHECK_FRAME_BUDGET := "ship-frame-budget"
const CHECK_WHAT_GETS_SAVED := "ship-what-gets-saved"
const CHECK_PIXEL_SCALE := "ship-pixel-scale"
const CHECK_RENDERER := "ship-renderer-only"
const CHECK_SKY_BACKDROP := "ship-sky-backdrop"

## Where Godot keeps the export presets, and the header a preset is one of.
const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const PRESET_HEADER := "[preset."

## The two Project Settings a first release forgets, and the values that mean "nobody has touched it".
const NAME_SETTING := "application/config/name"
const ICON_SETTING := "application/config/icon"
const DEFAULT_ICONS: PackedStringArray = ["res://icon.svg", "res://icon.png"]
const PLACEHOLDER_NAMES: PackedStringArray = ["", "Godot Project", "New Game", "Untitled"]

## Where Project Settings lists the game's translation catalogs.
const TRANSLATIONS_SETTING := "internationalization/locale/translations"

## A frame at 60 fps. The budget everything here is measured against, and a fact rather than a taste,
## which is why it lives in the code and not in a theme.
const FRAME_MS := 16.7

## Rows costing more than this share of one frame are worth saying out loud. Below it the run is
## simply reported as measured and nothing is claimed.
const BUDGET_SHARE_WARN := 0.25

## The calls that write to the console. `print_debug` is left out on purpose: it is already the
## engine's own debug-only spelling and an exported release build strips it.
const CONSOLE_CALLS: PackedStringArray = [
	"print(", "print_rich(", "prints(", "printt(", "printraw(",
]

## The guard that makes a console line debug-only, in both spellings a row can compile to.
const DEBUG_GUARD := "OS.is_debug_build()"

## Folders whose scripts are not this project's to answer for: the plugin itself, the shipped packs,
## and the suite.
const NOT_MINE: PackedStringArray = [
	"res://addons/", "res://eventsheet_addons/", "res://tests/", "res://tools/",
]

## How many things a band NAMES before it starts counting. A finding that lists forty keys is a wall
## nobody reads; three and a number is a sentence.
const NAMED_LIMIT: int = 3


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetShipItDoctor, "check"))


## The section, with the contract every registered check has: append findings, never write inside
## res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(project_sources()))


## The whole section over one corpus of {script path: source text}. Pure, so a test hands it three
## made-up scripts and reads back the exact sentences.
static func report(sources: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(export_preset_findings(_read_text(EXPORT_PRESETS_PATH)))
	out.append_array(identity_findings(
		str(ProjectSettings.get_setting(NAME_SETTING, "")),
		str(ProjectSettings.get_setting(ICON_SETTING, ""))))
	out.append_array(debug_row_findings(sources))
	out.append_array(translation_findings(used_translation_keys(sources), catalog_keys()))
	out.append_array(frame_budget_findings(measured_costs(sources)))
	out.append_array(what_gets_saved_findings(save_usage(sources)))
	out.append_array(pixel_scale_findings(sources))
	out.append_array(renderer_findings(sources, str(ProjectSettings.get_setting(
		EventForgeEnvironmentWords.RENDERING_METHOD_SETTING,
		EventForgeEnvironmentWords.FORWARD_PLUS))))
	out.append_array(sky_backdrop_findings(sources))
	return out


## The project's own scripts and their text, read ONCE for the whole section. The listing comes from
## the audit's shared one, so this adds a read of each file and never a second walk of the tree.
static func project_sources() -> Dictionary:
	var sources: Dictionary = {}
	for script_path: String in EventSheetProjectDoctor._project_scripts():
		if _is_someone_elses(script_path):
			continue
		var text: String = EventSheetProjectDoctor.source_of(script_path)
		if not text.is_empty():
			sources[script_path] = text
	return sources


# ── There is nothing to build ────────────────────────────────────────────────────────────────


## No preset, no release. The file is read as TEXT rather than through ConfigFile because the only
## question is whether a preset section exists at all, and a half-written file should answer that the
## same way a missing one does.
static func export_preset_findings(preset_text: String) -> Array[Dictionary]:
	if preset_text.contains(PRESET_HEADER):
		return []
	return [_finding("warning", CHECK_EXPORT_PRESET, EXPORT_PRESETS_PATH,
		EventSheetL10n.translate("This project has no export preset, so there is nothing to build a release from. Project > Export > Add makes one for the platform you are shipping to."), "")]


# ── It still looks like a new project ────────────────────────────────────────────────────────


## The window title and the taskbar icon, which are the first two things anybody who is not you sees.
## Pure over the two settings, so the test does not have to move a real project's settings around.
static func identity_findings(project_name: String, icon_path: String) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if PLACEHOLDER_NAMES.has(project_name.strip_edges()):
		findings.append(_finding("warning", CHECK_IDENTITY, "res://project.godot",
			EventSheetL10n.translate("The game has no name of its own yet, so the window and the built file are both called after the project template. Project Settings > Application > Config > Name."), NAME_SETTING))
	if DEFAULT_ICONS.has(icon_path.strip_edges()):
		findings.append(_finding("warning", CHECK_IDENTITY, "res://project.godot",
			EventSheetL10n.translate("The icon is still the engine's own, so the taskbar shows Godot's logo rather than the game's. Project Settings > Application > Config > Icon."), ICON_SETTING))
	return findings


# ── A console line a player would see ────────────────────────────────────────────────────────


## One finding per script that writes to the console outside a debug-build guard, naming the first
## line and counting the rest. The scripts are walked in sorted order so two audits of an unchanged
## project read identically.
static func debug_row_findings(sources: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for script_path: String in _sorted_keys(sources):
		var lines: PackedStringArray = unguarded_console_lines(str(sources[script_path]))
		if lines.is_empty():
			continue
		var first: String = lines[0]
		var message: String = EventSheetL10n.translate("%s writes to the console where an exported release build still runs it - first: %s.") % [script_path.get_file(), first]
		if lines.size() > 1:
			message += " " + EventSheetL10n.translate("%d more like it in this file.") % (lines.size() - 1)
		message += " " + EventSheetL10n.translate("Log (Debug Builds Only) compiles the line out of a release game.")
		findings.append(_finding("warning", CHECK_DEBUG_ROWS, script_path, message, first))
	return findings


## The console lines this source runs in a release build, trimmed, in the order they appear.
##
## A line is GUARDED when it carries the debug-build test itself (the one-line spelling a row compiles
## to) or when it sits inside a block that opened with one. The block is tracked by INDENT rather than
## by parsing: a guard opens at some indent and everything more deeply indented than it is inside,
## which is exactly what GDScript means by a block and costs one integer to know.
static func unguarded_console_lines(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var guard_indent: int = -1
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var indent: int = _indent_of(raw_line)
		if guard_indent >= 0 and indent <= guard_indent:
			guard_indent = -1
		if line.contains(DEBUG_GUARD):
			if line.ends_with(":"):
				guard_indent = indent
			continue
		if guard_indent >= 0:
			continue
		for call_text: String in CONSOLE_CALLS:
			if line.begins_with(call_text):
				found.append(line)
				break
	return found


## Swaps every plain Log action in a sheet for the debug-builds-only one - the data half of the
## Doctor's one-click guard. Returns how many rows changed, so the caller re-saves (and reports)
## only when something really moved.
##
## The swap keeps the row's own words: the message and the stream it writes to are the same
## parameters on both verbs, so nothing the author typed is lost and the only change is the guard.
static func guard_debug_rows(sheet: EventSheetResource) -> int:
	if sheet == null:
		return 0
	var changed: int = _guard_rows(sheet.events)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			var event_function: EventFunction = entry
			changed += _guard_rows(event_function.events if not event_function.events.is_empty()
				else event_function.rows)
	return changed


## What the guard swap WOULD do, as before/after pairs of the row's compiled line. The receipt a
## reader is shown before an automated fix touches anything.
static func guard_receipt(sheet: EventSheetResource) -> Array[Dictionary]:
	var receipt: Array[Dictionary] = []
	if sheet == null:
		return receipt
	_collect_receipt(sheet.events, receipt)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			var event_function: EventFunction = entry
			_collect_receipt(event_function.events if not event_function.events.is_empty()
				else event_function.rows, receipt)
	return receipt


## The verb a plain Log becomes, and the template it compiles to. Both are shipped vocabulary, so the
## swap adds nothing new to the project - it picks the other word for the same sentence.
const PLAIN_LOG_ACE := "ConsoleLog"
const DEBUG_LOG_ACE := "ConsoleDebugLog"
const DEBUG_LOG_TEMPLATE := "if OS.is_debug_build(): {level}({message})"


static func _guard_rows(rows: Array) -> int:
	var changed: int = 0
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row
			changed += _guard_rows(group.events if not group.events.is_empty() else group.rows)
		elif row is EventRow:
			var event: EventRow = row
			for action: Variant in event.actions:
				if action is ACEAction and (action as ACEAction).ace_id == PLAIN_LOG_ACE:
					var typed: ACEAction = action
					typed.ace_id = DEBUG_LOG_ACE
					typed.codegen_template = DEBUG_LOG_TEMPLATE
					changed += 1
			changed += _guard_rows(event.sub_events)
	return changed


static func _collect_receipt(rows: Array, receipt: Array[Dictionary]) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row
			_collect_receipt(group.events if not group.events.is_empty() else group.rows, receipt)
		elif row is EventRow:
			var event: EventRow = row
			for action: Variant in event.actions:
				if action is ACEAction and (action as ACEAction).ace_id == PLAIN_LOG_ACE:
					var message: String = str(((action as ACEAction).params as Dictionary).get("message", ""))
					receipt.append({
						"before": "print(%s)" % message,
						"after": "if OS.is_debug_build(): print(%s)" % message,
					})
			_collect_receipt(event.sub_events, receipt)


# ── A language that is short ─────────────────────────────────────────────────────────────────


## Every key the game asks for, sorted and unique. Read from the emitted scripts because that is where
## the call really is, whoever typed it - a hand-written `tr("HUD_SCORE")` is the same promise a row's
## globe-marked parameter makes.
static func used_translation_keys(sources: Dictionary) -> PackedStringArray:
	var keys: Dictionary = {}
	for script_path: String in _sorted_keys(sources):
		for key: String in translation_keys_in(str(sources[script_path])):
			keys[key] = true
	var out: PackedStringArray = PackedStringArray()
	for key: Variant in keys.keys():
		out.append(str(key))
	out.sort()
	return out


## The literal keys one source hands to tr(). Only literals: a key built at run time is not something
## a catalog can be checked against, and reporting it would be a guess.
static func translation_keys_in(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var search_from: int = 0
	while true:
		var call_at: int = source.find("tr(\"", search_from)
		if call_at < 0:
			break
		search_from = call_at + 4
		# `tr(` has to be a call, not the tail of another identifier (`str(`, `attr("` and friends).
		if call_at > 0 and _is_identifier_char(source[call_at - 1]):
			continue
		var close_at: int = source.find("\"", search_from)
		if close_at < 0:
			break
		var key: String = source.substr(search_from, close_at - search_from)
		if not key.is_empty() and not found.has(key):
			found.append(key)
	return found


## What each configured catalog holds: {catalog path: sorted keys}. A catalog that will not load is
## left out rather than reported as empty - "this file is broken" is a different finding from "this
## file is short", and inventing the second from the first would accuse a translator of a build error.
static func catalog_keys() -> Dictionary:
	var out: Dictionary = {}
	var configured: PackedStringArray = PackedStringArray(
		ProjectSettings.get_setting(TRANSLATIONS_SETTING, PackedStringArray()))
	var paths: Array[String] = []
	for path: String in configured:
		paths.append(path)
	paths.sort()
	for path: String in paths:
		var catalog: Translation = load(path) as Translation
		if catalog == null:
			continue
		var keys: PackedStringArray = PackedStringArray()
		for key: StringName in catalog.get_message_list():
			keys.append(str(key))
		keys.sort()
		out[path] = keys
	return out


## One finding per catalog that is short, naming the first few missing keys and counting the rest.
## Silent when the project has no catalogs at all: a game with no translations is not a game with a
## broken one, and the untranslated-project note already owns that case.
static func translation_findings(used: PackedStringArray, catalogs: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if catalogs.is_empty() or used.is_empty():
		return findings
	for path: String in _sorted_keys(catalogs):
		var missing: PackedStringArray = missing_from(used, PackedStringArray(catalogs[path]))
		if missing.is_empty():
			continue
		findings.append(_finding("warning", CHECK_TRANSLATION, path,
			EventSheetL10n.translate("%s is missing %d key(s) the game asks for, so a player reading it sees the raw key: %s.") % [
				path.get_file(), missing.size(), _named_then_counted(missing)], path))
	return findings


## The keys `used` asks for that this catalog has no answer for, in the order they were asked.
static func missing_from(used: PackedStringArray, held: PackedStringArray) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	for key: String in used:
		if not held.has(key):
			missing.append(key)
	return missing


## The missing keys of every short catalog, as a translation CSV that Godot itself imports: one key
## per row, one column per catalog, every cell waiting to be filled. A list of forty keys is a FILE,
## and handing it over as one is the difference between a report and a job somebody can do.
##
## Deterministic to the byte - catalogs in sorted order, keys in the order the game asks for them - so
## exporting the same project twice writes the same file and a diff of two exports is the work that
## happened in between.
static func missing_keys_csv(used: PackedStringArray, catalogs: Dictionary) -> String:
	var paths: PackedStringArray = _sorted_keys(catalogs)
	var short_paths: PackedStringArray = PackedStringArray()
	var missing_by_path: Dictionary = {}
	var every_key: PackedStringArray = PackedStringArray()
	for path: String in paths:
		var missing: PackedStringArray = missing_from(used, PackedStringArray(catalogs[path]))
		if missing.is_empty():
			continue
		short_paths.append(path)
		missing_by_path[path] = missing
		for key: String in missing:
			if not every_key.has(key):
				every_key.append(key)
	if every_key.is_empty():
		return ""
	var header: PackedStringArray = PackedStringArray(["keys"])
	for path: String in short_paths:
		header.append(path.get_file().get_basename())
	var lines: PackedStringArray = PackedStringArray([",".join(header)])
	for key: String in every_key:
		var row: PackedStringArray = PackedStringArray([key])
		for _short_path: String in short_paths:
			row.append("")
		lines.append(",".join(row))
	return "\n".join(lines) + "\n"


# ── The frame, where it was measured ─────────────────────────────────────────────────────────


## What the stored run says the rows cost, joined to the file each row lives in: an Array of
## {"path", "ms", "per_frame"} - the milliseconds one fire cost and how many fires a frame saw.
##
## Never LOADS the run. It reports one some other reader (a sheet opening) already brought into
## memory, because a section that pulled a file into a process-wide cache would silently change what
## every later reader sees.
static func measured_costs(sources: Dictionary) -> Array[Dictionary]:
	if not EventSheetRunProfile.has_numbers():
		return []
	var costs: Array[Dictionary] = []
	for script_path: String in _sorted_keys(sources):
		var text: String = str(sources[script_path])
		for uid: String in _fired_uids_in(text):
			var ms: float = EventSheetRunProfile.ms_for(uid)
			if ms < 0.0:
				continue
			costs.append({
				"path": script_path, "ms": ms,
				"per_frame": EventSheetRunProfile.fires_per_frame(uid),
			})
	return costs


## The row ids a traced script reports as it runs. They are in the file because a traced build writes
## them there, which is the only reason a cost can be told which script it belongs to at all.
static func _fired_uids_in(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var needle: String = "__eventsheets_fired.append(\""
	var search_from: int = 0
	while true:
		var at: int = source.find(needle, search_from)
		if at < 0:
			break
		search_from = at + needle.length()
		var close_at: int = source.find("\"", search_from)
		if close_at < 0:
			break
		var uid: String = source.substr(search_from, close_at - search_from)
		if not uid.is_empty() and not found.has(uid):
			found.append(uid)
	return found


## The costliest file of a measured run, against the frame it has to fit in. Pure over the joined
## costs, so a test states three rows and reads the sentence back.
static func frame_budget_findings(costs: Array[Dictionary]) -> Array[Dictionary]:
	if costs.is_empty():
		return []
	var per_file: Dictionary = {}
	for cost: Dictionary in costs:
		var path: String = str(cost.get("path", ""))
		per_file[path] = float(per_file.get(path, 0.0)) \
			+ float(cost.get("ms", 0.0)) * float(cost.get("per_frame", 0.0))
	var worst_path: String = ""
	var worst_ms: float = 0.0
	for path: String in _sorted_keys(per_file):
		var ms: float = float(per_file[path])
		if ms > worst_ms:
			worst_ms = ms
			worst_path = path
	if worst_path.is_empty():
		return []
	var share: float = worst_ms / FRAME_MS
	var severity: String = "warning" if share >= BUDGET_SHARE_WARN else "info"
	return [_finding(severity, CHECK_FRAME_BUDGET, worst_path,
		EventSheetL10n.translate("%s costs %.2f ms of a frame in the last measured run - %d%% of the %.1f ms a 60 fps frame has.") % [
			worst_path.get_file(), worst_ms, int(round(share * 100.0)), FRAME_MS], worst_path)]


# ── What gets saved ──────────────────────────────────────────────────────────────────────────


## What this project writes to a slot, per script: {script path: the keys it saves}. Read through the
## audit's own save-key reading, so the page and the save-symmetry warning can never disagree about
## what a save call is.
static func save_usage(sources: Dictionary) -> Dictionary:
	var usage: Dictionary = {}
	for script_path: String in _sorted_keys(sources):
		var keys: PackedStringArray = EventSheetProjectDoctor.save_key_usage(str(sources[script_path])).get("saved", PackedStringArray())
		if not keys.is_empty():
			usage[script_path] = keys
	return usage


## The page: one note stating what a slot of this game holds. A note rather than a warning, because
## nothing here is wrong - it is the answer to "does my save keep the coins", which is otherwise
## answered by reading emitted code.
static func what_gets_saved_findings(usage: Dictionary) -> Array[Dictionary]:
	if usage.is_empty():
		return []
	var keys: PackedStringArray = PackedStringArray()
	for script_path: String in _sorted_keys(usage):
		for key: String in PackedStringArray(usage[script_path]):
			if not keys.has(key):
				keys.append(key)
	keys.sort()
	return [_finding("info", CHECK_WHAT_GETS_SAVED, _sorted_keys(usage)[0],
		EventSheetL10n.translate("A save slot of this game holds %d value(s), written from %d script(s): %s. Anything not on this list is back to its starting value when a slot is loaded.") % [
			keys.size(), usage.size(), _named_then_counted(keys)], "")]


# ── Sharp pixels, asked for by a fraction ─────────────────────────────────────


## The line every Keep Pixels Sharp row writes when the answer is yes, and the line every Pixel Size
## row writes. Matched as text because the Doctor reads emitted SCRIPTS: `.gd` is the default sheet
## format, so a walk of sheet resources would miss most real projects.
const SHARP_PIXELS_LINE := "content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER"
const PIXEL_SIZE_LINE := "content_scale_factor = "


## Whole pixels and a fraction asked for in the same file. Godot rounds the scale DOWN to a whole
## number while whole pixels are being kept, so a game asking for 2.5 gets 2 and the row that asked
## is not the size the player sees. An info note rather than a warning, because both halves are
## deliberate settings and the fix is a decision (round the number, or let the fraction through)
## rather than a defect - and silent unless the number is really a literal fraction, since a factor
## computed at run time is nobody's business to guess at.
static func pixel_scale_findings(sources: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for script_path: String in _sorted_keys(sources):
		var text: String = str(sources[script_path])
		if not text.contains(SHARP_PIXELS_LINE):
			continue
		var fraction: String = fractional_pixel_size(text)
		if fraction.is_empty():
			continue
		findings.append(_finding("info", CHECK_PIXEL_SCALE, script_path,
			EventSheetL10n.translate("%s keeps pixels sharp and then asks for a pixel size of %s. Whole pixels only means the window rounds that down, so the size a player gets is not the one the row asks for - use a whole number, or let the fraction through.") % [
				script_path.get_file(), fraction], fraction))
	return findings


## The first fractional pixel size this source asks for, as the reader wrote it, or "" when every
## size in it is a whole number (or is not a literal at all).
static func fractional_pixel_size(source: String) -> String:
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		var at: int = line.find(PIXEL_SIZE_LINE)
		if at < 0 or line.begins_with("#"):
			continue
		var written: String = line.substr(at + PIXEL_SIZE_LINE.length()).strip_edges()
		if not written.is_valid_float():
			continue
		var asked: float = written.to_float()
		if not is_equal_approx(asked, floorf(asked)):
			return written
	return ""


# ── A look the renderer will not draw ─────────────────────────────────────────

## The three words Godot's own Project Settings spell a rendering method with, in the plain word a
## finding says out loud. Only Forward+ draws screen-space reflections, indirect light, global
## illumination and volumetric fog; the other two set the flag and ignore it, which is why nothing
## errors and nothing appears.
const RENDERER_WORDS: Dictionary = {
	"mobile": "mobile",
	"gl_compatibility": "compatibility",
}


## A row that only works on Forward+, in a project that is not built for it. One quiet note per
## file, naming the first such row it holds and the renderer this project actually ships with -
## because the row does not error, does not warn and does not draw, which is the worst kind of
## nothing there is. An info note rather than a warning: both halves are deliberate settings, and
## the fix is a decision (build for Forward+, or drop the row) rather than a defect.
##
## The rows it knows are DERIVED from the environment and camera word tables, so a word marked
## Forward+ in either is noticed here with nothing added, and a word that stops being one stops being
## named.
static func renderer_findings(sources: Dictionary, rendering_method: String) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var renderer: String = str(RENDERER_WORDS.get(rendering_method.strip_edges(), ""))
	if renderer.is_empty():
		return findings
	for script_path: String in _sorted_keys(sources):
		var asked: String = forward_plus_asked_for(str(sources[script_path]))
		if asked.is_empty():
			continue
		findings.append(_finding("info", CHECK_RENDERER, script_path,
			EventSheetL10n.translate("%s asks for %s, which only the Forward+ renderer draws - this row does nothing on %s. Either build for Forward+, or drop the row.") % [
				script_path.get_file(), asked, renderer], asked))
	return findings


## The other half of the same question, which the environment word table cannot know: a COMPOSITOR.
## Only Forward+ has one, so every row of the camera's post stack draws nothing on the other two
## renderers - and this note has to carry its own door, because the answer there is not "build for
## Forward+" but "the 2D packs do the same looks on any renderer".
##
## One fragment covers the whole pack: every one of its rows is emitted through the behavior node's
## own path, so a file holding any of them holds this.
const COMPOSITOR_SPELLINGS: Array[Array] = [
	["$PostKitBehavior.",
		"a camera post effect (the Screen FX and Blend Modes packs do the same looks on any renderer)"],
]


## The first Forward+-only thing one source asks for, in the plain word a reader knows it by, or ""
## when it asks for none of them. The table's own order, so two files holding the same rows are
## reported the same way round; the compositor spellings are asked last, so a file holding both an
## environment word and a post-stack row still answers with the word it always did.
static func forward_plus_asked_for(source: String) -> String:
	for reason: Array in EventForgeEnvironmentWords.forward_plus_reasons():
		if source.contains(str(reason[0])):
			return str(reason[1])
	# The lens has one word of its own with the same problem: a camera that opens and closes itself
	# adjusts nothing on Mobile or Compatibility. Derived from the camera word table for the same
	# reason the environment's are derived from theirs - a note must never name a row that has
	# stopped shipping - and asked after them so a file holding both keeps the answer it always gave.
	for reason: Array in EventForgeCameraAttributeWords.forward_plus_reasons():
		if source.contains(str(reason[0])):
			return str(reason[1])
	for spelling: Array in COMPOSITOR_SPELLINGS:
		if source.contains(str(spelling[0])):
			return str(spelling[1])
	return ""


# ── A sky nothing is drawing ──────────────────────────────────────────────────

## What makes the sky the thing behind everything, in the exact bytes both rows that do it write.
const SKY_BACKDROP_LINE := "background_mode = Environment.BG_SKY"


## A file that sets the sky's colours and never makes the sky the backdrop. The sky words are written
## to do nothing rather than to error when the world is drawing a flat colour, so the rows run, cost
## nothing and change nothing - and the only place that can be said is here. An info note, with the
## door that fixes it in the words.
static func sky_backdrop_findings(sources: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for script_path: String in _sorted_keys(sources):
		var text: String = str(sources[script_path])
		if text.contains(SKY_BACKDROP_LINE) or not _writes_a_sky_word(text):
			continue
		findings.append(_finding("info", CHECK_SKY_BACKDROP, script_path,
			EventSheetL10n.translate("%s sets the sky's colours, and nothing in it makes the sky the backdrop - the rows do nothing while the world is drawing a flat colour. Use Procedural Sky, or set the backdrop to sky.") % script_path.get_file(),
			script_path.get_file()))
	return findings


## True when a source writes any of the five procedural-sky words, by the whole three-deep path they
## are reached through. Derived from the sky word table, so a word added there is noticed with
## nothing added here.
static func _writes_a_sky_word(source: String) -> bool:
	for word: String in EventForgeSkyWords.words():
		if source.contains("%s.%s = " % [EventForgeSkyWords.SKY_MATERIAL_PATH,
				EventForgeSkyWords.property_of(word)]):
			return true
	return false


# ── Shared ───────────────────────────────────────────────────────────────────────────────────


## A band names a few things and counts the rest - a finding that lists forty keys is a wall nobody
## reads.
static func _named_then_counted(items: PackedStringArray) -> String:
	if items.size() <= NAMED_LIMIT:
		return ", ".join(items)
	var named: PackedStringArray = PackedStringArray()
	for index: int in range(NAMED_LIMIT):
		named.append(items[index])
	return EventSheetL10n.translate("%s and %d more") % [", ".join(named), items.size() - NAMED_LIMIT]


static func _sorted_keys(source: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in source.keys():
		keys.append(str(key))
	keys.sort()
	return keys


static func _is_someone_elses(script_path: String) -> bool:
	for prefix: String in NOT_MINE:
		if script_path.begins_with(prefix):
			return true
	return false


static func _is_identifier_char(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper() or character.is_valid_int()


static func _indent_of(line: String) -> int:
	var indent: int = 0
	while indent < line.length() and (line[indent] == "\t" or line[indent] == " "):
		indent += 1
	return indent


static func _read_text(path: String) -> String:
	return EventSheetProjectDoctor.source_of(path) if FileAccess.file_exists(path) else ""
