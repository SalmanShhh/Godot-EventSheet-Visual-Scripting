# Godot EventSheets — Addon tags
# `@ace_tags(a, b)` on an addon class (or the Tags field on a sheet-built addon) tags
# every ACE the provider publishes: searchable in the picker, exposed over MCP, and
# emitted/recovered through the generated script.
@tool
extends RefCounted
class_name AddonTagsTest

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

static func run() -> bool:
	var all_passed: bool = true

	# Analyzer: class-level @ace_tags parses (and stays out of the description).
	var tagged_source: String = "## A movement helper.\n## @ace_tags(movement, retro, jam)\nclass_name TagProbe\nextends Node\n"
	var probe_path: String = "user://eventsheets_tag_probe.gd"
	var file: FileAccess = FileAccess.open(probe_path, FileAccess.WRITE)
	file.store_string(tagged_source)
	file.close()
	var probe_script: GDScript = GDScript.new()
	probe_script.source_code = tagged_source
	probe_script.take_over_path(probe_path)
	var metadata: Dictionary = EventSheetSemanticAnalyzer.new().parse_source_metadata(probe_script)
	all_passed = _check("@ace_tags parses", metadata.get("tags", []), ["movement", "retro", "jam"]) and all_passed
	all_passed = _check("tags stay out of the description", str(metadata.get("class_description", "")), "A movement helper.") and all_passed

	# Definitions carry the tags; the picker search text matches them.
	var definition: ACEDefinition = ACEDefinition.new()
	definition.display_name = "Dash"
	definition.metadata = {"tags": ["movement", "retro"]}
	all_passed = _check("tags are searchable", definition.get_search_text().contains("retro"), true) and all_passed

	# Sheet-built addons: the Tags field emits the annotation above class_name.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "TaggedBehavior"
	sheet.addon_tags = PackedStringArray(["movement", "jam"])
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_tagged.gd").get("output", ""))
	all_passed = _check("sheet tags emit as the annotation",
		output.contains("## @ace_tags(movement, jam)") and output.find("@ace_tags") < output.find("class_name TaggedBehavior"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("tagged output parses", generated.reload(true) == OK, true) and all_passed

	# Dialog plumbing: tags apply through Sheet Type.
	var dialog_sheet: EventSheetResource = EventSheetResource.new()
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(dialog_sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._apply_sheet_type_settings(2, "TaggedThing", "", "Node2D", false, PackedStringArray(["ai", "patrol"]))
	all_passed = _check("Sheet Type applies tags", dialog_sheet.addon_tags, PackedStringArray(["ai", "patrol"])) and all_passed
	editor.free()

	# MCP: list_aces filters by tag and reports tags.
	var server: EventSheetMCPServer = EventSheetMCPServer.new()
	var response: Dictionary = server.handle_message({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
		"params": {"name": "list_aces", "arguments": {"query": "dictionary"}}})
	var payload: Variant = JSON.parse_string(str(((response.get("result", {}) as Dictionary).get("content", [])[0] as Dictionary).get("text", "")))
	all_passed = _check("MCP list_aces payload carries a tags field",
		(payload as Dictionary).get("aces", [])[0].has("tags"), true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] addon_tags_test: %s" % label)
		return true
	print("[FAIL] addon_tags_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
