# EventForge — custom node ICON support for behaviour addons + sheets.
# A sheet's custom_class_icon emits `@icon("res://…")` before class_name (so Godot's Create New Node
# dialog and the sheet banner show it), and opening the generated .gd recovers the icon back into the
# field. The icon ships WITH the packs (eventsheet_addons/), so a behaviour stays self-contained.
@tool
class_name IconRoundtripTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.custom_class_name = "IconDemoBehavior"
	sheet.custom_class_icon = "res://eventsheet_addons/behavior.svg"
	sheet.host_class = "Node2D"
	var fn: EventFunction = EventFunction.new()
	fn.function_name = "tick"
	fn.expose_as_ace = true
	fn.ace_display_name = "Tick"
	fn.ace_category = "Demo"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "host.set_process(false)"
	fn.events.append(body)
	sheet.functions.append(fn)

	var source: String = str(SheetCompiler.compile(sheet, "user://icon_demo.gd").get("output", ""))
	ok = _check("compiled output emits @icon before class_name", source.contains("@icon(\"res://eventsheet_addons/behavior.svg\")\nclass_name IconDemoBehavior"), true) and ok

	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	ok = _check("import recovers custom_class_icon into the field", imported.custom_class_icon, "res://eventsheet_addons/behavior.svg") and ok

	imported.external_source_path = "user://icon_rt.gd"
	var rt: String = str(SheetCompiler.compile(imported, "user://icon_rt.gd").get("output", ""))
	ok = _check("icon round-trips byte-identically (no double @icon)", rt == source, true) and ok
	if rt != source:
		print("    SRC<%s>\n    RT <%s>" % [source, rt])

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] icon_roundtrip_test: %s" % label)
		return true
	print("[FAIL] icon_roundtrip_test: %s" % label)
	print("  expected: %s, actual: %s" % [str(expected), str(actual)])
	return false
