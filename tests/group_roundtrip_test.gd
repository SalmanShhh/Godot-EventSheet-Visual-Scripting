@tool
class_name GroupRoundtripTest
extends RefCounted
# Event groups (EventGroup) survive the .gd round-trip. A grouped sheet compiles to class-scope
# `## @ace_group(...)` declarations plus a `# @group:<slug>` marker before each member event; opening
# that .gd back reconstructs the groups (nesting, colour, collapsed state) and re-saves byte-for-byte.
# The whole thing is gated by the lift's byte-verify, so a sheet that can't round-trip stays verbatim
# rather than corrupting - these assertions pin the happy path.

const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")


static func run() -> bool:
	var all_passed: bool = true

	# An outer "Juice" group (coloured) holding one event + a nested collapsed "Knockback" child.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var child: EventGroup = EventGroup.new()
	child.group_name = "Knockback"
	child.collapsed = true
	child.events = [_event(true)]
	var outer: EventGroup = EventGroup.new()
	outer.group_name = "Juice"
	outer.color_tag = "orange"
	outer.events = [_event(false), child]
	sheet.events.append(outer)

	var output: String = str(SheetCompiler.compile(sheet).get("output", ""))
	all_passed = _check("emits the @ace_group declaration", output.contains("## @ace_group(uid=\"juice\""), true) and all_passed
	all_passed = _check("emits the nested child declaration",
		output.contains("parent=\"juice\"") and output.contains("collapsed=true"), true) and all_passed
	all_passed = _check("emits the per-row # @group marker", output.contains("# @group:juice"), true) and all_passed

	# Opening the .gd back reconstructs the groups (import_external_source lifts internally).
	var sheet2: EventSheetResource = GDScriptImporter.new().import_external_source(output)
	var top_group: EventGroup = null
	for ev: Variant in sheet2.events:
		if ev is EventGroup:
			top_group = ev as EventGroup
	all_passed = _check("the outer EventGroup is reconstructed", top_group != null and top_group.group_name == "Juice", true) and all_passed
	if top_group != null:
		all_passed = _check("its colour round-trips", top_group.color_tag, "orange") and all_passed
		var nested_child: EventGroup = null
		for sub: Variant in top_group.events:
			if sub is EventGroup:
				nested_child = sub as EventGroup
		all_passed = _check("the nested child group is reconstructed", nested_child != null and nested_child.group_name == "Knockback", true) and all_passed
		if nested_child != null:
			all_passed = _check("the child's collapsed state round-trips", nested_child.collapsed, true) and all_passed

	# Re-saving the imported sheet (external path) reproduces the .gd byte-for-byte (stable markers).
	sheet2.external_source_path = "user://_group_rt_verify.gd"
	var recompiled: String = str(SheetCompiler.compile(sheet2, "user://_group_rt_verify.gd").get("output", ""))
	all_passed = _check("re-save is byte-identical (drift=0)", recompiled == output, true) and all_passed

	# Review fix: the # @group marker precedes ANY grouped event's first line, but the lift only
	# stamped `if` headers - a grouped action-only or loop event silently dropped out of its group
	# on reopen. The bytes still matched (the verify strips markers on both sides), so ONLY these
	# structural pins catch the loss. The ungrouped lead statement also proves the collector splits
	# at a marker instead of merging the grouped event into the previous one.
	var mixed: EventSheetResource = EventSheetResource.new()
	mixed.host_class = "Node2D"
	mixed.events.append(_raw_event("reset_hits()"))
	var scoring: EventGroup = EventGroup.new()
	scoring.group_name = "Scoring"
	scoring.events = [_raw_event("score_total += 1"), _raw_event("for item in hit_list:\n\tprint(item)")]
	mixed.events.append(scoring)
	var mixed_out: String = str(SheetCompiler.compile(mixed, "user://_group_rt_mixed.gd").get("output", ""))
	var mixed_in: EventSheetResource = GDScriptImporter.new().import_external_source(mixed_out)
	var scoring_in: EventGroup = null
	var loose_rows: int = 0
	for row: Variant in mixed_in.events:
		if row is EventGroup and (row as EventGroup).group_name == "Scoring":
			scoring_in = row as EventGroup
		elif row is EventRow:
			loose_rows += 1
	all_passed = _check("the group survives around non-if events", scoring_in != null, true) and all_passed
	if scoring_in != null:
		all_passed = _check("BOTH the action-only and the loop event stay grouped", scoring_in.events.size(), 2) and all_passed
	all_passed = _check("the ungrouped lead event stays OUTSIDE the group", loose_rows, 1) and all_passed
	mixed_in.external_source_path = "user://_group_rt_mixed_verify.gd"
	var mixed_rt: String = str(SheetCompiler.compile(mixed_in, "user://_group_rt_mixed_verify.gd").get("output", ""))
	all_passed = _check("mixed-kind grouped sheet re-saves byte-identically", mixed_rt == mixed_out, true) and all_passed

	return all_passed


## An action-only OnProcess event carrying one raw statement (or block) - no conditions, so its
## first emitted line is NOT an `if` header and the group marker lands on a plain statement.
static func _raw_event(code: String) -> EventRow:
	var e: EventRow = EventRow.new()
	e.trigger_provider_id = "Core"
	e.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	e.actions.append(raw)
	return e


static func _event(negated: bool) -> EventRow:
	var e: EventRow = EventRow.new()
	e.trigger_provider_id = "Core"
	e.trigger_id = "OnProcess"
	var c: ACECondition = ACECondition.new()
	c.provider_id = "Core"
	c.ace_id = "IsOnFloor"
	c.codegen_template = "is_on_floor()"
	c.negated = negated
	e.conditions.append(c)
	var a: ACEAction = ACEAction.new()
	a.provider_id = "Core"
	a.ace_id = "MoveAndSlide"
	a.codegen_template = "move_and_slide()"
	e.actions.append(a)
	return e


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] group_roundtrip_test: %s" % label)
		return true
	print("[FAIL] group_roundtrip_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
