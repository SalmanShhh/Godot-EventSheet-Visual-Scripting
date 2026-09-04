# EventForge module - Tilemaps (TileMapLayer, Godot 4.3+)
#
# set/erase/clear cells, query cell source/atlas, and map<->local coordinate conversion.
# Lane-1 wraps of native TileMapLayer methods, single-line per the parity contract; coords
# are Vector2i expressions (the ƒx field serves them). Targets TileMapLayer (the legacy
# TileMap node uses a layer-index arg these omit). Module contract: see ace_factory.gd.
@tool
class_name EventForgeTileMapACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The names of the emitted helper functions the level-query rows call. The compiler writes each
## definition into the file the first time any row asks for it, so a project that asks for a tile's
## data AND for the cells carrying it gains the plumbing once rather than twice, and the emitted
## line stays one readable sentence instead of a doubled null-guarded lookup.
##
## A row that calls one of these names its layer in an "On node" parameter of its own rather than
## taking the automatic {target.} prefix: that prefix is added to the START of a line only, so a row
## whose layer appears twice (or inside a helper call) would retarget half of itself and read the
## rest off the host. Rows that really are one plain member call take the automatic prefix as usual.
const DATA_AT := "__eventsheets_tile_data_at"
const CELL_IS_SOLID := "__eventsheets_cell_is_solid"
const FIRST_SOLID := "__eventsheets_first_solid_cell"
const CELLS_WITH_DATA := "__eventsheets_cells_with_data"
const CELLS_AROUND := "__eventsheets_cells_around"
const ERASE_CIRCLE := "__eventsheets_erase_tiles_in_circle"
const FILL_RECT := "__eventsheets_fill_tile_rect"
const FLOOD_FILL := "__eventsheets_flood_fill_tiles"
const SAVE_LAYER := "__eventsheets_save_tile_layer"
const LOAD_LAYER := "__eventsheets_load_tile_layer"

## The sentence every "On node" field on these rows reads with, written once so that nineteen rows
## cannot drift into nineteen wordings of the same field.
const ON_NODE_WORDS := "The tilemap layer this asks. Leave it as self for the layer this sheet is on, or name another one."

## The sentence the two "a cell or a position" fields read with, for the same reason.
const WHERE_WORDS := "A cell, or a global position - a position is turned into the cell that holds it."

## And the one every custom-data-name field reads with.
const DATA_KEY_WORDS := "The custom data layer's name, spelled as the tileset spells it."


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.act("TileMapSetCell", "Set Tile", "set_cell({coords}, {source_id}, {atlas_coords})", "Tilemap", "Set tile at {coords} to {atlas_coords}", "Paints a tile at a grid cell, choosing which tileset and which tile of it to use.", "TileMapLayer").param("coords", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression").param("source_id", "0", "Tileset", "Tile source id.", "expression").param("atlas_coords", "Vector2i(0, 0)", "Tile", "Which tile of the tileset (atlas coordinates).", "expression"))
	descriptors.append(F.act("TileMapEraseCell", "Erase Tile", "erase_cell({coords})", "Tilemap", "Erase tile at {coords}", "Clears the tile at a single grid cell, leaving it empty.", "TileMapLayer").param("coords", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression"))
	# The tile's own data, asked as one question - the guard and the lookup the hand-written shape
	# spells over two lines, in the one condition the sheet has for it.
	descriptors.append(F.cond("TileMapTileHasCustomData", "Tile Has Custom Data", "get_cell_tile_data({coords}) != null and get_cell_tile_data({coords}).get_custom_data({name})", "Tilemap", "tile at {coords} has {name} set", "True when the tile at a cell carries the named custom data - how a tileset marks walls, water or ladders.", "TileMapLayer").param("coords", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression").param("name", "\"solid\"", "Data", "The custom data layer's name."))
	descriptors.append(F.act("TileMapClear", "Clear Tilemap", "clear()", "Tilemap", "Clear the tilemap layer", "Wipes every tile from the tilemap layer, leaving it blank.", "TileMapLayer"))
	descriptors.append(F.cond("TileMapCellIsEmpty", "Cell Is Empty", "get_cell_source_id({coords}) == -1", "Tilemap", "Cell {coords} is empty", "True when the chosen tilemap cell has no tile in it.", "TileMapLayer").param("coords", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression"))
	descriptors.append(F.cond("TileMapCellHasSource", "Cell Has Tile", "get_cell_source_id({coords}) != -1", "Tilemap", "Cell {coords} has a tile", "True when the chosen tilemap cell actually has a tile placed.", "TileMapLayer").param("coords", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression"))
	descriptors.append(F.expr("TileMapGetCellSourceId", "Tile At", "get_cell_source_id({coords})", "Tilemap", "TileAt({coords})", "Returns which tileset the tile at a cell came from, or -1 when the cell is empty.", "TileMapLayer").param("coords", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression"))
	descriptors.append(F.expr("TileMapGetCellAtlasCoords", "Cell Atlas Coords", "get_cell_atlas_coords({coords})", "Tilemap", "cell {coords} atlas coords", "Returns which tile in the atlas sits at the given cell.", "TileMapLayer").param("coords", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression"))
	descriptors.append(F.expr("TileMapUsedCellsCount", "Used Cells Count", "get_used_cells().size()", "Tilemap", "used cells count", "Returns how many cells in the tilemap currently hold a tile.", "TileMapLayer"))
	descriptors.append(F.expr("TileMapLocalToMap", "Position To Tile", "local_to_map({pos})", "Tilemap", "PositionToTile({pos})", "Converts a pixel position into the cell coordinates that contain it.", "TileMapLayer").param("pos", "Vector2(0, 0)", "Position", "Local-space position (Vector2).", "expression"))
	descriptors.append(F.expr("TileMapMapToLocal", "Tile To Position", "map_to_local({coords})", "Tilemap", "TileToPosition({coords})", "Converts cell coordinates into the pixel position at that cell's center.", "TileMapLayer").param("coords", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression"))

	_add_level_queries(descriptors)
	_add_painting(descriptors)
	_add_layer_files(descriptors)

	return descriptors


## THE QUESTIONS A LEVEL IS ASKED. What a tile carries, whether a cell is solid, where a line first
## meets something solid, which cells touch a cell, which cells carry a value, how big the level is,
## how much of one tile is left, and which cell a node stands on. Every one of them is a question a
## game asks of the ground under it, and every one of them is three or four engine calls by hand.
static func _add_level_queries(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.expr("TileMapDataAt", "Tile Data At", "%s({target}, {where}, {key})" % DATA_AT, "Tilemap", "tile data {key} at {where}", "What the tile at a place carries under one of its tileset's custom data layers - the \"surface\" that says ice, the \"cost\" a path search adds up. Give it a cell, or a global position and it finds the cell holding it. Answers null where there is no tile.", "TileMapLayer").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("where", "Vector2i(0, 0)", "At", WHERE_WORDS, "expression").param("key", "\"surface\"", "Data", DATA_KEY_WORDS, "tile_data_key").featured())
	descriptors.append(F.cond("TileMapDataAtIs", "Tile Data At Is", "%s({target}, {where}, {key}) == {value}" % DATA_AT, "Tilemap", "tile data {key} at {where} is {value}", "True when the tile at a place carries this value under the named custom data layer. \"Is the player standing on ice\" as one row, rather than a cell lookup, a null guard and a data read written out by hand.", "TileMapLayer").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("where", "Vector2i(0, 0)", "At", WHERE_WORDS, "expression").param("key", "\"surface\"", "Data", DATA_KEY_WORDS, "tile_data_key").param("value", "\"ice\"", "Is", "The value to compare what the tile carries against.", "expression").featured())
	descriptors.append(F.cond("TileMapCellIsSolid", "Cell Is Solid", "%s({target}, {cell}, {layer})" % CELL_IS_SOLID, "Tilemap", "cell {cell} is solid", "True when the tile at a cell carries a collision shape on the tileset physics layer you name - what a path search, a dig tool and a \"can I stand here\" test are all really asking.", "TileMapLayer").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("cell", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression").param("layer", "0", "Physics layer", "Which of the TILESET's physics layers to look at, by its number in the tileset - not a project collision layer.", "expression"))
	descriptors.append(F.expr("TileMapFirstSolidCellAlong", "First Solid Cell Along", "%s({target}, {from}, {to}, {layer})" % FIRST_SOLID, "Tilemap", "first solid cell from {from} to {to}", "Walks the cells along a line and answers the first one whose tile is solid - line of sight, a laser stopping at a wall, a jump arc meeting the ground, with no physics query at all. Answers Vector2i.MAX when the line reaches its end having met nothing.", "TileMapLayer").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("from", "Vector2i(0, 0)", "From", WHERE_WORDS, "expression").param("to", "Vector2i(8, 0)", "To", WHERE_WORDS, "expression").param("layer", "0", "Physics layer", "Which of the TILESET's physics layers counts as solid, by its number in the tileset.", "expression"))
	descriptors.append(F.expr("TileMapSurroundingCells", "Surrounding Cells Of", "get_surrounding_cells({cell})", "Tilemap", "surrounding cells of {cell}", "The cells that touch a cell, as a list. It asks the LAYER rather than doing the arithmetic, so a hex or isometric map answers with its own neighbours instead of a square's four. Feed it to a For Each.", "TileMapLayer").param("cell", "Vector2i(0, 0)", "Cell", "The cell whose neighbours you want.", "expression"))
	descriptors.append(F.expr("TileMapCellsWithData", "Cells With Data", "%s({target}, {key}, {value})" % CELLS_WITH_DATA, "Tilemap", "cells with {key} = {value}", "Every cell of the layer whose tile carries this value under the named custom data layer, as a list - every spawn point, every water tile, every door the level was drawn with. Feed it to a For Each.", "TileMapLayer").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("key", "\"surface\"", "Data", DATA_KEY_WORDS, "tile_data_key").param("value", "\"water\"", "Is", "The value a cell's tile must carry to be in the list.", "expression"))
	descriptors.append(F.expr("TileMapUsedRect", "Used Rect", "get_used_rect()", "Tilemap", "used rect", "The rectangle of cells the layer actually holds tiles in, as a Rect2i. This is the number a camera's limits are set from, and how a level knows how big it is without anybody typing its size a second time.", "TileMapLayer"))
	descriptors.append(F.expr("TileMapCellCountOf", "Cell Count Of", "get_used_cells_by_id({source_id}, {atlas_coords}).size()", "Tilemap", "count of tile {atlas_coords}", "How many cells hold one particular tile - coins left on the level, walls still standing, how much of the board one colour covers.", "TileMapLayer").param("source_id", "0", "Tileset", "Tile source id.", "expression").param("atlas_coords", "Vector2i(0, 0)", "Tile", "Which tile of the tileset (atlas coordinates).", "expression"))
	descriptors.append(F.expr("TileMapTileUnder", "Tile Under", "{target}.local_to_map({target}.to_local({node}.global_position))", "Tilemap", "tile under {node}", "Which cell of the layer a node stands on, as map coordinates - the number every other tile row takes. It goes through the layer's own transform, so a scrolled, rotated or scaled map still answers correctly.", "TileMapLayer").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("node", "self", "Node", "The node whose cell you want.", "scene_node"))


## THE PAINTING WORDS. Terrain first, because a dug hole with broken autotile edges is the thing
## that makes hand-written tile editing look wrong; then the bulk shapes a level editor needs, and
## the two switches a door or a bridge throws.
static func _add_painting(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("TileMapPaintTerrain", "Paint Terrain", "set_cells_terrain_connect({cells}, {terrain_set}, {terrain})", "Tilemap", "Paint terrain {terrain} on {cells}", "Paints a list of cells with one terrain and lets the tileset choose each tile, so edges, corners and joins draw themselves. This is what makes a placed wall or a filled hole look like it was always there.", "TileMapLayer").param("cells", "[Vector2i(0, 0)]", "Cells", "The cells to paint, as a list of Vector2i.", "expression").param("terrain_set", "0", "Terrain set", "Which terrain set of the tileset, by its number.", "expression").param("terrain", "0", "Terrain", "Which terrain in that set. -1 means no terrain at all, which is how a hole is left clean.", "tile_terrain").featured())
	descriptors.append(F.act("TileMapRepaintTerrainAround", "Repaint Terrain Around", "{target}.set_cells_terrain_connect(%s({target}, {where}, {radius}), {terrain_set}, {terrain})" % CELLS_AROUND, "Tilemap", "Repaint terrain around {where}", "Runs the terrain join again over the cells around a place, so tiles left with broken edges by an explosion or a placed block heal themselves. Leave the terrain at -1 to say those cells hold no terrain, which is what the inside of a hole is.", "TileMapLayer").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("where", "Vector2i(0, 0)", "Around", WHERE_WORDS, "expression").param("radius", "3", "Cells", "How far out from there to repaint, counted in cells.", "expression").param("terrain_set", "0", "Terrain set", "Which terrain set of the tileset, by its number.", "expression").param("terrain", "-1", "Terrain", "Which terrain those cells now hold. -1 means none, which is what an emptied circle is.", "tile_terrain"))
	descriptors.append(F.act("TileMapFillRect", "Fill Rect With Tile", "%s({target}, {rect}, {source_id}, {atlas_coords})" % FILL_RECT, "Tilemap", "Fill {rect} with tile {atlas_coords}", "Paints every cell of a rectangle with one tile - a floor, a platform, a room's worth of wall, in one row instead of two loops.", "TileMapLayer").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("rect", "Rect2i(0, 0, 8, 1)", "Rect", "The rectangle of CELLS to fill (Rect2i).", "expression").param("source_id", "0", "Tileset", "Tile source id.", "expression").param("atlas_coords", "Vector2i(0, 0)", "Tile", "Which tile of the tileset (atlas coordinates).", "expression"))
	descriptors.append(F.act("TileMapEraseCircle", "Erase Tiles In Circle", "%s({target}, {where}, {radius})" % ERASE_CIRCLE, "Tilemap", "Erase tiles within {radius} of {where}", "Clears every cell within so many cells of a place - the crater a bomb leaves, the hole a drill makes. Give it a cell or a global position. Follow it with Repaint Terrain Around so the rim joins up again.", "TileMapLayer").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("where", "Vector2i(0, 0)", "At", WHERE_WORDS, "expression").param("radius", "3", "Cells", "How far the circle reaches, counted in cells.", "expression"))
	descriptors.append(F.act("TileMapFloodFill", "Flood Fill", "%s({target}, {cell}, {source_id}, {atlas_coords}, {limit})" % FLOOD_FILL, "Tilemap", "Flood fill from {cell} with {atlas_coords}", "The paint bucket: spreads one tile out from a cell across every touching cell holding whatever the starting cell held. It stops at the cell limit you set, so a fill let loose on open ground cannot run away with the frame.", "TileMapLayer").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("cell", "Vector2i(0, 0)", "From", "The cell the fill starts at. Whatever tile is there is what the fill spreads across.", "expression").param("source_id", "0", "Tileset", "Tile source id of the tile being painted.", "expression").param("atlas_coords", "Vector2i(0, 0)", "Tile", "Which tile of the tileset to paint (atlas coordinates).", "expression").param("limit", "4096", "Most cells", "The most cells one fill may paint. The stop that keeps an unbounded fill honest.", "expression"))
	descriptors.append(F.act("TileMapSetNavigation", "Set Navigation On Layer", "navigation_enabled = {on}", "Tilemap", "Set navigation on layer {on}", "Turns the layer's navigation regions on or off - what a door opening or a bridge dropping has to do before agents will route through it.", "TileMapLayer").param("on", true, "On", "Whether this layer builds navigation for agents.", ""))
	descriptors.append(F.act("TileMapSetCollision", "Set Collision On Layer", "collision_enabled = {on}", "Tilemap", "Set collision on layer {on}", "Turns the layer's collision on or off - a ghost phase, a drop-through floor, a background layer that should never stop anything.", "TileMapLayer").param("on", true, "On", "Whether this layer's tiles collide.", ""))


## THE LEVEL AS A FILE. Tiles saved and read back as the bytes the engine itself keeps them in, and
## one layer copied onto another - which is a level editor's undo step, taken twice.
static func _add_layer_files(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("TileMapSaveLayer", "Save Layer To File", "%s({target}, {path})" % SAVE_LAYER, "Tilemap", "Save layer to {path}", "Writes the layer's tiles to a file, exactly as the engine stores them. This is a level the player built, kept - Load Layer From File reads it straight back.", "TileMapLayer").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("path", "\"user://levels/mine.tiles\"", "File", "Where to write it. user:// is the player's own folder, which is the only place a running game may write.", "file_path"))
	descriptors.append(F.act("TileMapLoadLayer", "Load Layer From File", "%s({target}, {path})" % LOAD_LAYER, "Tilemap", "Load layer from {path}", "Puts the tiles from a file back onto the layer, replacing whatever it held. A file that is not there leaves the layer alone rather than clearing it.", "TileMapLayer").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("path", "\"user://levels/mine.tiles\"", "File", "The file to read. user:// is the player's own folder.", "file_path"))
	descriptors.append(F.act("TileMapCopyLayer", "Copy Layer", "{target}.tile_map_data = {from}.tile_map_data", "Tilemap", "Copy layer from {from}", "Copies every tile of one layer onto another in one go, as the bytes the engine keeps them in. A level editor's undo is two of these: one onto a spare layer before the edit, and one back afterwards.", "TileMapLayer").param("target", "self", "Onto", "The layer that receives the tiles.", "expression").param("from", "self", "From", "The layer the tiles are copied from.", "expression"))
