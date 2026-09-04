# EventForge module - GridMaps (the 3D twin of the tilemap words).
#
# A GridMap is a MeshLibrary laid out on a 3D grid, and the questions a game asks of it are the
# questions it asks of a tilemap layer with one more axis: put an item in a cell, ask what is in a
# cell, ask whether a cell holds anything, list the cells that do, and fill or clear a box of them.
# Those six are here under the same words their 2D twins use, so a reader who learned one knows the
# other.
#
# WHAT HAS NO TWIN, said plainly rather than faked: a GridMap has no tileset, so it has no custom
# data layers and no terrains. Tile Data At, Cells With Data, Paint Terrain and Repaint Terrain
# Around are 2D words and stay 2D words - a 3D game that wants "which cells are lava" keeps that in
# a collection or a group, the way it would for any other 3D scenery. Nothing here pretends
# otherwise.
#
# Lane-1 wraps of native GridMap methods, single-line per the parity contract; cells are Vector3i
# expressions (the fx field serves them). Module contract: see ace_factory.gd.
@tool
class_name EventForgeGridMapACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The shelf these six file under. Read as a class name by the picker, so the section wears the
## engine's own GridMap icon without anybody choosing one.
const CAT := "GridMap"

## The emitted helper both box words call. The compiler writes its definition into the file the
## first time either appears, so a level that fills boxes and clears them gains the plumbing once.
## Erasing IS filling with the invalid item - that is how the engine itself empties a cell - so the
## two rows are one function with a different last argument, and the emitted code says so.
const FILL_BOX := "__eventsheets_gridmap_fill_box"

## The sentence every "On node" field on the box rows reads with, written once.
const ON_NODE_WORDS := "The GridMap this works on. Leave it as self for the one this sheet is on, or name another."


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.act("GridMapSetCellItem", "Set Cell Item", "set_cell_item({cell}, {item}, {orientation})", CAT, "Set cell {cell} to item {item}", "Puts one item of the mesh library into a grid cell, turned the way you say. This is the 3D twin of Set Tile. Note what has no 3D twin: a GridMap has no tileset, so there are no custom data layers and no terrains here - a 3D game keeps \"which cells are lava\" in a collection or a group instead.", "GridMap").param("cell", "Vector3i(0, 0, 0)", "Cell", "Cell coordinates (Vector3i).", "expression").param("item", "0", "Item", "Which item of the mesh library, by its index. -1 empties the cell.", "expression").param("orientation", "0", "Turned", "The item's orientation index, 0 for none.", "expression").featured())
	descriptors.append(F.expr("GridMapItemAt", "Item At", "get_cell_item({cell})", CAT, "item at {cell}", "Which item of the mesh library sits in a cell, by its index, or -1 when the cell is empty. The 3D twin of Tile At.", "GridMap").param("cell", "Vector3i(0, 0, 0)", "Cell", "Cell coordinates (Vector3i).", "expression"))
	descriptors.append(F.cond("GridMapCellIsFilled", "Cell Is Filled", "get_cell_item({cell}) != GridMap.INVALID_CELL_ITEM", CAT, "cell {cell} is filled", "True when the grid cell holds an item - the 3D twin of Cell Has Tile, and what a builder asks before it puts something there.", "GridMap").param("cell", "Vector3i(0, 0, 0)", "Cell", "Cell coordinates (Vector3i).", "expression"))
	descriptors.append(F.expr("GridMapUsedCells", "Used Cells", "get_used_cells()", CAT, "used cells", "Every cell of the grid that holds an item, as a list of Vector3i. Feed it to a For Each to walk the level that was actually built.", "GridMap"))
	descriptors.append(F.act("GridMapFillBox", "Fill Box", "%s({target}, {from}, {to}, {item})" % FILL_BOX, CAT, "Fill box {from} to {to} with item {item}", "Puts one item into every cell of a box of grid cells - a floor, a wall, a solid block of the level, in one row instead of three loops. The two corners may be given in any order.", "GridMap").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("from", "Vector3i(0, 0, 0)", "From", "One corner of the box, in cells (Vector3i).", "expression").param("to", "Vector3i(4, 0, 4)", "To", "The opposite corner, in cells (Vector3i).", "expression").param("item", "0", "Item", "Which item of the mesh library, by its index.", "expression"))
	descriptors.append(F.act("GridMapEraseBox", "Erase Box", "%s({target}, {from}, {to}, GridMap.INVALID_CELL_ITEM)" % FILL_BOX, CAT, "Erase box {from} to {to}", "Empties every cell of a box of grid cells - the 3D crater, the room carved out of solid rock. The two corners may be given in any order.", "GridMap").param("target", "self", "On node", ON_NODE_WORDS, "expression").param("from", "Vector3i(0, 0, 0)", "From", "One corner of the box, in cells (Vector3i).", "expression").param("to", "Vector3i(4, 0, 4)", "To", "The opposite corner, in cells (Vector3i).", "expression"))

	return descriptors
