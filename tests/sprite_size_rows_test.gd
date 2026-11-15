# Godot EventSheets - a sprite is sized by the frame it draws.
#
# Pins, by VALUE: Set Size, Set Width and Set Height write the scale that makes the DRAWN frame (the
# whole picture, one cell of a sprite sheet, or the region) the size named, so Width and Height read
# back the number that was set; a sprite with no picture is left as it is; On node measures the other
# sprite, not this one. The old Set Sprite Size keeps its id and its line byte for byte, is retired
# from the picker, and Migrate moves a row of it onto Set Size.
@tool
class_name SpriteSizeRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const LIFTER := preload("res://addons/eventforge/importer/ace_lifter.gd")
const NAME: String = "sprite_size_rows_test"


static func run() -> bool:
	var passed: bool = true
	# First, before anything else here plans a row, so the folder is seen before the plan's first write.
	passed = _the_plan_writes_no_file() and passed
	passed = _the_rows() and passed
	passed = _the_lines_they_write() and passed
	passed = _the_old_row_is_retired() and passed
	passed = _a_file_round_trips() and passed
	passed = _the_sizes_come_out_right() and passed
	return passed


static func _descriptor(ace_id: String) -> ACEDescriptor:
	return ACERegistry.find_descriptor("Core", ace_id)


static func _template(ace_id: String) -> String:
	var descriptor: ACEDescriptor = _descriptor(ace_id)
	return descriptor.codegen_template if descriptor != null else "(missing)"


static func _param_ids(ace_id: String) -> Array[String]:
	var ids: Array[String] = []
	var descriptor: ACEDescriptor = _descriptor(ace_id)
	if descriptor != null:
		for param: ACEParam in descriptor.params:
			ids.append("%s=%s" % [param.id, param.default_value])
	return ids


static func _sheet_with(ace_id: String, params: Dictionary) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Sprite2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	event.actions.append(action)
	sheet.events.append(event)
	return sheet


## The one line a single-action sheet compiles to, without its indent.
static func _line(ace_id: String, params: Dictionary) -> String:
	for line: String in SUPPORT.compile_output(_sheet_with(ace_id, params)).split("\n"):
		if line.contains("scale"):
			return line.strip_edges()
	return "(no line)"


static func _read_back(line: String) -> String:
	var lifted: Resource = LIFTER.lift_one_line(line, false)
	return str(lifted.get("ace_id")) if lifted != null else "(nothing)"


static func _the_rows() -> bool:
	var size: ACEDescriptor = _descriptor("SpriteSetSize")
	var width: ACEDescriptor = _descriptor("SpriteSetWidth")
	var height: ACEDescriptor = _descriptor("SpriteSetHeight")
	return SUPPORT.pins(NAME, [
		["Set Size is a row", size != null, true],
		["Set Width is a row", width != null, true],
		["Set Height is a row", height != null, true],
		["Set Size is named in plain words", size.display_name if size != null else "", "Set Size"],
		["Set Width is named in plain words", width.display_name if width != null else "", "Set Width"],
		["Set Height is named in plain words", height.display_name if height != null else "", "Set Height"],
		["Set Size is offered on a sprite", size.node_type if size != null else "", "Sprite2D"],
		["Set Width is offered on a sprite", width.node_type if width != null else "", "Sprite2D"],
		["Set Height is offered on a sprite", height.node_type if height != null else "", "Sprite2D"],
		["Set Size divides by the drawn frame and leaves a sprite with no picture alone", _template("SpriteSetSize"),
			"{target.}scale = {size} / {target.}get_rect().size if {target.}texture else {target.}scale"],
		["Set Width writes scale.x only", _template("SpriteSetWidth"),
			"{target.}scale.x = {width} / {target.}get_rect().size.x if {target.}texture else {target.}scale.x"],
		["Set Height writes scale.y only", _template("SpriteSetHeight"),
			"{target.}scale.y = {height} / {target.}get_rect().size.y if {target.}texture else {target.}scale.y"],
		["Set Size takes a size and an On node", _param_ids("SpriteSetSize"), ["size=Vector2(64, 64)", "target="]],
		["Set Width takes a width and an On node", _param_ids("SpriteSetWidth"), ["width=64.0", "target="]],
		["Set Height takes a height and an On node", _param_ids("SpriteSetHeight"), ["height=64.0", "target="]],
	])


static func _the_lines_they_write() -> bool:
	var size: String = _line("SpriteSetSize", {"size": "Vector2(64, 64)"})
	var size_on_node: String = _line("SpriteSetSize", {"size": "Vector2(64, 64)", "target": "$Enemy"})
	var width: String = _line("SpriteSetWidth", {"width": "64.0"})
	var height_on_node: String = _line("SpriteSetHeight", {"height": "48.0", "target": "$Enemy"})
	return SUPPORT.pins(NAME, [
		["a Set Size row compiles to the bare scale line", size, "scale = Vector2(64, 64) / get_rect().size if texture else scale"],
		["On node measures the other sprite, never this one", size_on_node,
			"$Enemy.scale = Vector2(64, 64) / $Enemy.get_rect().size if $Enemy.texture else $Enemy.scale"],
		["a Set Width row compiles to the scale.x line", width, "scale.x = 64.0 / get_rect().size.x if texture else scale.x"],
		["a Set Height row on another node", height_on_node,
			"$Enemy.scale.y = 48.0 / $Enemy.get_rect().size.y if $Enemy.texture else $Enemy.scale.y"],
		["the Set Size line reads back as Set Size", _read_back(size), "SpriteSetSize"],
		["the On node line reads back as Set Size", _read_back(size_on_node), "SpriteSetSize"],
		["the Set Width line reads back as Set Width", _read_back(width), "SpriteSetWidth"],
		["the Set Height line reads back as Set Height", _read_back(height_on_node), "SpriteSetHeight"],
	])


static func _the_old_row_is_retired() -> bool:
	var old: ACEDescriptor = _descriptor("SetSpriteSize")
	var planned: Array[Dictionary] = EventSheetMigrationPlan.plan(
		_sheet_with("SetSpriteSize", {"size": "Vector2(96, 48)", "target": "$Enemy"}), EventForgeSuccessors.catalog())
	var entry: Dictionary = planned[0] if planned.size() == 1 else {}
	return SUPPORT.pins(NAME, [
		["Set Sprite Size keeps writing the line it always did", old.codegen_template, "{target.}scale = {size} / texture.get_size()"],
		["and a sheet that used it compiles it unchanged", _line("SetSpriteSize", {"size": "Vector2(96, 96)"}), "scale = Vector2(96, 96) / texture.get_size()"],
		["Set Sprite Size is retired from the picker", old.is_deprecated, true],
		["with the address of Set Size", old.replacement_ace_id, "Core::SpriteSetSize"],
		["and Migrate knows where it goes", old.successor_map().get("id", ""), "Core::SpriteSetSize"],
		["Migrate plans one row", planned.size(), 1],
		["onto Set Size", entry.get("to", ""), "Core::SpriteSetSize"],
		["without asking anything", entry.get("asks", true), false],
		["keeping the size and the node", entry.get("after", ""),
			"$Enemy.scale = Vector2(96, 48) / $Enemy.get_rect().size if $Enemy.texture else $Enemy.scale"],
	])


## A script that holds the old line, or any new one, reopens as a sheet and saves back the same bytes.
static func _a_file_round_trips() -> bool:
	var rows: Array = []
	var cases: Array[Array] = [
		["the old Set Sprite Size line", "SetSpriteSize", {"size": "Vector2(96, 48)"}],
		["the old line on another node", "SetSpriteSize", {"size": "Vector2(96, 48)", "target": "$Enemy"}],
		["a Set Size line", "SpriteSetSize", {"size": "Vector2(64, 64)"}],
		["a Set Width line on another node", "SpriteSetWidth", {"width": "80.0", "target": "$Enemy"}],
		["a Set Height line", "SpriteSetHeight", {"height": "48.0"}],
	]
	for case: Array in cases:
		var source: String = SUPPORT.compile_output(_sheet_with(case[1], case[2]), "user://sprite_size_rows_test.gd")
		var again: String = SUPPORT.reemit(source, "user://sprite_size_rows_test.gd")
		rows.append(["%s reopens and saves back the same bytes" % case[0], again == source, true])
	return SUPPORT.pins(NAME, rows)


static func _texture(width: int, height: int) -> ImageTexture:
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(image)


## The four sprites the fault was found on: a plain picture, a 4 x 2 sprite sheet, a region, and none.
static func _sprites() -> Array[Sprite2D]:
	var plain: Sprite2D = Sprite2D.new()
	plain.texture = _texture(32, 32)
	var sheet: Sprite2D = Sprite2D.new()
	sheet.texture = _texture(256, 128)
	sheet.hframes = 4
	sheet.vframes = 2
	var region: Sprite2D = Sprite2D.new()
	region.texture = _texture(256, 256)
	region.region_enabled = true
	region.region_rect = Rect2(0, 0, 32, 16)
	var empty: Sprite2D = Sprite2D.new()
	return [plain, sheet, region, empty]


## Runs the line each row compiles to on each sprite, then reads Width and Height with the lines
## those rows compile to. A script built from text is enough here: nothing reads an annotation.
## A sprite with no picture measures 1 x 1 in Godot 4.7 (get_rect() gives a 1 x 1 rectangle), so
## "left as it is" reads back as 1 x 1 at scale 1.
static func _the_sizes_come_out_right() -> bool:
	var source: String = "extends Sprite2D\n\nfunc set_size() -> void:\n\t%s\n\nfunc set_width() -> void:\n\t%s\n\nfunc measured() -> Vector2:\n\treturn Vector2(%s, %s)\n" % [
		_line("SpriteSetSize", {"size": "Vector2(64, 64)"}), _line("SpriteSetWidth", {"width": "80.0"}),
		_template("SpriteWidth"), _template("SpriteHeight")]
	var script: GDScript = GDScript.new()
	script.source_code = source
	var passed: bool = SUPPORT.check(NAME, "the compiled lines make a script", script.reload(), OK)
	if not passed:
		return false
	var rows: Array = []
	var names: Array[String] = ["a plain picture", "a 4 x 2 sprite sheet", "a region", "no picture"]
	var sized: Array[Vector2] = [Vector2(64, 64), Vector2(64, 64), Vector2(64, 64), Vector2(1, 1)]
	var widened: Array[Vector2] = [Vector2(80, 32), Vector2(80, 64), Vector2(80, 16), Vector2(1, 1)]
	var sprites: Array[Sprite2D] = _sprites()
	for index: int in sprites.size():
		var sprite: Sprite2D = sprites[index]
		sprite.set_script(script)
		sprite.call("set_size")
		rows.append(["Set Size 64 x 64 on %s reads back" % names[index], sprite.call("measured"), sized[index]])
		sprite.scale = Vector2.ONE
		sprite.call("set_width")
		rows.append(["Set Width 80 on %s reads back" % names[index], sprite.call("measured"), widened[index]])
		rows.append(["%s keeps a scale it can be drawn with" % names[index], sprite.scale.is_finite(), true])
		sprite.free()
	return SUPPORT.pins(NAME, rows) and passed


## Migrate's plan answers from the compiled text alone: it writes nothing into the user folder, so a
## second editor or test run sharing that folder - or a sync tool holding a file in it - cannot make
## a row the file takes ask a question.
static func _the_plan_writes_no_file() -> bool:
	var before: PackedStringArray = DirAccess.get_files_at("user://")
	EventSheetMigrationPlan.plan(_sheet_with("SetSpriteSize", {"size": "Vector2(96, 48)", "target": "$Enemy"}),
		EventForgeSuccessors.catalog())
	# Only the plan's own trial file names count: another process sharing the folder writes its own.
	var added: Array[String] = []
	for file: String in DirAccess.get_files_at("user://"):
		if not before.has(file) and file.begins_with("eventforge_migration_gate"):
			added.append(file)
	return SUPPORT.check(NAME, "Migrate plans a row without writing a file", added, [] as Array[String])
