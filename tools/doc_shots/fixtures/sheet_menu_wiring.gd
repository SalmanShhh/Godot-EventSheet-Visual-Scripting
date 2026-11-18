extends Node

var on_done: Callable = Callable(self, "handle_done")


func wire_up(menu) -> void:
	menu.open_sheet = open_sheet_in_workspace
	call_deferred("refresh_after_edit")


func finish(result) -> void:
	if on_done.is_valid():
		on_done.call(result)


func tidy_lists(rows: Array) -> void:
	var names = rows.map(func(r): return r.name)
	var ready_rows = rows.filter(func(r): return r.ready)
	print(names, ready_rows)


func open_sheet_in_workspace() -> void:
	pass


func handle_done(r) -> void:
	pass


func refresh_after_edit() -> void:
	pass
