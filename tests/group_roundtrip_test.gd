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

	return all_passed


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
