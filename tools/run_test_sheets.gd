# EventForge - run every Test sheet in the project, headlessly, and print a verdict.
#
#   godot --headless --path . --script tools/run_test_sheets.gd
#   godot --headless --path . --script tools/run_test_sheets.gd -- --root user://my_tests --timeout 10
#
# The work is the plugin's own command (addons/eventsheet/editor/test_sheet_command.gd), the same one
# the editor's Tools > Run Tests... window starts as a second process, so this command and that
# window print the same lines. Exits 0 when the run ends "All tests passed." and 1 when it ends
# "Some tests failed.".
@tool
extends "res://addons/eventsheet/editor/test_sheet_command.gd"
