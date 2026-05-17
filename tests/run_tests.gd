# EventForge — Test runner entrypoint
# Runs all repository tests in headless Godot.
@tool
extends SceneTree
class_name EventForgeTestRunner

const CompileDemoTestScript := preload("res://tests/compile_demo_test.gd")
const VariableRowFormatTestScript := preload("res://tests/variable_row_format_test.gd")
const ACEMetadataTestScript := preload("res://tests/ace_metadata_test.gd")
const AutoACESystemTestScript := preload("res://tests/auto_ace_system_test.gd")
const EventSheetEditorTestScript := preload("res://tests/event_sheet_editor_test.gd")
const PluginWorkspaceTestScript := preload("res://tests/plugin_workspace_test.gd")
const WorkspaceShellTestScript := preload("res://tests/workspace_shell_test.gd")

## Executes all EventForge tests and exits with status code.
func _init() -> void:
    var passed: bool = true
    passed = CompileDemoTestScript.run() and passed
    passed = VariableRowFormatTestScript.run() and passed
    passed = ACEMetadataTestScript.run() and passed
    passed = AutoACESystemTestScript.run() and passed
    passed = EventSheetEditorTestScript.run() and passed
    passed = PluginWorkspaceTestScript.run() and passed
    passed = WorkspaceShellTestScript.run() and passed
    if passed:
        print("All tests passed.")
        quit(0)
    else:
        push_error("Some tests failed.")
        quit(1)
