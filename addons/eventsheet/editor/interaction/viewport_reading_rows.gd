@tool
class_name EventSheetViewportReadingRows
extends RefCounted

# The row-level reading lenses, kept beside the text lenses but separate from them because these
# need to ASK things - the sheet for its host class, the editor theme for a class icon, the
# sheet's functions for their parameter names. Like the text lenses they are display-only: every
# function here returns something to draw, and nothing here touches a row model, a sheet
# resource, or emitted GDScript.
#
#   M13/M20  class icons on objects   - the pack's host, a $Node / %Node reference, and any
#                                       @onready-declared node variable draw their Godot class
#                                       icon before the object label
#   M16      Functions > Call Name    - a call to a known function reads with its display name
#                                       and one argument per parameter name
#   M17      folded code cards        - a raw block that could not lift reads as one card
#   M20      object declaration rows  - @onready var hp_bar: ProgressBar = %HpBar
#   N4       autoloads and behaviours - an autoload reads as a global, and a pack node under the
#                                       script's own node reads as that object's behaviour
#   W14      typed objects by class   - a receiver whose declared class the PROJECT wrote reads
#                                       under that class in words, its own name muted beside it


## The object label a pack's host is shown under. One constant so the icon map, the row builder
## and the tests can never disagree about which label the host icon belongs to.
const HOST_LABEL := "host"


## M25/M27/M28. What the sentence grammar needs to know about THIS sheet that only something able to
## ASK can answer: the name of the object the script itself is, the engine properties that object has
## (so `position.x = 100` reads under it and a plain script variable does not), and each declared
## signal's parameter names (so an emit shows named payload chips).
##
## Merged into the row builder's sentence context once per rebuild. Everything here is a lookup - no
## instancing, no scene loading - because it runs whenever the sheet identity changes.
static func sentence_context_extras(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {}
	# ── M38 / M40 lens hook ────────────────────────────────────────────────────────────────────
	# The sheet's own enums (so an unambiguous member can drop its enum name) and the class behind
	# every object label (so `play` can tell an animation from a sound). Both are plain walks of the
	# sheet, cached with the rest of the context.
	var enums: Dictionary = enum_member_map(sheet)
	# ── Q5 / Q6 / Q11 lens hook ────────────────────────────────────────────────────────────────
	# What the sheet's own DECLARATIONS say about a value's kind: the type of each variable (so
	# `inventory.erase(k)` can say "key" where `items.erase(v)` says "value"), the variables typed
	# with one of the sheet's enums plus each enum's numbering (so `dir = 2` reads LEFT), and the
	# 0..1 settings the project marked as fractions (so `0.5` reads 50%). All plain walks of the
	# sheet, cached with the rest of the context.
	var declared: Dictionary = declared_type_map(sheet)
	# ── R3 lens hook ───────────────────────────────────────────────────────────────────────────
	# The tween chains the file writes, walked once in FILE order: which locals hold a tween, and
	# which of their steps follow another one or run beside it.
	var tweens: Dictionary = tween_chain_facts(sheet)
	# ── S2 / S4 lens hook ──────────────────────────────────────────────────────────────────────
	# The PATTERNS this file writes - the numbers counted down by a delta and asked about against
	# zero, the lists used as object pools. No single line can answer either question, so both are
	# answered from one walk of the file here and handed to the grammar as ordinary context.
	var patterns: Dictionary = EventSheetPatternReadings.facts(ordered_code_lines(sheet))
	var extras: Dictionary = {
		"script_object": script_object_name(sheet),
		"engine_properties": engine_property_set(sheet),
		"signal_params": signal_parameter_map(sheet),
		"enum_members": enums.get("members", {}),
		"enum_names": enums.get("names", {}),
		"enum_values": enums.get("values", {}),
		"variable_types": declared.get("types", {}),
		"variable_enum_types": declared.get("enum_types", {}),
		"percent_members": declared.get("percent_members", {}),
		"object_classes": object_class_map(sheet),
		"self_class": sheet.host_class.strip_edges(),
		# ── P9 ────────────────────────────────────────────────────────────────────────────────
		# Whether this file is the scene's OWN script, which decides whether its `_ready` reads as the
		# layout starting or as one object being created. Cached here with the rest of the context
		# because the answer only changes when the opened sheet does.
		"scene_root": is_scene_root_script(sheet),
		# ── R9 ────────────────────────────────────────────────────────────────────────────────
		# Which of the Timer behavior's two modes each timer tag runs in, so a Start timer row can
		# say `(once)` / `(regular)`. The file itself is the only place that knows, and it says it
		# on a line of its own - so the line is read once per rebuild rather than per row.
		"timer_modes": timer_mode_map(sheet),
		# ── R3 ────────────────────────────────────────────────────────────────────────────────
		# Which locals hold a tween, and which of their steps follow another one. A tween chain is
		# spread over several lines joined only by the local's name, so the rows that belong together
		# are worked out once here rather than guessed at line by line.
		"tween_locals": tweens.get("locals", {}),
		"tween_notes": tweens.get("notes", {}),
		# ── S17 ───────────────────────────────────────────────────────────────────────────────
		# Which locals hold a tile's own data, and the cell each one came from. The question a tile
		# asks ("has solid set") is written a line below the answer's source, so the two are joined
		# once here rather than guessed at per row.
		"tile_data_locals": tile_data_local_map(sheet),
		# ── U9 / U10 / U11 ────────────────────────────────────────────────────────────────────
		# Every function's parameter names, so a call that hands values over - a job sent to a
		# background thread, a handler wired up with values bound to it, a call made by name - shows
		# each value under the name the function receives it as, exactly as a signal's payload chips
		# do. A function the sheet does not declare is simply absent, and the chips then show the
		# bare values rather than a guessed name.
		"function_params": function_parameter_map(sheet),
		# ── X4 ────────────────────────────────────────────────────────────────────────────────
		# Which of this file's objects are camera PIVOTS - nodes whose only children in the scene
		# are a camera or the arm one hangs off. Turning one of those is not a turn, it is the
		# camera going round what it looks at, and only the SCENE can say which nodes those are.
		"orbit_pivots": orbit_pivot_map(sheet)
	}
	extras.merge(patterns, true)
	# ── X2 / X20 / X30 lens hook ───────────────────────────────────────────────────────────────
	# The camera-ray runs the file casts through the cursor, and the locals it converts into canvas
	# space. A run is four lines joined only by its locals' names and a canvas distance is two
	# declarations away from the call that measures it, so both are answered from one walk here.
	extras.merge(cursor_ray_facts(sheet), true)
	# ── X22 / X28 lens hook ────────────────────────────────────────────────────────────────────
	# The sensor shapes and the input window are asked of the HALF-LIFTED file rather than of its
	# hand-written lines alone: the control a window waits for is written inside an `if` that lifts
	# to a condition row, so a walk that saw only the verbatim text would name the window in a file
	# the importer left alone and refuse to name it in the same file once it lifted.
	var input_lines: PackedStringArray = behavior_code_lines(sheet)
	extras["tilt_variables"] = EventSheetPatternReadings.tilt_variables(input_lines)
	extras["rate_variables"] = EventSheetPatternReadings.rate_variables(input_lines)
	extras["input_window"] = EventSheetPatternReadings.input_window_facts(input_lines)
	# ── Y12 lens hook ──────────────────────────────────────────────────────────────────────────
	# Which table this file keeps unlocked skill ids in. `unlocked.has("double_jump")` is a plain
	# dictionary lookup until the file elsewhere owns that table beside a requires list, so the
	# question is answered from one walk of the file rather than line by line. Both views of the
	# file are walked: a declaration lifts to a variable ROW (so it is only in the half-lifted
	# lines) while a prerequisite walk stays verbatim inside a function (so it is only in the
	# ordered ones), and the shape is exactly the two of them together.
	var owned_lines: PackedStringArray = input_lines.duplicate()
	owned_lines.append_array(ordered_code_lines(sheet))
	extras.merge(EventSheetPatternReadings.skill_tree_facts(owned_lines), true)
	# ── S8 / S10 / S15 lens hook ───────────────────────────────────────────────────────────────
	# The three patterns whose lines only mean something TOGETHER: the locals a background load
	# threads its path and its progress through, the messages the file publishes with `@rpc`, and the
	# navigation agent plus the waypoint local a path walk is written around. Worked out once here,
	# for the same reason the tween chains are - a per-row guess could only see one line at a time.
	extras.merge(godot_systems_facts(sheet), true)
	# ── T1 / T2 / T3 / T4 lens hook ────────────────────────────────────────────────────────────
	# What the FILE says about the hand-rolled behavior shapes it writes: whether it is a projectile
	# at all, which variable a nearest-in-family loop fills, which point a glide aims at and which
	# flag says it is running, which object a place is copied from, and which tween fades to nothing.
	# Not one of those questions can be answered from a single line, so all of them are answered from
	# one walk here and handed to the grammar as ordinary context.
	extras.merge(EventSheetBehaviorShapes.facts(ordered_code_lines(sheet)), true)
	# ── T10 lens hook ──────────────────────────────────────────────────────────────────────────
	# Whether each object's Z order counts from its parent or from the layer. The file states it on a
	# line of its own, a line away from the number it qualifies, so the answer is gathered once here
	# rather than guessed at per row.
	extras.merge(around_objects_facts(sheet), true)
	# ── V1 / V6 lens hook ──────────────────────────────────────────────────────────────────────
	# The two kinds of variable whose CLASS is only ever stated where they are declared: the physics
	# material a body's friction and elasticity are written on, and the regular expression a search
	# is run with. Worked out once here for the same reason the tween chains are.
	extras.merge(reading_gap_facts(sheet), true)
	# ── T5 / T6 / T25 / T26 lens hook ──────────────────────────────────────────────────────────
	# The behaviors a script hand-rolls: which local holds the sight ray, which boolean is the drag
	# flag and which vector is its grab offset, which local holds the noise and the seeded random,
	# and which local holds the clock the date fields are read out of. Every one of them is a whole-
	# file question, so it is answered once here rather than guessed at line by line.
	extras.merge(behavior_words_facts(sheet), true)
	# ── W3 / W4 / W5 / W16 lens hook ───────────────────────────────────────────────────────────
	# What a TOOL script's own shape says about it: the object a helper is a behavior of, the class
	# that is a shared store, the vocabulary rows a module publishes and the functions that call
	# themselves. Every one of those is stated in a `func` header or spread over a whole file, so all
	# of them are answered from one read of the file here rather than guessed at line by line.
	extras.merge(EventSheetEditorSourceFacts.facts(sheet), true)
	# ── W9 / W10 / W11 lens hook ───────────────────────────────────────────────────────────────
	# What KIND of tooling file this is - a test, a command-line tool, a behavior pack's recipe - and
	# the whole-file answers each of those readings needs: the names a test folds its verdict through,
	# the locals a folder walk fills, the facts a recipe states about the pack it builds. A file that
	# is none of the three adds nothing at all, which is every game script.
	extras.merge(tool_file_facts(sheet), true)
	# ── X3 lens hook ───────────────────────────────────────────────────────────────────────────
	# A facing test names its two vectors a line or two before it asks the question, so no single
	# line can say whose forward `forward` is or what `to_enemy` points at. Both are answered from
	# one walk of the file here, exactly as the tween chains and the sight rays are.
	extras.merge(spatial_words_facts(sheet), true)
	# ── W6 lens hook ───────────────────────────────────────────────────────────────────────────
	# The menus this file builds: which add_item labels went into which menu with which id, and
	# which handler answers that menu. Both halves are written far apart, so neither line can say
	# what the other knows - they are joined here, once, from one walk of the file.
	extras.merge(menu_facts(sheet), true)
	return extras


## W6. The menus this file builds, or {} when it builds none - which is every sheet that never calls
## add_item, so the common case costs one walk and nothing else. Read off DISK for an opened file,
## exactly as the tooling facts are: the importer lifts a menu's `_ready` into structure, and the
## file on disk is the only place that still holds every line in order.
static func menu_facts(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {}
	return EventSheetMenuFacts.facts(EventSheetToolFiles.lines_of_sheet(sheet))


## W9 / W10 / W11. What this file is as a piece of TOOLING, or {} when it is not one. The path is what
## tells a test from a helper and a recipe from a tool, so it is passed alongside the lines: the sheet
## remembers the file it was opened from, and an unsaved sheet is in no folder and claims nothing.
static func tool_file_facts(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {}
	return EventSheetToolFiles.facts(
		EventSheetToolFiles.lines_of_sheet(sheet), sheet.external_source_path)


## X3. What the FILE says about the vectors a facing test is written with:
##
##   facing_locals     {local name: the object whose FORWARD it holds}
##   direction_locals  {local name: {"from": object, "to": object} it points between}
##
## A local the file never declared from one of those two shapes is simply absent, and the facing
## reading then does not fire - which is what keeps a dot product nobody explained reading as one.
static func spatial_words_facts(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {}
	var facing: Dictionary = {}
	var directions: Dictionary = {}
	var own_object: String = script_object_name(sheet)
	var context: Dictionary = {
		"self_object": own_object, "script_object": own_object,
		"self_class": sheet.host_class.strip_edges(), "object_classes": object_class_map(sheet)
	}
	for line: String in behavior_code_lines(sheet):
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		var declared: String = _declared_local_name(text)
		if declared.is_empty():
			continue
		var value: String = _declared_local_value(text)
		if value.is_empty():
			continue
		var axis: Dictionary = EventSheetSentence.direction_axis_parts(value)
		if not axis.is_empty() and str(axis.get("word", "")) == "forward":
			var owner_text: String = str(axis.get("owner", ""))
			facing[declared] = own_object if owner_text == "self" \
				else EventSheetSentence.object_of_reference(owner_text)
			continue
		var between: Dictionary = EventSheetSentence.direction_between_parts(value, context)
		if not between.is_empty():
			directions[declared] = between
	return {"facing_locals": facing, "direction_locals": directions}


## T10 / T8. What the FILE says about its drawing order and about the lists it picks from:
##
##   z_order_relative  {object label: true when its Z order counts from the parent}
##   family_lists      {local name: the family its members are}
##
## Absent for an object the file never says it about, and every reading built on it then simply says
## nothing extra - the row still shows the number the file wrote.
static func around_objects_facts(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {}
	var relative: Dictionary = {}
	var families: Dictionary = {}
	var own_object: String = script_object_name(sheet)
	for line: String in ordered_code_lines(sheet):
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		_note_family_list(text, families)
		var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
		if assign_at <= 0:
			continue
		var target: String = text.substr(0, assign_at).strip_edges().trim_prefix("self.")
		var value: String = text.substr(assign_at + 3).strip_edges()
		if value != "true" and value != "false":
			continue
		if target == "z_as_relative":
			relative[own_object] = value == "true"
			continue
		if not target.ends_with(".z_as_relative"):
			continue
		var receiver: String = target.substr(0, target.length() - 14).strip_edges()
		if receiver.is_empty():
			continue
		relative[EventSheetSentence.object_of_reference(receiver)] = value == "true"
	return {"z_order_relative": relative, "family_lists": families}


## T8. Records the family a list holds, when the LINE that made the list says it: a list built from a
## group holds that group's family, and a list declared `Array[Enemy]` holds Enemies. A list the file
## never said the kind of is simply absent, and every pick reading then declines to fire.
static func _note_family_list(text: String, families: Dictionary) -> void:
	var declared: String = _declared_local_name(text)
	if declared.is_empty():
		return
	var typed: String = _declared_local_type(text)
	if not typed.is_empty():
		var typed_family: String = EventSheetSentence.family_word_of(typed)
		if not typed_family.is_empty():
			families[declared] = typed_family
			return
	var group: String = _group_list_source(_declared_local_value(text))
	if group.is_empty():
		return
	var group_family: String = EventSheetSentence.family_word_of(group)
	if not group_family.is_empty():
		families[declared] = group_family


## T8. The group a `get_tree().get_nodes_in_group("enemy")` list was built from, or "" for any other
## value. Only the literal group name answers: a group named by a variable is a name this reading
## cannot show, so the list keeps its own words.
static func _group_list_source(value: String) -> String:
	const HEADS: PackedStringArray = [
		"get_tree().get_nodes_in_group(", "get_nodes_in_group("
	]
	var text: String = value.strip_edges()
	for head: String in HEADS:
		if not text.begins_with(head) or not text.ends_with(")"):
			continue
		var inner: String = text.substr(head.length(), text.length() - head.length() - 1).strip_edges()
		if inner.begins_with("\"") and inner.ends_with("\"") and inner.length() > 2:
			return inner.substr(1, inner.length() - 2)
	return ""


## T8. The type a declaration carries (`var enemies: Array[Enemy] = ...`), or "" when it carries none.
static func _declared_local_type(text: String) -> String:
	var body: String = text.strip_edges()
	var keyword: String = EventSheetSentence.leading_word(body)
	if keyword != "var" and keyword != "const":
		return ""
	body = body.substr(keyword.length()).strip_edges()
	var assign_at: int = EventSheetSentence.top_level_index(body, " = ")
	if assign_at <= 0:
		return ""
	var head: String = body.substr(0, assign_at).strip_edges()
	var colon_at: int = head.find(":")
	return "" if colon_at < 0 else head.substr(colon_at + 1).strip_edges()


## V1 / V6. What the FILE says about the two kinds of variable batch eleven's readings need a class
## for, as the fact maps the sentence grammar reads:
##
##   physics_materials  {name: true} - the variables a `PhysicsMaterial.new()` filled
##   pattern_variables  {name: true} - the variables a `RegEx.new()` filled
##   match_variables    {name: true} - the variables one of those patterns' `search` filled
##
## A name filled from something else as well is dropped from every map: the same word may not read
## two ways on one sheet, exactly as the tween notes refuse a line that means two things.
static func reading_gap_facts(sheet: EventSheetResource) -> Dictionary:
	var materials: Dictionary = {}
	var patterns: Dictionary = {}
	var matches: Dictionary = {}
	if sheet == null:
		return {"physics_materials": materials, "pattern_variables": patterns,
			"match_variables": matches}
	for line: String in _systems_fact_lines(sheet):
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		var declared: String = _declared_local_name(text)
		if declared.is_empty():
			continue
		var value: String = _declared_local_value(text)
		if value == "PhysicsMaterial.new()":
			materials[declared] = true
		elif value == "RegEx.new()":
			patterns[declared] = true
		elif _is_pattern_search(value, patterns):
			matches[declared] = true
		else:
			# A name the file also fills from something else has no one class a reading could name.
			materials.erase(declared)
			patterns.erase(declared)
			matches.erase(declared)
	return {"physics_materials": materials, "pattern_variables": patterns,
		"match_variables": matches}


## V6. True when a value is `<a pattern this file declared>.search(...)` - the one call whose result
## is the match the reading calls "the match".
static func _is_pattern_search(value: String, patterns: Dictionary) -> bool:
	var call: Dictionary = EventSheetSentence.call_parts(value.strip_edges())
	if call.is_empty() or str(call.get("method", "")) != "search":
		return false
	return patterns.has(str(call.get("target", "")).strip_edges())


## Batch 8. Re-state every pattern this sheet writes in the registry, on the row that OWNS it - the
## trigger, tick event or function whose body holds the lines. Called once per rebuild, right after
## the registry is cleared, so the chips, the hover evidence, Adopt behavior and the Doctor all read
## one set of claims rather than each re-deriving the patterns for itself.
##
## A top-level event owns its own body and everything under it; a function owns its body and is
## addressed as `function:<name>`, because a function has no uid of its own to name it by.
static func claim_patterns(sheet: EventSheetResource) -> void:
	if sheet == null:
		return
	EventSheetPatternFacts.mark_stated(sheet)
	var file_facts: Dictionary = EventSheetPatternReadings.facts(ordered_code_lines(sheet))
	for event_entry: Variant in sheet.events:
		if not (event_entry is EventRow):
			continue
		var event_row: EventRow = event_entry
		var body: PackedStringArray = PackedStringArray()
		_append_ordered_lines(event_row, body, 0)
		_claim_body(sheet, event_row.event_uid, event_row.event_uid, body, file_facts)
	for function_entry: Variant in sheet.functions:
		if not (function_entry is EventFunction):
			continue
		var event_function: EventFunction = function_entry
		var function_body: PackedStringArray = PackedStringArray()
		for owned: Variant in event_function.events:
			_append_ordered_lines(owned, function_body, 0)
		var function_uid: String = "function:%s" % event_function.function_name
		_claim_body(sheet, function_uid, function_uid, function_body, file_facts)


## The same walk, but only when it has not already run since the last clear - what anything READING
## the registry calls before it reads. The two passes that claim (this one over the file's lines, the
## row builder's own span pass) do not run in a fixed order relative to every clear, and a marker
## that went missing because a clear landed between them would be a reading the sheet silently lost.
## Idempotent and cheap: on the overwhelmingly common path it is one dictionary lookup.
static func ensure_claims(sheet: EventSheetResource) -> void:
	if sheet == null or EventSheetPatternFacts.has_stated(sheet):
		return
	claim_patterns(sheet)


## One owning row's claims, handed to the registry as they come back.
static func _claim_body(sheet: EventSheetResource, row_uid: String, event_uid: String,
		body: PackedStringArray, file_facts: Dictionary) -> void:
	for entry: Variant in EventSheetPatternReadings.claims_in(body, file_facts):
		var claim: Dictionary = entry
		EventSheetPatternFacts.claim(sheet, str(claim.get("pattern", "")), row_uid, event_uid,
			claim.get("evidence", PackedStringArray()), str(claim.get("words", "")),
			str(claim.get("adoptable", "")), claim.get("ace_ids", PackedStringArray()))


## T2. The ACEs a turret is authored from, so the Manual's "Patterns using this" and Adopt behavior
## know what the hand-rolled loop would be replaced BY. The pack is the first option; these are the
## free actions the loop would otherwise be written as.
const TURRET_ACE_IDS: PackedStringArray = [
	"Core/AcquireNearestInFamily", "Core/HasTarget", "Core/RotateToward"
]


## T2. Records the nearest-in-family loop each event writes as the Turret behavior's Acquire target,
## with the loop's own lines as the evidence and the Weapon Kit as the pack that could replace it.
##
## The loop is a SHAPE spread over a `for`, the compare inside it and the assignment after, so it is
## claimed here rather than read as a row: the rows the loop is drawn as are unchanged, and the chip,
## the hover evidence and Adopt behavior get the one sentence the shape is.
static func claim_behavior_shape_patterns(sheet: EventSheetResource) -> void:
	if sheet == null:
		return
	for entry: Variant in sheet.events:
		if not (entry is EventRow):
			continue
		var event_row: EventRow = entry
		var body: PackedStringArray = PackedStringArray()
		_append_ordered_lines(event_row, body, 0)
		_claim_turret_runs(sheet, event_row.event_uid, body)
	for entry: Variant in sheet.functions:
		if not (entry is EventFunction):
			continue
		var event_function: EventFunction = entry
		var body: PackedStringArray = PackedStringArray()
		for owned: Variant in event_function.events:
			_append_ordered_lines(owned, body, 0)
		_claim_turret_runs(sheet, "function:%s" % event_function.function_name, body)


## One owning row's turret loops, handed to the registry in the Turret behavior's own words.
static func _claim_turret_runs(sheet: EventSheetResource, row_uid: String,
		body: PackedStringArray) -> void:
	for run: Dictionary in EventSheetBehaviorShapes.nearest_in_family_runs(body):
		var words: String = EventSheetL10n.translate("Acquire nearest {family} within {range}") \
			.replace("{family}", str(run.get("family", ""))) \
			.replace("{range}", str(run.get("range", "")).replace("_", " "))
		EventSheetPatternFacts.claim(sheet, "turret", row_uid, row_uid,
			run.get("evidence", PackedStringArray()), words, "weapon_kit", TURRET_ACE_IDS)


## S17. {local name: {object, cell}} for every `var data = <tilemap>.get_cell_tile_data(<cell>)` the
## file writes. A name filled twice from different cells is dropped: the same word may not read two
## ways on one sheet, exactly as the tween notes refuse a line that means two things.
static func tile_data_local_map(sheet: EventSheetResource) -> Dictionary:
	var found: Dictionary = {}
	var disagreed: Dictionary = {}
	if sheet == null:
		return found
	for line: String in ordered_code_lines(sheet):
		var text: String = line.strip_edges()
		if not text.begins_with("var "):
			continue
		for separator: String in [" := ", " = "]:
			var at: int = text.find(separator)
			if at < 0:
				continue
			var name_text: String = text.substr(4, at - 4).strip_edges()
			var colon_at: int = name_text.find(":")
			if colon_at >= 0:
				name_text = name_text.substr(0, colon_at).strip_edges()
			if not EventSheetSentence.is_identifier(name_text):
				break
			var parts: Dictionary = EventSheetSentence.tile_data_call_parts(
				text.substr(at + separator.length()), {})
			if parts.is_empty():
				break
			if found.has(name_text) and found[name_text] != parts:
				disagreed[name_text] = true
			found[name_text] = parts
			break
	for name_text: String in disagreed:
		found.erase(name_text)
	return found


## S8 / S10 / S15. What the FILE says about its Godot-systems patterns, as the fact maps the sentence
## grammar reads:
##
##   loading_paths     {local: the scene path literal it was declared from}
##   loading_progress  {local: true} - the arrays passed to load_threaded_get_status
##   loading_status    {local: the path expression its status was read for}
##   message_names     {function: its published name}   message_params {function: parameter names}
##   nav_agents        {local: true}   nav_waypoints {local: true}   nav_avoidance bool
##
## Everything here is a plain walk of lines the sheet already holds. A fact that the file does not
## state outright is simply absent, and every reading built on it then declines to fire.
static func godot_systems_facts(sheet: EventSheetResource) -> Dictionary:
	var loading_paths: Dictionary = {}
	var loading_progress: Dictionary = {}
	var loading_status: Dictionary = {}
	var nav_agents: Dictionary = {}
	var nav_waypoints: Dictionary = {}
	var avoidance_wired: bool = false
	var computed_handler: bool = false
	if sheet == null:
		return {}
	for line: String in _systems_fact_lines(sheet):
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		var declared: String = _declared_local_name(text)
		var value: String = _declared_local_value(text)
		var scene_path: String = _scene_path_literal(value)
		if not declared.is_empty() and not scene_path.is_empty():
			loading_paths[declared] = scene_path
		if not declared.is_empty() and _is_nav_agent_value(value, declared, sheet):
			nav_agents[declared] = true
		var status_at: int = text.find(EventSheetSentence.LOAD_STATUS_HEAD)
		if status_at >= 0:
			var close_at: int = EventSheetSentence.closing_paren(
				text, status_at + EventSheetSentence.LOAD_STATUS_HEAD.length() - 1)
			if close_at > 0:
				var inside: String = text.substr(
					status_at + EventSheetSentence.LOAD_STATUS_HEAD.length(),
					close_at - status_at - EventSheetSentence.LOAD_STATUS_HEAD.length())
				var asked: PackedStringArray = EventSheetSentence.split_top_level(inside, ",")
				if asked.size() >= 1 and not declared.is_empty():
					loading_status[declared] = asked[0].strip_edges()
				if asked.size() >= 2 and EventSheetSentence.is_identifier(asked[1].strip_edges()):
					loading_progress[asked[1].strip_edges()] = true
		if not declared.is_empty() and value.ends_with(".get_next_path_position()"):
			nav_waypoints[declared] = true
		if text.contains(".set_velocity(") or text.begins_with("set_velocity("):
			avoidance_wired = true
		if text.contains("velocity_computed"):
			computed_handler = true
	var message_names: Dictionary = {}
	var message_params: Dictionary = {}
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function == null:
			continue
		var mode_note: String = ""
		for annotation: String in event_function.annotation_lines:
			var words: String = EventSheetSentence.rpc_mode_words(annotation)
			if annotation.strip_edges().begins_with("@rpc"):
				mode_note = words
		if not _declares_rpc(event_function):
			continue
		var name_text: String = event_function.function_name.strip_edges()
		if name_text.is_empty():
			continue
		message_names[name_text] = EventSheetSentence.function_words(name_text)
		message_params[name_text] = parameter_names_of(event_function)
		if not mode_note.is_empty():
			message_names["%s::modes" % name_text] = mode_note
	return {
		"loading_paths": loading_paths,
		"loading_progress": loading_progress,
		"loading_status": loading_status,
		"message_names": message_names,
		"message_params": message_params,
		"nav_agents": nav_agents,
		"nav_waypoints": nav_waypoints,
		"nav_avoidance": avoidance_wired and computed_handler
	}


## S8 / S9 / S10 / S15. The evidence each pattern is recognised BY, as the fragments a line of the
## event has to contain. Frozen alongside the pattern ids: a chip, a Doctor smell and a Manual page
## all key on the same claim, so what counts as evidence may gain entries but never lose them.
const SYSTEMS_PATTERN_EVIDENCE: Dictionary = {
	"background_loading": [
		"load_threaded_request", "load_threaded_get_status", "load_threaded_get(",
		"THREAD_LOAD_LOADED", "change_scene_to_packed"
	],
	"movement": [
		"move_and_slide()", "velocity.limit_length(", "move_toward(velocity",
		"add_collision_exception_with(", "set_collision_mask_value(", "lerp_angle("
	],
	"multiplayer": [
		".rpc(", ".rpc_id(", "multiplayer.is_server()", "is_multiplayer_authority()",
		"multiplayer.get_unique_id()"
	],
	"navigation": [
		"target_position =", "get_next_path_position()", "is_navigation_finished()",
		"velocity_computed"
	],
	# V4. A data asset is loaded, saved or re-read by name. `.tres")` is the strongest single mark a
	# line carries - it is the file extension a data asset has, quoted, which no other shape writes.
	"data_asset": [
		"ResourceSaver.save(", ".tres\")", ".res\")", "ResourceLoader.exists(",
		"ResourceLoader.load("
	],
	# V5. The window, the frame cap, the anti-aliasing level, and the two lines a screenshot is made
	# of. Every fragment is the exact Godot spelling the reading above is claimed at.
	"window": [
		"get_window().", "DisplayServer.window_set_", "Engine.max_fps", "msaa_2d", "msaa_3d",
		"get_texture().get_image()", ".save_png(", ".save_jpg("
	],
	# X23. A swipe is a touch-down, a touch-up and the distance between them measured against a clock;
	# a drawn shape is the drag positions gathered into a stroke. Every fragment here is a Godot
	# spelling only a touch script writes, so a mouse-driven file cannot wander into the claim.
	"swipe": [
		"InputEventScreenTouch", "InputEventScreenDrag", "stroke.append("
	],
	# X25. The shooter's three shapes: the ray down the crosshair, the blast that pushes bodies away
	# from a point, and the wrapping index over a weapons list.
	"hitscan": [
		"project_ray_origin(", "project_ray_normal(", "PhysicsRayQueryParameters3D.create(",
		"intersect_shape(", "apply_impulse(", "weapons.size()", "weapon_index"
	],
	# X25. The counter every level of this shape keeps. `secret` is the word the Area itself is marked
	# with, which is why the claim asks for it beside a count rather than for a count alone.
	# Y18 adds the end-of-level tally's own lines: the kills, the par and the flag that says the
	# level is over are what turn a counter into a scoreboard, and a stats screen that lifted whole
	# would otherwise claim nothing at all.
	"secrets": [
		"secrets_found", "is_in_group(\"secret\")", "secrets_total",
		"level_over", "par_seconds", "level_seconds"
	],
	# Y16. The keycard shape, and every fragment of it names a KEY. A list called `keys` is not enough
	# on its own - plenty of dictionaries are keyed - so the claim wants a key going into it, a door
	# saying which one it wants, or one of the two calls the door contract is made of.
	"keys_doors": [
		"needs_key", "locked_door_tried(", "open_door()", "_key\" in keys", "keys.append(\""
	],
	# Y18. An alert is the noise words aimed at somebody: one enemy shouts and the room answers.
	# Only the two halves of that call are evidence. The infighting row is deliberately NOT here -
	# its lines are a group test and an assignment, which every project writes about everything, so
	# it counts through the row's own ace_id below and never through a fragment of text.
	"detection": [
		".alerted(", "func alerted("
	],
	# X29. The options screen: the live Input Map being rewritten, the settings the packs read, and
	# the spoken text. Each fragment is a line only an options screen writes.
	"accessibility_options": [
		"InputMap.action_erase_events(", "InputMap.action_add_event(", "effect_strength",
		"no_flashing", "text_size_scale", "aim_assist_radius", "DisplayServer.tts_speak(",
		"show_caption"
	],
	# Y12. A skill tree names itself: the points it is spent in, and the question it asks before
	# every unlock. A dictionary of flags spells neither, which is what keeps a door that remembers
	# being opened from reading as a talent tree.
	"skill_tree": [
		"skill_points", "skill_point", "can_unlock(", "unlock_skill(", "Upgrades.unlock_skill"
	]
}

## The one line the chip says for each pattern - the sheet's own name for the shape.
const SYSTEMS_PATTERN_WORDS: Dictionary = {
	"background_loading": "Loading a layout in the background",
	"movement": "Movement math a behavior already has words for",
	"multiplayer": "Messages sent between peers",
	"navigation": "Following a path a navigation agent worked out",
	"data_asset": "Values kept in data assets rather than in the file",
	"window": "Window, render and screenshot settings",
	"swipe": "Swipes and drawn shapes",
	"hitscan": "Shots, blasts and an arsenal",
	"secrets": "Secrets found",
	"keys_doors": "Keys and the doors that want them",
	"detection": "Enemies noticing you, and each other",
	"accessibility_options": "An accessibility options screen",
	"skill_tree": "A skill tree - prerequisites, points and unlocks"
}

## The sheet ACEs each pattern is made of - what Adopt behavior would write, and what the Manual's
## "Patterns using this" is derived from.
const SYSTEMS_PATTERN_ACES: Dictionary = {
	"background_loading": ["LoadLayoutInBackground", "LayoutFinishedLoading", "GoToLoadedLayout",
		"LoadingProgress"],
	"movement": ["ApplyGravitySimple", "AccelerateVelocityX", "AccelerateVelocityY", "LimitSpeed",
		"MoveAndSlide", "IgnoreCollisionsWith", "SetCollisionMaskBit", "RotateToward"],
	"multiplayer": ["SendMessageToEveryone", "SendMessageToHost", "SendMessageToPeer", "IsHost",
		"OwnsThisObject", "MyPeerId"],
	"navigation": ["SetNavTarget", "MoveAlongPath", "IsNavFinished", "GetNextPathPosition"],
	"data_asset": ["DataAsset", "SaveDataAsset", "ReloadDataAsset", "ResourcesInFolder",
		"ResourceInFolder", "LoadResourceOrDefault"],
	"window": ["WindowSetSize", "WindowGoFullscreen", "WindowGoWindowed", "WindowSetVSync",
		"WindowSetMaxFps", "WindowSetAntiAliasing", "WindowScreenshot", "WindowSaveImageAs",
		"WindowViewportImage"],
	"swipe": [],
	"hitscan": ["FireHitscan", "ExplodeAt", "SwitchToNextWeapon", "SwitchToPreviousWeapon",
		"CurrentWeapon"],
	"secrets": ["MarkSecretFound", "SecretsFoundCount", "SecretAlreadyFound", "FormatTime"],
	"keys_doors": ["PickUpKey", "HasKey", "NeedsKey", "KeysHeld", "TryDoor", "OpenDoor"],
	"detection": ["AlertEnemiesWithin", "RetaliateAgainstAttacker", "MakeNoise"],
	# The rebinding rows that already shipped belong to this pattern too: a remap screen written with
	# Clear The Bindings Of and Bind Control To IS the shape, and an event whose whole block lifted
	# would otherwise claim nothing at all.
	"accessibility_options": ["StartListeningForControl", "AnyInputReceived", "RebindControlTo",
		"TreatControlAsToggle", "SetEffectStrength", "SetNoFlashing", "SetTextSizeScale",
		"SetAimAssistRadius", "UsePalette", "SpeakText", "PlaySoundWithCaption",
		"InputWaitForNextKey", "InputClearBindings", "InputBindTo", "InputSaveBindings",
		"InputLoadBindings", "InputResetBindings"],
	"skill_tree": ["load_skill_tree", "unlock_skill", "respec", "is_skill_unlocked",
		"can_unlock_skill", "can_afford_skill", "skill_requires", "skill_points_left",
		"skill_cost_of", "skill_level_of", "earn_skill_points", "apply_grants_to"]
}


## S8 / S9 / S10 / S15. Records which events of a sheet read as one of the four Godot-systems
## patterns, with the statements themselves as evidence and - where one ships - the behavior that could
## replace the hand-written shape.
##
## Called once at the top of a row build, after the registry has been cleared. Nothing here draws
## anything: the chip, the hover and Adopt behavior all read the claims back.
static func claim_godot_systems_patterns(sheet: EventSheetResource) -> void:
	if sheet == null:
		return
	var dimension_3d: bool = sheet.host_class.strip_edges().contains("3D")
	for entry: Variant in sheet.events:
		_claim_systems_in(sheet, entry, dimension_3d, 0)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			for event_entry: Variant in (entry as EventFunction).events:
				_claim_systems_in(sheet, event_entry, dimension_3d, 0)


## One event of the walk: the lines it holds decide which pattern it owns, and its sub-events are
## walked in turn so a pattern spread over a parent and its children is claimed where it starts.
static func _claim_systems_in(sheet: EventSheetResource, entry: Variant, dimension_3d: bool,
		depth: int) -> void:
	if depth > 64 or not (entry is EventRow):
		return
	var event_row: EventRow = entry as EventRow
	var lines: PackedStringArray = PackedStringArray()
	_collect_code(event_row, lines)
	var text: String = "\n".join(lines)
	# A half-lifted event is the normal case, so the ids of the rows that DID lift count as grounds
	# beside the lines that stayed verbatim: a Move row and the `move_and_slide()` beside it are the
	# same pattern, and an event whose whole block lifted would otherwise claim nothing at all. An id
	# is an internal name, so whatever quotes a claim to a READER leaves those out again.
	var picked: PackedStringArray = _systems_row_ace_ids(event_row)
	for pattern: String in SYSTEMS_PATTERN_EVIDENCE:
		var evidence: PackedStringArray = PackedStringArray()
		for line: String in text.split("\n"):
			for fragment: Variant in (SYSTEMS_PATTERN_EVIDENCE[pattern] as Array):
				if line.contains(str(fragment)) and not evidence.has(line.strip_edges()):
					evidence.append(line.strip_edges())
		for ace_id: String in picked:
			if (SYSTEMS_PATTERN_ACES[pattern] as Array).has(ace_id) and not evidence.has(ace_id):
				evidence.append(ace_id)
		if evidence.is_empty():
			continue
		EventSheetPatternFacts.claim(sheet, pattern, event_row.event_uid, event_row.event_uid, evidence,
			str(SYSTEMS_PATTERN_WORDS.get(pattern, "")),
			_systems_adoptable(pattern, text, picked, dimension_3d),
			PackedStringArray(SYSTEMS_PATTERN_ACES.get(pattern, [])))
	for sub_event: Variant in event_row.sub_events:
		_claim_systems_in(sheet, sub_event, dimension_3d, depth + 1)


## Every ace_id an event's trigger, conditions and actions carry, so a lifted row can be evidence of
## the pattern it belongs to just as a hand-written line is.
static func _systems_row_ace_ids(event_row: EventRow) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var rows: Array = [event_row.trigger]
	rows.append_array(event_row.conditions)
	rows.append_array(event_row.actions)
	for entry: Variant in rows:
		if not (entry is Resource):
			continue
		var ace_id: String = str((entry as Resource).get("ace_id")).strip_edges()
		if not ace_id.is_empty() and not found.has(ace_id):
			found.append(ace_id)
	return found


## Which shipped behavior could replace a hand-rolled pattern, by the SHAPE the evidence has: a body
## that applies gravity is a platformer, one that only steers is an eight-direction mover, and a
## navigation block belongs to whichever pathfinding pack matches its dimension. "" when nothing
## ships for the pattern, which is what keeps the chip from offering an adoption nobody can take.
static func _systems_adoptable(pattern: String, text: String, picked: PackedStringArray,
		dimension_3d: bool) -> String:
	match pattern:
		"movement":
			var gravity: bool = text.contains("velocity.y +=") or picked.has("ApplyGravitySimple") or picked.has("ApplyGravity")
			return "platformer_movement" if gravity else "eight_direction"
		"navigation":
			return "nav_agent_3d" if dimension_3d else "platformer_pathfinding"
		# X23. A hand-written swipe or shape matcher has a behaviour that does the whole thing
		# properly, with the thresholds, the diagonals and the stroke templates - so the honest offer
		# is the pack, not a row that writes a third of it.
		"swipe":
			return "touch_gestures"
		# Y12. A hand-written tree has a pack that does the whole thing - the asset, the
		# prerequisite walk, the points and the grants - so the honest offer is the pack.
		"skill_tree":
			return "upgrades"
	return ""


## S8. A declaration's value as the QUOTED project path it is, or "" when it is not one. A lifted
## variable row is written back out with its value already unquoted, so both spellings answer the
## same literal and the layout gets named either way.
static func _scene_path_literal(value: String) -> String:
	var text: String = value.strip_edges()
	if text.begins_with("\"") and text.ends_with("\"") and text.length() > 1:
		text = text.substr(1, text.length() - 2)
	if not text.begins_with("res://") or text.contains("\""):
		return ""
	return "\"%s\"" % text


## Every line the systems facts are read from: the hand-written ones in file order, then the LIFTED
## rows written back out as the code they stand for. A half-lifted file is the normal case - the
## importer turns `velocity.y += gravity * delta` into a Movement row while the line beside it stays
## verbatim - so a fact walk that saw only one of the two would answer differently depending on how
## much of the file happened to lift, which is exactly the drift these facts exist to prevent.
static func _systems_fact_lines(sheet: EventSheetResource) -> PackedStringArray:
	var lines: PackedStringArray = ordered_code_lines(sheet)
	var lifted: PackedStringArray = PackedStringArray()
	for entry: Variant in sheet.events:
		_collect_code(entry, lifted)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			for event_entry: Variant in (entry as EventFunction).events:
				_collect_code(event_entry, lifted)
	for block: String in lifted:
		lines.append_array(block.split("\n"))
	return lines


## S10. True when a function carries an `@rpc` annotation - which is what makes it a message rather
## than a function anyone can call locally.
static func _declares_rpc(event_function: EventFunction) -> bool:
	for annotation: String in event_function.annotation_lines:
		if annotation.strip_edges().begins_with("@rpc"):
			return true
	return false


## The name a `var x ... = ...` line declares, or "" when the line declares nothing. The walrus, the
## annotated and the `@onready` spellings all answer the same name.
## A lifted row is written back out as `name = value` with no `var` in front of it (the declaration
## and the value it was filled from are two rows by then), so both spellings answer the same name.
static func _declared_local_name(text: String) -> String:
	var head: String = text.trim_prefix("@onready ").strip_edges()
	if not head.begins_with("var "):
		head = "var %s" % head
	for separator: String in [" := ", " = "]:
		var at: int = head.find(separator)
		if at < 0:
			continue
		var name_text: String = head.substr(4, at - 4).strip_edges()
		var colon_at: int = name_text.find(":")
		if colon_at >= 0:
			name_text = name_text.substr(0, colon_at).strip_edges()
		return name_text if EventSheetSentence.is_identifier(name_text) else ""
	return ""


## The value a `var x ... = ...` line is declared from, or "" when the line declares nothing.
static func _declared_local_value(text: String) -> String:
	var head: String = text.trim_prefix("@onready ").strip_edges()
	if not head.begins_with("var "):
		head = "var %s" % head
	for separator: String in [" := ", " = "]:
		var at: int = head.find(separator)
		if at >= 0:
			return head.substr(at + separator.length()).strip_edges()
	return ""


## S15. True when a declaration's value IS a navigation agent - either a node whose name says so, or
## a variable the sheet typed as one. A guess would put path words on an object that has no path.
static func _is_nav_agent_value(value: String, declared: String, sheet: EventSheetResource) -> bool:
	for agent_class: String in EventSheetSentence.NAV_AGENT_CLASSES:
		if value.contains(agent_class):
			return true
	var known: String = str(object_class_map(sheet).get(declared, ""))
	return EventSheetSentence.NAV_AGENT_CLASSES.has(known)


## T5 / T6 / T25 / T26. What the FILE says about the behaviors it hand-rolls, as the fact maps the
## sentence grammar reads:
##
##   sight_rays      {local: true} - the locals a raycast used for a sight test lives in
##   sight_range     the one number a distance guard is measured against, "" when there is none
##   drag_offsets    {local: true} - the vectors a grab offset is remembered in
##   drag_flags      {local: true} - the booleans raised beside one of those, and lowered elsewhere
##   noise_locals    {local: true}   noise_type  the Advanced Random word for the type the file set
##   random_locals   {local: true} - the seeded generators
##   datetime_locals {local: true} - the locals the system clock's fields are read out of
##
## Everything here is a plain walk of lines the sheet already holds, hand-written and lifted alike. A
## fact the file does not state outright is simply absent, and every reading built on it declines to
## fire, which is what keeps an ordinary boolean from being read as somebody's drag.
static func behavior_words_facts(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {}
	var sight_rays: Dictionary = {}
	var drag_offsets: Dictionary = {}
	var noise_locals: Dictionary = {}
	var random_locals: Dictionary = {}
	var datetime_locals: Dictionary = {}
	var sight_range: String = ""
	var noise_type: String = ""
	# The boolean a drag raises is only a drag flag when the file ALSO lowers it and remembers a grab
	# offset right beside it, so both halves are gathered first and matched up at the end.
	var raised: Dictionary = {}
	var lowered: Dictionary = {}
	var offset_at: PackedInt32Array = PackedInt32Array()
	var lines: PackedStringArray = behavior_code_lines(sheet)
	for index: int in lines.size():
		var text: String = lines[index].strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		var noise_word: String = _noise_type_word(text)
		if not noise_word.is_empty():
			noise_type = noise_word
		if sight_range.is_empty():
			sight_range = _sight_range_name(text)
		var declared: String = _declared_local_name(text)
		if declared.is_empty():
			continue
		var value: String = _declared_local_value(text)
		if _is_sight_ray_value(value, declared, sheet):
			sight_rays[declared] = true
		if value.begins_with("FastNoiseLite.new("):
			noise_locals[declared] = true
		if value.begins_with("RandomNumberGenerator.new("):
			random_locals[declared] = true
		if value == "Time.get_datetime_dict_from_system()":
			datetime_locals[declared] = true
		if EventSheetSentence.is_grab_offset_value(value):
			drag_offsets[declared] = true
			offset_at.append(index)
		if value == "true":
			raised[declared] = index
		elif value == "false":
			lowered[declared] = true
	var drag_flags: Dictionary = {}
	for flag_name: Variant in raised:
		if not lowered.has(flag_name):
			continue
		for line_index: int in offset_at:
			if absi(line_index - int(raised[flag_name])) <= 1:
				drag_flags[flag_name] = true
	return {
		"sight_rays": sight_rays,
		"sight_range": sight_range,
		"drag_offsets": drag_offsets,
		"drag_flags": drag_flags,
		"noise_locals": noise_locals,
		"noise_type": noise_type,
		"random_locals": random_locals,
		"datetime_locals": datetime_locals
	}


## T5 / T6 / T7 / T25 / T26. Every line the behavior facts and the behavior claims are read from, in
## FILE order: the hand-written ones as they stand, and the rows the importer already lifted written
## back out as the statement each stands for.
##
## A half-lifted file is the normal case - `rng.seed = hash("x")` becomes a Set property row while the
## line beside it stays verbatim - so a walk that saw only one of the two would answer differently
## depending on how much of the file happened to lift, which is exactly the drift these facts exist to
## prevent. Order matters as well as content: the boolean a drag raises is only recognised BY sitting
## beside the line that remembers the grab offset.
static func behavior_code_lines(sheet: EventSheetResource) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if sheet == null:
		return lines
	for entry: Variant in sheet.events:
		_append_behavior_lines(entry, lines, 0)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			for event_entry: Variant in (entry as EventFunction).events:
				_append_behavior_lines(event_entry, lines, 0)
	return lines


## One row unit of that walk. Depth-limited so a sheet that somehow nests into itself cannot spin.
static func _append_behavior_lines(entry: Variant, lines: PackedStringArray, depth: int) -> void:
	if depth > 64 or entry == null or not (entry is Resource):
		return
	if entry is RawCodeRow:
		lines.append_array((entry as RawCodeRow).code.split("\n"))
		return
	if entry is LocalVariable:
		var variable: LocalVariable = entry as LocalVariable
		lines.append("var %s = %s" % [variable.name, str(variable.default_value)])
		return
	if entry is EventRow:
		var event_row: EventRow = entry as EventRow
		_append_behavior_lines(event_row.trigger, lines, depth + 1)
		for local: Variant in event_row.local_variables:
			_append_behavior_lines(local, lines, depth + 1)
		for condition: Variant in event_row.conditions:
			_append_behavior_lines(condition, lines, depth + 1)
		for action: Variant in event_row.actions:
			_append_behavior_lines(action, lines, depth + 1)
		for sub_event: Variant in event_row.sub_events:
			_append_behavior_lines(sub_event, lines, depth + 1)
		return
	var line: String = _lifted_row_line(entry as Resource)
	if not line.is_empty():
		lines.append(line)
	# The head's own declarations are rows of a kind of their own, and a sheet may gain more of them.
	# Anything that carries a name and a value therefore reads as the declaration it is, rather than
	# being dropped for not being one of the shapes above.
	if line.is_empty() and (entry as Resource).get("var_name") != null:
		lines.append("var %s = %s" % [
			str((entry as Resource).get("var_name")), str((entry as Resource).get("default_value"))])


## The statement one LIFTED row stands for, in the spelling the row's own reading is built from - so
## a fact and a claim answer the same whether the importer took the line or left it. "" when the row
## has no such statement, which is the cue to leave it out rather than guess at one.
static func _lifted_row_line(resource: Resource) -> String:
	var params: Variant = resource.get("params")
	if not (params is Dictionary) or (params as Dictionary).is_empty():
		params = resource.get("parameters")
	if not (params is Dictionary):
		return ""
	var values: Dictionary = params
	var ace_id: String = str(resource.get("ace_id")).strip_edges()
	var target: String = str(values.get("target", "")).strip_edges()
	match ace_id:
		"SetVar":
			return "%s = %s" % [str(values.get("var_name", "")), str(values.get("value", ""))]
		"SetLocalVar", "SetLocalVarInferred", "SetLocalVarTyped":
			return "var %s = %s" % [str(values.get("name", "")), str(values.get("value", ""))]
		"SetProperty":
			return "%s.%s = %s" % [target, str(values.get("property", "")), str(values.get("value", ""))]
		"SetButtonDisabled":
			return "%s.disabled = %s" % [target, str(values.get("disabled", ""))]
		"SetCollisionLayerBit":
			return "set_collision_layer_value(%s, %s)" % [
				str(values.get("layer", "")), str(values.get("enabled", ""))]
		"RayCast2DForceUpdate", "RayCast3DForceUpdate":
			return "%s.force_raycast_update()" % target
		"IsFartherThan":
			return "%s.distance_to(%s) > %s" % [
				str(values.get("a", "")), str(values.get("b", "")), str(values.get("distance", ""))]
		"ExpressionIsTrue":
			return str(values.get("expr", ""))
		"IsOverlappingAtOffset":
			return "test_move(transform, %s)" % str(values.get("offset", ""))
		"ReturnValue":
			return "return %s" % str(values.get("value", ""))
		"CallMethod":
			return "%s.%s(%s)" % [target, str(values.get("method", "")), str(values.get("args", ""))]
	return ""


## T5. True when a declaration's value IS the ray a sight test is cast with - a node whose name says
## so, one made outright, or a local the sheet already typed as one.
static func _is_sight_ray_value(value: String, declared: String, sheet: EventSheetResource) -> bool:
	for ray_class: String in EventSheetSentence.SIGHT_RAY_CLASSES:
		if value.contains(ray_class):
			return true
	var known: String = str(object_class_map(sheet).get(declared, ""))
	return EventSheetSentence.SIGHT_RAY_CLASSES.has(known)


## T5. The number a `global_position.distance_to(t) > sight_range` guard is measured against, or ""
## when the line is not that guard. Only a plain name is claimed: a computed range has no word a row
## could honestly print after "within".
static func _sight_range_name(text: String) -> String:
	if not text.contains(".distance_to("):
		return ""
	for operator: String in [" > ", " >= "]:
		var at: int = EventSheetSentence.top_level_index(text, operator)
		if at < 0:
			continue
		var limit: String = text.substr(at + operator.length()).strip_edges().trim_suffix(":")
		if EventSheetSentence.is_identifier(limit):
			return limit
	return ""


## T25. The Advanced Random word for a `noise.noise_type = FastNoiseLite.TYPE_PERLIN` line, or "" for
## every other line. A file that never states a type is read with the plain `Noise` head.
static func _noise_type_word(text: String) -> String:
	if not text.contains("noise_type") or not text.contains("FastNoiseLite."):
		return ""
	for constant_name: Variant in EventSheetSentence.NOISE_TYPE_WORDS:
		if text.ends_with("FastNoiseLite.%s" % str(constant_name)):
			return str(EventSheetSentence.NOISE_TYPE_WORDS[constant_name])
	return ""


## T5 / T6 / T7 / T22 / T23 / T25 / T26. The evidence each behavior pattern is recognised BY, as the
## fragments a line of the event has to contain. Frozen alongside the pattern ids: a chip, a Doctor
## smell and a Manual page all key on the same claim, so this may gain entries but never lose them.
const BEHAVIOR_PATTERN_EVIDENCE: Dictionary = {
	"line_of_sight": ["force_raycast_update()", ".is_colliding()", "intersect_ray(",
		"target_position = to_local("],
	"drag_drop": ["- get_global_mouse_position()", "get_global_mouse_position() +",
		"- get_viewport().get_mouse_position()", "get_viewport().get_mouse_position() +"],
	"anchor": ["set_anchors_preset(", "set_anchors_and_offsets_preset(", "anchor_left =",
		"anchor_right =", "anchor_top =", "anchor_bottom ="],
	"solid": ["set_collision_layer_value(", "CollisionShape2D.disabled",
		"CollisionShape3D.disabled", "CollisionPolygon2D.disabled", "CollisionPolygon3D.disabled"],
	"jumpthru": ["one_way_collision"],
	"create_object": [".instantiate()"],
	"overlap": ["overlaps_body(", "overlaps_area(", "get_overlapping_areas()",
		"get_overlapping_bodies()", "test_move(", "move_and_collide("],
	"advanced_random": ["rand_weighted(", ".seed = ", "FastNoiseLite", ".get_noise_"],
	"date": ["get_datetime_dict_from_system()", "get_unix_time_from_system()",
		"get_date_string_from_system()", "get_time_string_from_system()"]
}

## The one line the chip says for each behavior pattern - the sheet's own name for the shape.
const BEHAVIOR_PATTERN_WORDS: Dictionary = {
	"line_of_sight": "A sight test cast at a target",
	"drag_drop": "Picking a thing up with the pointer",
	"anchor": "Where a panel sits when the window resizes",
	"solid": "What this body is to the others",
	"jumpthru": "A platform you can jump up through",
	"create_object": "Making an object and putting it somewhere",
	"overlap": "Asking what is touching, and what is just below",
	"advanced_random": "Seeded randomness and noise",
	"date": "The clock and the calendar"
}

## The sheet ACEs each behavior pattern is made of - what the Manual's "Patterns using this" reads.
const BEHAVIOR_PATTERN_ACES: Dictionary = {
	"line_of_sight": ["RayCast2DForceUpdate", "RayCast3DForceUpdate", "IsFartherThan"],
	"drag_drop": ["SetVar"],
	"anchor": ["SetProperty", "CallMethod"],
	"solid": ["SetCollisionLayerBit", "SetButtonDisabled"],
	"jumpthru": ["SetProperty"],
	"create_object": ["SetLocalVar", "AddChild"],
	"overlap": ["ExpressionIsTrue", "OnCollision"],
	"advanced_random": ["SetProperty", "SetVar"],
	"date": ["SetLocalVarTyped", "SetVar", "GetUnixTime", "GetSystemDate", "GetSystemTime"]
}


## T5 / T6 / T7 / T22 / T23 / T25 / T26. Records which events of a sheet read as one of the behavior
## patterns, with the statements themselves as evidence and - where one ships - the behavior that could
## replace the hand-written shape. Called once at the top of a row build, after the registry has been
## cleared; nothing here draws anything, because the chip and the hover read the claims back.
static func claim_behavior_patterns(sheet: EventSheetResource) -> void:
	if sheet == null:
		return
	var dimension_3d: bool = sheet.host_class.strip_edges().contains("3D")
	for entry: Variant in sheet.events:
		_claim_behaviors_in(sheet, entry, dimension_3d, 0)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			for event_entry: Variant in (entry as EventFunction).events:
				_claim_behaviors_in(sheet, event_entry, dimension_3d, 0)


## One event of the walk: the lines it holds decide which behaviors it owns, and its sub-events are
## walked in turn so a shape spread over a parent and its children is claimed where it starts.
static func _claim_behaviors_in(sheet: EventSheetResource, entry: Variant, dimension_3d: bool,
		depth: int) -> void:
	if depth > 64 or not (entry is EventRow):
		return
	var event_row: EventRow = entry as EventRow
	# The event's own lines, hand-written and lifted alike - the same walk the facts read, so a claim
	# and the words it is about can never disagree about what the event says.
	var lines: PackedStringArray = PackedStringArray()
	_append_behavior_lines(event_row, lines, 0)
	for pattern: String in BEHAVIOR_PATTERN_EVIDENCE:
		var evidence: PackedStringArray = PackedStringArray()
		for line: String in lines:
			for fragment: Variant in (BEHAVIOR_PATTERN_EVIDENCE[pattern] as Array):
				if line.contains(str(fragment)) and not evidence.has(line.strip_edges()):
					evidence.append(line.strip_edges())
		if evidence.is_empty():
			continue
		EventSheetPatternFacts.claim(sheet, pattern, event_row.event_uid, event_row.event_uid,
			evidence, str(BEHAVIOR_PATTERN_WORDS.get(pattern, "")),
			_behavior_adoptable(pattern, dimension_3d),
			PackedStringArray(BEHAVIOR_PATTERN_ACES.get(pattern, [])))
	for sub_event: Variant in event_row.sub_events:
		_claim_behaviors_in(sheet, sub_event, dimension_3d, depth + 1)


## Which shipped behavior could replace a hand-rolled shape. Solid and Jump-thru are deliberately not
## in the table: they are what a Godot body already IS, so there is nothing to adopt - and offering an
## adoption nobody can take is exactly what an empty answer here prevents.
static func _behavior_adoptable(pattern: String, dimension_3d: bool) -> String:
	match pattern:
		"line_of_sight":
			return "line_of_sight_3d" if dimension_3d else "line_of_sight"
		"drag_drop":
			return "drag_drop"
		"anchor":
			return "anchor"
		"advanced_random":
			return "advanced_random"
	return ""


## R9. {timer tag: true when it fires once} from the `$Timer.one_shot = true` lines the file holds.
## Only a plain `$Node` / `%Node` receiver and a literal `true` / `false` count: a mode assembled at
## runtime is not a fact the reading may claim. Empty whenever the file says nothing.
static func timer_mode_map(sheet: EventSheetResource) -> Dictionary:
	var modes: Dictionary = {}
	if sheet == null:
		return modes
	for line: String in _sheet_code_lines(sheet):
		var text: String = line.strip_edges()
		var split_at: int = text.find(".one_shot = ")
		if split_at <= 0:
			continue
		var value: String = text.substr(split_at + 12).strip_edges()
		if value != "true" and value != "false":
			continue
		var tag: String = EventSheetSentence.timer_tag(text.substr(0, split_at))
		if tag.is_empty():
			continue
		modes[tag] = value == "true"
	return modes


## R3. What the file says about its tween chains, as {"locals": {name: true}, "notes": {line: note}}.
##
## `locals` are the names declared from `create_tween()`; `notes` says `after` for a step that follows
## another step of the same chain and `parallel` for one that runs beside the step before it. Only a
## line the walk can read in FILE order earns a note, and a line whose exact text appears both as a
## first step and as a later one earns none: the same words may not read two ways on one sheet.
static func tween_chain_facts(sheet: EventSheetResource) -> Dictionary:
	var locals: Dictionary = {}
	var notes: Dictionary = {}
	if sheet == null:
		return {"locals": locals, "notes": notes}
	# {local name: [has a step already, the next step runs beside the last one]}
	var chains: Dictionary = {}
	# {line: the note EVERY occurrence of it earned, or "" once two occurrences disagree}
	var observed: Dictionary = {}
	var disagreed: Dictionary = {}
	for line: String in ordered_code_lines(sheet):
		var text: String = EventSheetSentence.tween_note_key(line)
		if text.is_empty():
			continue
		var declared: String = _tween_declared_local(text)
		if not declared.is_empty():
			locals[declared] = true
			chains[declared] = [false, false]
			continue
		var parts: Dictionary = EventSheetSentence.tween_chain_parts(text, {"tween_locals": locals})
		if parts.is_empty():
			continue
		var owner_name: String = str(parts.get("local", ""))
		if owner_name.is_empty() or not chains.has(owner_name):
			continue
		var state: Array = chains[owner_name]
		var method: String = str(parts.get("method", ""))
		if method == "set_parallel":
			state[1] = true
			continue
		if method == "kill" or method == "set_loops":
			continue
		var note: String = ""
		if bool(state[1]):
			note = "parallel"
		elif bool(state[0]):
			note = "after"
		state[0] = true
		if observed.has(text) and str(observed[text]) != note:
			disagreed[text] = true
		observed[text] = note
	for text: String in observed:
		var note: String = str(observed[text])
		if note.is_empty() or disagreed.has(text):
			continue
		notes[text] = note
	return {"locals": locals, "notes": notes}


## R3. The local a `var t = create_tween()` line declares, or "" when the line declares nothing of
## the sort. The walrus and the annotated spellings all answer the same name.
static func _tween_declared_local(text: String) -> String:
	if not text.begins_with("var "):
		return ""
	for separator: String in [" := ", " = "]:
		var at: int = text.find(separator)
		if at < 0:
			continue
		var value: String = text.substr(at + separator.length()).strip_edges()
		if not EventSheetSentence.TWEEN_MAKERS.has(value):
			return ""
		var name_text: String = text.substr(4, at - 4).strip_edges()
		var colon_at: int = name_text.find(":")
		if colon_at >= 0:
			name_text = name_text.substr(0, colon_at).strip_edges()
		return name_text if EventSheetSentence.is_identifier(name_text) else ""
	return ""


## Every line of hand-written GDScript the sheet holds, in the order the FILE writes them - top level
## first, then each function's body, each event's actions before its sub-events. The reversed walk
## the fact maps use elsewhere cannot answer a question about what comes BEFORE what, which is the
## only question a chain of steps asks.
static func ordered_code_lines(sheet: EventSheetResource) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if sheet == null:
		return lines
	for event_entry: Variant in sheet.events:
		_append_ordered_lines(event_entry, lines, 0)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			for event_entry: Variant in (function_entry as EventFunction).events:
				_append_ordered_lines(event_entry, lines, 0)
	return _joined_continuation_lines(lines)


## The same lines with every trailing-`\` run folded into the one statement it is, so a chain written
## across three lines is one entry here exactly as it is one row on the canvas.
static func _joined_continuation_lines(lines: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var pending: String = ""
	for line: String in lines:
		var text: String = line.rstrip(" \t")
		if not pending.is_empty():
			text = pending + " " + text.strip_edges()
			pending = ""
		if text.ends_with("\\"):
			pending = text.substr(0, text.length() - 1).rstrip(" \t")
			continue
		out.append(text)
	if not pending.is_empty():
		out.append(pending)
	return out


## One entry of the ordered walk. Depth-limited so a sheet that somehow nests into itself cannot
## spin here.
## The lines ONE row unit holds, in file order - a function's body, an event and everything under it.
## The public door onto the shared walk below, for the pattern readings, which ask what a single
## owning row says rather than what the whole sheet says.
static func append_body_lines(entry: Variant, lines: PackedStringArray) -> void:
	_append_ordered_lines(entry, lines, 0)


static func _append_ordered_lines(entry: Variant, lines: PackedStringArray, depth: int) -> void:
	if depth > 64:
		return
	if entry is RawCodeRow:
		lines.append_array((entry as RawCodeRow).code.split("\n"))
		return
	# A line the importer already claimed is not raw text any more, so the statement it stands for is
	# rebuilt from the row - in exactly the spelling the row's own reading is built from, which is what
	# keeps the two sides of the chain map agreeing on what "the same line" is.
	if entry is ACEAction:
		var params: Dictionary = (entry as ACEAction).params
		if params.is_empty():
			params = (entry as ACEAction).parameters
		match (entry as ACEAction).ace_id:
			# Batch 8 - the arithmetic and assignment steps a pattern is MADE of. Without these the
			# lifted half of a countdown is invisible here, and the pattern that spans a lifted line
			# and a raw one would never be seen at all.
			"SetVar":
				lines.append("%s = %s" % [str(params.get("var_name", "")), str(params.get("value", ""))])
			"AddVar":
				lines.append("%s += %s" % [str(params.get("var_name", "")), str(params.get("amount", ""))])
			"SubtractVar":
				lines.append("%s -= %s" % [str(params.get("var_name", "")), str(params.get("amount", ""))])
			"SetLocalVar", "SetLocalVarInferred":
				lines.append("var %s = %s" % [str(params.get("name", "")), str(params.get("value", ""))])
			"SetLocalVarTyped":
				lines.append("var %s: %s = %s" % [
					str(params.get("name", "")), str(params.get("var_type", "")), str(params.get("value", ""))])
			"CallMethod":
				lines.append("%s.%s(%s)" % [
					str(params.get("target", "")), str(params.get("method", "")), str(params.get("args", ""))])
			# The waits a SEQUENCE is made of. An `await` lifts to one of these rows, so without them a
			# cutscene body arrives here as its doing-steps alone and the sequence reading - two waits
			# with something between them - could never see the waits it is named after.
			"Wait":
				lines.append("await get_tree().create_timer(%s).timeout" % str(params.get("seconds", "")))
			"AwaitSignal":
				lines.append("await %s" % str(params.get("signal_expression", "")))
			"AwaitNextFrame":
				lines.append("await get_tree().process_frame")
			_:
				# T1 / T3 / T4 - the steps a behavior shape is MADE of, whether the importer claimed a
				# typed line for a shipped row or the picker wrote the row outright. Without them the
				# file cannot tell that it is a projectile at all: the step and the gravity pull are
				# exactly the two lines that say so.
				var shaped: String = EventSheetBehaviorShapes.line_for((entry as ACEAction).ace_id, params)
				if not shaped.is_empty():
					lines.append(shaped)
		return
	if entry is EventRow:
		# T2 - a `for` the importer lifted lives on a pick filter rather than in any text, so its header
		# is rebuilt here like every other lifted line. The family a nearest-in-family loop searched is
		# named on that one line and nowhere else, and a walk that could not see it would read the loop
		# without ever knowing what it was looking through.
		for filter_entry: Variant in (entry as EventRow).pick_filters:
			var pick: PickFilter = filter_entry as PickFilter
			if pick == null or pick.collection_kind != PickFilter.CollectionKind.EXPRESSION:
				continue
			if pick.iterator_name.strip_edges().is_empty():
				continue
			lines.append("for %s in %s:" % [pick.iterator_name, pick.collection_value])
		# Batch 8 - a pattern's two halves often sit on opposite sides of one event: `cooldown -= delta`
		# in the action lane and `cooldown <= 0` in the condition lane. A walk that saw only the actions
		# could never put the two together, so a lifted comparison is rebuilt here too.
		for condition_entry: Variant in (entry as EventRow).conditions:
			var condition_row: ACECondition = condition_entry as ACECondition
			if condition_row == null or condition_row.ace_id != "CompareVar":
				continue
			var condition_params: Dictionary = condition_row.params
			if condition_params.is_empty():
				condition_params = condition_row.parameters
			lines.append("%s %s %s" % [str(condition_params.get("var_name", "")),
				str(condition_params.get("op", "")), str(condition_params.get("value", ""))])
		# X21 / X26 - the RUN the condition lane stands for, rebuilt as the `if` it compiles to. Two
		# questions this walk has to answer are runs whose halves mean nothing apart: a roll that is
		# either won or guaranteed, and a health threshold guarded by the phase the fight is in.
		# Once the importer has lifted such a line into rows there is no text left to read it from,
		# so the line is rebuilt here - and ONLY for a run of two or more terms, because a single
		# term is already visible through its own row and repeating it would say the same thing twice.
		var run_line: String = _condition_run_line(entry as EventRow)
		if not run_line.is_empty():
			lines.append(run_line)
		for action_entry: Variant in (entry as EventRow).actions:
			_append_ordered_lines(action_entry, lines, depth + 1)
		for sub_entry: Variant in (entry as EventRow).sub_events:
			_append_ordered_lines(sub_entry, lines, depth + 1)


## X21 / X26. The `if ...:` a row's CONDITION RUN stands for, or "" when the row has no run to
## rebuild - fewer than two terms, a term whose spelling the row does not carry, or a disabled one.
## The joiner is the row's own, so an OR block reads back as the `or` it compiles to.
static func _condition_run_line(row: EventRow) -> String:
	var terms: PackedStringArray = PackedStringArray()
	for entry: Variant in row.conditions:
		var condition_row: ACECondition = entry as ACECondition
		if condition_row == null or not condition_row.enabled:
			return ""
		var text: String = _condition_expression(condition_row)
		if text.is_empty():
			return ""
		terms.append(text)
	if terms.size() < 2:
		return ""
	var joiner: String = " or " if row.condition_mode == EventRow.ConditionMode.OR else " and "
	return "if %s:" % joiner.join(terms)


## One lifted condition's expression, from the template the row baked and the parameters it holds.
## "" whenever the spelling cannot be reproduced exactly - a multi-line template, a placeholder with
## no value - because a half-substituted line would be a reading built on a sentence nobody wrote.
static func _condition_expression(condition_row: ACECondition) -> String:
	var params: Dictionary = condition_row.params
	if params.is_empty():
		params = condition_row.parameters
	var template: String = condition_row.codegen_template
	if template.is_empty():
		if condition_row.ace_id != "CompareVar":
			return ""
		template = "{var_name} {op} {value}"
	if template.contains("\n"):
		return ""
	var text: String = template
	for key: Variant in params.keys():
		text = text.replace("{%s}" % str(key), str(params[key]))
	if text.contains("{"):
		return ""
	return "not (%s)" % text if condition_row.negated else text


## Every line of hand-written GDScript the sheet still holds, from the top level down through event
## bodies and function bodies. One shared walk so a reading that needs a fact from a NEIGHBOURING
## line asks the sheet once per rebuild rather than once per row.
static func _sheet_code_lines(sheet: EventSheetResource) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var pending: Array = []
	pending.append_array(sheet.events)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			pending.append_array((function_entry as EventFunction).events)
	var guard: int = 0
	while not pending.is_empty() and guard < 20000:
		guard += 1
		var entry: Variant = pending.pop_back()
		if entry is RawCodeRow:
			lines.append_array((entry as RawCodeRow).code.split("\n"))
			continue
		# A line the importer already claimed is not raw text any more, so the assignment it stands for
		# is rebuilt from the row - otherwise a fact stated in a LIFTED line would be invisible here.
		if entry is ACEAction:
			var params: Dictionary = (entry as ACEAction).params
			match (entry as ACEAction).ace_id:
				"SetProperty":
					lines.append("%s.%s = %s" % [
						str(params.get("target", "")), str(params.get("property", "")), str(params.get("value", ""))])
				"SetOneShot":
					lines.append("%s.one_shot = %s" % [str(params.get("target", "")), str(params.get("one_shot", ""))])
			continue
		if entry is EventRow:
			pending.append_array((entry as EventRow).actions)
			pending.append_array((entry as EventRow).sub_events)
	return lines


## P9. True when the opened file is the script the SCENE ITSELF carries - the one on its root node.
## The scene scan already answers exactly this (it records a script only when the ROOT carries it), so
## this is a lookup rather than a second walk of the project.
static func is_scene_root_script(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	var source_path: String = str(sheet.external_source_path).strip_edges()
	if source_path.is_empty():
		return false
	return not ViewportRowBuilder.scene_using_script(source_path).is_empty()


## Q5/Q6/Q11. What the sheet's variable declarations say about their values, as three maps:
##
##   "types"           {name: declared type word}     - "Array", "Dictionary", "String", "Direction"
##   "enum_types"      {name: enum name}              - only the ones typed with an enum THIS sheet declares
##   "percent_members" {name: true}                   - the ones an `@export_range(0, 1)` marked as a fraction
##
## Nothing is guessed: a variable with no declared type appears in none of them, and the readings
## that depend on these fall back to the plain words they already had.
static func declared_type_map(sheet: EventSheetResource) -> Dictionary:
	var types: Dictionary = {}
	var enum_types: Dictionary = {}
	var percent_members: Dictionary = {}
	if sheet == null:
		return {"types": types, "enum_types": enum_types, "percent_members": percent_members}
	var enum_names: Dictionary = (enum_member_map(sheet).get("names", {}) as Dictionary)
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable == null or variable.name.strip_edges().is_empty():
			continue
		var declared_type: String = variable.type_name.strip_edges()
		if not declared_type.is_empty() and declared_type != "Variant":
			types[variable.name] = declared_type
			if enum_names.has(declared_type):
				enum_types[variable.name] = declared_type
		if _is_fraction_range(variable.export_hint):
			percent_members[variable.name] = true
	return {"types": types, "enum_types": enum_types, "percent_members": percent_members}


## Q5. True when an export hint says the value runs from 0 to 1 - the range the engine itself treats
## as a fraction (alpha, volume, a blend weight), and the one an event sheet shows as a percentage.
## Matched on the two numbers only, so `@export_range(0, 1, 0.01)` and `@export_range(0.0, 1.0)` both
## count and `@export_range(0, 100)` does not.
static func _is_fraction_range(export_hint: String) -> bool:
	var text: String = export_hint.strip_edges()
	if not text.begins_with("@export_range(") or not text.ends_with(")"):
		return false
	var parts: PackedStringArray = text.substr(14, text.length() - 15).split(",", false)
	if parts.size() < 2:
		return false
	return parts[0].strip_edges().to_float() == 0.0 and parts[1].strip_edges().to_float() == 1.0


## M38. The sheet's enums, as {"names": {EnumName: true}, "members": {MEMBER: how many enums declare
## it}}. The count is what decides whether a member may drop its enum name: `State.PATROL` reads
## `PATROL` only while no other enum on the sheet has a `PATROL` of its own.
## Q11 added a third map, "values": {EnumName: {number: MEMBER}}, so a number written into a variable
## typed with one of these enums can read as the member it names. GDScript's own numbering rule is
## followed exactly - members count up from 0 and an explicit `= n` restarts the count at n.
static func enum_member_map(sheet: EventSheetResource) -> Dictionary:
	var names: Dictionary = {}
	var members: Dictionary = {}
	var values: Dictionary = {}
	if sheet == null:
		return {"names": names, "members": members, "values": values}
	for entry: Variant in sheet.events:
		var enum_row: EnumRow = entry as EnumRow
		if enum_row == null or enum_row.enum_name.strip_edges().is_empty():
			continue
		names[enum_row.enum_name.strip_edges()] = true
		var numbered: Dictionary = {}
		var next_value: int = 0
		for value: String in enum_row.members:
			# A value may carry its number ("PATROL = 0"); the NAME is its head.
			var member: String = value.strip_edges()
			if member.contains("="):
				var written: String = member.substr(member.find("=") + 1).strip_edges()
				member = member.substr(0, member.find("=")).strip_edges()
				if written.is_valid_int():
					next_value = written.to_int()
			if member.is_empty():
				continue
			members[member] = int(members.get(member, 0)) + 1
			if not numbered.has(next_value):
				numbered[next_value] = member
			next_value += 1
		values[enum_row.enum_name.strip_edges()] = numbered
	return {"names": names, "members": members, "values": values}


## M25. The name a script's own object goes by: its `class_name` first, then the class it extends -
## the node it sits on, which is the object a reader sees in the scene tree. Never `self`.
##
## A plain `extends Node` script with no class_name gets NO name, and its rows stay with System: a
## bare Node has nothing an object picture could show, and the file name it happens to be saved
## under is not a name anybody calls it by.
static func script_object_name(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	var declared: String = sheet.custom_class_name.strip_edges()
	if not declared.is_empty():
		return declared
	# On a BEHAVIOUR the host class belongs to `host`, the node the pack is attached TO - naming the
	# script after it would send a reader looking for the object on the wrong node.
	if sheet.behavior_mode or _declares_host(sheet):
		return ""
	var host_class: String = sheet.host_class.strip_edges()
	return host_class if not host_class.is_empty() and host_class != "Node" else ""


## True when the sheet keeps its own `host` reference - the mark of a behaviour, whose host class is
## the node it rides rather than the class the script itself is.
static func _declares_host(sheet: EventSheetResource) -> bool:
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable != null and variable.name == HOST_LABEL:
			return true
	return false


## M25. Every property the ENGINE reports on the class this script extends, as a set. A name the
## sheet declares as its own variable is removed: a script that keeps a variable called `position`
## means ITS variable, and reading it as the node's place would be a confident lie.
static func engine_property_set(sheet: EventSheetResource) -> Dictionary:
	var properties: Dictionary = {}
	if sheet == null:
		return properties
	var host_class: String = sheet.host_class.strip_edges()
	if host_class.is_empty() or not ClassDB.class_exists(host_class):
		return properties
	for entry: Dictionary in ClassDB.class_get_property_list(host_class, false):
		var property_name: String = str(entry.get("name", ""))
		# Category / group rows carry no name a row could ever set.
		if not property_name.is_empty() and not property_name.contains("/"):
			properties[property_name] = true
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable != null:
			properties.erase(variable.name)
	return properties


## M28. Each declared signal's parameter names, in order, so an emit reads with named payload chips.
static func signal_parameter_map(sheet: EventSheetResource) -> Dictionary:
	var declared: Dictionary = {}
	if sheet == null:
		return declared
	for entry: Variant in sheet.events:
		var signal_row: SignalRow = entry as SignalRow
		if signal_row == null:
			continue
		var names: PackedStringArray = PackedStringArray()
		for parameter: String in signal_row.params:
			# A declaration carries its type ("amount: int"); the NAME is its head, and the type is
			# never part of a sentence.
			var bare: String = parameter.strip_edges()
			if bare.contains(":"):
				bare = bare.substr(0, bare.find(":")).strip_edges()
			if not bare.is_empty():
				names.append(bare)
		if not names.is_empty():
			declared[signal_row.signal_name] = names
	return declared


## M26. The engine's own names for a method's arguments ("name", "custom_speed" for
## AnimatedSprite2D.play), so a call's chips say what each value MEANS. Empty whenever the class or
## the method is not one the engine knows - the chips then show plain values, which is the honest
## answer.
static func method_parameter_names(class_name_str: String, method_name: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var bare_class: String = class_name_str.strip_edges()
	if bare_class.is_empty() or method_name.strip_edges().is_empty():
		return names
	if not ClassDB.class_exists(bare_class) or not ClassDB.class_has_method(bare_class, method_name, false):
		return names
	for entry: Dictionary in ClassDB.class_get_method_list(bare_class, false):
		if str(entry.get("name", "")) != method_name:
			continue
		for argument: Variant in (entry.get("args", []) as Array):
			names.append(str((argument as Dictionary).get("name", "")))
		break
	return names


## "<Class>|<method>" -> the parameter names, so the reading asks the project's class list once.
static var _project_parameter_names: Dictionary = {}


## P5. The names of a method's arguments when the method belongs to a class the PROJECT declared
## rather than to the engine. A wired-up call names another object's own function far more often than
## an engine one, and its chips are worth naming too ("count = 3" rather than a bare 3). The engine's
## answer is asked for first, so an engine class never pays for the project lookup.
static func project_method_parameter_names(class_name_str: String, method_name: String) -> PackedStringArray:
	var engine_names: PackedStringArray = method_parameter_names(class_name_str, method_name)
	if not engine_names.is_empty():
		return engine_names
	var bare_class: String = class_name_str.strip_edges()
	if bare_class.is_empty() or method_name.strip_edges().is_empty():
		return PackedStringArray()
	var key: String = "%s|%s" % [bare_class, method_name]
	if _project_parameter_names.has(key):
		return _project_parameter_names[key]
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) != bare_class:
			continue
		var script: Script = load(str(entry.get("path", ""))) as Script
		if script == null:
			break
		for method_info: Dictionary in script.get_script_method_list():
			if str(method_info.get("name", "")) != method_name:
				continue
			for argument: Variant in (method_info.get("args", []) as Array):
				names.append(str((argument as Dictionary).get("name", "")))
			break
		break
	_project_parameter_names[key] = names
	return names


## M26. The class a call's object is, for the parameter-name lookup: whatever the sheet's own object
## map knows, else the object label itself when it IS a class name (`$Sprite2D` names its class).
static func class_of_object(object_label: String, class_map: Dictionary) -> String:
	var label: String = object_label.strip_edges()
	if label.is_empty():
		return ""
	var known: String = str(class_map.get(label, ""))
	if not known.is_empty():
		return known
	return label if ClassDB.class_exists(label) else ""


## M27. The event-sheet words for the two tick triggers. The trigger ids are untouched - this is the
## reading only, so a sheet still stores (and compiles to) exactly what it did before.
static func tick_trigger_words(trigger_id: String, display_text: String) -> String:
	match trigger_id:
		"OnPhysicsProcess":
			return "%s %s" % [EventSheetL10n.translate("Every tick"), EventSheetL10n.translate("(physics)")]
		"OnProcess":
			return "%s %s" % [EventSheetL10n.translate("Every tick"), EventSheetL10n.translate("(draw)")]
	# M41 - the collision family reads as the event-sheet's own two triggers.
	var collision: String = collision_trigger_words(trigger_id)
	if not collision.is_empty():
		return collision
	# X8 - a notifier's two signals ARE the sheet's "came into view" and "left view", in both node
	# generations: Godot spells them the same on the 2D notifier and the 3D one.
	var seen: String = EventSheetSentence.view_trigger_words(trigger_id)
	return seen if not seen.is_empty() else display_text


## S27. The tick triggers whose body carries no condition of its own read as a BLANK event, because
## that is what a blank event means in an event sheet: it runs every tick. Nothing is written into
## the condition lane for the every-frame tick - the empty lane IS the reading, and the hover says
## it in words. The physics tick keeps one muted note, because blank alone cannot say WHICH tick.
const BLANK_TICK_TRIGGER_IDS: PackedStringArray = ["OnProcess", "OnPhysicsProcess"]

## What the margin hover and the Explain panel say about a blank top-level event.
const BLANK_EVENT_HOVER: String = "runs every tick"

## S27. And about a blank SUB-event, which means the other half of the same rule: it simply follows
## the event above it, in order. Nothing is skipped and nothing is decided - which is exactly why the
## lane is empty, and why writing "Every Tick" there would be a plain lie about when its rows run.
const BLANK_SUB_EVENT_HOVER: String = "follows its parent, in order"


## S27. Whether a top-level event reads as a blank one, and what (if anything) its condition lane
## still says. `patterns_on` is the Patterns reading toggle: with it off, the tick trigger keeps its
## explicit Every tick words for readers who want them.
## Returns {} when the event keeps its own trigger words, else {"note": String} - "" for the
## every-frame tick, the muted physics note for the physics tick.
static func blank_tick_reading(trigger_id: String, has_conditions: bool, patterns_on: bool = true) -> Dictionary:
	if not patterns_on or has_conditions:
		return {}
	if trigger_id.is_empty():
		return {"note": ""}
	if not BLANK_TICK_TRIGGER_IDS.has(trigger_id):
		return {}
	if trigger_id == "OnPhysicsProcess":
		return {"note": "%s %s" % [
			EventSheetL10n.translate("every tick"), EventSheetL10n.translate("(physics)")]}
	return {"note": ""}


## P8. The notification a `_notification` branch reads as. Only the ones an event sheet already has a
## word for are named; every other notification humanizes, which says what happened without pretending
## the sheet has a trigger of its own for it.
const NOTIFICATION_TRIGGER_WORDS: Dictionary = {
	"NOTIFICATION_APPLICATION_PAUSED": "On suspended",
	"NOTIFICATION_APPLICATION_RESUMED": "On resumed",
	"NOTIFICATION_APPLICATION_FOCUS_OUT": "On lost focus",
	"NOTIFICATION_APPLICATION_FOCUS_IN": "On gained focus",
	"NOTIFICATION_WM_CLOSE_REQUEST": "On close",
	"NOTIFICATION_PAUSED": "On paused",
	"NOTIFICATION_UNPAUSED": "On unpaused",
	"NOTIFICATION_PREDELETE": "On destroyed"
}

## The trigger id prefix a lifted `_notification` branch carries, with Godot's own constant after it.
const NOTIFICATION_TRIGGER_PREFIX := "OnNotification:"

## P8/P9. The lifecycle triggers whose reading is the same wherever the script sits. `_ready` and
## `_exit_tree` are NOT here: what those two say depends on whether the file is the scene's own script,
## which is the whole point of P9.
const LIFECYCLE_TRIGGER_WORDS: Dictionary = {
	"OnDraw": "On draw",
	"OnEnterTree": "On created",
	"OnExitTree": "On destroyed"
}


## P8/P9. The lifecycle triggers in the event sheet's own words, and who they belong to.
##
## Always on, never behind the Familiar Words toggle: these are not a friendlier spelling of Godot's
## names, they ARE the sheet's trigger names, and a reader who knows the sheet should find them here.
## Godot's own word stays one hover away, as it does for every other reading.
##
## The scene decides two of them. A `_ready` on the script the SCENE ITSELF carries is the layout
## starting - there is one of those per layout, and it runs when the layout opens; a `_ready` on a
## script sitting on some object in the scene is that object being created, which happens once per
## instance. Same split for `_exit_tree`: the layout ending, or the object being destroyed.
##
## Returns {"text", "object"} - both always filled - or {} when the trigger is not a lifecycle one,
## which is the caller's cue to keep whatever it was already drawing.
static func lifecycle_trigger_reading(trigger_id: String, object_label: String,
		scene_root: bool, script_object: String) -> Dictionary:
	var owner: String = script_object.strip_edges()
	if owner.is_empty():
		owner = object_label
	var system: String = EventSheetL10n.translate("System")
	match trigger_id:
		"OnReady":
			if scene_root:
				return {"text": EventSheetL10n.translate("On start of layout"), "object": system}
			return {"text": EventSheetL10n.translate("On created"), "object": owner}
		"OnExitTree":
			if scene_root:
				return {"text": EventSheetL10n.translate("On end of layout"), "object": system}
			return {"text": EventSheetL10n.translate("On destroyed"), "object": owner}
	if LIFECYCLE_TRIGGER_WORDS.has(trigger_id):
		return {"text": EventSheetL10n.translate(str(LIFECYCLE_TRIGGER_WORDS[trigger_id])), "object": owner}
	if trigger_id.begins_with(NOTIFICATION_TRIGGER_PREFIX):
		# A notification is something that happened to the GAME, not to one node, so it belongs to
		# System - the same object the sheet files its other whole-game triggers under.
		return {"text": notification_trigger_words(trigger_id.substr(NOTIFICATION_TRIGGER_PREFIX.length())),
			"object": system}
	return {}


## P8. One notification constant in the sheet's words. An unknown one reads as its own name in plain
## words ("On wm mouse enter") rather than as the SCREAMING_CASE constant: the reader still learns what
## happened, and nothing claims a trigger the sheet does not have.
static func notification_trigger_words(constant_name: String) -> String:
	var bare: String = constant_name.strip_edges()
	if NOTIFICATION_TRIGGER_WORDS.has(bare):
		return EventSheetL10n.translate(str(NOTIFICATION_TRIGGER_WORDS[bare]))
	var humanized: String = bare.trim_prefix("NOTIFICATION_").capitalize().to_lower()
	if humanized.is_empty():
		return EventSheetL10n.translate("On notification")
	return "%s %s" % [EventSheetL10n.translate("On"), humanized]


## R25/R26. The input signals whose words belong to a DEVICE rather than to the node that emitted
## them: the cursor arriving at an object and leaving it, and a gamepad being plugged in or pulled
## out. Godot files all three as ordinary signals, so today they read as "On Mouse Entered" under the
## node - a name a reader has to translate back. The sheet already says `Cursor is over <object>` and
## `On gamepad connected / disconnected`, so those are the words, on the device the reader would look
## for them under.
##
## Returns {"object", "text", "note"} - `note` the muted half-word that says WHICH edge of the pair
## this handler is - or {} when the trigger is not one of the three, which keeps today's reading.
## `object_label` is the object the cursor is over; it is unused by the gamepad reading, which is
## about the machine and not about any one node.
static func input_signal_trigger_reading(trigger_id: String, object_label: String) -> Dictionary:
	var signal_name: String = trigger_id.strip_edges().trim_prefix("signal:")
	var over: String = object_label.strip_edges()
	match signal_name:
		"mouse_entered":
			if over.is_empty():
				return {}
			return {
				"object": EventSheetL10n.translate("Mouse"),
				"text": "%s %s" % [EventSheetL10n.translate("Cursor is over"), over],
				"note": EventSheetL10n.translate("(enters)")
			}
		"mouse_exited":
			if over.is_empty():
				return {}
			return {
				"object": EventSheetL10n.translate("Mouse"),
				"text": "%s %s" % [EventSheetL10n.translate("Cursor is over"), over],
				"note": EventSheetL10n.translate("(leaves)")
			}
		"joy_connection_changed":
			# One signal, both edges: Godot hands the answer over as a parameter rather than raising
			# two signals, so the row says both and the `connected` chip beside it says which.
			return {
				"object": EventSheetL10n.translate("Gamepad"),
				"text": EventSheetL10n.translate("On gamepad connected / disconnected"),
				"note": ""
			}
	return {}


## M41. An event sheet has one collision trigger and one for the overlap ending, where Godot has four
## signals (bodies and areas, entering and leaving). Keyed by the trigger id AND usable from the
## signal name, so a handler lifted from a `.connect(...)` line and one lifted from a declared
## `func _on_body_entered` read the same words. "" when the trigger is not one of the four.
static func collision_trigger_words(trigger_id: String) -> String:
	match trigger_id:
		"OnBodyEntered", "OnAreaEntered", "body_entered", "area_entered":
			return EventSheetL10n.translate("On collision with")
		"OnBodyExited", "OnAreaExited", "body_exited", "area_exited":
			return EventSheetL10n.translate("On stopped overlapping")
	return ""


## M33. The event-sheet words for a loop row, and the object it belongs to.
##
## Returns {"text", "object"} - `object` empty for the System loops, and the host for a loop over
## another object's children, which an event sheet draws as that object's own For each. A ring loop
## also carries a muted "note". The loop rows themselves are unchanged: this is what they SAY, never
## what they are.
##
## X31. `body` is the lines the loop runs, which is how the head can say what the loop is FOR: a
## count alone is a count, and the same count whose body gives each step its share of a full turn is
## a circle. Empty for every caller that has no body to hand, and the head reads as it always did.
static func loop_words(kind: int, iterator_name: String, collection: String,
		body: PackedStringArray = PackedStringArray()) -> Dictionary:
	var iterator: String = iterator_name.strip_edges()
	var source: String = collection.strip_edges()
	# X31. Asked before anything else, because a ring loop IS a plain count however the loop was
	# lifted - what tells a ring from a count is only ever the body under it.
	if kind != PickFilter.CollectionKind.WHILE and kind != PickFilter.CollectionKind.CHILDREN:
		var ring: Dictionary = ring_loop_words(iterator, source, body)
		if not ring.is_empty():
			return ring
	match kind:
		PickFilter.CollectionKind.REPEAT:
			var bounds: PackedStringArray = EventSheetSentence.split_top_level(source, ", ")
			# U2. The two loop shapes M28 left over: counting DOWN, and counting in steps. Both are
			# `range(from, to, step)`, and both are For loops a reader already knows - what a reader
			# needs is the last value the body actually sees, which is what the row says.
			if bounds.size() == 3:
				var stepped: String = _stepped_range_words(iterator, bounds)
				if not stepped.is_empty():
					return {"text": stepped, "object": ""}
			if bounds.size() == 2:
				# The event-sheet For loop is INCLUSIVE at both ends, and `range(2, 8)` stops at 7 - so the
				# row says 7, which is the last value the loop body actually sees.
				var last: String = _one_less(bounds[1])
				if not last.is_empty():
					return {"text": "%s \"%s\" %s %s %s %s" % [EventSheetL10n.translate("For"), iterator,
						EventSheetL10n.translate("from"), bounds[0], EventSheetL10n.translate("to"), last], "object": ""}
			var repeat_text: String = "%s %s %s" % [EventSheetL10n.translate("Repeat"), source, EventSheetL10n.translate("times")]
			if not iterator.is_empty():
				repeat_text += " (%s %s)" % [EventSheetL10n.translate("loopindex"), iterator]
			return {"text": repeat_text, "object": ""}
		PickFilter.CollectionKind.WHILE:
			return {"text": "%s %s" % [EventSheetL10n.translate("While"), source], "object": ""}
		PickFilter.CollectionKind.CHILDREN:
			return {"text": "%s %s" % [EventSheetL10n.translate("For each child"), iterator], "object": ""}
	# `for child in host.get_children()` is that object's own For each, exactly as a sheet draws it -
	# and a receiver-less `get_children()` is the script's own, which the object column already names.
	if source == "get_children()":
		return {"text": "%s %s" % [EventSheetL10n.translate("For each child"), iterator], "object": ""}
	# X12. A loop over ANOTHER object's children names whose children they are, in the possessive the
	# rest of the hierarchy vocabulary uses ("leader's children") - the object column cannot say it,
	# because the loop belongs to the sheet's own For each rather than to the object being walked.
	var children_of: String = _children_receiver(source)
	if not children_of.is_empty():
		var possessive: String = EventSheetL10n.translate("For each {item} in {object}'s children")
		return {"text": possessive.replace("{item}", iterator).replace("{object}", children_of),
			"object": ""}
	return {}


## X31. Whether this loop head COULD be a ring, decided from the head alone. Two string tests, and
## the reason the row builder never walks a loop's body to find out: a ring is a plain count -
## `for i in n:` or `for i in 8:` - and a range's bounds, a collection and a call are all different
## loop heads with words of their own.
static func ring_loop_possible(iterator: String, count: String) -> bool:
	if iterator.strip_edges().is_empty():
		return false
	var source: String = count.strip_edges()
	if source.is_empty():
		return false
	return EventSheetSentence.is_identifier(source) or source.is_valid_int()


## X31. The head of a RING loop: `for i in n:` whose body gives each step its share of a full turn.
## Reads `For i from 0 to n − 1` with `evenly around a circle` beside it, because the count is not
## what the loop is about - the circle is, and a reader scanning for the ring should not have to read
## three lines of trigonometry to find it.
##
## {} unless the loop is a plain count AND its own body writes `TAU * float(i) / float(n)` for THIS
## loop's index: a count whose body does something else is a count, and says so.
static func ring_loop_words(iterator: String, count: String, body: PackedStringArray) -> Dictionary:
	if body.is_empty() or not ring_loop_possible(iterator, count):
		return {}
	for line: String in body:
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		var value: String = text
		for separator: String in [" := ", " = "]:
			var at: int = EventSheetSentence.top_level_index(text, separator)
			if at > 0:
				value = text.substr(at + separator.length()).strip_edges()
				break
		if EventSheetSentence.turn_share_index(value) != iterator:
			continue
		return {
			"text": EventSheetL10n.translate("For {index} from 0 to {count} − 1") \
				.replace("{index}", iterator).replace("{count}", count),
			"object": "",
			"note": EventSheetL10n.translate("evenly around a circle")
		}
	return {}


## The object whose children an expression walks (`host.get_children()` -> "host"), or "" when the
## expression is anything else.
static func _children_receiver(expression: String) -> String:
	var text: String = expression.strip_edges()
	if not text.ends_with(".get_children()"):
		return ""
	var receiver: String = text.substr(0, text.length() - ".get_children()".length()).strip_edges()
	if receiver.is_empty() or receiver.contains("(") or receiver.contains(" "):
		return ""
	return EventSheetSentence.object_of_reference(receiver)


## U2. A three-argument `range(...)` as the For loop it is: `range(10, 0, -1)` counts down to 1,
## `range(0, 100, 10)` steps to 90. Both ends are the values the BODY sees, which is what a reader is
## looking for - Godot's exclusive stop is a language detail, and the row does the arithmetic once so
## nobody has to do it every time they read the line. "" unless every bound is a plain whole number
## and the step actually reaches the stop, because a row that guesses is worse than the code it read.
static func _stepped_range_words(iterator: String, bounds: PackedStringArray) -> String:
	for bound: String in bounds:
		if not bound.strip_edges().is_valid_int():
			return ""
	var from_value: int = bounds[0].strip_edges().to_int()
	var stop_value: int = bounds[1].strip_edges().to_int()
	var step: int = bounds[2].strip_edges().to_int()
	if step == 0 or (step > 0 and stop_value <= from_value) or (step < 0 and stop_value >= from_value):
		return ""
	# The last value the body sees: the final whole step that still stops short of the stop value.
	var span: int = absi(stop_value - from_value)
	var last_value: int = from_value + step * ((span - 1) / absi(step))
	var head: String = "%s \"%s\" %s %d" % [EventSheetL10n.translate("For"), iterator,
		EventSheetL10n.translate("from"), from_value]
	if step < 0:
		var down_text: String = "%s %s %d" % [head, EventSheetL10n.translate("down to"), last_value]
		return down_text if step == -1 else "%s %s %d" % [down_text,
			EventSheetL10n.translate("step"), absi(step)]
	var up_text: String = "%s %s %d" % [head, EventSheetL10n.translate("to"), last_value]
	return up_text if step == 1 else "%s %s %d" % [up_text, EventSheetL10n.translate("step"), step]


## `8` -> `7`, so a half-open Godot range reads as the inclusive event-sheet one. Empty when the bound
## is not a plain number - `range(2, n)` has no last value a reader could be shown.
static func _one_less(bound: String) -> String:
	var text: String = bound.strip_edges()
	return str(text.to_int() - 1) if text.is_valid_int() else ""


## M13/M20 - the object-label to class-name map recovered from a sheet, so any row naming one of
## these objects can draw its Godot class icon.
##
## Three sources, cheapest first, and nothing else: the pack's declared host class; every
## @onready node variable's declared type (both under its own name and under the node path it
## reads, so `hp_bar` and `%HpBar` both resolve); nothing is instantiated and no scene is opened,
## because this runs on every span rebuild. A node reference with no declared type simply gets no
## icon, which is the honest answer - a guessed icon is worse than none.
static func object_class_map(sheet: EventSheetResource) -> Dictionary:
	var map: Dictionary = {}
	if sheet == null:
		return map
	var host_class: String = sheet.host_class.strip_edges()
	if not host_class.is_empty() and host_class != "Node":
		map[HOST_LABEL] = host_class
		# M25 - the script's own object draws the picture of the class it IS, so a row that names it
		# (`Player ▸ Set X to 100`) shows the same icon the scene tree shows for that node.
		var script_object: String = script_object_name(sheet)
		if not script_object.is_empty():
			map[script_object] = host_class
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable == null or not variable.onready:
			continue
		var declared_type: String = variable.type_name.strip_edges()
		if declared_type.is_empty():
			continue
		map[variable.name] = declared_type
		# `%HpBar` / `$Head`: the row that USES the node often names the path rather than the
		# variable, so the path resolves to the same class. Both spellings, and the bare name
		# after the sigil, so "HpBar" resolves too.
		# M47 - a `get_node("A/B")` lookup names the same node `$A/B` does, so both spellings (and the
		# last segment the rows read it under) resolve to the class the variable declared.
		var node_reference: String = EventSheetSentence.node_lookup_text(variable.default_value.strip_edges())
		if node_reference.begins_with("%") or node_reference.begins_with("$"):
			map[node_reference] = declared_type
			map[node_reference.substr(1)] = declared_type
			map[EventSheetSentence.object_of_reference(node_reference)] = declared_type
	return map


## W14. The prefixes a plugin puts in front of every class it declares. They are there to keep the
## global class list from colliding, and they say nothing to a reader looking at one row - the same
## seven characters on every object is noise, not information.
const CLASS_NAME_PREFIXES: PackedStringArray = ["EventSheet", "EventForge"]


## W14. The object label a DECLARED CLASS reads under: `EventSheetACERegistry` reads `ACE registry`,
## `EventSheetFindBar` reads `Find bar`, `ContextMenu` reads `Context menu`.
##
## The plugin prefix comes off, the camel-case name splits into words, an all-caps run stays an
## acronym, and only the first word is capitalized - which is how a sheet writes the name of a thing
## rather than how a language writes a type. "" when there is no class name to read.
static func class_object_label(class_text: String) -> String:
	var bare: String = class_text.strip_edges()
	if bare.is_empty():
		return ""
	for prefix: String in CLASS_NAME_PREFIXES:
		if bare.begins_with(prefix) and bare.length() > prefix.length():
			bare = bare.substr(prefix.length())
			break
	var words: PackedStringArray = PackedStringArray()
	var current: String = ""
	for index: int in bare.length():
		var character: String = bare[index]
		var upper: bool = character == character.to_upper() and character != character.to_lower()
		# A new word starts at a capital that FOLLOWS a lower-case letter or a digit, so an acronym
		# run (`ACERegistry`) stays whole until the word after it begins.
		var previous_lower: bool = index > 0 and bare[index - 1] != bare[index - 1].to_upper()
		var next_lower: bool = index + 1 < bare.length() and bare[index + 1] != bare[index + 1].to_upper() \
			and bare[index + 1] == bare[index + 1].to_lower()
		if upper and not current.is_empty() and (previous_lower or (next_lower and current.length() > 1)):
			words.append(current)
			current = ""
		current += character
	if not current.is_empty():
		words.append(current)
	if words.is_empty():
		return bare
	var spelled: PackedStringArray = PackedStringArray()
	for index: int in words.size():
		var word: String = words[index]
		# An acronym is a word a reader reads as letters, so it keeps its capitals wherever it sits.
		if word == word.to_upper() and word.length() > 1:
			spelled.append(word)
		elif index == 0:
			spelled.append(word)
		else:
			spelled.append(word.to_lower())
	return " ".join(spelled)


## W14. The object column for a receiver whose declared CLASS the sheet knows, as {label, note} - the
## class in words, and the variable's own name muted beside it when the two differ. {} when nothing
## was declared, which leaves the label exactly as the row already read it.
##
## The variable name says who; the class says WHAT, and for tool code (`_registry`, `_x_plugin`,
## `helper`) the what is the informative half. Only a class the PROJECT declared is read this way -
## see the engine-class refusal below. Display-only: nothing here reaches a row or the file.
static func typed_object_label(object_label: String, context: Dictionary, humanize: bool) -> Dictionary:
	var label: String = object_label.strip_edges()
	if label.is_empty() or label == EventSheetSentence.OBJECT_SYSTEM:
		return {}
	var declared: String = str((context.get("variable_types", {}) as Dictionary).get(label, ""))
	if declared.is_empty() or declared.contains("["):
		return {}
	# An ENGINE class is left alone. `label ▸ Set horizontal alignment` already reads right: the class
	# behind a `Label` is drawn as its icon and says nothing the row does not, while the variable name
	# is the half that says WHICH one. The case this reading exists for is a class the project itself
	# declared - `EventSheetACERegistry`, `HudKit` - where the name is the only place the class is
	# ever written down and `_registry` says nothing at all.
	if ClassDB.class_exists(declared):
		return {}
	# Familiar Words off: the class exactly as the file declares it, because that is then the name
	# the reader is looking for in the code.
	if not humanize:
		return {"label": declared, "note": ""} if declared != label else {}
	var words: String = class_object_label(declared)
	if words.is_empty() or words == label:
		return {}
	var spelled_name: String = EventSheetViewportLenses.humanize_identifier(label)
	return {"label": words, "note": "" if spelled_name.to_lower() == words.to_lower() else spelled_name}


## X4. The classes a node holds when it is a camera PIVOT rather than an ordinary parent: a camera,
## or the arm one hangs off. A node holding anything else is somebody's node, and turning it is a turn.
const ORBIT_PIVOT_CHILD_CLASSES: PackedStringArray = ["Camera3D", "SpringArm3D"]


## X4. {object label: true} for every object of this sheet the SCENE says is a camera pivot - a node
## with at least one child and no child that is anything but a camera or a camera arm. Both the
## variable's own name and the `$Path` spelling resolve, because a row may name either.
##
## Answered from the .tscn the script sits in, once per rebuild, and simply empty when the script is
## not placed in a scene at all - in which case the orbit reading declines to fire and a `rotate_y`
## keeps the plain rotate it already reads as. Nothing here loads a scene: it is the same cached
## text walk the object bar and the behavior chips already run.
static func orbit_pivot_map(sheet: EventSheetResource) -> Dictionary:
	var pivots: Dictionary = {}
	if sheet == null:
		return pivots
	var source_path: String = str(sheet.external_source_path).strip_edges()
	if source_path.is_empty():
		return pivots
	var placement: Dictionary = ViewportRowBuilder.scene_using_script(source_path)
	var scene_path: String = str(placement.get("scene_path", ""))
	if scene_path.is_empty():
		return pivots
	# The scene's nodes, grouped by the parent each one names. A .tscn spells a root child's parent
	# as ".", and a deeper node's as the path from the root - which is exactly the key a child of
	# that node names, so one map answers for every depth.
	var children_by_parent: Dictionary = {}
	for entry: Variant in (EventSheetObjectFacts.scene_facts(scene_path).get("children", []) as Array):
		var child: Dictionary = entry
		var parent: String = str(child.get("parent", ""))
		if not children_by_parent.has(parent):
			children_by_parent[parent] = []
		(children_by_parent[parent] as Array).append(str(child.get("type", "")))
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable == null or not variable.onready:
			continue
		var reference: String = EventSheetSentence.node_lookup_text(variable.default_value.strip_edges())
		if not (reference.begins_with("$") or reference.begins_with("%")):
			continue
		var node_path: String = reference.substr(1)
		if not _holds_only_camera(children_by_parent.get(node_path, []) as Array):
			continue
		pivots[variable.name] = true
		pivots[EventSheetSentence.object_of_reference(reference)] = true
	return pivots


## X4. True when a node's children are a camera rig and nothing else. An empty list is not a pivot:
## a node with no children at all is a node somebody turns.
static func _holds_only_camera(child_types: Array) -> bool:
	if child_types.is_empty():
		return false
	for entry: Variant in child_types:
		var type_name: String = str(entry).strip_edges()
		if not Array(ORBIT_PIVOT_CHILD_CLASSES).has(type_name):
			return false
	return true


## M13 - the Godot class icon for an object label, or null when nothing is known (which is also
## what headless returns, so a headless render keeps the text-only look and never crashes).
static func class_icon_for(object_label: String, class_map: Dictionary) -> Texture2D:
	var trimmed: String = object_label.strip_edges()
	if trimmed.is_empty():
		return null
	var class_name_str: String = str(class_map.get(trimmed, ""))
	if class_name_str.is_empty():
		return null
	return ACEPickerDialog.editor_icon(class_name_str)


## M20 - the class name a node declaration shows after its value ("ProgressBar"), or "" when the
## variable declared no type.
static func declared_class_of(variable: LocalVariable) -> String:
	if variable == null or not variable.onready:
		return ""
	return variable.type_name.strip_edges()


## M20 - true when a variable is an OBJECT declaration rather than a value one: an @onready that
## reads a node out of the scene. Those are the ones that become the sheet's object list.
static func is_object_declaration(variable: LocalVariable) -> bool:
	if variable == null or not variable.onready:
		return false
	var value: String = variable.default_value.strip_edges()
	# M47 - `get_node("A/B")` names a node exactly as `$A/B` does, so it is the same declaration.
	return value.begins_with("%") or value.begins_with("$") \
		or value.begins_with("get_node(") or value.begins_with("get_node_or_null(")


## M47. What an object declaration's VALUE reads as: the node reference in its `$Path` spelling,
## whichever way the file spells it. A `get_node_or_null` lookup may find nothing, and that is worth
## saying, so the note comes back beside the value: {"value", "note"} - `note` empty for the rest.
static func object_declaration_value(variable: LocalVariable) -> Dictionary:
	if variable == null:
		return {"value": "", "note": ""}
	var raw: String = variable.default_value.strip_edges()
	var shown: String = EventSheetSentence.node_lookup_text(raw)
	var note: String = EventSheetL10n.translate("may be missing") if raw.begins_with("get_node_or_null(") else ""
	return {"value": shown, "note": note}


## M17 - the label on a folded code card: "code  12 lines". The exact GDScript is what the card
## opens to, and it is on the row's hover either way, so the closed card only has to say how much
## is behind it.
static func code_card_label(line_count: int) -> String:
	var lines_word: String = EventSheetL10n.translate("line") if line_count == 1 else EventSheetL10n.translate("lines")
	return "%d %s" % [line_count, lines_word]


## M17 - whether a raw block should render as ONE folded card rather than as statement rows.
## Reading mode folds it (a stubborn helper costs one row until you want it); authoring keeps the
## statement rows, because that is what you edit. The fold itself is view state, so the caller
## seeds it from the viewport's fold map with THIS as the default.
static func code_card_default_folded(reading_mode: bool) -> bool:
	return reading_mode


## The raw function name a one-call statement invokes ("add_look" from "add_look(a, b)" or from
## "self.add_look(a, b)"), or "" when the line is not a plain call. The sentence layer hands back
## a DISPLAY verb; this recovers the name to look the function up by.
static func called_function_name(code: String) -> String:
	var text: String = code.strip_edges()
	var open_at: int = text.find("(")
	if open_at <= 0 or not text.ends_with(")"):
		return ""
	var callee: String = text.substr(0, open_at).strip_edges()
	if callee.contains("."):
		callee = callee.substr(callee.rfind(".") + 1)
	if not EventSheetViewportLenses.is_identifier(callee):
		return ""
	return callee


## M16 - the sentence pieces for a call to a KNOWN function: "Functions > Call Add Look" plus one
## argument per parameter, named by the function's own parameter names so the call is
## self-documenting. Returns [] when the function is not one this sheet knows, which is the
## caller's cue to keep the ordinary call reading - a call to something unknown must not be
## dressed up as a project function.
##
## `parameter_names` is the callee's parameter list in order; a shorter list simply leaves the
## remaining arguments unnamed, so a signature the editor only partly knows still reads.
static func call_reading_pieces(
	display_name: String,
	arguments: PackedStringArray,
	parameter_names: PackedStringArray,
	humanize: bool,
	knob_names: Dictionary = {}
) -> Array:
	if display_name.strip_edges().is_empty():
		return []
	var pieces: Array = []
	pieces.append([EventSheetL10n.translate("Functions") + "  ", "object"])
	pieces.append([EventSheetL10n.translate("Call") + " ", "plain"])
	pieces.append([display_name, "name"])
	for index: int in range(arguments.size()):
		var parameter_name: String = parameter_names[index] if index < parameter_names.size() else ""
		var value: String = arguments[index].strip_edges()
		if humanize:
			value = EventSheetViewportLenses.humanize_expression(value, knob_names)
		else:
			value = EventSheetViewportLenses.possessive_in_expression(value, false)
		pieces.append(["   ", "plain"])
		pieces.append([EventSheetViewportLenses.call_argument_chip(parameter_name, value, false), "value"])
	return pieces


## M26. The whole reading of a call the sheet has no verb of its own for: Object, verb in words, one
## chip per argument, and never a pair of parentheses. Returns {"object", "pieces"} - {} when the
## line is not exactly one call, which is the caller's cue to keep whatever it was drawing.
##
## `class_map` is the sheet's object-to-class map, so the chips can be named by the engine's own
## parameter names whenever the object's class is known.
static func generic_call_pieces(code: String, context: Dictionary, class_map: Dictionary) -> Dictionary:
	var call: Dictionary = EventSheetSentence.call_parts(code.strip_edges())
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	var object_label: String = EventSheetSentence.call_object(str(call.get("target", "")), method, context)
	var parameter_names: PackedStringArray = method_parameter_names(class_of_object(object_label, class_map), method)
	var reading: Dictionary = EventSheetSentence.call_reading(code, context, parameter_names)
	if reading.is_empty():
		return {}
	var pieces: Array = []
	for entry: Variant in (reading.get("segments", []) as Array):
		var segment: Dictionary = entry
		pieces.append([str(segment.get("text", "")), str(segment.get("tone", "plain"))])
	return {"object": str(reading.get("object", "")), "pieces": pieces}


## The parameter names of one of the sheet's own functions, in order. Empty when the function is
## unknown or declared none - the call then reads with plain argument values.
## U9 / U10 / U11. {function name: its parameter names, in order} for every function the sheet
## declares. One walk, because a call that names a function may sit anywhere in the file.
static func function_parameter_map(sheet: EventSheetResource) -> Dictionary:
	var map: Dictionary = {}
	if sheet == null:
		return map
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function == null:
			continue
		var name_text: String = event_function.function_name.strip_edges()
		if name_text.is_empty():
			continue
		map[name_text] = parameter_names_of(event_function)
	return map


static func parameter_names_of(event_function: EventFunction) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if event_function == null:
		return names
	for entry: Variant in event_function.params:
		var param: ACEParam = entry as ACEParam
		if param != null and not param.id.strip_edges().is_empty():
			names.append(param.id.strip_edges())
	if names.is_empty():
		for legacy: Variant in event_function.parameters:
			var legacy_name: String = str(legacy).strip_edges()
			# The legacy spelling is a whole declaration ("amount: float"); the name is its head.
			if legacy_name.contains(":"):
				legacy_name = legacy_name.substr(0, legacy_name.find(":")).strip_edges()
			if not legacy_name.is_empty():
				names.append(legacy_name)
	return names


## Every @export knob name on a sheet, as a set. The humanized-names lens shows these with Godot's
## Inspector capitalisation, so it needs to know which names they are.
static func export_knob_names(sheet: EventSheetResource) -> Dictionary:
	var knobs: Dictionary = {}
	if sheet == null:
		return knobs
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable != null and variable.exported:
			knobs[variable.name] = true
	return knobs


# ── N4. Autoloads as globals, pack nodes as behaviours ────────────────────────────────────────
# An event sheet has project-wide globals and per-object behaviours; Godot spells those as autoload
# singletons and as behaviour packs mounted on child nodes. Both already READ - `Game.score += 1`
# lands under the object `Game`, `$Health.take_damage(3)` under `Health` - but neither says WHAT it
# is, so a reader cannot tell a project-wide global from a node, or a behaviour from a sibling.
# Everything below only decides what those two shapes SAY; no row model and no emitted line moves.


## The muted word an autoload's object label wears, so a global is legible as one.
const GLOBAL_NOTE := "(global)"

## Editor-theme icons tried, in order, as the globe on an autoload's row. Which names a build ships
## is not something a headless run can answer - it has no editor theme and returns null for every
## name - so this degrades to NO icon rather than to a wrong one, and the "(global)" note carries
## the meaning on its own.
const AUTOLOAD_ICON_NAMES: PackedStringArray = ["Environment", "World3D", "Node"]


## Every registered autoload, singleton name -> the path its script lives at.
##
## Deliberately not the project scanner's list: that one drops an autoload whose script sits inside
## an addon, which is right for a picker (its verbs arrive through the provider system) and wrong
## here - an autoload is a global a reader can name whatever folder it was written in.
##
## Walking ProjectSettings is not free and the answer is the same for every row in a rebuild, so
## every per-row caller takes the map as an argument and the row builder hoists this call beside its
## other per-rebuild lens caches. Nothing here caches: a hidden cache on a settings list that the
## Project Settings dialog can change under it would go stale exactly when it mattered.
static func autoload_singletons() -> Dictionary:
	var found: Dictionary = {}
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting: String = str(property_info.get("name", ""))
		if not setting.begins_with("autoload/"):
			continue
		var singleton: String = setting.trim_prefix("autoload/").strip_edges()
		if singleton.is_empty():
			continue
		found[singleton] = str(ProjectSettings.get_setting(setting, "")).trim_prefix("*").strip_edges()
	return found


## True when an object label names a registered autoload - the singleton name game code types.
static func is_autoload_object(object_label: String, autoloads: Dictionary) -> bool:
	var label: String = object_label.strip_edges()
	return not label.is_empty() and autoloads.has(label)


## An autoload's object label with its note: "Game" -> "Game (global)". Every other label comes back
## untouched, so a caller can pipe all of them through this one door.
static func global_object_label(object_label: String, autoloads: Dictionary) -> String:
	if not is_autoload_object(object_label, autoloads):
		return object_label
	return "%s %s" % [object_label.strip_edges(), EventSheetL10n.translate(GLOBAL_NOTE)]


## The globe an autoload's row wears, or null when the editor theme has nothing to give.
static func autoload_icon() -> Texture2D:
	for icon_name: String in AUTOLOAD_ICON_NAMES:
		var icon: Texture2D = ACEPickerDialog.editor_icon(icon_name)
		if icon != null:
			return icon
	return null


## N4. A condition written on an autoload's member, re-attributed to the autoload: `Game.score > 100`
## becomes the object `Game (global)` and the test `score > 100`, so the owner is visible in the
## object column instead of buried in the sentence.
##
## Returns {"object", "text"}, or {} when the term does not open with a registered singleton, which
## is the caller's cue to read it exactly as before.
static func global_condition(condition_text: String, autoloads: Dictionary) -> Dictionary:
	var text: String = condition_text.strip_edges()
	var dot_at: int = text.find(".")
	if dot_at <= 0:
		return {}
	var head: String = text.substr(0, dot_at).strip_edges()
	if not is_autoload_object(head, autoloads):
		return {}
	var rest: String = text.substr(dot_at + 1).strip_edges()
	if not EventSheetViewportLenses.is_identifier(leading_identifier(rest)):
		return {}
	return {"object": global_object_label(head, autoloads), "text": rest}


## N4. A lifted row whose parameters reach THROUGH an autoload to one of its members, re-read as a
## row belonging to that autoload: a Compare on `EventForgeBridge.score` becomes the object
## `EventForgeBridge (global)` comparing `score`, so the owner sits in the object column rather than
## inside the sentence, where it read as a possessive ("event forge bridge's score").
##
## Returns {"object", "params"} - the owner's label and a COPY of the parameters with the singleton
## prefix taken off every value that carried it. Returns {} unless exactly one autoload is named:
## a row reaching through two globals has no single owner, and guessing one would be a lie.
##
## Nothing here mutates the row. The caller reads the rewritten copy and throws it away; the stored
## parameters, and everything the row compiles to, are untouched.
static func global_member_params(params: Dictionary, autoloads: Dictionary) -> Dictionary:
	var owner: String = ""
	var rewritten: Dictionary = {}
	var changed: bool = false
	for key: Variant in params.keys():
		var value: String = str(params[key])
		var dot_at: int = value.find(".")
		var head: String = value.substr(0, dot_at).strip_edges() if dot_at > 0 else ""
		var member: String = leading_identifier(value.substr(dot_at + 1)) if dot_at > 0 else ""
		if head.is_empty() or member.is_empty() or not is_autoload_object(head, autoloads):
			rewritten[key] = params[key]
			continue
		if not owner.is_empty() and owner != head:
			return {}
		owner = head
		rewritten[key] = value.substr(dot_at + 1)
		changed = true
	if not changed:
		return {}
	return {"object": global_object_label(owner, autoloads), "params": rewritten}


## The identifier a piece of code opens with ("score" from "score > 100"), or "" when it opens with
## anything else.
static func leading_identifier(text: String) -> String:
	var out: String = ""
	for index: int in text.length():
		var character: String = text[index]
		if character == "_" or character.to_lower() != character.to_upper() or character.is_valid_int():
			out += character
		else:
			break
	return out


## Every behaviour pack the editor ships or the project drops in, indexed by every name a row could
## call it by: its `class_name`, its folder in PascalCase, and its `@ace_category` with the spaces
## taken out. The value is that category - the pack's own display name, which is exactly the chip
## that belongs between an object and its behaviour verb ("Player > [Platform] Set max speed").
##
## Derived, never a maintained table: packs are compiler output, and a new one appears by being
## dropped in a folder. Only each file's HEAD is read (class_name and the annotations all sit above
## the first member).
##
## Held for the session and dropped when the filesystem changes, like the object and signal caches
## beside it. It USED to re-ask the scanner on every call, and the scanner re-stats every pack folder
## to answer - which reads as free until you count the calls: one row rebuild of an opened pack asks
## for this index 219 times, and those 219 fleet-stats were most of the rebuild's cost.
static func behaviour_pack_index() -> Dictionary:
	if _pack_index_built:
		return _pack_index
	var scripts: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	var index: Dictionary = {}
	for path: String in scripts:
		var head: Dictionary = _pack_head(path)
		var category: String = str(head.get("category", ""))
		if category.is_empty():
			continue
		var declared: String = str(head.get("class", ""))
		if not declared.is_empty():
			index[declared] = category
		index[path.get_base_dir().get_file().to_pascal_case()] = category
		index[category.replace(" ", "")] = category
	_pack_index = index
	_pack_index_built = true
	return _pack_index


## Drops the pack index so the next reader rebuilds it. Wired to the editor's filesystem-changed
## hook, next to the object and signal caches; tests call it between fixtures.
static func clear_pack_index() -> void:
	_pack_index = {}
	_pack_index_built = false


static var _pack_index: Dictionary = {}
static var _pack_index_built: bool = false


## A pack script's `class_name` and its `@ace_category`, read off the file's head. Stops at the first
## member declaration: everything wanted here is above it, and a pack file runs to thousands of lines.
static func _pack_head(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var head: Dictionary = {}
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.begins_with("class_name "):
			head["class"] = line.substr("class_name ".length()).strip_edges()
		elif line.begins_with("## @ace_category("):
			head["category"] = line.substr("## @ace_category(".length()).trim_suffix(")").strip_edges() \
				.trim_prefix("\"").trim_suffix("\"")
		elif line.begins_with("func ") or line.begins_with("var ") or line.begins_with("signal "):
			break
	file.close()
	return head


## N4. The behaviour a call's object IS, when that object is a pack node mounted under the script's
## own node. Returns the pack's display name, or "" when the label names no pack the editor knows.
##
## Two ways in, both honest: the label's DECLARED class is a pack class (`@onready var health:
## SimpleHealthBehavior`), or the label itself is a name a pack goes by. The declared class is tried
## first, so a node merely NAMED like a pack but typed as something else keeps its own reading.
static func behaviour_pack_of(object_label: String, class_map: Dictionary) -> String:
	var label: String = object_label.strip_edges()
	if label.is_empty():
		return ""
	var index: Dictionary = behaviour_pack_index()
	var declared: String = str(class_map.get(label, ""))
	if not declared.is_empty():
		return str(index.get(declared, ""))
	return str(index.get(label, ""))


## N4 applied to a finished reading, at the one moment a lane holds both its object label and its
## sentence pieces. Returns {"object", "pieces", "icon"} - always all three, so a caller never has to
## ask whether anything happened.
##
## Two shapes and nothing else. An autoload gains its "(global)" note and a globe. A pack node hands
## its rows back to the object the pack is mounted ON, with the pack's name as the leading chip, so
## the row reads "Player > [Health] Take damage 3". When the sheet has no object of its own (a plain
## `extends Node`), a behaviour keeps its own label rather than being handed to nobody.
static func object_attribution(object_label: String, pieces: Array, script_object: String,
		class_map: Dictionary, autoloads: Dictionary) -> Dictionary:
	var label: String = object_label.strip_edges()
	var unchanged: Dictionary = {"object": object_label, "pieces": pieces, "icon": null}
	if label.is_empty():
		return unchanged
	if is_autoload_object(label, autoloads):
		return {"object": global_object_label(label, autoloads), "pieces": pieces, "icon": autoload_icon()}
	var pack: String = behaviour_pack_of(label, class_map)
	if pack.is_empty():
		return unchanged
	var owner: String = script_object.strip_edges()
	if owner.is_empty():
		return unchanged
	var chipped: Array = [[pack, "behaviour"], ["  ", "plain"]]
	chipped.append_array(pieces)
	return {"object": owner, "pieces": chipped, "icon": class_icon_for(owner, class_map)}


# ── N10. The census: every object an open file uses ───────────────────────────────────────────
# One derived list, read by the Objects rail, by the object popup and by the picker's object page,
# so those three can never disagree about what is in this file. Everything here is recovered FROM
# the sheet - there is no stored object list to fall out of date, and nothing is instantiated and no
# scene is opened, because a rail refresh runs on every sheet change.
#
# The order is the one a reader looks for: the script's own object first, then the nodes it reaches
# for, then the behaviours mounted on it, then the project-wide globals, then groups, then the
# scenes it spawns.


## The kinds an object entry can be, in the order the rail lists them.
const OBJECT_KINDS: PackedStringArray = ["script", "node", "behaviour", "autoload", "group", "scene"]

## The muted words each kind wears in the rail and in the popup's title line.
const OBJECT_KIND_WORDS: Dictionary = {
	"script": "this script",
	"node": "node",
	"behaviour": "behaviour",
	# P10 - the word "autoload" is Godot's; "(global)" is the sheet's, and it is the half that says
	# what it MEANS. The same pair reads on the Include bar of an opened autoload and in every other
	# sheet's `Game (global) ▸ …` row, so the rail, the head and the rows all name it identically.
	"autoload": "autoload (global)",
	"group": "group",
	"scene": "scene"
}


## Every object the open file uses, in rail order. Each entry:
##   {"label", "kind", "class", "path", "rows", "verbs", "signals", "note"}
## `rows` counts the TOP-LEVEL rows whose subtree mentions the object, which is the number a reader
## can go and click; `verbs` are the verbs the file calls on it, in first-seen order; `signals` the
## signals it connects or waits on.
static func object_census(sheet: EventSheetResource) -> Array:
	if sheet == null:
		return []
	var class_map: Dictionary = object_class_map(sheet)
	var autoloads: Dictionary = autoload_singletons()
	var by_label: Dictionary = {}
	var order: Array = []
	var script_object: String = script_object_name(sheet)
	if not script_object.is_empty():
		order.append(_new_object_entry(by_label, script_object, "script", sheet.host_class.strip_edges(), ""))
	# @onready node declarations are the file's own object list, already typed and already named.
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable == null or not is_object_declaration(variable):
			continue
		var declared: String = declared_class_of(variable)
		var kind: String = "behaviour" if not str(behaviour_pack_index().get(declared, "")).is_empty() else "node"
		var reference: String = str(variable.default_value).strip_edges()
		order.append(_new_object_entry(by_label, variable.name, kind, declared, reference))
		# `@onready var hp_bar := %HpBar` is ONE object with two names. Claiming the path's own label
		# here keeps the scan below from listing the same node a second time as "HpBar".
		by_label[EventSheetSentence.object_of_reference(reference)] = by_label[variable.name]
	# Then everything the CODE names that nothing declared: bare $Node / %Unique references, the
	# autoloads it touches, the groups it addresses and the scenes it preloads.
	var units: Array = _row_units(sheet)
	for unit: Dictionary in units:
		var code: String = str(unit.get("code", ""))
		for reference: String in _node_references(code):
			var label: String = EventSheetSentence.object_of_reference(reference)
			if label.is_empty() or by_label.has(label):
				continue
			var declared: String = str(class_map.get(label, ""))
			var pack: String = behaviour_pack_of(label, class_map)
			order.append(_new_object_entry(by_label, label,
				"behaviour" if not pack.is_empty() else "node",
				pack if not pack.is_empty() else declared, reference))
		for singleton: String in _autoload_references(code, autoloads):
			if not by_label.has(singleton):
				order.append(_new_object_entry(by_label, singleton, "autoload", "",
					str(autoloads.get(singleton, ""))))
		for group_name: String in _group_references(code):
			if not by_label.has(group_name):
				order.append(_new_object_entry(by_label, group_name, "group", "", ""))
		for scene_path: String in _scene_references(code):
			var scene_label: String = scene_path.get_file().get_basename().to_pascal_case()
			if not by_label.has(scene_label):
				order.append(_new_object_entry(by_label, scene_label, "scene", "", scene_path, scene_path))
	_tally_usage(order, by_label, units)
	for index: int in order.size():
		(order[index] as Dictionary)["found_at"] = index
	order.sort_custom(_by_kind_order)
	return order


## A fresh census entry, registered under its label so a second sighting only tallies.
## `match_token` is the text the tally counts by when it differs from the label - a scene is named
## in code by its res:// path, never by the display name the rail shows it under.
static func _new_object_entry(by_label: Dictionary, label: String, kind: String,
		class_name_str: String, path: String, match_token: String = "") -> Dictionary:
	var entry: Dictionary = {
		"label": label, "kind": kind, "class": class_name_str, "path": path,
		"match": match_token if not match_token.is_empty() else label,
		"rows": 0, "verbs": PackedStringArray(), "signals": PackedStringArray()
	}
	by_label[label] = entry
	return entry


## Rail order: the kinds in their declared order, and within a kind the order they were found in,
## which is the order the file itself introduces them.
##
## The found-at tiebreaker is load-bearing, not decoration: `sort_custom` is NOT a stable sort, so
## without it two objects of the same kind could swap places between refreshes and the rail would
## reshuffle under the reader's cursor for no reason.
static func _by_kind_order(left: Dictionary, right: Dictionary) -> bool:
	var left_kind: int = Array(OBJECT_KINDS).find(str(left.get("kind", "")))
	var right_kind: int = Array(OBJECT_KINDS).find(str(right.get("kind", "")))
	if left_kind != right_kind:
		return left_kind < right_kind
	return int(left.get("found_at", 0)) < int(right.get("found_at", 0))


## One text unit per TOP-LEVEL row: every line of code in that row's subtree, joined. The rail's
## "N rows" is a count of these, so a number in the rail is a number of things a reader can click.
## Everything a sheet's rows stand for, as one block of GDScript-looking text - the same shape the
## object census reads, exposed so any other scanner (which Input Map actions this file names, for
## one) sees exactly what the census sees rather than growing a second, disagreeing walk.
static func sheet_code_text(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	var lines: PackedStringArray = PackedStringArray()
	for entry: Variant in sheet.events:
		_collect_code(entry, lines)
	return "\n".join(lines)


static func _row_units(sheet: EventSheetResource) -> Array:
	var units: Array = []
	for entry: Variant in sheet.events:
		var lines: PackedStringArray = PackedStringArray()
		_collect_code(entry, lines)
		if not lines.is_empty():
			units.append({"code": "\n".join(lines)})
	return units


## Everything under one row resource, however deeply it nests, rendered back into the ONE shape the
## scanners read: lines of GDScript-looking text.
##
## A lifted row does not hold code - it holds an object in one parameter and a verb in another - so
## an ACE row is written back out as the call it stands for (`$Health.take_damage(3)`). That way a
## hand-written line and the lifted row beside it are censused by exactly the same scanner, and a
## file that has been half-lifted cannot report two different object lists.
static func _collect_code(resource: Variant, into: PackedStringArray) -> void:
	if resource == null or not (resource is Resource):
		return
	var raw: RawCodeRow = resource as RawCodeRow
	if raw != null:
		into.append(_without_comments(raw.code))
		return
	var variable: LocalVariable = resource as LocalVariable
	if variable != null:
		into.append("%s = %s" % [variable.name, str(variable.default_value)])
		return
	var event_row: EventRow = resource as EventRow
	if event_row != null:
		_collect_ace_code(event_row.trigger, into)
		for condition: Variant in event_row.conditions:
			_collect_ace_code(condition, into)
		for action: Variant in event_row.actions:
			_collect_code(action, into)
		for pick_filter: Variant in event_row.pick_filters:
			var filter: PickFilter = pick_filter as PickFilter
			if filter != null:
				into.append(filter.collection_value if not filter.collection_value.is_empty()
					else filter.source_expression)
		for local: Variant in event_row.local_variables:
			_collect_code(local, into)
		for sub_event: Variant in event_row.sub_events:
			_collect_code(sub_event, into)
		return
	for container_property: String in ["events", "rows"]:
		var children: Variant = (resource as Resource).get(container_property)
		if children is Array and not (children as Array).is_empty():
			for child: Variant in (children as Array):
				_collect_code(child, into)
			return
	if (resource as Resource).get("params") != null or (resource as Resource).get("parameters") != null:
		_collect_ace_code(resource, into)
		return
	# Any other row kind - a preload, a signal declaration, a pack block - contributes its text.
	# A custom block keeps its content in a `fields` dictionary rather than in properties, which is
	# where a preload row's scene path lives; without it the rail was silently short every scene the
	# file spawns, with nothing to say it had missed one.
	var fields: Variant = (resource as Resource).get("fields")
	if fields is Dictionary:
		for value: Variant in (fields as Dictionary).values():
			into.append(str(value))
	for property_info: Dictionary in (resource as Resource).get_property_list():
		if int(property_info.get("type", TYPE_NIL)) != TYPE_STRING:
			continue
		var text: String = str((resource as Resource).get(str(property_info.get("name", ""))))
		if not text.is_empty():
			into.append(text)


## A block of GDScript with its comment lines dropped. Prose is not use: a doc comment that MENTIONS
## `$Health` describes the file, and censusing it put objects in the rail that no line of the file
## ever touches. Only whole-line comments go - a trailing `# note` after real code cannot introduce
## an object the code did not already name.
static func _without_comments(code: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in code.split("\n"):
		if not line.strip_edges().begins_with("#"):
			kept.append(line)
	return "\n".join(kept)


## One lifted row written back out as the call it stands for. A row carrying both a target and a
## method reconstructs the call exactly; one carrying only a target names the member it touches; a
## row with neither contributes its parameter values, which is where any remaining object name hides.
static func _collect_ace_code(resource: Variant, into: PackedStringArray) -> void:
	if not (resource is Resource):
		return
	# Only the LIVE parameters. The legacy `parameters` mirror carries an unfilled row's DEFAULTS, and
	# a default target ("$Node") censused as a real reference put a node in the rail that no line of
	# the file ever names.
	var params: Variant = (resource as Resource).get("params")
	if not (params is Dictionary):
		return
	var params_dict: Dictionary = params
	var target: String = str(params_dict.get("target", "")).strip_edges()
	var method: String = str(params_dict.get("method", "")).strip_edges()
	var property_name: String = str(params_dict.get("property", params_dict.get("var_name", ""))).strip_edges()
	if not target.is_empty() and not method.is_empty():
		into.append("%s.%s(%s)" % [target, method, str(params_dict.get("args", ""))])
	elif not target.is_empty() and not property_name.is_empty():
		into.append("%s.%s" % [target, property_name])
	elif not target.is_empty():
		into.append(target)
	for value: Variant in params_dict.values():
		into.append(str(value))


## How many top-level rows each object appears in, and which verbs and signals it is used with.
static func _tally_usage(order: Array, by_label: Dictionary, units: Array) -> void:
	for unit: Dictionary in units:
		var code: String = str(unit.get("code", ""))
		var seen: Dictionary = {}
		for entry: Dictionary in order:
			var label: String = str(entry.get("label", ""))
			var token: String = str(entry.get("match", label))
			if seen.has(label) or not _mentions(code, token):
				continue
			seen[label] = true
			entry["rows"] = int(entry.get("rows", 0)) + 1
			_collect_members(code, label, entry)
	for entry: Dictionary in order:
		by_label[str(entry.get("label", ""))] = entry


## Q12 - one object's usage split the way the sheet is split: {"conditions", "actions", "triggers"}.
## The Object bar's count says how many ROWS use the object, and hovering it says what those rows ARE,
## which is the difference between "Player is busy here" and "Player is checked here".
##
## Counted off the same text the census counts off, so a hand-written line and the lifted row beside
## it are counted alike.
static func object_usage_split(sheet: EventSheetResource, object_label: String) -> Dictionary:
	var split: Dictionary = {"conditions": 0, "actions": 0, "triggers": 0}
	var label: String = object_label.strip_edges()
	if sheet == null or label.is_empty():
		return split
	_split_rows(sheet.events, label, split)
	return split


static func _split_rows(rows: Array, label: String, split: Dictionary) -> void:
	for entry: Variant in rows:
		var event_row: EventRow = entry as EventRow
		if event_row == null:
			continue
		if not event_row.trigger_id.is_empty():
			var trigger_code: PackedStringArray = PackedStringArray()
			_collect_ace_code(event_row, trigger_code)
			if _mentions("\n".join(trigger_code), label):
				split["triggers"] = int(split["triggers"]) + 1
		for condition: Variant in event_row.conditions:
			var condition_code: PackedStringArray = PackedStringArray()
			_collect_ace_code(condition, condition_code)
			if _mentions("\n".join(condition_code), label):
				split["conditions"] = int(split["conditions"]) + 1
		for action: Variant in event_row.actions:
			var action_code: PackedStringArray = PackedStringArray()
			_collect_ace_code(action, action_code)
			if _mentions("\n".join(action_code), label):
				split["actions"] = int(split["actions"]) + 1
		_split_rows(event_row.sub_events, label, split)


## The verbs and signals one object is used with, in the order the code introduces them. A member
## followed by `(` is a verb; one connected or awaited is a signal.
static func _collect_members(code: String, label: String, entry: Dictionary) -> void:
	var verbs: PackedStringArray = entry.get("verbs", PackedStringArray())
	var signals_used: PackedStringArray = entry.get("signals", PackedStringArray())
	for prefix: String in ["%s." % label, "$%s." % label, "%%%s." % label]:
		var from: int = code.find(prefix)
		while from >= 0:
			var after: int = from + prefix.length()
			var member: String = leading_identifier(code.substr(after))
			if not member.is_empty():
				var tail: String = code.substr(after + member.length())
				if tail.begins_with("("):
					var verb: String = EventSheetSentence.verb_words(member)
					if not verb.is_empty() and Array(verbs).find(verb) < 0:
						verbs.append(verb)
				elif tail.begins_with(".connect") or tail.begins_with(".emit") or tail.begins_with(".disconnect"):
					if Array(signals_used).find(member) < 0:
						signals_used.append(member)
			from = code.find(prefix, after)
	entry["verbs"] = verbs
	entry["signals"] = signals_used


## True when a piece of code names an object - as a whole word, so `hp` does not match `hp_bar`.
static func _mentions(code: String, label: String) -> bool:
	if label.is_empty():
		return false
	var from: int = code.find(label)
	while from >= 0:
		var before_ok: bool = from == 0 or not _is_word_character(code[from - 1])
		var after_at: int = from + label.length()
		var after_ok: bool = after_at >= code.length() or not _is_word_character(code[after_at])
		if before_ok and after_ok:
			return true
		from = code.find(label, from + 1)
	return false


static func _is_word_character(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper() or character.is_valid_int()


## Every `$Node` / `%Unique` reference written in a piece of code.
##
## The name must open with a capital, which is what keeps a format string out of the object list:
## `"%s"` and `"%d"` are the same two characters as a unique-name reference, and one phantom object
## in the rail costs a reader more than a lowercase node name that goes unlisted (that node still
## reaches the rail through its @onready declaration, which is typed and unambiguous).
static func _node_references(code: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for index: int in code.length():
		var sigil: String = code[index]
		if sigil != "$" and sigil != "%":
			continue
		var head: String = code[index + 1] if index + 1 < code.length() else ""
		if head.is_empty() or head != head.to_upper() or head == head.to_lower():
			continue
		var body: String = ""
		var walk: int = index + 1
		while walk < code.length() and (_is_word_character(code[walk]) or code[walk] == "/"):
			body += code[walk]
			walk += 1
		if not body.is_empty():
			found.append(sigil + body)
	return found


## Every registered singleton a piece of code names as an object (`Game.score`), so an autoload that
## is merely mentioned in a string is not mistaken for one that is used.
static func _autoload_references(code: String, autoloads: Dictionary) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for singleton: Variant in autoloads.keys():
		var name_text: String = str(singleton)
		if code.contains("%s." % name_text) and _mentions(code, name_text):
			found.append(name_text)
	return found


## The group names a piece of code addresses. Only the calls that TAKE a group name are read, so an
## ordinary string never becomes a phantom object in the rail.
static func _group_references(code: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for marker: String in ["get_nodes_in_group(", "add_to_group(", "remove_from_group(",
			"is_in_group(", "call_group(", "get_first_node_in_group(", "notify_group("]:
		var from: int = code.find(marker)
		while from >= 0:
			var after: int = from + marker.length()
			var rest: String = code.substr(after).strip_edges()
			# call_group takes the group SECOND ("group", "method"); the first argument is a flag on
			# some overloads, so only a leading string literal is read and anything else is skipped.
			if rest.begins_with("\"") or rest.begins_with("&\""):
				var quoted: String = rest.trim_prefix("&").substr(1)
				var close_at: int = quoted.find("\"")
				if close_at > 0:
					found.append(quoted.substr(0, close_at))
			from = code.find(marker, after)
	return found


## Every packed scene a piece of code names. Any `res://` path ending in a scene extension counts,
## whether it was written as a `preload("…")` call or arrived as a preload row's stored field - the
## two spellings are the same object, and matching only the call shape listed the scenes a file
## typed while missing the ones it declared.
static func _scene_references(code: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var from: int = code.find("res://")
	while from >= 0:
		var walk: int = from
		while walk < code.length() and not code[walk] in ["\"", "'", " ", "\t", "\n", ")", ","]:
			walk += 1
		var path: String = code.substr(from, walk - from)
		if path.ends_with(".tscn") or path.ends_with(".scn"):
			found.append(path)
		from = code.find("res://", from + 1)
	return found


## The muted note one census entry wears in the rail: what kind of thing it is, the class or path it
## resolves to when that adds anything, and how many rows use it.
static func object_note(entry: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var kind: String = str(entry.get("kind", ""))
	var kind_word: String = str(OBJECT_KIND_WORDS.get(kind, kind))
	var class_name_str: String = str(entry.get("class", "")).strip_edges()
	var path: String = str(entry.get("path", "")).strip_edges()
	if kind == "script":
		parts.append(EventSheetL10n.translate(kind_word))
		if not class_name_str.is_empty():
			parts.append(class_name_str)
		return " · ".join(parts)
	if path.begins_with("$") or path.begins_with("%"):
		parts.append(path)
	else:
		parts.append(EventSheetL10n.translate(kind_word))
	if not class_name_str.is_empty() and class_name_str != parts[0]:
		parts.append(class_name_str)
	var rows: int = int(entry.get("rows", 0))
	if rows > 0:
		parts.append(EventSheetL10n.translate("%d rows") % rows if rows != 1 else EventSheetL10n.translate("1 row"))
	return " · ".join(parts)


## The icon one census entry draws: its own SPRITE when the object's scene has one (Q10), else its
## class picture for a node, the globe for an autoload, and nothing for a group (which is a name, not
## a thing with a picture).
##
## `sheet_source_path` is the open file; without it (a caller that has no sheet to hand) the answer
## is the class icon exactly as before, which is also what a headless run gets.
static func object_icon(entry: Dictionary, class_map: Dictionary, sheet_source_path: String = "") -> Texture2D:
	var picture: Texture2D = EventSheetObjectThumbnails.thumbnail_for(entry, sheet_source_path)
	if picture != null:
		return picture
	if str(entry.get("kind", "")) == "autoload":
		return autoload_icon()
	var class_name_str: String = str(entry.get("class", "")).strip_edges()
	if not class_name_str.is_empty() and ClassDB.class_exists(class_name_str):
		return ACEPickerDialog.editor_icon(class_name_str)
	return class_icon_for(str(entry.get("label", "")), class_map)


## X2 / X20 / X30. What the FILE says about the rays it casts through the cursor and the points it
## converts into canvas space, as the two fact maps the sentence grammar reads:
##
##   cursor_rays    {hit local: {reach, aimed_at, mask, cleared}} - one entry per camera-ray run the
##                  file writes, so `hit.position` can read "where the cursor touches the world"
##                  HERE and stay an ordinary possessive in a file that never cast a ray
##   canvas_points  {local: true} - the locals declared from a canvas conversion, so a distance
##                  between two of them can be named in PIXELS rather than in world units
##
## No single line can answer either question - a run is four lines and a canvas distance is two
## declarations away from the call that measures it - so both are answered from one walk of the file
## and handed to the grammar as ordinary context. Nothing here is written back: the lines stay as the
## file wrote them, which is what keeps the byte round-trip intact.
static func cursor_ray_facts(sheet: EventSheetResource) -> Dictionary:
	var rays: Dictionary = {}
	var canvas_points: Dictionary = {}
	if sheet == null:
		return {"cursor_rays": rays, "canvas_points": canvas_points}
	# What the run has said so far: the local holding the ray's start, the one holding its direction,
	# and the query the two of them built. Cleared whenever a name is filled from something else.
	var origins: Dictionary = {}
	var directions: Dictionary = {}
	var queries: Dictionary = {}
	# How many runs each name stands for across the whole file, and how many of them the file
	# guarded with an emptiness check.
	var total_runs: Dictionary = {}
	var cleared_runs: Dictionary = {}
	for line: String in _cursor_ray_lines(sheet):
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		# The mask a query is restricted to, written on a line of its own after it was built.
		var mask_at: int = text.find(".collision_mask = ")
		if mask_at > 0 and queries.has(text.substr(0, mask_at).strip_edges()):
			(queries[text.substr(0, mask_at).strip_edges()] as Dictionary)["mask"] = \
				text.substr(mask_at + 18).strip_edges()
			continue
		# The empty-check that follows a run and clears what it found: the row's "none when nothing
		# is hit" note, folded in from the branch rather than drawn as a rule of its own.
		var emptiness: String = _cursor_ray_empty_check(text)
		if not emptiness.is_empty() and rays.has(emptiness):
			(rays[emptiness] as Dictionary)["cleared"] = true
			cleared_runs[emptiness] = int(cleared_runs.get(emptiness, 0)) + 1
			continue
		var declared: String = _declared_local_name(text)
		if declared.is_empty():
			continue
		var value: String = _declared_local_value(text)
		if not EventSheetSentence.canvas_position_words(value, {}).is_empty() \
				or not EventSheetSentence.canvas_centre_words(value).is_empty():
			canvas_points[declared] = true
		var step: Dictionary = EventSheetSentence.cursor_ray_step_parts(value)
		# A name filled from anything else stops standing for what it stood for a moment ago: the
		# same word may not read two ways on one sheet.
		origins.erase(declared)
		directions.erase(declared)
		queries.erase(declared)
		rays.erase(declared)
		match str(step.get("step", "")):
			"project_ray_origin":
				origins[declared] = str(step.get("point", ""))
			"project_ray_normal":
				directions[declared] = str(step.get("point", ""))
			"query":
				var built: Dictionary = _cursor_ray_query_facts(step, origins, directions)
				if not built.is_empty():
					queries[declared] = built
			"cast":
				var query_name: String = str(step.get("query", ""))
				if queries.has(query_name):
					rays[declared] = (queries[query_name] as Dictionary).duplicate()
					total_runs[declared] = int(total_runs.get(declared, 0)) + 1
	# Two functions may both call their hit `hit`. The note is only allowed to say "none when
	# nothing is hit" when EVERY run of that name is followed by the branch that clears it: a note
	# taken from one run and drawn beside another would be the confident lie this walk exists to
	# prevent, and one word may not read two ways on one sheet.
	for name_text: String in rays:
		(rays[name_text] as Dictionary)["cleared"] = 			int(cleared_runs.get(name_text, 0)) >= int(total_runs.get(name_text, 0))
	return {"cursor_rays": rays, "canvas_points": canvas_points}


## X2. What a query line says about the ray it builds, given the locals declared above it - the far
## end's reach and the canvas point the ray was aimed through - or {} when its two ends are not the
## ray pair at all (a ray to a FIXED point is a different question, and reads as one).
static func _cursor_ray_query_facts(step: Dictionary, origins: Dictionary,
		directions: Dictionary) -> Dictionary:
	var from_name: String = str(step.get("from", ""))
	if not origins.has(from_name):
		return {}
	var to_text: String = str(step.get("to", ""))
	for direction_name: String in directions:
		var reach: String = EventSheetSentence.cursor_ray_reach(to_text, from_name, direction_name)
		if reach.is_empty():
			continue
		if str(origins[from_name]) != str(directions[direction_name]):
			continue
		return {"reach": reach, "aimed_at": cursor_aim_owner(str(origins[from_name])), "mask": "",
			"cleared": false}
	return {}


## X30. The object whose canvas position aimed a ray, "" when the ray was aimed by the OS mouse -
## which is what makes a gamepad or a touch crosshair as first-class as the pointer.
static func cursor_aim_owner(point: String) -> String:
	var bare: String = point.strip_edges()
	if bare.is_empty() or bare == EventSheetSentence.CURSOR_MOUSE_POINT:
		return ""
	if bare.ends_with(".origin"):
		var call: Dictionary = EventSheetSentence.call_parts(bare.substr(0, bare.length() - 7).strip_edges())
		if not call.is_empty() and str(call.get("method", "")) == "get_global_transform_with_canvas":
			return str(call.get("target", "")).strip_edges()
	return ""


## X2. The local a `if <name>.is_empty():` guard asks about, or "" when the line is not that guard.
static func _cursor_ray_empty_check(text: String) -> String:
	var bare: String = text.strip_edges()
	if not bare.begins_with("if ") or not bare.ends_with(":"):
		return ""
	var call: Dictionary = EventSheetSentence.call_parts(bare.substr(3, bare.length() - 4).strip_edges())
	if call.is_empty() or str(call.get("method", "")) != "is_empty":
		return ""
	return str(call.get("target", "")).strip_edges()


## X2 / X30. The file's lines for the ray walk, in FILE order, with the two things the shared walks
## leave out because no other reading needs them: the mask a query is restricted to (an ACE row, not
## a property write) and the emptiness GUARD under a run (a condition, not a statement). Both are
## members of the run's shape - a ray filtered to the floor and a branch that clears what the ray
## found - so the walk that answers about runs has to be able to see them.
static func _cursor_ray_lines(sheet: EventSheetResource) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if sheet == null:
		return lines
	for entry: Variant in sheet.events:
		_append_cursor_ray_lines(entry, lines, 0)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			for event_entry: Variant in (entry as EventFunction).events:
				_append_cursor_ray_lines(event_entry, lines, 0)
	return lines


## One row unit of that walk. Depth-limited so a sheet that somehow nests into itself cannot spin.
static func _append_cursor_ray_lines(entry: Variant, lines: PackedStringArray, depth: int) -> void:
	if depth > 64 or entry == null or not (entry is Resource):
		return
	if entry is RawCodeRow:
		lines.append_array((entry as RawCodeRow).code.split("\n"))
		return
	if entry is EventRow:
		var event_row: EventRow = entry as EventRow
		for condition: Variant in event_row.conditions:
			var guard: String = _cursor_ray_guard_line(condition as Resource)
			if not guard.is_empty():
				lines.append(guard)
		for action: Variant in event_row.actions:
			_append_cursor_ray_lines(action, lines, depth + 1)
		for sub_event: Variant in event_row.sub_events:
			_append_cursor_ray_lines(sub_event, lines, depth + 1)
		return
	var mask_line: String = _cursor_ray_mask_line(entry as Resource)
	if not mask_line.is_empty():
		lines.append(mask_line)
		return
	var line: String = _lifted_row_line(entry as Resource)
	if not line.is_empty():
		lines.append(line)


## X2. The `if <name>.is_empty():` a lifted emptiness question stands for, "" for anything else. Only
## the shapes that ASK about emptiness count: the note this feeds is "none when nothing is hit", and
## a guard about something else would put those words on a branch that never says them.
static func _cursor_ray_guard_line(condition: Resource) -> String:
	if condition == null:
		return ""
	var ace_id: String = str(condition.get("ace_id")).strip_edges()
	if ace_id != "DictIsEmpty" and ace_id != "ArrayIsEmpty":
		return ""
	var params: Variant = condition.get("params")
	if not (params is Dictionary) or (params as Dictionary).is_empty():
		params = condition.get("parameters")
	if not (params is Dictionary):
		return ""
	var name_text: String = str((params as Dictionary).get("var_name", "")).strip_edges()
	return "" if name_text.is_empty() else "if %s.is_empty():" % name_text


## X30. The `q.collision_mask = <mask>` a lifted Set RayCast Mask row stands for, "" for anything
## else. Both dimensions' rows spell the same property, and a query object takes it in either.
static func _cursor_ray_mask_line(action: Resource) -> String:
	if action == null:
		return ""
	var ace_id: String = str(action.get("ace_id")).strip_edges()
	if ace_id != "RayCast2DSetMask" and ace_id != "RayCast3DSetMask":
		return ""
	var params: Variant = action.get("params")
	if not (params is Dictionary) or (params as Dictionary).is_empty():
		params = action.get("parameters")
	if not (params is Dictionary):
		return ""
	var target: String = str((params as Dictionary).get("target", "")).strip_edges()
	var mask: String = str((params as Dictionary).get("mask", "")).strip_edges()
	if target.is_empty() or mask.is_empty():
		return ""
	return "%s.collision_mask = %s" % [target, mask]
