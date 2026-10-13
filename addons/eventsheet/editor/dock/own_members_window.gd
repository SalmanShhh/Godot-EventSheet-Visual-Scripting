@tool
extends AcceptDialog

# Sheet > Properties and actions…: what the open behaviour or global offers, as five lists.
#
# Properties (a behaviour's exported variables - what a designer sets per object in the Inspector) or
# Global values (a global's variables, kept while scenes change) as a table with the lines they are in
# code under it; then the Actions, Conditions, Triggers and Expressions every other sheet's picker
# offers, each named, kind-labelled, with a "returns" chip where it gives a value back. Clicking a name
# shows its row on the sheet. Each list's Add button opens the ordinary window that writes that kind
# of member, so there is one way to add each. A global also says whether it is on, and the tick
# writes its row in Godot's own Project Settings > Globals > Autoload.
#
# Read from the sheet every time the window is shown or comes back into focus, through the same census
# the Anatomy rail draws from - nothing here is stored, so it cannot disagree with the sheet.

const LISTS: Array[String] = ["properties", "actions", "conditions", "triggers", "expressions"]
const PANEL_PATH := "res://addons/eventsheet/editor/dock/new_addon_panel.gd"

var _dock: Control = null
var _list: String = "properties"
var _tabs: TabBar = null
var _lead: Label = null
var _body: VBoxContainer = null
var _add_button: Button = null
var _on_check: CheckBox = null


func _init(dock: Control) -> void:
	_dock = dock
	ok_button_text = EventSheetL10n.translate("Close")
	var page: VBoxContainer = EventSheetPopupUI.form_box()
	page.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(620.0), EventSheetPalette.scaled_f(380.0))
	_lead = EventSheetPopupUI.hint_label("", EventSheetPalette.scaled_f(600.0))
	page.add_child(_lead)
	_tabs = TabBar.new()
	_tabs.clip_tabs = false
	for list: String in LISTS:
		_tabs.add_tab(list)
	_tabs.tab_changed.connect(func(index: int) -> void:
		_list = LISTS[index]
		refresh())
	page.add_child(_tabs)
	_add_button = Button.new()
	_add_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_add_button.pressed.connect(_on_add)
	page.add_child(_add_button)
	_body = VBoxContainer.new()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	page.add_child(scroll)
	_on_check = CheckBox.new()
	_on_check.toggled.connect(_on_turned)
	page.add_child(_on_check)
	add_child(page)
	# Every Add opens another window; the lists catch up the moment this one is looked at again.
	focus_entered.connect(refresh)


## Reads the open sheet and shows the window.
func open() -> void:
	refresh()
	if is_inside_tree():
		popup_centered(Vector2i(int(EventSheetPalette.scaled_f(680.0)), int(EventSheetPalette.scaled_f(560.0))))


func _sheet() -> EventSheetResource:
	return _dock.get_current_sheet() if _dock != null else null


## What the open file is called on its lists, and whether it is a global.
static func identity(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {"name": "", "global": false}
	var file_name: String = sheet.external_source_path.get_file().get_basename().to_pascal_case()
	if sheet.autoload_mode or not global_name_for(sheet.external_source_path).is_empty():
		var autoload: String = sheet.autoload_name if not sheet.autoload_name.is_empty() else global_name_for(sheet.external_source_path)
		return {"name": autoload if not autoload.is_empty() else file_name, "global": true}
	return {"name": sheet.custom_class_name if not sheet.custom_class_name.is_empty() else file_name, "global": false}


## The autoload name Godot loads this script under (directly or as the scene beside it), or "".
static func global_name_for(script_path: String) -> String:
	if script_path.is_empty():
		return ""
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting: String = str(property_info.get("name", ""))
		var target: String = str(ProjectSettings.get_setting(setting, "")).trim_prefix("*") if setting.begins_with("autoload/") else ""
		if target == script_path or target == script_path.get_basename() + ".tscn":
			return setting.trim_prefix("autoload/")
	return ""


## The entries of one list, as {"label", "kind", "returns", "reads", "resource"} - or, for the first
## list, {"name", "type", "value", "means", "line", "resource"} per variable.
static func entries(sheet: EventSheetResource, list: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sheet == null:
		return out
	if list == "properties":
		var is_global: bool = bool(identity(sheet).get("global"))
		for entry: Variant in sheet.events:
			var variable: LocalVariable = entry as LocalVariable
			if variable == null or variable.is_constant or (not is_global and not variable.exported):
				continue
			out.append({"name": variable.name, "type": variable.type_name, "value": var_to_str(variable.default_value),
				"means": variable.description, "line": EventSheetCodeEcho.line_for(variable), "resource": variable})
		return out
	for organ: Dictionary in BehaviourAnatomyPanel.collect_anatomy(sheet):
		if str(organ.get("id")) != list:
			continue
		for entry: Dictionary in organ.get("entries", []):
			var resource: Resource = entry.get("resource") as Resource
			var returns: String = ""
			var reads: String = ""
			if resource is EventFunction:
				var event_function: EventFunction = resource as EventFunction
				returns = event_function.return_type_name if event_function.return_type != TYPE_NIL else ""
				if returns.is_empty() and event_function.return_type != TYPE_NIL:
					returns = type_string(event_function.return_type)
				reads = event_function.display_template if not event_function.display_template.is_empty() else event_function.description
			elif resource is SignalRow:
				reads = (resource as SignalRow).description
			out.append({"label": str(entry.get("label", "")), "kind": list.trim_suffix("s"), "returns": returns,
				"reads": reads, "resource": resource})
	return out


func refresh() -> void:
	var sheet: EventSheetResource = _sheet()
	var who: Dictionary = identity(sheet)
	var is_global: bool = bool(who.get("global"))
	var first_list: String = EventSheetL10n.translate("Global values") if is_global else EventSheetL10n.translate("Properties")
	var words: Array[String] = [first_list, EventSheetL10n.translate("Actions"), EventSheetL10n.translate("Conditions"),
		EventSheetL10n.translate("Triggers"), EventSheetL10n.translate("Expressions")]
	for index: int in range(LISTS.size()):
		_tabs.set_tab_title(index, "%s  %d" % [words[index], entries(sheet, LISTS[index]).size()])
	title = "%s · %s" % [str(who.get("name")), words[LISTS.find(_list)]]
	_lead.text = _lead_sentence(is_global)
	_add_button.text = _add_words(is_global)
	_add_button.disabled = sheet == null or sheet.read_only
	for old: Node in _body.get_children():
		_body.remove_child(old)
		old.queue_free()
	var shown: Array[Dictionary] = entries(sheet, _list)
	if shown.is_empty():
		_body.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("None yet - Add writes the first one.")))
	elif _list == "properties":
		var rows: Array = []
		var lines: PackedStringArray = PackedStringArray()
		for entry: Dictionary in shown:
			rows.append(PackedStringArray([str(entry["name"]), str(entry["type"]), str(entry["value"]), str(entry["means"])]))
			lines.append(str(entry["line"]))
		_body.add_child(EventSheetPopupUI.compact_table(PackedStringArray([EventSheetL10n.translate("Name"),
			EventSheetL10n.translate("Type"), EventSheetL10n.translate("Default"), EventSheetL10n.translate("What it means")]), rows, 3))
		_body.add_child(EventSheetPopupUI.code_card("\n".join(lines), EventSheetPalette.scaled_f(560.0)))
	else:
		for entry: Dictionary in shown:
			_body.add_child(_entry_row(entry))
	var global_name: String = global_name_for(sheet.external_source_path) if sheet != null else ""
	_on_check.visible = is_global
	_on_check.set_pressed_no_signal(not global_name.is_empty())
	_on_check.text = (EventSheetL10n.translate("%s is on - it loads before the first scene and stays while scenes change.") if not global_name.is_empty()
		else EventSheetL10n.translate("%s is off - the script stays, nothing loads it.")) % str(who.get("name"))


func _lead_sentence(is_global: bool) -> String:
	if _list == "properties":
		return EventSheetL10n.translate("Values every scene shares, kept while scenes change.") if is_global \
			else EventSheetL10n.translate("What a designer sets per object in the Inspector, like any behaviour's properties.")
	return EventSheetL10n.translate("What every sheet's picker offers under this global's name. Click a name to see its row.") if is_global \
		else EventSheetL10n.translate("What every sheet's picker offers under the object this is added to. Host is that object. Click a name to see its row.")


func _add_words(is_global: bool) -> String:
	match _list:
		"actions":
			return EventSheetL10n.translate("+ Add action")
		"conditions":
			return EventSheetL10n.translate("+ Add condition")
		"triggers":
			return EventSheetL10n.translate("+ Add trigger")
		"expressions":
			return EventSheetL10n.translate("+ Add expression")
	return EventSheetL10n.translate("+ Add global value") if is_global else EventSheetL10n.translate("+ Add property")


## One offered member: its kind as a coloured word, its name (click to see the row), what it returns.
func _entry_row(entry: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(8.0)))
	var kind: Label = Label.new()
	kind.text = kind_word(str(entry["kind"]))
	kind.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(80.0), 0.0)
	kind.add_theme_color_override("font_color", kind_color(str(entry["kind"])))
	row.add_child(kind)
	var name_button: LinkButton = LinkButton.new()
	name_button.text = str(entry["label"])
	name_button.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	name_button.add_theme_color_override("font_color", EventSheetPopupUI.text_color())
	name_button.tooltip_text = str(entry["reads"])
	name_button.pressed.connect(func() -> void:
		var view: EventSheetViewport = _dock._active_view()
		if view != null and entry["resource"] is Resource:
			view.reveal_resource(entry["resource"]))
	row.add_child(name_button)
	if not str(entry["returns"]).is_empty():
		row.add_child(EventSheetPopupUI.metadata_badge(EventSheetL10n.translate("returns %s") % str(entry["returns"])))
	return row


## The word a kind is labelled with.
static func kind_word(kind: String) -> String:
	match kind:
		"action":
			return EventSheetL10n.translate("Action")
		"condition":
			return EventSheetL10n.translate("Condition")
		"trigger":
			return EventSheetL10n.translate("Trigger")
	return EventSheetL10n.translate("Expression")


## The colour a kind's word is written in: an action green, a condition blue, a trigger amber and an
## expression purple, each from the editor's own tones so it reads on a light theme as well.
static func kind_color(kind: String) -> Color:
	match kind:
		"action":
			return EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_OK)
		"condition":
			return EventSheetPopupUI.accent_color()
		"trigger":
			return EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_WARNING)
	return EventSheetPopupUI.readable_on_panel(EventSheetPalette.COLOR_EXPRESSION)


func _on_add() -> void:
	var is_global: bool = bool(identity(_sheet()).get("global"))
	match _list:
		"properties":
			if is_global:
				_dock._variable_dlg.open("global")
			else:
				_dock._variables._on_add_instance_variable_requested()
		"triggers":
			if not _dock._ensure_sheet_for_editing():
				return
			var trigger: SignalRow = SignalRow.new()
			trigger.trigger = true
			if _dock._perform_undoable_sheet_edit("Add trigger", func() -> bool:
					_dock._insert_row_below_selection(trigger)
					return true):
				_dock._mark_dirty(EventSheetL10n.translate("Added a trigger."))
				_dock._open_signal_dialog(trigger)
		_:
			_dock._function_dialog_glue._open_function_dialog_new(_list.trim_suffix("s"), true)


func _on_turned(on: bool) -> void:
	var sheet: EventSheetResource = _sheet()
	if sheet == null:
		return
	var script_path: String = sheet.external_source_path
	var scene_path: String = script_path.get_basename() + ".tscn"
	var global_name: String = global_name_for(script_path)
	if global_name.is_empty():
		global_name = str(identity(sheet).get("name"))
	load(PANEL_PATH).set_global_on(global_name, scene_path if FileAccess.file_exists(scene_path) else script_path, on)
	refresh()
