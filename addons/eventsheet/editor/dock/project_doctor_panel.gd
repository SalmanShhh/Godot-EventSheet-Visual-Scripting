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
# class only draws it: a finding is a coloured edge plus one sentence, a double-click opens the sheet
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


func init(dock: Control) -> void:
	_dock = dock


## Every door a finding has, as {id, label}: the built-in fixes first, then the check's own "fix"
## Callable when an extension attached one (its id is ""). The rows these become under the selected
## finding are the only way a fix is applied - no second button below the list does the same job.
static func offers_for(finding: Dictionary) -> Array[Dictionary]:
	var offers: Array[Dictionary] = EventSheetQuickFixes.fixes_for(finding)
	if finding.get("fix") is Callable:
		offers.append({"id": "", "label": str(finding.get("fix_label", EventSheetL10n.translate("Apply its fix")))})
	return offers


func open() -> void:
	if _doctor_window == null:
		_build()
	_doctor_window.popup_centered()
	_run_project_doctor()


## The window: the summary, the inbox, what a finding and a fix do, and the ways out.
func _build() -> void:
	_doctor_window = Window.new()
	_doctor_window.title = EventSheetL10n.translate("Check the project")
	_doctor_window.size = Vector2i(EventSheetPalette.scaled(940), EventSheetPalette.scaled(500))
	# Closing the window is what "I have looked at this" means: the identities on the page are written
	# down then, so the next open marks what appeared in between and nothing else. Doing it on OPEN
	# instead would erase the marks the reader came to read.
	_doctor_window.close_requested.connect(_close)
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	var body: MarginContainer = EventSheetPopupUI.margined(box)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_summary_label = Label.new()
	box.add_child(_summary_label)
	_doctor_tree = inbox_tree()
	_doctor_tree.item_selected.connect(_on_finding_selected)
	_doctor_tree.item_mouse_selected.connect(func(_at: Vector2, _button: int) -> void:
		_apply_fix_row(_doctor_tree.get_selected()))
	# A finding is a destination, not just a report line: double-click (or Enter) opens the sheet.
	_doctor_tree.item_activated.connect(func() -> void:
		if not _apply_fix_row(_doctor_tree.get_selected()):
			_open_activated_finding())
	var findings_card: PanelContainer = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Inbox"), _doctor_tree)
	findings_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(findings_card)
	_this_finding = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(600.0))
	box.add_child(_this_finding)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_child(_button(EventSheetL10n.translate("Re-run Checks"), _run_project_doctor))
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
	# A plain Window clears to the engine's grey; the panel under the body is what makes it the theme's.
	var back: Panel = Panel.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_doctor_window.add_child(back)
	_doctor_window.add_child(body)
	_dock.add_child(_doctor_window)


## The inbox's four columns: the mark (a severity edge and a new dot, read before a word is), the
## section, where, and the finding. Static so a preview draws the same tree the window does.
static func inbox_tree() -> Tree:
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.columns = 4
	var titles: Array[String] = ["", EventSheetL10n.translate("Section"), EventSheetL10n.translate("Where"),
		EventSheetL10n.translate("Finding")]
	var widths: Array[float] = [26.0, 190.0, 170.0, 0.0]
	for column: int in 4:
		tree.set_column_title(column, titles[column])
		tree.set_column_expand(column, column == 3)
		tree.set_column_custom_minimum_width(column, roundi(EventSheetPalette.scaled_f(widths[column])))
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return tree


static func _button(text: String, pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(pressed)
	return button


func _close() -> void:
	_mark_page_as_read()
	_doctor_window.hide()


func _run_project_doctor() -> void:
	_fix_pending = false
	_doctor_tree.clear()
	_fixed_item = null
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
	_summary_label.text = EventSheetDoctorInbox.summary_line(_page)
	_on_finding_selected()
	_dock._set_status(_summary_label.text, int(report.get("errors", 0)) > 0)


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


## A click (or Enter) on a fix row applies it, then re-runs the audit so the finding's going away is
## proven rather than assumed. False when the row is not a fix row; a fix row clicked again before
## the re-run has redrawn the page is answered as handled, so one gesture is one undo step.
func _apply_fix_row(item: TreeItem) -> bool:
	if item == null or not (item.get_metadata(2) is Dictionary):
		return false
	if _fix_pending:
		return true
	_fix_pending = true
	var finding: Dictionary = item.get_parent().get_metadata(1) as Dictionary
	var fix_id: String = str((item.get_metadata(2) as Dictionary).get("id", ""))
	if fix_id.is_empty():
		(finding["fix"] as Callable).call(finding)
	else:
		var result: Dictionary = EventSheetQuickFixes.apply(fix_id, finding, {"dock": _dock})
		_dock._set_status(str(result.get("message", "")), not bool(result.get("ok", false)))
	# Deferred: the click that got here is still being handled by the tree this clears.
	_run_project_doctor.call_deferred()
	return true


## The front page as rows of a Tree: one branch per severity, worst first, each finding under it with
## its section, its file and its words. Every line leads with its mark: an edge in the severity's
## colour, and a dot on the ones that were not here last time.
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
		_mark(tree, branch, severity, new_here > 0)
		branch.set_text(1, "%s (%d)" % [EventSheetDoctorInbox.severity_label(severity), held])
		branch.set_custom_color(1, EventSheetPopupUI.tone_color(severity))
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
		_mark(tree, item, severity, bool(finding.get("is_new", false)))
		item.set_text(1, EventSheetDoctorInbox.label_for(str(finding.get("check", ""))))
		item.set_text(2, _where(finding))
		item.set_tooltip_text(2, str(finding.get("path")))
		item.set_text(3, str(finding.get("message")))
		item.set_metadata(0, str(finding.get("path", "")))
		item.set_metadata(1, finding)
		item.set_tooltip_text(3, "%s\n\n%s" % [str(finding.get("message")),
			EventSheetL10n.translate("Double-click to open this sheet.")])


## The mark a line leads with: a severity edge down the left of the cell and, when the line is new
## since the last look, the accent dot beside it. Drawn rather than typed, so it reads before a word.
static func _mark(tree: Tree, item: TreeItem, severity: String, is_new: bool) -> void:
	var edge: Color = EventSheetPopupUI.tone_color(severity)
	item.set_cell_mode(0, TreeItem.CELL_MODE_CUSTOM)
	item.set_metadata(3, is_new)
	item.set_tooltip_text(0, EventSheetL10n.translate("New since you last looked.") if is_new
		else EventSheetDoctorInbox.severity_label(severity))
	item.set_custom_draw_callback(0, func(_drawn: TreeItem, rect: Rect2) -> void:
		var width: float = EventSheetPalette.scaled_f(3.0)
		tree.draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), edge)
		if is_new:
			tree.draw_circle(rect.position + Vector2(width + EventSheetPalette.scaled_f(9.0), rect.size.y / 2.0),
				EventSheetPalette.scaled_f(3.5), EventSheetPopupUI.accent_color()))


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
	_dock._load_sheet_from_path(path)
	_doctor_window.hide()
	_dock._set_status(EventSheetL10n.translate("Opened %s from the Project Doctor.") % path.get_file())
