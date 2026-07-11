class_name EnemyStats
extends Resource

# @inspector_header Combat #e06666
## Damage rolled per hit - x is the low end, y the high.
@export_group("Combat")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:min_max:0:60") var combat_damage_range: Vector2 = Vector2(4.0, 11.0)
## Damage multiplier over distance.
@export_group("Combat")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:curve_editor") var combat_falloff: Curve = null
## Drop table - one row per possible drop.
@export_group("Combat")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:item=String,count=int,rare=bool") var combat_loot: Array = []
## Hit points - drag the bar.
@export_group("Combat")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:progress_bar:0:200") var combat_max_health: int = 120:
	set(value):
		combat_max_health = clampi(value, 0, 200)
# @inspector_header Identity #3aa6e0
## Shown in dialogs and the bestiary.
@export_group("Identity")
@export_placeholder("e.g. Cave Rat") var id_display_name: String = "Cave Rat"
# @inspector_required
## Bestiary portrait.
@export_group("Identity")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:texture_preview") var id_portrait: Texture2D = null
## Body tint - click a swatch.
@export_group("Identity")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var id_tint: Color = Color(0.54117649793625, 0.35294118523598, 0.23137255012989, 1.0)
# @inspector_header Spawning
# @inspector_info Shared resource - edits affect every enemy that references it.
## Seconds between spawns - low end to high end.
@export_group("Spawning")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:min_max:0:30") var spawn_gap: Vector2 = Vector2(8.0, 20.0)


func roll_damage() -> float:
	return randf_range(combat_damage_range.x, combat_damage_range.y)

# [b]EnemyStats[/b] - a Custom Resource whose Inspector was [b]designed from this sheet[/b]: accent section headers, an info note, a [b]required[/b] portrait slot (red warning until assigned), a min-max damage range, a [b]loot table edited as a grid[/b], a clamped health bar, swatches, and an inline curve. Click [i]enemy_stats_example.tres[/i] in the FileSystem to see it; every marker is a plain comment or annotation, so the resource works without the plugin.
