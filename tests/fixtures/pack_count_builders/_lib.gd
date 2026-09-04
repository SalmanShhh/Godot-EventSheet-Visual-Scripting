# Fixture stand-in for tools/pack_builders/_lib.gd, so the fixture builders beside it are real,
# parseable GDScript rather than text that only looks like a builder. A leading underscore marks a
# shared helper, and tools/measure_packs.gd must skip this file the way the build script does - if
# it ever stopped, this fixture would measure one pack too many and pack_count_records_test says so.
@tool


## Mirrors Lib.publish's shape: the destination base path is the second argument.
static func publish(_source: Variant, _base_path: String) -> bool:
	return true


## Mirrors Lib.save_pack's shape, third argument and all.
static func save_pack(_sheet: Variant, _base_path: String, _icon_path: String = "") -> bool:
	return true
