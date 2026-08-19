@tool
class_name EventSheetVerbProperties
extends RefCounted

# The ACE PROPERTIES popup - what a published verb's header hands over when you click it.
#
# A verb row reads as an event-sheet Function block: ƒ, its name, one chip per input, nothing else. Every
# other thing the verb IS - its kind, its picker category, what it gives back, its description, whether
# it is featured and with which icon, the exact line it inserts, and which function in which file backs
# it - lives here, one click away, in ONE place instead of scattered across chips on the row.
#
# The panel is a pure function of the EventFunction plus its sheet (property_rows/build_panel are
# static and display-free), so a test can pin the exact rows a verb answers with, and a headless run
# builds it without a display server. Only open_for() needs a live editor: it parents the panel in a
# PopupPanel on the dock, which dismisses on click-outside / Esc like every other popup here.
#
# The three buttons REUSE the surfaces that already exist - the verb dialog for editing, the pack's
# guide for reading, Godot's script editor for the code. Nothing is edited here that is not edited
# there, so the two can never disagree.


## Rows shown above the buttons, in order. Kept as data so a caller (and a test) reads exactly what a
## verb answers, and so the panel builder has one loop instead of eight hand-placed rows.
## Each entry: {"label": String, "value": String, "form": String} - form is "text" (a plain value),
## "badge" (a filled pill), "rich" (BBCode-rendered prose) or "code" (a monospace card).
static func property_rows(event_function: EventFunction, sheet: EventSheetResource) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if event_function == null:
		return rows
	var role: String = ViewportRowBuilder.define_role_for(event_function)
	rows.append({"label": EventSheetL10n.translate("Kind"), "value": EventSheetL10n.translate(role.capitalize()), "form": "badge"})
	var category: String = event_function.ace_category.strip_edges()
	rows.append({
		"label": EventSheetL10n.translate("Category"),
		"value": category if not category.is_empty() else EventSheetL10n.translate("none"),
		"form": "text"
	})
	rows.append({"label": EventSheetL10n.translate("Inputs"), "value": input_summary(event_function), "form": "text"})
	rows.append({"label": EventSheetL10n.translate("Gives back"), "value": gives_back(event_function), "form": "text"})
	var description: String = event_function.description.strip_edges()
	if description.is_empty():
		description = ViewportRowBuilder.helper_doc_line(event_function)
	rows.append({
		"label": EventSheetL10n.translate("Description"),
		"value": description if not description.is_empty() else EventSheetL10n.translate("none"),
		"form": "rich"
	})
	rows.append({"label": EventSheetL10n.translate("In the picker"), "value": picker_summary(event_function), "form": "text"})
	rows.append({"label": EventSheetL10n.translate("Inserts"), "value": inserted_line(event_function, sheet), "form": "code"})
	rows.append({"label": EventSheetL10n.translate("Function"), "value": function_summary(event_function, sheet), "form": "text"})
	# Only when they are true of this verb: a row saying "not async" would be noise on every other one.
	var notes: PackedStringArray = PackedStringArray()
	if event_function.is_async:
		notes.append(EventSheetL10n.translate("waits"))
	if event_function.is_static:
		notes.append(EventSheetL10n.translate("static"))
	if not notes.is_empty():
		rows.append({"label": EventSheetL10n.translate("Notes"), "value": " · ".join(notes), "form": "text"})
	return rows


## "enabled  true/false", one input per line with its default when it has one, or "none".
static func input_summary(event_function: EventFunction) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for param: Variant in event_function.params:
		if not (param is ACEParam):
			continue
		var ace_param: ACEParam = param as ACEParam
		var line: String = "%s  %s" % [
			ViewportRowBuilder.friendly_param_label(ace_param),
			ViewportRowBuilder.friendly_type_word(ace_param.type_name)
		]
		var default_text: String = ace_param.gdscript_default.strip_edges()
		if not default_text.is_empty():
			line += " = %s" % default_text
		lines.append(line)
	if lines.is_empty():
		for legacy: String in event_function.parameters:
			lines.append(str(legacy).replace("_", " ").strip_edges())
	if lines.is_empty():
		return EventSheetL10n.translate("none")
	return "\n".join(lines)


## What the verb hands over, in plain words - "nothing" for a void Action, because a reader asking
## "what do I get?" deserves an answer, not a blank.
static func gives_back(event_function: EventFunction) -> String:
	if event_function.return_type == TYPE_NIL and event_function.return_type_name.strip_edges().is_empty():
		return EventSheetL10n.translate("nothing")
	return ViewportRowBuilder.friendly_type_word(SheetCompiler._function_return_type_name(event_function))


## Whether the verb is featured, and the icon the picker draws for it. An unpublished helper says so
## here rather than wearing an "internal" badge on the row - not being in the picker is a property, not
## an identity.
static func picker_summary(event_function: EventFunction) -> String:
	if not event_function.expose_as_ace:
		return EventSheetL10n.translate("not in the picker - this pack uses it inside itself")
	var parts: PackedStringArray = PackedStringArray()
	parts.append(EventSheetL10n.translate("★ featured") if event_function.featured else EventSheetL10n.translate("not featured"))
	var icon_path: String = icon_for(event_function)
	if not icon_path.is_empty():
		parts.append(EventSheetL10n.translate("icon %s") % icon_path.get_file())
	return " · ".join(parts)


## The `@ace_icon("…")` path the pack author wrote, read back off the annotation lines the importer
## kept verbatim (there is no icon field on EventFunction - the annotation IS the storage).
static func icon_for(event_function: EventFunction) -> String:
	for line: String in event_function.annotation_lines:
		var trimmed: String = line.strip_edges()
		var marker: int = trimmed.find("@ace_icon(")
		if marker < 0:
			continue
		var open_quote: int = trimmed.find("\"", marker)
		var close_quote: int = trimmed.rfind("\"")
		if open_quote >= 0 and close_quote > open_quote:
			return trimmed.substr(open_quote + 1, close_quote - open_quote - 1)
	return ""


## The exact line the picker inserts when someone drops this verb on a sheet - the authored
## `@ace_codegen_template` when the pack wrote one, otherwise the call the compiler derives.
static func inserted_line(event_function: EventFunction, sheet: EventSheetResource) -> String:
	var authored: String = event_function.codegen_template_override.strip_edges()
	if not authored.is_empty():
		return authored
	var slots: PackedStringArray = PackedStringArray()
	for param: Variant in event_function.params:
		if param is ACEParam:
			slots.append("{%s}" % (param as ACEParam).id)
	var call_text: String = "%s(%s)" % [event_function.function_name, ", ".join(slots)]
	var prefix: String = event_function.codegen_call_prefix.strip_edges()
	if prefix.is_empty() and sheet != null and not sheet.custom_class_name.strip_edges().is_empty():
		prefix = "$%s." % sheet.custom_class_name.strip_edges()
	return prefix + call_text


## "do_jump() in fps_controller_behavior.gd" - the code behind the verb, named so a reader can find it.
static func function_summary(event_function: EventFunction, sheet: EventSheetResource) -> String:
	var source_name: String = ""
	if sheet != null:
		source_name = sheet.external_source_path.get_file()
	if source_name.is_empty():
		return "%s()" % event_function.function_name
	return EventSheetL10n.translate("%s() in %s") % [event_function.function_name, source_name]


## The panel a verb's header opens: a ƒ title line, the property rows, and the three ways out. Built
## with the shared popup helpers, so it wears the same card / small-caps / badge / code-card look as
## every other dialog. Display-free (no popup, no editor singleton), so it builds fine headless.
## `on_edit` / `on_guide` / `on_code` are optional - a button with no handler is simply not built.
static func build_panel(event_function: EventFunction, sheet: EventSheetResource,
		on_edit: Callable = Callable(), on_guide: Callable = Callable(), on_code: Callable = Callable()) -> Control:
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(360.0), 0.0)
	if event_function == null:
		column.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("This function is no longer on the sheet.")))
		return EventSheetPopupUI.margined(column)
	var role: String = ViewportRowBuilder.define_role_for(event_function)
	var accent: Color = (ViewportRowBuilder.define_role_badge_colors(role) as Array)[1]
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	title_row.add_child(EventSheetPopupUI.metadata_badge("ƒ", accent))
	var title: Label = Label.new()
	title.text = EventSheetBBCodeLite.strip(display_name_of(event_function))
	title_row.add_child(title)
	var trailing: Label = Label.new()
	trailing.text = EventSheetL10n.translate("ACE properties")
	trailing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trailing.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trailing.add_theme_color_override("font_color", EventSheetPalette.TEXT_MUTED)
	title_row.add_child(trailing)
	column.add_child(title_row)
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	for row: Dictionary in property_rows(event_function, sheet):
		form.add_child(EventSheetPopupUI.form_row(str(row.get("label", "")), _field_for(row, accent)))
	column.add_child(EventSheetPopupUI.panel_section(form))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	_add_button(buttons, EventSheetL10n.translate("Edit…"), on_edit)
	_add_button(buttons, EventSheetL10n.translate("Open guide"), on_guide)
	_add_button(buttons, EventSheetL10n.translate("Show in code"), on_code)
	if buttons.get_child_count() > 0:
		column.add_child(buttons)
	return EventSheetPopupUI.margined(column)


## The verb's display name, falling back to its function name capitalized - the same fallback the row
## uses, so the popup title and the row header can never say two different things.
static func display_name_of(event_function: EventFunction) -> String:
	var display_name: String = event_function.ace_display_name.strip_edges()
	return display_name if not display_name.is_empty() else event_function.function_name.capitalize()


## One property row's field control, by its declared form.
static func _field_for(row: Dictionary, accent: Color) -> Control:
	var value: String = str(row.get("value", ""))
	match str(row.get("form", "text")):
		"badge":
			var badge_row: HBoxContainer = HBoxContainer.new()
			badge_row.add_child(EventSheetPopupUI.metadata_badge(value, accent))
			var spacer: Control = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			badge_row.add_child(spacer)
			return badge_row
		"rich":
			# The description is authored with the plugin's BBCode-lite, so it RENDERS here - a reader
			# must never meet a raw [b] tag in a surface whose whole job is to explain the verb.
			var rich: RichTextLabel = RichTextLabel.new()
			rich.bbcode_enabled = true
			rich.fit_content = true
			rich.scroll_active = false
			rich.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(240.0), 0.0)
			rich.text = value
			return rich
		"code":
			return EventSheetPopupUI.code_card(value, EventSheetPalette.scaled_f(240.0))
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(240.0), 0.0)
	return label


static func _add_button(host: HBoxContainer, text: String, handler: Callable) -> void:
	if not handler.is_valid():
		return
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(handler)
	host.add_child(button)


## The 1-based line a `func <name>(` is declared on in `source_path`, or -1 when the file cannot be
## read or holds no such function. Godot's script editor takes a line, so "Show in code" lands ON the
## verb instead of at the top of a 900-line pack.
static func function_line_in(source_path: String, function_name: String) -> int:
	if source_path.is_empty() or function_name.strip_edges().is_empty():
		return -1
	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return -1
	var line_number: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_number += 1
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("func %s(" % function_name) or trimmed.begins_with("static func %s(" % function_name):
			file.close()
			return line_number
	file.close()
	return -1


# ── The live popup (editor only) ───────────────────────────────────────────────────────────────

var _dock: Control = null
var _popup: PopupPanel = null


func init(dock: Control) -> void:
	_dock = dock


## Opens the properties for one verb at the mouse. Guarded: without a dock (or without a display) it
## simply does nothing, so a headless caller cannot crash on it.
func open_for(event_function: Resource) -> void:
	var verb: EventFunction = event_function as EventFunction
	if _dock == null or verb == null or not _dock.is_inside_tree():
		return
	if _popup == null:
		_popup = PopupPanel.new()
		# One transient popup reused for every verb - it dismisses on click-outside and Esc like the
		# ghost row and the inline param editor, so the gesture is the one users already know.
		_popup.popup_window = false
		_dock.add_child(_popup)
	# Snapshot first: removing a child while walking get_children() skips the next one.
	for child: Node in Array(_popup.get_children()):
		_popup.remove_child(child)
		child.queue_free()
	var verb_name: String = verb.function_name
	_popup.add_child(build_panel(
		verb, _dock._current_sheet,
		func() -> void: _run_and_close(func() -> void: _dock.edit_function(_find_verb(verb_name))),
		func() -> void: _run_and_close(func() -> void: _dock.open_pack_guide_for_sheet()),
		func() -> void: _run_and_close(func() -> void: _dock.show_verb_in_code(_find_verb(verb_name)))
	))
	_popup.reset_size()
	_popup.popup(Rect2i(Vector2i(_dock.get_screen_transform() * _dock.get_local_mouse_position()), Vector2i.ZERO))


## The verb of this name on the LIVE sheet. Re-fetched at click time because the undo funnel replaces
## every resource on commit, so a reference captured when the popup opened may point at a discarded
## snapshot.
func _find_verb(function_name: String) -> EventFunction:
	if _dock == null or _dock._current_sheet == null:
		return null
	return ViewportRowBuilder.find_function_by_name(_dock._current_sheet, function_name)


func _run_and_close(action: Callable) -> void:
	if _popup != null:
		_popup.hide()
	action.call()
