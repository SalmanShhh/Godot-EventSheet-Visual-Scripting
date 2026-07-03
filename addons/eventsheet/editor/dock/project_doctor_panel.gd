@tool
class_name EventSheetProjectDoctorPanel
extends RefCounted

# The Project Doctor window (Tools ▸ Project Doctor) — a one-stop health-audit report.
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
		var findings_card: PanelContainer = EventSheetPopupUI.titled_card("Findings", _doctor_tree)
		findings_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(findings_card)
		var rerun_button: Button = Button.new()
		rerun_button.text = "Re-run checks"
		rerun_button.pressed.connect(_run_project_doctor)
		box.add_child(rerun_button)
		_doctor_window.add_child(body)
		_dock.add_child(_doctor_window)
	_doctor_window.popup_centered()
	_run_project_doctor()


func _run_project_doctor() -> void:
	_doctor_tree.clear()
	var root_item: TreeItem = _doctor_tree.create_item()
	var report: Dictionary = EventSheetProjectDoctor.run()
	for finding: Dictionary in (report.get("findings", []) as Array):
		var item: TreeItem = _doctor_tree.create_item(root_item)
		var severity: String = str(finding.get("severity"))
		item.set_text(0, severity.to_upper())
		item.set_custom_color(0, Color(0.92, 0.42, 0.42) if severity == "error"
			else (Color(0.93, 0.78, 0.4) if severity == "warning" else Color(0.6, 0.72, 0.86)))
		item.set_text(1, str(finding.get("path")).get_file())
		item.set_tooltip_text(1, str(finding.get("path")))
		item.set_text(2, str(finding.get("message")))
	var errors: int = int(report.get("errors", 0))
	_dock._set_status("Project Doctor: %d error(s), %d warning(s), %d note(s)." % [errors, int(report.get("warnings", 0)), int(report.get("infos", 0))], errors > 0)
