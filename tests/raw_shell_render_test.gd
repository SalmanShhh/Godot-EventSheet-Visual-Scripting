# EventForge — published-verb shell rendering: a RawCodeRow that is PURELY an `## @ace_*` annotation
# block (the header a pack author writes above each exposed func) renders as ONE Define-style line —
# role badge · friendly name · category chip — instead of a 7-line annotation wall. A pure VIEW over
# the same RawCodeRow: the resource, editing, and the byte round-trip are untouched (drift=0 pinned on
# a real pack). The classifier is strict: any real code line, a missing kind marker, or a missing
# @ace_name falls back to plain GDScript-block rendering.
@tool
extends RefCounted
class_name RawShellRenderTest

static func run() -> bool:
	var ok: bool = true

	# ── The pure classifier ──
	var shell: Dictionary = ViewportRowBuilder.define_shell_info("\n".join(PackedStringArray([
		"",
		"## @ace_action",
		"## @ace_name(\"Take Damage\")",
		"## @ace_category(\"Health\")",
		"## @ace_codegen_template(\"$X.take_damage({amount})\")",
	])))
	ok = _check("action shell classified", str(shell.get("kind", "")), "action") and ok
	ok = _check("friendly name extracted", str(shell.get("name", "")), "Take Damage") and ok
	ok = _check("category extracted", str(shell.get("category", "")), "Health") and ok
	ok = _check("expression shell classified",
		str(ViewportRowBuilder.define_shell_info("## @ace_expression\n## @ace_name(\"Health %\")").get("kind", "")), "expression") and ok
	ok = _check("a row with real code is NOT a shell",
		ViewportRowBuilder.define_shell_info("## @ace_action\n## @ace_name(\"X\")\nfunc x() -> void:").is_empty(), true) and ok
	ok = _check("no @ace_name → not a shell (nothing to show)",
		ViewportRowBuilder.define_shell_info("## @ace_action\n## @ace_category(\"Y\")").is_empty(), true) and ok
	ok = _check("a plain comment block is not a shell",
		ViewportRowBuilder.define_shell_info("## just a note\n## nothing published").is_empty(), true) and ok
	ok = _check("an @ace_trigger block is left to the signal fold, not shelled",
		ViewportRowBuilder.define_shell_info("## @ace_trigger\n## @ace_name(\"On Hit\")").is_empty(), true) and ok

	# ── Rendering over an opened sheet whose annotated verb CAN'T lift (a custom return type keeps
	# it raw) — the shell is the honest fallback for whatever the per-function lift leaves behind,
	# so the annotation wall still reads as one Define-style line. ──
	var source: String = "
".join(PackedStringArray([
		"@tool",
		"extends Node",
		"",
		"func _warmup() -> PetHandle:",
		"	return null",
		"",
		"## @ace_action",
		"## @ace_name(\"Summon Pet\")",
		"## @ace_category(\"Pets\")",
		"## @ace_codegen_template(\"$X.summon()\")",
		"func summon() -> PetHandle:",
		"	return PetHandle.new()",
	])) + "
"
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var opened: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	opened.external_source_path = "user://_raw_shell_source.gd"
	dock.setup(opened)
	# The plain `_warmup` helper anchors in place now (custom returns lift via FunctionAnchorRow);
	# only the ANNOTATED verb must stay raw - its `## @ace_*` wall belongs to the trailing-scan
	# flow, so the anchor pass refuses it and the shell stays the honest fallback.
	ok = _check("the annotated custom-return verb stays raw (only _warmup lifts)", opened.functions.size(), 1) and ok
	var view: EventSheetViewport = dock._active_view()
	var shell_row: EventRowData = null
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is RawCodeRow 				and row_data.spans.size() > 0 and str(row_data.spans[0].text) == "Action":
			shell_row = row_data
	ok = _check("the unliftable verb renders as a shell", shell_row != null, true) and ok
	var has_name: bool = false
	var has_chip: bool = false
	if shell_row != null:
		for span: SemanticSpan in shell_row.spans:
			if str(span.text) == "Summon Pet":
				has_name = true
			if str(span.text) == "Pets":
				has_chip = true
	ok = _check("named from its @ace_name", has_name, true) and ok
	ok = _check("a shell visually collapses to one line", shell_row.line_count if shell_row != null else -1, 1) and ok
	ok = _check("the shell keeps its RawCodeRow (pure view — editing/round-trip untouched)",
		shell_row != null and (shell_row.source_resource as RawCodeRow).code.contains("## @ace_codegen_template"), true) and ok
	ok = _check("the category rides as a chip", has_chip, true) and ok

	# ── Covenant: view-only — the sheet still round-trips byte-identically ──
	var reemitted: String = str(SheetCompiler.compile(dock.get_current_sheet(), "user://_raw_shell_source.gd").get("output", ""))
	ok = _check("drift stays 0 with shells rendered", reemitted == source, true) and ok

	dock.free()
	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] raw_shell_render_test: %s" % label)
		return true
	print("[FAIL] raw_shell_render_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
