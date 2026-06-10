# EventForge — Standalone headless-safe checks runner.
# Runs the viewport checks that do NOT touch the display server (no popups), so they
# can run under `godot --headless --script tests/run_perf.gd` for quick verification
# during the editor overhaul without the full editor test suite (which opens popups).
@tool
extends SceneTree
class_name EventForgePerfRunner

func _init() -> void:
	var passed: bool = true
	passed = EventLazySpansTest.run() and passed
	passed = ACEPickerLogicTest.run() and passed
	passed = ACEParamsLogicTest.run() and passed
	passed = KeyboardActionsTest.run() and passed
	passed = ColumnHeaderTest.run() and passed
	passed = ThemePresetsTest.run() and passed
	passed = CustomACEProviderTest.run() and passed
	passed = SubEventAuthoringTest.run() and passed
	passed = SheetFunctionTest.run() and passed
	passed = MultiTabTest.run() and passed
	passed = ImporterTest.run() and passed
	passed = RowLayoutTest.run() and passed
	passed = ACEDragTest.run() and passed
	passed = HitTestTest.run() and passed
	passed = LaneResizeTest.run() and passed
	passed = LayoutStateTest.run() and passed
	passed = ACEReorderDragTest.run() and passed
	passed = VariableExportTest.run() and passed
	passed = TreeVariableTest.run() and passed
	passed = CommentNestingTest.run() and passed
	passed = ConditionEditTest.run() and passed
	passed = InlineEditTest.run() and passed
	passed = DisableSelectionTest.run() and passed
	passed = SubeventSelectionTest.run() and passed
	passed = FooterRowsTest.run() and passed
	passed = GDScriptPairingTest.run() and passed
	passed = ProvenanceTest.run() and passed
	passed = ACEAddonTest.run() and passed
	passed = InflowGDScriptTest.run() and passed
	passed = SnippetShareTest.run() and passed
	passed = CodegenParityTest.run() and passed
	passed = ExternalSheetTest.run() and passed
	passed = SubeventCompileTest.run() and passed
	passed = CustomNodeClassTest.run() and passed
	passed = BehaviorFoundationsTest.run() and passed
	passed = BehaviorAuthoringTest.run() and passed
	passed = SampleBehaviorPackTest.run() and passed
	passed = PairingPolishTest.run() and passed
	passed = ACELiftTest.run() and passed
	passed = RuntimeProviderTest.run() and passed
	passed = VisualCompletenessTest.run() and passed
	passed = ReleaseHardeningTest.run() and passed
	passed = GDScriptPasteTest.run() and passed
	passed = PickFilterTest.run() and passed
	passed = FxCompletionWatchTest.run() and passed
	passed = SignalLiftTest.run() and passed
	passed = IntellisenseTest.run() and passed
	passed = FunctionLiftTest.run() and passed
	passed = BookmarksIncludesTest.run() and passed
	passed = InspectorPolishTest.run() and passed
	passed = EnumRowTest.run() and passed
	passed = UxGuardrailsTest.run() and passed
	passed = CollectionVariablesTest.run() and passed
	passed = CollectionAcesTest.run() and passed
	passed = PerfSmokeTest.run() and passed
	if passed:
		print("Headless-safe checks passed.")
		quit(0)
	else:
		push_error("Headless-safe checks failed.")
		quit(1)
