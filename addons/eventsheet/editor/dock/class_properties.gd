@tool
extends RefCounted
# The class this file IS, edited in the Properties bar the way an object type's properties are.
# Selecting any line of the sheet's class head shows it:
#
#   OBJECT TYPE
#   Name                Player                     Rename…
#   Type                CharacterBody2D ▾
#                       A body you move with code: players and enemies that walk, jump and collide.
#   Description         What a Player is for, in one line.
#   Icon                [icon] Default: the CharacterBody2D icon   Pick…
#   Runs in the editor  No ▾
#   File                res://player.gd                Show
#
# Every field writes exactly the one head line it stands for, through the head's own gestures
# (dock/sheet_head_actions.gd), so the bar, the head bands and the file can never disagree. Name
# renames everywhere after listing every file it will change; a new Type first says which of the
# old type's members the events use that the new one does not have.
#
# Loaded BY PATH from the Properties bar the first time a class head is selected.

const INSERT_OBJECT_PATH := "res://addons/eventsheet/editor/dock/insert_object_dialog.gd"
## The types the Type dropdown offers before the class's own: the everyday ones, in tile order.
const TYPE_CHOICES: PackedStringArray = ["CharacterBody2D", "Area2D", "Node2D", "CharacterBody3D", "Node3D",
	"Control", "Node", "Resource"]
## The Type dropdown's last item: any other class, picked in the Sheet Type window.
const OTHER_TYPE := "…"

var _dock: Control = null


func _init(dock: Control) -> void:
	_dock = dock


## The members a sheet's code uses that `old_host` has and `new_host` does not, sorted - what stops
## compiling after the change. Empty when the new type keeps everything (it extends the old one) or
## when either is not a class Godot knows, because a guess is worse than no warning.
static func members_lost(code: String, old_host: String, new_host: String) -> PackedStringArray:
	var lost: PackedStringArray = PackedStringArray()
	if not ClassDB.class_exists(old_host) or not ClassDB.class_exists(new_host) \
			or ClassDB.is_parent_class(new_host, old_host):
		return lost
	var kept: Dictionary = {}
	for name: String in _member_names(new_host):
		kept[name] = true
	for name: String in _member_names(old_host):
		if kept.has(name) or lost.has(name) or not name.is_valid_identifier():
			continue
		if RegEx.create_from_string("\\b%s\\b" % name).search(code) != null:
			lost.append(name)
	lost.sort()
	return lost


static func _member_names(class_id: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in ClassDB.class_get_method_list(class_id):
		names.append(str(entry.get("name", "")))
	for entry: Dictionary in ClassDB.class_get_property_list(class_id):
		if int(entry.get("usage", 0)) & (PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP) == 0:
			names.append(str(entry.get("name", "")))
	for entry: Dictionary in ClassDB.class_get_signal_list(class_id):
		names.append(str(entry.get("name", "")))
	return names


## The two choices of "Runs in the editor", as [word, sentence]: off first.
static func tool_choices() -> Array:
	return [
		[EventSheetL10n.translate("No"), EventSheetL10n.translate("The code runs only when the game runs. Right for almost every script.")],
		[EventSheetL10n.translate("Yes (@tool)"), EventSheetL10n.translate("The code also runs inside the editor: previews, level tools, Inspector buttons.")],
	]


## Builds the section into the bar's two-column grid.
func build_into(form: GridContainer) -> void:
	var head: Dictionary = _dock._head_actions.head_facts()
	var editable: bool = not _dock._current_sheet.read_only
	var base: String = str(head.get("extends", "")).strip_edges()
	if base.is_empty():
		base = "Node"
	form.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("Object type")))
	form.add_child(Control.new())
	var class_word: String = str(head.get("class_name", ""))
	_row(form, EventSheetL10n.translate("Name"), _value_with_button(
		class_word if not class_word.is_empty() else EventSheetL10n.translate("(no class name)"),
		EventSheetL10n.translate("Rename…"), _dock._head_actions.open_class_rename, editable),
		EventSheetL10n.translate("Renames the class everywhere it is used, after showing every file."))
	var type_box: VBoxContainer = VBoxContainer.new()
	var types: OptionButton = EventSheetPopupUI.described_option()
	var choices: PackedStringArray = TYPE_CHOICES.duplicate()
	if not choices.has(base):
		choices.append(base)
	var words_of: Script = load(INSERT_OBJECT_PATH)
	for class_id: String in choices:
		EventSheetPopupUI.add_described_item(types, class_id, str(words_of.words_for(class_id)[1]))
	EventSheetPopupUI.add_described_item(types, EventSheetL10n.translate("Other class…"),
		EventSheetL10n.translate("Any class Godot or this project has, picked in the Sheet Type window."), OTHER_TYPE)
	EventSheetPopupUI.select_option(types, base)
	EventSheetPopupUI.follow_description(types)
	types.disabled = not editable
	type_box.add_child(types)
	# The chosen type's sentence stays visible under the dropdown, not only on hover.
	type_box.add_child(EventSheetPopupUI.hint_label(types.tooltip_text, EventSheetPalette.scaled_f(190.0)))
	types.item_selected.connect(func(index: int) -> void:
		if str(types.get_item_metadata(index)) == OTHER_TYPE:
			_dock._open_sheet_type_dialog()
			return
		change_type(types.get_item_text(index)))
	_row(form, EventSheetL10n.translate("Type"), type_box,
		EventSheetL10n.translate("What it extends: its built-in properties and actions come from this."))
	var description: LineEdit = LineEdit.new()
	description.text = EventSheetHeadBands.description_line(str(head.get("description", "")))
	description.placeholder_text = EventSheetL10n.translate("What it is for, in one line.")
	description.editable = editable
	var write_description: Callable = func(text: String) -> void:
		if text.strip_edges() != EventSheetHeadBands.description_line(str(_dock._head_actions.head_facts().get("description", ""))):
			_dock._head_actions.apply_band_value(EventSheetHeadBands.BAND_DESCRIPTION, text.strip_edges())
	description.text_submitted.connect(write_description)
	description.focus_exited.connect(func() -> void: write_description.call(description.text))
	_row(form, EventSheetL10n.translate("Description"), description,
		EventSheetL10n.translate("The ## line: shown as its tooltip in the editor."))
	_row(form, EventSheetL10n.translate("Icon"), _icon_field(str(head.get("icon", "")), base, editable),
		EventSheetL10n.translate("The picture Godot shows for this class in the Scene dock and Create New Node."))
	var tool_option: OptionButton = EventSheetPopupUI.described_option()
	for choice: Array in tool_choices():
		EventSheetPopupUI.add_described_item(tool_option, str(choice[0]), str(choice[1]))
	tool_option.select(1 if bool(head.get("tool", false)) else 0)
	EventSheetPopupUI.follow_description(tool_option)
	tool_option.disabled = not editable
	tool_option.item_selected.connect(func(index: int) -> void:
		if (index == 1) != bool(_dock._head_actions.head_facts().get("tool", false)):
			_dock._head_actions.toggle_tool_mode())
	_row(form, EventSheetL10n.translate("Runs in the editor"), tool_option,
		EventSheetL10n.translate("A tool: its code runs while you edit."))
	var file_path: String = str(head.get("source_path", ""))
	if file_path.is_empty():
		file_path = str(_dock._current_sheet_path)
	if not file_path.is_empty():
		_row(form, EventSheetL10n.translate("File"), _value_with_button(file_path, EventSheetL10n.translate("Show"),
			func() -> void: _dock._head_actions.browse_to_scene(file_path), true),
			EventSheetL10n.translate("Where it lives."))


## Changes what the class extends. When the events use something the new type does not have, the
## question names each of those first, so nothing stops compiling unannounced.
func change_type(new_host: String) -> void:
	var old_host: String = str(_dock._head_actions.head_facts().get("extends", ""))
	if new_host == old_host:
		return
	var code: String = str(SheetCompiler.compile(_dock._current_sheet, "", true).get("output", ""))
	var lost: PackedStringArray = members_lost(code, old_host, new_host)
	if lost.is_empty():
		_dock._head_actions.apply_band_value(EventSheetHeadBands.BAND_EXTENDS, new_host)
		return
	var places: Array = []
	for name: String in lost:
		places.append([name, old_host])
	load(_dock.SMALL_PROMPT_PATH).open(_dock, {
		"title": EventSheetL10n.translate("Change %s to %s?") % [old_host, new_host],
		"say": EventSheetL10n.translate("The events use these, and a %s does not have them. Those lines stop compiling until they are changed.") % new_host,
		"list": places,
		"glyph": "!",
		"main": EventSheetL10n.translate("Keep %s") % old_host,
		"danger": EventSheetL10n.translate("Change type"),
		"on_main": func() -> void: _dock._properties_bar.refresh(),
		"on_cancel": func() -> void: _dock._properties_bar.refresh(),
		"on_danger": func() -> void: _dock._head_actions.apply_band_value(EventSheetHeadBands.BAND_EXTENDS, new_host),
		"note": EventSheetL10n.translate("Ctrl+Z undoes it."),
	})


## The icon: a preview of what Godot will show, the path or the default it falls back to, and the
## button that changes it.
func _icon_field(icon_path: String, base: String, editable: bool) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	var preview: TextureRect = TextureRect.new()
	preview.custom_minimum_size = Vector2.ONE * EventSheetPalette.scaled_f(16.0)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var own: bool = not icon_path.is_empty()
	if own and ResourceLoader.exists(icon_path):
		preview.texture = load(icon_path) as Texture2D
	elif _dock.has_theme_icon(base, "EditorIcons"):
		preview.texture = _dock.get_theme_icon(base, "EditorIcons")
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(preview)
	var words: HBoxContainer = _value_with_button(icon_path if own
		else EventSheetL10n.translate("Default: the %s icon") % base,
		EventSheetL10n.translate("Use default") if own else EventSheetL10n.translate("Pick…"),
		(func() -> void: _dock._head_actions.apply_band_value(EventSheetHeadBands.BAND_ICON, "")) if own
			else _dock._head_actions.open_icon_dialog, editable)
	words.tooltip_text = EventSheetL10n.translate("Your own icon, written as @icon at the top of the file.") if own \
		else EventSheetL10n.translate("Until you pick one, the class uses its type's own editor icon - nothing extra is written.")
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	return line


## A value read as text with the one button that changes it beside it.
static func _value_with_button(value: String, button_text: String, pressed: Callable, enabled: bool) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = value
	label.tooltip_text = value
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var button: Button = Button.new()
	button.text = button_text
	button.disabled = not enabled
	button.pressed.connect(pressed)
	line.add_child(button)
	return line


static func _row(form: GridContainer, label_text: String, field: Control, tooltip: String) -> void:
	var label: Label = Label.new()
	label.text = label_text
	label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	form.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if field.tooltip_text.is_empty():
		field.tooltip_text = tooltip
	form.add_child(field)
