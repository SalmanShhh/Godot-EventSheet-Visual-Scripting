extends Control

var registry: EventSheetACERegistry = null
var find_bar: LineEdit = null


func refresh() -> void:
	registry.get_all_definitions()
	find_bar.clear()
