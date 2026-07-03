# Demo pack-defined block kind (the Custom Block API's living proof, like demo_health_addon.gd
# is for ACE providers). Drop a script extending EventSheetBlockKind into res://eventsheet_addons/
# and it registers automatically - no manifest, no plugin edits. This one is a "Note" row: a
# highlighted `## NOTE: <text>` line that opens as a first-class block instead of plain prelude
# text. kind_ids from packs are namespaced "<pack>.<name>".
@tool
extends EventSheetBlockKind

func _init() -> void:
	kind_id = "demo.note"
	title = "Note"

func fields() -> Array[Dictionary]:
	return [
		{"id": "text", "label": "Note", "type": TYPE_STRING, "default": ""},
	]

func emit(block: CustomBlockRow) -> PackedStringArray:
	var text: String = str(block.fields.get("text", "")).strip_edges()
	if text.is_empty():
		return PackedStringArray()
	return PackedStringArray(["## NOTE: %s" % text])

func lift(lines: PackedStringArray, i: int) -> Dictionary:
	if not lines[i].begins_with("## NOTE: "):
		return {}
	return verified_claim({"text": lines[i].substr(9)}, lines, i, 1)

func summary(block: CustomBlockRow) -> String:
	return str(block.fields.get("text", ""))
