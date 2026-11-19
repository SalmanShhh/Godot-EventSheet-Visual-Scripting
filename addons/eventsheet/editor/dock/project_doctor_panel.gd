@tool
class_name EventSheetProjectDoctorPanel
extends RefCounted

## The last Doctor run of this session, exactly as the run reported it. Empty when nobody has run
## one; nothing here ever runs the Doctor to fill it.
static var _doctor_findings: Array = []


## Records a Doctor run's findings. Called by whoever ran it.
static func set_doctor_findings(findings: Array) -> void:
	_doctor_findings = findings.duplicate()


static func doctor_findings() -> Array:
	return _doctor_findings


static func clear_doctor_findings() -> void:
	_doctor_findings = []

# The Project Doctor window (Tools ▸ Project Doctor) - the triage inbox for everything the audit
# found.
#
# The actual checks live in the global EventSheetProjectDoctor so the headless CLI and CI run the
# exact same audit; this class is only the editor window shell. What it renders is the FRONT PAGE:
# every finding from every section in one tree, worst first, with the ones that appeared since the
# reader last looked marked - because the audit grew sections faster than it grew a way to read them,
# and sixty findings in the order the checks happened to run is a junk drawer.
#
# The page itself is decided by EventSheetDoctorInbox, which is pure and headless, so the ordering
# and the new-since-last-look mark are pinned by tests rather than by looking at the window. This
# class only draws it: a finding is one sentence, a double-click opens the sheet
# it is about, and the selected finding's fixes open as rows under it - the only door a fix has.
#
# The dock keeps a thin _open_project_doctor() delegate for the Tools menu; this class parents its
# window on the dock and writes the audit summary to the dock status bar.

var _dock: Control = null
var _doctor_window: Window = null
var _doctor_tree: Tree = null
var _summary_label: Label = null
var _open_button: Button = null
## One sentence under the inbox saying where the selected finding is and how to open it.
var _this_finding: EventSheetPopupUI.StateNote = null
## The finding whose fixes are listed under it right now, so choosing another one takes them away.
var _fixed_item: TreeItem = null
## The page currently drawn - what "mark as read" writes down.
var _page: Array[Dictionary] = []
## True from a fix being applied until the re-run redraws the page, so the second click of a
## double-click (which Godot also reports as an activation) does not apply the same fix again.
var _fix_pending: bool = false
## The door every row finding has: its sheet opened on that row.
const SHOW_ROW := "show_row"
## The door the coverage note has: read every script as a sheet too, in slices, with progress and Cancel.
const CHECK_EVERY_SCRIPT := "check_every_script"
## The window opens wide enough to read a real finding, never under its least, and keeps the size the
## reader leaves it at.
const DEFAULT_WIDTH: int = 1120
const DEFAULT_HEIGHT: int = 720
const MIN_WIDTH: int = 720
const MIN_HEIGHT: int = 440
const SIZE_SECTION: String = "eventsheets"
const SIZE_KEY: String = "doctor_window_size"
## Headless twin of the editor's metadata store, so the remembered size is testable without an editor.
static var _size_memory: Array = []
## While an audit is running: the line saying how far it is, the button that stops it, and the flag it reads.
var _progress_label: Label = null
var _cancel_button: Button = null
var _rerun_button: Button = null
var _running: bool = false
## True once the reader took the coverage note's door: this window's runs read every script as a sheet.
var _every_script: bool = false
var _cancel_requested: bool = false
## The page being laid into the tree a few milliseconds a frame, so a long page never holds one frame; a
## newer page (or a closed window) makes the older fill stop where it is.
var _fill_generation: int = 0
## When the page last began to be drawn during an audit, so findings arriving are drawn a few times a second
## and not once per step.
var _last_partial_draw_msec: int = 0
## What one frame may spend laying rows into the tree.
const FILL_BUDGET_USEC: int = 5000
## The selected finding's whole sentence, wrapped, under the list: a cell cuts a long one.
var _whole_finding: PanelContainer = null
var _whole_finding_text: Label = null
## Where each check's Learn more goes, found once a session: reading the whole Manual is not free.
static var _learn_more_cache: Dictionary = {}
## The Manual's pages as read for the lookups above, {page id: Markdown}, kept for the session once read.
static var _learn_corpus: Dictionary = {}
## True while a Learn more lookup runs on its thread: one at a time, as the Manual's lazy caches are built on it.
static var _learn_busy: bool = false


func init(dock: Control) -> void:
	_dock = dock


## Every door a finding has, as {id, label}: the built-in fixes first, then the check's own "fix"
## Callable when an extension attached one (its id is ""). The rows these become under the selected
## finding are the only way a fix is applied - no second button below the list does the same job.
static func offers_for(finding: Dictionary) -> Array[Dictionary]:
	var offers: Array[Dictionary] = EventSheetQuickFixes.fixes_for(finding)
	if finding.get("fix") is Callable:
		offers.append({"id": "", "label": str(finding.get("fix_label", EventSheetL10n.translate("Apply its fix")))})
	# A row finding's address is a door too: the sheet opened with that row selected.
	if finding.has("doors") and int(finding.get("event", 0)) > 0:
		offers.append({"id": SHOW_ROW, "label": EventSheetL10n.translate("Show row")})
	if str(finding.get("check", "")) == "sheet-coverage" and int(finding.get("plain_count", 0)) > 0:
		offers.append({"id": CHECK_EVERY_SCRIPT, "label": load("res://addons/eventforge/known_sheets.gd").door_text(int(finding["plain_count"]))})
	return offers


func open() -> void:
	if _doctor_window == null:
		_build()
	_every_script = false
	_doctor_window.size = _wanted_size()
	EventSheetWindowPlacement.popup_centered(_doctor_window)
	_run_project_doctor()


## The size the window opens at: what the reader last left it at, else the default, never under the least.
func _wanted_size() -> Vector2i:
	var stored: Variant = _size_memory
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		stored = EditorInterface.get_editor_settings().get_project_metadata(SIZE_SECTION, SIZE_KEY, [])
	var wanted: Vector2i = Vector2i(EventSheetPalette.scaled(DEFAULT_WIDTH), EventSheetPalette.scaled(DEFAULT_HEIGHT))
	if stored is Array and (stored as Array).size() == 2:
		wanted = Vector2i(int((stored as Array)[0]), int((stored as Array)[1]))
	return wanted.max(Vector2i(EventSheetPalette.scaled(MIN_WIDTH), EventSheetPalette.scaled(MIN_HEIGHT)))


## Keeps the size the reader left the window at, for the next time it opens.
func _remember_size() -> void:
	if _doctor_window == null or _doctor_window.visible:
		return
	var kept: Array = [_doctor_window.size.x, _doctor_window.size.y]
	_size_memory = kept
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata(SIZE_SECTION, SIZE_KEY, kept)


## The window: the summary, the inbox, what a finding and a fix do, and the ways out.
func _build() -> void:
	_doctor_window = Window.new()
	_doctor_window.title = EventSheetL10n.translate("Check the project")
	_doctor_window.size = Vector2i(EventSheetPalette.scaled(DEFAULT_WIDTH), EventSheetPalette.scaled(DEFAULT_HEIGHT))
	_doctor_window.min_size = Vector2i(EventSheetPalette.scaled(MIN_WIDTH), EventSheetPalette.scaled(MIN_HEIGHT))
	_doctor_window.visibility_changed.connect(_remember_size)
	# Closing the window is what "I have looked at this" means: the identities on the page are written
	# down then, so the next open marks what appeared in between and nothing else. Doing it on OPEN
	# instead would erase the marks the reader came to read.
	_doctor_window.close_requested.connect(_close)
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	_summary_label = Label.new()
	box.add_child(_summary_label)
	# How far an audit has got, and the way to stop it; hidden while none is running.
	var progress_row: HBoxContainer = HBoxContainer.new()
	progress_row.visible = false
	_progress_label = Label.new()
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	progress_row.add_child(_progress_label)
	_cancel_button = _button(EventSheetL10n.translate("Cancel"), func() -> void: _cancel_requested = true)
	progress_row.add_child(_cancel_button)
	box.add_child(progress_row)
	_progress_label.set_meta("row", progress_row)
	_doctor_tree = inbox_tree()
	# Deferred: a Tree refuses to create items while it is handling the click that selected one, so
	# the fix and Learn more rows under a finding are built once that click is over.
	_doctor_tree.item_selected.connect(_on_finding_selected, CONNECT_DEFERRED)
	_doctor_tree.item_mouse_selected.connect(func(_at: Vector2, _button: int) -> void:
		_apply_fix_row(_doctor_tree.get_selected()))
	# A finding is a destination, not just a report line: double-click (or Enter) opens the sheet.
	_doctor_tree.item_activated.connect(func() -> void:
		if not _apply_fix_row(_doctor_tree.get_selected()):
			_open_activated_finding())
	var findings_card: PanelContainer = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Inbox"), _doctor_tree)
	findings_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(findings_card)
	_whole_finding_text = EventSheetPopupUI.hint_label("", 0.0)
	_whole_finding_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_whole_finding = EventSheetPopupUI.panel_section(_whole_finding_text)
	_whole_finding.visible = false
	box.add_child(_whole_finding)
	_this_finding = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(600.0))
	box.add_child(_this_finding)
	var buttons: HBoxContainer = HBoxContainer.new()
	_rerun_button = _button(EventSheetL10n.translate("Re-run Checks"), _run_project_doctor)
	buttons.add_child(_rerun_button)
	# The reader's own "I have dealt with this page" - the same thing closing the window does, for a
	# reader who wants to keep it open and start again from a clean page.
	var read_button: Button = _button(EventSheetL10n.translate("Mark All as Read"), func() -> void:
		_mark_page_as_read()
		_run_project_doctor())
	read_button.tooltip_text = EventSheetL10n.translate("Writes down what is on this page, so the next audit marks only what appeared after it.")
	buttons.add_child(read_button)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(gap)
	buttons.add_child(_button(EventSheetL10n.translate("Close"), _close))
	_open_button = _button(EventSheetL10n.translate("Open"), _open_activated_finding)
	_open_button.disabled = true
	_open_button.add_theme_color_override("font_color", EventSheetPopupUI.accent_color())
	buttons.add_child(_open_button)
	box.add_child(buttons)
	_doctor_window.add_child(EventSheetPopupUI.window_body(box))
	_dock.add_child(_doctor_window)


## The inbox's four columns: the mark (a dot on a line that is new, read before a word is), the
## section, where, and the finding. Static so a preview draws the same tree the window does.
static func inbox_tree() -> Tree:
	return EventSheetPopupUI.table(PackedStringArray(["", EventSheetL10n.translate("Section"),
		EventSheetL10n.translate("Where"), EventSheetL10n.translate("Finding")]), 0.0, {0: 42.0, 1: 190.0, 2: 170.0})


static func _button(text: String, pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(pressed)
	return button


func _close() -> void:
	# Closing the window stops an audit still running behind it.
	_cancel_requested = true
	_fill_generation += 1
	_mark_page_as_read()
	_doctor_window.hide()


func _run_project_doctor() -> void:
	if _running:
		# An audit being stopped (the window was closed) finishes its step first; a new one waits for that rather
		# than being dropped, so closing and opening the window at once still checks the project.
		if not _cancel_requested or _dock == null or not _dock.is_inside_tree():
			return
		while _running:
			await _dock.get_tree().process_frame
		if _running or _doctor_window == null:
			return
	_running = true
	_cancel_requested = false
	_fix_pending = false
	_set_running(true)
	_fill_generation += 1
	_last_partial_draw_msec = 0
	_fixed_item = null
	await _clear_in_turns(_dock.get_tree(), _fill_generation)
	if _doctor_tree.get_root() == null:
		_doctor_tree.create_item()
	# The audit is taken in slices of a few milliseconds with a frame between them, so the editor keeps
	# drawing and the Cancel button works; the page is drawn again as findings come in. Extension-registered
	# checks (EventSheets.register_doctor_check) report here exactly like built-ins, because the same
	# steps run.
	# Two frames first, so the window is drawn saying it is checking before the audit's code is loaded
	# for the first time in this session (which takes a moment the window should not hide behind).
	await _dock.get_tree().process_frame
	await _dock.get_tree().process_frame
	# The project is listed on a worker while the window says it is checking; begin() then finds the listing waiting.
	await EventSheetProjectDoctor.prime_listing(_dock.get_tree(),
		func() -> bool: return _cancel_requested or _doctor_window == null)
	if _cancel_requested:
		EventSheetProjectDoctor.drop_primed_listing()
		_running = false
		_set_running(false)
		return
	var session: Dictionary = EventSheetProjectDoctor.begin(_audit_options())
	var report: Dictionary = await EventSheetProjectDoctor.run_sliced(session, _dock.get_tree(),
		func() -> bool: return _cancel_requested or _doctor_window == null,
		func(partial: Dictionary) -> void: _show_progress(partial))
	_running = false
	_set_running(false)
	if bool(report.get("interrupted", false)):
		# A whole audit was asked for from outside while this one was under way (the MCP tool, a test): it took the
		# shared state over and this one was abandoned, so the window asks again rather than show half a page.
		if not _cancel_requested and _doctor_window != null and _doctor_window.visible:
			_run_project_doctor()
		return
	if report.is_empty():
		# Stopped: what had come in stays on the page, and the summary says it is not the whole.
		_summary_label.text = EventSheetL10n.translate("Stopped - %d finding(s) so far; run it again for the whole project.") % (session["findings"] as Array).size()
		_dock._set_status(_summary_label.text)
		return
	# One store, so every page that wants to say what the Doctor found reads this run rather than
	# starting one of its own.
	set_doctor_findings(report.get("findings", []))
	await _draw_page(report.get("findings", []) as Array)
	_dock._set_status(_summary_label.text, int(report.get("errors", 0)) > 0)


## What the audit is told about the project: only the known sheets are read row by row, unless the reader
## took the door that reads every script.
func _audit_options() -> Dictionary:
	var state: Dictionary = _dock.get_open_sheets_state()
	var open_paths: PackedStringArray = PackedStringArray()
	for tab: Variant in (state.get("open", []) as Array):
		var tab_path: String = str((tab as Dictionary).get("path", ""))
		if not tab_path.is_empty():
			open_paths.append(tab_path)
	return {"known_only": true, "every_script": _every_script, "open_paths": open_paths,
		"recent_paths": PackedStringArray(state.get("recent", []))}


## Draws the page for the findings so far: worst first, and what is new against the last read. The rows go
## into the tree a few milliseconds a frame (see `FILL_BUDGET_USEC`), so a page of thousands of findings
## never holds a frame; the summary line is ready at once.
func _draw_page(findings: Array) -> void:
	_fill_generation += 1
	var mine: int = _fill_generation
	var tree: SceneTree = _dock.get_tree() if _dock != null and _dock.is_inside_tree() else null
	# Putting the findings in order is plain data work, so a long page is ordered on a worker thread.
	var triaged: Array = []
	if tree != null and findings.size() > 200:
		triaged = await load("res://addons/eventforge/doctor_background.gd").run_work(
			func() -> Array: return EventSheetDoctorInbox.triage(findings, EventSheetDoctorInbox.load_seen()), tree)
		if mine != _fill_generation or _doctor_window == null or _doctor_tree == null:
			return
	else:
		triaged = EventSheetDoctorInbox.triage(findings, EventSheetDoctorInbox.load_seen())
	_page.assign(triaged)
	_summary_label.text = EventSheetDoctorInbox.summary_line(_page)
	await _clear_in_turns(tree, mine)
	if mine != _fill_generation or _doctor_window == null or _doctor_tree == null:
		return
	_fixed_item = null
	var root_item: TreeItem = _doctor_tree.get_root() if _doctor_tree.get_root() != null else _doctor_tree.create_item()
	_fill_page(InboxFill.new(_doctor_tree, root_item, _page), mine, tree)


## Lays a page's rows into the tree a few milliseconds a frame, until it is done or a newer page replaces it.
func _fill_page(filler: InboxFill, mine: int, tree: SceneTree) -> void:
	while not filler.step(FILL_BUDGET_USEC if tree != null else 0):
		await tree.process_frame
		if mine != _fill_generation or _doctor_window == null or _doctor_tree == null:
			return
	_on_finding_selected()


## Empties the tree, a few milliseconds of rows a frame when it holds a long page: letting go of thousands of rows at
## once is a frame of its own.
func _clear_in_turns(tree: SceneTree, mine: int) -> void:
	var root_item: TreeItem = _doctor_tree.get_root()
	if root_item == null or tree == null:
		_doctor_tree.clear()
		return
	var branch: TreeItem = root_item.get_first_child()
	while branch != null:
		var started: int = Time.get_ticks_usec()
		var freed: int = 0
		while branch.get_child_count() > 0:
			branch.get_first_child().free()
			freed += 1
			if (freed & 15) == 0 and Time.get_ticks_usec() - started > FILL_BUDGET_USEC:
				await tree.process_frame
				if mine != _fill_generation or _doctor_window == null or _doctor_tree == null:
					return
				started = Time.get_ticks_usec()
		branch = branch.get_next()
	_doctor_tree.clear()


## The progress line after each step, and the page again when something new has come in - a few times a
## second at most, because every redraw lays the whole page out again.
func _show_progress(session: Dictionary) -> void:
	var progress: Vector2i = EventSheetProjectDoctor.progress_of(session)
	var found: int = (session["findings"] as Array).size()
	_progress_label.text = "%s - %s - %s" % [
		EventSheetL10n.translate("Checking the project - step %d of %d") % [progress.x, progress.y],
		_step_words(session), EventSheetL10n.translate("%d found so far") % found]
	var now: int = Time.get_ticks_msec()
	# A page of hundreds is drawn once, when the audit is done: laying it out again and again is the audit's own cost.
	if found != int(_progress_label.get_meta("drawn", -1)) and found <= 300 and _doctor_tree.get_selected() == null 			and now - _last_partial_draw_msec >= 300 + found / 2:
		_progress_label.set_meta("drawn", found)
		_last_partial_draw_msec = now
		_draw_page((session["findings"] as Array).duplicate())


## What the audit is reading next, in words: the next step's name, which is a check's own id for most of them.
## A step that only registers a section by its class name says nothing a reader could use, so it is skipped.
func _step_words(session: Dictionary) -> String:
	var steps: Array = session["steps"]
	var next: int = mini(int(session["index"]), steps.size() - 1)
	while next < steps.size():
		var step_name: String = str((steps[next] as Array)[0])
		if not step_name.begins_with("EventSheet") and step_name != "extension_checks":
			return EventSheetDoctorInbox.label_for(step_name.replace("_", "-"))
		next += 1
	return EventSheetL10n.translate("the last checks")


func _set_running(running: bool) -> void:
	(_progress_label.get_meta("row") as Control).visible = running
	_rerun_button.disabled = running
	if running:
		_progress_label.text = EventSheetL10n.translate("Getting ready...")
		_progress_label.set_meta("drawn", -1)
		_summary_label.text = ""


## Writes down every identity on the page, so the next audit marks only what appeared after it.
func _mark_page_as_read() -> void:
	EventSheetDoctorInbox.save_seen(EventSheetDoctorInbox.identities_of(_page))


## Lists the selected finding's fixes as rows under it, takes the last finding's away, and names the
## selected finding's file on the Open button. Selecting one of those fix rows changes nothing here:
## a click on it, or Enter, is what applies it.
func _on_finding_selected() -> void:
	var item: TreeItem = _doctor_tree.get_selected()
	if item != null and item.get_metadata(2) is Dictionary:
		return
	if _fixed_item != null and _fixed_item != item:
		for old: TreeItem in _fixed_item.get_children():
			old.free()
	_fixed_item = item
	var finding: Variant = item.get_metadata(1) if item != null else null
	var is_finding: bool = finding is Dictionary
	_whole_finding.visible = is_finding
	if is_finding:
		_whole_finding_text.text = str((finding as Dictionary).get("message", ""))
	_open_button.disabled = not is_finding
	_open_button.text = EventSheetL10n.translate("Open %s") % item.get_tooltip_text(2).get_file() \
		if is_finding else EventSheetL10n.translate("Open")
	_this_finding.say(EventSheetL10n.translate("Double-click it, or press Open, to open %s.") % item.get_text(2)
		if is_finding else EventSheetL10n.translate("Select a finding to see where it is and what fixes it."), "")
	if not is_finding or item.get_child_count() > 0:
		return
	for offer: Dictionary in offers_for(finding as Dictionary):
		var row: TreeItem = _doctor_tree.create_item(item)
		row.set_text(3, "%s %s" % [EventSheetL10n.translate("Fix:"), str(offer.get("label", ""))])
		row.set_custom_color(3, EventSheetPopupUI.accent_color())
		row.set_tooltip_text(3, EventSheetL10n.translate("Applies this fix through undo, then re-runs the check."))
		row.set_metadata(2, offer)
	_add_learn_row(item, finding as Dictionary)


## The row under a finding that opens the page explaining it - the Manual's own search asked with the finding's
## words, so a check needs no entry anywhere to have one. The first time a check is asked about, the Manual's
## pages are read on a worker thread and the row appears a moment after the selection, so choosing a finding
## never waits on the disk; once it is known the row is made at once.
func _add_learn_row(item: TreeItem, finding: Dictionary) -> void:
	var check: String = str(finding.get("check", "")).strip_edges()
	if check.is_empty():
		return
	if not _learn_more_cache.has(check):
		var tree: SceneTree = _dock.get_tree() if _dock != null and _dock.is_inside_tree() else null
		if tree == null:
			learn_more_for(finding)
		else:
			var job: LearnJob = LearnJob.new(finding)
			if _learn_busy:
				return
			if not job.start():
				learn_more_for(finding)
			else:
				_learn_busy = true
				while job.is_running():
					await tree.process_frame
				var found: Dictionary = job.finish()
				_learn_busy = false
				_learn_more_cache[check] = found
				if not (found.get("corpus_read", {}) as Dictionary).is_empty() and _learn_corpus.is_empty():
					_learn_corpus = found["corpus_read"]
				found.erase("corpus_read")
		if not is_instance_valid(item) or item != _fixed_item or _doctor_window == null:
			return
	var learn: Dictionary = _learn_more_cache.get(check, {}) as Dictionary
	if learn.is_empty():
		return
	var learn_row: TreeItem = _doctor_tree.create_item(item)
	learn_row.set_text(3, "%s · %s" % [EventSheetL10n.translate("Learn more"), str(learn.get("title", ""))])
	learn_row.set_custom_color(3, EventSheetPopupUI.accent_color())
	learn_row.set_tooltip_text(3, EventSheetL10n.translate("Opens the Manual on the page that explains this finding and its fix."))
	learn_row.set_metadata(2, learn)
	item.collapsed = false


## One Learn more lookup on a thread of its own: reads the Manual's pages and finds the page for one finding's
## check. Only plain strings cross back; the cache is filled by whoever joins it.
class LearnJob extends RefCounted:
	var _thread: Thread = null
	var _finding: Dictionary = {}
	var _answer: Dictionary = {}


	func _init(finding: Dictionary) -> void:
		_finding = finding


	func start() -> bool:
		_thread = Thread.new()
		if _thread.start(_run, Thread.PRIORITY_LOW) != OK:
			_thread = null
			return false
		return true


	func is_running() -> bool:
		return _thread != null and _thread.is_alive()


	func finish() -> Dictionary:
		if _thread != null:
			_thread.wait_to_finish()
			_thread = null
		return _answer


	func _run() -> void:
		var corpus: Dictionary = EventSheetProjectDoctorPanel._learn_corpus
		if corpus.is_empty():
			corpus = EventSheetProjectDoctorPanel.read_manual_pages()
		var found: Dictionary = EventSheetProjectDoctorPanel.find_learn_more(_finding, corpus)
		found["corpus_read"] = corpus
		_answer = found


## Where a finding's Learn more goes: {doc_id, anchor, title}, or {} when the Manual has nothing
## about it. The page that names the check is the page that explains it, so the first guide whose
## text carries the check's id lands the reader on the heading over that mention; without one, the
## Manual's search is asked for a HEADING in the check's own words. A page with only a passing
## mention of the words would be a guess, and a Learn more that lands on the wrong page is worse
## than none. `pages` ({page id: Markdown}) stands in for the shipped Manual in a test.
static func learn_more_for(finding: Dictionary, pages: Dictionary = {}) -> Dictionary:
	var check: String = str(finding.get("check", "")).strip_edges()
	if check.is_empty():
		return {}
	var corpus: Dictionary = pages
	if corpus.is_empty():
		if _learn_more_cache.has(check):
			return _learn_more_cache[check]
		corpus = _learn_corpus
		if corpus.is_empty():
			corpus = read_manual_pages()
			_learn_corpus = corpus
	var found: Dictionary = find_learn_more(finding, corpus, pages.is_empty())
	if pages.is_empty():
		_learn_more_cache[check] = found
	return found


## Every page of the Manual as {page id: Markdown}. Plain file reads, so a worker thread may run it.
static func read_manual_pages() -> Dictionary:
	var corpus: Dictionary = {}
	for page_id: String in EventSheetDocLibrary.page_ids():
		corpus[page_id] = EventSheetDocLibrary.page_source(page_id)
	return corpus


## The page for a finding's check among `corpus`, uncached: the page that names the check, else the guide's
## own Doctor heading, else (for the shipped Manual only) a search of it. Touches no shared state, so a worker
## thread may run it.
static func find_learn_more(finding: Dictionary, corpus: Dictionary, ask_search: bool = true) -> Dictionary:
	var check: String = str(finding.get("check", "")).strip_edges()
	if check.is_empty():
		return {}
	var found: Dictionary = mention_in(corpus, check)
	if found.is_empty():
		found = doctor_heading_in(corpus, check)
	if found.is_empty() and ask_search:
		for result: Dictionary in EventSheetDocSearch.search(check.replace("-", " "), 5):
			if not str(result.get("anchor", "")).is_empty():
				found = {"doc_id": str(result.get("doc_id", "")), "anchor": str(result.get("anchor", "")),
					"title": "%s · %s" % [str(result.get("title", "")), str(result.get("heading", ""))]}
				break
	return found


## The guides keep a "What the Doctor says" section about their own subject. The first heading that
## names the Doctor, on a page whose title or that heading carries the check's first word ("Collisions"
## for collisions, "Interop" for interop-script), as {doc_id, anchor, title}, or {}.
static func doctor_heading_in(pages: Dictionary, check: String) -> Dictionary:
	var subject: String = check.get_slice("-", 0).to_lower()
	if subject.length() < 4:
		return {}
	var word: RegEx = RegEx.create_from_string("\\b%s\\b" % subject)
	var ids: Array = pages.keys()
	ids.sort()
	for page_id: Variant in ids:
		var title: String = ""
		var in_fence: bool = false
		for line: String in str(pages[page_id]).split("\n"):
			var stripped: String = line.strip_edges()
			if stripped.begins_with("```"):
				in_fence = not in_fence
				continue
			if in_fence or not stripped.begins_with("#"):
				continue
			var text: String = stripped.lstrip("#").strip_edges()
			if stripped.begins_with("# ") and title.is_empty():
				title = text
				continue
			if not text.to_lower().contains("doctor"):
				continue
			if word.search(text.to_lower()) != null or word.search(title.to_lower()) != null:
				return {"doc_id": "guide:%s" % str(page_id), "anchor": EventSheetDocMarkdown.slug(text),
					"title": "%s · %s" % [title, text]}
	return {}


## The first page whose text names `check` as a whole word, as {doc_id, anchor, title} at the
## heading over the mention, or {}. Pure over the pages it is handed; pages are read in id order.
static func mention_in(pages: Dictionary, check: String) -> Dictionary:
	# A one-word check ("collisions", "compile") is an ordinary word in prose, so only its spelling as
	# code (`collisions`) names it; a hyphenated id is distinctive wherever it appears.
	if not check.contains("-"):
		check = "`%s`" % check
	var matcher: RegEx = RegEx.create_from_string("(^|[^a-z0-9-])%s([^a-z0-9-]|$)" % check.replace("-", "\\-"))
	var ids: Array = pages.keys()
	ids.sort()
	for page_id: Variant in ids:
		var title: String = ""
		var heading: String = ""
		var in_fence: bool = false
		for line: String in str(pages[page_id]).split("\n"):
			var stripped: String = line.strip_edges()
			if stripped.begins_with("```"):
				in_fence = not in_fence
				continue
			if in_fence:
				continue
			if stripped.begins_with("#"):
				var text: String = stripped.lstrip("#").strip_edges()
				if stripped.begins_with("# ") and title.is_empty():
					title = text
				else:
					heading = text
			if matcher.search(line) == null:
				continue
			if heading.is_empty():
				break
			return {"doc_id": "guide:%s" % str(page_id), "anchor": EventSheetDocMarkdown.slug(heading),
				"title": "%s · %s" % [title, heading]}
	return {}


## A click (or Enter) on a fix row applies it, then re-runs the audit so the finding's going away is
## proven rather than assumed. False when the row is not a fix row; a fix row clicked again before
## the re-run has redrawn the page is answered as handled, so one gesture is one undo step.
func _apply_fix_row(item: TreeItem) -> bool:
	if item == null or not (item.get_metadata(2) is Dictionary):
		return false
	var learn: Dictionary = item.get_metadata(2) as Dictionary
	if learn.has("doc_id"):
		_dock.open_documentation(str(learn["doc_id"]), str(learn.get("anchor", "")))
		return true
	if _fix_pending:
		return true
	_fix_pending = true
	var finding: Dictionary = item.get_parent().get_metadata(1) as Dictionary
	var fix_id: String = str((item.get_metadata(2) as Dictionary).get("id", ""))
	if fix_id == CHECK_EVERY_SCRIPT:
		_every_script = true
		_fix_pending = false
		_run_project_doctor.call_deferred()
		return true
	if fix_id == SHOW_ROW:
		_fix_pending = false
		_show_finding_row(finding)
		return true
	if fix_id.is_empty():
		(finding["fix"] as Callable).call(finding)
	else:
		var result: Dictionary = EventSheetQuickFixes.apply(fix_id, finding, {"dock": _dock})
		_dock._set_status(str(result.get("message", "")), not bool(result.get("ok", false)))
	# Deferred: the click that got here is still being handled by the tree this clears.
	_run_project_doctor.call_deferred()
	return true


## Opens a finding's sheet and selects the row it is about, found by the number the margin draws.
func _show_finding_row(finding: Dictionary) -> void:
	var path: String = str(finding.get("path", ""))
	if path.is_empty():
		return
	# An open tab comes forward; a closed file opens on a worker, and the row exists when that has landed.
	_dock.open_or_focus_sheet(path)
	_doctor_window.hide()
	while _dock._sheet_io.get("_open_job") != null:
		await _dock.get_tree().process_frame
	var sheet: EventSheetResource = _dock._current_sheet
	var number: int = int(finding.get("event", 0))
	if sheet == null or number <= 0:
		return
	var numbers: Dictionary = EventSheetResource.margin_numbers(sheet)
	var wanted: int = numbers.find_key(number) if numbers.find_key(number) != null else 0
	var row: Object = instance_from_id(wanted) if wanted != 0 else null
	var view: EventSheetViewport = _dock._active_view()
	if view != null and row is EventRow:
		load("res://addons/eventsheet/editor/dock/mistake_fixes.gd").reveal_event(view, row as EventRow, sheet)
	elif view != null and row is Resource:
		view.reveal_resource(row as Resource)
	_dock._set_status(EventSheetL10n.translate("Row %d of %s.") % [number, path.get_file()])


## The front page as rows of a Tree: one branch per severity, worst first, each finding under it with
## its section, its file and its words. A line that was not here last time leads with a dot.
##
## Static and given its tree for the same reason `fill` is: the window is not the only thing that can
## draw a page, and there is exactly one place that decides what a line looks like.
static func fill_inbox(tree: Tree, root_item: TreeItem, page: Array[Dictionary]) -> void:
	var filler: InboxFill = InboxFill.new(tree, root_item, page)
	filler.step(0)


## One inbox page laid into a tree in turns: `step(budget_usec)` makes rows until the budget is spent and
## answers whether the page is finished (a budget of 0 runs to the end). The rows are exactly those
## `fill_inbox` has always made, so a page filled in many frames and one filled at once are the same page.
class InboxFill extends RefCounted:
	var _tree: Tree = null
	var _page: Array[Dictionary] = []
	var _branches: Dictionary = {}
	var _cursor: int = 0
	var _prepared: bool = false
	var _root: TreeItem = null


	func _init(tree: Tree, root_item: TreeItem, page: Array[Dictionary]) -> void:
		_tree = tree
		_root = root_item
		_page = page


	func step(budget_usec: int) -> bool:
		var started: int = Time.get_ticks_usec()
		if not _prepared:
			_prepared = true
			_make_branches()
		while _cursor < _page.size():
			_add_finding(_page[_cursor])
			_cursor += 1
			if budget_usec > 0 and (_cursor & 7) == 0 and Time.get_ticks_usec() - started >= budget_usec:
				return _cursor >= _page.size()
		return true


	func _make_branches() -> void:
		var held_by: Dictionary = {}
		var new_by: Dictionary = {}
		for finding: Dictionary in _page:
			var severity: String = str(finding.get("severity", ""))
			held_by[severity] = int(held_by.get(severity, 0)) + 1
			if bool(finding.get("is_new", false)):
				new_by[severity] = int(new_by.get(severity, 0)) + 1
		for severity: String in EventSheetDoctorInbox.SEVERITY_ORDER:
			var held: int = int(held_by.get(severity, 0))
			var new_here: int = int(new_by.get(severity, 0))
			if held == 0:
				continue
			var branch: TreeItem = _tree.create_item(_root)
			EventSheetProjectDoctorPanel._mark(_tree, branch, severity, new_here > 0)
			branch.set_text(1, "%s (%d)" % [EventSheetDoctorInbox.severity_label(severity), held])
			branch.set_custom_color(1, EventSheetPopupUI.tone_color(severity))
			branch.set_text(3, EventSheetL10n.translate("%d new since you last looked.") % new_here
				if new_here > 0 else "")
			branch.set_selectable(0, false)
			branch.set_selectable(1, false)
			_branches[severity] = branch


	func _add_finding(finding: Dictionary) -> void:
		var severity: String = str(finding.get("severity", "info"))
		if not _branches.has(severity):
			return
		var item: TreeItem = _tree.create_item(_branches[severity])
		EventSheetProjectDoctorPanel._mark(_tree, item, severity, bool(finding.get("is_new", false)))
		item.set_text(1, EventSheetDoctorInbox.label_for(str(finding.get("check", ""))))
		item.set_text(2, EventSheetProjectDoctorPanel._where(finding))
		item.set_tooltip_text(2, str(finding.get("path")))
		item.set_text(3, str(finding.get("message")))
		item.set_metadata(0, str(finding.get("path", "")))
		item.set_metadata(1, finding)
		item.set_tooltip_text(3, "%s\n\n%s" % [str(finding.get("message")),
			EventSheetL10n.translate("Double-click to open this sheet.")])


## The mark a line leads with: nothing when the line was here last time, and one small accent dot
## when it is new since the last look. Drawn rather than typed, so it reads before a word, and drawn
## inside its own column so a read line's words start exactly where an unread line's do. There is no
## edge and no tint: the branch a line sits under already says how serious it is.
static func _mark(tree: Tree, item: TreeItem, severity: String, is_new: bool) -> void:
	item.set_cell_mode(0, TreeItem.CELL_MODE_CUSTOM)
	item.set_metadata(3, is_new)
	item.set_tooltip_text(0, EventSheetL10n.translate("New since you last looked.") if is_new
		else EventSheetDoctorInbox.severity_label(severity))
	if not is_new:
		return
	item.set_custom_draw_callback(0, func(_drawn: TreeItem, rect: Rect2) -> void:
		for shape: Dictionary in mark_shapes(rect, true):
			tree.draw_circle(shape["center"] as Vector2, float(shape["radius"]), EventSheetPopupUI.accent_color()))


## What the mark draws in a cell of `rect`: for a new line one dot, for a read line nothing. The dot
## sits against the cell's right side, the side next to the section word, with a clear gap on both
## sides of it, so it lines up down the column whatever depth the row is indented to and never
## reaches the word. Plain data so a test can pin it without a drawing surface.
static func mark_shapes(rect: Rect2, is_new: bool) -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	if not is_new:
		return shapes
	var radius: float = EventSheetPalette.scaled_f(3.0)
	var gap: float = EventSheetPalette.scaled_f(6.0)
	shapes.append({"kind": "circle", "radius": radius,
		"center": Vector2(rect.end.x - gap - radius, rect.position.y + rect.size.y / 2.0)})
	return shapes


## A finding about one row names it the way the margin, the bookmarks and the Find results name it -
## "player.gd · event 4" - so it can be quoted without a scroll position.
static func _where(finding: Dictionary) -> String:
	var where: String = str(finding.get("path")).get_file()
	var finding_event: int = int(finding.get("event", 0))
	if finding_event > 0:
		where += " · " + EventSheetL10n.translate("event %d") % finding_event
	return where


## The report itself, as rows of a Tree: severity, where, and the finding. Static and given its tree,
## so the window is not the only thing that can draw a report - a preview and a test build the same
## rows from the same findings, and there is one place that decides what a report line looks like.
static func fill(tree: Tree, root_item: TreeItem, findings: Array) -> void:
	for finding: Dictionary in findings:
		var item: TreeItem = tree.create_item(root_item)
		var severity: String = str(finding.get("severity"))
		item.set_text(0, severity.to_upper())
		item.set_custom_color(0, EventSheetPopupUI.tone_color(severity))
		item.set_text(1, _where(finding))
		item.set_tooltip_text(1, str(finding.get("path")))
		item.set_text(2, str(finding.get("message")))
		item.set_metadata(0, str(finding.get("path", "")))
		item.set_metadata(1, finding)
		item.set_tooltip_text(2, "%s\n\n%s" % [str(finding.get("message")),
			EventSheetL10n.translate("Double-click to open this sheet.")])


## Double-click / Enter on a finding, or Open: open its sheet in a tab (re-focusing an already-open
## one). Findings that point at non-sheet files (project.godot, a doc) fall back to a status hint.
func _open_activated_finding() -> void:
	var item: TreeItem = _doctor_tree.get_selected()
	if item == null or not (item.get_metadata(1) is Dictionary):
		return
	var path: String = str(item.get_metadata(0))
	if path.is_empty() or not ResourceLoader.exists(path):
		_dock._set_status(EventSheetL10n.translate("This finding has no sheet to open (%s).") % (path if not path.is_empty() else "no path"))
		return
	if path.get_extension() != "gd" and path.get_extension() != "tres":
		_dock._set_status(EventSheetL10n.translate("This finding points at %s - open it from the FileSystem dock.") % path.get_file())
		return
	_dock._navigate.open_or_focus(path)
	_doctor_window.hide()
	_dock._set_status(EventSheetL10n.translate("Opened %s from the Project Doctor.") % path.get_file())
	var line: int = reading_line_of(item.get_metadata(1) as Dictionary)
	if line > 0:
		_show_script_line(path, line)


## The line of its script a Reading finding is about, 0 for any other finding and for one that counts lines instead of
## naming one. The Reading section files each of its lines under the id "reading-line" with "path:line" as its subject.
static func reading_line_of(finding: Dictionary) -> int:
	if str(finding.get("check", "")) != "reading-line":
		return 0
	var subject: String = str(finding.get("subject", ""))
	var colon: int = subject.rfind(":")
	if colon < 0 or not subject.substr(colon + 1).is_valid_int():
		return 0
	return maxi(int(subject.substr(colon + 1)), 0)


## Selects, in the sheet just opened, the row that holds the script's `line`: the same lookup an error in the running
## game uses (the sheet's source map says which row wrote each line, most specific first), and the same way of reaching
## a row inside a folded block (`reveal_resource` unfolds what holds it). A coroutine: the sheet may still be opening
## on a worker.
func _show_script_line(path: String, line: int) -> void:
	while _dock._sheet_io.get("_open_job") != null:
		await _dock.get_tree().process_frame
	var sheet: EventSheetResource = _dock._current_sheet
	var view: EventSheetViewport = _dock._active_view()
	if sheet == null or view == null or _dock._current_sheet_path != path:
		return
	var mapped: Dictionary = EventSheetRuntimeErrorLocator.source_map_for(sheet, bool(_dock._dirty))
	if bool(mapped.get("stale", false)):
		return
	for entry: Variant in EventSheetLineRowMapper.entries_for_line(mapped.get("map", []), line):
		var resource: Resource = instance_from_id(int(str((entry as Dictionary).get("uid", "0")))) as Resource
		if resource != null and (view.select_resource(resource) or view.reveal_resource(resource)):
			return
