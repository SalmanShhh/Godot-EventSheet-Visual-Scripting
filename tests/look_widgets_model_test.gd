@tool
class_name LookWidgetsModelTest
extends RefCounted

## The model-level rules of four Inspector parts: a wide part put under a row's first line, the
## swatch row's chosen colour, the min-max pair's clamp, and the corners' link beside the first line.

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _under_field() and ok
	ok = _swatches() and ok
	ok = _min_max() and ok
	ok = _corner_link() and ok
	return ok


static func _under_field() -> bool:
	# An EditorProperty can only be built inside the editor, so the rule that places the wide part
	# is a static the look calls, and it is held here on its own.
	return SUPPORT.pins("look_widgets_model_test", [
		["the wide part starts where the value column starts", EventSheetInspectorLook.under_field_margin(300.0, 120.0), 180],
		["a first row with no width yet leaves no margin", EventSheetInspectorLook.under_field_margin(300.0, 0.0), 0],
		["a first row wider than the row never gives a negative margin", EventSheetInspectorLook.under_field_margin(100.0, 160.0), 0],
	])


static func _swatches() -> bool:
	var row: EventSheetDrawerWidgets.DrawerSwatchRow = EventSheetDrawerWidgets.DrawerSwatchRow.new()
	var first_preset: Color = Color.html(EventSheetDrawerWidgets.SWATCH_PRESET_HTML[0])
	row.set_value(first_preset)
	var rows: Array = [
		["a preset colour marks its own swatch", row.chosen_index(), 0],
		["every preset has a swatch and one picker follows them", row.get_child_count(), EventSheetDrawerWidgets.SWATCH_PRESET_HTML.size() + 1],
	]
	row.set_value(Color(0.123, 0.456, 0.789))
	rows.append(["a colour that is no preset marks no swatch", row.chosen_index(), -1])
	rows.append(["the value read back is the one set", row.get_value(), Color(0.123, 0.456, 0.789)])
	rows.append(["one line needs a click target for every swatch and the picker", row.width_for_one_line() > 0.0, true])
	row.free()
	return SUPPORT.pins("look_widgets_model_test", rows)


static func _min_max() -> bool:
	var slider: EventSheetDrawerWidgets.DrawerMinMaxSlider = EventSheetDrawerWidgets.DrawerMinMaxSlider.new(0.0, 10.0)
	slider.set_value(Vector2(12.0, -3.0))
	var rows: Array = [
		["a pair set outside the range is clamped and put in order", slider.get_value(), Vector2(0.0, 10.0)],
	]
	slider.set_value(Vector2(7.0, 2.0))
	rows.append(["a pair given high-first is put low-first", slider.get_value(), Vector2(2.0, 7.0)])
	slider.call("_on_low_typed", 9.0)
	rows.append(["the low end typed past the high end stops at it", slider.get_value(), Vector2(7.0, 7.0)])
	slider.call("_on_high_typed", 1.0)
	rows.append(["the high end typed under the low end stops at it", slider.get_value(), Vector2(7.0, 7.0)])
	slider.call("_on_high_typed", 99.0)
	rows.append(["the high end typed past the range stops at the range end", slider.get_value(), Vector2(7.0, 10.0)])
	slider.free()
	return SUPPORT.pins("look_widgets_model_test", rows)


static func _corner_link() -> bool:
	var corners: EventSheetDrawerWidgets.DrawerCorners = EventSheetDrawerWidgets.DrawerCorners.new()
	corners.size = Vector2(1000.0, 100.0)
	corners.call("_arrange")
	var rows: Array = [
		["room for two to a line puts the link beside the first line of fields", corners.link_beside_first_field(), true],
		["room for two to a line leaves the head line unused", corners.head_holds_link(), false],
	]
	corners.size = Vector2(60.0, 100.0)
	corners.call("_arrange")
	rows.append(["fields stacked, the link still sits on the first line of fields", corners.link_beside_first_field(), true])
	rows.append(["fields stacked, the link shares the first field's line", corners.head_holds_link(), true])
	corners.size = Vector2(1000.0, 100.0)
	corners.call("_arrange")
	rows.append(["widening again brings the link back to the first line", corners.link_beside_first_field() and not corners.head_holds_link(), true])
	corners.set_value(Vector4(1.0, 2.0, 3.0, 4.0))
	rows.append(["four different corners come up unlinked", corners.is_linked(), false])
	rows.append(["four equal corners count as uniform", EventSheetDrawerWidgets.DrawerCorners.is_uniform(Vector4(5.0, 5.0, 5.0, 5.0)), true])
	corners.free()
	return SUPPORT.pins("look_widgets_model_test", rows)
