@tool
class_name EventSheetParamFieldFactory
extends RefCounted

# The ONE door to "give me the right editor for this parameter".
#
# The per-hint widgets - the colour swatch, the enum dropdown, the node picker, the Input Map
# picker, the physics-layer mask, the key capture, the animation and audio and scene pickers, the
# ƒx expression field - were reachable from exactly one place: the Edit Parameter dialog. So the
# Properties bar, which shows the very same parameters of the very same row, had one untyped
# LineEdit for all of them, and editing a colour there meant typing `Color("#ff9b3c")` by hand.
#
# This is the shared door both now use. It is deliberately a DOOR and not a second implementation:
# the builders stay where they are (`ace_params_dialog.gd`), because there are forty of them, they
# reach each other, and two copies of a widget set is exactly how a colour picker in one place and a
# colour picker in another come to disagree. What the factory owns is the part that made them
# unreachable - a dialog-free host to build them in, and one way to read a built widget's value
# back out.
#
# WHAT A CALLER GETS BACK: `build()` returns {control, field}. They are usually the same node, but
# several builders wrap their value-bearing widget in a row (a LineEdit beside a 🌐 toggle, a path
# field beside a Browse button, three axis fields in a box). `control` is what you add to your
# layout; `field` is what you read with `value_of()` and connect a change signal on. Mixing them up
# is the one mistake this shape is designed to make impossible.
#
# WHY THERE IS NO OK BUTTON HERE: the dialog commits every field at once when OK is pressed; a bar
# commits one field the moment it changes. So the factory reports which SIGNAL a built widget
# changes on (`change_signal_of`) rather than deciding when a value is worth keeping.

## The dialog instance the widgets are built in. Never shown: `init_dialog` is not called, so it owns
## no window, and every builder that would reach for one is already null-guarded (a plain field just
## does not get its Enter-presses-OK binding, which is right - there is no OK).
var _builder: ACEParamsDialog = ACEParamsDialog.new()


## Points the factory at the same registry and sheet context the Edit Parameter dialog uses, so the
## enum lists, the ƒx validation and the variable dropdowns say the same things in both places.
func init(dock: Control) -> void:
	if dock == null:
		return
	_builder.set_registry(dock._ace_registry)
	_builder.set_lint_context_provider(func() -> EventSheetResource: return dock._current_sheet)
	# The variable dropdowns read the sheet's own variables through the same provider the dialog uses,
	# so a `variable_reference` parameter offers the same names in the bar as in the dialog.
	_builder._variable_names_provider = dock._collect_sheet_variable_names


## The editor for one parameter. `descriptor` is the shipped parameter dictionary (id, type, hint,
## options, autocomplete, default_value); `value` is what the row currently holds.
##
## Returns {control, field}. A hint this build does not know still returns a plain text field, so a
## caller never has to check whether a parameter is "supported" - every parameter is.
func build(descriptor: Dictionary, value: String) -> Dictionary:
	var param_id: String = str(descriptor.get("id", ""))
	if param_id.is_empty():
		return {}
	# The builders register the value-bearing node in `_fields` under this key, which is how a wrapped
	# widget is told apart from its wrapper. Cleared per call so one caller's field is never another's.
	_builder._fields.erase(param_id)
	# Refreshed per build rather than once: a variable added since the last field was made must be in
	# the next dropdown, and there is no OK here to hang a refresh off.
	_builder._variable_names = _builder._resolve_variable_names()
	var hint: String = str(descriptor.get("hint", ""))
	var control: Control = _builder._create_field(descriptor, {param_id: value}, param_id, hint)
	var field: Control = _builder._fields.get(param_id) as Control
	return {"control": control, "field": field if field != null else control}


## The GDScript the built widget currently names - the same conversion the dialog commits with, so a
## colour picked in the Properties bar ships as the literal the dialog would have written.
func value_of(field: Control) -> String:
	if field == null:
		return ""
	return str(_builder._extract_value(field))


## Which signal on a built widget means "the user changed this", and "" for the widgets that have no
## such moment (a container, an unknown control). A bar connects to this; the dialog does not need it
## because OK is its moment.
##
## Deliberately a small table rather than a guess: connecting to the wrong signal is how a field
## silently stops saving, and the widget kinds are exactly the ones `_extract_value` reads.
static func change_signal_of(field: Control) -> String:
	if field is CheckBox:
		return "toggled"
	if field is ColorPickerButton:
		return "color_changed"
	if field is OptionButton:
		return "item_selected"
	if field is SpinBox:
		return "value_changed"
	if field is LineEdit:
		return "text_submitted"
	if field is CodeEdit or field is TextEdit:
		return "focus_exited"
	# A physics-layer mask (a MenuButton) commits through its own popup's checkboxes, with no single
	# "changed" moment on the button itself. Rather than guess at one and have the field silently stop
	# saving, it stays a job for the Edit Parameter dialog and says so by naming no signal.
	return ""


# ── What the help strip says about a parameter ───────────────────────────────────────────────
#
# The Parameters dialog used to print each parameter's description under its field in 11px and hang
# the same string off the field as a tooltip. Four parameters therefore read as four paragraphs, and
# the paragraph never said what the FIELD wanted - only what the parameter was for. The strip at the
# foot says both, for the focused parameter only: the parameter's own description first, then what
# this KIND of field takes, which is a fact about the hint and belongs beside the widget the hint
# builds. One table, one place to translate, and a pack that ships a new hint can be described by
# adding one row rather than by teaching the dialog about it.


## The paragraph each hint contributes. A "%s" is filled with the owner of the row being edited
## (the object whose variables are in scope), so the sentence names something the reader can see.
## A hint that is not here contributes nothing and the strip shows the description alone.
const HINT_PARAGRAPHS: Dictionary = {
	"expression": "A number, a variable, or an expression. In scope are the event's trigger parameters, %s's variables and the globals - the fx button lists them all, and the arrow holds what you typed here before.",
	"variable_reference": "One of %s's variables. The list shows each one's type and, while the game runs, its value.",
	"color": "A colour word (red), a hex (#ff4d4d) or Color(1, 0.3, 0.3). The swatch opens the palette with your saved colours; the row shows the word and the swatch.",
	"key_capture": "Press the key you want while this box is focused. Prefer an Input Map action when the player may rebind it.",
	"input_action": "An action from the project's Input Map, with the keys bound to it beside each name. New action adds one the map does not have yet.",
	"group_reference": "A node group, with how many nodes of the open scene are in each. Any node joins a group from the Node dock.",
	"mode_reference": "One of the game's declared modes. They are declared once, on the modes band of the Game sheet's head - a mode that is not in this list has not been declared yet.",
	"scene_node": "A node in the open scene - drag it in from the Scene dock or pick it from the list; the code uses its path.",
	"scene_path": "A scene file from the project. Browse opens the file picker; the code loads the path.",
	"audio_path": "A sound file from the project. The play button previews it without leaving the dialog.",
	"animation_reference": "An animation the attached scene really has, listed with how long it runs (or that it loops) and which node declares it. A name the scene has never heard of goes amber with the nearest one offered: a misspelled animation plays nothing and reports nothing. A name built while the game runs is still typeable.",
	"marker_reference": "A named moment on that animation's timeline - what a keyframed clip has instead of frames. Retiming it in the Animation panel moves the moment and this row does not change.",
	"animation_frame": "The frame number, counted the way Godot counts them: from 0. The strip under the box is the animation itself, one cell per frame - click the cell where the moment happens instead of counting in another window, hover one to see it large, or type the number if you already know it.",
	"property_reference": "A property of the object this row acts on, by name.",
	"method_reference": "A method of the object this row acts on, by name. It is called with no arguments unless the row says otherwise.",
	"signal_reference": "A signal of the object this row acts on, by name.",
	"angle": "Degrees, measured from pointing right and turning clockwise - a quarter turn is 90. There is no unit to choose: a plain number is degrees. Radians are not locked out either - write PI/4, or say the unit out loud (1.2 rad), and the field keeps what you meant and converts it once. The row always shows which unit it ended up meaning.",
	"bbcode_text": "Text with the engine's own markup - the buttons wrap the selection, and the preview under the box is what the label will show.",
	"physics_layer_2d": "The 2D physics layers this row looks at, by their project names. Tick as many as apply.",
	"physics_layer_3d": "The 3D physics layers this row looks at, by their project names. Tick as many as apply.",
	"render_layer_2d": "The visibility layers that may see this node, by their project names (Project Settings > Layer Names > 2D Render). A camera draws what its own cull mask and this share, so a marker ticked for the minimap layer alone is drawn by the minimap camera and by nothing else.",
	"quality_preset": "A quality preset file from res://settings/quality/ - the folder IS the list, so adding a preset is adding a file. New preset copies the picked one and opens it in the Inspector. The word is a shorthand for values over settings you already declared; nudging one of them afterwards changes that setting and the quality label reads Custom on its own.",
	"feature_tag": "A build feature tag - the engine's own set plus every tag your export presets declare. host and client are tags you add to two presets yourself; dedicated_server comes from Godot's own server preset, whose build is run with --headless.",
	# The four networking fields, answering what a reader would otherwise go and look up: which
	# ports are free, why 127.0.0.1 only reaches this machine, what a player costs the host, and which
	# peer kind a browser can open. They live here rather than in the descriptors so a pack that ships
	# a hosting row of its own gets the same words for free.
	"net_address": "Play as host + client puts both instances on this machine, which is what 127.0.0.1 is for. Across the internet the host has to forward its port on the router, or both sides go through a relay. A field or a variable works here as well as a literal - the player usually types it.",
	"net_port": "7000 to 65535 are free for games; anything below 1024 needs admin rights on most systems. Over the internet the host forwards this one port on its router, which is the step people miss.",
	"peer_kind": "How the game talks over the network, and both sides have to pick the same one. ENet is Godot's own default; a browser export can only open WebSocket; WebRTC goes browser to browser through a signalling server you run.",
	"max_players": "Every connected player costs the host bandwidth on every tick, for every value it keeps in step, so this number is a budget as much as a limit.",
	# The one networking field that edits the SCENE as well as the row, so it says what pressing
	# OK is about to do while the field still has focus.
	"spawn_scene": "A scene the spawner is allowed to make. The list is the spawner's own, from the Inspector; a scene that is not in it yet is added when you press OK, as one step of the scene's undo. A spawner only copies scenes it lists - one it does not know is made here and nowhere else.",
	"editor_icon": "The name of an icon in the editor's own set; the picture beside the field is what it draws.",
	"editor_preference": "An editor setting, by its full path. These are the editor's own preferences, not the project's.",
	"project_setting": "A project setting, by its full path, as Project Settings spells it.",
	"minutes_seconds": "A length of time. Type it as minutes:seconds - 3:00 - or as plain seconds; the row ships the seconds.",
	"palette": "A palette asset from the project, and which set of colours inside it this row uses.",
	"input_prompt_show": "Optional. With the tick on, the control's key is written onto the named label for as long as the window is open.",
	"input_prompt_clear": "Optional. With the tick on, the prompt comes off the named label as the window shuts.",
	"shader_dial": "A uniform declared by the shader this node's material runs, by name. The picker fills it in from the shader file, so a name that is not in that file cannot reach the game - which matters here more than anywhere: Godot accepts a misspelled dial name without a word and then does nothing with it, forever.",
	"shader_dial_value": "What the dial is set to, in the editor its own declaration asks for: a range makes a slider, source_color a colour, a sampler a texture file, a whole number a stepper. The same hints Godot's Inspector obeys, read from the same shader file - and a dial nothing can be derived for takes an ordinary value or expression.",
}

## The phrase a heading ends with, per hint: "Colour - a colour". Only for the hints whose kind is
## not already obvious from the parameter's declared type.
const HINT_TYPE_PHRASES: Dictionary = {
	"color": "a colour",
	"expression": "a value",
	"variable_reference": "a variable",
	"input_action": "an input action",
	"group_reference": "a node group",
	"mode_reference": "a mode",
	"scene_node": "a node",
	"scene_path": "a scene",
	"spawn_scene": "a scene",
	"audio_path": "a sound",
	"angle": "degrees",
	"key_capture": "a key",
	"minutes_seconds": "a length of time",
	"bbcode_text": "text with markup",
	"net_address": "text",
	"net_port": "a number",
	"max_players": "a number",
	"shader_dial": "a shader dial",
	"render_layer_2d": "visibility layers",
	"quality_preset": "a quality preset",
}

## The phrase for a parameter that leans on its declared GDScript type instead of a hint.
const TYPE_PHRASES: Dictionary = {
	"int": "a whole number",
	"integer": "a whole number",
	"float": "a number",
	"double": "a number",
	"bool": "true or false",
	"boolean": "true or false",
	"String": "text",
	"string": "text",
	"Color": "a colour",
	"Vector2": "a point",
	"Vector3": "a point",
}


## The paragraph the strip shows under a parameter's own description. `owner` is the object whose
## variables are in scope - the sentence names it rather than saying "the object".
static func hint_paragraph(hint: String, owner: String = "") -> String:
	var key: String = hint.get_slice(":", 0) if hint.contains(":") else hint
	# A pack that ships a hint of its own describes it through EventSheets.register_param_help, and
	# its wording wins - it knows what its field takes and this table cannot.
	var text: String = EventSheets.param_help_for(key)
	if text.is_empty():
		text = str(HINT_PARAGRAPHS.get(key, ""))
	if text.is_empty():
		return ""
	text = EventSheetL10n.translate(text)
	if not text.contains("%s"):
		return text
	var named: String = owner.strip_edges()
	return text % (named if not named.is_empty() else EventSheetL10n.translate("this object"))


## What KIND of value a parameter takes, in the two or three words a heading ends with. The hint
## answers first (a colour is a colour whatever its declared type), the declared type second.
static func type_phrase(param: Dictionary) -> String:
	var hint: String = str(param.get("hint", ""))
	var key: String = hint.get_slice(":", 0) if hint.contains(":") else hint
	if HINT_TYPE_PHRASES.has(key):
		return EventSheetL10n.translate(str(HINT_TYPE_PHRASES[key]))
	if not param.get("options", []).is_empty():
		return EventSheetL10n.translate("one of a list")
	var type_name: String = str(param.get("type_name", ""))
	if TYPE_PHRASES.has(type_name):
		return EventSheetL10n.translate(str(TYPE_PHRASES[type_name]))
	return EventSheetL10n.translate("a value")


## The strip's heading for a parameter: its name, then what it takes ("Amount - a number"). `tail`
## replaces the kind when something is wrong with the value ("Variable - not found").
static func strip_heading(param: Dictionary, tail: String = "") -> String:
	var name_text: String = str(param.get("display_name", param.get("id", "")))
	var ending: String = tail if not tail.strip_edges().is_empty() else type_phrase(param)
	return name_text if ending.is_empty() else "%s - %s" % [name_text, ending]


## The strip's paragraph: the parameter's own description (the string that used to sit under the
## field in 11px), then what this kind of field takes. Either half alone still reads.
static func strip_body(param: Dictionary, owner: String = "") -> String:
	var description: String = str(param.get("description", "")).strip_edges()
	var paragraph: String = hint_paragraph(str(param.get("hint", "")), owner)
	if description.is_empty():
		return paragraph
	if paragraph.is_empty():
		return description
	return "%s  %s" % [description, paragraph]


# ── The second line under a choice ───────────────────────────────────────────────────────────
#
# A dropdown shows the value and nothing else, so "active" and "inactive" teach nobody what they do
# and an Input Map action is a name with no key beside it. Each of these reads the hint's OWN source
# for the line under a choice - the Input Map for an action, the open scene for a node group, the
# option's declared note for a list a pack shipped. A choice with no line renders as it always did.


## The keys bound to an Input Map action, as the line under its name: "Space - Gamepad A". "" for an
## action the map does not have (a name typed by hand, or one added in another project).
static func input_action_note(action_value: String) -> String:
	var action_name: String = _unquoted(action_value)
	if action_name.is_empty() or not InputMap.has_action(action_name):
		return ""
	var bindings: PackedStringArray = PackedStringArray()
	for event: InputEvent in InputMap.action_get_events(StringName(action_name)):
		var text: String = event.as_text().strip_edges()
		if not text.is_empty() and not bindings.has(text):
			bindings.append(text)
	if bindings.is_empty():
		return EventSheetL10n.translate("not bound to anything yet")
	return " - ".join(bindings)


## How many nodes of the open scene are in a group, as the line under its name. A group nothing is in
## is not an error - the nodes may be added at runtime - so the line says that rather than warning.
static func node_group_note(group_value: String, scene_root: Node) -> String:
	var group_name: String = _unquoted(group_value)
	if group_name.is_empty():
		return ""
	var count: int = 0
	var pending: Array[Node] = []
	if scene_root != null:
		pending.append(scene_root)
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node.is_in_group(StringName(group_name)):
			count += 1
		for child: Node in node.get_children():
			pending.append(child)
	if count == 0:
		return EventSheetL10n.translate("none yet - added at runtime?")
	if count == 1:
		return EventSheetL10n.translate("1 node in this scene")
	return EventSheetL10n.translate("%d nodes in this scene") % count


## The line under a variable in a variable list: its type in plain words, its value, and - while the
## game runs - what it holds right now. The same chip the sheet's own rows lead with.
static func variable_option_note(entry: Dictionary, live_value: String = "") -> String:
	if entry.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	var type_word: String = str(entry.get("type_word", "")).strip_edges()
	if not type_word.is_empty():
		parts.append(type_word)
	var value_text: String = str(entry.get("value", "")).strip_edges()
	if not value_text.is_empty():
		parts.append(value_text)
	var live: String = live_value.strip_edges()
	if not live.is_empty():
		parts.append(EventSheetL10n.translate("%s now") % live)
	return " - ".join(parts)


## The line under each choice of an OPTIONS dropdown, as {option key -> line}. Two sources, both
## already in the descriptor: a note the option itself declares, and - for a list that opted into
## label display - the plain words a true/false pair stands for. A list with neither comes back
## empty and its dropdown is built exactly as it always was.
static func option_notes(param: Dictionary) -> Dictionary:
	var notes: Dictionary = {}
	var labelled: bool = bool(param.get("display_option_labels", false))
	for option: Variant in param.get("options", []):
		if not (option is Dictionary):
			continue
		var entry: Dictionary = option
		var key: String = str(entry.get("key", ""))
		if key.is_empty():
			continue
		var note: String = str(entry.get("note", "")).strip_edges()
		if note.is_empty() and labelled:
			note = _boolean_note(key, str(entry.get("label", key)))
		if not note.is_empty():
			notes[key] = EventSheetL10n.translate(note)
	return notes


## A true/false choice said in plain words rather than as the token it emits. "" for a key that is
## not a boolean, which is every other list.
static func _boolean_note(option_key: String, label: String) -> String:
	match option_key.strip_edges():
		"true":
			return "" if label == "true" else "true"
		"false":
			return "" if label == "false" else "false"
	return ""


## A value written as a GDScript string literal, with its quotes taken off. Values reach the dialog
## both ways (the Input Map hint stores `"jump"`, a hand-typed one may not), and the source being
## asked wants the bare name.
static func _unquoted(value: String) -> String:
	var text: String = value.strip_edges()
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	return text


# ── What is wrong with the value as typed ────────────────────────────────────────────────────
#
# A required field left empty, a name that is not a variable, text where a number goes: these used
# to surface when OK was pressed, or later as a note on the row. The checks are the same ones; they
# run here at keystroke time on the dialog's own values, and they answer in the words the row's own
# notes use, so the dialog and the row never disagree about what is wrong.


## It compiles, but it will surprise: a literal of the wrong kind for what the verb takes.
const LEVEL_WARNING := "warning"
## It cannot be meant: a name that is not a variable, a required field left blank.
const LEVEL_ERROR := "error"


## What is wrong with `value` in `param`, or {} when nothing is - {} IS "nothing is wrong", which is
## why there is no third level for it. Keys: level, heading, body, reason
## (the short line that sits beside OK) and fixes ([{kind, name}] - "use" swaps in the nearest name,
## "add" offers to declare the one that was typed).
##
## `entries` is the variable catalog the row can see and `owner` the object that owns them; `takes`
## is the kind of value the VERB needs ("number" / "boolean" / ""), which a parameter's declared
## type cannot say for itself - every expression parameter declares String.
static func validate(param: Dictionary, value: String, entries: Array[Dictionary],
		owner: String, takes: String = "") -> Dictionary:
	var text: String = value.strip_edges()
	var name_text: String = str(param.get("display_name", param.get("id", "")))
	if text.is_empty() and _is_required(param):
		return {
			"level": LEVEL_ERROR,
			"heading": strip_heading(param, EventSheetL10n.translate("needed")),
			"body": EventSheetL10n.translate("%s cannot be left blank - the row has nothing to write.") % name_text,
			"reason": EventSheetL10n.translate("%s is empty") % name_text,
			"fixes": [],
		}
	if _asks_for_a_variable(param) and text.is_valid_identifier() and not entries.is_empty():
		var unknown: Dictionary = EventSheetVariableOwners.unknown_note(entries, text, owner)
		if not unknown.is_empty():
			var fixes: Array = []
			var suggestion: String = str(unknown.get("suggestion", ""))
			if not suggestion.is_empty():
				fixes.append({"kind": "use", "name": suggestion})
			fixes.append({"kind": "add", "name": text})
			return {
				"level": LEVEL_ERROR,
				"heading": strip_heading(param, EventSheetL10n.translate("not found")),
				"body": str(unknown.get("note", "")),
				"reason": EventSheetL10n.translate("fix %s first") % name_text,
				"fixes": fixes,
			}
	var mismatch: Dictionary = _literal_mismatch(param, text, takes, name_text)
	return mismatch


## The amber case: the value is a LITERAL and the verb wants a different kind of one. Only a literal
## is judged - an expression or a variable name is not something this can be sure about, and an
## amber warning that fires on every ordinary value teaches the reader to ignore it.
static func _literal_mismatch(param: Dictionary, text: String, takes: String, name_text: String) -> Dictionary:
	var wanted: String = takes.strip_edges()
	if wanted.is_empty():
		wanted = _wanted_from_type(str(param.get("type_name", "")), str(param.get("hint", "")))
	if wanted.is_empty():
		return {}
	var got: String = literal_kind(text)
	if got.is_empty() or got == wanted:
		return {}
	var body: String = EventSheetL10n.translate("%s is %s. This needs %s.") % [
		text, _kind_word(got), _kind_word(wanted)]
	var alternative: String = EventSheetL10n.translate("If you meant to join text, Set value can.")
	if wanted == "number" and got == "text":
		body += " " + alternative
	return {
		"level": LEVEL_WARNING,
		"heading": strip_heading(param, EventSheetL10n.translate("wants %s") % _kind_word(wanted)),
		"body": body,
		"reason": EventSheetL10n.translate("%s may not fit") % name_text,
		"fixes": [],
	}


## The kind of literal a value IS - "number", "text", "boolean" - or "" when it is not a literal at
## all (a variable name, an expression, a call). Static and pure, so the row's own note and this
## dialog judge a value the same way.
static func literal_kind(text: String) -> String:
	var literal: String = text.strip_edges()
	if literal.is_empty():
		return ""
	if literal == "true" or literal == "false":
		return "boolean"
	if literal.is_valid_float() or literal.is_valid_int():
		return "number"
	if literal.length() >= 2 and literal.begins_with("\"") and literal.ends_with("\""):
		return "text"
	return ""


## The kind a parameter wants when the VERB does not say. Only settled types answer - an expression
## parameter declares String and means "anything", so it answers with nothing.
static func _wanted_from_type(type_name: String, hint: String) -> String:
	if hint == "expression" or hint.begins_with("variable_reference"):
		return ""
	match type_name.strip_edges():
		"int", "integer", "float", "double":
			return "number"
		"bool", "boolean":
			return "boolean"
	return ""


## A kind said the way a sentence says it.
static func _kind_word(kind: String) -> String:
	match kind:
		"number":
			return EventSheetL10n.translate("a number")
		"text":
			return EventSheetL10n.translate("text")
		"boolean":
			return EventSheetL10n.translate("true or false")
	return kind


## True when a blank is not an answer: the descriptor said so, or the parameter names a variable
## (there is no such thing as "no variable" for a row that changes one).
static func _is_required(param: Dictionary) -> bool:
	return bool(param.get("required", false)) or _asks_for_a_variable(param)


## True when the parameter's value is meant to BE a variable name - the only place a bare identifier
## is checked against the catalog, because everywhere else a bare word is legitimately a local or a
## member this dialog cannot see.
static func _asks_for_a_variable(param: Dictionary) -> bool:
	return str(param.get("hint", "")).begins_with("variable_reference")
