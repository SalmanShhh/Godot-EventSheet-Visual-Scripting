# EventForge — Test runner entrypoint
# Runs all repository tests in headless Godot.
@tool
extends SceneTree
class_name EventForgeTestRunner

## Executes all EventForge tests and exits with status code.
func _init() -> void:
	var passed: bool = true
	passed = CompileDemoTest.run() and passed
	passed = VariableRowFormatTest.run() and passed
	passed = ACEMetadataTest.run() and passed
	if passed:
		print("All tests passed.")
		quit(0)
	else:
		push_error("Some tests failed.")
		quit(1)
