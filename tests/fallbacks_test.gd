# Godot EventSheets - the fallback vocabulary: Number/Text/List/Record/Value Or, plus Part Of and
# Set Part Of ("Variables" and "Variables: Vector").
#
# Two halves, because a descriptor that merely PARSES proves nothing about what a row does:
#   1. Emission - the shipped templates go through the real ActionCodegen substitution, land in a
#      real sheet row, and the whole sheet is run through SheetCompiler; the emitted lines are
#      pinned character-for-character (they are a compatibility promise once shipped) and the
#      generated GDScript is reload()ed to prove it parses.
#   2. Runtime - those same substituted templates are assembled into a script that is loaded and
#      CALLED, so every branch the vocabulary promises is asserted on real values: the value comes
#      back when the type matches, the fallback comes back when it does not, a zero counts as a real
#      number, an empty text/list/record counts as missing, a Split Text result counts as a list,
#      and writing one named part leaves the rest of the vector/colour/record alone.
#
# Two further things are pinned here because they are DECISIONS, not accidents: the part cell reads
# as its plain-English label while emitting a quoted GDScript key, and Set Part Of's emitted line is
# indistinguishable from Set Key's, so a reopened .gd sheet shows the row as Set Key. The second is
# the deliberate price of never re-labelling somebody's `save["gold"] = 5` as a vector part.
#
# ONE engine error line is expected from this file: "Invalid access to property or key 'y'", from
# the assertion that Part Of on a record lacking that part hands back nothing. That is the case that
# sends an author to Get Key (with default), and asserting it is how the caveat stays true.
@tool
class_name FallbacksTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true

	var by_id: Dictionary = {}
	var id_counts: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
		id_counts[descriptor.ace_id] = int(id_counts.get(descriptor.ace_id, 0)) + 1

	# ── Registry shape ───────────────────────────────────────────────────────────────────────────
	for ace_id: String in ["NumberOr", "TextOr", "ListOr", "RecordOr", "ValueOr", "PartOf", "SetPartOf"]:
		ok = _check("%s is registered" % ace_id, by_id.has(ace_id), true) and ok
		ok = _check("%s is registered exactly once (no shadowed id)" % ace_id, int(id_counts.get(ace_id, 0)), 1) and ok

	ok = _check("Number Or reads as its display name", str(by_id["NumberOr"].display_name), "Number Or") and ok
	ok = _check("Text Or reads as its display name", str(by_id["TextOr"].display_name), "Text Or") and ok
	ok = _check("List Or reads as its display name", str(by_id["ListOr"].display_name), "List Or") and ok
	ok = _check("Record Or reads as its display name", str(by_id["RecordOr"].display_name), "Record Or") and ok
	ok = _check("Value Or reads as its display name", str(by_id["ValueOr"].display_name), "Value Or") and ok
	ok = _check("Part Of reads as its display name", str(by_id["PartOf"].display_name), "Part Of") and ok
	ok = _check("Set Part Of reads as its display name", str(by_id["SetPartOf"].display_name), "Set Part Of") and ok

	ok = _check("the Or family lands in the Variables category", str(by_id["NumberOr"].category), "Variables") and ok
	ok = _check("Text Or lands in the Variables category", str(by_id["TextOr"].category), "Variables") and ok
	ok = _check("List Or lands in the Variables category", str(by_id["ListOr"].category), "Variables") and ok
	ok = _check("Record Or lands in the Variables category", str(by_id["RecordOr"].category), "Variables") and ok
	ok = _check("Value Or lands in the Variables category", str(by_id["ValueOr"].category), "Variables") and ok
	ok = _check("Part Of lands beside Make Vector2", str(by_id["PartOf"].category), "Variables: Vector") and ok
	ok = _check("Set Part Of lands beside Make Vector2", str(by_id["SetPartOf"].category), "Variables: Vector") and ok

	ok = _check("Number Or is an expression", by_id["NumberOr"].ace_type, ACEDescriptor.ACEType.EXPRESSION) and ok
	ok = _check("Part Of is an expression", by_id["PartOf"].ace_type, ACEDescriptor.ACEType.EXPRESSION) and ok
	ok = _check("Set Part Of is an action", by_id["SetPartOf"].ace_type, ACEDescriptor.ACEType.ACTION) and ok

	# Templates are API once shipped - pinned character-for-character.
	ok = _check("Number Or template guards the type with typeof, never `is`",
		str(by_id["NumberOr"].codegen_template),
		"({value} if typeof({value}) in [TYPE_INT, TYPE_FLOAT] else {fallback})") and ok
	ok = _check("Text Or template guards the type and the emptiness",
		str(by_id["TextOr"].codegen_template),
		"({value} if (typeof({value}) == TYPE_STRING and {value}) else {fallback})") and ok
	ok = _check("List Or template accepts a packed list too, and guards the emptiness",
		str(by_id["ListOr"].codegen_template),
		"({value} if ((typeof({value}) == TYPE_ARRAY or typeof({value}) >= TYPE_PACKED_BYTE_ARRAY) and {value}) else {fallback})") and ok
	ok = _check("Record Or template guards the type and the emptiness",
		str(by_id["RecordOr"].codegen_template),
		"({value} if (typeof({value}) == TYPE_DICTIONARY and {value}) else {fallback})") and ok
	ok = _check("Value Or template guards null only",
		str(by_id["ValueOr"].codegen_template),
		"({value} if {value} != null else {fallback})") and ok
	ok = _check("Part Of template is a plain subscript",
		str(by_id["PartOf"].codegen_template), "({value})[{part}]") and ok
	# The guard re-reads the value expression, so a value that CONSUMES something would run twice.
	# That warning belongs on the ROW (hover help), not only in a code comment nobody authoring a
	# sheet will ever open - so it is asserted, per verb.
	for or_id: String in ["NumberOr", "TextOr", "ListOr", "RecordOr", "ValueOr"]:
		ok = _check("%s warns in its own row help that the value is read twice" % or_id,
			str(by_id[or_id].description).contains("read twice"), true) and ok
	ok = _check("Set Part Of template writes through the same subscript",
		str(by_id["SetPartOf"].codegen_template), "{var_name}[{part}] = {value}") and ok

	# The part dropdown: labeled options whose VALUES never carry a {param} placeholder (substitution
	# is a single left-to-right pass, so a placeholder arriving from an option is emitted literally).
	var part_param: ACEParam = _param_of(by_id["PartOf"], "part")
	ok = _check("Part Of offers the seven named parts", part_param.options.size(), 7) and ok
	var first_option: Dictionary = part_param.options[0] as Dictionary
	ok = _check("the first part inserts a quoted key", str(first_option.get("key", "")), "\"x\"") and ok
	ok = _check("the first part reads in plain English", str(first_option.get("label", "")), "X (left / right)") and ok
	var placeholder_keys: int = 0
	var unlabeled: int = 0
	for option: Variant in part_param.options:
		var option_dict: Dictionary = option as Dictionary
		if str(option_dict.get("key", "")).contains("{"):
			placeholder_keys += 1
		if str(option_dict.get("label", "")) == str(option_dict.get("key", "")):
			unlabeled += 1
	ok = _check("no part option value smuggles a {param} placeholder", placeholder_keys, 0) and ok
	ok = _check("every part option carries its own plain-English label", unlabeled, 0) and ok
	ok = _check("Set Part Of offers the same seven parts (one shared list, no drift)",
		_param_of(by_id["SetPartOf"], "part").options, part_param.options) and ok
	# The headline targets are a NODE's own members - "zero the vertical of velocity", "fade the
	# see-through part of modulate". A closed sheet-variables dropdown cannot name either of them, so
	# the target is a property reference: the host class's members, reflected, in an EDITABLE field
	# (a sheet variable is still typed into the same cell).
	ok = _check("Set Part Of's target is a property reference, so a node member can be picked",
		str(_param_of(by_id["SetPartOf"], "var_name").hint), "property_reference") and ok
	ok = _check("and that picker really offers the row's headline target",
		ACEParamsDialog.reflected_members("CharacterBody2D", "property").has("velocity"), true) and ok
	ok = _check("the tint case is reachable the same way",
		ACEParamsDialog.reflected_members("CanvasItem", "property").has("modulate"), true) and ok
	ok = _check("Part Of defaults to the up/down part (the jump-or-fall test)",
		str(part_param.default_value), "\"y\"") and ok
	# The row is a SENTENCE, so the part cell must read as its label - the option KEY is GDScript
	# (`"y"`, quotes and all) and rendering that would put source code in the middle of the sentence.
	ok = _check("the part dropdown declares label display", part_param.display_option_labels, true) and ok
	ok = _check("Set Part Of's part dropdown does too",
		_param_of(by_id["SetPartOf"], "part").display_option_labels, true) and ok
	ok = _check("so Part Of READS as the plain-English part, not as the quoted key",
		by_id["PartOf"].format_display({"value": "velocity", "part": "\"y\""}), "the Y (up / down) part of velocity") and ok
	ok = _check("and so does Set Part Of",
		by_id["SetPartOf"].format_display({"var_name": "velocity", "part": "\"y\"", "value": "0.0"}),
		"set the Y (up / down) part of velocity to 0.0") and ok
	# The same rule has to survive the trip through the editor-side definition, which is what the
	# viewport actually formats from.
	var part_definition: ACEDefinition = EventSheetACEAdapter.from_eventforge_descriptor(by_id["PartOf"])
	ok = _check("the adapter carries the label-display flag into the definition",
		bool((part_definition.parameters[1] as Dictionary).get("display_option_labels", false)), true) and ok
	ok = _check("so the editor-side definition reads the same sentence",
		part_definition.format_display({"value": "velocity", "part": "\"a\""}),
		"the Alpha (see-through) part of velocity") and ok
	# A value matching no option is shown verbatim: the label lookup must never invent a reading.
	ok = _check("a part outside the seven is shown as it is",
		by_id["PartOf"].format_display({"value": "save", "part": "\"score\""}), "the \"score\" part of save") and ok
	# The opposite case, pinned so nobody widens this into every dropdown: a comparison operator IS
	# its own best reading, and "score = (equal to) 5" would be a regression.
	ok = _check("an operator dropdown does NOT opt in",
		_param_of(by_id["CompareValues"], "op").display_option_labels, false) and ok

	# ── Emission: a real sheet through the real compiler ─────────────────────────────────────────
	var number_line: String = _fill(by_id["NumberOr"], {"value": "save.get(\"score\")", "fallback": "0"})
	var text_line: String = _fill(by_id["TextOr"], {"value": "save.get(\"name\")", "fallback": "\"Player\""})
	var list_line: String = _fill(by_id["ListOr"], {"value": "save.get(\"items\")", "fallback": "[]"})
	var record_line: String = _fill(by_id["RecordOr"], {"value": "save.get(\"options\")", "fallback": "{}"})
	var value_line: String = _fill(by_id["ValueOr"], {"value": "save.get(\"held\")", "fallback": "0"})
	var part_line: String = _fill(by_id["PartOf"], {"value": "heading", "part": "\"y\""})

	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	_add_local(event, by_id, "save", "{\"score\": 7, \"name\": \"\", \"items\": [], \"options\": {}, \"held\": null}")
	_add_local(event, by_id, "bet", number_line)
	_add_local(event, by_id, "player_name", text_line)
	_add_local(event, by_id, "inventory", list_line)
	_add_local(event, by_id, "settings", record_line)
	_add_local(event, by_id, "held_item", value_line)
	_add_local(event, by_id, "heading", "Vector2(3, 4)")
	_add_local(event, by_id, "fall_speed", part_line)
	var write: ACEAction = ACEAction.new()
	write.provider_id = "Core"
	write.ace_id = "SetPartOf"
	write.codegen_template = str(by_id["SetPartOf"].codegen_template)
	write.params = {"var_name": "heading", "part": "\"y\"", "value": "0.0"}
	event.actions.append(write)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_fallbacks.gd").get("output", ""))

	ok = _check("Number Or emits the typeof guard around the read",
		output.contains("var bet = (save.get(\"score\") if typeof(save.get(\"score\")) in [TYPE_INT, TYPE_FLOAT] else 0)"), true) and ok
	ok = _check("Text Or emits the type guard plus the emptiness test",
		output.contains("var player_name = (save.get(\"name\") if (typeof(save.get(\"name\")) == TYPE_STRING and save.get(\"name\")) else \"Player\")"), true) and ok
	ok = _check("List Or emits the type guard plus the emptiness test",
		output.contains("var inventory = (save.get(\"items\") if ((typeof(save.get(\"items\")) == TYPE_ARRAY or typeof(save.get(\"items\")) >= TYPE_PACKED_BYTE_ARRAY) and save.get(\"items\")) else [])"), true) and ok
	ok = _check("Record Or emits the type guard plus the emptiness test",
		output.contains("var settings = (save.get(\"options\") if (typeof(save.get(\"options\")) == TYPE_DICTIONARY and save.get(\"options\")) else {})"), true) and ok
	ok = _check("Value Or emits the plain null guard",
		output.contains("var held_item = (save.get(\"held\") if save.get(\"held\") != null else 0)"), true) and ok
	ok = _check("Part Of emits a plain subscript, no helper call",
		output.contains("var fall_speed = (heading)[\"y\"]"), true) and ok
	ok = _check("Set Part Of emits a plain subscript assignment",
		output.contains("heading[\"y\"] = 0.0"), true) and ok
	ok = _check("nothing reaches the output with an unbaked placeholder",
		output.contains("{value}") or output.contains("{part}") or output.contains("{fallback}"), false) and ok
	var compiled: GDScript = GDScript.new()
	compiled.source_code = output
	ok = _check("the compiled sheet parses as GDScript", compiled.reload(true), OK) and ok

	# ── Runtime: the shipped templates, called on real values ────────────────────────────────────
	var runtime: GDScript = GDScript.new()
	runtime.source_code = _runtime_source(by_id)
	var runtime_error: int = runtime.reload()
	ok = _check("the assembled runtime script parses", runtime_error, OK) and ok
	# Guard, not ceremony: with a template that stopped compiling, runtime.new() is null and every
	# call below would abort run() mid-way - the suite would print ONE failure and silently lose the
	# rest of this file's assertions, which is exactly the "a crashed test looks green" trap.
	if runtime_error != OK:
		return false
	var probe: RefCounted = runtime.new()
	if probe == null:
		return _check("the runtime probe instantiates", false, true) and ok

	# Number Or - the value when it is a number, the fallback for everything else. A zero is kept.
	ok = _check("Number Or keeps a whole number", probe.number_or(7), 7) and ok
	ok = _check("Number Or keeps a decimal", probe.number_or(1.5), 1.5) and ok
	ok = _check("Number Or keeps a zero (a score of 0 is a real value)", probe.number_or(0), 0) and ok
	ok = _check("Number Or falls back on numeric-looking TEXT (the silent-zero bug)", probe.number_or("7"), -1) and ok
	ok = _check("Number Or falls back on a missing key (null)", probe.number_or(null), -1) and ok
	ok = _check("Number Or falls back on a true/false (a flag is not a number)", probe.number_or(true), -1) and ok
	ok = _check("Number Or falls back on a list", probe.number_or([1, 2]), -1) and ok

	# Text Or - text with something in it, else the fallback.
	ok = _check("Text Or keeps real text", probe.text_or("Ada"), "Ada") and ok
	ok = _check("Text Or falls back on blank text", probe.text_or(""), "Player") and ok
	ok = _check("Text Or falls back on a number", probe.text_or(5), "Player") and ok
	ok = _check("Text Or falls back on a missing key (null)", probe.text_or(null), "Player") and ok

	# List Or - a list with items in it, else the fallback.
	ok = _check("List Or keeps a filled list", probe.list_or([1, 2]), [1, 2]) and ok
	ok = _check("List Or falls back on an empty list", probe.list_or([]), [9]) and ok
	ok = _check("List Or falls back on text", probe.list_or("ab"), [9]) and ok
	ok = _check("List Or falls back on a missing key (null)", probe.list_or(null), [9]) and ok
	# Split Text hands back a PackedStringArray, which is NOT TYPE_ARRAY - the single most natural
	# way a sheet ever makes a list. Without the packed clause a perfectly good split was discarded.
	ok = _check("List Or keeps a Split Text result", probe.list_or("a,b".split(",")), "a,b".split(",")) and ok
	ok = _check("List Or falls back on an EMPTY Split Text result", probe.list_or("".split(",", false)), [9]) and ok
	ok = _check("List Or keeps a list of bytes too", probe.list_or(PackedByteArray([1, 2])), PackedByteArray([1, 2])) and ok

	# Record Or - a record with keys in it, else the fallback.
	ok = _check("Record Or keeps a filled record", probe.record_or({"a": 1}), {"a": 1}) and ok
	ok = _check("Record Or falls back on an empty record", probe.record_or({}), {"d": 1}) and ok
	ok = _check("Record Or falls back on a list", probe.record_or([]), {"d": 1}) and ok
	ok = _check("Record Or falls back on a missing key (null)", probe.record_or(null), {"d": 1}) and ok

	# Value Or - null is the ONLY thing it treats as missing.
	ok = _check("Value Or keeps a zero", probe.value_or(0), 0) and ok
	ok = _check("Value Or keeps blank text", probe.value_or(""), "") and ok
	ok = _check("Value Or keeps an empty list", probe.value_or([]), []) and ok
	ok = _check("Value Or falls back on null", probe.value_or(null), -1) and ok

	# Part Of - one verb over a pair, a triple, a colour and a record.
	ok = _check("Part Of reads the up/down part of a Vector2", probe.part_y(Vector2(3.0, 4.0)), 4.0) and ok
	ok = _check("Part Of reads the up/down part of a Vector3", probe.part_y(Vector3(1.0, 2.0, 3.0)), 2.0) and ok
	ok = _check("Part Of reads the forward/back part of a Vector3", probe.part_z(Vector3(1.0, 2.0, 3.0)), 3.0) and ok
	ok = _check("Part Of reads the see-through part of a Color", probe.part_a(Color(1.0, 1.0, 1.0, 0.25)), 0.25) and ok
	ok = _check("Part Of reads a record's field of the same name", probe.part_y({"x": 1, "y": 12}), 12) and ok
	# The dropdown ships the seven named parts; the subscript itself accepts any record key, which is
	# what makes this ONE verb for vectors, colours and records alike.
	ok = _check("Part Of reads a record field outside the seven named parts",
		probe.part_named({"score": 7}), 7) and ok

	# Set Part Of - one part changes, the rest is left alone.
	ok = _check("Set Part Of zeroes the vertical of a Vector2", probe.set_part_vector(), Vector2(3.0, 0.0)) and ok
	ok = _check("Set Part Of leaves the horizontal alone", probe.set_part_vector().x, 3.0) and ok
	ok = _check("Set Part Of flattens a Vector3 to the ground plane", probe.set_part_vector3(), Vector3(1.0, 0.0, 3.0)) and ok
	ok = _check("Set Part Of fades only the see-through part", probe.set_part_color(), Color(1.0, 1.0, 1.0, 0.25)) and ok
	ok = _check("Set Part Of writes a record field, leaving the others", probe.set_part_record(), {"x": 1, "y": 5.0}) and ok

	# Set Part Of on a record ADDS the part when it is not there yet (its description says so), which
	# is also why the read side needs the caveat asserted just below.
	ok = _check("Set Part Of adds a part a record did not have", probe.set_part_new_record(), {"y": 5.0}) and ok

	# The read side has no fallback cell, so a record missing the part answers with nothing rather
	# than a value. Pinned deliberately: it is what sends an author to Get Key (with default), which
	# is the verb that takes a fallback, and it is the ONE engine error line this file provokes.
	ok = _check("Part Of on a record without that part hands back nothing",
		probe.part_y({"hp": 5}), null) and ok

	# The headline use is a NODE member (`velocity`, `modulate`), not a local - a subscript write on a
	# node property really does take effect, which a local-only test would never have caught.
	var host: GDScript = GDScript.new()
	host.source_code = _host_source(by_id)
	var host_error: int = host.reload()
	ok = _check("the node-hosted script parses", host_error, OK) and ok
	if host_error != OK:
		return false
	var node: Node2D = Node2D.new()
	node.set_script(host)
	node.call("fade_out")
	ok = _check("Set Part Of writes a node's own colour property", node.modulate, Color(1.0, 1.0, 1.0, 0.25)) and ok
	node.free()

	# The lead row: zero the vertical on landing, keep the horizontal. `velocity` only
	# exists on a body, so this needs its own host - and it is the case a sheet-variables dropdown
	# could not have reached at all.
	var body_script: GDScript = GDScript.new()
	body_script.source_code = _body_source(by_id)
	var body_error: int = body_script.reload()
	ok = _check("the body-hosted script parses", body_error, OK) and ok
	if body_error != OK:
		return false
	var body: CharacterBody2D = CharacterBody2D.new()
	body.set_script(body_script)
	ok = _check("Set Part Of zeroes a body's own vertical speed and keeps the horizontal",
		body.call("land"), Vector2(120.0, 0.0)) and ok
	body.free()

	# ── The reopen trade, pinned rather than assumed ──────────────────────────────────────────────
	# Set Part Of emits character-for-character what Set Key emits, so the reverse-lifter cannot tell
	# them apart and Set Key (authored earlier, same specificity) wins. That means a .gd-backed sheet
	# reopens the row as Set Key - the CODE is byte-identical, the sentence is what is lost. Pinned in
	# BOTH directions so the trade stays deliberate: somebody else's record write must never be
	# re-labelled as a vector part, which is the failure this shape was chosen to avoid.
	var entries: Array = EventSheetACELifter._build_reverse_entries()
	ok = _check("an ordinary record write still lifts as Set Key",
		str(EventSheetACELifter._match_entry("save[\"gold\"] = 5", entries, "action").get("ace_id", "")), "DictSetKey") and ok
	ok = _check("and a Set Part Of row reads back as Set Key on reopen (the documented trade)",
		str(EventSheetACELifter._match_entry("velocity[\"y\"] = 0.0", entries, "action").get("ace_id", "")), "DictSetKey") and ok
	ok = _check("nothing in this family claims a plain member assignment",
		str(EventSheetACELifter._match_entry("tuning.wobble_amount = 3", entries, "action").get("ace_id", "")), "SetProperty") and ok

	return ok


## The shipped template, substituted through the REAL codegen (never a hand-built string).
static func _fill(descriptor: ACEDescriptor, params: Dictionary) -> String:
	return ActionCodegen._apply_template(str(descriptor.codegen_template), params)


## Appends a Set Local Variable row, the row a user drops an expression verb into.
static func _add_local(event: EventRow, by_id: Dictionary, local_name: String, value: String) -> void:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetLocalVar"
	action.codegen_template = str((by_id["SetLocalVar"] as ACEDescriptor).codegen_template)
	action.params = {"name": local_name, "value": value}
	event.actions.append(action)


static func _param_of(descriptor: ACEDescriptor, param_id: String) -> ACEParam:
	for param: ACEParam in descriptor.params:
		if str(param.id) == param_id:
			return param
	return ACEParam.new()


## A script built from the SHIPPED templates so the runtime asserts exercise what ships, not a copy.
static func _runtime_source(by_id: Dictionary) -> String:
	var lines: Array[String] = [
		"@tool",
		"extends RefCounted",
		"func number_or(v):",
		"\treturn %s" % _fill(by_id["NumberOr"], {"value": "v", "fallback": "-1"}),
		"func text_or(v):",
		"\treturn %s" % _fill(by_id["TextOr"], {"value": "v", "fallback": "\"Player\""}),
		"func list_or(v):",
		"\treturn %s" % _fill(by_id["ListOr"], {"value": "v", "fallback": "[9]"}),
		"func record_or(v):",
		"\treturn %s" % _fill(by_id["RecordOr"], {"value": "v", "fallback": "{\"d\": 1}"}),
		"func value_or(v):",
		"\treturn %s" % _fill(by_id["ValueOr"], {"value": "v", "fallback": "-1"}),
		"func part_y(v):",
		"\treturn %s" % _fill(by_id["PartOf"], {"value": "v", "part": "\"y\""}),
		"func part_z(v):",
		"\treturn %s" % _fill(by_id["PartOf"], {"value": "v", "part": "\"z\""}),
		"func part_a(v):",
		"\treturn %s" % _fill(by_id["PartOf"], {"value": "v", "part": "\"a\""}),
		"func part_named(v):",
		"\treturn %s" % _fill(by_id["PartOf"], {"value": "v", "part": "\"score\""}),
		"func set_part_vector() -> Vector2:",
		"\tvar heading := Vector2(3.0, 4.0)",
		"\t%s" % _fill(by_id["SetPartOf"], {"var_name": "heading", "part": "\"y\"", "value": "0.0"}),
		"\treturn heading",
		"func set_part_vector3() -> Vector3:",
		"\tvar facing := Vector3(1.0, 2.0, 3.0)",
		"\t%s" % _fill(by_id["SetPartOf"], {"var_name": "facing", "part": "\"y\"", "value": "0.0"}),
		"\treturn facing",
		"func set_part_color() -> Color:",
		"\tvar tint := Color(1.0, 1.0, 1.0, 1.0)",
		"\t%s" % _fill(by_id["SetPartOf"], {"var_name": "tint", "part": "\"a\"", "value": "0.25"}),
		"\treturn tint",
		"func set_part_record() -> Dictionary:",
		"\tvar save := {\"x\": 1}",
		"\t%s" % _fill(by_id["SetPartOf"], {"var_name": "save", "part": "\"y\"", "value": "5.0"}),
		"\treturn save",
		"func set_part_new_record() -> Dictionary:",
		"\tvar save := {}",
		"\t%s" % _fill(by_id["SetPartOf"], {"var_name": "save", "part": "\"y\"", "value": "5.0"}),
		"\treturn save",
		"",
	]
	return "\n".join(lines)


## The same write, aimed at a node's own property - the row this reading leads with.
static func _host_source(by_id: Dictionary) -> String:
	return "\n".join([
		"@tool",
		"extends Node2D",
		"func fade_out() -> void:",
		"\t%s" % _fill(by_id["SetPartOf"], {"var_name": "modulate", "part": "\"a\"", "value": "0.25"}),
		"",
	])


## The OTHER headline target: a CharacterBody2D's own `velocity`, zeroed on landing while the
## horizontal speed is kept. Written as its own host because `velocity` exists only there.
static func _body_source(by_id: Dictionary) -> String:
	return "\n".join([
		"@tool",
		"extends CharacterBody2D",
		"func land() -> Vector2:",
		"\tvelocity = Vector2(120.0, -300.0)",
		"\t%s" % _fill(by_id["SetPartOf"], {"var_name": "velocity", "part": "\"y\"", "value": "0.0"}),
		"\treturn velocity",
		"",
	])


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("fallbacks_test", label, actual, expected)
