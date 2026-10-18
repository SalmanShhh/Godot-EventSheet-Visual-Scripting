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
#
# A project that installs Post Kit has threaded import on by default and meets the same crash, so the
# Doctor names the switch there: a warning with two or more compute shaders on several threads, and
# silence on one thread or with a single shader.
@tool
class_name ImportThreadsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var six: PackedStringArray = PackedStringArray()
	for index: int in 6:
		six.append("res://eventsheet_addons/post_kit/effects/post_%d.glsl" % index)
	var threaded: Dictionary = EventSheetProjectDoctor.threaded_shader_import_finding(true, six)
	return SUPPORT.pins("import_threads_test", [
		["the project imports on one thread",
			ProjectSettings.get_setting("editor/import/use_multiple_threads", true), false],
		["several shaders on several threads earn the Doctor's warning",
			[threaded.get("severity"), threaded.get("check"), threaded.get("subject")],
			["warning", "threaded-shader-import", "editor/import/use_multiple_threads"]],
		["which counts the shaders", str(threaded.get("message", "")).begins_with("6 compute shaders"), true],
		["on one thread it says nothing", EventSheetProjectDoctor.threaded_shader_import_finding(false, six), {}],
		["nor with a single shader",
			EventSheetProjectDoctor.threaded_shader_import_finding(true, six.slice(0, 1)), {}],
	])
