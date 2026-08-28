@tool
class_name EventSheetProjectDoctorPanel
extends RefCounted

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
# class only draws it, and it keeps the two things that made the old report worth opening: a
# double-click on any line opens the sheet it is about, and a selected finding shows the one-step
# fixes it has.
#
# Extracted from event_sheet_dock.gd so the dock stays focused; the dock keeps a thin
# _open_project_doctor() delegate for the Tools menu, and this class parents its window on the dock
# and writes the audit summary to the dock status bar.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

var _doctor_window: Window = null
var _doctor_tree: Tree = null
var _fix_button: Button = null


var _quick_fix_bar: HBoxContainer = null


## Enables the Fix button only when the selected finding carries a fix Callable, and redraws the
## quick-fix chips for whatever is selected now.
func _refresh_fix_button() -> void:
	_refresh_quick_fixes()
	if _fix_button == null:
		return
	var item: TreeItem = _doctor_tree.get_selected()
	var finding: Variant = item.get_metadata(1) if item != null else null
	_fix_button.disabled = not (finding is Dictionary and (finding as Dictionary).get("fix") is Callable)


## The one-step fixes for the selected finding, as chips. A finding with a one-click fix is a
## finding people act on; every chip here applies an operation the dock already has, and the
## check re-runs straight after so its disappearance is proven rather than assumed.
func _refresh_quick_fixes() -> void:
	if _quick_fix_bar == null:
		return
	for child: Node in _quick_fix_bar.get_children():
		child.queue_free()
	var item: TreeItem = _doctor_tree.get_selected()
	var finding: Variant = item.get_metadata(1) if item != null else null
	if not (finding is Dictionary):
		_quick_fix_bar.visible = false
		return
	var offered: Array[Dictionary] = EventSheetQuickFixes.fixes_for(finding as Dictionary)
	_quick_fix_bar.visible = not offered.is_empty()
	for offer: Dictionary in offered:
		var chip: Button = Button.new()
		chip.text = "%s %s" % [EventSheetL10n.translate("Fix:"), str(offer.get("label", ""))]
		chip.tooltip_text = "Applies this fix through undo, then re-runs the check."
		var fix_id: String = str(offer.get("id", ""))
		chip.pressed.connect(func() -> void: _apply_quick_fix(fix_id, finding as Dictionary))
		_quick_fix_bar.add_child(chip)


func _apply_quick_fix(fix_id: String, finding: Dictionary) -> void:
	var result: Dictionary = EventSheetQuickFixes.apply(fix_id, finding, {"dock": _dock})
	_dock._set_status(str(result.get("message", "")), not bool(result.get("ok", false)))
	_run_project_doctor()


func _run_selected_fix() -> void:
	var item: TreeItem = _doctor_tree.get_selected()
	var finding: Variant = item.get_metadata(1) if item != null else null
	if finding is Dictionary and (finding as Dictionary).get("fix") is Callable:
		((finding as Dictionary)["fix"] as Callable).call(finding)
		_run_project_doctor()


func open() -> void:
	if _doctor_window == null:
		_doctor_window = Window.new()
		_doctor_window.title = "Project Doctor"
		# Wider than the old three-column report: the page now carries a mark and a section beside
		# every finding, and a finding whose words are cut off is a finding nobody acts on.
		_doctor_window.size = Vector2i(940, 460)
		# Closing the window is what "I have looked at this" means: the identities on the page are
		# written down then, so the next open marks what appeared in between and nothing else. Doing
		# it on OPEN instead would erase the marks the reader came to read.
		_doctor_window.close_requested.connect(func() -> void:
			_mark_page_as_read()
			_doctor_window.hide())
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		var body: MarginContainer = EventSheetPopupUI.margined(box)
		body.set_anchors_preset(Control.PRESET_FULL_RECT)
		_doctor_tree = Tree.new()
		_doctor_tree.hide_root = true
		_doctor_tree.columns = 4
		# The mark column is first and narrow: "is this new" is the question a reader has before they
		# have read anything, so it must be answerable without reading a word.
		_doctor_tree.set_column_title(0, "New")
		_doctor_tree.set_column_title(1, "Section")
		_doctor_tree.set_column_title(2, "Where")
		_doctor_tree.set_column_title(3, "Finding")
		_doctor_tree.set_column_expand(0, false)
		_doctor_tree.set_column_custom_minimum_width(0, 40)
		_doctor_tree.set_column_expand(1, false)
		_doctor_tree.set_column_custom_minimum_width(1, 150)
		_doctor_tree.set_column_expand(2, false)
		_doctor_tree.set_column_custom_minimum_width(2, 180)
		_doctor_tree.column_titles_visible = true
		_doctor_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# A finding is a destination, not just a report line: double-click (or Enter) opens the
		# offending sheet in a tab so "go fix it" is one gesture instead of a manual hunt.
		_doctor_tree.item_activated.connect(_open_activated_finding)
		var findings_card: PanelContainer = EventSheetPopupUI.titled_card("Inbox", _doctor_tree)
		findings_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(findings_card)
		var buttons: HBoxContainer = HBoxContainer.new()
		var rerun_button: Button = Button.new()
		rerun_button.text = "Re-run checks"
		rerun_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rerun_button.pressed.connect(_run_project_doctor)
		buttons.add_child(rerun_button)
		# Extension checks may attach a "fix" Callable to a finding - one click repairs it, then
		# the audit re-runs so the finding's disappearance is PROVEN, not assumed.
		_fix_button = Button.new()
		_fix_button.text = "Fix selected"
		_fix_button.disabled = true
		_fix_button.pressed.connect(_run_selected_fix)
		buttons.add_child(_fix_button)
		# The reader's own "I have dealt with this page" - the same thing closing the window does,
		# for a reader who wants to keep it open and start again from a clean page.
		var read_button: Button = Button.new()
		read_button.text = "Mark all as read"
		read_button.tooltip_text = "Writes down what is on this page, so the next audit marks only what appeared after it."
		read_button.pressed.connect(func() -> void:
			_mark_page_as_read()
			_run_project_doctor())
		buttons.add_child(read_button)
		box.add_child(buttons)
		_quick_fix_bar = HBoxContainer.new()
		_quick_fix_bar.add_theme_constant_override("separation", 6)
		_quick_fix_bar.visible = false
		box.add_child(_quick_fix_bar)
		_doctor_tree.item_selected.connect(_refresh_fix_button)
		_doctor_window.add_child(body)
		_dock.add_child(_doctor_window)
	_doctor_window.popup_centered()
	_run_project_doctor()


func _run_project_doctor() -> void:
	_doctor_tree.clear()
	var root_item: TreeItem = _doctor_tree.create_item()
	# Through the public API so extension-registered checks (EventSheets.register_doctor_check)
	# report in the panel exactly like built-ins.
	var report: Dictionary = EventSheets.doctor()
	# The Project bar badges its entries from THIS run rather than running the audit itself: a
	# scan of the whole project on every bar rebuild is exactly the cost that panel promised not to
	# have. Handing the findings over here is what makes the badges free.
	EventSheetProjectOutline.set_doctor_findings(report.get("findings", []))
	if _dock._project_bar_glue.bar() != null:
		_dock._project_bar_glue.bar().refresh()
	# The page, decided once and headlessly: worst first, and what is new against the last read.
	_page = EventSheetDoctorInbox.triage(report.get("findings", []) as Array,
		EventSheetDoctorInbox.load_seen())
	fill_inbox(_doctor_tree, root_item, _page)
	var errors: int = int(report.get("errors", 0))
	_dock._set_status(EventSheetDoctorInbox.summary_line(_page), errors > 0)


## The page currently drawn - what "mark as read" writes down.
var _page: Array[Dictionary] = []


## Writes down every identity on the page, so the next audit marks only what appeared after it.
func _mark_page_as_read() -> void:
	EventSheetDoctorInbox.save_seen(EventSheetDoctorInbox.identities_of(_page))


## The front page as rows of a Tree: one branch per severity, worst first, each finding under it with
## its section, its file and its words - and a mark on the ones that were not here last time.
##
## Static and given its tree for the same reason `fill` is: the window is not the only thing that can
## draw a page, and there is exactly one place that decides what a line looks like.
static func fill_inbox(tree: Tree, root_item: TreeItem, page: Array[Dictionary]) -> void:
	var branches: Dictionary = {}
	for severity: String in EventSheetDoctorInbox.SEVERITY_ORDER:
		var held: int = 0
		var new_here: int = 0
		for finding: Dictionary in page:
			if str(finding.get("severity", "")) == severity:
				held += 1
				if bool(finding.get("is_new", false)):
					new_here += 1
		if held == 0:
			continue
		var branch: TreeItem = tree.create_item(root_item)
		branch.set_text(0, "●" if new_here > 0 else "")
		branch.set_text(1, "%s (%d)" % [EventSheetDoctorInbox.severity_label(severity), held])
		branch.set_custom_color(1, _severity_color(severity))
		branch.set_text(3, EventSheetL10n.translate("%d new since you last looked.") % new_here
			if new_here > 0 else "")
		branch.set_selectable(0, false)
		branch.set_selectable(1, false)
		branches[severity] = branch
	for finding: Dictionary in page:
		var severity: String = str(finding.get("severity", "info"))
		if not branches.has(severity):
			continue
		var item: TreeItem = tree.create_item(branches[severity])
		item.set_text(0, "●" if bool(finding.get("is_new", false)) else "")
		item.set_tooltip_text(0, "New since you last looked." if bool(finding.get("is_new", false))
			else "You have seen this one before.")
		item.set_text(1, EventSheetDoctorInbox.label_for(str(finding.get("check", ""))))
		item.set_custom_color(1, _severity_color(severity))
		var where: String = str(finding.get("path")).get_file()
		var finding_event: int = int(finding.get("event", 0))
		if finding_event > 0:
			where += " · " + EventSheetL10n.translate("event %d") % finding_event
		item.set_text(2, where)
		item.set_tooltip_text(2, str(finding.get("path")))
		item.set_text(3, str(finding.get("message")))
		item.set_metadata(0, str(finding.get("path", "")))
		item.set_metadata(1, finding)
		item.set_tooltip_text(3, "%s\n\nDouble-click to open this sheet." % str(finding.get("message")))


static func _severity_color(severity: String) -> Color:
	if severity == "error":
		return Color(0.92, 0.42, 0.42)
	return Color(0.93, 0.78, 0.4) if severity == "warning" else Color(0.6, 0.72, 0.86)


## The report itself, as rows of a Tree: severity, where, and the finding. Static and given its tree,
## so the window is not the only thing that can draw a report - a preview and a test build the same
## rows from the same findings, and there is one place that decides what a report line looks like.
static func fill(tree: Tree, root_item: TreeItem, findings: Array) -> void:
	for finding: Dictionary in findings:
		var item: TreeItem = tree.create_item(root_item)
		var severity: String = str(finding.get("severity"))
		item.set_text(0, severity.to_upper())
		item.set_custom_color(0, _severity_color(severity))
		# A finding about one row names it the way the margin, the bookmarks and the Find results
		# name it - "player.gd · event 4" - so it can be quoted without a scroll position.
		var where: String = str(finding.get("path")).get_file()
		var finding_event: int = int(finding.get("event", 0))
		if finding_event > 0:
			where += " · " + EventSheetL10n.translate("event %d") % finding_event
		item.set_text(1, where)
		item.set_tooltip_text(1, str(finding.get("path")))
		item.set_text(2, str(finding.get("message")))
		item.set_metadata(0, str(finding.get("path", "")))
		item.set_metadata(1, finding)
		item.set_tooltip_text(2, "%s\n\nDouble-click to open this sheet." % str(finding.get("message")))


## Double-click / Enter on a finding: open its sheet in a tab (re-focusing an already-open one).
## Findings that point at non-sheet files (project.godot, a doc) fall back to a status hint.
func _open_activated_finding() -> void:
	var item: TreeItem = _doctor_tree.get_selected()
	if item == null:
		return
	var path: String = str(item.get_metadata(0))
	if path.is_empty() or not ResourceLoader.exists(path):
		_dock._set_status("This finding has no sheet to open (%s)." % (path if not path.is_empty() else "no path"))
		return
	if path.get_extension() != "gd" and path.get_extension() != "tres":
		_dock._set_status("This finding points at %s - open it from the FileSystem dock." % path.get_file())
		return
	_dock._load_sheet_from_path(path)
	_doctor_window.hide()
	_dock._set_status("Opened %s from the Project Doctor." % path.get_file())
