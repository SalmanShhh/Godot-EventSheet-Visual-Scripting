# EventForge - lifting GDScript that follows Godot's own style guide.
#
# THE CONTRACT: a hand-written .gd opened as a sheet must render as real rows, and the two
# things that stopped it were both spelling, not semantics.
#
#   1. TWO blank lines between top-level functions - what the official GDScript style guide
#      asks for, so essentially every hand-written file has them. The import groups contiguous
#      non-func lines, so the gap before a DOCUMENTED function arrives inside that function's
#      `##` block row rather than as a blank row of its own. That row's leading blank count was
#      dropped, emission re-added a single blank, the whole-file byte-verify came up one line
#      short per documented function, and the lift reverted EVERYTHING to verbatim blocks.
#
#   2. A TYPED COLLECTION return (`-> Array[Dictionary]:`) - ordinary modern GDScript. The
#      header regex accepted only a bare identifier there, so the header matched nothing at
#      all; and because a failed row re-anchors the trailing run, one such helper also took
#      every function above it down with it.
#
# Both are pinned here by VALUE (how many functions lift) and by BYTES (the file must still
# reproduce exactly), because a lift that gains rows while corrupting the source is worse than
# no lift at all.
@tool
class_name StyleGuideLiftTest
extends RefCounted

## Style-guide spacing: two blank lines between top-level functions, each with a `##` doc
## comment. Before the fix this lifted 0 functions and stayed 5 verbatim blocks.
const DOC_GAP_SOURCE := """extends Node

var speed: float = 200.0


## Doubles the value.
func doubled(value: float) -> float:
	return value * 2.0


## Halves the value.
func halved(value: float) -> float:
	return value * 0.5
"""

## The same file with ONE blank line between functions. It lifted before the fix and must keep
## lifting: the gap count now rides through the doc row, so this is the case that would break
## if the count were ever double-counted against the emitter's own separator.
const SINGLE_GAP_SOURCE := """extends Node

var speed: float = 200.0

## Doubles the value.
func doubled(value: float) -> float:
	return value * 2.0

## Halves the value.
func halved(value: float) -> float:
	return value * 0.5
"""

## A typed-collection return on a mid-file helper (the trailing `if` keeps it out of the
## trailing run, so only the byte-gated anchor path can claim it).
const TYPED_RETURN_SOURCE := """extends Node

var rows: Array[Dictionary] = []

func all_rows() -> Array[Dictionary]:
	return rows

if true:
	pass
"""

## Undocumented functions separated by the style guide's two blank lines - the gap arrives as a
## real blank row here, which is the path that already worked. Pinned so the doc-row fix cannot
## regress it.
const PLAIN_GAP_SOURCE := """extends Node

func doubled(value: float) -> float:
	return value * 2.0


func halved(value: float) -> float:
	return value * 0.5
"""

## An explicitly `: Variant`-annotated parameter beside ordinary typed and untyped ones. "Variant"
## used to double as the emitter's render-bare sentinel, so this header re-emitted `row` and the
## whole file reverted - one such helper cost every function in the file.
const VARIANT_PARAM_SOURCE := """extends Node

static func collect(row: Variant, organs: Dictionary, bare) -> void:
	print(row, organs, bare)
"""

## A plain `#` note written directly above a function - the ordinary way anyone annotates one.
## Comments lifted by the trailing run emit at the END of the file (that path exists for genuinely
## trailing notes), so this one was relocated there, failed the whole-file verify, and reverted
## every function in the file. One dock helper lost all twelve of its functions to a single note.
const MIDFILE_NOTE_SOURCE := """extends Node

func first() -> void:
	pass


# Second half lives elsewhere; this note keeps the wiring obvious.
func second() -> void:
	pass
"""

## The same shape with genuinely TRAILING comments, which the deferred path is for. Pinned so
## fixing the mid-file case does not quietly disable it.
const TRAILING_NOTE_SOURCE := """extends Node

func only() -> void:
	pass

# A closing note with nothing after it.
"""

## A multi-line dictionary inside a function body. Its opening line used to be matched as an
## ACTION on its own, stranding the entries in a block below it; now the whole literal is
## recognised and split at its line boundaries, so each entry is an action row you can read and
## drag. Consecutive code rows re-emit by appending their lines, so this stays byte-exact.
const BODY_LITERAL_SOURCE := """extends Node

func _ready() -> void:
	var waves := {
		"calm": 3,
		"busy": 8,
	}
	print(waves)
"""

## A `#` note inside a function body. It becomes a real CommentRow action - the same resource a
## comment authored in the sheet uses - so it drags, disables and converts like any other comment
## instead of being a code block that merely looks like one. An unusual marker (`#` with no space)
## is claimed too: the row records it, so emission writes it back exactly as it was written.
const BODY_NOTE_SOURCE := """extends Node

func _ready() -> void:
	# Bank the streak before the reset below.
	print("hi")
"""

const ODD_NOTE_SOURCE := """extends Node

func _ready() -> void:
	#no space after the hash
	print("hi")
"""

## A file whose COMMENTS discuss the instance-backed provider convention. The compiler declares
## a provider member for every such reference it finds in the emitted lines, and it used to read
## these comments as real call sites - so merely opening this file and saving it injected two
## lines of code that were never in it. Prose is not a use site.
const PROVIDER_PROSE_SOURCE := """extends Node

# Baked templates call through __eventsheet_provider_Score.add(1) on the provider path,
# and __eventsheet_provider_Score is declared once per class.
func note() -> void:
	pass
"""


static func run() -> bool:
	var all_passed: bool = true
	var importer: GDScriptImporter = GDScriptImporter.new()

	# ── Style-guide spacing: documented functions lift, and the file still round-trips ──
	var doc_sheet: EventSheetResource = importer.import_external_source(DOC_GAP_SOURCE)
	doc_sheet.external_source_path = "user://style_lift_doc.gd"
	all_passed = _check("two-blank-line documented functions lift", _function_names(doc_sheet),
		["doubled", "halved"]) and all_passed
	all_passed = _check("the doc gap file reproduces byte-identically",
		str(SheetCompiler.compile(doc_sheet, "user://style_lift_doc.gd").get("output", "")),
		DOC_GAP_SOURCE) and all_passed
	# The point of the fix is that structure REPLACES blocks, not that it joins them.
	all_passed = _check("its function bodies are no longer verbatim blocks",
		_raw_block_count(doc_sheet.events), 1) and all_passed
	# Each function's doc comment survives the lift - dropping it would round-trip only by
	# leaving the text in a block, which is the failure this test exists to catch.
	all_passed = _check("the doc comment rides on the lifted function",
		_doc_comment_of(doc_sheet, "doubled"), "Doubles the value.") and all_passed

	# ── Single-blank spacing keeps working (no double-counted separator) ──
	var single_sheet: EventSheetResource = importer.import_external_source(SINGLE_GAP_SOURCE)
	single_sheet.external_source_path = "user://style_lift_single.gd"
	all_passed = _check("single-blank documented functions still lift", _function_names(single_sheet),
		["doubled", "halved"]) and all_passed
	all_passed = _check("the single-gap file reproduces byte-identically",
		str(SheetCompiler.compile(single_sheet, "user://style_lift_single.gd").get("output", "")),
		SINGLE_GAP_SOURCE) and all_passed

	# ── Undocumented two-blank spacing (the blank-row path) is untouched ──
	var plain_sheet: EventSheetResource = importer.import_external_source(PLAIN_GAP_SOURCE)
	plain_sheet.external_source_path = "user://style_lift_plain.gd"
	all_passed = _check("undocumented two-blank functions lift", _function_names(plain_sheet),
		["doubled", "halved"]) and all_passed
	all_passed = _check("the plain gap file reproduces byte-identically",
		str(SheetCompiler.compile(plain_sheet, "user://style_lift_plain.gd").get("output", "")),
		PLAIN_GAP_SOURCE) and all_passed

	# ── A typed-collection return no longer blocks the header match ──
	var typed_sheet: EventSheetResource = importer.import_external_source(TYPED_RETURN_SOURCE)
	typed_sheet.external_source_path = "user://style_lift_typed.gd"
	all_passed = _check("a typed-collection return lifts", _function_names(typed_sheet),
		["all_rows"]) and all_passed
	all_passed = _check("the typed return rides verbatim on the function",
		_return_type_name_of(typed_sheet, "all_rows"), "Array[Dictionary]") and all_passed
	all_passed = _check("the typed-return file reproduces byte-identically",
		str(SheetCompiler.compile(typed_sheet, "user://style_lift_typed.gd").get("output", "")),
		TYPED_RETURN_SOURCE) and all_passed

	# ── An explicit `: Variant` annotation is not the same as no annotation ──
	var variant_sheet: EventSheetResource = importer.import_external_source(VARIANT_PARAM_SOURCE)
	variant_sheet.external_source_path = "user://style_lift_variant.gd"
	all_passed = _check("a helper with a Variant-annotated param lifts",
		_function_names(variant_sheet), ["collect"]) and all_passed
	all_passed = _check("the annotated param keeps its type, the bare one stays bare",
		_param_types_of(variant_sheet, "collect"), ["Variant", "Dictionary", ""]) and all_passed
	all_passed = _check("the Variant-param file reproduces byte-identically",
		str(SheetCompiler.compile(variant_sheet, "user://style_lift_variant.gd").get("output", "")),
		VARIANT_PARAM_SOURCE) and all_passed

	# ── A `#` note above a function must not relocate to the end of the file ──
	var note_sheet: EventSheetResource = importer.import_external_source(MIDFILE_NOTE_SOURCE)
	note_sheet.external_source_path = "user://style_lift_note.gd"
	all_passed = _check("both functions lift despite the note between them",
		_function_names(note_sheet), ["first", "second"]) and all_passed
	all_passed = _check("the mid-file note file reproduces byte-identically",
		str(SheetCompiler.compile(note_sheet, "user://style_lift_note.gd").get("output", "")),
		MIDFILE_NOTE_SOURCE) and all_passed

	# ...while a genuinely trailing note still uses the deferred path it was written for.
	var trailing_sheet: EventSheetResource = importer.import_external_source(TRAILING_NOTE_SOURCE)
	trailing_sheet.external_source_path = "user://style_lift_trailing.gd"
	all_passed = _check("a trailing note still lifts its function",
		_function_names(trailing_sheet), ["only"]) and all_passed
	all_passed = _check("the trailing note file reproduces byte-identically",
		str(SheetCompiler.compile(trailing_sheet, "user://style_lift_trailing.gd").get("output", "")),
		TRAILING_NOTE_SOURCE) and all_passed

	# -- A body note becomes a real comment row, not a code block that looks like one --
	var note_body: EventSheetResource = importer.import_external_source(BODY_NOTE_SOURCE)
	note_body.external_source_path = "user://style_lift_body_note.gd"
	all_passed = _check("a body note lifts to a CommentRow action",
		_action_kinds(note_body), ["CommentRow", "ACEAction"]) and all_passed
	all_passed = _check("its text drops the comment marker",
		_first_comment_text(note_body), "Bank the streak before the reset below.") and all_passed
	all_passed = _check("the body-note file reproduces byte-identically",
		str(SheetCompiler.compile(note_body, "user://style_lift_body_note.gd").get("output", "")),
		BODY_NOTE_SOURCE) and all_passed
	# The marker rides on the row, so a `#no space` note is claimed as a comment too and re-emits
	# exactly as written instead of gaining a space.
	var odd_note: EventSheetResource = importer.import_external_source(ODD_NOTE_SOURCE)
	odd_note.external_source_path = "user://style_lift_odd_note.gd"
	all_passed = _check("an unusual marker is claimed too, and recorded",
		_action_kinds(odd_note), ["CommentRow", "ACEAction"]) and all_passed
	all_passed = _check("the marker rides on the row so it re-emits as written",
		_first_comment_marker(odd_note), "#") and all_passed
	all_passed = _check("the odd-note file still reproduces byte-identically",
		str(SheetCompiler.compile(odd_note, "user://style_lift_odd_note.gd").get("output", "")),
		ODD_NOTE_SOURCE) and all_passed

	# -- A body literal lifts as ONE structured Declare action, and still round-trips --
	var body_sheet: EventSheetResource = importer.import_external_source(BODY_LITERAL_SOURCE)
	body_sheet.external_source_path = "user://style_lift_body_literal.gd"
	var body_decl: CollectionDeclRow = _first_decl(body_sheet)
	all_passed = _check("a canonical body literal lifts to a Declare row", body_decl != null, true) and all_passed
	all_passed = _check("it knows its name", body_decl.variable_name() if body_decl != null else "", "waves") and all_passed
	all_passed = _check("its entries are structured values",
		[Array(body_decl.entry_keys), Array(body_decl.entry_values)] if body_decl != null else [],
		[["\"calm\"", "\"busy\""], ["3", "8"]]) and all_passed
	all_passed = _check("the body-literal file reproduces byte-identically",
		str(SheetCompiler.compile(body_sheet, "user://style_lift_body_literal.gd").get("output", "")),
		BODY_LITERAL_SOURCE) and all_passed
	# Option 3: the inline value edit (indexes ride in edit_kind). The emitted line must change
	# and the file must stay parseable - the round-trip contract only covers UNTOUCHED files.
	var body_event: EventRow = null
	for entry: Variant in body_sheet.events:
		if entry is EventRow and (entry as EventRow).actions.has(body_decl):
			body_event = entry
	var decl_action_index: int = body_event.actions.find(body_decl) if body_event != null else -1
	all_passed = _check("the inline line edit rewrites one entry",
		EventSheetViewport._apply_decl_entry_edit(body_event, "decl_entry_line:%d:0" % decl_action_index, "\"calm\" = 12"), true) and all_passed
	all_passed = _check("the edited entry emits its new value",
		str(SheetCompiler.compile(body_sheet, "user://style_lift_body_literal.gd").get("output", "")).contains("		\"calm\": 12,"), true) and all_passed
	all_passed = _check("a blank inline line is refused",
		EventSheetViewport._apply_decl_entry_edit(body_event, "decl_entry_line:%d:0" % decl_action_index, "   "), false) and all_passed
	all_passed = _check("a dictionary line with no separator is refused",
		EventSheetViewport._apply_decl_entry_edit(body_event, "decl_entry_line:%d:0" % decl_action_index, "just_a_value"), false) and all_passed
	# Option 2's dialog path shares one static mutation: add, edit, and the refusals.
	all_passed = _check("Add Entry appends a keyed entry",
		EventSheetQuickPromptDialogs.set_collection_entry(body_decl, -1, "\"swarm\"", "20"), true) and all_passed
	all_passed = _check("the added entry emits",
		str(SheetCompiler.compile(body_sheet, "user://style_lift_body_literal.gd").get("output", "")).contains("		\"swarm\": 20,"), true) and all_passed
	all_passed = _check("a dictionary entry with no key is refused",
		EventSheetQuickPromptDialogs.set_collection_entry(body_decl, -1, "", "9"), false) and all_passed
	all_passed = _check("a blank value is refused by the dialog path too",
		EventSheetQuickPromptDialogs.set_collection_entry(body_decl, 0, "\"calm\"", ""), false) and all_passed
	# Removal is the third menu verb; the entry must vanish from emission.
	body_decl.entry_keys.remove_at(2)
	body_decl.entry_values.remove_at(2)
	all_passed = _check("a removed entry no longer emits",
		str(SheetCompiler.compile(body_sheet, "user://style_lift_body_literal.gd").get("output", "")).contains("swarm"), false) and all_passed
	# A NON-canonical literal (no trailing comma) must refuse the structured lift and fall back
	# to per-line rows - claiming it would re-emit a comma the file never had.
	var loose: EventSheetResource = importer.import_external_source("extends Node\n\nfunc _ready() -> void:\n\tvar odd := {\n\t\t\"a\": 1\n\t}\n\tprint(odd)\n")
	loose.external_source_path = "user://style_lift_loose.gd"
	all_passed = _check("a literal without trailing commas stays per-line rows",
		_first_decl(loose) == null, true) and all_passed
	all_passed = _check("...and still reproduces byte-identically",
		str(SheetCompiler.compile(loose, "user://style_lift_loose.gd").get("output", "")).contains("var odd := {"), true) and all_passed

	# ── Prose about the provider convention must not be compiled as a call site ──
	var prose_sheet: EventSheetResource = importer.import_external_source(PROVIDER_PROSE_SOURCE)
	prose_sheet.external_source_path = "user://style_lift_prose.gd"
	var prose_output: String = str(SheetCompiler.compile(prose_sheet, "user://style_lift_prose.gd").get("output", ""))
	all_passed = _check("a comment mentioning a provider member injects no declaration",
		prose_output.contains("var __eventsheet_provider_Score := Score.new()"), false) and all_passed
	all_passed = _check("the provider-prose file reproduces byte-identically",
		prose_output, PROVIDER_PROSE_SOURCE) and all_passed

	return all_passed


## The lifted function names, sorted - a VALUE to compare against, not a count.
static func _function_names(sheet: EventSheetResource) -> Array:
	var names: Array = []
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			names.append((entry as EventFunction).function_name)
	names.sort()
	return names


## The class of each action across the sheet's events, in order - the VALUE that says whether a
## note arrived as a real comment resource or as a block of code.
static func _action_kinds(sheet: EventSheetResource) -> Array:
	var kinds: Array = []
	for entry: Variant in sheet.events:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				kinds.append("CommentRow" if action is CommentRow else ("RawCodeRow" if action is RawCodeRow else "ACEAction"))
	return kinds


static func _first_comment_marker(sheet: EventSheetResource) -> String:
	for entry: Variant in sheet.events:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				if action is CommentRow:
					return (action as CommentRow).source_marker
	return "<no comment row>"


static func _first_comment_text(sheet: EventSheetResource) -> String:
	for entry: Variant in sheet.events:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				if action is CommentRow:
					return (action as CommentRow).text
	return "<no comment row>"


## The first structured collection declaration anywhere in the sheet's events, or null.
static func _first_decl(sheet: EventSheetResource) -> CollectionDeclRow:
	for entry: Variant in sheet.events:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				if action is CollectionDeclRow:
					return action
	return null


## Every verbatim code action in the sheet, in order, as its literal text - the VALUE that says
## whether a literal arrived as separate rows or as one wall.
static func _raw_action_texts(sheet: EventSheetResource) -> Array:
	var texts: Array = []
	for entry: Variant in sheet.events:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				if action is RawCodeRow:
					texts.append((action as RawCodeRow).code)
	return texts


## Each parameter's declared type in order, "" for one that carries no annotation at all.
static func _param_types_of(sheet: EventSheetResource, function_name: String) -> Array:
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			var types: Array = []
			for param: ACEParam in (entry as EventFunction).params:
				types.append(param.type_name)
			return types
	return ["<no such function>"]


static func _doc_comment_of(sheet: EventSheetResource, function_name: String) -> String:
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			return (entry as EventFunction).doc_comment.strip_edges()
	return "<no such function>"


static func _return_type_name_of(sheet: EventSheetResource, function_name: String) -> String:
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			return (entry as EventFunction).return_type_name
	return "<no such function>"


static func _raw_block_count(items: Array) -> int:
	var count: int = 0
	for item: Variant in items:
		if item is RawCodeRow:
			count += 1
		elif item is EventRow:
			count += _raw_block_count((item as EventRow).actions)
			count += _raw_block_count((item as EventRow).sub_events)
	return count


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] style_guide_lift_test: %s" % label)
		return true
	print("[FAIL] style_guide_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
