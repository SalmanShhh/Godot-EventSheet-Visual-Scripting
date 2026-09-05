# EventForge - the tilemap and GridMap level-query words.
#
# The eleven shipped tilemap rows set, erase and read one cell. These are the questions a level that
# REACTS is asked - what the tile under the player carries, whether a cell is solid, where a line
# first meets something solid, how big the level is - and the words that CHANGE it: terrain paint
# that joins its own edges, the circle erase, the rectangle fill, the flood fill, and the layer
# saved to a file and read back. Plus the six GridMap twins, which are the same ideas one axis up.
#
# Seven gates, in the order they matter:
#   1. THE VOCABULARY - each row's kind, host and POST-TRANSFORM template, because a node-scoped row
#      does not ship the template it was authored with;
#   2. THE EMITTED FILE - every row compiled through the real compiler, the whole file parsed, and
#      each shared helper landing exactly ONCE however many rows called for it;
#   3. THE ROUND TRIP - that emitted file reopened and re-emitted byte for byte, which is the one
#      promise a helper appended at the end of a file could break, and the same promise from the
#      other side: a hand-written file that CALLS a helper without defining it grows nothing;
#   4. THE ANSWERS - the helpers run against a real TileMapLayer built here, tile data and all, so
#      "cell is solid" is a fact rather than a spelling;
#   5. THE FILE WORDS - a layer's bytes written and read back, and the tiles surviving the trip;
#   6. THE 3D TWIN - the GridMap box fill and erase, run against a real GridMap;
#   7. THE READING BACK - a hand-written line of each shape claimed by the row that writes it.
#
# NO SCENE TREE IS NEEDED and none is used: a TileMapLayer and a GridMap are built here with `new()`,
# handed a tileset made in memory, and freed at the end. The suite's own runner has no main loop, so
# a test that reached for one would be a test that never ran.
@tool
class_name TilemapQueryACEsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SheetCompiler := preload("res://addons/eventforge/compiler/sheet_compiler.gd")

const NAME := "tilemap_query_aces_test"

## Where the emitted file is verified from. A user:// path naming the test, by convention.
const EMITTED_PATH := "user://eventforge_tilemap_queries.gd"

## And where the hand-written files of the round-trip gate below are verified from - a script that
## CALLS one of the helpers without defining it, which is the one shape the appender could grow a
## definition onto that its author never wrote.
const HANDWRITTEN_PATH := "user://eventforge_tilemap_handwritten.gd"

## And where the layer's own bytes go on the file gate's round trip.
const LAYER_FILE := "user://eventforge_tilemap_queries_layer.tiles"

## One valid call per helper, in the order _helper_names lists them. The host script below needs the
## calls to be REAL: the compiler appends a definition only to a file that CALLS it, so a mention
## that is not a call would leave the host with no helpers in it and the answers with nothing to ask.
## The function holding them is never run - it exists so the appender has something to find.
const HELPER_CALL_ARGUMENTS: Array[String] = [
	"self, Vector2i.ZERO, \"surface\"",
	"self, Vector2i.ZERO, 0",
	"self, Vector2i.ZERO, Vector2i.ONE, 0",
	"self, \"surface\", \"water\"",
	"self, Vector2i.ZERO, 3",
	"self, Vector2i.ZERO, 3",
	"self, Rect2i(0, 0, 2, 2), 0, Vector2i.ZERO",
	"self, Vector2i.ZERO, 0, Vector2i.ZERO, 4096",
	"self, \"user://eventforge_tilemap_queries_unused.tiles\"",
	"self, \"user://eventforge_tilemap_queries_unused.tiles\"",
	"null, Vector3i.ZERO, Vector3i.ONE, 0"
]

## One tileset as a saved file's TEXT says it - the shape EventForgeTileSetFacts reads, written by
## hand here so the parse is asserted rather than whatever tileset happened to be in the project.
const TILESET_TEXT: String = """[sub_resource type="TileSet" id="TileSet_1"]
custom_data_layer_0/name = "surface"
custom_data_layer_0/type = 4
custom_data_layer_1/name = "cost"
custom_data_layer_1/type = 2
terrain_set_0/mode = 0
terrain_set_0/terrain_0/name = "Grass"
terrain_set_0/terrain_1/name = "Dirt"
terrain_set_1/mode = 0
terrain_set_1/terrain_0/name = "Water"
"""


static func run() -> bool:
	var ok: bool = _vocabulary()
	ok = _emitted_file() and ok
	ok = _answers() and ok
	ok = _layer_files() and ok
	ok = _gridmap_twin() and ok
	ok = _reading_back() and ok
	ok = _tileset_facts() and ok
	ok = _doctor() and ok
	return ok


# ── 1. the vocabulary ───────────────────────────────────────────────────────────────────
## Each new row's SHIPPED template - which for a node-scoped row whose template is one plain member
## call is not the one it was authored with: the registrar prefixes it with the optional `{target.}`
## and appends an "On node" parameter. A row that calls a shared helper names its layer itself and
## keeps the template it was written with, and the difference between the two is asserted here so a
## change to either rule fails in one place.
static func _vocabulary() -> bool:
	var pins: Dictionary = {
		# It names its layer twice, so it names it ITSELF: the automatic prefix would have gone on
		# the guard and left the lookup reading off the host.
		"TileMapTileHasCustomData": "{target}.get_cell_tile_data({coords}) != null and {target}.get_cell_tile_data({coords}).get_custom_data({name})",
		"TileMapDataAt": "__eventsheets_tile_data_at({target}, {where}, {key})",
		"TileMapDataAtIs": "__eventsheets_tile_data_at({target}, {where}, {key}) == {value}",
		"TileMapCellIsSolid": "__eventsheets_cell_is_solid({target}, {cell}, {layer})",
		"TileMapFirstSolidCellAlong": "__eventsheets_first_solid_cell({target}, {from}, {to}, {layer})",
		"TileMapSurroundingCells": "{target.}get_surrounding_cells({cell})",
		"TileMapCellsWithData": "__eventsheets_cells_with_data({target}, {key}, {value})",
		"TileMapUsedRect": "{target.}get_used_rect()",
		"TileMapCellCountOf": "{target.}get_used_cells_by_id({source_id}, {atlas_coords}).size()",
		"TileMapTileUnder": "{target}.local_to_map({target}.to_local({node}.global_position))",
		"TileMapPaintTerrain": "{target.}set_cells_terrain_connect({cells}, {terrain_set}, {terrain})",
		"TileMapRepaintTerrainAround": "{target}.set_cells_terrain_connect(__eventsheets_cells_around({target}, {where}, {radius}), {terrain_set}, {terrain})",
		"TileMapFillRect": "__eventsheets_fill_tile_rect({target}, {rect}, {source_id}, {atlas_coords})",
		"TileMapEraseCircle": "__eventsheets_erase_tiles_in_circle({target}, {where}, {radius})",
		"TileMapFloodFill": "__eventsheets_flood_fill_tiles({target}, {cell}, {source_id}, {atlas_coords}, {limit})",
		"TileMapSetNavigation": "{target.}navigation_enabled = {on}",
		"TileMapSetCollision": "{target.}collision_enabled = {on}",
		"TileMapSaveLayer": "__eventsheets_save_tile_layer({target}, {path})",
		"TileMapLoadLayer": "__eventsheets_load_tile_layer({target}, {path})",
		"TileMapCopyLayer": "{target}.tile_map_data = {from}.tile_map_data",
		"GridMapSetCellItem": "{target.}set_cell_item({cell}, {item}, {orientation})",
		"GridMapItemAt": "{target.}get_cell_item({cell})",
		"GridMapCellIsFilled": "{target.}get_cell_item({cell}) != GridMap.INVALID_CELL_ITEM",
		"GridMapUsedCells": "{target.}get_used_cells()",
		"GridMapFillBox": "__eventsheets_gridmap_fill_box({target}, {from}, {to}, {item})",
		"GridMapEraseBox": "__eventsheets_gridmap_fill_box({target}, {from}, {to}, GridMap.INVALID_CELL_ITEM)"
	}
	var ok: bool = SUPPORT.pin_table(NAME, pins, func(ace_id: String) -> String:
		return str(_descriptor(ace_id).codegen_template))
	# The kind is the promise: a condition asks, an action does, an expression answers. A row filed
	# under the wrong one reads correctly and lands in the wrong lane for ever.
	var kinds: Dictionary = {
		"TileMapDataAt": ACEDescriptor.ACEType.EXPRESSION,
		"TileMapDataAtIs": ACEDescriptor.ACEType.CONDITION,
		"TileMapCellIsSolid": ACEDescriptor.ACEType.CONDITION,
		"TileMapFirstSolidCellAlong": ACEDescriptor.ACEType.EXPRESSION,
		"TileMapUsedRect": ACEDescriptor.ACEType.EXPRESSION,
		"TileMapPaintTerrain": ACEDescriptor.ACEType.ACTION,
		"TileMapSaveLayer": ACEDescriptor.ACEType.ACTION,
		"GridMapCellIsFilled": ACEDescriptor.ACEType.CONDITION,
		"GridMapItemAt": ACEDescriptor.ACEType.EXPRESSION,
		"GridMapEraseBox": ACEDescriptor.ACEType.ACTION
	}
	ok = SUPPORT.pin_table(NAME, kinds, func(ace_id: String) -> int:
		return int(_descriptor(ace_id).ace_type)) and ok
	# And the host, because it is what puts the row on the right shelf and what the compile gate
	# wraps each template in.
	var hosts: Dictionary = {
		"TileMapDataAt": "TileMapLayer", "TileMapFloodFill": "TileMapLayer",
		"GridMapSetCellItem": "GridMap", "GridMapFillBox": "GridMap"
	}
	ok = SUPPORT.pin_table(NAME, hosts, func(ace_id: String) -> String:
		return str(_descriptor(ace_id).node_type)) and ok
	# The eleven shipped rows are untouched: their ids still resolve and Set Tile still writes the
	# line it has always written.
	ok = SUPPORT.pin_value(NAME, "the shipped Set Tile is unchanged",
		str(_descriptor("TileMapSetCell").codegen_template),
		"{target.}set_cell({coords}, {source_id}, {atlas_coords})") and ok
	# The two fields the tileset answers for carry the hints that make them suggest, which is the
	# whole of the wiring: the completion seam keys on the parameter's own hint.
	ok = SUPPORT.pin_value(NAME, "the data key field suggests",
		_param_hint("TileMapDataAt", "key"), "tile_data_key") and ok
	ok = SUPPORT.pin_value(NAME, "the terrain field suggests",
		_param_hint("TileMapPaintTerrain", "terrain"), "tile_terrain") and ok
	return ok


# ── 2. the emitted file, and the helper that lands once ─────────────────────────────────
## Every new row compiled through the real compiler into one file: the whole thing must parse, each
## helper must appear exactly once however many rows asked for it, and a row that asks for none must
## not drag one in.
static func _emitted_file() -> bool:
	var emitted: String = _compile_all()
	var script: GDScript = GDScript.new()
	script.source_code = emitted
	var ok: bool = SUPPORT.pin_value(NAME, "the emitted file parses",
		error_string(script.reload()), error_string(OK))
	var once: Dictionary = {}
	for helper_name: String in _helper_names():
		once[helper_name] = emitted.count("func %s(" % helper_name)
	ok = SUPPORT.pin_table(NAME, once, func(helper_name: String) -> int:
		return int(once[helper_name])) and ok
	for helper_name: String in _helper_names():
		ok = SUPPORT.pin_value(NAME, "%s is defined exactly once" % helper_name,
			emitted.count("func %s(" % helper_name), 1) and ok
	# A sheet holding ONLY rows that call no helper gains no definitions at all - the appender asks
	# what the file calls, and a file that calls nothing is left alone.
	var plain: String = _compile_rows([
		{"kind": "expression", "ace_id": "TileMapUsedRect"},
		{"kind": "action", "ace_id": "TileMapSetNavigation"}])
	var dragged: int = 0
	for helper_name: String in _helper_names():
		dragged += plain.count("func %s(" % helper_name)
	ok = SUPPORT.pin_value(NAME, "a sheet calling no helper gains none", dragged, 0) and ok
	# THE ROUND TRIP: the appended helpers are read back as ordinary functions and written out
	# again in the same place, so the file saves byte for byte.
	ok = SUPPORT.pin_value(NAME, "the emitted file re-emits byte for byte",
		SUPPORT.reemit(emitted, EMITTED_PATH), emitted) and ok
	# AND THE OTHER HALF OF THAT PROMISE: a HAND-WRITTEN file that calls one of these helpers
	# without defining it - a test driving them, a script reaching another node's plumbing - is
	# passed through as written. The appender asks what the ROWS of the sheet called for, and a call
	# that only rode through a verbatim block asked for nothing, so opening such a file and saving it
	# must not grow a definition its author never wrote. Four spellings, because each reaches the
	# appender by a different road: a call inside an argument, a bare statement, a call on another
	# node, and a call as the term of an `if`.
	var handwritten: Dictionary = {
		"\tprint(__eventsheets_tile_data_at(self, Vector2i(0, 0), \"surface\"))": true,
		"\t__eventsheets_erase_tiles_in_circle(self, Vector2i(0, 0), 3)": true,
		"\tlayer.__eventsheets_erase_tiles_in_circle(layer, Vector2i(0, 0), 3)": true,
		"\tif __eventsheets_cell_is_solid(self, Vector2i(0, 0), 0):\n\t\tprint(1)": true
	}
	ok = SUPPORT.pin_table(NAME, handwritten, func(body: String) -> bool:
		var source: String = "extends Node\n\n\nfunc _ready() -> void:\n%s\n" % body
		return SUPPORT.reemit(source, HANDWRITTEN_PATH) == source) and ok
	return ok


# ── 3. the answers, against a real layer ────────────────────────────────────────────────
## The helpers RUN, against a TileMapLayer built here with a tileset of its own: a data layer called
## "surface", a physics layer, one solid tile that says "ice" and one bare tile that says "grass".
## Every answer below is a fact about that layer rather than a spelling.
static func _answers() -> bool:
	var host: GDScript = _helper_host("TileMapLayer")
	var layer: TileMapLayer = host.new()
	_dress(layer)
	var ok: bool = SUPPORT.pin_value(NAME, "tile data at a cell",
		layer.__eventsheets_tile_data_at(layer, Vector2i(0, 0), "surface"), "ice")
	ok = SUPPORT.pin_value(NAME, "tile data at a position",
		layer.__eventsheets_tile_data_at(layer, layer.map_to_local(Vector2i(1, 0)), "surface"),
		"grass") and ok
	ok = SUPPORT.pin_value(NAME, "tile data where there is no tile",
		layer.__eventsheets_tile_data_at(layer, Vector2i(9, 9), "surface"), null) and ok
	ok = SUPPORT.pin_value(NAME, "tile data from a layer that is not there",
		layer.__eventsheets_tile_data_at(null, Vector2i(0, 0), "surface"), null) and ok
	ok = SUPPORT.pin_value(NAME, "the solid cell is solid",
		layer.__eventsheets_cell_is_solid(layer, Vector2i(0, 0), 0), true) and ok
	ok = SUPPORT.pin_value(NAME, "the bare cell is not solid",
		layer.__eventsheets_cell_is_solid(layer, Vector2i(1, 0), 0), false) and ok
	ok = SUPPORT.pin_value(NAME, "an empty cell is not solid",
		layer.__eventsheets_cell_is_solid(layer, Vector2i(9, 9), 0), false) and ok
	# The tile raycast: a line that runs into the solid cell stops on it, and one that never meets
	# anything says so with Vector2i.MAX rather than with a cell it did not find.
	ok = SUPPORT.pin_value(NAME, "the line stops on the solid cell",
		layer.__eventsheets_first_solid_cell(layer, Vector2i(-3, 0), Vector2i(3, 0), 0),
		Vector2i(0, 0)) and ok
	ok = SUPPORT.pin_value(NAME, "a line meeting nothing answers MAX",
		layer.__eventsheets_first_solid_cell(layer, Vector2i(0, 5), Vector2i(6, 5), 0),
		Vector2i.MAX) and ok
	ok = SUPPORT.pin_value(NAME, "cells carrying a value",
		layer.__eventsheets_cells_with_data(layer, "surface", "ice"),
		[Vector2i(0, 0)] as Array[Vector2i]) and ok
	ok = SUPPORT.pin_value(NAME, "cells carrying a value nothing has",
		layer.__eventsheets_cells_with_data(layer, "surface", "lava"),
		[] as Array[Vector2i]) and ok
	# The cells around a place, and the circle erase over the same walk.
	ok = SUPPORT.pin_value(NAME, "the cells around a cell at radius 1",
		layer.__eventsheets_cells_around(layer, Vector2i(0, 0), 1).size(), 9) and ok
	ok = SUPPORT.pin_value(NAME, "the used rect before anything is erased",
		layer.get_used_rect(), Rect2i(0, 0, 2, 1)) and ok
	layer.__eventsheets_erase_tiles_in_circle(layer, Vector2i(0, 0), 1)
	ok = SUPPORT.pin_value(NAME, "the circle erase clears both cells",
		layer.get_used_cells().size(), 0) and ok
	# The rectangle fill and the flood fill, over the now-empty layer.
	layer.__eventsheets_fill_tile_rect(layer, Rect2i(0, 0, 3, 2), 0, Vector2i(1, 0))
	ok = SUPPORT.pin_value(NAME, "the rectangle fill paints every cell of it",
		layer.get_used_cells().size(), 6) and ok
	layer.__eventsheets_flood_fill_tiles(layer, Vector2i(0, 0), 0, Vector2i(0, 0), 4096)
	ok = SUPPORT.pin_value(NAME, "the flood fill reaches the whole patch",
		layer.get_used_cells_by_id(0, Vector2i(0, 0)).size(), 6) and ok
	# The limit is the row's own field, and it is what stops a fill let loose on open ground: a
	# limit of one paints one cell and gives up.
	layer.__eventsheets_fill_tile_rect(layer, Rect2i(0, 0, 3, 2), 0, Vector2i(1, 0))
	layer.__eventsheets_flood_fill_tiles(layer, Vector2i(0, 0), 0, Vector2i(0, 0), 1)
	ok = SUPPORT.pin_value(NAME, "the flood fill stops at its limit",
		layer.get_used_cells_by_id(0, Vector2i(0, 0)).size(), 1) and ok
	layer.free()
	return ok


# ── 4. the layer as a file ──────────────────────────────────────────────────────────────
## The two file words, over the engine's own bytes: a layer written out, a second layer that read it
## back holding the same tiles, and a read of a file that is not there leaving a layer alone rather
## than clearing it.
static func _layer_files() -> bool:
	var host: GDScript = _helper_host("TileMapLayer")
	var written: TileMapLayer = host.new()
	_dress(written)
	var ok: bool = SUPPORT.pin_value(NAME, "the layer saves",
		written.__eventsheets_save_tile_layer(written, LAYER_FILE), true)
	var read_back: TileMapLayer = host.new()
	read_back.tile_set = written.tile_set
	ok = SUPPORT.pin_value(NAME, "the layer loads",
		read_back.__eventsheets_load_tile_layer(read_back, LAYER_FILE), true) and ok
	ok = SUPPORT.pin_value(NAME, "the tiles survive the trip",
		read_back.get_used_cells(), written.get_used_cells()) and ok
	ok = SUPPORT.pin_value(NAME, "and so does what they carry",
		read_back.__eventsheets_tile_data_at(read_back, Vector2i(0, 0), "surface"), "ice") and ok
	# A file that was never written leaves the layer exactly as it was. This is the one the row's
	# help promises, and the one a first run always meets.
	var untouched: TileMapLayer = host.new()
	untouched.tile_set = written.tile_set
	untouched.set_cell(Vector2i(4, 4), 0, Vector2i(0, 0))
	ok = SUPPORT.pin_value(NAME, "a missing file reports failure",
		untouched.__eventsheets_load_tile_layer(untouched, "user://eventforge_no_such.tiles"),
		false) and ok
	ok = SUPPORT.pin_value(NAME, "and leaves the layer alone",
		untouched.get_used_cells(), [Vector2i(4, 4)] as Array[Vector2i]) and ok
	# Copy Layer is a plain assignment of the same bytes, which is why it is a row rather than a
	# helper: pinning it here says the two words really do move the same thing.
	var copy: TileMapLayer = host.new()
	copy.tile_set = written.tile_set
	copy.tile_map_data = written.tile_map_data
	ok = SUPPORT.pin_value(NAME, "one layer copies onto another",
		copy.get_used_cells(), written.get_used_cells()) and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LAYER_FILE))
	written.free()
	read_back.free()
	untouched.free()
	copy.free()
	return ok


# ── 5. the 3D twin ──────────────────────────────────────────────────────────────────────
## The GridMap box words, run against a real GridMap: fill puts an item in every cell of the box,
## erase takes it back out, and the two corners may be given in either order because a box drawn
## backwards is still a box.
static func _gridmap_twin() -> bool:
	var host: GDScript = _helper_host("GridMap")
	var grid: GridMap = host.new()
	grid.__eventsheets_gridmap_fill_box(grid, Vector3i(0, 0, 0), Vector3i(1, 0, 1), 0)
	var ok: bool = SUPPORT.pin_value(NAME, "the box fill fills every cell of it",
		grid.get_used_cells().size(), 4)
	ok = SUPPORT.pin_value(NAME, "and the cells hold the item",
		grid.get_cell_item(Vector3i(1, 0, 1)), 0) and ok
	grid.__eventsheets_gridmap_fill_box(grid, Vector3i(1, 0, 1), Vector3i(0, 0, 0),
		GridMap.INVALID_CELL_ITEM)
	ok = SUPPORT.pin_value(NAME, "the box erase empties it, corners either way round",
		grid.get_used_cells().size(), 0) and ok
	ok = SUPPORT.pin_value(NAME, "an emptied cell answers the invalid item",
		grid.get_cell_item(Vector3i(0, 0, 0)), GridMap.INVALID_CELL_ITEM) and ok
	grid.free()
	return ok


# ── 6. the reading back ─────────────────────────────────────────────────────────────────
## A hand-written line of each shape claimed by the row that WRITES that line. Only conditions and
## actions enter the reverse index - an expression lives inside another row's field and is never a
## line of its own - so those are what is asked here.
static func _reading_back() -> bool:
	var entries: Array = EventSheetACELifter._build_reverse_entries()
	var pins: Dictionary = {
		"__eventsheets_cell_is_solid(self, cell, 0)": "TileMapCellIsSolid",
		"__eventsheets_tile_data_at(self, cell, \"surface\") == \"ice\"": "TileMapDataAtIs",
		"get_cell_item(cell) != GridMap.INVALID_CELL_ITEM": "GridMapCellIsFilled"
	}
	var ok: bool = SUPPORT.pin_table(NAME, pins, func(line: String) -> String:
		return str(EventSheetACELifter._match_entry(line, entries, "condition").get("ace_id", "")))
	var actions: Dictionary = {
		"__eventsheets_erase_tiles_in_circle(self, centre, 3)": "TileMapEraseCircle",
		"__eventsheets_save_tile_layer(self, \"user://levels/mine.tiles\")": "TileMapSaveLayer",
		"__eventsheets_load_tile_layer(self, \"user://levels/mine.tiles\")": "TileMapLoadLayer",
		"set_cells_terrain_connect(rim, 0, 0)": "TileMapPaintTerrain",
		"navigation_enabled = true": "TileMapSetNavigation",
		"collision_enabled = false": "TileMapSetCollision",
		"set_cell_item(cell, 2, 0)": "GridMapSetCellItem",
		"__eventsheets_gridmap_fill_box(self, low, high, 1)": "GridMapFillBox",
		"__eventsheets_gridmap_fill_box(self, low, high, GridMap.INVALID_CELL_ITEM)": "GridMapEraseBox"
	}
	ok = SUPPORT.pin_table(NAME, actions, func(line: String) -> String:
		return str(EventSheetACELifter._match_entry(line, entries, "action").get("ace_id", ""))) and ok
	return ok


# ── 7. what a tileset says about itself ─────────────────────────────────────────────────
## The text reading both the suggestion lists and the Doctor rest on. Asked of a tileset written
## here in the engine's own saved shape, so the parse is what is pinned rather than whichever
## tileset a project happened to hold.
static func _tileset_facts() -> bool:
	var ok: bool = SUPPORT.pin_value(NAME, "the data layers a tileset declares",
		EventForgeTileSetFacts.data_keys(TILESET_TEXT),
		PackedStringArray(["surface", "cost"]))
	var terrains: Array[Dictionary] = EventForgeTileSetFacts.terrains(TILESET_TEXT)
	ok = SUPPORT.pin_value(NAME, "the terrains it declares", terrains.size(), 3) and ok
	ok = SUPPORT.pin_value(NAME, "each terrain knows its set and its number",
		terrains[2], {"set": 1, "index": 0, "name": "Water"}) and ok
	ok = SUPPORT.pin_value(NAME, "a text with no tileset in it declares nothing",
		EventForgeTileSetFacts.data_keys("extends Node\n").size(), 0) and ok
	return _reading_a_file_once_is_a_thing_a_caller_asks_for() and ok


## One Doctor run asks this file three questions about the same bytes, and each one walked the
## project and read every text resource in it. A caller may now say it is asking a run of them, and
## in between each file is read once - but only in between: outside that pair nothing is held, so
## the answer is about the project as it is now rather than as it was when somebody last looked.
static func _reading_a_file_once_is_a_thing_a_caller_asks_for() -> bool:
	var path: String = "user://tilemap_query_aces_test_facts.tres"
	_write_text(path, "first")
	var without: String = EventForgeTileSetFacts.source_of(path)
	_write_text(path, "second")
	var still_fresh: String = EventForgeTileSetFacts.source_of(path)
	EventForgeTileSetFacts.remember()
	var held: String = EventForgeTileSetFacts.source_of(path)
	_write_text(path, "third")
	var still_held: String = EventForgeTileSetFacts.source_of(path)
	EventForgeTileSetFacts.forget()
	var let_go: String = EventForgeTileSetFacts.source_of(path)
	DirAccess.remove_absolute(path)
	return SUPPORT.pins(NAME, [
		["nothing is held by default", [without, still_fresh], ["first", "second"]],
		["a caller that is remembering reads each file once", [held, still_held],
			["second", "second"]],
		["and forgetting is really forgetting", let_go, "third"],
	])


## One file written, for the reading above. The fixtures further down write scripts; this writes a
## few letters, and the point is only that the bytes on disk changed.
static func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


# ── 8. the quiet notes ──────────────────────────────────────────────────────────────────
## The two findings, pure over one script's text and the two facts a project's tilesets answer: a
## data key nothing declares, and a terrain set the tilesets do not reach. And the silences that
## matter as much - a key that IS declared says nothing, a deliberate -1 erase is not a missing
## terrain set, a NODE named with a quoted string inside the call is not a data key, and a key held
## in a variable is one nothing here can name.
static func _doctor() -> bool:
	var source: String = """extends TileMapLayer

func _process(_delta: float) -> void:
	var a = __eventsheets_tile_data_at(self, Vector2i(0, 0), "surface")
	var b = __eventsheets_tile_data_at(self, player.global_position, "slipperiness")
	var c = __eventsheets_cells_with_data(self, "cost", 3)
	var d = __eventsheets_tile_data_at(get_node("Ground"), marker.global_position, "surface")
	var e = __eventsheets_tile_data_at(self, Vector2i(0, 0), whichever_key)
	set_cells_terrain_connect([Vector2i(0, 0)], 0, 1)
	set_cells_terrain_connect(__eventsheets_cells_around(self, Vector2i(0, 0), 3), 4, -1)
	set_cells_terrain_connect(__eventsheets_cells_around(self, Vector2i(0, 0), 3), -1, -1)
"""
	# The `get_node("Ground")` line is the trap: a reading that claimed the first quoted string it
	# found before a bracket reported "Ground" as a data layer, which is a warning about a row that
	# is entirely correct. The `whichever_key` line is the other side of it - a key nothing can read
	# off the text is a key this section says nothing about.
	var ok: bool = SUPPORT.pin_value(NAME, "the keys a script asks for, and only the keys",
		EventSheetTilemapDoctor.data_keys_asked(source),
		PackedStringArray(["surface", "slipperiness", "cost"]))
	ok = SUPPORT.pin_value(NAME, "the terrain sets it paints into, the -1 erase left out",
		EventSheetTilemapDoctor.terrain_sets_painted(source), [0, 4] as Array[int]) and ok
	var findings: Array[Dictionary] = EventSheetTilemapDoctor.script_findings("res://ground.gd",
		source, PackedStringArray(["surface", "cost"]), 2)
	ok = SUPPORT.pin_value(NAME, "two notes, and only two", findings.size(), 2) and ok
	ok = SUPPORT.pin_value(NAME, "the unknown key is named",
		str(findings[0].get("subject", "")), "slipperiness") and ok
	ok = SUPPORT.pin_value(NAME, "and filed under its own check",
		str(findings[0].get("check", "")), "tilemap-unknown-data-key") and ok
	ok = SUPPORT.pin_value(NAME, "the missing terrain set is named",
		str(findings[1].get("subject", "")), "4") and ok
	ok = SUPPORT.pin_value(NAME, "and filed under its own check",
		str(findings[1].get("check", "")), "tilemap-missing-terrain-set") and ok
	# A project whose tilesets declare everything the script asks for hears nothing at all, which is
	# the quiet sheet's whole point.
	ok = SUPPORT.pin_value(NAME, "a project that declares them all is quiet",
		EventSheetTilemapDoctor.script_findings("res://ground.gd", source,
			PackedStringArray(["surface", "slipperiness", "cost"]), 5).size(), 0) and ok
	# A project whose readable tilesets declare no terrain set at all has no highest one, and the
	# arithmetic that names it said "go up to -1".
	var no_terrains: Array[Dictionary] = EventSheetTilemapDoctor.script_findings("res://ground.gd",
		source, PackedStringArray(["surface", "slipperiness", "cost"]), 0)
	ok = SUPPORT.pin_value(NAME, "with no terrain set anywhere, the note says so in words",
		str(no_terrains[0].get("message", "")),
		"ground.gd paints terrain set 0, and no tileset in this project declares a terrain set at all - the paint call does nothing.") and ok
	# And the summary line leads the section, so a reader sees the shape before the notes.
	var report: Array[Dictionary] = EventSheetTilemapDoctor.report(
		[{"path": "res://ground.gd", "source": source}], PackedStringArray(["surface", "cost"]), 2)
	ok = SUPPORT.pin_value(NAME, "the summary leads and is information",
		str(report[0].get("severity", "")), "info") and ok
	return ok


# ── the fixtures ────────────────────────────────────────────────────────────────────────
## One shipped descriptor by id, out of either module, so a rename fails here rather than silently.
static func _descriptor(ace_id: String) -> ACEDescriptor:
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if descriptor.ace_id == ace_id:
			return descriptor
	return ACEDescriptor.new()


## One parameter's hint, which is the key the completion seam answers on.
static func _param_hint(ace_id: String, param_id: String) -> String:
	for param: ACEParam in _descriptor(ace_id).params:
		if str(param.id) == param_id:
			return str(param.hint)
	return ""


## The eleven helper names, asked of the compiler rather than spelled again here.
static func _helper_names() -> Array[String]:
	return [SheetCompiler.TILE_DATA_HELPER, SheetCompiler.TILE_SOLID_HELPER,
		SheetCompiler.TILE_RAY_HELPER, SheetCompiler.TILE_DATA_CELLS_HELPER,
		SheetCompiler.TILE_CELLS_AROUND_HELPER, SheetCompiler.TILE_ERASE_CIRCLE_HELPER,
		SheetCompiler.TILE_FILL_RECT_HELPER, SheetCompiler.TILE_FLOOD_FILL_HELPER,
		SheetCompiler.TILE_SAVE_HELPER, SheetCompiler.TILE_LOAD_HELPER,
		SheetCompiler.GRIDMAP_FILL_BOX_HELPER]


## A script holding every helper definition and nothing else, in the host asked for, so the answers
## above are run against the SAME text the compiler writes into a real project rather than a copy of
## it kept here.
static func _helper_host(host_class: String) -> GDScript:
	var lines: PackedStringArray = PackedStringArray(["extends %s" % host_class, "",
		"func __calls() -> void:"])
	var names: Array[String] = _helper_names()
	for index: int in names.size():
		lines.append("\t%s(%s)" % [names[index], HELPER_CALL_ARGUMENTS[index]])
	SheetCompiler._append_level_query_helpers(lines)
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(lines) + "\n"
	script.reload()
	return script


## The layer every answer above is about: a tileset with a "surface" data layer and a physics layer,
## a solid tile that says "ice" at the origin, and a bare tile that says "grass" beside it.
static func _dress(layer: TileMapLayer) -> void:
	var image: Image = Image.create(32, 16, false, Image.FORMAT_RGBA8)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(16, 16)
	source.create_tile(Vector2i(0, 0))
	source.create_tile(Vector2i(1, 0))
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "surface")
	tile_set.set_custom_data_layer_type(0, TYPE_STRING)
	tile_set.add_physics_layer()
	tile_set.add_source(source, 0)
	var solid: TileData = source.get_tile_data(Vector2i(0, 0), 0)
	solid.set_custom_data("surface", "ice")
	solid.add_collision_polygon(0)
	solid.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8),
		Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	source.get_tile_data(Vector2i(1, 0), 0).set_custom_data("surface", "grass")
	layer.tile_set = tile_set
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(1, 0), 0, Vector2i(1, 0))


## Every new row in one compiled file: the expressions stored into variables, the conditions asked,
## the actions run. Compiled through the real compiler, which is the only thing that appends the
## helpers.
static func _compile_all() -> String:
	var rows: Array[Dictionary] = []
	for ace_id: String in ["TileMapDataAt", "TileMapFirstSolidCellAlong", "TileMapSurroundingCells",
			"TileMapCellsWithData", "TileMapUsedRect", "TileMapCellCountOf", "TileMapTileUnder"]:
		rows.append({"kind": "expression", "ace_id": ace_id})
	for ace_id: String in ["TileMapDataAtIs", "TileMapCellIsSolid"]:
		rows.append({"kind": "condition", "ace_id": ace_id})
	for ace_id: String in ["TileMapPaintTerrain", "TileMapRepaintTerrainAround", "TileMapFillRect",
			"TileMapEraseCircle", "TileMapFloodFill", "TileMapSetNavigation",
			"TileMapSetCollision", "TileMapSaveLayer", "TileMapLoadLayer", "TileMapCopyLayer"]:
		rows.append({"kind": "action", "ace_id": ace_id})
	# The GridMap words compile into the same file on purpose: the box helper is one definition
	# whichever host asked for it, and a file holding both must still hold exactly one of it.
	rows.append({"kind": "action", "ace_id": "GridMapFillBox"})
	rows.append({"kind": "action", "ace_id": "GridMapEraseBox"})
	return _compile_rows(rows)


## One sheet built out of {kind, ace_id} rows and compiled. An expression is stored into a variable
## (an expression is not a line of its own), a condition guards the event, an action is one of its
## actions.
static func _compile_rows(rows: Array) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "TileMapLayer"
	var event_row: EventRow = EventRow.new()
	event_row.event_uid = "tilequeries"
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		var descriptor: ACEDescriptor = _descriptor(str(row["ace_id"]))
		match str(row["kind"]):
			"expression":
				var store: ACEAction = ACEAction.new()
				store.provider_id = "Core"
				store.ace_id = "SetLocalVar"
				store.params = {"name": "asked_%d" % index, "value": _filled(descriptor)}
				event_row.actions.append(store)
			"condition":
				var condition: ACECondition = ACECondition.new()
				condition.provider_id = "Core"
				condition.ace_id = descriptor.ace_id
				condition.params = _defaults(descriptor)
				event_row.conditions.append(condition)
			_:
				var action: ACEAction = ACEAction.new()
				action.provider_id = "Core"
				action.ace_id = descriptor.ace_id
				action.params = _defaults(descriptor)
				event_row.actions.append(action)
	sheet.events.append(event_row)
	return SUPPORT.compile_output(sheet, EMITTED_PATH)


## One descriptor's parameters as the dictionary a row carries: each id against its own default.
static func _defaults(descriptor: ACEDescriptor) -> Dictionary:
	var params: Dictionary = {}
	for param: ACEParam in descriptor.params:
		params[str(param.id)] = str(param.default_value)
	return params


## An expression descriptor's template with its own defaults filled in - what the picker writes into
## a field when the row is dropped and nothing is edited.
static func _filled(descriptor: ACEDescriptor) -> String:
	var written: String = str(descriptor.codegen_template)
	for param: ACEParam in descriptor.params:
		written = written.replace("{%s.}" % str(param.id), "")
		written = written.replace("{%s}" % str(param.id), str(param.default_value))
	return written
