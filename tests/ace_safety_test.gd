# EventForge - Core ACE runtime-safety regression guards
#
# The adversarial template audit found 9 built-in ACEs that PARSED fine but crashed, leaked, or
# misbehaved at runtime (null-deref on a failed file/focus, a leaked one-shot player, a wrong-host
# global_position, a delta that doesn't exist outside _process, defaults that no-op or error-spam).
# Each was fixed in its module; this test asserts the SHIPPED descriptor still carries the corrected
# form, so a future edit can't quietly reintroduce the hazard. Pairs with builtin_ace_compile_test
# (which proves they parse) - this proves the specific runtime guards are present.
@tool
class_name ACESafetyTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true
	var by_id: Dictionary = {}
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[d.ace_id] = d

	# JsonSaveFile: guard the FileAccess handle (was a null-deref crash) and close it.
	all_passed = _check("JsonSaveFile guards + closes the file handle",
		_tmpl(by_id, "JsonSaveFile").contains("if __json_") and _tmpl(by_id, "JsonSaveFile").contains(".close()"), true) and all_passed
	# FocusNext / FocusPrevious: guard the null focus result (was a null-deref crash).
	all_passed = _check("FocusNext guards a null next-focus",
		_tmpl(by_id, "FocusNext").contains("if __n_"), true) and all_passed
	all_passed = _check("FocusPrevious guards a null prev-focus",
		_tmpl(by_id, "FocusPrevious").contains("if __p_"), true) and all_passed
	# FindChildrenByPattern: pass owned=false so runtime-spawned nodes are included.
	all_passed = _check("FindChildrenByPattern searches unowned (spawned) nodes",
		_tmpl(by_id, "FindChildrenByPattern").contains(", false)"), true) and all_passed
	# Nearest / Furthest In Group: host-typed to Node2D (global_position only exists on spatial nodes).
	all_passed = _check("NearestInGroup is Node2D-hosted",
		_node_type(by_id, "NearestInGroup") == "Node2D", true) and all_passed
	all_passed = _check("FurthestInGroup is Node2D-hosted",
		_node_type(by_id, "FurthestInGroup") == "Node2D", true) and all_passed
	# EveryXSeconds: prelude uses get_process_delta_time() so it compiles under any trigger.
	all_passed = _check("EveryXSeconds prelude is trigger-agnostic",
		str(by_id["EveryXSeconds"].codegen_prelude).contains("get_process_delta_time"), true) and all_passed
	# LookAt3D: default target offset from the node's own origin (Vector3.ZERO error-spammed).
	all_passed = _check("LookAt3D default target is offset from origin",
		_param_default(by_id, "LookAt3D", "target") == "Vector3(0, 0, -1)", true) and all_passed
	# PlaySound / PlaySoundAt: free the throwaway player when the stream fails to load (was a leak).
	all_passed = _check("PlaySound frees a failed-stream player",
		_tmpl(by_id, "PlaySound").contains("if __sfx_") and _tmpl(by_id, "PlaySound").contains("== null"), true) and all_passed
	all_passed = _check("PlaySoundAt frees a failed-stream player",
		_tmpl(by_id, "PlaySoundAt").contains("if __sfx_") and _tmpl(by_id, "PlaySoundAt").contains("== null"), true) and all_passed

	# The "On node" target every node-scoped ACE gets automatically is applied by PREFIXING each
	# template line with `{target.}`. That is only valid when the line begins with a member operation.
	# A condition reading `not thing.is_empty()` starts with a letter, so the identifier check waved it
	# through - and a set target then emitted `$Node.not thing.is_empty()`, which does not parse. It
	# never showed up in the compile gate, because that leaves the target BLANK and the prefix drops to
	# nothing. Assert on the shipped templates directly: nothing carrying an On-node target may lead
	# with a keyword that cannot follow a dot.
	var unprefixable: Array[String] = []
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		var template: String = str(descriptor.codegen_template)
		if not template.contains("{target.}"):
			continue
		for line: String in template.split("\n"):
			var marker: int = line.find("{target.}")
			if marker == -1:
				continue
			var head: String = line.substr(marker + 9).split("(")[0].split(" ")[0].split(".")[0].strip_edges()
			if head in ["not", "and", "or", "in", "is", "true", "false", "null", "self", "super"]:
				unprefixable.append("%s (%s)" % [str(descriptor.ace_id), head])
	all_passed = _check("no auto-targeted template leads with a keyword a node prefix cannot precede",
		unprefixable, [] as Array[String]) and all_passed

	# Every brace pair in a codegen template is read as a PARAMETER PLACEHOLDER: the reverse-lifter
	# turns each one into a named regex capture, "(?<name>.+?)". A pair that does not spell an
	# identifier - GDScript's empty-dictionary literal `{}` above all - would inject an illegal group
	# name, and the whole pattern then fails to compile: the ACE drops out of the reverse index
	# silently AND every import prints a PCRE error, once per lifted function. The builder treats such
	# a pair as literal text; this pins that it does, and that no shipped template defeats it.
	var lifter: GDScript = load("res://addons/eventforge/importer/ace_lifter.gd")
	all_passed = _check("a literal {} in a template is matched as text, not as a capture",
		lifter._template_to_regex("var d: Dictionary = e if e is Dictionary else {}") != null, true) and all_passed
	var unliftable: Array[String] = []
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		var template: String = str(descriptor.codegen_template).strip_edges()
		if template.is_empty():
			continue
		for variant: String in lifter._optional_prefix_variants(template):
			if lifter._template_to_regex(variant) == null:
				unliftable.append(str(descriptor.ace_id))
	all_passed = _check("every registered template builds a legal reverse-lift pattern",
		unliftable, [] as Array[String]) and all_passed

	return all_passed


static func _tmpl(by_id: Dictionary, ace_id: String) -> String:
	return str(by_id[ace_id].codegen_template) if by_id.has(ace_id) else ""


static func _node_type(by_id: Dictionary, ace_id: String) -> String:
	return str(by_id[ace_id].node_type) if by_id.has(ace_id) else ""


static func _param_default(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	if not by_id.has(ace_id):
		return ""
	for p: ACEParam in by_id[ace_id].params:
		if p.id == param_id:
			return str(p.default_value)
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("ace_safety_test", label, actual, expected)
