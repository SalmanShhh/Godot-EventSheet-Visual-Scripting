# EventForge - editor-string extraction for translators (dev tool, headless-safe).
#
# Builds the live dock, walks every Control it created, and collects the user-facing strings
# (button/label text, tooltips, placeholders, window titles, menu items) plus the canvas-drawn
# tables (empty-sheet advice, CTA labels, add affordances, banner templates). Writes a ready-to-
# fill translation template CSV - add your locale's column header and fill the second column:
#   "$GODOT" --headless --path . --script tools/extract_editor_strings.gd
# Output: res://eventsheet_translations/eventsheet_editor_strings.template.csv
extends SceneTree


func _init() -> void:
	var dock: Control = EventSheetEditor.new()
	root.add_child(dock)
	dock.setup(EventSheetResource.new())
	var strings: Dictionary = {}
	_collect(dock, strings)
	_collect_drawn_tables(strings)
	var keys: Array = strings.keys()
	keys.sort()
	var out_dir: String = "res://eventsheet_translations"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var out_path: String = "%s/eventsheet_editor_strings.template.csv" % out_dir
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	file.store_csv_line(PackedStringArray(["keys", "your_locale_code_here"]))
	for key: Variant in keys:
		file.store_csv_line(PackedStringArray([str(key), ""]))
	file.close()
	print("extracted %d strings -> %s" % [keys.size(), out_path])
	dock.free()
	quit(0)


func _remember(strings: Dictionary, text: String) -> void:
	var trimmed: String = text.strip_edges()
	# Skip empties, bare glyphs/numbers, and obviously dynamic strings (paths, format leftovers).
	if trimmed.length() < 2 or trimmed.begins_with("res://") or trimmed.begins_with("user://"):
		return
	strings[trimmed] = true


func _collect(node: Node, strings: Dictionary) -> void:
	if node is Window:
		_remember(strings, (node as Window).title)
	if node is Control:
		_remember(strings, (node as Control).tooltip_text)
	if node is Button:
		_remember(strings, (node as Button).text)
	elif node is Label:
		_remember(strings, (node as Label).text)
	elif node is LineEdit:
		_remember(strings, (node as LineEdit).placeholder_text)
	elif node is TextEdit:
		_remember(strings, (node as TextEdit).placeholder_text)
	if node is MenuButton or node is OptionButton:
		var popup: PopupMenu = (node as MenuButton).get_popup() if node is MenuButton else (node as OptionButton).get_popup()
		for index: int in range(popup.item_count):
			_remember(strings, popup.get_item_text(index))
			_remember(strings, popup.get_item_tooltip(index))
	if node is PopupMenu:
		for index: int in range((node as PopupMenu).item_count):
			_remember(strings, (node as PopupMenu).get_item_text(index))
	for child: Node in node.get_children(true):
		_collect(child, strings)


## The strings drawn straight to canvas (they never live on a Control) - collected from their
## data tables so translators see them without hunting through code.
func _collect_drawn_tables(strings: Dictionary) -> void:
	var probe_sheets: Array = [null, EventSheetResource.new()]
	var behavior_sheet: EventSheetResource = EventSheetResource.new()
	behavior_sheet.behavior_mode = true
	var autoload_sheet: EventSheetResource = EventSheetResource.new()
	autoload_sheet.autoload_mode = true
	probe_sheets.append(behavior_sheet)
	probe_sheets.append(autoload_sheet)
	for sheet: Variant in probe_sheets:
		var advice: Dictionary = EventSheetScriptIntent.empty_sheet_advice(sheet)
		for value: Variant in advice.values():
			_remember(strings, str(value))
		for spec: Dictionary in ViewportEmptyStateHelper.cta_specs(sheet):
			_remember(strings, str(spec.get("label", "")))
	for affordance: String in ["+ Add action", "+ Add condition", "+ Add event…", "Every Tick"]:
		_remember(strings, affordance)
	for template: String in [
		"%s - Behavior · acts on host: %s",
		"%s - Autoload · one instance, project-wide",
		"%s - Editor Tool · runs in the editor (File > Run)",
		"%s - Custom Resource · every .tres of it is a data asset",
		"Event Sheet · a script for the %s it's attached to",
		"%s - Custom Node · extends %s",
	]:
		_remember(strings, template)
