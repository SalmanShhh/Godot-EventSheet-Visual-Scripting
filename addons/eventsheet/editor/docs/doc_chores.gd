# Godot EventSheets - the documentation chores, written once and run from three places.
#
# THE CHORES ARE THE THING; THE DOORS ARE NOT. A person can do every one of these by hand: open each
# sheet and copy the page it writes about itself, read the guides and note what they do not answer,
# compare the shipped copy of a guide with its source, save the Manual as HTML, write out the keys a
# translator is missing. Doing them by hand is not hard, it is just tedious and easy to forget, and
# a forgotten chore is how documentation rots. So they live here, once, and three doors call them:
# a dialog in the editor, a command line for a hook or a build, and a CI workflow the reader owns.
# Three implementations of "regenerate the manual" would be three answers to one question inside a
# month.
#
# THE HONESTY LINE, which is a rule about behaviour and not a slogan:
#   - a chore only does what a person could do by hand, in the same order, with the same result;
#   - it produces the SAME report whichever door ran it;
#   - it never publishes. Drafted prose is written to a drafts file and stays a draft; nothing here
#     edits a guide, a sheet's description or a commit. A person decides what is true.
#
# DETERMINISTIC: no chore writes a timestamp, a machine name or an absolute path into anything it
# produces, and every walk it makes is sorted. Two runs over an unchanged project write the same
# bytes, which is what makes the output reviewable in version control.
#
# WHY THE REPORT IS NOT TRANSLATED WHILE THE CHORE NAMES ARE: the names are read in a dialog, in the
# reader's own editor, and belong in their language. The report is the same text in the dialog, in a
# terminal and in a CI log, and a build log that changed language depending on who ran it could not
# be compared with the one from yesterday. "The same report whichever door ran it" is the promise;
# one of them being in another language would break it.
@tool
class_name EventSheetDocChores
extends RefCounted

## The chore ids. FROZEN: a project remembers which boxes were ticked by these ids, and the command
## line names them, so a rename would silently un-tick somebody's dialog and break somebody's hook.
const CHORE_MANUAL := "manual"
const CHORE_HARVEST := "harvest"
const CHORE_DRAFTS := "drafts"
const CHORE_CHECK := "check"
const CHORE_SITE := "site"
const CHORE_KEYS := "keys"

## The order they run in, which is the order they depend on each other: the manual is regenerated
## before the site exports it, and the checks run before the site so a failing check is reported
## against what was actually exported.
const CHORE_ORDER: PackedStringArray = [CHORE_MANUAL, CHORE_HARVEST, CHORE_DRAFTS, CHORE_CHECK,
	CHORE_SITE, CHORE_KEYS]

## Where the chores put what they make. All inside the project, all in folders a person would have
## picked themselves, and none of them anywhere the plugin's own files live.
const MANUAL_SUBDIR := "manual"
const DRAFTS_FILE := "DRAFT-descriptions.md"
const SITE_SUBDIR := "site"

## The heading the drafts file carries, and the line under it. Both say the same thing the code
## does: these are drafts, nothing was applied, and a person decides.
const DRAFTS_TITLE := "Drafts: descriptions nothing has written yet"

## How many guides the coverage chore reads. The Doctor's own section reads a dozen because it runs
## inside a health audit with a time budget; a chore somebody asked for has no such budget and is
## expected to read everything.
const COVERAGE_READ_LIMIT: int = 4096


## Every chore, in run order: {id, label, note}. `note` is what the chore would cost a person to do
## by hand, which is the only honest way to describe automation.
static func chores() -> Array[Dictionary]:
	return [
		{"id": CHORE_MANUAL,
			"label": EventSheetL10n.translate("Rewrite the project manual and refresh the search"),
			"note": EventSheetL10n.translate("Writes the page each sheet writes about itself, then re-reads the Manual so the new pages are searchable.")},
		{"id": CHORE_HARVEST,
			"label": EventSheetL10n.translate("Harvest the engine's documentation"),
			"note": EventSheetL10n.translate("Only when this version of Godot has not been harvested yet. Nothing is downloaded: the engine writes its own reference.")},
		{"id": CHORE_DRAFTS,
			"label": EventSheetL10n.translate("Draft the descriptions nothing has written yet"),
			"note": EventSheetL10n.translate("Collected into one drafts file. Nothing is applied to a sheet or a guide - a draft stays a draft until you move it.")},
		{"id": CHORE_CHECK,
			"label": EventSheetL10n.translate("Check coverage and drift"),
			"note": EventSheetL10n.translate("Reports what the guides do not answer and where a shipped copy has drifted from the page it was copied from.")},
		{"id": CHORE_SITE,
			"label": EventSheetL10n.translate("Export the Manual as a site"),
			"note": EventSheetL10n.translate("The whole Manual as plain HTML files, with its search, that open in a browser with no server.")},
		{"id": CHORE_KEYS,
			"label": EventSheetL10n.translate("Write out the translator's missing keys"),
			"note": EventSheetL10n.translate("One spreadsheet of every key your game asks for that a catalog does not answer yet.")},
	]


## The chore with this id, or an empty Dictionary. Ids are frozen, so an unknown one is a caller's
## typo rather than something to guess at.
static func chore(id: String) -> Dictionary:
	for entry: Dictionary in chores():
		if str(entry["id"]) == id:
			return entry
	return {}


## Runs the named chores in CHORE_ORDER and answers ONE report, whichever door asked:
##   {ok, ran: [{id, ok, lines, wrote}], lines, wrote, failed}
## `lines` is the whole report in reading order and `wrote` every file that changed, so a dialog, a
## terminal and a CI log all show the same words.
##
## `options` is passed through to every chore; the ones they read are named at each chore below.
static func run(ids: PackedStringArray, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {"ok": true, "ran": [], "lines": PackedStringArray(),
		"wrote": PackedStringArray(), "failed": 0}
	for id: String in CHORE_ORDER:
		if not Array(ids).has(id):
			continue
		var entry: Dictionary = run_one(id, options)
		(report["ran"] as Array).append(entry)
		var lines: PackedStringArray = report["lines"]
		lines.append("%s:" % str(chore(id).get("label", id)))
		for line: String in (entry.get("lines", PackedStringArray()) as PackedStringArray):
			lines.append("  %s" % line)
		report["lines"] = lines
		var wrote: PackedStringArray = report["wrote"]
		wrote.append_array(entry.get("wrote", PackedStringArray()) as PackedStringArray)
		report["wrote"] = wrote
		if not bool(entry.get("ok", false)):
			report["ok"] = false
			report["failed"] = int(report["failed"]) + 1
	return report


## One chore. Always answers {id, ok, lines, wrote} - a chore that could not run says why in its
## lines and is not an error the caller has to catch.
static func run_one(id: String, options: Dictionary = {}) -> Dictionary:
	match id:
		CHORE_MANUAL:
			return _run_manual(options)
		CHORE_HARVEST:
			return _run_harvest(options)
		CHORE_DRAFTS:
			return _run_drafts(options)
		CHORE_CHECK:
			return _run_check(options)
		CHORE_SITE:
			return _run_site(options)
		CHORE_KEYS:
			return _run_keys(options)
	return {"id": id, "ok": false, "wrote": PackedStringArray(),
		"lines": PackedStringArray(["There is no chore by that name."])}


## The whole report as text - the terminal's output, the dialog's report panel and the CI log, from
## one place so they cannot word it differently.
static func report_text(report: Dictionary) -> String:
	return "\n".join(report.get("lines", PackedStringArray()) as PackedStringArray)


# ── Where things go ───────────────────────────────────────────────────────────────────────────


## The project's own docs folder - the same setting the Manual reads its "This project" pages from,
## so a page a chore writes is a page the reader can already open.
static func docs_dir() -> String:
	return EventSheetDocLibrary.user_docs_dir().trim_suffix("/")


static func manual_dir() -> String:
	return "%s/%s" % [docs_dir(), MANUAL_SUBDIR]


static func site_dir() -> String:
	return "%s/%s" % [docs_dir(), SITE_SUBDIR]


static func drafts_path() -> String:
	return "%s/%s" % [docs_dir(), DRAFTS_FILE]


## The file a sheet's own manual page is written to. One definition, so the chore that writes every
## page and the save that refreshes ONE cannot disagree about which file that sheet owns - and the
## stem itself comes from the manual, which the site exporter also asks, so all three agree.
static func manual_page_path(sheet_path: String) -> String:
	var name: String = EventSheetProjectManual.page_stem(sheet_path)
	if name.is_empty():
		return ""
	return "%s/%s.md" % [manual_dir(), name]


# ── The chores themselves ─────────────────────────────────────────────────────────────────────


## Writes a page per sheet and re-reads the Manual so the pages are searchable.
##
## THE SHEETS IT DOCUMENTS ARE THE ONES IT IS HANDED, plus every .tres sheet in the project. It does
## not hunt for GDScript-backed sheets: deciding whether a .gd is a sheet means lifting it, and a
## chore that lifted every script in a project to find out would cost minutes and still guess. A
## door hands over what it has open (`sheets`), which is exactly what a person doing this by hand
## would have in front of them.
static func _run_manual(options: Dictionary) -> Dictionary:
	var lines: PackedStringArray = PackedStringArray()
	var wrote: PackedStringArray = PackedStringArray()
	var sheets: Dictionary = collected_sheets(options)
	if sheets.is_empty():
		lines.append("No sheets to document.")
		return {"id": CHORE_MANUAL, "ok": true, "lines": lines, "wrote": wrote}
	DirAccess.make_dir_recursive_absolute(manual_dir())
	var pages: Dictionary = EventSheetProjectManual.pages_for(sheets)
	for key: Variant in pages:
		var path: String = manual_page_path(str(key))
		if path.is_empty():
			continue
		if _write_if_changed(path, str(pages[key])):
			wrote.append(path)
	EventSheetDocLibrary.reload()
	EventSheetDocSearch.reload()
	lines.append("%d page(s) for %d sheet(s), in %s." % [wrote.size(),
		pages.size(), manual_dir()])
	return {"id": CHORE_MANUAL, "ok": true, "lines": lines, "wrote": wrote}


## Asks the engine to write its own class reference, once per engine version. Nothing is downloaded
## and nothing is read from a network: this is `--doctool`, the engine documenting itself.
static func _run_harvest(_options: Dictionary) -> Dictionary:
	var lines: PackedStringArray = PackedStringArray()
	if EventSheetDocEngineReference.is_harvested():
		lines.append("Already harvested for this version of Godot - nothing to do.")
		return {"id": CHORE_HARVEST, "ok": true, "lines": lines, "wrote": PackedStringArray()}
	var classes: int = EventSheetDocEngineReference.harvest_now()
	if classes <= 0:
		lines.append("The harvest did not finish - the engine wrote nothing.")
		return {"id": CHORE_HARVEST, "ok": false, "lines": lines, "wrote": PackedStringArray()}
	lines.append("%d engine class(es) harvested." % classes)
	lines.append(EventSheetDocEngineReference.CREDIT_LINE)
	return {"id": CHORE_HARVEST, "ok": true, "lines": lines,
		"wrote": PackedStringArray([EventSheetDocEngineReference.cache_dir()])}


## Collects a draft description for everything in the project's sheets that has none, into one file.
## NOTHING IS APPLIED. The drafts are written where a person can read them beside each other, decide
## which are true, and paste the ones they keep - which is the whole difference between a tool that
## helps write documentation and a tool that writes documentation nobody wrote.
static func _run_drafts(options: Dictionary) -> Dictionary:
	var lines: PackedStringArray = PackedStringArray()
	var sheets: Dictionary = collected_sheets(options)
	var text: String = drafts_markdown(sheets)
	if text.is_empty():
		lines.append("Everything already has a description.")
		return {"id": CHORE_DRAFTS, "ok": true, "lines": lines, "wrote": PackedStringArray()}
	DirAccess.make_dir_recursive_absolute(docs_dir())
	var path: String = drafts_path()
	var wrote: PackedStringArray = PackedStringArray()
	if _write_if_changed(path, text):
		wrote.append(path)
	lines.append("Drafts written to %s. They stay drafts until you move them." % path)
	return {"id": CHORE_DRAFTS, "ok": true, "lines": lines, "wrote": wrote}


## The drafts file itself, as Markdown. Pure over the sheets it is given, so the suite pins the words
## against a fixture instead of against whatever project ran it.
static func drafts_markdown(sheets: Dictionary) -> String:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in sheets:
		keys.append(str(key))
	keys.sort()
	var sections: PackedStringArray = PackedStringArray()
	for key: String in keys:
		var sheet: EventSheetResource = sheets[key] as EventSheetResource
		if sheet == null:
			continue
		var rows: PackedStringArray = PackedStringArray()
		for entry: Dictionary in EventSheetDescriptions.catalog(sheet):
			if not str(entry.get("text", "")).strip_edges().is_empty():
				continue
			var draft: String = EventSheetDescriptionDrafts.for_entry(sheet, entry)
			if draft.strip_edges().is_empty():
				continue
			rows.append("- **%s** (%s): %s" % [str(entry.get("name", "")),
				str(entry.get("kind", "")), draft])
		if rows.is_empty():
			continue
		sections.append("## %s" % key.get_file())
		sections.append("")
		sections.append_array(rows)
		sections.append("")
	if sections.is_empty():
		return ""
	var lines: PackedStringArray = PackedStringArray(["# %s" % DRAFTS_TITLE, "",
		"These are suggestions, written from what the rows already do. Nothing here has been applied to a sheet. Keep the ones that are true, rewrite the ones that are not, and delete this file when it is empty.", ""])
	lines.append_array(sections)
	return "\n".join(lines).strip_edges() + "\n"


## Reads the guides and reports what they do not answer, then compares each shipped page with the
## source it was copied from. Both halves are read-only: this chore never edits a guide.
static func _run_check(options: Dictionary) -> Dictionary:
	var lines: PackedStringArray = PackedStringArray()
	var findings: Array[Dictionary] = EventSheetDocsDoctor.report(EventSheetDocsDoctor.guide_pages(),
		_changelog_text(), int(options.get("coverage_limit", COVERAGE_READ_LIMIT)))
	var problems: int = 0
	for finding: Dictionary in findings:
		var severity: String = str(finding.get("severity", "info"))
		if severity == "warning" or severity == "error":
			problems += 1
		lines.append(str(finding.get("message", "")))
	var drifted: PackedStringArray = bundle_drift()
	for id: String in drifted:
		lines.append("%s differs from the page it was copied from." % id)
	# WHAT FAILS AND WHAT ONLY REPORTS. Drift fails: a shipped copy that differs from the page it was
	# copied from is wrong by definition, and nobody has to judge it. Coverage only reports: "this
	# guide never mentions that verb" is a reading somebody may disagree with, and a gate that went
	# red on a judgement call would teach a team to ignore the gate. The count is printed either way.
	lines.append("%d thing(s) a guide does not answer, %d page(s) drifted." % [
		problems, drifted.size()])
	var ok: bool = drifted.is_empty()
	return {"id": CHORE_CHECK, "ok": ok, "lines": lines, "wrote": PackedStringArray()}


## Every shipped page whose bytes differ from the source it was copied from, sorted. Empty on an
## installed plugin, which has no sources to compare against - a reader who never had them is not
## drifting, they simply have the copy.
static func bundle_drift() -> PackedStringArray:
	var drifted: PackedStringArray = PackedStringArray()
	var ids: PackedStringArray = EventSheetDocLibrary.page_ids()
	ids.sort()
	for id: String in ids:
		var repo_path: String = EventSheetDocLibrary.repo_path_for_page(id)
		if repo_path.is_empty():
			continue
		var source_path: String = "res://%s" % repo_path
		if not FileAccess.file_exists(source_path):
			continue
		if _read(source_path) != EventSheetDocLibrary.page_source(id):
			drifted.append(id)
	return drifted


## Exports the whole Manual as a folder of HTML. The figures it can show are the ones already drawn
## and cached; the rest degrade to the code they are pictures of, and the report says how many, so
## somebody can run the drawing pass and export again.
static func _run_site(options: Dictionary) -> Dictionary:
	var lines: PackedStringArray = PackedStringArray()
	var out_dir: String = str(options.get("site_dir", site_dir()))
	var settings: Dictionary = {
		"locale": str(options.get("locale", EventSheetDocLocale.BASE_LOCALE)),
		"sheets": collected_sheets(options),
		# The engine's reference is thousands of pages and is off unless somebody asks for it: a
		# machine that happens to have harvested should not quietly export a site forty times the
		# size of the one the reader was expecting.
		"engine": bool(options.get("engine", false)),
	}
	if options.has("figures_dir"):
		settings["figures_dir"] = str(options["figures_dir"])
	var written: Dictionary = EventSheetDocSiteExport.export_site(out_dir, settings)
	if not str(written.get("error", "")).is_empty():
		lines.append(str(written["error"]))
		return {"id": CHORE_SITE, "ok": false, "lines": lines, "wrote": PackedStringArray()}
	lines.append("%d page(s) and %d figure(s) written to %s." % [
		int(written.get("pages", 0)), int(written.get("figures", 0)), out_dir])
	if int(written.get("undrawn", 0)) > 0:
		lines.append("%d figure(s) have no picture yet and are shown as their code." % int(written.get("undrawn", 0)))
	return {"id": CHORE_SITE, "ok": true, "lines": lines,
		"wrote": written.get("files", PackedStringArray()) as PackedStringArray}


## Writes the keys the game asks for that no catalog answers, as a translation CSV a translator can
## fill in a spreadsheet. The same file the Doctor's own one-click fix writes, from the same code.
static func _run_keys(_options: Dictionary) -> Dictionary:
	var result: Dictionary = export_missing_keys()
	return {"id": CHORE_KEYS, "ok": bool(result.get("ok", false)),
		"lines": PackedStringArray([str(result.get("message", ""))]),
		"wrote": result.get("wrote", PackedStringArray()) as PackedStringArray}


## The missing-keys export itself: {ok, message, wrote}. Lives here rather than beside the Doctor's
## quick fixes because three doors and a quick fix now ask for it, and a file this specific written
## two slightly different ways is how two reports start disagreeing.
static func export_missing_keys() -> Dictionary:
	var sources: Dictionary = EventSheetShipItDoctor.project_sources()
	var text: String = EventSheetShipItDoctor.missing_keys_csv(
		EventSheetShipItDoctor.used_translation_keys(sources), EventSheetShipItDoctor.catalog_keys())
	if text.is_empty():
		return {"ok": true, "wrote": PackedStringArray(),
			"message": "Every key the game asks for is answered by every catalog - nothing to write out."}
	var file: FileAccess = FileAccess.open(EventSheetQuickFixes.MISSING_KEYS_PATH, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "wrote": PackedStringArray(),
			"message": "Could not write %s." % EventSheetQuickFixes.MISSING_KEYS_PATH}
	file.store_string(text)
	file.close()
	return {"ok": true, "wrote": PackedStringArray([EventSheetQuickFixes.MISSING_KEYS_PATH]),
		"message": "Wrote the missing keys to %s - one row per key, one column per catalog." % EventSheetQuickFixes.MISSING_KEYS_PATH}


# ── What the chores are handed ────────────────────────────────────────────────────────────────


## The sheets a run documents: the ones the door handed over (`sheets`), plus every .tres sheet in
## the project unless the caller said not to look (`scan_project`). Keyed by path and sorted by the
## manual itself, so the same project always produces the same pages in the same order.
static func collected_sheets(options: Dictionary) -> Dictionary:
	var sheets: Dictionary = {}
	for key: Variant in (options.get("sheets", {}) as Dictionary):
		var handed: Variant = (options["sheets"] as Dictionary)[key]
		if handed is EventSheetResource:
			sheets[str(key)] = handed
	if not bool(options.get("scan_project", true)):
		return sheets
	for path: String in EventSheetProjectFind.list_project_sheets():
		if sheets.has(path):
			continue
		var resource: Resource = load(path)
		if resource is EventSheetResource:
			sheets[path] = resource
	return sheets


# ── The smallest automation: one sheet, on save ───────────────────────────────────────────────


## What a saved sheet costs its own documentation: its manual page, and its entry in the search.
## JUST THAT SHEET. A project walk on every save would make saving slower the bigger the project
## got, which is exactly backwards, and there is nothing a walk would find that the save did not
## already know.
##
## It refreshes a page that ALREADY EXISTS and creates nothing: a project that never asked for a
## manual does not silently acquire one because somebody pressed Ctrl+S. Answers whether anything
## was rewritten, so a caller can say so in the status line.
static func refresh_after_save(sheet_path: String, sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	var path: String = manual_page_path(sheet_path)
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var page: String = EventSheetProjectManual.page_for(sheet)
	if not _write_if_changed(path, page):
		return false
	EventSheetDocSearch.refresh_page(EventSheetDocLibrary.id_for_page_path(path),
		_first_heading(page), page)
	return true


# ── Plumbing ──────────────────────────────────────────────────────────────────────────────────


## Writes only when the bytes would change, and answers whether they did. A chore that rewrote every
## file every run would turn "what changed in the docs" into "everything, again" in version control.
static func _write_if_changed(path: String, text: String) -> bool:
	if FileAccess.file_exists(path) and _read(path) == text:
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return true


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


static func _first_heading(source: String) -> String:
	for line: String in source.replace("\r\n", "\n").split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("# "):
			return stripped.substr(2).strip_edges().replace("`", "")
	return ""


## The project's ledger. Asked for by the same name the Doctor and the bundle build ask for it by -
## the three exist so that one question gets one answer, and a literal here would be a second place
## to change if a project ever kept its ledger anywhere else.
static func _changelog_text() -> String:
	return _read(EventSheetDocWhatsNew.SOURCE_PATH)
