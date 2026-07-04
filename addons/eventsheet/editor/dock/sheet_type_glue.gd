@tool
class_name EventSheetTypeGlue
extends RefCounted
# The Sheet Type dialog's dock-side glue, extracted from event_sheet_dock.gd:
# opening the dialog, its two field factories, and _apply_sheet_type_settings -
# the one function that turns the dialog's answers (intent, class name, icon,
# host, tags, includes, uses/requires, autoload, family) into sheet fields.
# Bodies moved verbatim behind the `_dock.` back-reference; delegates keep the
# menu wiring and tests untouched.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


# ── Sheet Type dialog (what the sheet compiles into) → dock/sheet_type_dialog.gd ──
# The dialog shell lives in the helper; the field-builders below (_add_sheet_type_field is shared with the
# pick dialog) and the _apply_sheet_type_settings service (driven directly by the addon-composition / tags /
# tool / singleton tests) stay here, so only the dialog's _ensure / widget reach-ins were repointed.
func open_sheet_type_dialog() -> void:  # Sheet menu / identity-banner edit / Tools menu
	_dock._sheet_type.open()


func add_sheet_type_field(form: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(130.0, 0.0)
	row.add_child(label)
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	form.add_child(row)
	return edit


## Like _add_sheet_type_field, but a small multi-line TextEdit - used for the class description,
## which compiles to a `##` doc comment (Godot's Create Node tooltip supports multiple lines).
func add_sheet_type_multiline_field(form: VBoxContainer, label_text: String, placeholder: String) -> TextEdit:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(130.0, 0.0)
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)
	var edit: TextEdit = TextEdit.new()
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0.0, 54.0)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	row.add_child(edit)
	form.add_child(row)
	return edit


## Applies the chosen sheet type (0 = plain, 1 = custom node, 2 = behavior) undoably and
## refreshes every identity surface (banner, tab badge, header, lint context). `family_enabled` marks
## a named sheet as a Family (instances collected into group family_<class>); it's cleared for a plain
## sheet, which has no class name to derive a family group from.
func apply_sheet_type_settings(type_index: int, class_name_text: String, icon_path: String, host_class_text: String, tool_enabled: bool = false, addon_tags: PackedStringArray = PackedStringArray(), include_paths: PackedStringArray = PackedStringArray(), uses_classes: PackedStringArray = PackedStringArray(), requires_classes: PackedStringArray = PackedStringArray(), autoload_name_text: String = "", class_description_text: String = "", family_enabled: bool = false) -> void:
	if _dock._current_sheet == null:
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Set Sheet Type", func() -> bool:
		_dock._current_sheet.behavior_mode = type_index == 2
		# The class description rides with the named-type identity (cleared for a plain sheet,
		# which has no class_name to attach a doc to).
		_dock._current_sheet.class_description = class_description_text.strip_edges() if type_index != 0 else ""
		# Autoload (Singleton) sheets: extends Node, addressed project-wide by name.
		_dock._current_sheet.autoload_mode = type_index == 4
		_dock._current_sheet.autoload_name = autoload_name_text.strip_edges() if type_index == 4 else ""
		if type_index == 4:
			_dock._current_sheet.host_class = "Node"
		# Editor Tool preset: an EditorScript with @tool - pair with On Editor Run.
		_dock._current_sheet.tool_mode = tool_enabled or type_index == 3
		_dock._current_sheet.custom_class_name = class_name_text.strip_edges() if type_index != 0 else ""
		_dock._current_sheet.custom_class_icon = icon_path.strip_edges() if type_index != 0 else ""
		# Family rides with the named-type identity: a plain sheet has no class to form a group from, so
		# clear it there (mirrors custom_class_name) to avoid a stale flag that would emit nothing.
		_dock._current_sheet.is_family = family_enabled and type_index != 0
		# Plain sheets aren't addons: clear tags like the class name/icon (otherwise a
		# type switch would leave stale tags that never emit - silent confusion).
		_dock._current_sheet.addon_tags = addon_tags if type_index != 0 else PackedStringArray()
		# Lane A composition (meta-packs): includes apply like tags; plain sheets keep
		# their includes too (library sheets predate addon composition).
		var applied_includes: Array[String] = []
		for include_path: String in include_paths:
			if not include_path.strip_edges().is_empty():
				applied_includes.append(include_path.strip_edges())
		_dock._current_sheet.includes = applied_includes
		var applied_uses: Array[String] = []
		for uses_class: String in uses_classes:
			if not uses_class.strip_edges().is_empty():
				applied_uses.append(uses_class.strip_edges())
		_dock._current_sheet.uses_addons = applied_uses
		var applied_requires: Array[String] = []
		for requires_class: String in requires_classes:
			if not requires_class.strip_edges().is_empty():
				applied_requires.append(requires_class.strip_edges())
		_dock._current_sheet.requires_behaviors = applied_requires
		if type_index == 4:
			pass  # Autoload already forced host_class = "Node" above; the dialog's stale host text must not undo it
		elif type_index == 3:
			_dock._current_sheet.host_class = "EditorScript"
		elif type_index == 5:
			# Custom Resource: the host must BE a data-asset class. Keep the user's Resource
			# subclass (AudioStream, a project class typed by hand); anything node-ish falls
			# back to plain Resource so the choice always produces a valid asset script.
			var resource_host: String = host_class_text.strip_edges()
			_dock._current_sheet.host_class = resource_host if EventSheetScriptIntent.is_resource_host(resource_host) else "Resource"
		elif not host_class_text.strip_edges().is_empty():
			_dock._current_sheet.host_class = host_class_text.strip_edges()
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._refresh_title_strip()
		_dock._refresh_tab_bar()
		_dock._mark_dirty("Sheet type updated.")
