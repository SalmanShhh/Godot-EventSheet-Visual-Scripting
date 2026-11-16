# Godot EventSheets - a block kind's validate() is the quiet amber finding, not a red note in the row.
#
# A kind may say what is wrong with one of its rows. That sentence used to be appended to the row as
# red text; every other check on the canvas says its words in the strip under the selected row and
# marks the row with the quiet amber state. validate() now does the same: the row carries no extra
# span and no error colour, its note is the kind's own sentence, and a row with nothing wrong carries
# nothing.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "block_validate_is_quiet_test"
const PROBLEM := "That check is too short to mean anything."


class CheckedKind:
	extends EventSheetBlockKind

	func _init() -> void:
		kind_id = "validate_probe.checked"
		title = "Checked Probe"

	func fields() -> Array[Dictionary]:
		return [{"id": "text", "label": "Text", "type": TYPE_STRING, "default": ""}]

	func emit(block: CustomBlockRow) -> PackedStringArray:
		return PackedStringArray(["## CHECK: %s" % str(block.fields.get("text", ""))])

	func summary(block: CustomBlockRow) -> String:
		return str(block.fields.get("text", ""))

	func validate(block: CustomBlockRow) -> String:
		if str(block.fields.get("text", "")).length() < 4:
			return PROBLEM
		return ""


static func run() -> bool:
	var ok: bool = true
	var kind: CheckedKind = CheckedKind.new()
	EventSheetBlockRegistry.register_kind(kind)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_block("no"))
	sheet.events.append(_block("the player can reach the exit"))
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var bad: EventRowData = _row_with_text(editor._viewport, "no")
	var good: EventRowData = _row_with_text(editor._viewport, "the player can reach the exit")
	ok = SUPPORT.check(P, "both rows are on the canvas", bad != null and good != null, true) and ok
	if bad != null and good != null:
		var colours: Array[Color] = []
		var words: PackedStringArray = PackedStringArray()
		for span: EventSheetSemanticSpan in bad.spans:
			words.append(span.text)
			colours.append(span.metadata.get("text_color", Color.WHITE))
		ok = SUPPORT.check(P, "no warning sign is painted into the row", " ".join(words).contains("⚠"), false) and ok
		ok = SUPPORT.check(P, "the sentence is not painted into the row", " ".join(words).contains(PROBLEM), false) and ok
		ok = SUPPORT.check(P, "the row is the badge and the summary, nothing more", bad.spans.size(), 2) and ok
		ok = SUPPORT.check(P, "no span wears the error colour",
			colours.has(EventSheetActiveTheme.reading().error_text_color), false) and ok
		ok = SUPPORT.check(P, "the row wears the quiet amber note", bad.attention_note, PROBLEM) and ok
		ok = SUPPORT.check(P, "which is not the red state", bad.attention_severe, false) and ok
		ok = SUPPORT.check(P, "a row with nothing wrong carries nothing", good.attention_note, "") and ok
		ok = SUPPORT.check(P, "and the finding has no door, so the strip offers no button",
			str(bad.attention_findings[0].get("fix_label", "")) if not bad.attention_findings.is_empty() else "no finding", "") and ok
	editor.free()
	EventSheetBlockRegistry.unregister_kind(kind.kind_id)
	return ok


static func _block(text: String) -> CustomBlockRow:
	var block: CustomBlockRow = CustomBlockRow.new()
	block.kind_id = "validate_probe.checked"
	block.fields = {"text": text}
	return block


static func _row_with_text(viewport: EventSheetViewport, text: String) -> EventRowData:
	for entry: Dictionary in viewport.get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row != null and row.source_resource is CustomBlockRow \
				and str((row.source_resource as CustomBlockRow).fields.get("text", "")) == text:
			return row
	return null
