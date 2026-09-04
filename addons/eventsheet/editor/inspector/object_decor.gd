# Godot EventSheets - object-level Inspector decor (editor-only).
#
# The decor comments that bind to the NEXT variable (# @inspector_header, # @inspector_info,
# # @inspector_link ...) are parsed by the attribute-drawers plugin. Two decor lines belong to the
# OBJECT rather than to one property, so they are read here instead:
#
#   # @inspector_preview                              a live picture of this object at the top of
#                                                     its Inspector
#   # @inspector_handle <property> <kind> [from <p>]  a draggable handle in the 2D / 3D viewport
#
# Kinds: `point` (the property is a position), `length` (a distance from the anchor), `angle` (an
# angle in degrees around the anchor) and `points` (a list of positions). `from <property>` names
# the anchor the handle is measured against; without it the anchor is the node's own origin.
#
# Both are PLAIN `#` comments (never `##` - those merge into the hover tooltip), so they reach the
# editor only through the script's source text and emit nothing: a project without this plugin runs
# the same code and ships the same bytes. Parsed maps are cached per script and keyed by source
# length, exactly like the property decor parser - a same-length edit that misses the cache costs
# one stale render until the next real edit, and nothing else.
@tool
class_name EventSheetInspectorObjectDecor
extends RefCounted

## The handle kinds, frozen once shipped: a pack's decor line is source text a user wrote.
const HANDLE_KINDS: Array[String] = ["point", "length", "angle", "points"]
## The mark each kind wears in the viewport and on the Inspector Designer's chips.
const HANDLE_GLYPHS: Dictionary = {"point": "●", "length": "○", "angle": "◇", "points": "●●"}

const PREVIEW_LINE: String = "# @inspector_preview"
const HANDLE_PREFIX: String = "# @inspector_handle "

# script instance id -> {"len": <source length>, "decor": {...}}
static var _cache: Dictionary = {}


## The object decor of one script source: {"preview": bool, "handles": Array[Dictionary]}, each
## handle {"property", "kind", "from"}. Static + UI-free so the headless suite pins the contract.
static func parse(source: String) -> Dictionary:
	var decor: Dictionary = {"preview": false, "handles": []}
	if not source.contains("# @inspector_"):
		return decor
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line == PREVIEW_LINE:
			decor["preview"] = true
		elif line.begins_with(HANDLE_PREFIX):
			var handle: Dictionary = parse_handle_line(line.substr(HANDLE_PREFIX.length()))
			if not handle.is_empty():
				(decor["handles"] as Array).append(handle)
	return decor


## "radius length from position" -> {"property":"radius", "kind":"length", "from":"position"}.
## A line naming an unknown kind, a missing property, or anything that is not a plain identifier is
## refused (an empty Dictionary) rather than guessed at - a mistyped decor line draws no handle
## instead of dragging the wrong property.
static func parse_handle_line(spec: String) -> Dictionary:
	var words: PackedStringArray = spec.strip_edges().split(" ", false)
	if words.size() < 2:
		return {}
	var property: String = words[0]
	var kind: String = words[1]
	if not _is_identifier(property) or not HANDLE_KINDS.has(kind):
		return {}
	var anchor: String = ""
	if words.size() >= 4 and words[2] == "from":
		if not _is_identifier(words[3]):
			return {}
		anchor = words[3]
	elif words.size() != 2:
		return {}
	return {"property": property, "kind": kind, "from": anchor}


## The object decor of a live object, through the per-script cache. A scriptless object (or one
## whose source names no decor at all) answers with the empty decor.
static func for_object(object: Object) -> Dictionary:
	if object == null:
		return {"preview": false, "handles": []}
	var script: GDScript = object.get_script() as GDScript
	if script == null:
		return {"preview": false, "handles": []}
	var source: String = script.source_code
	if not source.contains("# @inspector_"):
		return {"preview": false, "handles": []}
	var key: int = script.get_instance_id()
	var cached: Variant = _cache.get(key)
	if cached is Dictionary and int((cached as Dictionary).get("len", -1)) == source.length():
		return (cached as Dictionary).get("decor", {})
	var decor: Dictionary = parse(source)
	_cache[key] = {"len": source.length(), "decor": decor}
	return decor


## The handles one object declares, in declaration order.
static func handles_for(object: Object) -> Array:
	return for_object(object).get("handles", [])


## True when the object asked for the preview card at the top of its Inspector.
static func wants_preview(object: Object) -> bool:
	return bool(for_object(object).get("preview", false))


## One handle as the chip an author reads before opening a scene: "radius ○".
static func chip_text(handle: Dictionary) -> String:
	var kind: String = str(handle.get("kind", ""))
	var glyph: String = str(HANDLE_GLYPHS.get(kind, "●"))
	var anchor: String = str(handle.get("from", ""))
	if anchor.is_empty():
		return "%s %s" % [str(handle.get("property", "")), glyph]
	return "%s %s from %s" % [str(handle.get("property", "")), glyph, anchor]


## A whole handle list as chips, in declaration order.
static func chips(handles: Array) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for handle: Variant in handles:
		if handle is Dictionary:
			texts.append(chip_text(handle as Dictionary))
	return texts


## A plain GDScript identifier - the only thing a decor line may name.
static func _is_identifier(text: String) -> bool:
	return not text.is_empty() and text.is_valid_identifier()
