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
var line_number: int = 0
var breakpoint_enabled: bool = false
var bookmark_enabled: bool = false
var disabled: bool = false
# Per-row custom tint (C3-style colored comments); alpha 0 = use the theme color.
var custom_color: Color = Color(0, 0, 0, 0)
