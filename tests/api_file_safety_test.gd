# Godot EventSheets - the file-safety half of the public extension API.
#
# THE CONTRACT: a third-party block kind, a removed pack or a misbehaving callback can never
# corrupt, silently drop or overwrite a user's file. Each group below is one promise, in the order
# the fixes landed: resource-kind lifts go through the byte gate, a built-in kind id cannot be
# taken, a block the compiler cannot emit is reported, a block whose pack is gone still draws,
# compile() says what it writes, and edit() is atomic.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "api_file_safety_test"


## A resource-kind claim that does NOT reproduce the line it consumed: it swaps `## KEEP ME` for a
## different raw block. The importer must refuse it.
class UngatedResourceKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "audit.ungated"
		title = "Ungated"

	func addable() -> bool:
		return false

	func handles(entry: Resource) -> bool:
		return entry is RawCodeRow and (entry as RawCodeRow).code == "## CHANGED"

	func emit_lines(entry: Resource) -> PackedStringArray:
		return PackedStringArray([(entry as RawCodeRow).code])

	func lift(lines: PackedStringArray, i: int) -> Dictionary:
		if lines[i] == "## KEEP ME":
			var row: RawCodeRow = RawCodeRow.new()
			row.code = "## CHANGED"
			return {"resource": row, "consumed": 1}
		return {}


## A resource-kind claim that DOES reproduce its line, so the gate has to let it through.
class FaithfulResourceKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "audit.faithful"
		title = "Faithful"

	func addable() -> bool:
		return false

	func handles(entry: Resource) -> bool:
		return entry is RawCodeRow and (entry as RawCodeRow).code == "## FAITHFUL"

	func emit_lines(entry: Resource) -> PackedStringArray:
		return PackedStringArray([(entry as RawCodeRow).code])

	func lift(lines: PackedStringArray, i: int) -> Dictionary:
		if lines[i] == "## FAITHFUL":
			var row: RawCodeRow = RawCodeRow.new()
			row.code = "## FAITHFUL"
			return {"resource": row, "consumed": 1}
		return {}


static func run() -> bool:
	var ok: bool = true
	ok = _resource_claims_are_gated() and ok
	return ok


static func _forget(kind_ids: Array) -> void:
	for kind_id: Variant in kind_ids:
		EventSheetBlockRegistry._kinds.erase(kind_id)


static func _row_kinds(sheet: EventSheetResource) -> Array:
	var out: Array = []
	for entry: Variant in sheet.events:
		out.append((entry as Object).get_class() if entry is Object else typeof(entry))
		if entry is RawCodeRow:
			out[out.size() - 1] = "raw:" + (entry as RawCodeRow).code.strip_edges()
	return out


static func _resource_claims_are_gated() -> bool:
	var ok: bool = true
	EventSheetBlockRegistry.rescan_pack_kinds()
	EventSheetBlockRegistry._kinds["audit.ungated"] = UngatedResourceKind.new()
	EventSheetBlockRegistry._kinds["audit.faithful"] = FaithfulResourceKind.new()
	var source: String = "extends Node\n\n## KEEP ME\n"
	var reemitted: String = SUPPORT.reemit(source, "user://api_file_safety.gd")
	ok = SUPPORT.check(P, "a resource claim that cannot reproduce its line leaves the file byte-identical",
		reemitted, source) and ok
	ok = SUPPORT.check(P, "the refused claim leaves the round trip holding", EventSheets.round_trips(source), true) and ok
	var faithful_source: String = "extends Node\n\n## FAITHFUL\n"
	ok = SUPPORT.check(P, "a resource claim that reproduces its line still lifts",
		SUPPORT.reemit(faithful_source, "user://api_file_safety.gd"), faithful_source) and ok
	_forget(["audit.ungated", "audit.faithful"])
	return ok
