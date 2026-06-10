# EventForge — Test runner entrypoint
# Runs all repository tests in headless Godot.
@tool
extends SceneTree
class_name EventForgeTestRunner

const CompileDemoTestScript := preload("res://tests/compile_demo_test.gd")
const DemoResourceReferenceTestScript := preload("res://tests/demo_resource_reference_test.gd")
const VariableRowFormatTestScript := preload("res://tests/variable_row_format_test.gd")
const ACEMetadataTestScript := preload("res://tests/ace_metadata_test.gd")
const AutoACESystemTestScript := preload("res://tests/auto_ace_system_test.gd")
const EventSheetEditorTestScript := preload("res://tests/event_sheet_editor_test.gd")
const EventSheetStyleTestScript := preload("res://tests/event_sheet_style_test.gd")
const PluginWorkspaceTestScript := preload("res://tests/plugin_workspace_test.gd")
const WorkspaceShellTestScript := preload("res://tests/workspace_shell_test.gd")
const EditorParamExposureTestScript := preload("res://tests/editor_param_exposure_test.gd")
const DocsIntegrityTestScript := preload("res://tests/docs_integrity_test.gd")
const EventLazySpansTestScript := preload("res://tests/event_lazy_spans_test.gd")
const ACEPickerLogicTestScript := preload("res://tests/ace_picker_logic_test.gd")
const ACEParamsLogicTestScript := preload("res://tests/ace_params_logic_test.gd")
const KeyboardActionsTestScript := preload("res://tests/keyboard_actions_test.gd")
const ColumnHeaderTestScript := preload("res://tests/column_header_test.gd")
const ThemePresetsTestScript := preload("res://tests/theme_presets_test.gd")
const CustomACEProviderTestScript := preload("res://tests/custom_ace_provider_test.gd")
const SubEventAuthoringTestScript := preload("res://tests/sub_event_authoring_test.gd")
const SheetFunctionTestScript := preload("res://tests/sheet_function_test.gd")
const MultiTabTestScript := preload("res://tests/multi_tab_test.gd")
const ImporterTestScript := preload("res://tests/importer_test.gd")
const RowLayoutTestScript := preload("res://tests/row_layout_test.gd")
const ACEDragTestScript := preload("res://tests/ace_drag_test.gd")
const HitTestTestScript := preload("res://tests/hit_test_test.gd")
const LaneResizeTestScript := preload("res://tests/lane_resize_test.gd")
const LayoutStateTestScript := preload("res://tests/layout_state_test.gd")
const ACEReorderDragTestScript := preload("res://tests/ace_reorder_drag_test.gd")
const VariableExportTestScript := preload("res://tests/variable_export_test.gd")
const TreeVariableTestScript := preload("res://tests/tree_variable_test.gd")
const CommentNestingTestScript := preload("res://tests/comment_nesting_test.gd")
const ConditionEditTestScript := preload("res://tests/condition_edit_test.gd")
const InlineEditTestScript := preload("res://tests/inline_edit_test.gd")
const DisableSelectionTestScript := preload("res://tests/disable_selection_test.gd")
const SubeventSelectionTestScript := preload("res://tests/subevent_selection_test.gd")
const FooterRowsTestScript := preload("res://tests/footer_rows_test.gd")
const GDScriptPairingTestScript := preload("res://tests/gdscript_pairing_test.gd")
const ProvenanceTestScript := preload("res://tests/provenance_test.gd")
const ACEAddonTestScript := preload("res://tests/ace_addon_test.gd")
const InflowGDScriptTestScript := preload("res://tests/inflow_gdscript_test.gd")
const SnippetShareTestScript := preload("res://tests/snippet_share_test.gd")
const CodegenParityTestScript := preload("res://tests/codegen_parity_test.gd")
const ExternalSheetTestScript := preload("res://tests/external_sheet_test.gd")
const SubeventCompileTestScript := preload("res://tests/subevent_compile_test.gd")
const CustomNodeClassTestScript := preload("res://tests/custom_node_class_test.gd")
const BehaviorFoundationsTestScript := preload("res://tests/behavior_foundations_test.gd")
const BehaviorAuthoringTestScript := preload("res://tests/behavior_authoring_test.gd")
const SampleBehaviorPackTestScript := preload("res://tests/sample_behavior_pack_test.gd")
const PairingPolishTestScript := preload("res://tests/pairing_polish_test.gd")
const ACELiftTestScript := preload("res://tests/ace_lift_test.gd")
const RuntimeProviderTestScript := preload("res://tests/runtime_provider_test.gd")
const VisualCompletenessTestScript := preload("res://tests/visual_completeness_test.gd")
const ReleaseHardeningTestScript := preload("res://tests/release_hardening_test.gd")
const GDScriptPasteTestScript := preload("res://tests/gdscript_paste_test.gd")
const PickFilterTestScript := preload("res://tests/pick_filter_test.gd")
const FxCompletionWatchTestScript := preload("res://tests/fx_completion_watch_test.gd")
const SignalLiftTestScript := preload("res://tests/signal_lift_test.gd")
const IntellisenseTestScript := preload("res://tests/intellisense_test.gd")
const FunctionLiftTestScript := preload("res://tests/function_lift_test.gd")
const BookmarksIncludesTestScript := preload("res://tests/bookmarks_includes_test.gd")
const InspectorPolishTestScript := preload("res://tests/inspector_polish_test.gd")
const EnumRowTestScript := preload("res://tests/enum_row_test.gd")
const UxGuardrailsTestScript := preload("res://tests/ux_guardrails_test.gd")
const CollectionVariablesTestScript := preload("res://tests/collection_variables_test.gd")
const CollectionAcesTestScript := preload("res://tests/collection_aces_test.gd")
const McpServerTestScript := preload("res://tests/mcp_server_test.gd")
const InputTimeAcesTestScript := preload("res://tests/input_time_aces_test.gd")
const GodotFeelTestScript := preload("res://tests/godot_feel_test.gd")
const SignalAutocompleteTestScript := preload("res://tests/signal_autocomplete_test.gd")
const PerfSmokeTestScript := preload("res://tests/perf_smoke_test.gd")

## Executes all EventForge tests and exits with status code.
func _init() -> void:
	var passed: bool = true
	passed = CompileDemoTestScript.run() and passed
	passed = DemoResourceReferenceTestScript.run() and passed
	passed = VariableRowFormatTestScript.run() and passed
	passed = ACEMetadataTestScript.run() and passed
	passed = AutoACESystemTestScript.run() and passed
	passed = EventLazySpansTestScript.run() and passed
	passed = ACEPickerLogicTestScript.run() and passed
	passed = ACEParamsLogicTestScript.run() and passed
	passed = KeyboardActionsTestScript.run() and passed
	passed = ColumnHeaderTestScript.run() and passed
	passed = ThemePresetsTestScript.run() and passed
	passed = CustomACEProviderTestScript.run() and passed
	passed = SubEventAuthoringTestScript.run() and passed
	passed = SheetFunctionTestScript.run() and passed
	passed = MultiTabTestScript.run() and passed
	passed = ImporterTestScript.run() and passed
	passed = RowLayoutTestScript.run() and passed
	passed = ACEDragTestScript.run() and passed
	passed = HitTestTestScript.run() and passed
	passed = LaneResizeTestScript.run() and passed
	passed = LayoutStateTestScript.run() and passed
	passed = ACEReorderDragTestScript.run() and passed
	passed = VariableExportTestScript.run() and passed
	passed = TreeVariableTestScript.run() and passed
	passed = CommentNestingTestScript.run() and passed
	passed = ConditionEditTestScript.run() and passed
	passed = InlineEditTestScript.run() and passed
	passed = DisableSelectionTestScript.run() and passed
	passed = SubeventSelectionTestScript.run() and passed
	passed = FooterRowsTestScript.run() and passed
	passed = GDScriptPairingTestScript.run() and passed
	passed = ProvenanceTestScript.run() and passed
	passed = ACEAddonTestScript.run() and passed
	passed = InflowGDScriptTestScript.run() and passed
	passed = SnippetShareTestScript.run() and passed
	passed = CodegenParityTestScript.run() and passed
	passed = ExternalSheetTestScript.run() and passed
	passed = SubeventCompileTestScript.run() and passed
	passed = CustomNodeClassTestScript.run() and passed
	passed = BehaviorFoundationsTestScript.run() and passed
	passed = BehaviorAuthoringTestScript.run() and passed
	passed = SampleBehaviorPackTestScript.run() and passed
	passed = PairingPolishTestScript.run() and passed
	passed = ACELiftTestScript.run() and passed
	passed = RuntimeProviderTestScript.run() and passed
	passed = VisualCompletenessTestScript.run() and passed
	passed = ReleaseHardeningTestScript.run() and passed
	passed = GDScriptPasteTestScript.run() and passed
	passed = PickFilterTestScript.run() and passed
	passed = FxCompletionWatchTestScript.run() and passed
	passed = SignalLiftTestScript.run() and passed
	passed = IntellisenseTestScript.run() and passed
	passed = FunctionLiftTestScript.run() and passed
	passed = BookmarksIncludesTestScript.run() and passed
	passed = InspectorPolishTestScript.run() and passed
	passed = EnumRowTestScript.run() and passed
	passed = UxGuardrailsTestScript.run() and passed
	passed = CollectionVariablesTestScript.run() and passed
	passed = CollectionAcesTestScript.run() and passed
	passed = McpServerTestScript.run() and passed
	passed = InputTimeAcesTestScript.run() and passed
	passed = GodotFeelTestScript.run() and passed
	passed = SignalAutocompleteTestScript.run() and passed
	passed = EventSheetEditorTestScript.run() and passed
	passed = EventSheetStyleTestScript.run() and passed
	passed = PluginWorkspaceTestScript.run() and passed
	passed = WorkspaceShellTestScript.run() and passed
	passed = EditorParamExposureTestScript.run() and passed
	passed = DocsIntegrityTestScript.run() and passed
	passed = PerfSmokeTestScript.run() and passed
	if passed:
		print("All tests passed.")
		quit(0)
	else:
		push_error("Some tests failed.")
		quit(1)
