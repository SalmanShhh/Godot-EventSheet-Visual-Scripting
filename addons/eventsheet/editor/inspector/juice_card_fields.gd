# Godot EventSheets - the fields of a juice card that point at something in the scene (editor-only).
#
# A juice card that acts on another node, a property of it, a value of its shader or a signal of its
# script does not ask for a typed name. It asks Godot: the node comes from Godot's own node picker, the
# property from its property picker, and the lists (an animation, a shader value, a signal) are read from
# the node that was picked. This file draws those fields for the card-list drawer and answers the
# questions they share: which node a stored path means from where this player stands, and what to say
# when it means nothing any more.
#
# A STORED PATH IS RELATIVE TO THE PLAYER. A card keeps `player.get_path_to(node)`, a NodePath, so the
# card follows a rename or a move in the Scene dock the way every other exported path does, and a scene
# copied somewhere else still finds its nodes.
#
# THE DRAWER IS HANDED IN, never reached for: every function here takes the drawer that is building the
# card, so the field writes through the drawer's own write path and the list keeps its one undo funnel.
#
# Loaded by path from the drawer, so the first open of the editor does not compile it.
@tool
extends RefCounted

## The plain words a field says when it names nothing.
const NOTHING_PICKED: String = "(none)"


## The node a card's stored path means from the object being edited, or null.
static func resolve(edited: Object, stored: Variant) -> Node:
	var path: NodePath = stored if stored is NodePath else NodePath(str(stored))
	if path.is_empty() or not (edited is Node):
		return null
	return (edited as Node).get_node_or_null(path)


## The object a juice player acts on: its Acts On node, else its parent.
static func host_of(edited: Object) -> Node:
	if not (edited is Node):
		return null
	var chosen: Variant = edited.get("acts_on")
	return chosen as Node if chosen is Node else (edited as Node).get_parent()


## The node a card means under a key, where an empty key means the object the player is under.
static func target_of(edited: Object, card: Dictionary, key: String) -> Node:
	if str(card.get(key, "")).is_empty():
		return host_of(edited)
	return resolve(edited, card.get(key))


## The sentence under a node field whose path finds nothing, or an empty text when it finds a node.
static func missing_note(edited: Object, card: Dictionary, key: String) -> String:
	var stored: Variant = card.get(key, NodePath())
	var path: NodePath = stored if stored is NodePath else NodePath(str(stored))
	if path.is_empty() or not (edited is Node) or resolve(edited, path) != null:
		return ""
	var named: String = path.get_name(path.get_name_count() - 1) if path.get_name_count() > 0 else str(path)
	return EventSheetL10n.translate("%s is not under this object any more.") % named


## The words a node field shows: the name of the picked node, as the Scene dock shows it (a parent, the
## owner and the player itself included), else what an empty field means. A path that finds no node shows
## its last name.
static func node_words(edited: Object, card: Dictionary, key: String, empty_means: String) -> String:
	var stored: Variant = card.get(key, NodePath())
	var path: NodePath = stored if stored is NodePath else NodePath(str(stored))
	if path.is_empty():
		return EventSheetL10n.translate(empty_means) if not empty_means.is_empty() else EventSheetL10n.translate(NOTHING_PICKED)
	var found: Node = resolve(edited, path)
	if found != null:
		return str(found.name)
	return path.get_name(path.get_name_count() - 1) if path.get_name_count() > 0 else str(path)


## The path from the player to a node Godot's picker handed back. Its answer is a path from the scene
## root or from the tree root depending on where the picker was opened, so each is tried.
static func path_from_pick(edited: Object, picked: NodePath) -> NodePath:
	if not (edited is Node) or picked.is_empty():
		return NodePath()
	var node: Node = null
	var root: Node = EditorInterface.get_edited_scene_root() if ClassDB.class_exists("EditorInterface") else null
	if root != null:
		node = root.get_node_or_null(picked)
	if node == null and (edited as Node).is_inside_tree():
		node = (edited as Node).get_tree().root.get_node_or_null(picked)
	if node == null:
		node = (edited as Node).get_node_or_null(picked)
	return (edited as Node).get_path_to(node) if node != null else NodePath()


## The editor for one export of a card of your own: Godot's own editor for its type.
static func godot_field(drawer: Control, card: Dictionary, field: Dictionary, write: Callable, _index: int) -> Control:
	return load("res://addons/eventsheet/editor/inspector/juice_own_cards.gd").call("field", drawer, card, field, write)


## A node field: the picked node's name in a read-only box, Godot's own node picker behind a Pick button,
## and a clear button. The quiet amber line under it says when the stored path finds no node.
static func node_field(drawer: Control, card: Dictionary, field: Dictionary, write: Callable, index: int) -> Control:
	var key: String = str(field.get("key", ""))
	var edited: Object = drawer.call("edited_object")
	var box: VBoxContainer = VBoxContainer.new()
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	var shown: LineEdit = LineEdit.new()
	shown.editable = false
	shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shown.text = node_words(edited, card, key, str(field.get("empty", "")))
	shown.tooltip_text = str(card.get(key, ""))
	line.add_child(shown)
	var finding: Label = EventSheetLookStyle.message_line(missing_note(edited, card, key), EventSheetLookStyle.Tone.WARNING)
	finding.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	finding.visible = not finding.text.is_empty()
	var pick: Button = Button.new()
	pick.text = EventSheetL10n.translate("Pick")
	pick.tooltip_text = EventSheetL10n.translate("Pick a node with Godot's own node picker.")
	pick.disabled = not bool(drawer.get("editable")) or not (edited is Node)
	var types: Array[StringName] = []
	for type_name: Variant in field.get("types", []):
		types.append(StringName(str(type_name)))
	pick.pressed.connect(func() -> void:
		if not ClassDB.class_exists("EditorInterface"):
			return
		var current: Node = resolve(edited, card.get(key))
		EditorInterface.popup_node_selector(func(chosen: NodePath) -> void:
			var relative: NodePath = path_from_pick(edited, chosen)
			if relative.is_empty() and not chosen.is_empty():
				return
			var picked: Node = resolve(edited, relative)
			write.call(relative)
			var extra: Variant = field.get("also")
			if extra is Callable and picked != null:
				var more: Variant = (extra as Callable).call(card, picked)
				if more is Dictionary:
					for more_key: Variant in more:
						drawer.call("write_card_key", index, str(more_key), more[more_key])
			shown.text = node_words(edited, {key: relative}, key, str(field.get("empty", "")))
			shown.tooltip_text = str(relative)
			finding.text = missing_note(edited, {key: relative}, key)
			finding.visible = not finding.text.is_empty()
			drawer.call("rebuild_soon"), types, current))
	line.add_child(pick)
	var clear: Button = EventSheetLookStyle.icon_button(&"Remove", "✕", EventSheetL10n.translate("Clear the node."))
	clear.disabled = not bool(drawer.get("editable")) or str(card.get(key, "")).is_empty()
	clear.pressed.connect(func() -> void:
		drawer.call("erase_card_key", index, key)
		drawer.call("rebuild_soon"))
	line.add_child(clear)
	box.add_child(line)
	box.add_child(finding)
	return box


## A property field: the property's name in a read-only box and Godot's own property picker behind Pick.
## The property belongs to the node the card picked (or the object the player is under), under `node_key`.
static func property_field(drawer: Control, card: Dictionary, field: Dictionary, write: Callable, _index: int) -> Control:
	var key: String = str(field.get("key", ""))
	var edited: Object = drawer.call("edited_object")
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	var shown: LineEdit = LineEdit.new()
	shown.editable = false
	shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shown.text = str(card.get(key, ""))
	shown.placeholder_text = EventSheetL10n.translate(NOTHING_PICKED)
	line.add_child(shown)
	var pick: Button = Button.new()
	pick.text = EventSheetL10n.translate("Pick")
	pick.tooltip_text = EventSheetL10n.translate("Pick a property with Godot's own property picker.")
	var target: Node = target_of(edited, card, str(field.get("node_key", "node")))
	pick.disabled = not bool(drawer.get("editable")) or target == null
	pick.pressed.connect(func() -> void:
		if not ClassDB.class_exists("EditorInterface") or target == null:
			return
		EditorInterface.popup_property_selector(target, func(chosen: NodePath) -> void:
			var text: String = property_text(chosen)
			if text.is_empty():
				return
			shown.text = text
			write.call(text)
			drawer.call("rebuild_soon"), PackedInt32Array(), str(card.get(key, ""))))
	line.add_child(pick)
	return line


## The property Godot's picker handed back as the plain name a card stores: the picker answers a path that
## begins with a colon (":modulate"), and a tween reads "modulate".
static func property_text(chosen: NodePath) -> String:
	return str(chosen).trim_prefix(":")


## The sample value a typed field is shaped by, read from the property or the shader value it is for, or
## null when there is nothing to read.
static func sample_for(drawer: Control, card: Dictionary, field: Dictionary) -> Variant:
	var edited: Object = drawer.call("edited_object")
	var finder: Variant = field.get("sample")
	if finder is Callable:
		return (finder as Callable).call(card, edited)
	var target: Node = target_of(edited, card, str(field.get("node_key", "node")))
	var property: String = str(card.get(str(field.get("property_key", "effect")), ""))
	if target == null or property.is_empty():
		return null
	return target.get_indexed(NodePath(property))


## A value box that takes the shape of what it sets: a number, two or three numbers, a colour or a
## tick. A card keeps the value in its own type, so a colour stays a colour in the saved list.
static func typed_field(drawer: Control, card: Dictionary, field: Dictionary, write: Callable, _index: int) -> Control:
	var key: String = str(field.get("key", ""))
	var sample: Variant = sample_for(drawer, card, field)
	var stored: Variant = card.get(key, card.get(str(field.get("fallback_key", "")), sample))
	var editable: bool = bool(drawer.get("editable"))
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	# Until the property or shader value is picked there is no kind of value to draw a box for.
	if sample == null and str(card.get(str(field.get("property_key", "")), "x")).is_empty():
		var waiting: LineEdit = LineEdit.new()
		waiting.editable = false
		waiting.placeholder_text = EventSheetL10n.translate("Pick a property first")
		waiting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(waiting)
		return line
	if sample == null:
		sample = stored if stored != null else 0.0
	var shape: int = typeof(sample)
	match shape:
		TYPE_BOOL:
			var check: CheckBox = CheckBox.new()
			check.button_pressed = bool(stored)
			check.disabled = not editable
			check.toggled.connect(func(pressed: bool) -> void: write.call(pressed))
			line.add_child(check)
		TYPE_COLOR:
			var swatch: ColorPickerButton = ColorPickerButton.new()
			swatch.custom_minimum_size = Vector2(EventSheetPalette.scaled(60), 0.0)
			swatch.color = stored if stored is Color else Color.WHITE
			swatch.disabled = not editable
			swatch.color_changed.connect(func(picked: Color) -> void: write.call(picked))
			line.add_child(swatch)
		TYPE_VECTOR2, TYPE_VECTOR3:
			var parts: int = 2 if shape == TYPE_VECTOR2 else 3
			var held: Array = []
			for axis: int in range(parts):
				held.append(float((stored as Vector2)[axis]) if stored is Vector2 and axis < 2 else (float((stored as Vector3)[axis]) if stored is Vector3 else 0.0))
			for axis: int in range(parts):
				var box: SpinBox = _spin(float(held[axis]), editable)
				box.value_changed.connect(func(value: float) -> void:
					held[axis] = value
					write.call(Vector2(held[0], held[1]) if parts == 2 else Vector3(held[0], held[1], held[2])))
				line.add_child(box)
		_:
			var number: SpinBox = _spin(float(stored) if stored is float or stored is int else 0.0, editable)
			number.value_changed.connect(func(value: float) -> void: write.call(int(value) if shape == TYPE_INT else value))
			line.add_child(number)
	return line


## What a value of a kind starts as when the card has not been given one yet.
static func _blank_of(kind: int) -> Variant:
	match kind:
		TYPE_BOOL:
			return false
		TYPE_INT:
			return 0
		TYPE_FLOAT:
			return 0.0
	return ""


## Where a tween starts: where the property is now (the card stores nothing), or a value of its own, which
## the card stores under `from`. Choosing "where it is now" takes the key off the card again.
static func from_field(drawer: Control, card: Dictionary, field: Dictionary, write: Callable, index: int) -> Control:
	var key: String = str(field.get("key", "from"))
	var box: VBoxContainer = VBoxContainer.new()
	var choice: OptionButton = OptionButton.new()
	choice.add_item(EventSheetL10n.translate("Where it is now"))
	choice.add_item(EventSheetL10n.translate("A value"))
	choice.select(1 if card.has(key) else 0)
	choice.disabled = not bool(drawer.get("editable"))
	box.add_child(choice)
	if card.has(key):
		box.add_child(typed_field(drawer, card, field, write, index))
	choice.item_selected.connect(func(chosen: int) -> void:
		if chosen == 0:
			drawer.call("erase_card_key", index, key)
		else:
			var sample: Variant = sample_for(drawer, card, field)
			drawer.call("write_card_key", index, key, sample if sample != null else 0.0)
		drawer.call("rebuild_soon"))
	return box


static func _spin(value: float, editable: bool) -> SpinBox:
	var box: SpinBox = SpinBox.new()
	box.step = 0.001
	box.allow_greater = true
	box.allow_lesser = true
	box.min_value = -1000000.0
	box.max_value = 1000000.0
	box.value = value
	box.editable = editable
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


## A choice among names read from the node the card picked: the animations of a player, the values of a
## shader, the signals and methods of a script. The names are looked up when the card is drawn, so a name
## added to the node later is on the list the next time the card is opened. A stored name the node no
## longer has is still shown, and said to be missing, so it is never dropped without being seen.
static func choices_field(drawer: Control, card: Dictionary, field: Dictionary, write: Callable, index: int) -> Control:
	var key: String = str(field.get("key", ""))
	var edited: Object = drawer.call("edited_object")
	var names: PackedStringArray = PackedStringArray()
	var lister: Variant = field.get("choices")
	if lister is Callable:
		var listed: Variant = (lister as Callable).call(card, edited)
		if listed is Array or listed is PackedStringArray:
			for entry: Variant in listed:
				names.append(str(entry))
	var current: String = str(card.get(key, ""))
	var choice: OptionButton = OptionButton.new()
	var values: PackedStringArray = PackedStringArray([""])
	choice.add_item(EventSheetL10n.translate(str(field.get("empty", NOTHING_PICKED))))
	for named: String in names:
		values.append(named)
		choice.add_item(named)
	var picked: int = values.find(current) if not current.is_empty() else 0
	if picked < 0:
		values.append(current)
		choice.add_item(EventSheetL10n.translate("%s (not there any more)") % current)
		picked = values.size() - 1
	choice.select(picked)
	choice.disabled = not bool(drawer.get("editable"))
	choice.item_selected.connect(func(chosen: int) -> void:
		if chosen <= 0 or chosen >= values.size():
			drawer.call("erase_card_key", index, key)
			return
		write.call(values[chosen])
		var extra: Variant = field.get("also")
		if extra is Callable:
			var more: Variant = (extra as Callable).call(card, edited, values[chosen])
			if more is Dictionary:
				for more_key: Variant in more:
					drawer.call("write_card_key", index, str(more_key), more[more_key])
			drawer.call("rebuild_soon"))
	return choice


## The values a signal or a method of the picked node takes, one box for each, in the order it declares
## them. Only a signal or method the node's own script declares is offered, so an engine signal is never
## fired by hand. A value is a number, a whole number, a tick or a word; any other kind is left out and
## the card says so.
static func arguments_field(drawer: Control, card: Dictionary, field: Dictionary, _write: Callable, index: int) -> Control:
	var edited: Object = drawer.call("edited_object")
	var box: VBoxContainer = VBoxContainer.new()
	var wanted: Array = (field.get("arguments") as Callable).call(card, edited) if field.get("arguments") is Callable else []
	var held: Array = (card.get("args", []) as Array).duplicate() if card.get("args", []) is Array else []
	for position: int in range(wanted.size()):
		var argument: Dictionary = wanted[position] as Dictionary
		var title: Label = Label.new()
		title.text = str(argument.get("name", ""))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		title.custom_minimum_size = Vector2(EventSheetPalette.scaled(120), 0.0)
		title.modulate = Color(1.0, 1.0, 1.0, 0.75)
		row.add_child(title)
		var kind: int = int(argument.get("type", TYPE_NIL))
		while held.size() <= position:
			held.append(_blank_of(kind))
		var editable: bool = bool(drawer.get("editable"))
		var save: Callable = func(value: Variant) -> void:
			held[position] = value
			drawer.call("write_card_key", index, "args", held.duplicate())
		match kind:
			TYPE_BOOL:
				var check: CheckBox = CheckBox.new()
				check.button_pressed = bool(held[position])
				check.disabled = not editable
				check.toggled.connect(func(pressed: bool) -> void: save.call(pressed))
				row.add_child(check)
			TYPE_STRING, TYPE_STRING_NAME:
				var text: LineEdit = LineEdit.new()
				text.text = str(held[position])
				text.editable = editable
				text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				text.text_changed.connect(func(typed: String) -> void: save.call(typed))
				row.add_child(text)
			TYPE_INT, TYPE_FLOAT:
				var number: SpinBox = _spin(float(held[position]), editable)
				number.value_changed.connect(func(value: float) -> void: save.call(int(value) if kind == TYPE_INT else value))
				row.add_child(number)
			_:
				var skipped: Label = EventSheetLookStyle.message_line(EventSheetL10n.translate("This kind of value cannot be set from a card."), EventSheetLookStyle.Tone.NOTE)
				row.add_child(skipped)
		box.add_child(row)
	return box


## A number a card may leave alone: an empty box that says what leaving it alone means ("From where it is"), and
## a number once one is typed. Clearing the box takes the key off the card again, so a card nobody touched stores
## nothing and plays as it always did.
static func optional_field(drawer: Control, card: Dictionary, field: Dictionary, write: Callable, index: int) -> Control:
	var key: String = str(field.get("key", ""))
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = EventSheetL10n.translate(str(field.get("empty", "")))
	edit.editable = bool(drawer.get("editable"))
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if card.has(key):
		edit.text = str(snappedf(float(card[key]), 0.001)).trim_suffix(".0")
	edit.text_changed.connect(func(text: String) -> void:
		if text.strip_edges().is_empty():
			drawer.call("erase_card_key", index, key)
		elif text.is_valid_float():
			write.call(text.to_float()))
	return edit


## A colour a card may leave alone: a flat button that says what leaving it alone means until it is pressed, then a
## colour box (starting from the colour the thing has now) and a button that puts it back to leaving it alone.
static func optional_color_field(drawer: Control, card: Dictionary, field: Dictionary, write: Callable, index: int) -> Control:
	var key: String = str(field.get("key", ""))
	var editable: bool = bool(drawer.get("editable"))
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	if not card.has(key):
		var start: Button = Button.new()
		start.text = EventSheetL10n.translate(str(field.get("empty", "")))
		start.flat = true
		start.alignment = HORIZONTAL_ALIGNMENT_LEFT
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		start.disabled = not editable
		start.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
		start.pressed.connect(func() -> void:
			var finder: Variant = field.get("sample")
			var sample: Variant = (finder as Callable).call(card, drawer.call("edited_object")) if finder is Callable else Color.WHITE
			write.call(sample if sample is Color else Color.WHITE)
			drawer.call("rebuild_soon"))
		line.add_child(start)
		return line
	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.edit_alpha = true
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stored: Variant = card[key]
	picker.color = stored if stored is Color else Color(str(stored))
	picker.disabled = not editable
	picker.color_changed.connect(func(picked: Color) -> void: write.call(picked))
	line.add_child(picker)
	var clear: Button = EventSheetLookStyle.icon_button(&"Remove", "✕", EventSheetL10n.translate(str(field.get("empty", ""))))
	clear.disabled = not editable
	clear.pressed.connect(func() -> void:
		drawer.call("erase_card_key", index, key)
		drawer.call("rebuild_soon"))
	line.add_child(clear)
	return line


## A collision layer picked from the project's thirty-two, each read as its number and the name Project Settings gives it.
## A layer nobody named is its number. The card keeps the number.
static func layer_pick_field(drawer: Control, card: Dictionary, field: Dictionary, write: Callable, _index: int) -> Control:
	var key: String = str(field.get("key", ""))
	var kinds: Script = load("res://addons/eventsheet/editor/inspector/juice_scene_kinds.gd") as Script
	var words: PackedStringArray = kinds.call("layer_choices", str(kinds.call("layer_space", card, drawer.call("edited_object"))))
	var choice: OptionButton = OptionButton.new()
	for word: String in words:
		choice.add_item(word)
	choice.select(clampi(int(card.get(key, 1)), 1, 32) - 1)
	choice.disabled = not bool(drawer.get("editable"))
	choice.item_selected.connect(func(chosen: int) -> void: write.call(chosen + 1))
	return choice
