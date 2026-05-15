# EventForge — Test runner entrypoint
@tool
extends SceneTree
class_name EventForgeTestRunner

## Executes all EventForge tests and exits with status code.
func _init() -> void:
var passed: bool = true
passed = CompileDemoTest.run() and passed
if passed:
print("All tests passed.")
quit(0)
else:
push_error("Some tests failed.")
quit(1)
