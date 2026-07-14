# EventForge - published-verb shell rendering: a RawCodeRow that is PURELY an `## @ace_*` annotation
# block (the header a pack author writes above each exposed func) renders as ONE Define-style line -
# role badge · friendly name · category chip - instead of a 7-line annotation wall. A pure VIEW over
# the same RawCodeRow: the resource, editing, and the byte round-trip are untouched (drift=0 pinned on
# a real pack). The classifier is strict: any real code line, a missing kind marker, or a missing
# @ace_name falls back to plain GDScript-block rendering.
@tool
class_name RawShellRenderTest
extends RefCounted


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

	# ── function_body_info: a lone top-level func (an unliftable helper) collapses to a ƒ header ──
	var tick: Dictionary = ViewportRowBuilder.function_body_info("func _tick() -> void:\n\tpass")
	ok = _check("a plain void func is a function row", str(tick.get("name", "")), "_tick") and ok
	ok = _check("void return recorded", str(tick.get("return_type", "")), "void") and ok
	var score: Dictionary = ViewportRowBuilder.function_body_info("func score(bonus: int) -> int:\n\treturn 5 + bonus\n\treturn 0")
	ok = _check("typed return recorded", str(score.get("return_type", "")), "int") and ok
	ok = _check("params captured", str(score.get("params", "")), "bonus: int") and ok
	ok = _check("body line count captured (blank/indented body)", int(score.get("body_lines", -1)), 2) and ok
	ok = _check("TWO top-level funcs stay a plain block (not one function row)",
		ViewportRowBuilder.function_body_info("func a() -> void:\n\tpass\nfunc b() -> void:\n\tpass").is_empty(), true) and ok
	ok = _check("a bodyless func stub is not collapsed",
		ViewportRowBuilder.function_body_info("func stub() -> void:").is_empty(), true) and ok
	ok = _check("a non-func block is not a function row",
		ViewportRowBuilder.function_body_info("health += 5\nqueue_free()").is_empty(), true) and ok

	# ── is_comment_only_block + strip_comment_prefix: a pure-comment block reads as a clean note (no
	# "setup"/code badge, no leading #), while any real code keeps the GDScript block treatment. ──
	ok = _check("a block of only ## comments is comment-only",
		ViewportRowBuilder.is_comment_only_block(PackedStringArray(["## On: the canvas clears", "## Off: strokes stay"])), true) and ok
	ok = _check("a # note is comment-only", ViewportRowBuilder.is_comment_only_block(PackedStringArray(["# tip"])), true) and ok
	ok = _check("a mixed code+comment block is NOT comment-only",
		ViewportRowBuilder.is_comment_only_block(PackedStringArray(["## note", "var x := 1"])), false) and ok
	ok = _check("an empty block is not comment-only (nothing to show as a note)",
		ViewportRowBuilder.is_comment_only_block(PackedStringArray(["", "  "])), false) and ok
	ok = _check("the ## prefix is dropped for display", ViewportRowBuilder.strip_comment_prefix("## On: the canvas"), "On: the canvas") and ok
	ok = _check("a single # prefix is dropped too", ViewportRowBuilder.strip_comment_prefix("# tip: keep it short"), "tip: keep it short") and ok

	# ── is_blank_block: a wholly blank block is round-trip spacing, not code - it renders badge-less. ──
	ok = _check("a wholly blank block is a blank block", ViewportRowBuilder.is_blank_block(PackedStringArray(["", "  "])), true) and ok
	ok = _check("a block with any content is not a blank block", ViewportRowBuilder.is_blank_block(PackedStringArray(["", "x"])), false) and ok

	# ── Rendering over an opened sheet whose annotated verb CAN'T lift (a custom return type keeps
	# it raw) - the shell is the honest fallback for whatever the per-function lift leaves behind,
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
	ok = _check("the shell keeps its RawCodeRow (pure view - editing/round-trip untouched)",
		shell_row != null and (shell_row.source_resource as RawCodeRow).code.contains("## @ace_codegen_template"), true) and ok
	ok = _check("the category rides as a chip", has_chip, true) and ok

	# ── Covenant: view-only - the sheet still round-trips byte-identically ──
	var reemitted: String = str(SheetCompiler.compile(dock.get_current_sheet(), "user://_raw_shell_source.gd").get("output", ""))
	ok = _check("drift stays 0 with shells rendered", reemitted == source, true) and ok
	dock.free()

	# ── A blank RawCodeRow (round-trip spacing separator) renders with NO "GDScript" badge - was an
	# empty pill. Build a real sheet with a stray blank block and inspect its rendered spans. ──
	var blank_source: String = "\n".join(PackedStringArray(["extends Node", "", "", "func _ready() -> void:", "	visible = true"])) + "\n"
	var blank_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	blank_dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var blank_sheet: EventSheetResource = EventSheetResource.new()
	var blank_row: RawCodeRow = RawCodeRow.new()
	blank_row.code = ""
	blank_sheet.events.append(blank_row)
	blank_sheet.external_source_path = "user://_blank_block.gd"
	blank_dock.setup(blank_sheet)
	var blank_view: EventSheetViewport = blank_dock._active_view()
	var blank_span_texts: Array = []
	for blank_entry: Dictionary in blank_view.get_flat_rows():
		var blank_rd: EventRowData = blank_entry.get("row")
		if blank_rd != null and blank_rd.source_resource == blank_row:
			for blank_span: SemanticSpan in blank_rd.spans:
				blank_span_texts.append(str(blank_span.text))
	ok = _check("a blank block has no GDScript badge", blank_span_texts.has("GDScript"), false) and ok
	blank_dock.free()

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] raw_shell_render_test: %s" % label)
		return true
	print("[FAIL] raw_shell_render_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
