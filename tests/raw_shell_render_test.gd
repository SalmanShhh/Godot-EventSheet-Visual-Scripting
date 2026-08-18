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
	# A static helper is a function too. Tool and utility scripts are largely static, so while the
	# prefix was unrecognized those files rendered as walls of code next to tidy non-static rows.
	var shared: Dictionary = ViewportRowBuilder.function_body_info("static func shared(id: String) -> Array[Dictionary]:\n\treturn []")
	ok = _check("a static func is a function row", str(shared.get("name", "")), "shared") and ok
	ok = _check("its typed-collection return is recorded", str(shared.get("return_type", "")), "Array[Dictionary]") and ok
	ok = _check("its params are captured", str(shared.get("params", "")), "id: String") and ok

	# -- data_literal_info: a multi-line collection is ONE value, so it collapses to one row --
	# A table of constants rendered as fifteen lines of code makes data look like logic and buries
	# the rows around it. The collapse is a pure view: the block is unchanged, so the byte
	# round-trip is untouched and double-click still opens the code editor on the real entries.
	var table: Dictionary = ViewportRowBuilder.data_literal_info(
		"const RULES := {\n\t\"a\": 1,\n\t\"b\": 2,\n}")
	ok = _check("a dictionary literal collapses", str(table.get("head", "")), "const RULES := {") and ok
	ok = _check("its entries are counted", int(table.get("entries", -1)), 2) and ok
	ok = _check("its closing bracket is kept", str(table.get("close", "")), "}") and ok
	var typed: Dictionary = ViewportRowBuilder.data_literal_info(
		"var rows: Array[Dictionary] = [\n\t{\"x\": 1},\n\t{\"y\": 2},\n]")
	ok = _check("a typed array literal collapses too", int(typed.get("entries", -1)), 2) and ok
	# A nested value closes with its OWN `},` line - counting that as an entry reported a
	# two-key dictionary as three.
	var nested: Dictionary = ViewportRowBuilder.data_literal_info(
		"const M := {\n\t\"a\": {\n\t\t\"deep\": 1,\n\t},\n\t\"b\": 2,\n}")
	ok = _check("a nested value counts as ONE entry, not its closing line",
		int(nested.get("entries", -1)), 2) and ok
	# ...and the refusals, which are what keep the collapse from ever hiding real code.
	ok = _check("a WRAPPED CALL is not a literal (a bare `(` opens arguments)",
		ViewportRowBuilder.data_literal_info("add_child(\n\tnode,\n)").is_empty(), true) and ok
	ok = _check("a statement after the closing bracket refuses the collapse",
		ViewportRowBuilder.data_literal_info("const X := {\n\t\"a\": 1,\n}\nprint(X)").is_empty(), true) and ok
	ok = _check("a comment above the head refuses it (the note would be hidden)",
		ViewportRowBuilder.data_literal_info("# table\nconst X := {\n\t\"a\": 1,\n}").is_empty(), true) and ok
	ok = _check("a one-line literal is left alone (already readable)",
		ViewportRowBuilder.data_literal_info("const X := {\"a\": 1}").is_empty(), true) and ok
	ok = _check("an if block is not a literal",
		ViewportRowBuilder.data_literal_info("if ready:\n\tpass\n\treturn").is_empty(), true) and ok

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

	# ── Badge split: a BLANK RawCodeRow (round-trip spacing separator) renders with NO "GDScript" badge
	# (was an empty pill), while a GENUINE code block KEEPS the badge so it reads unambiguously as code -
	# the explicit marking that lets it round-trip as raw truth. Both rows, one dock, inspect their spans. ──
	var blank_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	blank_dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var blank_sheet: EventSheetResource = EventSheetResource.new()
	var blank_row: RawCodeRow = RawCodeRow.new()
	blank_row.code = ""
	blank_sheet.events.append(blank_row)
	var code_row: RawCodeRow = RawCodeRow.new()
	code_row.code = "flags |= 2"  # a genuine, irreducible statement (no ACE) - stays a GDScript block
	blank_sheet.events.append(code_row)
	blank_sheet.external_source_path = "user://_blank_block.gd"
	blank_dock.setup(blank_sheet)
	var blank_view: EventSheetViewport = blank_dock._active_view()
	var blank_span_texts: Array = []
	var code_span_texts: Array = []
	for blank_entry: Dictionary in blank_view.get_flat_rows():
		var blank_rd: EventRowData = blank_entry.get("row")
		if blank_rd == null:
			continue
		if blank_rd.source_resource == blank_row:
			for blank_span: SemanticSpan in blank_rd.spans:
				blank_span_texts.append(str(blank_span.text))
		elif blank_rd.source_resource == code_row:
			for code_span: SemanticSpan in blank_rd.spans:
				code_span_texts.append(str(code_span.text))
	ok = _check("a blank block has no GDScript badge", blank_span_texts.has("GDScript"), false) and ok
	ok = _check("a genuine code block keeps the GDScript badge (explicit)", code_span_texts.has("GDScript"), true) and ok
	blank_dock.free()

	# ── #4 covenant: a genuine irreducible code block, opened from a .gd, stays an explicit RawCodeRow and
	# recompiles byte-for-byte - the "GDScript block survives the round-trip" guarantee. ──
	var code_source: String = "\n".join(PackedStringArray(["extends Node", "", "", "func _ready() -> void:", "	flags |= 2"])) + "\n"
	var code_imported: EventSheetResource = GDScriptImporter.new().import_external_source(code_source)
	code_imported.external_source_path = "user://_code_block_rt.gd"
	var code_reemit: String = str(SheetCompiler.compile(code_imported, "user://_code_block_rt.gd").get("output", ""))
	ok = _check("a genuine code block round-trips byte-identically", code_reemit == code_source, true) and ok

	# -- statement_sentence + call_parts: a single lifted statement READS as a step --
	# `score += wave[1]` shown as "Add wave[1] to score" removes the one part of a line a reader has
	# to decode. Both classifiers are pure views over the unchanged RawCodeRow, so nothing here can
	# touch emission; the refusals below are what keep an ALMOST-right sentence off the canvas.
	ok = _check("compound add reads as a sentence", _sentence_text("score += wave[1]"), "Add wave[1] to score") and ok
	var add_sentence: Dictionary = ViewportRowBuilder.statement_sentence("score += wave[1]")
	ok = _check("the added amount is tinted as a value",
		str(((add_sentence.get("segments", []) as Array)[1] as Dictionary).get("tone", "")), "value") and ok
	# A declaration is its own ROW SHAPE now (a type-word chip, the name, the value), so it reads as
	# Construct's local-variable row rather than as a step - and the annotation never shows.
	ok = _check("a typed declaration reads as a local row",
		_sentence_text("var label: String = wave[0]"), "Local text label = wave[0]") and ok
	ok = _check("an inferred declaration reads the same", _sentence_text("var n := 3"), "Local number n = 3") and ok
	ok = _check("plain assignment reads as Set", _sentence_text("x = 5"), "Set x to 5") and ok
	ok = _check("compound subtract reads as Subtract", _sentence_text("hp -= dmg"), "Subtract dmg from hp") and ok
	ok = _check("compound multiply names the target first", _sentence_text("speed *= 2"), "Multiply speed by 2") and ok
	ok = _check("compound divide names the target first", _sentence_text("speed /= 2"), "Divide speed by 2") and ok
	ok = _check("a returned value reads as Return", _sentence_text("return rows"), "Return rows") and ok
	# A bare return inside an ordinary action body means "stop here", which is Construct's Stop event.
	ok = _check("a bare return stops the event", _sentence_text("return"), "Stop event") and ok
	# ...and the refusals. A comparison is NOT an assignment, control flow is a branch rather than a
	# step, and a call belongs to the Object/Verb view below.
	ok = _check("a comparison is never mistaken for an assignment",
		ViewportRowBuilder.statement_sentence("x == y").is_empty(), true) and ok
	ok = _check("a <= comparison stays out too",
		ViewportRowBuilder.statement_sentence("x <= y").is_empty(), true) and ok
	ok = _check("control flow is refused", ViewportRowBuilder.statement_sentence("if ready:").is_empty(), true) and ok
	ok = _check("a call is not a sentence (it is the Object/Verb view)",
		ViewportRowBuilder.statement_sentence("emit_signal(\"hit\")").is_empty(), true) and ok
	ok = _check("await is never papered over",
		ViewportRowBuilder.statement_sentence("await ready_signal").is_empty(), true) and ok
	ok = _check("a multi-line block is refused",
		ViewportRowBuilder.statement_sentence("x = 1\ny = 2").is_empty(), true) and ok
	# An ` = ` inside a STRING must not split the line - a plain find() would report `x = "a` here.
	ok = _check("an ` = ` inside a string does not fool the split",
		_sentence_text("x = \"a = b\""), "Set x to \"a = b\"") and ok
	# A row lifted from inside an unlifted block keeps its depth, shown as four spaces per tab.
	var indented: Dictionary = ViewportRowBuilder.statement_sentence("\tscore += 1")
	ok = _check("a tab-indented statement records its indent", int(indented.get("indent", -1)), 1) and ok
	ok = _check("...and still claims the sentence", _sentence_text("\tscore += 1"), "Add 1 to score") and ok

	# call_parts: object · verb · parameters, the shape every ACE row already has.
	var set_text: Dictionary = ViewportRowBuilder.call_parts("subgroup_item.set_text(0, str(subgroup[0]))")
	ok = _check("the receiver is the object", str(set_text.get("target", "")), "subgroup_item") and ok
	ok = _check("the method reads as a verb", str(set_text.get("verb", "")), "Set Text") and ok
	ok = _check("its arguments split at the top level",
		Array(set_text.get("args", PackedStringArray()) as PackedStringArray), ["0", "str(subgroup[0])"]) and ok
	var bare_call: Dictionary = ViewportRowBuilder.call_parts("_add_self_leaves(a, b)")
	ok = _check("a receiverless call belongs to self", str(bare_call.get("target", "")), "self") and ok
	ok = _check("a leading underscore is trimmed from the verb", str(bare_call.get("verb", "")), "Add Self Leaves") and ok
	ok = _check("a node path is a legal object",
		str(ViewportRowBuilder.call_parts("$HUD/Bar.update_value(hp)").get("target", "")), "$HUD/Bar") and ok
	ok = _check("a no-argument call still claims",
		str(ViewportRowBuilder.call_parts("queue_free()").get("verb", "")), "Queue Free") and ok
	ok = _check("an assignment is not a call row",
		ViewportRowBuilder.call_parts("x = foo()").is_empty(), true) and ok
	ok = _check("a chained call has no single object",
		ViewportRowBuilder.call_parts("foo().bar()").is_empty(), true) and ok
	ok = _check("arithmetic after the call refuses it",
		ViewportRowBuilder.call_parts("foo(1) + 1").is_empty(), true) and ok
	ok = _check("an awaited call is refused",
		ViewportRowBuilder.call_parts("await thing()").is_empty(), true) and ok

	# -- Reading Mode: a body comment renders as an italic caption, marker dropped --
	# View state only: the CommentRow is unchanged, so toggling the pill back restores the
	# programmer view and the byte round-trip never notices.
	var caption_sheet: EventSheetResource = EventSheetResource.new()
	caption_sheet.host_class = "Node"
	var caption_event: EventRow = EventRow.new()
	caption_event.trigger_provider_id = "Core"
	caption_event.trigger_id = "OnReady"
	var caption_note: CommentRow = CommentRow.new()
	caption_note.text = "Keep only the entries that match."
	caption_event.actions.append(caption_note)
	caption_sheet.events.append(caption_event)
	var caption_view: EventSheetViewport = EventSheetViewport.new()
	caption_view.set_ace_registry(EventSheetACERegistry.new())
	caption_view.size = Vector2(900, 400)
	caption_view.set_sheet(caption_sheet)
	caption_view.set_reading_mode(true)
	var caption_text: String = ""
	var caption_italic: bool = false
	for row_index: int in 10:
		var row_data: EventRowData = caption_view._row_at(row_index)
		if row_data == null:
			break
		for span: SemanticSpan in row_data.spans:
			var meta: Dictionary = span.metadata if span.metadata is Dictionary else {}
			if bool(meta.get("action_comment", false)):
				caption_text = span.text
				var segments: Array = meta.get("bbcode_segments", [])
				if segments.size() > 0 and bool((segments[0] as Dictionary).get("italic", false)):
					caption_italic = true
	ok = _check("Reading Mode drops the comment marker", caption_text, "Keep only the entries that match.") and ok
	ok = _check("...and the caption is italic", caption_italic, true) and ok
	caption_view.set_reading_mode(false)
	var plain_text: String = ""
	for row_index: int in 10:
		var row_data: EventRowData = caption_view._row_at(row_index)
		if row_data == null:
			break
		for span: SemanticSpan in row_data.spans:
			var meta: Dictionary = span.metadata if span.metadata is Dictionary else {}
			if bool(meta.get("action_comment", false)):
				plain_text = span.text
	ok = _check("toggling the pill off restores the # marker", plain_text, "# Keep only the entries that match.") and ok
	caption_view.free()

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] raw_shell_render_test: %s" % label)
		return true
	print("[FAIL] raw_shell_render_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false


## The sentence a statement reads as, segments joined - one VALUE to compare per check.
static func _sentence_text(code: String) -> String:
	var sentence: Dictionary = ViewportRowBuilder.statement_sentence(code)
	if sentence.is_empty():
		return ""
	var text: String = ""
	for segment: Variant in (sentence.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return text
