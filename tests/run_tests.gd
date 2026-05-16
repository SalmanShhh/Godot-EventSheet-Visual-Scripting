# EventForge — Test runner entrypoint
# Runs all repository tests in headless Godot.
@tool
extends SceneTree
class_name EventForgeTestRunner

const CompileDemoTestScript = preload("res://tests/compile_demo_test.gd")
const BuiltinACEMetadataTestScript = preload("res://tests/builtin_ace_metadata_test.gd")
const CompilerTriggerBehaviorTestScript = preload("res://tests/compiler_trigger_behavior_test.gd")
const VariableRowFormatTestScript = preload("res://tests/variable_row_format_test.gd")

## Executes all EventForge tests and exits with status code.
func _init() -> void:
	var passed: bool = (
		CompileDemoTestScript.run()
		and BuiltinACEMetadataTestScript.run()
		and CompilerTriggerBehaviorTestScript.run()
		and VariableRowFormatTestScript.run()
	)
	if passed:
		print("All tests passed.")
		quit(0)
	else:
		push_error("Some tests failed.")
		quit(1)
