class_name MirrorAndFlip
extends Node2D

## Mirror the panel. The pivot moves to its middle first, which is why it mirrors in place instead of jumping sideways.
@export var mirror_ui: bool = true
## Mirror what the sub-viewport shows - the rear-view-mirror trick.
@export var mirror_view: bool = true
## Flip the third tile, so one wall drawing covers both sides of the corridor.
@export var flip_tile: bool = true
var __every_turn: float = 0.0

func _ready() -> void:
	$Panel.pivot_offset.x = $Panel.size.x * 0.5
	$Panel.scale.x = -1.0 if mirror_ui else 1.0
	$Mirror.pivot_offset.x = $Mirror.size.x * 0.5
	$Mirror.scale.x = -1.0 if mirror_view else 1.0
	$Tiles.set_cell(Vector2i(2, 0), $Tiles.get_cell_source_id(Vector2i(2, 0)), $Tiles.get_cell_atlas_coords(Vector2i(2, 0)), TileSetAtlasSource.TRANSFORM_FLIP_H if flip_tile else 0)

func _process(delta: float) -> void:
	__every_turn += delta
	if __every_turn >= maxf(2.0, 0.001):
		__every_turn = fmod(__every_turn, maxf(2.0, 0.001))
		$Mirror/View/Twin.rotate_y(PI)

# [b]Mirror and Flip[/b] - one verb, every host. The [b]hero[/b] mirrors as a whole object and drags its ray, its muzzle and its dust along. The [b]panel[/b] mirrors in place because its pivot moves to the middle first. The [b]sub-viewport[/b] mirrors its view. The third [b]tile[/b] carries the flip bit, so one drawing covers both sides. The [b]3D twin[/b] does NOT scale itself negative - it turns around, which is the honest 3D answer and leaves nothing inside out.
