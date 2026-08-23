# Godot EventSheets - the ONE place that answers questions about a #region.
#
# A region is not a resource: it is two plain lines of the file (`#region Name` and `#endregion`)
# stored as two independent CustomBlockRow fences in the same container. Everything a reader sees
# on a region row - its name, the fence line echoed at the right edge, the dashed rule down its
# body, the amber note when a fence has no partner - is derived here, so the row builder, the
# refactors, the menu and the tests can never answer the same question two ways.
#
# PURE + STATIC on purpose: no viewport, no theme, no display server. The pairing function takes a
# plain container Array (a sheet's `events`, or a group's), which is exactly the shape the model
# stores fences in, so both the view layer and the model-level refactors ask the same walk.
@tool
class_name EventSheetRegionFacts
extends RefCounted

## The Custom Block API id the two fences are stored under. Frozen - a kind_id is public API.
const KIND_ID: String = "region"

## The mark a region opener leads with: the character the file itself starts the fence with.
const FENCE_GLYPH: String = "#"

## The closing fence, verbatim. The kind emits exactly this for a closer, and the closing row's
## only text is this line.
const CLOSING_LINE: String = "#endregion"

## What a folded opener echoes: the script editor's own folded-fence shape.
const FOLDED_ECHO_JOIN: String = " … "

## What an unnamed region reads as. A fence may legitimately carry no label.
const UNNAMED_LABEL: String = "(unnamed region)"


## True when this row is one of the two fences of a region.
static func is_fence(entry: Variant) -> bool:
	return entry is CustomBlockRow and (entry as CustomBlockRow).kind_id == KIND_ID


## True when this row is the CLOSING fence (`#endregion`). False for an opener and for anything
## that is not a fence at all.
static func is_closing_fence(entry: Variant) -> bool:
	if not is_fence(entry):
		return false
	return bool(((entry as CustomBlockRow).fields as Dictionary).get("is_end", false))


## True when this row is an OPENING fence.
static func is_opening_fence(entry: Variant) -> bool:
	return is_fence(entry) and not is_closing_fence(entry)


## The region's name, trimmed. "" when the fence carries none.
static func label(entry: Variant) -> String:
	if not is_fence(entry):
		return ""
	return str(((entry as CustomBlockRow).fields as Dictionary).get("label", "")).strip_edges()


## The name a region READS with - its label, or the placeholder when it has none.
static func display_name(entry: Variant) -> String:
	var named: String = label(entry)
	return named if not named.is_empty() else UNNAMED_LABEL


## The one-line description a styled fence carries, trimmed. "" when it has none.
static func description(entry: Variant) -> String:
	if not is_fence(entry):
		return ""
	return str(((entry as CustomBlockRow).fields as Dictionary).get("description", "")).strip_edges()


## The region's own colour as the `#rrggbb` string the fence stores, or "" for "use the theme".
static func accent_hex(entry: Variant) -> String:
	if not is_fence(entry):
		return ""
	var stored: String = str(((entry as CustomBlockRow).fields as Dictionary).get("color", "")).strip_edges()
	return stored if Color.html_is_valid(stored) else ""


## The line of the file this fence IS - asked of the block kind that writes it, never formatted
## here, so the echo on the row can never drift from what the compiler emits. A styled opener
## emits its `## @ace_region(...)` marker above the fence; the FENCE is the last line, and the
## fence is what the row stands for.
static func fence_line(entry: Variant) -> String:
	if not is_fence(entry):
		return ""
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind(KIND_ID)
	if kind == null:
		return ""
	var emitted: PackedStringArray = kind.emit(entry as CustomBlockRow)
	return emitted[emitted.size() - 1] if not emitted.is_empty() else ""


## What a FOLDED opener echoes: both fences with the body elided, the way the script editor shows
## a folded region on one line.
static func folded_echo(entry: Variant) -> String:
	var opener: String = fence_line(entry)
	if opener.is_empty():
		return ""
	return "%s%s%s" % [opener, FOLDED_ECHO_JOIN, CLOSING_LINE]


## Every fence in ONE container, paired by a stack walk - the same grammar the view folds with,
## answered on the model so the refactors and the orphan notes agree with what is drawn.
## Returns {"pairs": {opener_index: closer_index}, "orphan_openers": Array[int],
## "orphan_closers": Array[int]}. Indices are positions in `container`.
static func pairing(container: Array) -> Dictionary:
	var pairs: Dictionary = {}
	var orphan_closers: Array[int] = []
	var open_stack: Array[int] = []
	for index: int in range(container.size()):
		var entry: Variant = container[index]
		if not is_fence(entry):
			continue
		if is_closing_fence(entry):
			if open_stack.is_empty():
				orphan_closers.append(index)
				continue
			pairs[open_stack.pop_back()] = index
			continue
		open_stack.append(index)
	var orphan_openers: Array[int] = []
	for still_open: int in open_stack:
		orphan_openers.append(still_open)
	orphan_openers.sort()
	return {"pairs": pairs, "orphan_openers": orphan_openers, "orphan_closers": orphan_closers}


## Where an unclosed opener's `#endregion` belongs: after the last row before the next structural
## head (another region opener, or an event group) or the end of the container - the same guess a
## script editor's fold makes. Returns the INSERT index, so `container.insert(result, closer)`
## puts the fence in the right place. -1 when `opener_index` is not an opening fence.
static func closer_insert_index(container: Array, opener_index: int) -> int:
	if opener_index < 0 or opener_index >= container.size() or not is_opening_fence(container[opener_index]):
		return -1
	for index: int in range(opener_index + 1, container.size()):
		var entry: Variant = container[index]
		if entry is EventGroup or is_fence(entry):
			return index
	return container.size()


## The amber sentence an unmatched OPENING fence wears: what is wrong, and what to write.
static func unclosed_note(entry: Variant) -> String:
	return "%s never closes, so it cannot fold. Add %s after the last row you want inside." % [
		display_name(entry), CLOSING_LINE
	]


## The amber sentence an unmatched CLOSING fence wears. There is nothing to close, so the only
## honest fix is to remove it or open a region above it.
static func unopened_note() -> String:
	return "%s closes nothing - there is no #region above it. Remove it, or open a region first." % CLOSING_LINE


## The fix button on an unclosed opener's note: the row the closing fence would land after.
static func close_after_label(row_number: int) -> String:
	return "Close after row %d" % row_number
