# EventForge - the picker's "copy authoring stub" (right-click any ACE).
#
# The stub builder turns a live ACEDefinition back into the two provider dialects, and the
# whole point is that what it hands you WORKS when you paste it. So every pin here is an
# exact line VALUE built from a REAL registry descriptor, never a hand-built definition, and
# the last section pastes an emitted stub back into a provider script and re-reflects it -
# the only check that can prove the quoting rules are right rather than merely plausible.
#
# The traps these pins exist to catch, each verified against the parsers:
#   - an annotation value is read VERBATIM (first "(" to last ")", one quote pair trimmed),
#     so escaping an inner quote as \" ships the backslash into the emitted GDScript;
#   - the param spec splits on commas outside quotes and trims one quote pair off a default,
#     so a value that IS a quoted literal ships wrapped in a second pair;
#   - nothing in the pipeline unescapes "\n", so a multi-line template cannot ride a comment
#     annotation at all (the registrar's real GDScript string can);
#   - `pass` under a non-void return type is a parse error, so condition/expression skeletons
#     must return a value;
#   - a node-scoped ACE's SHIPPED template already carries the automatic {target.} prefix and
#     the injected "On node" param, which is plumbing and must not be re-emitted as vocabulary;
#   - a param description quoting something ("A key name like "Space"") still rides the one-line
#     spec, because the parser trims one surrounding pair and splits on commas outside quotes -
#     dropping it silently cost the params dialog the only help text it shows.
@tool
class_name ACEAuthoringStubTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)

	all_passed = _section("a node-scoped ACE ships its transformed template", _run_node_scoped(registry)) and all_passed
	all_passed = _section("labeled dropdown options keep their labels", _run_labeled_options(registry)) and all_passed
	all_passed = _section("a stateful condition hands over the descriptor chain", _run_stateful(registry)) and all_passed
	all_passed = _section("a multi-line template names the dialect it needs", _run_multiline(registry)) and all_passed
	all_passed = _section("a looping condition keeps its iterator and collection return", _run_looping()) and all_passed
	all_passed = _section("a quoted param description survives both dialects", _run_quoted_description(registry)) and all_passed
	all_passed = _section("the picker points at the notes a stub leads with", _run_note_hint(registry)) and all_passed
	all_passed = _section("an emitted stub reflects back into the same definition", _run_paste_round_trip(registry)) and all_passed
	return all_passed


## One visible line per section, so the suite log shows this test RAN rather than only showing
## it when it breaks (a silent test and a test that never loaded read identically).
static func _section(label: String, passed: bool) -> bool:
	if passed:
		print("[PASS] ace_authoring_stub_test: %s" % label)
	return passed


## Queue Animation is node-scoped to AnimationPlayer and got the automatic target prefix, so it
## pins the shipped-not-authored template, the injected param staying out of the vocabulary, and
## a default that is itself a quoted literal.
static func _run_node_scoped(registry: EventSheetACERegistry) -> bool:
	var all_passed: bool = true
	var definition: ACEDefinition = registry.find_definition("Core", "QueueAnimation")
	if definition == null:
		return _check("Core::QueueAnimation is registered", false, true)
	var stub: String = EventSheetACEAnnotationStub.comment_stub(definition)
	all_passed = _check("the node-scope note names the class and the descriptor field",
		_line_starting_with(stub, "# NODE-SCOPED"),
		"# NODE-SCOPED (AnimationPlayer): node scoping is a descriptor field (node_type), which neither") and all_passed
	all_passed = _check("the note says the prefix and the On node param arrive by themselves",
		_line_starting_with(stub, "# dialect annotates. The template below"),
		"# dialect annotates. The template below is the SHIPPED one: registration added the \"{target.}\"") and all_passed
	all_passed = _check("the shipped template ships as-is, quotes unescaped",
		_line_starting_with(stub, "## @ace_codegen_template("),
		"## @ace_codegen_template(\"{target.}queue({animation})\")") and all_passed
	all_passed = _check("a quoted-literal default ships wrapped in a second quote pair",
		_line_starting_with(stub, "## @ace_param(animation"),
		"## @ace_param(animation, hint: expression, default: \"\"idle\"\", desc: \"The clip to play once the current one finishes.\")") and all_passed
	all_passed = _check("the injected On node param is plumbing, not vocabulary",
		_line_starting_with(stub, "## @ace_param(target"), "") and all_passed
	all_passed = _check("the authored row caption survives",
		_line_starting_with(stub, "## @ace_display_template("),
		"## @ace_display_template(\"queue animation {animation}\")") and all_passed
	all_passed = _check("the member skeleton drops the injected param too",
		_tail_lines(stub, 2), "func queue_animation(animation: String) -> void:\n\tpass") and all_passed

	var registrar: String = EventSheetACEAnnotationStub.registrar_stub(definition)
	all_passed = _check("the registrar template escapes as real GDScript",
		_line_starting_with(registrar, "\t\t.template("),
		"\t\t.template(\"{target.}queue({animation})\")") and all_passed
	all_passed = _check("the registrar says where a starting value comes from",
		_line_starting_with(registrar, "# STARTING VALUES"),
		"# STARTING VALUES: reg.param() carries hint/options/autocomplete/desc only. The value a row") and all_passed
	return all_passed


## Is Within Distance (choose metric) is the shipped labeled-dropdown condition: its options
## READ as English and INSERT an index into an inline array. It is also node-scoped WITHOUT a
## target, because its template opens with "(" rather than a member operation.
static func _run_labeled_options(registry: EventSheetACERegistry) -> bool:
	var all_passed: bool = true
	var definition: ACEDefinition = registry.find_definition("Core", "IsWithinDistanceMetric")
	if definition == null:
		return _check("Core::IsWithinDistanceMetric is registered", false, true)
	var stub: String = EventSheetACEAnnotationStub.comment_stub(definition)
	all_passed = _check("labels survive the comment dialect, keys still insert",
		_line_starting_with(stub, "## @ace_param(metric"),
		"## @ace_param(metric, options: 0=Straight line|1=Horizontal only|2=Vertical only|3=Grid steps|4=King moves, default: 0, desc: \"How the distance is counted - the platformer leash wants Horizontal only, the roguelike wants Grid steps.\")") and all_passed
	all_passed = _check("a template that is not a member operation gets no target",
		_line_starting_with(stub, "# dialect annotates. This template"),
		"# dialect annotates. This template got NO \"{target.}\" prefix and no \"On node\" param:") and all_passed
	all_passed = _check("a bare expression default ships unquoted",
		_line_starting_with(stub, "## @ace_param(other"),
		"## @ace_param(other, hint: expression, default: get_parent(), desc: \"The other node.\")") and all_passed
	all_passed = _check("the condition skeleton returns a value instead of falling through",
		_tail_lines(stub, 2),
		"func is_within_distance_metric(other: String, distance: String, metric: String) -> bool:\n\treturn false") and all_passed

	var registrar: String = EventSheetACEAnnotationStub.registrar_stub(definition)
	all_passed = _check("the registrar keeps options in their key/label dict form",
		_line_starting_with(registrar, "\t\t.param(\"metric\""),
		"\t\t.param(\"metric\", {\"options\": [{\"key\": \"0\", \"label\": \"Straight line\"}, {\"key\": \"1\", \"label\": \"Horizontal only\"}, {\"key\": \"2\", \"label\": \"Vertical only\"}, {\"key\": \"3\", \"label\": \"Grid steps\"}, {\"key\": \"4\", \"label\": \"King moves\"}], \"desc\": \"How the distance is counted - the platformer leash wants Horizontal only, the roguelike wants Grid steps.\"})") and all_passed
	return all_passed


## Every X Seconds owns a per-row member, which NEITHER dialect can declare - so the stub has to
## hand over the descriptor chain that can, plus the three rules that come with it.
static func _run_stateful(registry: EventSheetACERegistry) -> bool:
	var all_passed: bool = true
	var definition: ACEDefinition = registry.find_definition("Core", "EveryXSeconds")
	if definition == null:
		return _check("Core::EveryXSeconds is registered", false, true)
	var stub: String = EventSheetACEAnnotationStub.comment_stub(definition)
	all_passed = _check("the stateful note names the dialect gap",
		_line_starting_with(stub, "# STATEFUL:"),
		"# STATEFUL: this ACE owns per-row memory, which is a DESCRIPTOR feature - neither the ## @ace_*") and all_passed
	all_passed = _check("the note hands over this ACE's own stateful chain",
		_line_starting_with(stub, "#   F.make_descriptor"),
		"#   F.make_descriptor(...).stateful(\"var __every_{uid}: float = 0.0\", \"__every_{uid} += get_process_delta_time()\", \"__every_{uid} = fmod(__every_{uid}, maxf({seconds}, 0.001))\")") and all_passed
	all_passed = _check("the note states where {uid} is baked",
		_line_starting_with(stub, "# Every local it declares"),
		"# Every local it declares must carry {uid}, which the dock bakes fresh at apply time and the") and all_passed
	all_passed = _check("the note points at the standalone-compile gate",
		_line_starting_with(stub, "# the ace_id belongs"),
		"# the ace_id belongs in NOT_STANDALONE in tests/builtin_ace_compile_test.gd or that gate fails.") and all_passed
	all_passed = _check("a plain numeric default ships unquoted",
		_line_starting_with(stub, "## @ace_param(seconds"),
		"## @ace_param(seconds, hint: expression, default: 1.0, desc: \"Interval between runs (needs a per-frame trigger).\")") and all_passed
	all_passed = _check("the registrar carries the same stateful note",
		_line_starting_with(EventSheetACEAnnotationStub.registrar_stub(definition), "# STATEFUL:"),
		"# STATEFUL: this ACE owns per-row memory, which is a DESCRIPTOR feature - neither the ## @ace_*") and all_passed

	# Trigger Once is the hoisted edge gate: its chain has to carry .evaluated_last() too.
	var gate: ACEDefinition = registry.find_definition("Core", "TriggerOnce")
	if gate == null:
		return _check("Core::TriggerOnce is registered", false, true) and all_passed
	var gate_chain: String = _line_starting_with(EventSheetACEAnnotationStub.comment_stub(gate), "#   F.make_descriptor")
	all_passed = _check("an edge gate's chain ends in evaluated_last",
		gate_chain.right(18), ").evaluated_last()") and all_passed
	all_passed = _check("the gate's multi-line member is escaped onto the note line",
		gate_chain.contains("\\n\\nfunc __trigger_once_{uid}() -> bool:"), true) and all_passed
	return all_passed


## Tween Camera FOV is a real multi-line template. The registrar can carry it (a GDScript
## string); the comment dialect cannot, and must say so rather than shipping a silent lie.
static func _run_multiline(registry: EventSheetACERegistry) -> bool:
	var all_passed: bool = true
	var definition: ACEDefinition = registry.find_definition("Core", "TweenCameraFov")
	if definition == null:
		return _check("Core::TweenCameraFov is registered", false, true)
	var stub: String = EventSheetACEAnnotationStub.comment_stub(definition)
	all_passed = _check("the comment dialect admits it cannot carry a newline",
		_line_starting_with(stub, "# MULTI-LINE TEMPLATE"),
		"# MULTI-LINE TEMPLATE: one annotation is one line, and a \"\\n\" written into it stays two") and all_passed
	all_passed = _check("the escaped one-line form is still shown, quotes untouched",
		_line_starting_with(stub, "## @ace_codegen_template("),
		"## @ace_codegen_template(\"var __fovcam_{uid} := get_viewport().get_camera_3d()\\nif __fovcam_{uid} != null:\\n\\tcreate_tween().tween_property(__fovcam_{uid}, \"fov\", clampf({degrees}, 1.0, 179.0), {duration}).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\")") and all_passed
	var registrar: String = EventSheetACEAnnotationStub.registrar_stub(definition)
	all_passed = _check("the registrar carries the same template as escaped GDScript",
		_line_starting_with(registrar, "\t\t.template("),
		"\t\t.template(\"var __fovcam_{uid} := get_viewport().get_camera_3d()\\nif __fovcam_{uid} != null:\\n\\tcreate_tween().tween_property(__fovcam_{uid}, \\\"fov\\\", clampf({degrees}, 1.0, 179.0), {duration}).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\")") and all_passed
	all_passed = _check("the registrar needs no multi-line warning",
		_line_starting_with(registrar, "# MULTI-LINE TEMPLATE"), "") and all_passed
	return all_passed


## For Each Buff (the shipped StatForge pack) is a LOOPING condition: it returns the collection
## the event loops over, so the stub must keep the annotation, the iterator, and a return type
## that is not bool - and must say the registrar has no verb for any of it.
static func _run_looping() -> bool:
	var all_passed: bool = true
	var pack: Node = load("res://eventsheet_addons/stat_forge/stat_forge_behavior.gd").new()
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([pack], false)
	var definition: ACEDefinition = registry.find_definition("StatForge", "method:each_buff")
	if definition == null:
		pack.free()
		return _check("StatForge::method:each_buff is registered", false, true)
	var stub: String = EventSheetACEAnnotationStub.comment_stub(definition)
	all_passed = _check("the looping annotation keeps its iterator",
		_line_starting_with(stub, "## @ace_looping"), "## @ace_looping(buff_id)") and all_passed
	all_passed = _check("a looping condition returns its collection, not a bool",
		_tail_lines(stub, 2), "func each_buff() -> Array:\n\treturn Array()") and all_passed
	all_passed = _check("the registrar admits it has no looping verb",
		_line_starting_with(EventSheetACEAnnotationStub.registrar_stub(definition), "# LOOPING:"),
		"# LOOPING: the registrar has no looping verb. Keep \"## @ace_looping(buff_id)\" as a comment") and all_passed
	pack.free()
	return all_passed


## Keycode From Name's help text quotes two key names, and ten shipped built-ins are spelled the same
## way. A description like that RIDES the one-line spec - the parser trims one surrounding pair and
## splits on commas outside quotes, so a balanced inner pair comes back whole - and dropping it left
## the params dialog with no help text at all. The pasted round-trip below proves the claim rather
## than asserting it, and the rule itself is pinned on the three shapes that decide it.
static func _run_quoted_description(registry: EventSheetACERegistry) -> bool:
	var all_passed: bool = true
	var definition: ACEDefinition = registry.find_definition("Core", "KeycodeFromName")
	if definition == null:
		return _check("Core::KeycodeFromName is registered", false, true)
	var stub: String = EventSheetACEAnnotationStub.comment_stub(definition)
	all_passed = _check("a quoted description rides the comment dialect",
		_line_starting_with(stub, "## @ace_param(name"),
		"## @ace_param(name, hint: expression, default: \"\"Space\"\", desc: \"A key name like \"Space\" or \"A\".\")") and all_passed
	all_passed = _check("and nothing had to be noted about it",
		_line_starting_with(stub, "# PARAM HELP"), "") and all_passed
	all_passed = _check("the registrar escapes the same text as real GDScript",
		_line_starting_with(EventSheetACEAnnotationStub.registrar_stub(definition), "\t\t.param(\"name\""),
		"\t\t.param(\"name\", {\"hint\": EventForgeRegistrar.EXPRESSION, \"desc\": \"A key name like \\\"Space\\\" or \\\"A\\\".\"})") and all_passed

	var pasted: ACEDefinition = _paste_and_reflect(registry, "KeycodeFromName", "user://__stub_paste_keycode.gd", "method:keycode_from_name")
	if pasted == null:
		return _check("the pasted Keycode From Name stub reflects back", false, true) and all_passed
	all_passed = _check("the quoted help text round-trips through the parser, quotes and all",
		str((pasted.parameters[0] as Dictionary).get("description", "")), "A key name like \"Space\" or \"A\".") and all_passed

	# The rule itself: what the spec can carry, and the two shapes it cannot.
	all_passed = _check("a balanced inner pair is carryable",
		EventSheetACEAnnotationStub._description_survives_one_line("A key name like \"Space\" or \"A\"."), true) and all_passed
	all_passed = _check("an unbalanced quote is not",
		EventSheetACEAnnotationStub._description_survives_one_line("Press \" to open."), false) and all_passed
	all_passed = _check("nor is a comma inside the first quoted phrase",
		EventSheetACEAnnotationStub._description_survives_one_line("A key name like \"Space, Enter\"."), false) and all_passed
	return all_passed


## The picker's status line after a copy. A stub that LEADS with plain `#` notes is the one whose
## dialect could not declare everything, and those notes are the part most easily pasted past.
static func _run_note_hint(registry: EventSheetACERegistry) -> bool:
	var all_passed: bool = true
	var stateful: ACEDefinition = registry.find_definition("Core", "EveryXSeconds")
	var plain: ACEDefinition = registry.find_definition("Core", "KeycodeFromName")
	if stateful == null or plain == null:
		return _check("both sample ACEs are registered", false, true)
	all_passed = _check("a note-carrying stub says to read the notes",
		ACEPickerDialog._stub_note_hint(EventSheetACEAnnotationStub.comment_stub(stateful)),
		" Read the # notes on top first - this one needs more than the dialect can declare.") and all_passed
	all_passed = _check("a stub that starts with its ## description says nothing extra",
		ACEPickerDialog._stub_note_hint(EventSheetACEAnnotationStub.comment_stub(plain)), "") and all_passed
	return all_passed


## The proof the rest of the pins are ABOUT something: paste an emitted stub into a provider
## script, reflect it back, and the definition that comes out must carry the same template,
## the same starting value and the same labeled options as the ACE it was copied from.
static func _run_paste_round_trip(registry: EventSheetACERegistry) -> bool:
	var all_passed: bool = true
	var animation: ACEDefinition = _paste_and_reflect(registry, "QueueAnimation", "user://__stub_paste_queue.gd", "method:queue_animation")
	if animation == null:
		return _check("the pasted Queue Animation stub reflects back", false, true)
	all_passed = _check("the pasted template round-trips verbatim",
		str(animation.metadata.get("codegen_template", "")), "{target.}queue({animation})") and all_passed
	all_passed = _check("the pasted quoted default round-trips as a quoted literal",
		str((animation.parameters[0] as Dictionary).get("default_value", "")), "\"idle\"") and all_passed
	all_passed = _check("the pasted caption round-trips",
		str(animation.metadata.get("display_template", "")), "queue animation {animation}") and all_passed

	var metric: ACEDefinition = _paste_and_reflect(registry, "IsWithinDistanceMetric", "user://__stub_paste_metric.gd", "method:is_within_distance_metric")
	if metric == null:
		return _check("the pasted metric stub reflects back", false, true) and all_passed
	all_passed = _check("the pasted labels round-trip with their keys",
		_option_signature(metric.parameters[2]),
		"0=Straight line|1=Horizontal only|2=Vertical only|3=Grid steps|4=King moves") and all_passed
	all_passed = _check("the pasted condition kind survives", metric.ace_type, ACEDefinition.ACEType.CONDITION) and all_passed
	all_passed = _check("the pasted inline-array template round-trips whole",
		str(metric.metadata.get("codegen_template", "")).right(27), "]) <= maxf({distance}, 0.0)") and all_passed
	return all_passed


## Writes one ACE's comment stub into a provider script, reflects it, and returns the
## definition it produced (null when the pasted stub does not even parse).
static func _paste_and_reflect(registry: EventSheetACERegistry, ace_id: String, path: String, member_id: String) -> ACEDefinition:
	var source: ACEDefinition = registry.find_definition("Core", ace_id)
	if source == null:
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("extends Node\n\n\n%s\n" % EventSheetACEAnnotationStub.comment_stub(source))
	file.close()
	var script: Script = load(path)
	if script == null:
		return null
	var instance: Object = script.new()
	var pasted_registry: EventSheetACERegistry = EventSheetACERegistry.new()
	pasted_registry.refresh_from_sources([instance], false)
	var provider_id: String = path.get_file().get_basename().to_pascal_case()
	var definition: ACEDefinition = pasted_registry.find_definition(provider_id, member_id)
	if instance is Node:
		(instance as Node).free()
	DirAccess.remove_absolute(path)
	return definition


## One parameter's dropdown as `key=label|key=label`, so a drifted key OR a lost label reads
## as a plain diff instead of a Dictionary dump.
static func _option_signature(parameter: Variant) -> String:
	var entries: PackedStringArray = PackedStringArray()
	for option_entry in (parameter as Dictionary).get("options", []):
		var option: Dictionary = option_entry
		entries.append("%s=%s" % [str(option.get("key", "")), str(option.get("label", ""))])
	return "|".join(entries)


## The first line whose text starts with `prefix`, or "" when the stub has none. Registrar chain
## lines carry the trailing line-continuation, which is joining punctuation rather than content,
## so it is trimmed off before the comparison.
static func _line_starting_with(stub: String, prefix: String) -> String:
	for line: String in stub.split("\n"):
		if line.begins_with(prefix):
			return line.trim_suffix(" \\")
	return ""


static func _tail_lines(stub: String, count: int) -> String:
	var lines: PackedStringArray = stub.split("\n")
	var start: int = maxi(0, lines.size() - count)
	var tail: PackedStringArray = PackedStringArray()
	for index: int in range(start, lines.size()):
		tail.append(lines[index])
	return "\n".join(tail)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] ace_authoring_stub_test: %s" % label)
	print("    expected: %s" % str(expected))
	print("    actual:   %s" % str(actual))
	return false
