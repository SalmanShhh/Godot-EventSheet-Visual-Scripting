# Regenerates every bundled pack (eventsheet_addons/) from its per-pack builder in
# tools/pack_builders/ - one pack per file, shared scaffold in _lib.gd. Run:
#   godot --headless --path . --script tools/build_sample_behaviors.gd
# Faithfulness gate: tools/audit_addons.gd must report drifted=0 afterwards.
@tool
extends SceneTree

const PACK_BUILDERS: Array[String] = [
	"platformer",
	"eight_direction",
	"timer",
	"flash",
	"spring",
	"tween",
	"save_system",
	"state_machine",
	"sine",
	"orbit",
	"bullet",
	"move_to",
	"follow",
	"drag_drop",
	"car",
	"tile_movement",
	"line_of_sight",
	"line_of_sight_3d",
	"sine_3d",
	"orbit_3d",
	"bullet_3d",
	"move_to_3d",
	"health",
	"virtual_cursor",
	"weapon_kit",
	"htn_agent",
	"advanced_random",
	"abilities",
	"juice",
	"time_slicer",
	"background_runner",
	"hud_kit",
	"scene_flow",
	"dialogue_kit",
	"currency_ledger",
	"loot_table",
	"storylet_weaver",
	"skin_vault",
	"proc_room",
	"utility_ai",
	"combo_box",
	"physics_car",
	"fade",
	"slide_move",
	"object_pool",
	"loot_table_resource",
	"loot_loader",
	"skin_catalog_resource",
	"skin_catalog_loader",
	"big_number",
	"idle_generator",
	"prestige",
	"upgrades",
	"milestones",
	"click_power",
	"boosts",
]


func _init() -> void:
	var ok: bool = true
	for builder_name: String in PACK_BUILDERS:
		var builder: GDScript = load("res://tools/pack_builders/%s.gd" % builder_name)
		ok = bool(builder.call("build")) and ok
	if not ok:
		push_error("[build_sample_behaviors] one or more packs failed - see errors above.")
	quit()
