# EventForge - this project imports on one thread, because Godot 4.7 crashes importing several
# compute-shader .glsl files at once. The Post Kit pack ships six of them (and its builder's source
# folder six more); with threaded import on, a first `--import` of a fresh copy could die with an
# access violation - always just after the translation CSVs, where the .glsl group starts. Every
# file after that point stayed unimported, so the next test run failed all 141 pack_icons_test
# "icon.svg is imported" checks and drawing_prefab_perf_test's stamp texture, and the run after it
# passed because the import had been finished in between.
# Measured on fresh copies of ff3cf143 outside OneDrive, threaded: 6 of 17 imports stopped half way
# with the plugin enabled and 1 of 15 with it disabled; with a single .glsl left, 0 of 6; with none,
# 0 of 6. On one thread, every .glsl in place: 0 of 6 (a fresh import takes about 90 s, not 55 s).
@tool
class_name ImportThreadsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	return SUPPORT.check("import_threads_test", "the project imports on one thread",
		ProjectSettings.get_setting("editor/import/use_multiple_threads", true), false)
