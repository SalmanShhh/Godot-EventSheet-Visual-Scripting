@tool
extends RefCounted
# Godot EventSheets - the HEAD of a sheet as one class head, and the blocks under it: who includes a
# shared sheet, the variables an included sheet brings with it, which variables hold an inner class,
# and the paint for the rounded Include bar and the inner-class block.
#
# The facts here are READ, never stored: a shared sheet's includers come from walking the project's
# scripts, an included sheet's variables from its own file, a class's users from the open sheet's
# own variable rows. Each file answer is cached - the walk for a few seconds, a file's answer until
# the file changes on disk or the editor's filesystem ping drops it - because the row build asks
# them on every rebuild and the head must not make a rebuild pay for a scan.
#
# The paint is PAINT ONLY, like the other native marks: a rounded bar and a block frame are drawn
# over the geometry a row already has, reserve no width and are never hit-tested.

## How long one walk of the project for a shared sheet's includers is trusted. Long enough that a
## burst of rebuilds (typing, folding) pays for one walk; short enough that saving an includer shows
## in the head of the shared sheet a moment later.
const INCLUDERS_TRUST_MSEC := 15000

## The folders a walk for includers never enters: the engine's own cache, and the plugin's code,
## which includes no game sheet.
const SKIPPED_FOLDERS: PackedStringArray = ["res://.godot", "res://addons"]

## The rounded Include bar's edge width and its inset from the row, so two bars one above the other
## keep a gap between them.
const BAR_EDGE := 2.0
const BAR_INSET := 2.0

## The inner-class block's edge width.
const BLOCK_EDGE := 2.0

## The two-line group head draws its on/off switch with the variable rows' own tick box.
const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")

static var _includers_cache: Dictionary = {}
static var _file_cache: Dictionary = {}
static var _include_cache: Dictionary = {}
static var _bar_box_cache: Dictionary = {}
static var _declaration_re: RegEx = null


## The shared-sheet wiring a script file declares ("base_class", "helper"), or "" for a file that is
## not a shared sheet. Read off the file on disk, once per version of the file.
static func shared_wiring(path: String) -> String:
	return str(_file_facts(path).get("wiring", ""))


## The display names of the scripts that include the shared sheet at `shared_path`, sorted: the
## class each declares, or its file name when it declares none. Empty for a sheet nothing includes.
static func includers_of(shared_path: String) -> PackedStringArray:
	if shared_path.is_empty():
		return PackedStringArray()
	var cached: Variant = _includers_cache.get(shared_path)
	if cached is Dictionary and Time.get_ticks_msec() - int((cached as Dictionary)["at"]) < INCLUDERS_TRUST_MSEC:
		return (cached as Dictionary)["names"]
	var names: PackedStringArray = PackedStringArray()
	if not str(_file_facts(shared_path).get("class", "")).is_empty():
		var scripts: PackedStringArray = PackedStringArray()
		_collect_scripts("res://", scripts)
		for script_path: String in scripts:
			if script_path == shared_path:
				continue
			var facts: Dictionary = _include_facts(script_path)
			if (facts["paths"] as PackedStringArray).has(shared_path):
				names.append(str(facts["name"]))
	names.sort()
	_includers_cache[shared_path] = {"at": Time.get_ticks_msec(), "names": names}
	return names


## Forgets every cached walk and every file's answers, so the next question reads again. The dock
## calls it on the editor's filesystem ping: a file's includes name OTHER files (the class it
## extends, the helper it makes), so a file can go stale without its own stamp moving.
static func forget_includers() -> void:
	_includers_cache.clear()
	_include_cache.clear()
	_file_cache.clear()


## The variables a script file declares at its top level, in file order, as {name, type, value}:
## what an including sheet can use. A name starting with `_` is the script's own business and is
## left out. The type is the one written, or the one a `:=` literal makes ("" when neither says).
static func shared_variables(path: String) -> Array[Dictionary]:
	var found: Variant = _file_facts(path).get("variables", [])
	var typed: Array[Dictionary] = []
	for entry: Variant in found as Array:
		typed.append(entry as Dictionary)
	return typed


## The variables of the sheet at `path` that hold `inner_class` - one value of it, or a list of them
## - as the words "Settings (a variable)", "Waves (a list)".
static func class_users(path: String, inner_class: String) -> PackedStringArray:
	var users: PackedStringArray = PackedStringArray()
	if inner_class.is_empty():
		return users
	for variable: Dictionary in shared_variables(path) + _private_variables(path):
		var type_text: String = str(variable["type"]).replace(" ", "")
		if type_text == inner_class:
			users.append(EventSheetL10n.translate("%s (a variable)") % str(variable["name"]))
		elif type_text == "Array[%s]" % inner_class:
			users.append(EventSheetL10n.translate("%s (a list)") % str(variable["name"]))
	return users


## The same answer for a sheet that is OPEN: read off the variable rows it holds in memory, so the
## line under an inner class follows an edit straight away rather than waiting for a save, and an
## unsaved sheet answers too. A `:=` variable says the type its value makes, as in a file.
static func class_users_in_sheet(sheet: EventSheetResource, inner_class: String) -> PackedStringArray:
	var users: PackedStringArray = PackedStringArray()
	if sheet == null or inner_class.is_empty():
		return users
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable == null or variable.name.is_empty():
			continue
		var type_text: String = variable.type_name.replace(" ", "")
		if (type_text.is_empty() or type_text == "Variant") and variable.default_value is String:
			type_text = _literal_type(str(variable.default_value).strip_edges())
		if type_text == inner_class:
			users.append(EventSheetL10n.translate("%s (a variable)") % variable.name)
		elif type_text == "Array[%s]" % inner_class:
			users.append(EventSheetL10n.translate("%s (a list)") % variable.name)
	return users


## The top-level declarations of one line of source, {name, type, value}, or {} when the line is not
## one. Public so a test can pin the reading of a line without a file.
static func declaration_of(line: String) -> Dictionary:
	if line.is_empty() or line[0] == "\t" or line[0] == " ":
		return {}
	if _declaration_re == null:
		_declaration_re = RegEx.create_from_string(
			"^(?:@\\w+(?:\\([^)]*\\))?\\s+)*var\\s+([A-Za-z_]\\w*)\\s*(?::\\s*([A-Za-z_][\\w.\\[\\], ]*?))?\\s*(?:(:=|=)\\s*(.+?))?\\s*$")
	var hit: RegExMatch = _declaration_re.search(line.split(" #")[0].strip_edges(false, true))
	if hit == null:
		return {}
	var value: String = hit.get_string(4).strip_edges()
	var type_text: String = hit.get_string(2).strip_edges()
	if type_text.is_empty() and hit.get_string(3) == ":=":
		type_text = _literal_type(value)
	return {"name": hit.get_string(1), "type": type_text, "value": value}


## Paints a rounded bar inside `row_rect`: `fill` inside an edge of `edge`, its corners rounded by
## `radius` (never more than half the bar's height, which is the pill end of the bar).
static func draw_rounded_bar(control: Control, row_rect: Rect2, fill: Color, edge: Color, radius: float) -> void:
	var bar: Rect2 = row_rect.grow_individual(-BAR_INSET, -BAR_INSET, -BAR_INSET, -BAR_INSET)
	if bar.size.x <= 0.0 or bar.size.y <= 0.0:
		return
	# One box per fill, edge and corner (a handful per theme), so a frame allocates nothing.
	var corner: int = int(minf(radius, bar.size.y * 0.5))
	var key: String = "%s/%s/%d" % [fill.to_html(), edge.to_html(), corner]
	var box: StyleBoxFlat = _bar_box_cache.get(key)
	if box == null:
		box = StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = edge
		box.set_border_width_all(int(BAR_EDGE))
		box.set_corner_radius_all(corner)
		box.anti_aliasing = true
		box.set_content_margin_all(0)
		_bar_box_cache[key] = box
	control.draw_style_box(box, bar)


## The word the two-line group head's switch says beside its tick box.
static func active_word() -> String:
	return EventSheetL10n.translate("Active")


## The room the switch takes on a two-line group head: the tick box, its gap and the word. The row
## builder reserves exactly this, and the painter draws into it.
static func active_tick_width(font: Font, font_size: int) -> float:
	var word: float = 40.0
	if font != null:
		word = font.get_string_size(active_word(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return NativeVariableMarks.TICK_BOX + NativeVariableMarks.TICK_GAP + ceilf(word) + 2.0


## Paints the switch as the design draws it: a tick box, filled and ticked while the group is
## active, and the word Active beside it - full ink when on, `muted` when off.
static func draw_active_tick(control: CanvasItem, rect: Rect2, active: bool, font: Font, font_size: int,
		fill: Color, frame: Color, ink: Color, muted: Color) -> void:
	if font == null:
		return
	var advance: float = NativeVariableMarks.draw_tick_box(control, rect.position.x, rect.get_center().y,
		active, fill, frame)
	var baseline: float = rect.get_center().y + float(font_size) * 0.35
	control.draw_string(font, Vector2(rect.position.x + advance, baseline), active_word(),
		HORIZONTAL_ALIGNMENT_LEFT, maxf(rect.size.x - advance, 1.0), font_size, ink if active else muted)


## Where a block's frame is drawn on one of its rows: from the head row's indent to the row's right
## edge, the full height of the row.
static func block_frame_rect(row_rect: Rect2, gutter_rect: Rect2, frame_indent: int, indent_width: int) -> Rect2:
	var left: float = maxf(gutter_rect.end.x, row_rect.position.x) + float(frame_indent * indent_width) + 2.0
	return Rect2(left, row_rect.position.y, maxf(row_rect.end.x - left - 2.0, 0.0), row_rect.size.y)


## Paints one row's part of a block: the block's fill, its two side edges, and a top or bottom edge
## where the row opens or closes the block.
static func draw_block_frame(control: Control, row_data: EventRowData, frame: Rect2) -> void:
	if frame.size.x <= 0.0:
		return
	if row_data.frame_fill.a > 0.01:
		control.draw_rect(frame, row_data.frame_fill, true)
	var ink: Color = row_data.frame_color
	control.draw_rect(Rect2(frame.position, Vector2(BLOCK_EDGE, frame.size.y)), ink, true)
	control.draw_rect(Rect2(Vector2(frame.end.x - BLOCK_EDGE, frame.position.y), Vector2(BLOCK_EDGE, frame.size.y)), ink, true)
	if row_data.frame_top:
		control.draw_rect(Rect2(frame.position, Vector2(frame.size.x, BLOCK_EDGE)), ink, true)
	# A closed block is its head row alone, so the head closes it.
	if row_data.frame_bottom or (row_data.frame_top and row_data.folded):
		control.draw_rect(Rect2(Vector2(frame.position.x, frame.end.y - BLOCK_EDGE), Vector2(frame.size.x, BLOCK_EDGE)), ink, true)


## One file's facts, read once per version of the file: whether it is a shared sheet and of which
## wiring, the class it declares, and its top-level variables split into the ones an includer can
## use and the script's own.
static func _file_facts(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var stamp: int = FileAccess.get_modified_time(path)
	var cached: Variant = _file_cache.get(path)
	if cached is Dictionary and int((cached as Dictionary)["stamp"]) == stamp:
		return cached
	var source: String = FileAccess.get_file_as_string(path)
	var public_variables: Array = []
	var private_variables: Array = []
	for line: String in source.split("\n"):
		var declared: Dictionary = declaration_of(line)
		if declared.is_empty():
			continue
		if str(declared["name"]).begins_with("_"):
			private_variables.append(declared)
		else:
			public_variables.append(declared)
	var facts: Dictionary = {
		"stamp": stamp,
		"wiring": EventSheetSharedSheets.wiring_of(source),
		"class": EventSheetSharedSheets.class_name_of(source),
		"variables": public_variables,
		"private_variables": private_variables,
	}
	_file_cache[path] = facts
	return facts


static func _private_variables(path: String) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for entry: Variant in _file_facts(path).get("private_variables", []) as Array:
		typed.append(entry as Dictionary)
	return typed


## The shared sheets a script file includes, as their paths, and what the file is called on a head
## (its class, or its file name read as words), read once per version of the file - so a walk that
## finds nothing changed only stats each file. Kept apart from `_file_facts` so a walk never pays
## for reading every file's variables.
static func _include_facts(path: String) -> Dictionary:
	var stamp: int = FileAccess.get_modified_time(path)
	var cached: Variant = _include_cache.get(path)
	if cached is Dictionary and int((cached as Dictionary)["stamp"]) == stamp:
		return cached
	var source: String = FileAccess.get_file_as_string(path)
	var paths: PackedStringArray = PackedStringArray()
	for include: Dictionary in EventSheetSharedSheets.includes_of_source(source):
		paths.append(str(include["path"]))
	var declared: String = EventSheetSharedSheets.class_name_of(source)
	var facts: Dictionary = {
		"stamp": stamp,
		"paths": paths,
		"name": declared if not declared.is_empty() else path.get_file().get_basename().capitalize(),
	}
	_include_cache[path] = facts
	return facts


## The type a `:=` literal gives a variable, "" when the literal does not say.
static func _literal_type(value: String) -> String:
	if value == "true" or value == "false":
		return "bool"
	if value.is_valid_int():
		return "int"
	if value.is_valid_float():
		return "float"
	if value.begins_with("\"") or value.begins_with("'"):
		return "String"
	# `Thing.new()` and `Vector2(…)` both say the type they make: the class before `.new`, or the
	# capitalised name being called.
	var call: String = value.get_slice("(", 0).trim_suffix(".new")
	if value.contains("(") and not call.is_empty() and not call.contains(".") \
			and call.substr(0, 1) == call.substr(0, 1).to_upper():
		return call
	return ""


## Every `.gd` under `folder`, sorted, skipping the folders no game sheet lives in.
static func _collect_scripts(folder: String, into: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return
	var subfolders: PackedStringArray = dir.get_directories()
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file_name: String in files:
		if file_name.get_extension() == "gd":
			into.append(folder.path_join(file_name))
	subfolders.sort()
	for sub: String in subfolders:
		var sub_path: String = folder.path_join(sub)
		if sub.begins_with(".") or SKIPPED_FOLDERS.has(sub_path):
			continue
		_collect_scripts(sub_path, into)
