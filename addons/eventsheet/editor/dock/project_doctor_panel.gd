@tool
class_name EventSheetProjectDoctorPanel
extends RefCounted

# The Project Doctor window (Tools ▸ Project Doctor) - a one-stop health-audit report.
#
# The actual checks live in the global EventSheetProjectDoctor so the headless CLI and CI run the
# exact same audit; this class is only the editor window shell that renders the findings in a Tree
# (severity / where / finding) with a Re-run button. Extracted from event_sheet_dock.gd so the dock
# stays focused; the dock keeps a thin _open_project_doctor() delegate for the Tools menu, and this
# class parents its window on the dock and writes the audit summary to the dock status bar.

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
		_doctor_window.size = Vector2i(680, 440)
		_doctor_window.close_requested.connect(func() -> void: _doctor_window.hide())
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		var body: MarginContainer = EventSheetPopupUI.margined(box)
		body.set_anchors_preset(Control.PRESET_FULL_RECT)
		_doctor_tree = Tree.new()
		_doctor_tree.hide_root = true
		_doctor_tree.columns = 3
		_doctor_tree.set_column_title(0, "Severity")
		_doctor_tree.set_column_title(1, "Where")
		_doctor_tree.set_column_title(2, "Finding")
		_doctor_tree.set_column_expand(0, false)
		_doctor_tree.set_column_custom_minimum_width(0, 80)
		_doctor_tree.set_column_expand(1, false)
		_doctor_tree.set_column_custom_minimum_width(1, 180)
		_doctor_tree.column_titles_visible = true
		_doctor_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# A finding is a destination, not just a report line: double-click (or Enter) opens the
		# offending sheet in a tab so "go fix it" is one gesture instead of a manual hunt.
		_doctor_tree.item_activated.connect(_open_activated_finding)
		var findings_card: PanelContainer = EventSheetPopupUI.titled_card("Findings", _doctor_tree)
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
	# T13 - the Project bar badges its entries from THIS run rather than running the audit itself: a
	# scan of the whole project on every bar rebuild is exactly the cost that panel promised not to
	# have. Handing the findings over here is what makes the badges free.
	EventSheetProjectOutline.set_doctor_findings(report.get("findings", []))
	if _dock._project_bar_glue.bar() != null:
		_dock._project_bar_glue.bar().refresh()
	for finding: Dictionary in (report.get("findings", []) as Array):
		var item: TreeItem = _doctor_tree.create_item(root_item)
		var severity: String = str(finding.get("severity"))
		item.set_text(0, severity.to_upper())
		item.set_custom_color(0, Color(0.92, 0.42, 0.42) if severity == "error"
			else (Color(0.93, 0.78, 0.4) if severity == "warning" else Color(0.6, 0.72, 0.86)))
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
	var errors: int = int(report.get("errors", 0))
	_dock._set_status("Project Doctor: %d error(s), %d warning(s), %d note(s)." % [errors, int(report.get("warnings", 0)), int(report.get("infos", 0))], errors > 0)


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
