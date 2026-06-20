# Godot EventSheets — Intellisense upgrades
# Dot-context completion (host./typed-variable./$Behavior. → that type's members),
# signature hints for the innermost call, and the C3-style quick-add bar (synonym matcher
# + positional params + apply).
@tool
extends RefCounted
class_name IntellisenseTest

class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass

static func _labels(candidates: Array[Dictionary]) -> Array[String]:
	var labels: Array[String] = []
	for candidate in candidates:
		labels.append(str(candidate.get("label", "")))
	return labels

static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.variables = {
		"health": {"type": "int", "default": 100, "exported": false},
		"body": {"type": "Node2D", "default": null, "exported": false},
		"enemies": {"type": "Array[Node2D]", "default": null, "exported": false}
	}
	var reload_fn: EventFunction = EventFunction.new()
	reload_fn.function_name = "reload"
	var ammo_param: ACEParam = ACEParam.new()
	ammo_param.id = "ammo"
	ammo_param.type_name = "int"
	reload_fn.params.append(ammo_param)
	sheet.functions.append(reload_fn)

	# Dot-context: host. → host class members; typed variable → its class; flat otherwise.
	var host_members: Array[String] = _labels(EventSheetGDScriptLint.completion_for_context("host.", sheet))
	all_passed = _check("host. offers host-class members", host_members.has("move_and_slide"), true) and all_passed
	all_passed = _check("host. does not offer sheet variables", host_members.has("health"), false) and all_passed
	var body_members: Array[String] = _labels(EventSheetGDScriptLint.completion_for_context("if body.", sheet))
	all_passed = _check("typed variable offers its class members", body_members.has("global_position"), true) and all_passed
	var typed_array_members: Array[String] = _labels(EventSheetGDScriptLint.completion_for_context("enemies.", sheet))
	all_passed = _check("typed Array[T] variable completes container (Array) members",
		typed_array_members.has("append") and typed_array_members.has("size"), true) and all_passed
	var behavior_members: Array[String] = _labels(EventSheetGDScriptLint.completion_for_context("$TimerBehavior.", sheet))
	all_passed = _check("$Behavior. offers the script class's methods", behavior_members.has("start_timer"), true) and all_passed
	all_passed = _check("$Behavior. includes base-class members", behavior_members.has("get_child_count"), true) and all_passed
	var flat: Array[String] = _labels(EventSheetGDScriptLint.completion_for_context("hea", sheet))
	all_passed = _check("non-dot context stays flat (sheet symbols)", flat.has("health") and flat.has("reload"), true) and all_passed
	all_passed = _check("unknown token offers nothing", EventSheetGDScriptLint.completion_for_context("mystery.", sheet).is_empty(), true) and all_passed

	# Signature hints.
	all_passed = _check("sheet-function hint", EventSheetGDScriptLint.signature_hint("reload(", sheet), "reload(ammo: int)") and all_passed
	var host_hint: String = EventSheetGDScriptLint.signature_hint("x = move_and_collide(", sheet)
	all_passed = _check("host-method hint resolves", host_hint.begins_with("move_and_collide("), true) and all_passed
	all_passed = _check("no call context, no hint", EventSheetGDScriptLint.signature_hint("health + 1", sheet), "") and all_passed

	# Quick add: matcher + apply.
	var target_sheet: EventSheetResource = EventSheetResource.new()
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(target_sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var tick_match: Dictionary = editor._quick_match("every tick")
	all_passed = _check("C3 phrasing matches the trigger",
		not tick_match.is_empty() and (tick_match.get("definition") as ACEDefinition).id == "OnProcess", true) and all_passed
	var heal_match: Dictionary = editor._quick_match("heal 7")
	all_passed = _check("trailing words fill params positionally",
		not heal_match.is_empty() and str((heal_match.get("params") as Dictionary).get("amount", "")) == "7", true) and all_passed
	all_passed = _check("garbage matches nothing", editor._quick_match("zzz qqq").is_empty(), true) and all_passed
	var before: int = target_sheet.events.size()
	all_passed = _check("quick add applies", editor._quick_add("every tick"), true) and all_passed
	all_passed = _check("a new event landed", target_sheet.events.size(), before + 1) and all_passed
	all_passed = _check("quick add of garbage reports and declines", editor._quick_add("zzz qqq"), false) and all_passed
	editor.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] intellisense_test: %s" % label)
		return true
	print("[FAIL] intellisense_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
