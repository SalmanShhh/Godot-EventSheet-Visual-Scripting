# Godot EventSheets - the FORWARDING ADDRESSES, and the fixtures they write for themselves.
#
# A forwarding address is a promise about somebody's existing sheet: the row you already wrote can be
# rewritten as this other row, and land complete. The promise is only worth making if every address
# keeps it, and the way an address stops keeping it is by being added without a test.
#
# So nothing here is written per address. The harness walks EVERY successor map in the installed
# vocabulary - built-ins and packs alike - plus a small table written here with real templates, so it
# goes on proving something on the day the shipped vocabulary carries none. For each map it:
#   1. BUILDS a row on the old spelling, filling each of its parameters with the value the verb
#      itself starts on, or a sample where the verb asks the author to say;
#   2. applies the rewrite the map describes, resolved to the end of its chain;
#   3. emits the successor row through the REAL emitter (ActionCodegen / ConditionCodegen), compiles
#      it inside a one-row sheet through the real compiler, pins that the two agree, and PUTS THE
#      COMPILED FILE THROUGH GODOT'S OWN PARSER - the step the migrate dialog runs before it commits,
#      and the one a harness that stopped at "the text contains the line" cannot see;
#   4. checks that every value the old row carried arrived, that no slot was left unfilled, and that
#      emitting twice writes the same byte.
# A map that names a verb nobody has, points at itself, joins a cycle, renames a parameter neither
# side has, or leaves a successor parameter unanswered fails `problems()` before any of that - which
# is what "an address cannot exist untested" means in practice, and is the same list the pack gate
# refuses to ship on.
@tool
class_name SuccessorMapTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## The token a parameter the old verb asks the author to fill gets in the generated fixture. An
## identifier rather than prose, so the emitted line is a line somebody could have written.
const SAMPLE_PREFIX: String = "mg_"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_vocabulary_is_sound() and ok
	ok = _test_the_annotation() and ok
	ok = _test_the_builder() and ok
	ok = _test_the_shipped_addresses() and ok
	ok = _test_a_hand_written_line_reads_as_the_current_verb() and ok
	ok = _test_the_sheet_says_it_quietly() and ok
	ok = _test_generated_fixtures() and ok
	ok = _test_the_engine() and ok
	ok = _test_a_broken_map_is_named() and ok
	return ok


## The whole installed vocabulary, held to the gate the pack audit fails on. Empty is the only
## shipping state.
static func _test_the_vocabulary_is_sound() -> bool:
	var known: Dictionary = EventForgeSuccessors.catalog()
	var ok: bool = _check("the vocabulary is found", known.size() > 100, true)
	ok = _check("every forwarding address in it is sound",
		EventForgeSuccessors.problems(known), PackedStringArray()) and ok
	return ok


## The annotation route, read the way the editor reads it: off a REAL file. A GDScript built from a
## source string in memory has no `resource_path`, and the analyzer reads annotations off disk - so a
## round-trip written that way would pass for the wrong reason.
static func _test_the_annotation() -> bool:
	var path: String = "user://_successor_annotation_probe.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(PackedStringArray([
		"@tool",
		"extends RefCounted",
		"",
		"",
		"## @ace_action",
		"## @ace_name(\"Travel to state\")",
		"## @ace_succeeded_by(Core::GoToState, renames: destination=state, defaults: seconds=1.0)",
		"func travel_to_state(destination: String) -> void:",
		"\tprint(destination)",
		"",
	])))
	file.close()
	var script: GDScript = load(path)
	var ok: bool = _check("the probe script loads", script != null, true)
	if not ok:
		return false
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	var carried: Dictionary = {}
	for definition: ACEDefinition in generator.generate_from_object(script.new()):
		if definition.id == "method:travel_to_state":
			carried = EventForgeSuccessors.map_of(definition)
	ok = _check("the annotation says the three things and no more", carried,
		{"id": "Core::GoToState", "renames": {"destination": "state"}, "defaults": {"seconds": "1.0"}}) and ok
	DirAccess.remove_absolute(path)
	# And the grammar's edges, asked of the reader directly rather than through a file each time.
	var analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
	ok = _check("the id may be written with its key",
		analyzer._parse_successor_spec("id: Core::GoToState"),
		{"id": "Core::GoToState", "renames": {}, "defaults": {}}) and ok
	ok = _check("several pairs split on the bar, not the comma",
		analyzer._parse_successor_spec("P::B, renames: one=two|three=four"),
		{"id": "P::B", "renames": {"one": "two", "three": "four"}, "defaults": {}}) and ok
	ok = _check("and an annotation naming no successor is not an address",
		analyzer._parse_successor_spec("renames: one=two"), {}) and ok
	# THE TWO READERS OF THAT LINE HAVE TO AGREE. The analyzer builds the live vocabulary from it and
	# the lifter re-emits it, so a comma one of them reads as a separator and the other as a
	# character of a string literal is a file that comes back different - and the per-function byte
	# gate then degrades the whole function to a verbatim block.
	var spec: String = "P::B, renames: one=two, defaults: msg=\"a,b\"|n=2"
	ok = _check("a comma inside a default's string literal is not a separator",
		analyzer._parse_successor_spec(spec),
		{"id": "P::B", "renames": {"one": "two"}, "defaults": {"msg": "\"a,b\"", "n": "2"}}) and ok
	ok = _check("and the lifter reads that line exactly the same way",
		EventSheetACELifter._parse_successor_annotation(spec),
		{"successor_ace_id": "P::B", "successor_param_renames": {"one": "two"},
			"successor_param_defaults": {"msg": "\"a,b\"", "n": "2"}}) and ok
	return ok


## The builder route - the built-in half of the same fact, set where the descriptor is CONSTRUCTED
## because descriptors are normalized once and shared for the whole session.
static func _test_the_builder() -> bool:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	var ok: bool = _check("a verb with no address has no map", descriptor.successor_map(), {})
	descriptor.succeeded_by("Core::GoToState", {"next": "state"}, {"seconds": "1.0"})
	ok = _check("and .succeeded_by() writes the same three keys the annotation does",
		descriptor.successor_map(),
		{"id": "Core::GoToState", "renames": {"next": "state"}, "defaults": {"seconds": "1.0"}}) and ok
	ok = _check("a forwarding address is not a deprecation", descriptor.is_deprecated, false) and ok
	ok = _check("and says nothing in the deprecation note", descriptor.deprecation_note(), "") and ok
	return ok


## THE FOUR ADDRESSES THE VOCABULARY SHIPS, pinned by value rather than counted, so a fifth one
## added later has to come here and say what it is.
##
## All four are the same story. They landed on the general shelf the day before the Audio shelf
## existed; the Audio module then authored the same four questions on the page a reader looks for
## them on, against the same node type, with the same parameters and the same emitted call, and the
## two spellings have sat side by side ever since. Nothing about the older four changed when the
## address was written on them: same id, same template, same place in the picker, same emitted byte.
##
## The State Machine pack is the pair that looked exactly as plausible and is NOT here, which is the
## other half of what this test pins. Its Go to state and Current state is ask the same questions the
## object-state Go To State and Is In State ask, but they keep the answer somewhere else: this pack's
## parameter is a state NAME, so a row holds the quoted literal a text field writes; the object-state
## parameter is a member of the object's own State enum, so a row holds a bare name. A map may say
## three things and none of them converts one into the other, so the rewrite emitted
## `state = State."chasing"` and the file gate refused every real row. And the second reason, which no
## value conversion would have fixed: those four verbs are one machine. Time in state reads the clock
## Go to state stamps and On any state change rides the signal it emits, and neither has an honest
## address - so forwarding the other two would have left a machine that still compiles and no longer
## works.
static func _test_the_shipped_addresses() -> bool:
	var known: Dictionary = EventForgeSuccessors.catalog()
	var addressed: PackedStringArray = PackedStringArray()
	for key: Variant in known.keys():
		if not EventForgeSuccessors.normalize_map((known[key] as Dictionary).get("map", {})).is_empty():
			addressed.append(str(key))
	addressed.sort()
	var ok: bool = _check("the shipped vocabulary carries exactly these forwarding addresses", addressed,
		PackedStringArray(["Core::IsAudioPlaying", "Core::PlayAudio", "Core::SetVolumeDb",
			"Core::StopAudio"]))
	ok = _check("Play Sound forwards to Play, renaming its one parameter",
		EventForgeSuccessors.resolve("Core::PlayAudio", known),
		{"id": "Core::AudioPlay", "renames": {"from_position": "from"}, "defaults": {},
			"hops": PackedStringArray(["Core::AudioPlay"])}) and ok
	ok = _check("Stop Sound forwards to Stop with nothing to rename",
		EventForgeSuccessors.resolve("Core::StopAudio", known),
		{"id": "Core::AudioStop", "renames": {}, "defaults": {},
			"hops": PackedStringArray(["Core::AudioStop"])}) and ok
	ok = _check("Set Volume (dB) forwards to Set Volume",
		EventForgeSuccessors.resolve("Core::SetVolumeDb", known),
		{"id": "Core::AudioSetVolume", "renames": {}, "defaults": {},
			"hops": PackedStringArray(["Core::AudioSetVolume"])}) and ok
	ok = _check("and Sound Is Playing forwards to Is Playing",
		EventForgeSuccessors.resolve("Core::IsAudioPlaying", known),
		{"id": "Core::AudioIsPlaying", "renames": {}, "defaults": {},
			"hops": PackedStringArray(["Core::AudioIsPlaying"])}) and ok
	# NOTHING ABOUT THE OLDER VERB MOVED. An address is written beside a frozen row, never over it.
	ok = _check("and the older row keeps the template it always had",
		str((known["Core::PlayAudio"] as Dictionary)["template"]), "{target.}play({from_position})") and ok
	ok = _check("as does the newer one",
		str((known["Core::AudioPlay"] as Dictionary)["template"]), "{target.}play({from})") and ok
	# Playback Position is the fifth row of the same family and is deliberately unaddressed: an
	# expression is not a row, so nothing could ever act on the address.
	ok = _check("the expression beside them points nowhere",
		EventForgeSuccessors.resolve("Core::GetPlaybackPosition", known), {}) and ok
	for key: String in ["StateMachineBehavior::method:set_state",
			"StateMachineBehavior::method:is_in_state",
			"StateMachineBehavior::method:time_in_state",
			"StateMachineBehavior::signal:state_changed"]:
		ok = _check("%s points nowhere - the machine's four verbs stay together" % key,
			EventForgeSuccessors.resolve(key, known), {}) and ok
	var go_to: Dictionary = known["StateMachineBehavior::method:set_state"]
	ok = _check("and that pack keeps the template it always had",
		str(go_to["template"]), "{target}.set_state({next})") and ok
	return ok


## THE PROMISE THAT AN OPENED `.gd` FILE GAINS NO MIGRATION ROW, asked of a real file.
##
## All four audio addresses join a retired verb to a current one whose template is the same line to
## the character: `{target.}play({from_position})` and `{target.}play({from})` differ only in what a
## slot is called. Both are in the lifter's reverse index at exactly equal specificity, so which of
## them claims a hand-written `$Sfx.play(0.5)` used to be settled by registration order - which is
## module file name order, which put the retired spelling first by the alphabet alone. A file opened
## that way reads back on the retired verb and grows a migration row that nothing about the file
## asked for.
##
## So the four lines are lifted out of a REAL file (the lifter reads text off disk, and a fixture
## built in memory is not the thing the promise is about; the branch's own `print` comes along and is
## pinned with them rather than trimmed out), the id each row landed on is pinned, and
## the migration plan over the whole sheet is pinned EMPTY - the same question the head band asks
## before it offers anybody a rewrite.
static func _test_a_hand_written_line_reads_as_the_current_verb() -> bool:
	var path: String = "user://_successor_audio_lift_probe.gd"
	var source: String = "extends Node\n\n\nfunc _ready() -> void:\n\t$Sfx.play(0.5)\n\t$Sfx.stop()\n\t$Sfx.volume_db = -6.0\n\tif $Sfx.playing:\n\t\tprint(\"still going\")\n"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _check("the probe file can be written", false, true)
	file.store_string(source)
	file.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var ok: bool = _check("the probe file opens as a sheet", sheet != null, true)
	if sheet == null:
		return false
	var landed: PackedStringArray = PackedStringArray()
	_collect_ids(sheet.events, landed)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			_collect_ids((entry as EventFunction).events, landed)
	ok = _check("every audio line reads back as the verb the vocabulary writes today",
		landed, PackedStringArray(["Core::AudioPlay", "Core::AudioStop", "Core::AudioSetVolume",
			"Core::AudioIsPlaying", "Core::PrintLog"])) and ok
	# And the whole point of the pin above: nothing about opening this file asks anybody for anything.
	ok = _check("so the file gains no migration row at all",
		EventSheetMigrationPlan.plan(sheet).size(), 0) and ok
	# The lossless contract over the same file, because a lift that read well and re-emitted badly
	# would be a worse bug than the one this test is about.
	sheet.external_source_path = path
	ok = _check("and re-emits byte for byte",
		str(SheetCompiler.compile(sheet, path).get("output", "")), source) and ok
	DirAccess.remove_absolute(path)
	# AND THE RULE ITSELF, asked where the alphabet cannot answer it. The four pins above hold today
	# for a reason nobody chose: `audio_aces.gd` sorts before `collection_aces.gd`, so the current
	# spelling is registered first and wins the tie on registration order. Rename either module and
	# they all invert, silently. So the reverse index is composed here over a pair registered the
	# OTHER way round - the superseded verb first - and the current spelling still has to come out in
	# front of it.
	var retired: ACEDescriptor = ACEDescriptor.new()
	retired.provider_id = "P"
	retired.ace_id = "Retired"
	retired.ace_type = ACEDescriptor.ACEType.ACTION
	retired.codegen_template = "ring({old_name})"
	retired.succeeded_by("P::Current", {"old_name": "name"})
	var current: ACEDescriptor = ACEDescriptor.new()
	current.provider_id = "P"
	current.ace_id = "Current"
	current.ace_type = ACEDescriptor.ACEType.ACTION
	current.codegen_template = "ring({name})"
	var composed: Array = EventSheetACELifter._compose_reverse_entries([retired, current])
	var sorted_ids: PackedStringArray = PackedStringArray()
	for entry: Variant in composed:
		sorted_ids.append(str((entry as Dictionary).get("ace_id", "")))
	ok = _check("a superseded spelling never wins a tie, whatever order it was registered in",
		sorted_ids, PackedStringArray(["Current", "Retired"])) and ok
	return ok


## Every verb id a lifted sheet's rows landed on, in reading order - conditions before actions, and
## sub-events after the event they hang under, which is the order a reader counts in.
static func _collect_ids(items: Array, into: PackedStringArray) -> void:
	for item: Variant in items:
		if not (item is EventRow):
			continue
		var event_row: EventRow = item as EventRow
		for condition: ACECondition in event_row.conditions:
			if not condition.ace_id.is_empty():
				into.append("%s::%s" % [condition.provider_id, condition.ace_id])
		for action: Variant in event_row.actions:
			if action is ACEAction and not (action as ACEAction).ace_id.is_empty():
				into.append("%s::%s" % [(action as ACEAction).provider_id,
					(action as ACEAction).ace_id])
		_collect_ids(event_row.sub_events, into)


## THE QUIET SHEET LAW, asked of the one thing this slice puts on screen, in its two halves.
##
## THE SHEET: a row whose verb has been superseded grows NOTHING - no block, no icon, no inline text,
## not even the amber state - because it is not wrong and still compiles exactly as written. Asked
## here of a real dock over a real row on a really superseded verb, which is the state the law is
## about: the muted line exists, and the sheet still shows none of it.
##
## THE STRIP: the one place the words are allowed to appear, and it names the successor by the words
## a picker reads out rather than by its id, because what the reader is being told is what they would
## write.
static func _test_the_sheet_says_it_quietly() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "StopAudio"
	action.codegen_template = "{target.}stop()"
	action.params = {"target": "$AudioStreamPlayer"}
	event.actions.append(action)
	sheet.events.append(event)
	dock.setup(sheet)
	var row: EventRowData = dock._viewport._root_rows[0]
	var ok: bool = _check("a row on a superseded verb carries the muted line",
		row.successor_hint, "newer spelling: Stop")
	ok = _check("wears no amber state", row.attention_note, "") and ok
	ok = _check("and hangs nothing under itself", row.children.size(), 0) and ok
	# And a row on a verb that is the current spelling says nothing at all.
	var current: EventRow = EventRow.new()
	current.trigger_provider_id = "Core"
	current.trigger_id = "OnReady"
	var newer: ACEAction = ACEAction.new()
	newer.provider_id = "Core"
	newer.ace_id = "AudioStop"
	newer.codegen_template = "{target.}stop()"
	newer.params = {"target": "$AudioStreamPlayer"}
	current.actions.append(newer)
	sheet.events.append(current)
	dock.setup(sheet)
	ok = _check("while a row on the current spelling says nothing at all",
		dock._viewport._root_rows[1].successor_hint, "") and ok
	# The strip, over the superseded row itself.
	dock._update_row_help_strip(dock._viewport._root_rows[0])
	ok = _check("selecting a superseded row puts the muted line on the strip",
		dock._row_help_label.text, "newer spelling: Stop") and ok
	ok = _check("and shows it", dock._row_help_label.visible, true) and ok
	ok = _check("muted rather than in the warning colour",
		dock._row_help_label.modulate, EventSheetActiveTheme.reading().muted_text_color) and ok
	# No door: following an address is an edit somebody approves, offered from the head band, not a
	# button under one row.
	ok = _check("with no door beside it", dock._row_help_button.visible, false) and ok
	dock._update_row_help_strip(EventRowData.new())
	ok = _check("and a row whose verb is the current one says nothing at all",
		dock._row_help_label.visible, false) and ok
	dock.free()
	return ok


## The generated corpus. Every line printed here is one this harness invented from the map itself,
## so the printout doubles as the list of rewrites the plugin claims it can make.
##
## Two populations: every installed map, plus a small table written HERE with real templates. The
## second one is not redundancy - a harness whose only corpus is the shipped one quietly becomes an
## assertion about nothing the day the last address is withdrawn, and would be no readier to catch
## the next bad address than it was to catch the first.
static func _test_generated_fixtures() -> bool:
	var known: Dictionary = EventForgeSuccessors.catalog()
	var ok: bool = true
	var probed: int = 0
	for key: String in _addressed_keys(known):
		ok = _test_one_map(key, known) and ok
		probed += 1
	# A value, not a count of a live tree: whatever the vocabulary carries is what was walked, and an
	# address added later is walked above without this line moving.
	ok = _check("every installed forwarding address was probed", probed,
		_addressed_keys(known).size()) and ok
	# And the written table, which does carry one, so the whole walk above is exercised either way.
	var written: Dictionary = _probe_table()
	for key: String in _addressed_keys(written):
		ok = _test_one_map(key, written) and ok
	ok = _check("the written table is sound too",
		EventForgeSuccessors.problems(written), PackedStringArray()) and ok
	# THE GATE ITSELF, pinned on the exact shape that got past the old harness: a value a text field
	# writes, landing in a slot the successor spells as a name.
	ok = _check("a quoted literal in a slot spelled as a name is not GDScript",
		EventSheetMigrationPlan.parses("extends Node


func _ready() -> void:
	state = State.\"chasing\"
"),
		false) and ok
	ok = _check("and the same line with a name in it is",
		EventSheetMigrationPlan.parses("extends Node


enum State { CHASING }

var state: State = State.CHASING


func _ready() -> void:
	state = State.CHASING
"),
		true) and ok
	return ok


## The keys of one vocabulary that carry a forwarding address, sorted.
static func _addressed_keys(known: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in known.keys():
		if not EventForgeSuccessors.normalize_map((known[key] as Dictionary).get("map", {})).is_empty():
			keys.append(str(key))
	keys.sort()
	return keys


## A sound address written for this harness, with REAL templates - the corpus the walk above needs to
## have something to walk. Both verbs write a line that is GDScript on its own, so the compile and
## the parse are asking about the rewrite rather than about the fixture.
static func _probe_table() -> Dictionary:
	var older: Dictionary = _entry("P::Older", ["message"],
		{"id": "P::Newer", "renames": {"message": "text"}, "defaults": {}})
	older["template"] = "print({message})"
	older["declared_types"] = {"message": "String"}
	var newer: Dictionary = _entry("P::Newer", ["text"], {})
	newer["template"] = "print({text})"
	newer["declared_types"] = {"text": "String"}
	return {"P::Older": older, "P::Newer": newer}


## One address, end to end.
static func _test_one_map(key: String, known: Dictionary) -> bool:
	var entry: Dictionary = known[key]
	var resolved: Dictionary = EventForgeSuccessors.resolve(key, known)
	var ok: bool = _check("%s: resolves to the end of its chain" % key, not resolved.is_empty(), true)
	if not ok:
		return false
	var successor_key: String = str(resolved[EventForgeSuccessors.KEY_ID])
	var successor: Dictionary = known[successor_key]
	var old_params: Dictionary = _sample_params(entry)
	var old_line: String = _emit(str(entry["template"]), old_params, int(entry["ace_type"]))
	var new_params: Dictionary = EventForgeSuccessors.rewrite_params(old_params, resolved,
		successor.get("params", PackedStringArray()))
	var new_line: String = _emit(str(successor["template"]), new_params, int(successor["ace_type"]))
	print("  [rewrite] %s -> %s" % [old_line, new_line])
	# Nothing left unfilled: a slot still showing in the emitted line is a parameter the map does not
	# answer, which is a row that would land with a hole in it.
	var unfilled: PackedStringArray = PackedStringArray()
	for parameter: String in successor.get("params", PackedStringArray()):
		if new_line.contains("{%s}" % parameter):
			unfilled.append(parameter)
	ok = _check("%s: the rewritten row has no unfilled slot" % key, unfilled, PackedStringArray()) and ok
	# And every value the old row carried arrives under its new name - the whole point of a rename.
	var lost: PackedStringArray = PackedStringArray()
	for old_name: Variant in (resolved[EventForgeSuccessors.KEY_RENAMES] as Dictionary).keys():
		var carried: String = str(old_params.get(old_name, "")).strip_edges()
		if carried.is_empty() or not old_params.has(old_name):
			continue
		if not new_line.contains(carried):
			lost.append("%s -> %s" % [str(old_name), str((resolved[EventForgeSuccessors.KEY_RENAMES] as Dictionary)[old_name])])
	ok = _check("%s: every renamed value arrives" % key, lost, PackedStringArray()) and ok
	# Emission is deterministic: the same row writes the same byte every time it is asked.
	ok = _check("%s: emits the same byte twice" % key,
		_emit(str(successor["template"]), new_params, int(successor["ace_type"])), new_line) and ok
	# And the line the migrate receipt would show is the line the FILE would get - proved by putting
	# the rewritten row through the compiler rather than by trusting the emitter twice.
	ok = _check("%s: the compiled sheet carries that exact line" % key,
		_compiles_to(successor_key, successor, new_params, new_line), true) and ok
	return ok


## The values a fixture row starts on: what the verb itself declares, and a sample where the verb
## leaves the answer to the author (a blank default means "a row must say which", and a fixture that
## honoured the blank would prove nothing about whether the value travels).
##
## THE SAMPLE HAS TO BE THE SHAPE A REAL ROW HOLDS, or the whole harness proves the wrong thing. A
## plain text parameter stores a QUOTED LITERAL - that is what the field writes the moment somebody
## types a word into it - while a name-shaped one (a state, a variable, a node) stores a bare name.
## Filling every blank with a bare identifier made `state = State.mg_state` parse and `state =
## State."chasing"` never be asked about, which is exactly how a forwarding address that cannot
## migrate one real row shipped.
static func _sample_params(entry: Dictionary) -> Dictionary:
	var declared: Dictionary = entry.get("declared_defaults", {})
	var hints: Dictionary = entry.get("declared_hints", {})
	var types: Dictionary = entry.get("declared_types", {})
	var template: String = str(entry.get("template", ""))
	var filled: Dictionary = {}
	for parameter: String in entry.get("params", PackedStringArray()):
		var value: String = str(declared.get(parameter, "")).strip_edges()
		if not value.is_empty():
			filled[parameter] = value
			continue
		# THE NODE-SCOPING SLOT IS THE ONE BLANK THAT IS AN ANSWER. A node-scoped verb wears an
		# "On node" parameter whose slot is written `{target.}` - the dot lives inside the braces so
		# the whole prefix disappears when the row acts on the node it is written on, which is what
		# nearly every such row holds. Filling it with an identifier instead wrote
		# `mg_target.stop()` into the fixture, which is a line naming a variable nobody declared:
		# the parse below then refused every node-scoped address for a reason that was the harness's
		# and not the map's.
		if template.contains("{%s.}" % parameter):
			filled[parameter] = ""
			continue
		filled[parameter] = _blank_value(parameter, str(hints.get(parameter, "")),
			str(types.get(parameter, "")))
	return filled


## What a row holds in a parameter its verb leaves blank, in the shape that parameter's own field
## writes. A hinted field is a picker over names, so its value is a bare name; a plain field of a
## given type holds a literal of that type.
static func _blank_value(parameter: String, hint: String, type_name: String) -> String:
	var token: String = "%s%s" % [SAMPLE_PREFIX, parameter]
	if not hint.strip_edges().is_empty():
		return token
	match type_name:
		"bool":
			return "false"
		"int":
			return "0"
		"float":
			return "0.0"
		"String":
			return "\"%s\"" % token
	return token


## One row's line, through the compiler's own emitters - never a copy of the substitution. A fixture
## the harness wrote with its own `replace()` would agree with itself and prove nothing.
static func _emit(template: String, params: Dictionary, ace_type: int) -> String:
	if ace_type == ACEDefinition.ACEType.CONDITION:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Core"
		condition.codegen_template = template
		condition.params = params.duplicate()
		return ConditionCodegen.generate_condition(condition)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.codegen_template = template
	action.params = params.duplicate()
	return ActionCodegen.generate_action(action)


## Whether a one-row sheet holding the rewritten row compiles, whether the GDScript it wrote really
## does carry the emitted line, AND WHETHER THAT GDSCRIPT PARSES. This is the byte gate the migrate
## dialog runs before it commits, asked here of every address the vocabulary ships.
##
## The parse is the step that matters and the step that was missing: `SheetCompiler.compile` builds
## text and never asks the engine to read it, so a rewrite that lands a quoted literal in a slot
## spelled as a name writes a file nothing loads and a `contains()` check calls it a pass. The
## migrate dialog refuses such a row (`why=file-refuses`); a harness that could not see it let the
## address ship anyway.
static func _compiles_to(successor_key: String, successor: Dictionary, params: Dictionary, line: String) -> bool:
	var address: PackedStringArray = EventForgeSuccessors.split_key(successor_key)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "SuccessorFixture"
	# THE HOST IS THE VERB'S OWN. A node-scoped verb writes a member call on the node it is written
	# on, so compiling it under a bare `Node` asks the engine about a method that class has never had
	# and gets an honest refusal about the fixture rather than about the rewrite.
	var node_type: String = str(successor.get("node_type", "")).strip_edges()
	sheet.host_class = node_type if not node_type.is_empty() else "Node"
	var event: EventRow = EventRow.new()
	if int(successor["ace_type"]) == ACEDefinition.ACEType.CONDITION:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = address[0]
		condition.ace_id = address[1]
		condition.codegen_template = str(successor["template"])
		condition.params = params.duplicate()
		event.conditions.append(condition)
		# A condition needs something to do when it is true, or the event has no body to emit.
		var body: ACEAction = ACEAction.new()
		body.provider_id = "Core"
		body.codegen_template = "pass"
		event.actions.append(body)
	else:
		var action: ACEAction = ACEAction.new()
		action.provider_id = address[0]
		action.ace_id = address[1]
		action.codegen_template = str(successor["template"])
		action.params = params.duplicate()
		event.actions.append(action)
	sheet.events.append(event)
	var compiled: Dictionary = SheetCompiler.compile(sheet, "user://_successor_map_fixture.gd")
	if not bool(compiled.get("success", false)):
		print("  [why] %s did not compile: %s" % [successor_key, str(compiled.get("errors", []))])
		return false
	var written: String = str(compiled.get("output", ""))
	if not written.contains(line):
		print("  [why] %s compiled without its own line: %s" % [successor_key, line])
		return false
	if not EventSheetMigrationPlan.parses(written):
		print("  [why] %s compiled to GDScript the engine refuses, around: %s" % [successor_key, line])
		return false
	return true


## The engine itself, on maps written for the purpose - the mechanics the shipped addresses rely on
## and none of them exercises alone.
static func _test_the_engine() -> bool:
	var known: Dictionary = _table()
	# A chain resolves to its END, with the renames composed through the middle and the middle's own
	# default carried along and re-keyed on the way.
	var ok: bool = _check("a chain resolves to the last verb in it",
		EventForgeSuccessors.resolve("P::A", known),
		{"id": "P::C", "renames": {"one": "three"}, "defaults": {"extra": "1.0"},
			"hops": PackedStringArray(["P::B", "P::C"])})
	ok = _check("and one hop is left exactly as it was authored",
		EventForgeSuccessors.resolve("P::B", known),
		{"id": "P::C", "renames": {"two": "three"}, "defaults": {"extra": "1.0"},
			"hops": PackedStringArray(["P::C"])}) and ok
	ok = _check("a verb with no address answers nothing",
		EventForgeSuccessors.resolve("P::C", known), {}) and ok
	ok = _check("nor does a key the vocabulary has never heard of",
		EventForgeSuccessors.resolve("P::Nobody", known), {}) and ok
	ok = _check("a cycle answers nothing rather than looping",
		EventForgeSuccessors.resolve("P::Ring", known), {}) and ok
	# A PARAMETER THE FIRST HOP SUPPLIED AS A DEFAULT AND THE SECOND HOP RENAMED. It arrives at the
	# second hop carrying a value, but not from the original row - which has no parameter of that
	# name at all - so it belongs in the defaults under its new name and never in the renames. Put
	# there, it composed an entry keyed by a name the first verb never had, and problems() called a
	# correct chain a build error, which fails the pack audit.
	var carried: Dictionary = _carried_default_table()
	ok = _check("a default carried through a hop that renames it stays a default",
		EventForgeSuccessors.resolve("P::First", carried),
		{"id": "P::Third", "renames": {"a": "b2"}, "defaults": {"c2": "5"},
			"hops": PackedStringArray(["P::Second", "P::Third"])}) and ok
	ok = _check("so the chain is sound rather than a build error",
		EventForgeSuccessors.problems(carried), PackedStringArray()) and ok
	ok = _check("and the rewrite puts both values where they belong",
		EventForgeSuccessors.rewrite_params({"a": "hp"},
			EventForgeSuccessors.resolve("P::First", carried),
			PackedStringArray(["b2", "c2"])), {"b2": "hp", "c2": "5"}) and ok
	# The rewrite itself: values move to their new names, new parameters get their value, and a
	# parameter the successor does not have is left behind rather than carried as baggage.
	ok = _check("the rewrite renames, fills and drops",
		EventForgeSuccessors.rewrite_params({"one": "hp", "gone": "9"},
			EventForgeSuccessors.resolve("P::A", known), PackedStringArray(["three", "extra"])),
		{"three": "hp", "extra": "1.0"}) and ok
	ok = _check("and a row already holding a value keeps it over the default",
		EventForgeSuccessors.rewrite_params({"two": "hp", "extra": "9.0"},
			EventForgeSuccessors.resolve("P::B", known), PackedStringArray(["three", "extra"])),
		{"three": "hp", "extra": "9.0"}) and ok
	ok = _check("the two halves of a key come apart",
		EventForgeSuccessors.split_key("Core::GoToState"), PackedStringArray(["Core", "GoToState"])) and ok
	ok = _check("and a bare id is a built-in",
		EventForgeSuccessors.split_key("GoToState"), PackedStringArray(["Core", "GoToState"])) and ok
	ok = _check("an address with no destination is not an address",
		EventForgeSuccessors.normalize_map({"id": "  "}), {}) and ok
	return ok


## Every way a map can be wrong, each said once and named. A gate that stopped detecting these would
## report a clean vocabulary while shipping rewrites that land blank.
static func _test_a_broken_map_is_named() -> bool:
	return _check("every broken address is named, and why",
		EventForgeSuccessors.problems(_broken_table()), PackedStringArray([
			"P::Blank: nothing answers P::C's three, so a rewritten row would land blank",
			"P::Itself: succeeded by itself",
			"P::Renamer: renames nothing_here, which it has no parameter called",
			"P::Renamer: renames one to elsewhere, which P::C has no parameter called",
			"P::Renamer: nothing answers P::C's three, so a rewritten row would land blank",
			"P::Ring: the chain comes back to itself (P::Ring -> P::Round -> P::Ring)",
			"P::Round: the chain comes back to itself (P::Round -> P::Ring -> P::Round)",
			"P::Stranger: succeeded by P::Nobody, which no installed vocabulary has",
			"P::Twice: gives three both a renamed value and a default",
		]))


## THE TWO-HOP SHAPE THE CHAIN MACHINERY EXISTS FOR: the first hop supplies a parameter the original
## verb never had, and the second hop renames that very parameter. First has [a]; Second has [b, c]
## and is reached by renaming a to b and giving c a value; Third has [b2, c2] and is reached by
## renaming both. From First's point of view the answer is one rename and one default.
static func _carried_default_table() -> Dictionary:
	return {
		"P::First": _entry("P::First", ["a"],
			{"id": "P::Second", "renames": {"a": "b"}, "defaults": {"c": "5"}}),
		"P::Second": _entry("P::Second", ["b", "c"],
			{"id": "P::Third", "renames": {"b": "b2", "c": "c2"}, "defaults": {}}),
		"P::Third": _entry("P::Third", ["b2", "c2"], {}),
	}


## A sound little vocabulary: A -> B -> C, plus a verb that cycles.
static func _table() -> Dictionary:
	return {
		"P::A": _entry("P::A", ["one"], {"id": "P::B", "renames": {"one": "two"}, "defaults": {}}),
		"P::B": _entry("P::B", ["two"], {"id": "P::C", "renames": {"two": "three"}, "defaults": {"extra": "1.0"}}),
		"P::C": _entry("P::C", ["three", "extra"], {}),
		"P::Ring": _entry("P::Ring", ["one"], {"id": "P::Round", "renames": {"one": "one"}, "defaults": {}}),
		"P::Round": _entry("P::Round", ["one"], {"id": "P::Ring", "renames": {"one": "one"}, "defaults": {}}),
	}


## And every way of being wrong, one verb each.
static func _broken_table() -> Dictionary:
	var table: Dictionary = _table()
	table["P::Itself"] = _entry("P::Itself", ["one"], {"id": "P::Itself", "renames": {}, "defaults": {}})
	table["P::Stranger"] = _entry("P::Stranger", ["one"], {"id": "P::Nobody", "renames": {}, "defaults": {}})
	table["P::Renamer"] = _entry("P::Renamer", ["one"],
		{"id": "P::C", "renames": {"one": "elsewhere", "nothing_here": "three"}, "defaults": {"extra": "1.0"}})
	table["P::Blank"] = _entry("P::Blank", ["one"], {"id": "P::C", "renames": {}, "defaults": {"extra": "1.0"}})
	table["P::Twice"] = _entry("P::Twice", ["one"],
		{"id": "P::C", "renames": {"one": "three"}, "defaults": {"three": "x", "extra": "1.0"}})
	return table


## One entry in the shape the catalogue holds them, with every parameter asking to be answered - the
## strict case, so a map that leaves one blank is caught rather than excused by a default.
static func _entry(key: String, params: Array, map: Dictionary) -> Dictionary:
	return {
		"key": key,
		"name": key,
		"template": "",
		"ace_type": ACEDefinition.ACEType.ACTION,
		"params": PackedStringArray(params),
		"declared_defaults": {},
		"answered_by_default": PackedStringArray(),
		"map": map,
	}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("successor_map_test", label, actual, expected)
