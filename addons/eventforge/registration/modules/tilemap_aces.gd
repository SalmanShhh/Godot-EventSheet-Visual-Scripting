# EventForge module — Tilemaps (TileMapLayer, Godot 4.3+)
#
# set/erase/clear cells, query cell source/atlas, and map<->local coordinate conversion.
# Lane-1 wraps of native TileMapLayer methods, single-line per the parity contract; coords
# are Vector2i expressions (the ƒx field serves them). Targets TileMapLayer (the legacy
# TileMap node uses a layer-index arg these omit). Module contract: see ace_factory.gd.
@tool
extends RefCounted
class_name EventForgeTileMapACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "TileMapSetCell", "Set Cell", ACEDescriptor.ACEType.ACTION, "set_cell({coords}, {source_id}, {atlas_coords})", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression"), F.make_param("source_id", "String", "0", "Source", "Tile source id.", "expression"), F.make_param("atlas_coords", "String", "Vector2i(0, 0)", "Atlas Coords", "Atlas coordinates (Vector2i).", "expression")], "Tilemap", "Set cell {coords} to source {source_id}", "TileMapLayer"))
	descriptors.append(F.make_descriptor("Core", "TileMapEraseCell", "Erase Cell", ACEDescriptor.ACEType.ACTION, "erase_cell({coords})", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression")], "Tilemap", "Erase cell {coords}", "TileMapLayer"))
	descriptors.append(F.make_descriptor("Core", "TileMapClear", "Clear Tilemap", ACEDescriptor.ACEType.ACTION, "clear()", "", [], "Tilemap", "Clear the tilemap layer", "TileMapLayer"))
	descriptors.append(F.make_descriptor("Core", "TileMapCellIsEmpty", "Cell Is Empty", ACEDescriptor.ACEType.CONDITION, "get_cell_source_id({coords}) == -1", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression")], "Tilemap", "Cell {coords} is empty", "TileMapLayer"))
	descriptors.append(F.make_descriptor("Core", "TileMapCellHasSource", "Cell Has Tile", ACEDescriptor.ACEType.CONDITION, "get_cell_source_id({coords}) != -1", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression")], "Tilemap", "Cell {coords} has a tile", "TileMapLayer"))
	descriptors.append(F.make_descriptor("Core", "TileMapGetCellSourceId", "Cell Source Id", ACEDescriptor.ACEType.EXPRESSION, "get_cell_source_id({coords})", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression")], "Tilemap", "cell {coords} source id", "TileMapLayer"))
	descriptors.append(F.make_descriptor("Core", "TileMapGetCellAtlasCoords", "Cell Atlas Coords", ACEDescriptor.ACEType.EXPRESSION, "get_cell_atlas_coords({coords})", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression")], "Tilemap", "cell {coords} atlas coords", "TileMapLayer"))
	descriptors.append(F.make_descriptor("Core", "TileMapUsedCellsCount", "Used Cells Count", ACEDescriptor.ACEType.EXPRESSION, "get_used_cells().size()", "", [], "Tilemap", "used cells count", "TileMapLayer"))
	descriptors.append(F.make_descriptor("Core", "TileMapLocalToMap", "Local To Map", ACEDescriptor.ACEType.EXPRESSION, "local_to_map({pos})", "", [F.make_param("pos", "String", "Vector2(0, 0)", "Local Position", "Local-space position (Vector2).", "expression")], "Tilemap", "local {pos} to map", "TileMapLayer"))
	descriptors.append(F.make_descriptor("Core", "TileMapMapToLocal", "Map To Local", ACEDescriptor.ACEType.EXPRESSION, "map_to_local({coords})", "", [F.make_param("coords", "String", "Vector2i(0, 0)", "Cell", "Cell coordinates (Vector2i).", "expression")], "Tilemap", "map {coords} to local", "TileMapLayer"))

	return descriptors
