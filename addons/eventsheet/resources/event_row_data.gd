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
var children: Array[EventRowData] = []
var source_resource: Resource = null
var row_uid: String = ""
var debug_state: String = ""
