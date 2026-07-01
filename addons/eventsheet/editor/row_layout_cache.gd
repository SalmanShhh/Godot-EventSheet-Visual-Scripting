@tool
class_name RowLayoutCache
extends RefCounted

var _entries: Dictionary = {}
var _width: float = -1.0

func reset(width: float) -> void:
	if is_equal_approx(_width, width):
		return
	_width = width
	_entries.clear()

func clear() -> void:
	_entries.clear()

func has(key: String) -> bool:
	return _entries.has(key)

func get_layout(key: String) -> Dictionary:
	return _entries.get(key, {})

func store(key: String, layout: Dictionary) -> void:
	_entries[key] = layout
