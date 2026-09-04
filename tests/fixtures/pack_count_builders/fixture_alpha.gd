# Fixture pack builder: publishes a pack FOLDER through Lib.publish, so it counts. Named
# differently from the folder it publishes (alpha -> fixture_alpha_pack), which pins that
# tools/measure_packs.gd reads the destination string and not the builder's file name.
@tool

const Lib := preload("res://tests/fixtures/pack_count_builders/_lib.gd")


static func build() -> bool:
	var source: Variant = null
	return Lib.publish(source, "res://eventsheet_addons/fixture_alpha_pack/fixture_alpha_behavior")
