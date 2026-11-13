@tool
class_name EventSheetRowLayoutCache
extends RefCounted

var _entries: Dictionary = {}
## The keys stored for each flat row index, so a change that moves a few rows drops only their layouts.
var _keys_by_row: Dictionary = {}
var _width: float = -1.0


func reset(width: float) -> void:
	if is_equal_approx(_width, width):
		return
	_width = width
	clear()


func clear() -> void:
	_entries.clear()
	_keys_by_row.clear()


func has(key: String) -> bool:
	return _entries.has(key)


func get_layout(key: String) -> Dictionary:
	return _entries.get(key, {})


func store(key: String, layout: Dictionary, row_index: int = -1) -> void:
	_entries[key] = layout
	if row_index >= 0:
		if not _keys_by_row.has(row_index):
			_keys_by_row[row_index] = []
		(_keys_by_row[row_index] as Array).append(key)


## Drops the layouts of rows `first` to `last` (flat indices) and keeps every other row's. A layout
## stored without a row index cannot be told apart, so a cache holding any clears whole.
func erase_rows(first: int, last: int) -> void:
	if _entries.size() > _count_indexed():
		clear()
		return
	for row_index: Variant in _keys_by_row.keys():
		if int(row_index) < first or int(row_index) > last:
			continue
		for key: Variant in _keys_by_row[row_index]:
			_entries.erase(key)
		_keys_by_row.erase(row_index)


func _count_indexed() -> int:
	var count: int = 0
	for keys: Variant in _keys_by_row.values():
		count += (keys as Array).size()
	return count


## How many layouts are held, for the tests.
func size() -> int:
	return _entries.size()
