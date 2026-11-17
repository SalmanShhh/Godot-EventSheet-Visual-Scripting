# Godot EventSheets - the Drawing Prefab's picture is drawn off the main thread, once per frame at most.
#
# Every edit of a prefab (a move, a field, an add) used to draw the whole picture on the main thread before the
# editor could carry on, and a selection change drew it a second time. Now an edit only ASKS for a picture: any
# number of asks in one frame make one, and it is drawn on a worker thread from its own copy of the steps. What it
# draws is the very picture the main thread would have drawn - the same function, the same pixels - and what is
# saved and undone is untouched.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PICKING_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_picking.gd"
const PREVIEW_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_preview.gd"
const PANEL_PATH := "res://addons/eventsheet/editor/inspector/preview_panel.gd"
const P := "drawing_prefab_preview_async_test"


static func _steps(count: int, with_stamp: bool = false) -> Array:
	var kinds: Array = ["circle", "ring", "rect", "line", "cone", "arc", "pie", "rounded_rect", "regular_polygon"]
	var steps: Array = []
	for index: int in count:
		steps.append({"kind": kinds[index % kinds.size()], "x": float((index % 9) * 12 - 50), "y": float((index / 9) * 12 - 30),
			"p1": 7.0 + float(index % 6), "p2": 4.0 + float(index % 5), "p3": 3.0 + float(index % 4), "color": "#%02x%02x%02x" % [(index * 37) % 256, (index * 91) % 256, (index * 53) % 256]})
	if with_stamp:
		steps.append({"kind": "stamp", "x": 0.0, "y": 0.0, "p1": 1.0, "p2": 0.0, "texture": "res://eventsheet_addons/behavior.svg", "color": "white"})
	return steps


static func _prefab(steps: Array) -> Resource:
	var prefab: Resource = load("res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource.gd").new()
	prefab.set("steps", steps)
	return prefab


static func _data(texture: Texture2D) -> PackedByteArray:
	return texture.get_image().get_data()


static func run() -> bool:
	var table: Array = []
	var size: Vector2i = load(PANEL_PATH).RASTER_SIZE
	var background: Color = load(PANEL_PATH).BACKGROUND
	var prefab: Resource = _prefab(_steps(60))
	var picking: RefCounted = load(PICKING_PATH).new(prefab)

	# The picture a worker makes is the picture the main thread makes.
	var job: Callable = picking.call("render_job", prefab, size)
	var from_job: Image = job.call() as Image
	var from_main: Image = load(PREVIEW_PATH).call("rasterize", _steps(60), size, background, [])
	table.append(["the job makes the same pixels as the main-thread drawing", from_job.get_data() == from_main.get_data(), true])
	table.append(["at the card's size", from_job.get_size(), size])
	picking.set("_chosen", [3, 4])
	var chosen_job: Image = (picking.call("render_job", prefab, size) as Callable).call() as Image
	var chosen_main: Image = load(PREVIEW_PATH).call("rasterize", _steps(60), size, background, [3, 4])
	table.append(["with some shapes chosen it makes the quietened picture the main thread makes", chosen_job.get_data() == chosen_main.get_data(), true])
	table.append(["and that picture differs from the plain one", chosen_job.get_data() == from_job.get_data(), false])
	picking.set("_chosen", [])
	var with_stamp: Resource = _prefab(_steps(5, true))
	var stamp_picking: RefCounted = load(PICKING_PATH).new(with_stamp)
	table.append(["a prefab with a stamp is left to the main thread", (stamp_picking.call("render_job", with_stamp, size) as Callable).is_valid(), false])

	# Asks in one frame make one picture, on a worker.
	var panel: EventSheetInspectorPreviewPanel = EventSheetInspectorPreviewPanel.new(prefab, Callable(picking, "render"))
	var made: Array = [0]
	panel.set_image_maker(func(object: Object, wanted: Vector2i) -> Callable:
		made[0] += 1
		return picking.call("render_job", object, wanted))
	panel.refresh()
	var first: Texture2D = panel.preview_texture()
	table.append(["the card draws its first picture at once", first != null, true])
	for ask: int in 6:
		panel.request_refresh()
	panel.pump()
	table.append(["six asks in one frame start one picture", made[0], 1])
	panel.finish_pending()
	var second: Texture2D = panel.preview_texture()
	table.append(["the finished picture replaces the first", second != first, true])
	table.append(["and holds the pixels of the drawing", _data(second) == from_main.get_data(), true])

	# The picture is of the steps as they were when it was asked for.
	var steps: Array = (prefab.get("steps") as Array).duplicate(true)
	steps[0]["p1"] = 40.0
	prefab.set("steps", steps.duplicate(true))
	var asked_for: Image = load(PREVIEW_PATH).call("rasterize", steps.duplicate(true), size, background, [])
	panel.request_refresh()
	panel.pump()
	var later: Array = (prefab.get("steps") as Array).duplicate(true)
	later[1]["color"] = "#ffffff"
	prefab.set("steps", later)
	panel.finish_pending()
	table.append(["a change made while it is drawn does not leak into it", _data(panel.preview_texture()) == asked_for.get_data(), true])
	table.append(["and it is not the picture of the steps before the edit", _data(panel.preview_texture()) == from_main.get_data(), false])
	panel.request_refresh()
	panel.pump()
	panel.finish_pending()
	var latest: Image = load(PREVIEW_PATH).call("rasterize", prefab.get("steps"), size, background, [])
	table.append(["and the next ask draws the newest steps", _data(panel.preview_texture()) == latest.get_data(), true])

	# With no maker the picture is still made, once per frame, on the main thread.
	var plain: EventSheetInspectorPreviewPanel = EventSheetInspectorPreviewPanel.new(prefab, Callable(picking, "render"))
	plain.refresh()
	var before: Texture2D = plain.preview_texture()
	plain.request_refresh()
	plain.request_refresh()
	plain.pump()
	table.append(["a card with no maker draws on the main thread when it is pumped", plain.preview_texture() != before, true])
	var ok: bool = SUPPORT.pins(P, table)
	panel.free()
	plain.free()
	return ok
