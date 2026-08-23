@tool
class_name EventRowData
extends Resource

enum RowType {
EVENT,
GROUP,
COMMENT,
SECTION,
## R1 - a `#region` fence. It is NOT a group: it holds no locals, it cannot be switched off, and
## it is two plain lines of the file rather than a resource. So it reads as what it is in the
## script editor - a fold mark: a dashed `#` badge, a dashed rule down its body, and a slim
## closing tick whose only text is the `#endregion` the file really has.
REGION
}

var indent: int = 0
var row_type: int = RowType.EVENT
var folded: bool = false
var selected: bool = false
var hovered: bool = false
var spans: Array[SemanticSpan] = []
## Number of stacked text lines this row occupies. Precomputed cheaply so row
## heights/metrics can be resolved for EVENT rows without building their (lazy) spans.
var line_count: int = 1
var children: Array[EventRowData] = []
var source_resource: Resource = null
var row_uid: String = ""
var debug_state: String = ""
# Set by the viewport from EventSheetDiagnostics: a non-empty message paints a red error
# marker on the row and shows in its tooltip (the "error → row" deep-link). "" = no error.
var error_message: String = ""
# Live event trace: true while this event is in the latest streamed "fired" frame - a transient
# highlight so you can watch which events fire in real time during a debug run.
var firing: bool = false
# The pulse: 1.0 the moment a fired frame lands, decaying to 0 over ~half a second so a
# fire reads as a fading flash instead of a hard blink (an event still firing re-bumps it
# every streamed batch and holds near full glow).
var firing_intensity: float = 0.0
var line_number: int = 0
# The event-sheet stable event number (1-based, sheet order through groups and sub-events);
# 0 for non-event rows. View-only, recomputed per rebuild - never serialized.
var event_number: int = 0
var breakpoint_enabled: bool = false
var bookmark_enabled: bool = false
var disabled: bool = false
# Per-row custom tint (event-sheet-style colored comments); alpha 0 = use the theme color.
var custom_color: Color = Color(0, 0, 0, 0)
# True on a row that renders a LANGUAGE construct (a data-class holder, a methods-class, a host binding,
# a lifted switch case, a collapsed function...) rather than a regular ACE event. The renderer marks such
# rows with a quiet indigo left stripe + faint wash so the distinction is visible at a glance without
# dimming the row. Stamp via EventSheets.mark_language_block so custom blocks get the same cue for free.
var language_block: bool = false
# True on a row that DECLARES a variable (a sheet member, a tree variable, an event local, an
# Inspector-group strip over a run of them). The renderer washes those rows in the theme's flat
# variable tint and rules their left edge, so a declaration never reads as an event. View-only,
# never serialized.
var variable_row: bool = false
# V2. True on the LAST row of a block that a hairline closes - the globals this sheet only uses,
# separated from the variables it declares. A rule, not a row: it costs no height, so a block break
# never pushes the sheet down a line. View-only, never serialized.
var rule_below: bool = false
# K4. The condition LINE INDICES an "or" divider is drawn above - every line after the first when the
# event's conditions are OR'd. The word is drawn BETWEEN the two conditions rather than stamped on
# either of them, because "or" is what sits between two questions, not a property of one. View-only,
# never serialized; empty on an AND event, which is every event by default.
var or_condition_lines: PackedInt32Array = PackedInt32Array()

## Vertical presence multiplier (1.0 = normal). Header-like rows (state headers, the Class
## setup bar, Host binding) reserve extra height so they read as BARS, the way an event sheet's
## Includes strip does; content re-centers inside the taller rect at layout time.
var height_scale: float = 1.0
# True when the row DIRECTLY BELOW belongs to this one and must not be pushed away by the inter-block
# gap - a published verb's description caption and the verb row it describes read as one block. It also
# marks this row as STARTING that block, so the gap lands above the caption instead of between the
# caption and its verb. View-only, never serialized.
var attached_below: bool = false
# True on a row whose content spans BOTH lanes as one track (no divider, no action column). An
# event-sheet Function block header is the case it exists for: it carries the verb and its input chips
# and nothing else, so clipping those chips at the lane divider - with an empty right lane sitting
# beside them - wastes half the row. View-only, never serialized.
var full_width_lanes: bool = false
# True on a row rendered INSIDE a published verb's body. A sheet's own events run every frame, so a
# condition-less event reads as "Every Tick" there - but a verb's body runs when the verb is CALLED, so
# the same row must read "Always" instead. View-only, never serialized.
var in_verb_body: bool = false
# Which KIND of published verb this row's body belongs to (an EventSheetSentence.VerbKind). A `return`
# inside a published condition or expression reads "Set return value to x", and inside an
# action "Stop event" - and spans are built lazily, long after the walk that knew which verb this was,
# so the answer is carried on the row. View-only, never serialized.
var verb_kind: int = 0
# M23: the half-open range of the source event's ACTIONS this row draws. A statement carrying a
# ternary reads as a sub-event pair, which splits the event it lives in into the actions BEFORE the
# branch (this row), the branch rows, and the actions after (a continuation row) - so each of those
# rows renders its own slice of the one unchanged EventRow. -1 means "to the end". View-only, never
# serialized: the resource, the emitted GDScript and the byte round-trip are untouched.
var action_slice_from: int = 0
var action_slice_to: int = -1
# M23: true on the slice that carries the EVENT's own trailing furniture - its comment and the
# "+ Add condition" / "+ Add action" affordances. Normally that is the continuation after the last
# branch; when the branch IS the final action it is the head, so the scaffolding stays exactly where
# it sat before the pair existed instead of growing an empty row under every ternary. View-only.
var action_slice_tail: bool = false
# M23: true on the continuation row of such a split - its conditions were already drawn by the row
# the split began at, and an event sheet never repeats them. View-only, never serialized.
var conditions_hidden: bool = false
# M23: true on a row the ternary reading itself produced (a head slice, a branch row, a continuation),
# so a second pass over the same tree leaves it alone instead of branching it again. View-only.
var ternary_view: bool = false
# M23 (editable sheets): the row_uid of the ONE statement row every row of a pair stands for. The pair
# is a reading of a single statement, so selection, drag, delete and the gutter must all address it as
# one - and this is the single field they key on. "" on every row that is not part of such a reading.
# View-only, never serialized.
var ternary_anchor_uid: String = ""
# M23: true on the row a pair LEADS with (the head slice, or the first branch row when the head drew
# nothing). Exactly one row per pair carries it, which is the row the event number, the breakpoint dot,
# the bookmark pennant and the trace hit chip belong to - the others must draw no gutter marks at all.
var ternary_lead: bool = false
# M23: the index into the source event's `actions` of the statement a branch row reads, or -1. It is
# what routes a double-click anywhere on the pair (the condition cell and the Else row included) to
# that ONE line's existing editor. View-only, never serialized.
var ternary_action_index: int = -1
# M36: the object a For-each PICKS, and the muted note saying where they came from ("(group
# \"enemies\")"). Set on the row a loop-plus-one-`if` merged into, so its first condition line reads as
# a condition ON that object - which is what event-sheet picking looks like. Spans are built lazily,
# long after the walk that saw the loop, so the answer is carried on the row. View-only, never
# serialized: the loop and the `if` are two untouched rows in the sheet.
var picking_object: String = ""
var picking_note: String = ""


## The uid of the STATEMENT this row belongs to - its own, unless it is one row of a ternary pair, in
## which case every row of that pair answers with the same uid. Selection sets, drag payloads and the
## row->resource lookups are all keyed on this, so a pair counts once wherever rows are counted.
func statement_uid() -> String:
	return ternary_anchor_uid if not ternary_anchor_uid.is_empty() else row_uid
