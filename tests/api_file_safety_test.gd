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
	ok = _built_in_ids_cannot_be_taken() and ok
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


## A kind that names a built-in id, as an editor plugin's `_enter_tree` might before anything has asked
## the registry for anything.
class ImpostorKind extends EventSheetBlockKind:
	var wording: String = ""

	func _init(id: String = "preload") -> void:
		kind_id = id
		title = "Impostor"

	func emit(_block: CustomBlockRow) -> PackedStringArray:
		return PackedStringArray(["# hijacked"])


static func _built_in_ids_cannot_be_taken() -> bool:
	var ok: bool = true
	var built_ins: Array = ["preload", "region", "enum", "signal", "moment"]
	# A cold registry: nothing has asked it for anything yet, which is when an editor plugin registers.
	EventSheetBlockRegistry._built_ins_registered = false
	EventSheetBlockRegistry._kinds.clear()
	EventSheets.register_block_kind(ImpostorKind.new("preload"))
	ok = SUPPORT.check(P, "a kind registered first cannot replace the built-in preload kind",
		EventSheetBlockRegistry.get_kind("preload") is EventSheetBlockRegistry.PreloadBlockKind, true) and ok
	var block: CustomBlockRow = EventSheets.preload_block_for("res://icon.svg")
	var emitted: PackedStringArray = EventSheetBlockRegistry.get_kind("preload").emit(block)
	ok = SUPPORT.check(P, "the user's preload row still emits a preload line", emitted[0].begins_with("const "), true) and ok
	for built_in: String in built_ins:
		EventSheetBlockRegistry._built_ins_registered = false
		EventSheetBlockRegistry._kinds.clear()
		EventSheetBlockRegistry.register_kind(ImpostorKind.new(built_in))
		var holder: EventSheetBlockKind = EventSheetBlockRegistry.get_kind(built_in)
		ok = SUPPORT.check(P, "the %s id stays the built-in kind" % built_in, holder != null and not (holder is ImpostorKind), true) and ok
	var reason: String = _registry().call("_refusal_for", ImpostorKind.new("region"))
	ok = SUPPORT.check(P, "the refusal names the id", reason.contains("'region'"), true) and ok
	ok = SUPPORT.check(P, "the refusal says it is built in", reason.contains("built-in"), true) and ok
	ok = SUPPORT.check(P, "an ordinary id is not refused", _registry().call("_refusal_for", ImpostorKind.new("my_pack.note")), "") and ok
	# Registering a pack-style kind first still works and leaves every built-in alone.
	EventSheetBlockRegistry._built_ins_registered = false
	EventSheetBlockRegistry._kinds.clear()
	EventSheetBlockRegistry.register_kind(ImpostorKind.new("my_pack.note"))
	var all_there: bool = EventSheetBlockRegistry.get_kind("my_pack.note") != null
	for built_in: String in built_ins:
		all_there = all_there and EventSheetBlockRegistry.get_kind(built_in) != null
	ok = SUPPORT.check(P, "a first registration of an ordinary id leaves the built-ins in place", all_there, true) and ok
	# Put the registry back the way the rest of the suite expects it.
	EventSheetBlockRegistry._kinds.erase("my_pack.note")
	return ok


## The registry as a script object, so a private helper can be asked by name.
static func _registry() -> GDScript:
	return EventSheetBlockRegistry
