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
var line_number: int = 0
var breakpoint_enabled: bool = false
var bookmark_enabled: bool = false
var disabled: bool = false
# Per-row custom tint (event-sheet-style colored comments); alpha 0 = use the theme color.
var custom_color: Color = Color(0, 0, 0, 0)
