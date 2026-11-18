extends Node
## Reads the item table and writes the run's scores back out.

var items: Array = []


func _ready() -> void:
	items = (func(__path: String) -> Array:
			var __file: FileAccess = FileAccess.open(__path, FileAccess.READ)
			if __file == null:
				return []
			var __rows: Array = []
			var __columns: PackedStringArray = __file.get_csv_line(",")
			while not __file.eof_reached():
				var __cells: PackedStringArray = __file.get_csv_line(",")
				if __cells.size() == 1 and __cells[0].is_empty():
					continue
				var __record: Dictionary = {}
				for __column: int in mini(__columns.size(), __cells.size()):
					__record[__columns[__column]] = __cells[__column]
				__rows.append(__record)
			return __rows).call("res://data/items.csv")
	var __file_1 = FileAccess.open("user://scores.csv", FileAccess.WRITE)
	if __file_1:
		var __columns_1: PackedStringArray = PackedStringArray(items[0].keys()) if not items.is_empty() else PackedStringArray()
		__file_1.store_csv_line(__columns_1, ",")
		for __record_1: Dictionary in items:
			var __cells_1: PackedStringArray = PackedStringArray()
			for __column_1: String in __columns_1:
				__cells_1.append(str(__record_1.get(__column_1, "")))
			__file_1.store_csv_line(__cells_1, ",")
		__file_1.close()
	for line in FileAccess.get_file_as_string("user://run.log").split("\n"):
		print(line)
	$FileDialog.popup_centered()
