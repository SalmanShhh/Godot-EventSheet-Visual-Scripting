# EventForge - behaviour/class descriptions. A sheet's class_description compiles to a `##` doc
# comment right after `extends` (Godot's class-doc position, so it shows in the Create Node dialog),
# and the importer recovers it from there. Round-trips byte-identically; absence never false-matches
# the host-member doc or signal annotations (which a blank line separates from `extends`).
@tool
class_name ClassDescriptionRoundtripTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# Multi-line description on a behaviour -> `##` lines right after `extends Node`.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "TestBehaviour"
	sheet.class_description = "A test behaviour.\nDoes two things."
	var compiled: String = str(SheetCompiler.compile(sheet, "user://cd_a.gd").get("output", ""))
	ok = _check("description emits as a doc block after extends",
		compiled.contains("extends Node\n## A test behaviour.\n## Does two things.\n"), true) and ok

	# Importer recovers it verbatim.
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(compiled)
	ok = _check("description round-trips through the importer", imported.class_description, "A test behaviour.\nDoes two things.") and ok

	# A sheet with NO description must not falsely recover the host-member doc comment.
	var bare: EventSheetResource = EventSheetResource.new()
	bare.behavior_mode = true
	bare.host_class = "CharacterBody2D"
	bare.custom_class_name = "NoDesc"
	var bare_compiled: String = str(SheetCompiler.compile(bare, "user://cd_b.gd").get("output", ""))
	ok = _check("no description emits no doc block", bare_compiled.contains("extends Node\n\n"), true) and ok
	var bare_imported: EventSheetResource = GDScriptImporter.new().import_external_source(bare_compiled)
	ok = _check("absent description stays empty", bare_imported.class_description, "") and ok

	# A non-behaviour (typed host) sheet also carries the description.
	var plain: EventSheetResource = EventSheetResource.new()
	plain.host_class = "Node2D"
	plain.custom_class_name = "PlainNode"
	plain.class_description = "One liner."
	var plain_compiled: String = str(SheetCompiler.compile(plain, "user://cd_c.gd").get("output", ""))
	ok = _check("typed-host sheet emits the description",
		plain_compiled.contains("extends Node2D\n## One liner.\n"), true) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] class_description_roundtrip_test: %s" % label)
		return true
	print("[FAIL] class_description_roundtrip_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
