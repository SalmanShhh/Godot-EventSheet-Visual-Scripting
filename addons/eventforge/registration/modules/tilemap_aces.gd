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

	return descriptors
