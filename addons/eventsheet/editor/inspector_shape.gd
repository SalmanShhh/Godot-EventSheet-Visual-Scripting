# Godot EventSheets - "Shape this field": the six kinds of choice the Inspector Designer offers for one
# exported variable, what each choice writes, and how a file is read back as the same choices.
#
#   Look        how the value is drawn and edited       the looks table (EventSheetInspectorLooks)
#   Layout      where the field sits                    its export group, side by side
#   Show when   when the field appears                  show_if / lock_unless (_validate_property)
#   Check       what a good value is                    clamp, required, validate
#   Help        words that explain the field            info (# @inspector_info)
#   Button      a button that runs a function           action (# @inspector_action)
#
# Nothing here is a new data model: every choice is a set of attribute keys the compiler already
# writes and the importer already lifts back, so a choice is ONE rewrite of the keys that choice owns -
# choosing the default removes them, and every other key (another tab's choice, the group, the
# description) is left exactly as it was. The only fact outside the attributes is @tool: Show when
# needs it, so the first such choice turns the sheet's Tool mode on and remembers, on the sheet, that
# it was the one that did; the last one taken back turns it off again. A sheet that was a tool sheet
# before keeps its @tool whatever is chosen.
#
# A field whose shape is code the reader wrote in a form this table does not write is read, never
# rewritten: reading() names those fields, and the Designer shows them as shaped by your own code.
#
# DELIBERATELY NO `class_name`: the Inspector Designer loads it by path when it first opens, so
# neither the editor's boot nor a sheet's first open compiles it.
@tool
extends RefCounted

## The kinds of choice, in the panel's order. Frozen: the doors open a tab by these ids.
const CATEGORIES: PackedStringArray = ["look", "layout", "show", "check", "help", "button"]
## Each kind's no-choice option: what a field that has never been shaped reads as.
const DEFAULTS: Dictionary = {"look": "default", "layout": "group", "show": "always", "check": "none",
	"help": "none", "button": "none"}

## The sheet meta that says THIS table turned the sheet's Tool mode on, so taking the last Show when
## back may turn it off again. It rides the sheet's snapshots and is never written to a file, so a
## sheet opened again later keeps its @tool: leaving a line is safer than taking one the reader wants.
const TOOL_META: StringName = &"__inspector_shape_tool"

## The looks that are a marker only this plugin reads; every other look is Godot's own annotation.
const MARKER_LOOKS: PackedStringArray = ["progress_bar", "unit", "toggle_row", "swatch_row", "vector_dial",
	"min_max", "corners", "texture_preview", "curve_editor", "table", "table_row"]
## Types a "Must be filled in" can watch: a number or a tick box is never empty.
const NEVER_EMPTY_TYPES: PackedStringArray = ["int", "float", "bool", "Color", "Vector2", "Vector2i",
	"Vector3", "Vector3i", "Vector4", "Vector4i"]

const GESTURES_PATH := "res://addons/eventsheet/editor/dock/variable_gestures.gd"

# The two spellings Godot users write to hide a field, and the one to lock it.
const HIDE_LINES: PackedStringArray = ["\t\tproperty.usage &= ~PROPERTY_USAGE_EDITOR", "\t\tproperty.usage = PROPERTY_USAGE_NO_EDITOR"]
const LOCK_LINE: String = "\t\tproperty.usage |= PROPERTY_USAGE_READ_ONLY"
const VALIDATE_HEADER: String = "func _validate_property(property: Dictionary) -> void:"


## A kind of choice's name on its tab.
static func category_name(category: String) -> String:
	match category:
		"look":
			return EventSheetL10n.translate("Look")
		"layout":
			return EventSheetL10n.translate("Layout")
		"show":
			return EventSheetL10n.translate("Show when")
		"check":
			return EventSheetL10n.translate("Check")
		"help":
			return EventSheetL10n.translate("Help")
	return EventSheetL10n.translate("Button")


## A kind of choice's hover: what the tab is about.
static func category_tip(category: String) -> String:
	match category:
		"look":
			return EventSheetL10n.translate("How the value is drawn and edited.")
		"layout":
			return EventSheetL10n.translate("Where the field sits.")
		"show":
			return EventSheetL10n.translate("When the field appears.")
		"check":
			return EventSheetL10n.translate("What a good value is.")
		"help":
			return EventSheetL10n.translate("Words that explain the field.")
	return EventSheetL10n.translate("A button that runs a function of the script.")


## The options of one kind that fit `field` (a Designer entry: name, type_name, attributes), in the
## order they are offered. `fields` is every exported entry of the sheet, for the tick boxes a Show
## when can follow. Each option is {id, label, tip, plain, reason, asks, ready}: `plain` is what the
## field is without this plugin, `reason` is why it cannot be chosen ("" when it can), `asks` is the
## details it takes, as the looks table spells them ([key, label, kind, default, hint]), and `ready`
## says whether it can be written at once on those details' defaults.
static func options(category: String, field: Dictionary, fields: Array = []) -> Array[Dictionary]:
	var type_name: String = str(field.get("type_name", ""))
	var var_name: String = str(field.get("name", ""))
	var attributes: Dictionary = field.get("attributes") if field.get("attributes") is Dictionary else {}
	var output: Array[Dictionary] = []
	var same: String = EventSheetL10n.translate("Exactly the same.")
	match category:
		"look":
			output.append(_option("default", EventSheetInspectorLooks.plain_label(type_name),
				EventSheetL10n.translate("The field Godot picks for the type. Nothing added."), EventSheetL10n.translate("Exactly the same field.")))
			for look: Dictionary in EventSheetInspectorLooks.for_type(type_name):
				var look_id: String = str(look.get("id"))
				var plain: String = EventSheetL10n.translate("Shows as a plain field, and the game runs the same: the marker is something only the plugin reads.") \
					if MARKER_LOOKS.has(look_id) else EventSheetL10n.translate("The same: this is Godot's own annotation, so it works with or without the plugin.")
				var option: Dictionary = _option(look_id, EventSheetInspectorLooks.label(look), EventSheetL10n.translate(str(look.get("tip", ""))), plain)
				option["asks"] = _translated(look.get("fields", []))
				option["ready"] = _stands_on_defaults(look_id, type_name)
				output.append(option)
			if type_name == "String":
				var listed: Dictionary = _option("function_choices", EventSheetL10n.translate("Pick from a list a function gives"),
					EventSheetL10n.translate("A dropdown filled by a function of the script, so the choices follow your data: attack names, level names, save slots."),
					EventSheetL10n.translate("A plain text field: the chosen word, as written."))
				listed["asks"] = [["choices_function", EventSheetL10n.translate("Function"), "text", "", "%s_choices" % var_name]]
				listed["ready"] = false
				output.append(listed)
			# Stay within limits keeps the value inside the look's own limits, so a look without limits
			# takes the check with it. The option says so rather than leave the Check tab to change quietly.
			if chosen("check", field) == "clamp":
				for option: Dictionary in output:
					if not apply("look", str(option["id"]), attributes, type_name).has("clamp"):
						option["tip"] = "%s %s" % [option["tip"], EventSheetL10n.translate("It also turns Stay within limits off on the Check tab: with no limits left, there is nothing to stay within.")]
		"layout":
			output.append(_option("group", EventSheetL10n.translate("In its group"),
				EventSheetL10n.translate("Under the heading of the group it is declared in, one field per line."), same))
			output.append(_option("side_by_side", EventSheetL10n.translate("Side by side with the next field"),
				EventSheetL10n.translate("Shares one line with the field declared after it, for pairs that belong together: min and max, x and y, width and height."),
				EventSheetL10n.translate("Two lines, one after the other."), _side_by_side_refusal(field, fields)))
		"show":
			output.append(_option("always", EventSheetL10n.translate("Always"), EventSheetL10n.translate("Always shown."), same))
			var hide_plain: String = EventSheetL10n.translate("The same: this is Godot's own way to hide a field, so it works with or without the plugin. The script becomes a @tool script so the Inspector can ask it.")
			var switches: PackedStringArray = PackedStringArray()
			for other: Variant in fields:
				if other is Dictionary and str((other as Dictionary).get("type_name", "")) == "bool" and str((other as Dictionary).get("name", "")) != var_name:
					switches.append(str((other as Dictionary).get("name")))
			for switch: String in switches:
				output.append(_option("show_if:" + switch, EventSheetL10n.translate("Only when %s is on") % switch,
					EventSheetL10n.translate("Hidden while %s is off, so only the fields that matter are on screen. The value is kept while hidden.") % switch, hide_plain))
			for switch: String in switches:
				output.append(_option("lock_unless:" + switch, EventSheetL10n.translate("Read-only when %s is off") % switch,
					EventSheetL10n.translate("Stays visible but greyed out while %s is off, for a value worth seeing but not changing.") % switch,
					EventSheetL10n.translate("The same: Godot's own read-only flag.")))
			if switches.is_empty():
				output.append(_option("show_if:", EventSheetL10n.translate("Only when a tick box is on"),
					EventSheetL10n.translate("Hidden while a tick box of the script is off."), hide_plain,
					EventSheetL10n.translate("Add an exported bool variable first: it is the tick box that shows or hides this field.")))
		"check":
			output.append(_option("none", EventSheetL10n.translate("No check"), EventSheetL10n.translate("Any value of the type is accepted."), same))
			if type_name == "int" or type_name == "float":
				var limits: Dictionary = _option("clamp", EventSheetL10n.translate("Stay within limits"),
					EventSheetL10n.translate("The field refuses values outside a lowest and highest number."),
					EventSheetL10n.translate("The same: Godot's own range, and the setter keeps the value inside it in the game too."))
				# With no limits yet the choice asks for them; with some (a slider, a bar) it keeps those.
				if not (attributes.get("range") is Dictionary):
					limits["asks"] = [["min", EventSheetL10n.translate("Min"), "number", "0", ""], ["max", EventSheetL10n.translate("Max"), "number", "100", ""]]
				output.append(limits)
			if not NEVER_EMPTY_TYPES.has(type_name):
				output.append(_option("required", EventSheetL10n.translate("Must be filled in"),
					EventSheetL10n.translate("An empty value shows a quiet amber note in the Inspector, and the Project Doctor lists every scene that leaves it empty."),
					EventSheetL10n.translate("A plain field; the Doctor still lists empty ones.")))
			var validate: Dictionary = _option("validate", EventSheetL10n.translate("Checked by a function"),
				EventSheetL10n.translate("A function of the script answers what is wrong, in its own words; an empty answer means all is well."),
				EventSheetL10n.translate("A plain field; the function is never called."))
			validate["asks"] = [["validate", EventSheetL10n.translate("Function"), "text", "check_" + var_name, "check_" + var_name]]
			output.append(validate)
		"help":
			output.append(_option("none", EventSheetL10n.translate("Hover text only"),
				EventSheetL10n.translate("The ## comment above the variable, shown when hovering its name, as Godot does."), same))
			var note: Dictionary = _option("info", EventSheetL10n.translate("A note above the field"),
				EventSheetL10n.translate("A short sentence always shown above the field, for the one thing nobody should miss."),
				EventSheetL10n.translate("The note is a comment; the field shows plain."))
			note["asks"] = [["info", EventSheetL10n.translate("Note"), "text", "", EventSheetL10n.translate("one short sentence")]]
			note["ready"] = false
			output.append(note)
		"button":
			output.append(_option("none", EventSheetL10n.translate("No button"), EventSheetL10n.translate("No button."), same))
			var button: Dictionary = _option("action", EventSheetL10n.translate("A button under the field"),
				EventSheetL10n.translate("Runs a function of the script when pressed. Works when the script is a @tool script; otherwise it says why it is off."),
				EventSheetL10n.translate("No button; the function is still there to call."))
			button["asks"] = [["action", EventSheetL10n.translate("Function"), "text", "", "pick_" + var_name],
				["action_label", EventSheetL10n.translate("Button label"), "text", "", EventSheetL10n.translate("what the button says")]]
			button["ready"] = false
			output.append(button)
	return output


## The "Groups show as" choices, each with its sentence.
static func group_styles() -> Array[Dictionary]:
	return [_option("sections", EventSheetL10n.translate("Sections"),
			EventSheetL10n.translate("Every group is a heading, all on one long page, as Godot shows them."), ""),
		_option("tabs", EventSheetL10n.translate("Tabs"),
			EventSheetL10n.translate("Each group is a tab, so a long resource fits on one screen. Without the plugin they are headings again."), "")]


## How the sheet's groups show now: "tabs" when an exported variable carries the tabs line.
static func group_style(sheet: EventSheetResource) -> String:
	for entry: Dictionary in EventSheetInspectorDesignerDialog.collect_entries(sheet):
		if bool((entry.get("attributes") as Dictionary).get("tabs", false)):
			return "tabs"
	return "sections"


## Writes the groups' way of showing: the tabs line rides the first exported variable (it heads the
## file's export block) and no other. False when nothing changed.
static func write_group_style(sheet: EventSheetResource, style: String) -> bool:
	var gestures: GDScript = load(GESTURES_PATH)
	var changed: bool = false
	var first: bool = true
	for entry: Dictionary in EventSheetInspectorDesignerDialog.collect_entries(sheet):
		var found: Variant = gestures.member(sheet, str(entry.get("name")))
		if found == null:
			continue
		var attributes: Dictionary = (gestures.attributes_of(found) as Dictionary).duplicate(true)
		var wanted: bool = first and style == "tabs"
		first = false
		if bool(attributes.get("tabs", false)) == wanted:
			continue
		if wanted:
			attributes["tabs"] = true
		else:
			attributes.erase("tabs")
		gestures._set_attributes(found, attributes)
		changed = true
	return changed


## The option of `category` the field wears now, read from its attributes (and, for Show when, from
## the script's own _validate_property when the sheet writes one - see reading()).
static func chosen(category: String, field: Dictionary, reading_of_field: Dictionary = {}) -> String:
	var attributes: Dictionary = field.get("attributes") if field.get("attributes") is Dictionary else {}
	match category:
		"look":
			if not str(attributes.get("choices_function", "")).strip_edges().is_empty():
				return "function_choices"
			var look_id: String = str(EventSheetInspectorLooks.unfold(attributes, PackedStringArray(attributes.get("options", [])))[0])
			return look_id if not look_id.is_empty() else "default"
		"layout":
			if bool(attributes.get("side_by_side", false)):
				return "side_by_side"
		"show":
			if reading_of_field.has("show"):
				return str(reading_of_field["show"])
			if not str(attributes.get("show_if", "")).strip_edges().is_empty():
				return "show_if:" + str(attributes.get("show_if")).strip_edges()
			if not str(attributes.get("lock_unless", "")).strip_edges().is_empty():
				return "lock_unless:" + str(attributes.get("lock_unless")).strip_edges()
		"check":
			if not str(attributes.get("validate", "")).strip_edges().is_empty():
				return "validate"
			if bool(attributes.get("required", false)):
				return "required"
			if bool(attributes.get("clamp", false)) and attributes.get("range") is Dictionary:
				return "clamp"
		"help":
			if not str(attributes.get("info", "")).strip_edges().is_empty():
				return "info"
		"button":
			if not str(attributes.get("action", "")).strip_edges().is_empty():
				return "action"
	return str(DEFAULTS.get(category, ""))


## The details `option_id` of `category` holds on this field now, by key: what its fields show when
## it is the chosen one (empty for another option, whose fields start at their defaults).
static func current_answers(category: String, option_id: String, attributes: Dictionary) -> Dictionary:
	match category:
		"look":
			if option_id == "function_choices":
				return {"choices_function": str(attributes.get("choices_function", ""))}
			var current: Array = EventSheetInspectorLooks.unfold(attributes, PackedStringArray(attributes.get("options", [])))
			return (current[1] as Dictionary).duplicate() if str(current[0]) == option_id else {}
		"check":
			if option_id == "validate":
				return {"validate": str(attributes.get("validate", ""))}
		"help":
			return {"info": str(attributes.get("info", ""))}
		"button":
			return {"action": str(attributes.get("action", "")), "action_label": str(attributes.get("action_label", ""))}
	return {}


## The attributes after choosing `option_id` of `category`: a copy in which only that kind's keys are
## rewritten. `answers` fills the option's details by key. A String dropdown's choices come back
## under "options", the way the Designer's entries carry them.
static func apply(category: String, option_id: String, attributes: Dictionary, type_name: String, answers: Dictionary = {}) -> Dictionary:
	var output: Dictionary = attributes.duplicate(true)
	match category:
		"look":
			for key: String in EventSheetInspectorLooks.look_keys():
				output.erase(key)
			output.erase("options")
			output.erase("choices_function")
			if option_id == "function_choices":
				output["choices_function"] = str(answers.get("choices_function", "")).strip_edges()
			elif option_id != "default":
				var look: Dictionary = EventSheetInspectorLooks.by_id(option_id)
				var held: Dictionary = current_answers("look", option_id, attributes)
				var values: Dictionary = held.duplicate()
				for detail: Array in look.get("fields", []):
					if not values.has(detail[0]):
						values[detail[0]] = detail[3]
				# Limits survive a change of look, so a slider made a bar keeps its 0 to 500.
				if held.is_empty() and attributes.get("range") is Dictionary:
					for bound: String in ["min", "max", "step"]:
						if (attributes["range"] as Dictionary).has(bound) and values.has(bound):
							values[bound] = str((attributes["range"] as Dictionary)[bound])
				values.merge(answers, true)
				output.merge(EventSheetInspectorLooks.fold(option_id, values, type_name), true)
			# A clamp keeps a value inside the look's limits; with no limits left it has nothing to keep.
			if not (output.get("range") is Dictionary):
				output.erase("clamp")
		"layout":
			output.erase("side_by_side")
			if option_id == "side_by_side":
				output["side_by_side"] = true
		"show":
			output.erase("show_if")
			output.erase("lock_unless")
			var parts: PackedStringArray = option_id.split(":")
			if parts.size() == 2 and not parts[1].is_empty() and parts[0] in ["show_if", "lock_unless"]:
				output[parts[0]] = parts[1]
		"check":
			for key: String in ["clamp", "required", "validate"]:
				output.erase(key)
			match option_id:
				"clamp":
					output["clamp"] = true
					if not (output.get("range") is Dictionary):
						output["range"] = {"min": _or(str(answers.get("min", "")), "0"), "max": _or(str(answers.get("max", "")), "100"), "step": "1"}
				"required":
					output["required"] = true
				"validate":
					output["validate"] = str(answers.get("validate", "")).strip_edges()
		"help":
			output.erase("info")
			if option_id == "info":
				output["info"] = str(answers.get("info", "")).strip_edges().replace("\n", " ")
		"button":
			output.erase("action")
			output.erase("action_label")
			if option_id == "action":
				output["action"] = str(answers.get("action", "")).strip_edges()
				if not str(answers.get("action_label", "")).strip_edges().is_empty():
					output["action_label"] = str(answers.get("action_label")).strip_edges()
	return output


## Why the answers cannot be written, or "" when they can: a function must be a plain name, a note
## must say something.
static func refusal(category: String, option_id: String, answers: Dictionary) -> String:
	for key: String in ["validate", "action", "choices_function"]:
		if answers.has(key) and (category != "look" or option_id == "function_choices") \
				and not str(answers[key]).strip_edges().is_valid_identifier():
			return EventSheetL10n.translate("A function name is one word of letters, digits and _, like check_health.")
	if category == "help" and str(answers.get("info", "")).strip_edges().is_empty():
		return EventSheetL10n.translate("Fill this in first: it is what the choice writes.")
	if category == "look" and option_id != "default" and option_id != "function_choices" \
			and not _stands_on_defaults(option_id, "") and answers.values().all(func(value: Variant) -> bool: return str(value).strip_edges().is_empty()):
		return EventSheetL10n.translate("Fill this in first: it is what the choice writes.")
	return ""


## True when the attributes carry a choice the Inspector can only honour in a @tool script.
static func needs_tool(attributes: Dictionary) -> bool:
	return not str(attributes.get("show_if", "")).strip_edges().is_empty() or not str(attributes.get("lock_unless", "")).strip_edges().is_empty()


## True when any exported variable of the sheet still needs @tool for its shape.
static func sheet_needs_tool(sheet: EventSheetResource) -> bool:
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).exported and (entry as LocalVariable).attributes is Dictionary \
				and needs_tool((entry as LocalVariable).attributes):
			return true
	for descriptor: Variant in sheet.variables.values():
		if descriptor is Dictionary and (descriptor as Dictionary).get("attributes") is Dictionary and needs_tool((descriptor as Dictionary)["attributes"]):
			return true
	return false


## Writes one choice onto the live sheet's variable `var_name`; false when nothing changed (or there
## is no such variable). The caller runs it inside the undo funnel, so the whole of it - every line it
## rewrites and the @tool it turns on or off - is one undo step.
static func write(sheet: EventSheetResource, var_name: String, category: String, option_id: String, answers: Dictionary = {}) -> bool:
	var gestures: GDScript = load(GESTURES_PATH)
	var found: Variant = gestures.member(sheet, var_name)
	if found == null:
		return false
	var before: Dictionary = _attributes_with_options(found)
	var after: Dictionary = apply(category, option_id, before, str(gestures._type_of(found)), answers)
	if after == before:
		return false
	var combo: PackedStringArray = PackedStringArray(after.get("options", []))
	after.erase("options")
	gestures._set_attributes(found, after)
	if found is LocalVariable:
		(found as LocalVariable).options = combo
		# A look is written from the attributes, so a verbatim hint kept from the file gives way to it.
		if category == "look":
			(found as LocalVariable).export_hint = ""
	elif combo.is_empty():
		(found as Dictionary).erase("options")
	else:
		(found as Dictionary)["options"] = Array(combo)
	if sheet_needs_tool(sheet) and not sheet.tool_mode:
		_set_tool(sheet, true)
		sheet.set_meta(TOOL_META, true)
	elif not sheet_needs_tool(sheet) and sheet.has_meta(TOOL_META):
		_set_tool(sheet, false)
		sheet.remove_meta(TOOL_META)
	return true


## Turns the sheet's Tool mode on or off the way the head's @tool switch does: the flag, and for an
## opened script the `@tool` line of its own prelude, which the file keeps as written.
static func _set_tool(sheet: EventSheetResource, on: bool) -> void:
	sheet.tool_mode = on
	var prelude: RawCodeRow = EventSheetHeadActions.new()._prelude_row_for(sheet, EventSheetHeadBands.BAND_TOOL)
	if prelude != null:
		prelude.code = EventSheetHeadActions.rewrite_prelude(prelude.code, EventSheetHeadBands.BAND_TOOL, "true" if on else "false")


## The code choosing `option_id` writes for `var_name`, as the file will hold it: the variable's own
## lines, and for a Show when the @tool line, the tick box's refreshing setter and the function that
## hides or locks the field. Emitted by the compiler itself from a copy, so it cannot disagree with
## the file.
static func code(sheet: EventSheetResource, var_name: String, category: String, option_id: String, answers: Dictionary = {}) -> String:
	var gestures: GDScript = load(GESTURES_PATH)
	var found: Variant = gestures.member(sheet, var_name)
	if found == null:
		return ""
	var after: Dictionary = apply(category, option_id, _attributes_with_options(found), str(gestures._type_of(found)), answers)
	var lines: PackedStringArray = PackedStringArray()
	var switch: String = str(after.get("show_if", after.get("lock_unless", ""))).strip_edges()
	if category == "show" and not switch.is_empty():
		# The @tool line is this choice's while the sheet was not a tool sheet before it.
		if not sheet.tool_mode or sheet.has_meta(TOOL_META):
			lines.append("@tool")
		var controller: Variant = gestures.member(sheet, switch)
		if controller != null:
			lines.append(_emitted(controller, switch, attributes_of_member(controller), true, false))
	lines.append(_emitted(found, var_name, after, false, category == "look"))
	if category == "show" and not switch.is_empty():
		lines.append_array(SheetCompiler.inspector_conditions_function([{"name": var_name, "predicate": switch, "known": true,
			"kind": "lock_unless" if after.has("lock_unless") else "show_if"}]))
	return "\n".join(lines)


## The attributes a member carries, its String dropdown's choices folded in under "options".
static func attributes_of_member(found: Variant) -> Dictionary:
	return _attributes_with_options(found)


## What the sheet's own code says about its fields' shapes, by field name: {"show": option_id} for a
## field its own _validate_property hides or locks the way a Show when would, {"own": <why>} for one
## shaped in any other way. Empty when the sheet writes nothing of the kind.
static func reading(sheet: EventSheetResource) -> Dictionary:
	var found: Dictionary = {}
	if sheet == null:
		return found
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable != null and variable.exported and not variable.export_hint.strip_edges().is_empty() \
				and str(EventSheetInspectorLooks.unfold(variable.attributes if variable.attributes is Dictionary else {}, variable.options)[0]).is_empty():
			found[variable.name] = {"own": variable.export_hint.strip_edges()}
	var function_text: String = own_validate_property(sheet)
	if function_text.is_empty():
		return found
	found["__owns_validate"] = true
	var pattern: RegEx = RegEx.create_from_string("^\\tif (?:str\\(property\\.name\\)|property\\.name) == \"(\\w+)\" and not (?:bool\\((\\w+)\\)|(\\w+)):$")
	var lines: PackedStringArray = function_text.split("\n")
	var index: int = 1
	var own: Dictionary = {}
	while index < lines.size():
		var line: String = lines[index]
		var matched: RegExMatch = pattern.search(line)
		var body: String = lines[index + 1] if index + 1 < lines.size() else ""
		if matched != null and (HIDE_LINES.has(body) or body == LOCK_LINE):
			var switch: String = matched.get_string(2) if not matched.get_string(2).is_empty() else matched.get_string(3)
			var named: String = matched.get_string(1)
			# A field the function names twice is shaped in a way no one choice says.
			if (found.get(named, {}) as Dictionary).has("show"):
				own[named] = true
			found[named] = {"show": ("lock_unless:" if body == LOCK_LINE else "show_if:") + switch}
			index += 2
			continue
		for quoted: RegExMatch in RegEx.create_from_string("\"(\\w+)\"").search_all(line):
			own[quoted.get_string(1)] = true
		index += 1
	for named: Variant in own:
		found[named] = {"own": "_validate_property"}
	return found


## The script's own `func _validate_property` as it stands in the file, or "" when the sheet does not
## write one (the compiler's own generated function is not the sheet's - it is a Show when).
static func own_validate_property(sheet: EventSheetResource) -> String:
	var source: String = ""
	for entry: Variant in sheet.events:
		if entry is RawCodeRow and (entry as RawCodeRow).code.contains(VALIDATE_HEADER):
			source = (entry as RawCodeRow).code
	var writes_one: bool = not source.is_empty()
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction and (function_entry as EventFunction).function_name == "_validate_property":
			writes_one = true
	if not writes_one:
		return ""
	if source.is_empty() and not sheet.external_source_path.is_empty() and FileAccess.file_exists(sheet.external_source_path):
		source = FileAccess.get_file_as_string(sheet.external_source_path)
	var start: int = source.find(VALIDATE_HEADER)
	if start < 0:
		return VALIDATE_HEADER
	var block: PackedStringArray = PackedStringArray()
	for line: String in source.substr(start).split("\n"):
		if not block.is_empty() and not line.is_empty() and not line.begins_with("\t") and not line.begins_with(" "):
			break
		block.append(line)
	while block.size() > 1 and block[block.size() - 1].strip_edges().is_empty():
		block.remove_at(block.size() - 1)
	return "\n".join(block)


## True when a look written on its details' defaults reads back as that look and holds something -
## false for one whose detail is the whole point (a dropdown's choices, a box's hint, a table's
## columns), which is asked for first.
static func _stands_on_defaults(look_id: String, type_name: String) -> bool:
	var look: Dictionary = EventSheetInspectorLooks.by_id(look_id)
	if look.is_empty():
		return false
	var values: Dictionary = {}
	for detail: Array in look.get("fields", []):
		values[detail[0]] = detail[3]
	var folded: Dictionary = EventSheetInspectorLooks.fold(look_id, values, type_name)
	if folded.values().any(func(value: Variant) -> bool: return (value is Array and (value as Array).is_empty()) or (value is String and (value as String).is_empty())):
		return false
	return str(EventSheetInspectorLooks.unfold(folded, PackedStringArray(folded.get("options", [])))[0]) == look_id


static func _emitted(found: Variant, var_name: String, attributes: Dictionary, refresh: bool, drop_hint: bool) -> String:
	var combo: PackedStringArray = PackedStringArray(attributes.get("options", []))
	var clean: Dictionary = attributes.duplicate(true)
	clean.erase("options")
	if found is LocalVariable:
		var copy: LocalVariable = (found as LocalVariable).duplicate(true) as LocalVariable
		copy.attributes = clean
		copy.options = combo
		if drop_hint:
			copy.export_hint = ""
		return SheetCompiler._emit_tree_variable_line(copy, refresh)
	var descriptor: Dictionary = (found as Dictionary).duplicate(true)
	descriptor["attributes"] = clean
	descriptor.erase("options")
	if not combo.is_empty():
		descriptor["options"] = Array(combo)
	return "\n".join(SheetCompiler._emit_variables({var_name: descriptor}, [], {}, {var_name: true} if refresh else {}))


static func _attributes_with_options(found: Variant) -> Dictionary:
	var gestures: GDScript = load(GESTURES_PATH)
	var attributes: Dictionary = (gestures.attributes_of(found) as Dictionary).duplicate(true)
	var combo: Array = Array((found as LocalVariable).options) if found is LocalVariable \
		else ((found as Dictionary).get("options", []) if (found as Dictionary).get("options") is Array else [])
	if not combo.is_empty():
		attributes["options"] = combo
	return attributes


## A look's detail fields with their words in the editor's language, the way the Variable window shows
## them: the label, and the hint of a typed field (a "pick" field's hint is its choices, kept as values).
static func _translated(fields: Array) -> Array:
	var output: Array = []
	for detail: Array in fields:
		var copy: Array = detail.duplicate(true)
		copy[1] = EventSheetL10n.translate(str(copy[1]))
		while copy.size() < 5:
			copy.append("")
		if copy[4] is String:
			copy[4] = EventSheetL10n.translate(str(copy[4]))
		output.append(copy)
	return output


## Why `field` cannot share a line with the field declared after it, or "" when it can. Only two
## numbers share a line (the Inspector draws anything else one per line), and never across a group
## line: the next field then sits under another heading. A group line rides on the first field of the
## group, so a group key on the next field means a heading comes between the two.
static func _side_by_side_refusal(field: Dictionary, fields: Array) -> String:
	var var_name: String = str(field.get("name", ""))
	var at: int = -1
	for index: int in fields.size():
		if fields[index] is Dictionary and str((fields[index] as Dictionary).get("name", "")) == var_name:
			at = index
	if at < 0:
		return ""
	if at == fields.size() - 1:
		return EventSheetL10n.translate("No field is declared after this one to share its line.")
	var next: Dictionary = fields[at + 1] as Dictionary
	var next_attributes: Dictionary = next.get("attributes") if next.get("attributes") is Dictionary else {}
	for level: String in ["category", "group", "subgroup"]:
		if next_attributes.has(level):
			return EventSheetL10n.translate("The next field, %s, starts another group, so the two sit under different headings.") % str(next.get("name", ""))
	if not (str(field.get("type_name", "")) in ["int", "float"] and str(next.get("type_name", "")) in ["int", "float"]):
		return EventSheetL10n.translate("Only two numbers share a line; this field and %s are drawn one per line.") % str(next.get("name", ""))
	return ""


static func _option(id: String, label: String, tip: String, plain: String, reason: String = "") -> Dictionary:
	return {"id": id, "label": label, "tip": tip, "plain": plain, "reason": reason, "asks": [], "ready": true}


static func _or(text: String, fallback: String) -> String:
	return fallback if text.strip_edges().is_empty() else text
