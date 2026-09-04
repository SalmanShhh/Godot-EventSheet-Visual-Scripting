# Fixture pack builder: ships a ROOT runtime script, not a pack folder - the shape
# eventsheet_addons/free_spot.gd and pooled_nodes.gd have. The destination has no folder after
# eventsheet_addons/, so tools/measure_packs.gd must not count it.
@tool

const Lib := preload("res://tests/fixtures/pack_count_builders/_lib.gd")


static func build() -> bool:
	var sheet: Variant = null
	return Lib.save_pack(sheet, "res://eventsheet_addons/fixture_root_runtime", "")
