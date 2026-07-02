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

	# ── Rendering over a REAL opened pack ──
	var pack_path: String = "res://eventsheet_addons/health/health_behavior.gd"
	var source: String = (FileAccess.open(pack_path, FileAccess.READ)).get_as_text()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._load_sheet_from_path(pack_path)
	var view: EventSheetViewport = dock._active_view()
	var shells: Array = []
	var take_damage_row: EventRowData = null
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null or not (row_data.source_resource is RawCodeRow):
			continue
		if row_data.spans.size() > 0 and str(row_data.spans[0].text) in ["Action", "Condition", "Expression"]:
			shells.append(row_data)
			for span: SemanticSpan in row_data.spans:
				if str(span.text) == "Take Damage":
					take_damage_row = row_data
	ok = _check("an opened pack renders MANY verb shells (health publishes dozens)", shells.size() > 20, true) and ok
	ok = _check("Take Damage's shell is among them", take_damage_row != null, true) and ok
	ok = _check("a shell visually collapses to one line", take_damage_row.line_count if take_damage_row != null else -1, 1) and ok
	ok = _check("the shell keeps its RawCodeRow (pure view — editing/round-trip untouched)",
		take_damage_row != null and (take_damage_row.source_resource as RawCodeRow).code.contains("## @ace_codegen_template"), true) and ok
	var category_chip: bool = false
	if take_damage_row != null:
		for span: SemanticSpan in take_damage_row.spans:
			if str(span.text) == "Health":
				category_chip = true
	ok = _check("the category rides as a chip", category_chip, true) and ok

	# ── Covenant: view-only — the opened pack still round-trips byte-identically ──
	var reemitted: String = str(SheetCompiler.compile(dock.get_current_sheet(), pack_path).get("output", ""))
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
