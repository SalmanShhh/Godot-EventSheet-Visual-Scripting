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

	descriptors.append(F.make_descriptor("Core", "TileMapSetCell", "Set Tile", ACEDescriptor.ACEType.ACTION, "set_cell({coords}, {source_id}, {atlas_coords})", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression"), F.make_param("source_id", "String", "0", "Tileset", "Tile source id.", "expression"), F.make_param("atlas_coords", "String", "Vector2i(0, 0)", "Tile", "Which tile of the tileset (atlas coordinates).", "expression")], "Tilemap", "Set tile at {coords} to {atlas_coords}", "TileMapLayer")
		.described("Paints a tile at a grid cell, choosing which tileset and which tile of it to use."))
	descriptors.append(F.make_descriptor("Core", "TileMapEraseCell", "Erase Tile", ACEDescriptor.ACEType.ACTION, "erase_cell({coords})", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression")], "Tilemap", "Erase tile at {coords}", "TileMapLayer")
		.described("Clears the tile at a single grid cell, leaving it empty."))
	# The tile's own data, asked as one question - the guard and the lookup the hand-written shape
	# spells over two lines, in the one condition the sheet has for it.
	descriptors.append(F.make_descriptor("Core", "TileMapTileHasCustomData", "Tile Has Custom Data", ACEDescriptor.ACEType.CONDITION, "get_cell_tile_data({coords}) != null and get_cell_tile_data({coords}).get_custom_data({name})", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression"), F.make_param("name", "String", "\"solid\"", "Data", "The custom data layer's name.")], "Tilemap", "tile at {coords} has {name} set", "TileMapLayer")
		.described("True when the tile at a cell carries the named custom data - how a tileset marks walls, water or ladders."))
	descriptors.append(F.make_descriptor("Core", "TileMapClear", "Clear Tilemap", ACEDescriptor.ACEType.ACTION, "clear()", "", [], "Tilemap", "Clear the tilemap layer", "TileMapLayer")
		.described("Wipes every tile from the tilemap layer, leaving it blank."))
	descriptors.append(F.make_descriptor("Core", "TileMapCellIsEmpty", "Cell Is Empty", ACEDescriptor.ACEType.CONDITION, "get_cell_source_id({coords}) == -1", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression")], "Tilemap", "Cell {coords} is empty", "TileMapLayer")
		.described("True when the chosen tilemap cell has no tile in it."))
	descriptors.append(F.make_descriptor("Core", "TileMapCellHasSource", "Cell Has Tile", ACEDescriptor.ACEType.CONDITION, "get_cell_source_id({coords}) != -1", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression")], "Tilemap", "Cell {coords} has a tile", "TileMapLayer")
		.described("True when the chosen tilemap cell actually has a tile placed."))
	descriptors.append(F.make_descriptor("Core", "TileMapGetCellSourceId", "Tile At", ACEDescriptor.ACEType.EXPRESSION, "get_cell_source_id({coords})", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression")], "Tilemap", "TileAt({coords})", "TileMapLayer")
		.described("Returns which tileset the tile at a cell came from, or -1 when the cell is empty."))
	descriptors.append(F.make_descriptor("Core", "TileMapGetCellAtlasCoords", "Cell Atlas Coords", ACEDescriptor.ACEType.EXPRESSION, "get_cell_atlas_coords({coords})", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression")], "Tilemap", "cell {coords} atlas coords", "TileMapLayer")
		.described("Returns which tile in the atlas sits at the given cell."))
	descriptors.append(F.make_descriptor("Core", "TileMapUsedCellsCount", "Used Cells Count", ACEDescriptor.ACEType.EXPRESSION, "get_used_cells().size()", "", [], "Tilemap", "used cells count", "TileMapLayer")
		.described("Returns how many cells in the tilemap currently hold a tile."))
	descriptors.append(F.make_descriptor("Core", "TileMapLocalToMap", "Position To Tile", ACEDescriptor.ACEType.EXPRESSION, "local_to_map({pos})", "", [F.make_param("pos", "String", "Vector2(0, 0)", "Position", "Local-space position (Vector2).", "expression")], "Tilemap", "PositionToTile({pos})", "TileMapLayer")
		.described("Converts a pixel position into the cell coordinates that contain it."))
	descriptors.append(F.make_descriptor("Core", "TileMapMapToLocal", "Tile To Position", ACEDescriptor.ACEType.EXPRESSION, "map_to_local({coords})", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression")], "Tilemap", "TileToPosition({coords})", "TileMapLayer")
		.described("Converts cell coordinates into the pixel position at that cell's center."))

	return descriptors
