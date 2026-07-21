@tool
class_name EventRowData
extends Resource

enum RowType {
EVENT,
GROUP,
COMMENT,
SECTION
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
# The C3-style stable event number (1-based, sheet order through groups and sub-events);
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
# True when the row DIRECTLY BELOW belongs to this one and must not be pushed away by the inter-block
# gap - a published verb's description caption and the verb row it describes read as one block. It also
# marks this row as STARTING that block, so the gap lands above the caption instead of between the
# caption and its verb. View-only, never serialized.
var attached_below: bool = false
