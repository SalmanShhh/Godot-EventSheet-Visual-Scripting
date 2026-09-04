# Fixture pack builder: publishes a pack FOLDER through the other shipping door, Lib.save_pack, so
# it counts too. Both spellings are in the fixture because a measurement that only knew one of them
# would read the live tree fifteen packs short and still look right.
@tool

const Lib := preload("res://tests/fixtures/pack_count_builders/_lib.gd")


static func build() -> bool:
	var sheet: Variant = null
	return Lib.save_pack(sheet, "res://eventsheet_addons/fixture_beta/fixture_beta_behavior")
