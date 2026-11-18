extends Node

var row_index: int = 0
var span_index: int = 0
var kind: String = ""
var source: Object = null
var edits: Array = []
var condition_object_column_width: int = 220
var action_object_column_width: int = 320


func selection_snapshot() -> Dictionary:
	return {
		"row_index": row_index,
		"span_index": span_index,
		"kind": kind,
		"source_resource": source,
	}


func request_replace(path: String) -> void:
	edits.append({
		"mode": "replace",
		"path": path,
	})


func column_widths() -> void:
	var widths: Array = [
		condition_object_column_width,
		action_object_column_width,
	]
	print(widths)
