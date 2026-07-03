# EventForge - the Custom Block API (registered non-ACE row kinds).
#
# THE CONTRACT: a registered EventSheetBlockKind wires all seams
# generically - the compiler emits its pure emit(), the importer lifts via byte-verify-gated
# lift() (a claim that cannot re-emit the source byte-exactly is dropped, the line stays a
# GDScript block), and the viewport renders kind badge + summary() as a SECTION row. This pins
# the registry, both proof kinds (Preload Resource, Region marker), the whole-file round-trip,
# the verify-gate rejecting near-misses, and undo-snapshot duplication.
@tool
class_name CustomBlockTest
extends RefCounted

const BLOCK_SOURCE := """extends Node

const Sfx := preload("res://sfx/jump.ogg")

#region Combat

func take_hit(damage: int) -> void:
	pass

#endregion
"""


static func run() -> bool:
	var all_passed: bool = true

	# ── The registry ──
	all_passed = _check("preload kind registered", EventSheetBlockRegistry.get_kind("preload") != null, true) and all_passed
	all_passed = _check("region kind registered", EventSheetBlockRegistry.get_kind("region") != null, true) and all_passed
	all_passed = _check("unknown kind resolves null", EventSheetBlockRegistry.get_kind("nope") == null, true) and all_passed

	# ── Dogfooding: the plugin's OWN EnumRow is a registered resource kind - the compiler,
	# importer, and viewport dispatch a shipped feature through the registry. ──
	var enum_probe: EnumRow = EnumRow.new()
	enum_probe.enum_name = "Mode"
	enum_probe.members = PackedStringArray(["IDLE", "RUN"])
	var enum_kind: EventSheetBlockKind = EventSheetBlockRegistry.kind_for(enum_probe)
	all_passed = _check("EnumRow resolves to the registered enum kind", enum_kind != null and enum_kind.kind_id == "enum", true) and all_passed
	all_passed = _check("the kind emits the canonical enum line",
		enum_kind.emit_lines(enum_probe), PackedStringArray(["enum Mode { IDLE, RUN }"])) and all_passed
	all_passed = _check("compiler enum emission goes through the kind (same bytes)",
		SheetCompiler._emit_enum_line(enum_probe), "enum Mode { IDLE, RUN }") and all_passed
	var enum_claim: Dictionary = enum_kind.lift(PackedStringArray(["enum Mode { IDLE, RUN }"]), 0)
	all_passed = _check("the kind lifts back to a real EnumRow resource",
		enum_claim.get("resource") is EnumRow and (enum_claim.get("resource") as EnumRow).enum_name == "Mode", true) and all_passed
	all_passed = _check("resource kinds stay out of the generic add surfaces",
		EventSheetBlockRegistry.addable_kinds().any(func(kind: EventSheetBlockKind) -> bool: return kind.kind_id == "enum" or kind.kind_id == "signal"), false) and all_passed
	var signal_probe: SignalRow = SignalRow.new()
	signal_probe.signal_name = "hurt"
	signal_probe.params = PackedStringArray(["amount: int"])
	var signal_kind: EventSheetBlockKind = EventSheetBlockRegistry.kind_for(signal_probe)
	all_passed = _check("SignalRow resolves to the registered signal kind", signal_kind != null and signal_kind.kind_id == "signal", true) and all_passed
	all_passed = _check("the signal kind emits the canonical declaration",
		signal_kind.emit_lines(signal_probe), PackedStringArray(["signal hurt(amount: int)"])) and all_passed
	var signal_claim: Dictionary = signal_kind.lift(PackedStringArray(["signal hurt(amount: int)"]), 0)
	all_passed = _check("the signal kind lifts back to a real SignalRow",
		signal_claim.get("resource") is SignalRow and (signal_claim.get("resource") as SignalRow).signal_name == "hurt", true) and all_passed

	# ── P2: pack-defined kinds register zero-config from eventsheet_addons/ ──
	var note_kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind("demo.note")
	all_passed = _check("pack-defined kind auto-registers from eventsheet_addons/", note_kind != null, true) and all_passed
	var note_importer: GDScriptImporter = GDScriptImporter.new()
	var note_sheet: EventSheetResource = note_importer.import_external_source("extends Node\n\n## NOTE: tune this after the jam\n")
	var note_row: CustomBlockRow = null
	for entry: Variant in note_sheet.events:
		if entry is CustomBlockRow:
			note_row = entry
	all_passed = _check("pack kind lifts its line", note_row != null and note_row.kind_id == "demo.note", true) and all_passed
	note_sheet.external_source_path = "user://note_sample.gd"
	all_passed = _check("pack kind round-trips byte-identically",
		str(SheetCompiler.compile(note_sheet, "user://note_sample.gd").get("output", "")), "extends Node\n\n## NOTE: tune this after the jam\n") and all_passed

	# ── Import: the preload + both region fences lift to CustomBlockRows ──
	var importer: GDScriptImporter = GDScriptImporter.new()
	var sheet: EventSheetResource = importer.import_external_source(BLOCK_SOURCE)
	sheet.external_source_path = "user://custom_block_sample.gd"
	var lifted_kinds: Array = []
	for entry: Variant in sheet.events:
		if entry is CustomBlockRow:
			lifted_kinds.append((entry as CustomBlockRow).kind_id)
	all_passed = _check("preload + both region fences lift", lifted_kinds, ["preload", "region", "region"]) and all_passed

	# ── Round-trip: an untouched sheet reproduces the file byte-identically ──
	var output: String = str(SheetCompiler.compile(sheet, "user://custom_block_sample.gd").get("output", ""))
	all_passed = _check("byte-identical round-trip with custom blocks", output, BLOCK_SOURCE) and all_passed

	# ── The verify-gate: near-miss lines stay verbatim GDScript, never a lossy claim ──
	var hostile: EventSheetResource = importer.import_external_source("extends Node\n\nconst Sfx := preload(\"res://a.ogg\") # keep my comment\n\n#region trailing-space \n")
	var hostile_blocks: int = 0
	for entry: Variant in hostile.events:
		if entry is CustomBlockRow:
			hostile_blocks += 1
	all_passed = _check("near-miss preload/region lines stay raw (verify-gated)", hostile_blocks, 0) and all_passed

	# ── The kinds' display contract ──
	var preload_row: CustomBlockRow = sheet.events[1] if sheet.events.size() > 1 and sheet.events[1] is CustomBlockRow else null
	if preload_row == null:
		for entry: Variant in sheet.events:
			if entry is CustomBlockRow and (entry as CustomBlockRow).kind_id == "preload":
				preload_row = entry
				break
	all_passed = _check("preload summary names constant and path",
		EventSheetBlockRegistry.get_kind("preload").summary(preload_row), "Sfx = res://sfx/jump.ogg") and all_passed

	# ── The viewport renders a custom block as a SECTION row: kind badge + summary ──
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(900, 400)
	view.set_sheet(sheet)
	var block_row_data: EventRowData = view._build_row_from_resource(preload_row, 0)
	all_passed = _check("custom block renders as a SECTION row", block_row_data.row_type, EventRowData.RowType.SECTION) and all_passed
	all_passed = _check("row shows the kind badge", block_row_data.spans[0].text, "Preload Resource") and all_passed
	all_passed = _check("row shows the kind summary", block_row_data.spans[1].text, "Sfx = res://sfx/jump.ogg") and all_passed
	view.free()

	# ── Undo-funnel compatibility: snapshot duplication preserves kind + fields ──
	var clone: CustomBlockRow = preload_row.duplicate(true)
	all_passed = _check("duplicate keeps kind_id", clone.kind_id, "preload") and all_passed
	all_passed = _check("duplicate keeps fields", str(clone.fields.get("path", "")), "res://sfx/jump.ogg") and all_passed

	# ── The generic schema dialog: add builds from defaults, edit prefills + applies undoably ──
	var dialog_sheet: EventSheetResource = EventSheetResource.new()
	dialog_sheet.host_class = "Node2D"
	var edit_target: CustomBlockRow = CustomBlockRow.new()
	edit_target.kind_id = "preload"
	edit_target.fields = {"name": "Music", "path": "res://music/theme.ogg"}
	dialog_sheet.events.append(edit_target)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(dialog_sheet)
	var block_dialog: EventSheetCustomBlockDialog = dock._custom_block_dialog
	# Edit the LIVE resource from the live sheet (setup/undo replace resources; the viewport
	# always emits the live one - a held stale reference would silently edit a dead copy).
	var live_target: CustomBlockRow = null
	for entry: Variant in dock._current_sheet.events:
		if entry is CustomBlockRow:
			live_target = entry
	block_dialog.open_edit(live_target)
	all_passed = _check("edit dialog prefills the constant name",
		(block_dialog._field_controls.get("name") as LineEdit).text, "Music") and all_passed
	(block_dialog._field_controls.get("path") as LineEdit).text = "res://music/boss.ogg"
	block_dialog._apply()
	# The undo funnel REPLACES resources on commit - re-fetch the live block from the live sheet.
	var live_block: CustomBlockRow = null
	for entry: Variant in dock._current_sheet.events:
		if entry is CustomBlockRow:
			live_block = entry
	all_passed = _check("edit applies through the undo funnel",
		str(live_block.fields.get("path", "")), "res://music/boss.ogg") and all_passed
	block_dialog.open_add("region")
	all_passed = _check("add dialog builds a bool field for the region fence",
		block_dialog._field_controls.get("is_end") is CheckBox, true) and all_passed
	(block_dialog._field_controls.get("label") as LineEdit).text = "Combat"
	block_dialog._apply()
	var region_count: int = 0
	for entry: Variant in dock._current_sheet.events:
		if entry is CustomBlockRow and (entry as CustomBlockRow).kind_id == "region":
			region_count += 1
	all_passed = _check("add inserts a new region block", region_count, 1) and all_passed

	# ── P3: every registered kind is reachable from the command palette ──
	var palette_titles: Array = []
	for command: Dictionary in dock._command_palette_commands():
		palette_titles.append(str(command.get("title", "")))
	all_passed = _check("palette lists built-in kinds", palette_titles.has("Add Preload Resource…") and palette_titles.has("Add Region…"), true) and all_passed
	all_passed = _check("palette lists pack-defined kinds", palette_titles.has("Add Note…"), true) and all_passed
	dock.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] custom_block_test: %s" % label)
		return true
	print("[FAIL] custom_block_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
