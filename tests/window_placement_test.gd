# EventSheets - where a window the plugin opens lands (EventSheetWindowPlacement).
#
# The rect maths is pure, so every case is pinned here by value: a window near each edge and corner
# of a screen, an anchored popup that has to flip above its anchor or right-align to it, an oversize
# window that has to shrink, a second monitor at a negative and at a large offset, a title bar's
# reserve, an editor window half off screen, and the editor scale folded into the margin. The second
# half is the sweep: no file of the plugin may open a window with the engine's own popup functions,
# because they do not keep a plain Window or dialog on its screen - the one helper does.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "window_placement_test"
const W := preload("res://addons/eventsheet/editor/window_placement.gd")

## Files that name an engine popup call without opening a window with it, and why.
const SWEEP_OVERRIDES: Dictionary = {
	"res://addons/eventsheet/editor/window_placement.gd": "the helper itself: it is the one place that calls the engine",
	"res://addons/eventsheet/editor/interaction/sentence_grammar.gd": "words the reader sees for a game's own dialog, not a call",
	"res://addons/eventsheet/editor/interaction/viewport_row_builder.gd": "the sentence a row reads as for a game's own dialog, not a call",
	"res://addons/eventforge/registration/modules/file_aces.gd": "GDScript the compiler emits into a game, not the editor",
	"res://addons/eventforge/registration/modules/ui_aces.gd": "action templates compiled into a game's own dialogs, not the editor",
	"res://addons/eventsheet/editor/dock/states_dialog.gd": "re-shows a dialog the OK press just hid, in the place it already was",
}

## The engine calls that open a window without keeping it on its screen.
const BANNED: PackedStringArray = [".popup_centered(", ".popup_centered_ratio(", ".popup_centered_clamped(",
	".popup_on_parent(", ".popup_exclusive(", ".popup_exclusive_centered(", ".popup("]


static func run() -> bool:
	var screen: Rect2i = Rect2i(0, 0, 1920, 1040)
	var ok: bool = true
	ok = SUPPORT.pins(P, [
		# fit: slide in from every side, shrink an oversize window, leave one that fits alone.
		["fit leaves a window that fits", W.fit(Rect2i(100, 100, 400, 300), screen), Rect2i(100, 100, 400, 300)],
		["fit slides in from the right", W.fit(Rect2i(1800, 100, 400, 300), screen), Rect2i(1520, 100, 400, 300)],
		["fit slides in from the bottom", W.fit(Rect2i(100, 900, 400, 300), screen), Rect2i(100, 740, 400, 300)],
		["fit slides in from the left", W.fit(Rect2i(-200, 100, 400, 300), screen), Rect2i(0, 100, 400, 300)],
		["fit slides in from the top", W.fit(Rect2i(100, -50, 400, 300), screen), Rect2i(100, 0, 400, 300)],
		["fit slides in from the bottom-right corner", W.fit(Rect2i(1900, 1030, 400, 300), screen), Rect2i(1520, 740, 400, 300)],
		["fit shrinks an oversize window", W.fit(Rect2i(0, 0, 3000, 2000), screen), screen],
		["fit shrinks one side only", W.fit(Rect2i(500, 100, 3000, 300), screen), Rect2i(0, 100, 1920, 300)],
		["fit with no screen is no constraint", W.fit(Rect2i(-9, -9, 50, 50), Rect2i()), Rect2i(-9, -9, 50, 50)],
		# inset: a margin all round, a title bar's reserve along the top, never negative.
		["inset keeps a margin", W.inset(screen, 8), Rect2i(8, 8, 1904, 1024)],
		["inset reserves a title bar", W.inset(screen, 8, 32), Rect2i(8, 40, 1904, 992)],
		["inset never goes negative", W.inset(Rect2i(0, 0, 10, 10), 8, 32).size, Vector2i(0, 0)],
		# centred: the middle of what it opens over, fitted.
		["centred in the middle", W.centred(Vector2i(400, 300), Rect2i(0, 0, 1000, 800), screen), Rect2i(300, 250, 400, 300)],
		["centred over a window half off the left edge", W.centred(Vector2i(400, 300),
			W.visible_part(Rect2i(-600, 100, 1000, 800), screen), screen), Rect2i(0, 350, 400, 300)],
		["centred over a window off the right edge stays in", W.centred(Vector2i(600, 300),
			W.visible_part(Rect2i(1700, 100, 1000, 800), screen), screen), Rect2i(1320, 350, 600, 300)],
		["a window wholly off screen centres on the screen", W.visible_part(Rect2i(5000, 5000, 100, 100), screen), screen],
		["centred oversize shrinks to the screen", W.centred(Vector2i(4000, 3000), Rect2i(0, 0, 1920, 1040), screen), screen],
		# anchored: below and left-aligned; flips above; right-aligns; oversize still lands inside.
		["anchored below its anchor", W.anchored(Vector2i(200, 100), Rect2i(100, 100, 150, 24), screen), Rect2i(100, 124, 200, 100)],
		["anchored flips above at the bottom edge", W.anchored(Vector2i(200, 100), Rect2i(100, 1000, 150, 24), screen), Rect2i(100, 900, 200, 100)],
		["anchored right-aligns at the right edge", W.anchored(Vector2i(300, 100), Rect2i(1800, 100, 100, 24), screen), Rect2i(1600, 124, 300, 100)],
		["anchored flips and right-aligns in the bottom-right corner", W.anchored(Vector2i(300, 100),
			Rect2i(1800, 1000, 100, 24), screen), Rect2i(1600, 900, 300, 100)],
		["anchored takes the side with more room when neither fits", W.anchored(Vector2i(200, 900),
			Rect2i(100, 300, 150, 24), screen), Rect2i(100, 140, 200, 900)],
		["anchored too tall for either side still lands inside", W.anchored(Vector2i(200, 5000), Rect2i(100, 300, 150, 24), screen),
			Rect2i(100, 0, 200, 1040)],
		# at_point: a menu's corner on the pointer, flipping away from the right and bottom edges.
		["a menu at the pointer", W.at_point(Vector2i(180, 300), Vector2i(500, 400), screen), Rect2i(500, 400, 180, 300)],
		["a menu at the pointer flips left at the right edge", W.at_point(Vector2i(180, 300), Vector2i(1900, 400), screen),
			Rect2i(1720, 400, 180, 300)],
		["a menu at the pointer flips up at the bottom edge", W.at_point(Vector2i(180, 300), Vector2i(500, 1030), screen),
			Rect2i(500, 730, 180, 300)],
		["a menu at the bottom-right corner flips both ways", W.at_point(Vector2i(180, 300), Vector2i(1915, 1035), screen),
			Rect2i(1735, 735, 180, 300)],
		["a menu at the top-left corner stays put", W.at_point(Vector2i(180, 300), Vector2i(0, 0), screen), Rect2i(0, 0, 180, 300)],
	]) and ok
	ok = _second_monitor(screen) and ok
	ok = _scale(screen) and ok
	ok = _blend_strip() and ok
	ok = _oversize_dialog() and ok
	ok = _sweep() and ok
	return ok


## Two monitors: one to the left of the primary (negative x), one far to the right and lower. A window
## belongs to the screen holding most of it; the maths then runs against THAT screen's usable rect.
static func _second_monitor(primary: Rect2i) -> bool:
	var left: Rect2i = Rect2i(-1600, 100, 1600, 860)
	var right: Rect2i = Rect2i(1920, 300, 2560, 1380)
	var usables: Array = [primary, left, right]
	var on_left: Rect2i = W.screen_of(Rect2i(-1200, 200, 800, 600), usables)
	var on_right: Rect2i = W.screen_of(Rect2i(2000, 400, 800, 600), usables)
	var straddling: Rect2i = W.screen_of(Rect2i(1700, 400, 400, 300), usables)
	var nowhere: Rect2i = W.screen_of(Rect2i(-3000, 5000, 100, 100), usables)
	return SUPPORT.pins(P + " (second monitor)", [
		["a window on the left monitor belongs to it", on_left, left],
		["a window on the right monitor belongs to it", on_right, right],
		["a window straddling two screens belongs to the one with most of it", straddling, primary],
		["a window on no screen belongs to the nearest", nowhere, left],
		["no screens answers an empty rect", W.screen_of(Rect2i(0, 0, 10, 10), []), Rect2i()],
		["a popup at the left monitor's left edge stays on it", W.at_point(Vector2i(200, 200), Vector2i(-1590, 150), left),
			Rect2i(-1590, 150, 200, 200)],
		["a popup near the left monitor's right edge flips left, onto that monitor", W.at_point(Vector2i(200, 200),
			Vector2i(-20, 150), left), Rect2i(-220, 150, 200, 200)],
		["a popup near the right monitor's bottom flips up, onto that monitor", W.at_point(Vector2i(200, 200),
			Vector2i(2400, 1670), right), Rect2i(2400, 1470, 200, 200)],
		["a dialog too wide for the left monitor shrinks to it", W.centred(Vector2i(2000, 400), Rect2i(-1600, 100, 1600, 860), left),
			Rect2i(-1600, 330, 1600, 400)],
	])


## Editor scale folds into the margin and the title bar's reserve, so a 200% editor keeps twice the
## gap: the same maths, a bigger inset, and the margin helper agrees with the palette's scale.
static func _scale(screen: Rect2i) -> bool:
	var one: Rect2i = W.inset(screen, 8, 32)
	var two: Rect2i = W.inset(screen, 16, 64)
	return SUPPORT.pins(P + " (scale)", [
		["twice the scale keeps twice the margin on the left", two.position.x, one.position.x * 2],
		["twice the scale reserves twice the title bar", two.position.y - 16, (one.position.y - 8) * 2],
		["a dialog at 200% still fits the room it has", W.fit(Rect2i(0, 0, 3000, 900), two).size.x, two.size.x],
		["the scaled margin follows the palette", W._margin(true), int(EventSheetPalette.scaled_f(float(W.EDGE_MARGIN)))],
		["a window with no title bar has no margin", W._margin(false), 0],
	])


## The blend-mode strip's content must not ask for more room than a screen has: its wrapping shelves
## used to report a height of two screens before their first layout, and no placement can fit that.
static func _blend_strip() -> bool:
	var field: LineEdit = load("res://addons/eventsheet/editor/blend_mode_field.gd").new()
	var strip: PopupPanel = field.call("_build_strip")
	var least: Vector2i = Vector2i(strip.get_contents_minimum_size().ceil())
	strip.free()
	field.free()
	return SUPPORT.pins(P + " (blend strip)", [
		["the strip asks for a bounded height", least.y <= int(EventSheetPalette.scaled_f(600.0)), true],
		["the strip asks for a real width", least.x >= int(EventSheetPalette.scaled_f(300.0)), true],
	])


## A dialog whose content is bigger than its room is never scaled down: it is clamped to the room and
## its body scrolls, the button row staying inside the room. A dialog that fits is left alone, and one
## opened again in a bigger room gets its whole content back.
static func _oversize_dialog() -> bool:
	var room: Rect2i = Rect2i(0, 0, 700, 500)
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	var form: VBoxContainer = VBoxContainer.new()
	var tall: Control = Control.new()
	tall.custom_minimum_size = Vector2(1600, 1500)
	form.add_child(tall)
	dialog.add_child(EventSheetPopupUI.margined(form))
	var natural: Vector2i = Vector2i(dialog.get_contents_minimum_size().ceil())
	W.fit_bodies(dialog, Rect2i(0, 0, 5000, 5000))
	var untouched: bool = W.body_scrolls(dialog).is_empty()
	W.fit_bodies(dialog, room)
	var scrolls: Array = W.body_scrolls(dialog)
	var scroll: ScrollContainer = scrolls[0] if not scrolls.is_empty() else null
	var content_min: Vector2 = scroll.get_child(0).get_combined_minimum_size() if scroll != null else Vector2.ZERO
	# A control outside the tree keeps its first measured minimum, so the window's own minimum is
	# rebuilt from the parts: its chrome (the unwrapped minimum less the body) plus the body's least.
	var chrome: Vector2i = natural - Vector2i(content_min.ceil())
	var viewport_min: Vector2 = scroll.custom_minimum_size if scroll != null else Vector2.ZERO
	var squeezed: Vector2i = chrome + Vector2i(viewport_min.ceil())
	var button_row: float = dialog.get_ok_button().get_combined_minimum_size().y
	W.fit_bodies(dialog, Rect2i(0, 0, 5000, 5000))
	var restored: Vector2 = scroll.custom_minimum_size if scroll != null else Vector2.ZERO
	var result: bool = SUPPORT.pins(P + " (oversize dialog)", [
		["a dialog that fits is not wrapped", untouched, true],
		["an oversize dialog gets one scrolling body", scrolls.size(), 1],
		["its least width fits the room", squeezed.x <= room.size.x, true],
		["its least height fits the room, button row included", squeezed.y <= room.size.y, true],
		["the button row is part of what fits", button_row > 0.0 and squeezed.y >= int(button_row), true],
		["its text is never scaled", dialog.content_scale_factor, 1.0],
		["the body is taller than its view, so it scrolls to reveal the last control", content_min.y > viewport_min.y, true],
		["the body is wider than its view, so it can scroll sideways when it must", content_min.x > viewport_min.x, true],
		["in a bigger room the whole content comes back", restored, content_min],
	])
	dialog.free()
	return result


## No file of the plugin may open a window with an engine popup call. A window that lands by the
## engine's rules alone can open with its title bar or its buttons off screen; EventSheetWindowPlacement
## keeps it inside the usable rect of its screen. The detectors are pinned first, on text: a sweep that
## matched nothing would look as clean as a clean tree.
static func _sweep() -> bool:
	var ok: bool = SUPPORT.pins(P + " (sweep detectors)", [
		["a direct popup_centered is caught", _offence("\tdialog.popup_centered(Vector2i(1, 1))"), true],
		["a direct popup is caught", _offence("\tmenu.popup(Rect2i(Vector2i.ZERO, Vector2i.ZERO))"), true],
		["a popup_on_parent is caught", _offence("\t_strip.popup_on_parent(Rect2i())"), true],
		["a file browser left unchecked is caught", _unchecked_browser(["\tbrowser.popup_file_dialog()", "\tpass"], 0), true],
		["a file browser kept on screen is not", _unchecked_browser(["\tbrowser.popup_file_dialog()",
			"\tEventSheetWindowPlacement.keep_on_screen(browser)"], 0), false],
		["a call through the helper is not", _offence("\tEventSheetWindowPlacement.popup_centered(dialog)"), false],
		["a get_popup() read is not", _offence("\tvar menu: PopupMenu = button.get_popup()"), false],
		["a comment is not", _offence("\t# the dialog's popup_centered() call"), false],
		["popup_at on the helper is not", _offence("\tEventSheetWindowPlacement.popup_at(menu, point)"), false],
	])
	var offenders: PackedStringArray = PackedStringArray()
	var scanned: int = 0
	for path: String in _plugin_sources():
		if SWEEP_OVERRIDES.has(path):
			continue
		scanned += 1
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in lines.size():
			if _offence(lines[index]) or _unchecked_browser(lines, index):
				offenders.append("%s:%d" % [path.trim_prefix("res://addons/"), index + 1])
	ok = SUPPORT.check(P, "the sweep read the plugin's sources", scanned > 300, true) and ok
	ok = SUPPORT.check(P, "no file opens a window with an engine popup call", offenders, PackedStringArray()) and ok
	return ok


## True when `line` opens a window with an engine call instead of the helper.
static func _offence(line: String) -> bool:
	var code: String = line.strip_edges()
	if code.begins_with("#") or code.contains("EventSheetWindowPlacement."):
		return false
	for banned: String in BANNED:
		if code.contains(banned):
			return true
	return false


## True when `lines[index]` opens an engine file browser (which centres itself and clamps its size, but
## not to the screen the editor window is on) and the next line does not pull it back on screen.
static func _unchecked_browser(lines: Variant, index: int) -> bool:
	if not lines[index].contains(".popup_file_dialog(") or lines[index].strip_edges().begins_with("#"):
		return false
	return index + 1 >= lines.size() or not lines[index + 1].contains("EventSheetWindowPlacement.keep_on_screen(")


static func _plugin_sources() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pending: PackedStringArray = PackedStringArray(["res://addons/eventsheet", "res://addons/eventforge"])
	while not pending.is_empty():
		var dir_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		for name: String in DirAccess.get_directories_at(dir_path):
			pending.append(dir_path.path_join(name))
		for name: String in DirAccess.get_files_at(dir_path):
			if name.ends_with(".gd"):
				found.append(dir_path.path_join(name))
	found.sort()
	return found
