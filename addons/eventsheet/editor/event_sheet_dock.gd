@tool
class_name EventSheetDock
extends Control

# .gd is listed first so it is the default format for New Sheet / Save As - a sheet is just plain
# GDScript (no .tres needed). .tres/.res stay available (e.g. library sheets used via Includes).
const EVENT_SHEET_FILTERS: Array[String] = ["*.gd ; GDScript EventSheet", "*.tscn ; Scene (read only)", "*.tres ; EventSheetResource", "*.res ; EventSheetResource"]
## "Teach a Verb" persistence: sheets shared project-wide list their compiled .gd here
## (a PackedStringArray in project settings), and the provider scan appends them - so a
## taught verb survives sessions, unlike the bridge's in-memory registrations.
const TAUGHT_PROVIDERS_SETTING := "eventsheets/vocabulary/taught_provider_scripts"
const CONDITION_MENU_EDIT := 1
const CONDITION_MENU_ADD := 2
const CONDITION_MENU_REPLACE := 3
const CONDITION_MENU_INVERT := 4
const CONDITION_MENU_DELETE := 5
const CONDITION_MENU_TOGGLE_ENABLED := 6
const CONDITION_MENU_EDIT_ACE_COMMENT := 21
const ACE_MENU_SELECT_ALL_MATCHING := 22  # shared by the condition + action cell menus
const ACTION_MENU_EDIT := 1
const ACTION_MENU_ADD := 2
const ACTION_MENU_REPLACE := 3
const ACTION_MENU_DELETE := 4
const ACTION_MENU_EXTRACT_FN := 40
## "This raw call looks like one of your own verbs - name it."
const ACTION_MENU_CONVERT_TO_VERB := 41
# Collection-declaration rows (Declare <name> with entry rows) - shown only when the
# right-clicked action IS one; the entry items additionally need the click to have landed
# on an entry line (the span carries decl_entry_index).
const ACTION_MENU_DECL_ADD_ENTRY := 60
const ACTION_MENU_DECL_EDIT_ENTRY := 61
const ACTION_MENU_DECL_REMOVE_ENTRY := 62
const ACTION_MENU_TIMELINE_ADD_STEP := 63
const ACTION_MENU_TOGGLE_ENABLED := 5
const ACTION_MENU_EDIT_ACE_COMMENT := 21
const ROW_MENU_ADD_SUB_EVENT := 1
const ROW_MENU_ADD_EVENT_BELOW := 2
const ROW_MENU_ADD_GROUP_BELOW := 3
const ROW_MENU_ADD_COMMENT_BELOW := 4
const ROW_MENU_COPY := 5
const ROW_MENU_PASTE := 6
const ROW_MENU_DELETE := 7
const ROW_MENU_TOGGLE_CONDITION_BLOCK := 8
const ROW_MENU_TOGGLE_GROUP_FOLD := 9
const ROW_MENU_ADD_SUB_CONDITION := 10
const ROW_MENU_TOGGLE_ENABLED := 11
const ROW_MENU_ADD_VARIABLE_BELOW := 12
const ROW_MENU_ADD_COMMENT_SUB_EVENT := 13
const ROW_MENU_ADD_GDSCRIPT_BELOW := 14
const ROW_MENU_ADD_GDSCRIPT_ACTION := 15
const ROW_MENU_EDIT_COMMENT := 16
const ROW_MENU_ATTACH_COMMENT := 17
const ACTION_MENU_DETACH_COMMENT := 6
const ROW_MENU_ADD_PICK_FILTER := 18
const ROW_MENU_ADD_ENUM := 19
const ROW_MENU_GROUP_COLOR := 27
const ROW_MENU_FIND_USAGES := 29
# 41, not 30: SURROUND_REGION shipped colliding with SAVE_SNIPPET, which made "Save Selection
# as Snippet…" silently run Surround with Region (first match in the dispatch wins).
const ROW_MENU_SURROUND_REGION := 41
const ROW_MENU_SAVE_SNIPPET := 30
const ROW_MENU_INSERT_SNIPPET := 31
const ROW_MENU_BULK_TOGGLE_ENABLED := 32
const ROW_MENU_BULK_DUPLICATE := 33
const ROW_MENU_BULK_GROUP := 34
const ROW_MENU_ADD_SIGNAL := 21
const ROW_MENU_ADD_MATCH := 22
const ROW_MENU_OPEN_IN_SPLIT := 23
const ROW_MENU_MAKE_ELSE := 35
const ROW_MENU_MAKE_ELIF := 36
const ROW_MENU_EXTRACT_GDSCRIPT_FN := 37
const ROW_MENU_BREAKPOINT_CONDITION := 38
const ROW_MENU_SCOPE_TO_NODE := 39
const ROW_MENU_CUT := 42
const ROW_MENU_COPY_AS_TEXT := 43
const ROW_MENU_ADD_EVENT_ABOVE := 44
const ROW_MENU_EDIT_FUNCTION := 45
const ROW_MENU_ADD_FUNCTION_PARAM := 46
const ROW_MENU_MAKE_FUNCTION_EDITABLE := 47
const ROW_MENU_REPLACE_OBJECT := 48
const ROW_MENU_BATCH_EDIT_PARAMS := 49
const ROW_MENU_DATA_CLASS_ADD_FIELD := 50
const ROW_MENU_DATA_CLASS_REMOVE_FIELD := 51
const ROW_MENU_ADD_TIMELINE_BELOW := 52
## Paste Special: paste the clipboard snippet retargeted (dock/paste_special_dialog.gd).
const ROW_MENU_PASTE_SPECIAL := 53
## G4 - the group head's own verbs: the one Edit group dialog, the Active-on-start tick, the
## whole-sheet fold, a local variable of this group, and unwrapping the group off its rows.
const ROW_MENU_EDIT_GROUP := 54
const ROW_MENU_GROUP_ENABLED := 55
const ROW_MENU_FOLD_ALL_GROUPS := 56
const ROW_MENU_GROUP_ADD_LOCAL := 57
const ROW_MENU_UNGROUP := 58
## R2 - the region verbs. A region is two lines of the file, so what it offers is its own list:
## rename the fence, fold it, turn it into a group (or a group into it), colour it, or drop the
## pair and keep the rows.
const ROW_MENU_REGION_RENAME := 59
const ROW_MENU_FOLD_ALL_REGIONS := 60
const ROW_MENU_REGION_TO_GROUP := 61
const ROW_MENU_REGION_REMOVE := 62
const ROW_MENU_GROUP_TO_REGION := 63
## What the colour picker opens on when a group or a region carries no colour of its own yet.
const DEFAULT_STRUCTURE_COLOR := Color(0.55, 0.45, 0.85, 1.0)
const VARIABLE_MENU_EDIT := 1
const VARIABLE_MENU_CONVERT_SCOPE := 2
const VARIABLE_MENU_TOGGLE_CONST := 3
const VARIABLE_MENU_RENAME := 4
const VARIABLE_MENU_GROUP := 5
const VARIABLE_MENU_REMEMBER := 6
## Change Type Everywhere / the grid CSV round trip (dock/variable_retype_dialog.gd,
## dock/grid_csv_dialog.gd).
const VARIABLE_MENU_CHANGE_TYPE := 7
const VARIABLE_MENU_GRID_EXPORT := 8
const VARIABLE_MENU_GRID_IMPORT := 9
## The TRANSLATOR's file on the same grid - a different shape from the designer's (Godot's own
## keys,en catalog, one row per key) written by the same codec (dock/grid_csv_dialog.gd).
const VARIABLE_MENU_TEXT_EXPORT := 10
const VARIABLE_MENU_TEXT_IMPORT := 11
## R2 - the two accessor events a property can have. "Add setter" writes the `set(value):` block that
## reads as an `On <name> set` trigger, "Add getter" the `get:` block that reads as an expression.
const VARIABLE_MENU_ADD_SETTER := 12
const VARIABLE_MENU_ADD_GETTER := 13
## V2 - the variable list reads in AUTHOR order, so alphabetical is something you ask for. It writes
## the order rather than sorting the view, which is why it lands through the undo funnel.
const VARIABLE_MENU_SORT_AZ := 14
## V8. The two verbs the variable row menu was missing: the name as code, ready to paste into a
## field or a script, and the one tick that puts a variable in the Inspector.
const VARIABLE_MENU_COPY_EXPRESSION := 15
const VARIABLE_MENU_SHOW_IN_INSPECTOR := 16
const EMPTY_MENU_NEW_EVENT := 1
const EMPTY_MENU_NEW_CONDITION := 2
const EMPTY_MENU_ADD_VARIABLE := 3
const EMPTY_MENU_INSERT_SNIPPET := 4
## R32. An Inspector button and the empty function it calls, written in one step.
const EMPTY_MENU_ADD_INSPECTOR_BUTTON := 5
## V8. The Add submenu names the three scopes, because "add a variable" is really three different
## questions and the answer decides where the declaration goes.
const EMPTY_MENU_ADD_LOCAL_VARIABLE := 6
const EMPTY_MENU_ADD_INSTANCE_VARIABLE := 7
# The "New Function" submenu on the empty-space menu. Its items open the function dialog pre-set:
# a plain (unpublished) helper, or a published Action / Condition / Expression.
const NEW_FUNCTION_MENU_PLAIN := 0
const NEW_FUNCTION_MENU_ACTION := 1
const NEW_FUNCTION_MENU_CONDITION := 2
const NEW_FUNCTION_MENU_EXPRESSION := 3
const ACE_DRAG_KINDS := ["condition", "action"]
const SIDE_PANEL_MIN_WIDTH := 160.0
const SIDE_PANEL_MAX_WIDTH := 220.0
const SIDE_PANEL_WIDTH_RATIO := 0.18

var _toolbar: HFlowContainer = null
var _title_strip: HBoxContainer = null
var _title_tab_label: Label = null
var _title_path_label: Label = null
var _title_dirty_dot: Label = null
var _status_label: Label = null
## The status bar's right half: "event 4 of 61 · line 38" for the selected row.
var _row_address_label: Label = null
var _theme_picker: OptionButton = null
var _provider_dialog: Window = null
var _provider_list: ItemList = null
var _provider_file_dialog: FileDialog = null
# The provider dialog's "what will this publish?" half: browsing a script PREVIEWS it (the scan is
# read-only) and registering is a second, deliberate click, so nothing joins the vocabulary unseen.
var _provider_preview_summary: Label = null
var _provider_preview_warnings: VBoxContainer = null
var _provider_preview_tree: Tree = null
var _provider_register_button: Button = null
var _provider_pending_path: String = ""
# Curation (the wizard's second half): the script currently shown in the preview, and the scan it
# came from. The scan is the BEFORE side of the diff - what the table shows is compared against it,
# so only members the user actually changed get annotated.
var _provider_curate_button: Button = null
var _provider_params_button: Button = null
var _provider_shim_button: Button = null
var _provider_preview_path: String = ""
var _provider_preview_scan: Dictionary = {}
var _split: HSplitContainer = null
var _scroll: ScrollContainer = null
# Open Sheets panel: a left in-workspace pane (the "Filter Scripts"-style list). _workspace_body
# is a stable HSplit holding [_open_sheets_panel | _content_host]; _content_host wraps _scroll, so
# the code-panel/split-view machinery (which reparents _scroll relative to its parent) stays inside
# it and never disturbs the panel. Toggled from the View menu; collapsible to a strip.
var _workspace_body: HSplitContainer = null
var _content_host: VBoxContainer = null
var _open_sheets_panel: EventSheetOpenSheetsDock = null
var _anatomy_panel: BehaviourAnatomyPanel = null
var _picker_preview_panel: EventSheetPickerPreviewPanel = null  # left rail, under Open Sheets (behaviour_anatomy_panel.gd)
var _functions_panel: EventSheetFunctionsPanel = null  # left rail, dockable fold-expand Functions overview (functions_panel.gd)
const _OPEN_SHEETS_PANEL_META: String = "eventsheets_open_sheets_panel"  # editor metadata: {shown, collapsed}
var _minimap: EventSheetMinimap = null  # the thin picture-of-the-sheet column at the canvas's right edge (dock/minimap.gd)
var _column_header: SheetColumnHeader = null
var _identity_banner: SheetIdentityBanner = null
var _preview_banner: PanelContainer = null
var _preview_label: Label = null
## The "Opening <file>" strip shown while a .gd's ACE lift runs on a worker thread (dock/open_progress.gd).
## Owns its own widgets - the dock only holds the helper so sheet_io can drive it.
var _open_progress: EventSheetOpenProgress = EventSheetOpenProgress.new()
var _viewport: EventSheetViewport = null
var _side_panel: VBoxContainer = null
var _preview_window: Window = null
var _preview_title: Label = null
var _preview_list: ItemList = null
## Functions overview (event-sheet-style): every sheet function at a glance, atop the GDScript panel.
var _functions_list: ItemList = null
var _functions_menu: PopupMenu = null

var _current_sheet: EventSheetResource = null  # the ACTIVE tab's sheet
var _current_sheet_path: String = ""           # the ACTIVE tab's path
var _dirty: bool = false                        # the ACTIVE tab's dirty flag
# Open sheet tabs. Each entry: {sheet: EventSheetResource, path: String, dirty: bool}.
# The active tab's live state mirrors _current_sheet/_current_sheet_path/_dirty.
## Emitted whenever the open-tab set, the active tab, or a tab's dirty flag changes - the
## Open Sheets dock (a left editor dock) listens and re-renders its list.
signal open_tabs_changed

var _open_tabs: Array[Dictionary] = []
var _active_tab_index: int = -1
var _tab_bar: TabBar = null
var _recent_closed_paths: Array[String] = []  # MRU of recently-closed tab paths (capped) - the Open Sheets dock offers to reopen them
var _suppress_tab_signal: bool = false
# Provider class -> autoload name (rebuilt with the registry): lets picked bus triggers
# bake "autoload:<Name>" sources so consumers connect by singleton name.
var _autoload_provider_names: Dictionary = {}
var _autoload_annotation_regex: RegEx = null
var _ace_registry: EventSheetACERegistry = EventSheetACERegistry.new()
var _editor_param_store: EditorParamStore = EditorParamStore.new()
var _param_resolver: ParamDefaultResolver = ParamDefaultResolver.new()
var _exposed_node: EventSheetExposedNode = EventSheetExposedNode.new()
var _ace_sources: Array[Object] = []  # instances we created (sheet providers / demo); freed on refresh
var _manual_ace_sources: Array[Object] = []  # externally supplied (caller-owned, not freed)
var _undo_redo_adapter: EventSheetUndoRedoAdapter = EventSheetUndoRedoAdapter.new()

# ── Extracted sub-components ─────────────────────────────────────────────────
var _ace_picker: ACEPickerDialog = ACEPickerDialog.new()
var _ace_params: ACEParamsDialog = ACEParamsDialog.new()
var _variable_dlg: VariableDialog = VariableDialog.new()
var _new_addon_panel: EventSheetNewAddonPanel = EventSheetNewAddonPanel.new()  # Sheet ▸ New Behaviour Addon… (dock/new_addon_panel.gd)
var _new_resource_wizard: EventSheetNewResourceWizard = EventSheetNewResourceWizard.new()  # Sheet ▸ New Custom Resource… (dock/new_resource_wizard.gd)
var _import_sheet_wizard: EventSheetImportSheetWizard = EventSheetImportSheetWizard.new()  # Sheet ▸ Import event sheet… (dock/import_sheet_wizard.gd)
var _inspector_designer_dialog: EventSheetInspectorDesignerDialog = null  # Sheet ▸ Inspector Designer… (lazy; added to the dock on first open)
var _welcome: EventSheetWelcomeWindow = EventSheetWelcomeWindow.new()  # Tools ▸ Welcome… onboarding window (dock/welcome_window.gd)
var _tour: EventSheetTourWindow = EventSheetTourWindow.new()  # Tools ▸ Start the Tour… first-time walkthrough (dock/tour_window.gd)
var _behavior_preview: EventSheetBehaviorPreview = EventSheetBehaviorPreview.new()  # Tools ▸ Preview Behaviors on Selected Node (behavior_preview.gd)
var _starter: EventSheetStarterTemplates = EventSheetStarterTemplates.new()  # New-from-template starters (dock/starter_templates.gd)
var _comments: EventSheetCommentAndScopeDialogs = EventSheetCommentAndScopeDialogs.new()  # comment/with-node dialogs (dock/comment_and_scope_dialogs.gd)
var _struct_rows: EventSheetStructRowDialogs = EventSheetStructRowDialogs.new()  # enum/signal/match row editors (dock/struct_row_dialogs.gd)
var _inline_params: EventSheetInlineParamEditor = EventSheetInlineParamEditor.new()  # double-click value / swatch / node-drop editors (dock/inline_param_editor.gd)
var _doctor: EventSheetProjectDoctorPanel = EventSheetProjectDoctorPanel.new()  # Tools ▸ Project Doctor health-audit window (dock/project_doctor_panel.gd)
var _includes: EventSheetIncludeManager = EventSheetIncludeManager.new()  # Sheet ▸ Manage Includes… window (dock/include_manager.gd)
var _find_refs: EventSheetFindReferencesPanel = EventSheetFindReferencesPanel.new()  # Edit ▸ Find References… window (dock/find_references_panel.gd)
var _pick: EventSheetPickFilterDialog = EventSheetPickFilterDialog.new()  # "For Each" pick-filter dialog (dock/pick_filter_dialog.gd)
var _compare: EventSheetCompareConditionDialog = EventSheetCompareConditionDialog.new()  # the one Compare dialog (dock/compare_condition_dialog.gd)
var _ai: EventSheetAIGenerateWindow = EventSheetAIGenerateWindow.new()  # Edit ▸ Generate from Description… window (dock/ai_generate_window.gd)
var _ask: EventSheetAskWindow = EventSheetAskWindow.new()  # View ▸ Ask… proposed-events window (dock/ask_window.gd)
var _sheet_type: EventSheetSheetTypeDialog = EventSheetSheetTypeDialog.new()  # Sheet ▸ Sheet Type… dialog shell (dock/sheet_type_dialog.gd)
var _session: EventSheetSessionStore = EventSheetSessionStore.new()  # open-tabs restore across restarts (event_sheet_session_store.gd)
var _shortcuts: EventSheetShortcutsDialog = EventSheetShortcutsDialog.new()  # Tools ▸ Keyboard Shortcuts editor (event_sheet_shortcuts_dialog.gd)
var _docs: EventSheetDocWindow = EventSheetDocWindow.new()  # Tools ▸ Documentation… / F1 / "What does this do?" (docs/doc_window.gd)
var _rename: EventSheetRenameRefactor = EventSheetRenameRefactor.new()  # variable rename engine + "Rename Everywhere" dialog (event_sheet_rename_refactor.gd)
var _head_actions: EventSheetHeadActions = EventSheetHeadActions.new()  # the gestures on the sheet's head bands (dock/sheet_head_actions.gd)
var _variables: EventSheetVariablesManager = EventSheetVariablesManager.new()  # global/local/tree variable authoring + usage scan (dock/variables_manager.gd)
var _multi_view: EventSheetMultiViewManager = EventSheetMultiViewManager.new()  # split-view subsystem: second pane over the same sheet (dock/multi_view_manager.gd)
var _command_palette: EventSheetCommandPalette = EventSheetCommandPalette.new()  # Ctrl+P command palette: list + fuzzy filter + popup shell (dock/command_palette.gd)
var _sheet_diff: EventSheetSheetDiff = EventSheetSheetDiff.new()  # "What Changed Since Save" - rows a save would touch (dock/sheet_diff.gd)
var _variable_grouping: EventSheetVariableGrouping = EventSheetVariableGrouping.new()  # drag-onto-variable folders + rename popup (dock/variable_grouping.gd)
var _menu_bar: EventSheetMenuBar = EventSheetMenuBar.new()  # top toolbar + grouped Sheet/Add/Edit/View/Tools menus + theme picker + quick-add (dock/menu_bar.gd)
var _project_bar_glue: EventSheetProjectBarGlue = EventSheetProjectBarGlue.new()  # T13 the Project bar (the Object bar's other tab): when it shows, and where each entry goes (dock/project_bar_glue.gd)
var _run_controls: EventSheetRunControls = EventSheetRunControls.new()  # T15 Preview layout / Preview project / Debug layout, routed to the editor's own run commands (dock/run_controls.gd)
var _beginner_toolbar: EventSheetBeginnerToolbar = EventSheetBeginnerToolbar.new()  # T18 the eight Add gestures as buttons above the canvas, on in Simple mode (dock/beginner_toolbar.gd)
## T14 the Start page. Loaded BY PATH on first open: it names the Manual's tutorials, and the dock is
## constructed at every editor boot - naming it here would pull the whole help corpus into that boot.
var _start_page: RefCounted = null
var _context_menus: EventSheetContextMenus = EventSheetContextMenus.new()  # right-click context menus: condition/action/row/variable/empty-space build + per-click configure (dock/context_menus.gd)
var _external_watcher: EventSheetExternalWatcher = EventSheetExternalWatcher.new()  # GDScript-backed sheet file-watch + reload-on-disk-change dialog (dock/external_watcher.gd)
var _sheet_io: EventSheetSheetIO = EventSheetSheetIO.new()  # sheet FILE-IO: open-from-disk + every write-back path (Save/Save As/Export/Save-as-.gd) (dock/sheet_io.gd)
var _live_edit_bar: EventSheetLiveEditBar = EventSheetLiveEditBar.new()  # ⟳ Apply to running game on the status strip (dock/live_edit_bar.gd)
var _shared_sheets: EventSheetSharedSheetDialogs = EventSheetSharedSheetDialogs.new()  # New shared sheet… + Include sheet… (dock/shared_sheet_dialogs.gd)
var _ui_builder: EventSheetDockUIBuilder = EventSheetDockUIBuilder.new()
var _input_dispatch: EventSheetDockInputDispatch = EventSheetDockInputDispatch.new()
var _code_panel_glue: EventSheetCodePanelGlue = EventSheetCodePanelGlue.new()
var _providers_glue: EventSheetProviderRegistryGlue = EventSheetProviderRegistryGlue.new()  # dock/provider_registry_glue.gd
var _sheet_type_glue: EventSheetTypeGlue = EventSheetTypeGlue.new()  # dock/sheet_type_glue.gd
var _queries: EventSheetDockQueries = EventSheetDockQueries.new()  # dock/sheet_queries.gd
var _add_rows: EventSheetAddRowRequests = EventSheetAddRowRequests.new()
var _extract_ops: EventSheetExtractOps = EventSheetExtractOps.new()  # extract-to-function / extract-to-include (dock/extract_ops.gd)  # dock/add_row_requests.gd  # code/provenance + open-sheets panel behavior (dock/code_panel_glue.gd)  # menu/shortcut routing (dock/dock_input_dispatch.gd)  # UI construction pass (dock/dock_ui_builder.gd)
var _ace_apply: EventSheetACEApply = EventSheetACEApply.new()  # ACE application (condition/action/trigger baking + insert) + row/ACE drag-drop reorder (dock/ace_apply.gd)
var _editor_tool_bar: EventSheetEditorToolBar = EventSheetEditorToolBar.new()  # R33: Run now / Reload / Output / Enable plugin on a tool sheet's Include bar (dock/editor_tool_bar.gd)
var _pending_built_here: Dictionary = {}  # W19: a recorded "show the events behind this" waiting for its file to finish opening
var _this_editor_bar: EventSheetThisEditorBar = EventSheetThisEditorBar.new()  # W20: Enabled / Reload / Output / plugin.cfg + the read-only guard on a sheet that is part of the running editor (dock/this_editor_bar.gd)
var _row_edit_ops: EventSheetRowEditOps = EventSheetRowEditOps.new()  # context-menu row/ACE edit ops: enable/disable, delete, indent/outdent, else, insert, bulk-selection, invert/OR-AND (dock/row_edit_ops.gd)
var _preview_glue: EventSheetPreviewGlue = EventSheetPreviewGlue.new()  # .gd-preview banner + "Edit Events" unlock + Open-in-Godot script-editor glue + lift-report window (dock/preview_glue.gd)
var _author_actions: EventSheetAuthorActions = EventSheetAuthorActions.new()  # author quick-actions: quick-add match+apply + Run Scene + Save/Insert row snippets (dock/author_actions.gd)
var _verb_properties: EventSheetVerbProperties = EventSheetVerbProperties.new()  # a published verb's header click: the ACE properties popup (kind, category, inputs, inserts) (dock/verb_properties_popup.gd)
var _object_properties: EventSheetObjectProperties = EventSheetObjectProperties.new()  # a row's object-name click: the object popup (type, path, rows, signals) (dock/object_properties_popup.gd)
var _instance_variables: EventSheetInstanceVariableTable = EventSheetInstanceVariableTable.new()  # the object's variables as an editable table on Object properties and the Properties bar (dock/instance_variable_table.gd)
var _hierarchy_edits: EventSheetHierarchyEdits = EventSheetHierarchyEdits.new()  # X15: what the Hierarchy pane's gestures write - Add child + flags dialog, Remove from parent (dock/hierarchy_edits.gd)
var _global_variables: EventSheetGlobalVariables = EventSheetGlobalVariables.new()  # Add ▸ Global variable…: one value the project shares, written into an autoload (dock/global_variables.gd)
var _find_results: EventSheetFindResultsBar = EventSheetFindResultsBar.new()  # Find all references: the results bar under the sheet, grouped by sheet with event numbers (dock/find_results_bar.gd)
var _properties_bar: EventSheetPropertiesBar = EventSheetPropertiesBar.new()  # the selected condition/action/object/group as fields edited in place, beside the canvas (dock/properties_bar.gd)
var _objects_panel: EventSheetObjectsPanel = null  # left-rail Objects section: every object the open file uses (editor/objects_panel.gd)
var _ghost_row: EventSheetGhostRow = EventSheetGhostRow.new()  # zero-dialog add: E/C/A open a type-a-sentence popup at the selected row (dock/ghost_row.gd)
var _navigate: EventSheetNavigate = EventSheetNavigate.new()  # Ctrl+Click go-to-definition: addon verbs open their behaviour as a sheet (dock/navigate.gd)
var _export_pack: EventSheetExportPack = EventSheetExportPack.new()  # Sheet ▸ Export Addon Pack: writes eventsheet_addons/<class>/ (.tres + .gd + README, bundles includes) (dock/export_pack.gd)
var _save_studio: EventSheetSaveStudio = EventSheetSaveStudio.new()  # Tools ▸ Save Studio: format preview + slot browser/export + save_state generator (dock/save_studio.gd)
var _translation_studio: EventSheetTranslationStudio = EventSheetTranslationStudio.new()  # Tools ▸ Translation Studio: extract / notes+orphans / import+register+coverage (dock/translation_studio.gd)
var _function_dialog_glue: EventSheetFunctionDialogGlue = EventSheetFunctionDialogGlue.new()  # Add ▾ ▸ Function… dialog wiring + apply-to-sheet (dock/function_dialog.gd)
var _theme_manager: EventSheetThemeManager = EventSheetThemeManager.new()  # editor theme: load/apply/pick style + theme file dialog + theme editor + live-reload binding to the active .tres (dock/theme_manager.gd)
var _find_bar_glue: EventSheetFindBar = EventSheetFindBar.new()  # Ctrl+F find bar + Replace-All across the sheet + _replace_in_rows recursion (dock/find_bar.gd)
var _clipboard_glue: EventSheetClipboard = EventSheetClipboard.new()  # copy/paste: internal clipboard + portable snippets + raw-GDScript paste (owns _clipboard state) (dock/clipboard.gd)
var _quick_prompts: EventSheetQuickPromptDialogs = EventSheetQuickPromptDialogs.new()  # one-field prompt popups: Extract-to-Function name + Conditional Breakpoint + Group editor (dock/quick_prompt_dialogs.gd)
var _custom_block_dialog: EventSheetCustomBlockDialog = EventSheetCustomBlockDialog.new()  # Custom Block API: schema-driven add/edit dialog for registered kinds (dock/custom_block_dialog.gd)
var _raw_call_namer: EventSheetRawCallNamer = EventSheetRawCallNamer.new()  # Sheet ▸ Name Raw Calls: binds raw one-call code rows to existing vocabulary, byte-gated (dock/raw_call_namer.gd)
var _variable_retype_dialog: EventSheetVariableRetypeDialog = EventSheetVariableRetypeDialog.new()  # variable ▸ Change Type Everywhere…: preview + one-undo-step retype (dock/variable_retype_dialog.gd)
var _pattern_adopt_dialog: EventSheetPatternAdoptDialog = EventSheetPatternAdoptDialog.new()  # row ▸ Adopt behavior…: preview-first swap of a hand-written pattern for the shipped one (dock/pattern_adopt_dialog.gd)
var _grid_csv_dialog: EventSheetGridCSVDialog = EventSheetGridCSVDialog.new()  # variable ▸ Export/Import Grid …CSV: the data-asset grid round trip (dock/grid_csv_dialog.gd)
var _paste_special_dialog: EventSheetPasteSpecialDialog = EventSheetPasteSpecialDialog.new()  # row ▸ More ▸ Paste Special…: snippet paste, retargeted (dock/paste_special_dialog.gd)
var _language_variants_dialog: EventSheetLanguageVariantsDialog = EventSheetLanguageVariantsDialog.new()  # row ▸ Language Variants…: writes Godot's own per-locale asset remap table, and names the preloads that would ignore it (dock/language_variants_dialog.gd)
var _translation_key_dialog: EventSheetTranslationKeyDialog = EventSheetTranslationKeyDialog.new()  # the offer after editing a globe-marked value: rename the key in every catalog (dock/translation_key_dialog.gd)
var _condition_context_menu: PopupMenu = null
var _action_context_menu: PopupMenu = null
var _row_context_menu: PopupMenu = null
var _row_insert_submenu: PopupMenu = null
var _row_more_submenu: PopupMenu = null
var _variable_context_menu: PopupMenu = null
var _empty_space_context_menu: PopupMenu = null
var _new_function_submenu: PopupMenu = null
## V8. The Add ▸ Variable submenu (Global / Local / Instance), on the canvas menu.
var _add_variable_submenu: PopupMenu = null
var _context_row: EventRowData = null
var _context_hit: Dictionary = {}
## Simple mode (progressive disclosure for artist-first / first-time users): trims the
## right-click menus to the everyday authoring verbs and hides the advanced/code-leaning
## entries (GDScript blocks, sub-conditions, pick filters, match, signals/enums). Persisted
## per-project in editor metadata. Starts OFF here, but a project's FIRST run flips it on
## (welcome_window.show_if_first_run) - the toolbar pill makes Expert one visible click away.
var _simple_mode: bool = false
# The toolbar's Simple Mode pill + the surfaces it gates live: the Add Code button disappears and
# the Add menu's code item disables while Simple Mode is on (set by menu_bar.gd at build).
var _simple_mode_button: Button = null
var _add_code_button: Button = null
var _add_menu_popup: PopupMenu = null
# Fades informational status messages to muted after a few seconds (errors never fade).
var _status_fade_tween: Tween = null
var _view_popup: PopupMenu = null
## View ▸ Preview In Language (the GAME's locales, never the editor's own) - rebuilt each open so a
## language column a translator just added is pickable without reopening the workspace.
var _preview_language_menu: PopupMenu = null
# Command palette (Ctrl+P): keyboard-first access to every dock action - list + fuzzy filter +
# popup shell live on _command_palette (dock/command_palette.gd); the action targets stay here.


func _init() -> void:
	if not _undo_redo_adapter.has_manager():
		_undo_redo_adapter.set_manager(UndoRedo.new())
	# Wire the file-IO helper's back-reference up front (init() only stores _dock - nothing
	# tree-bound), so a delegate like _load_sheet_from_path works even when a test calls it on a
	# fresh .new() editor BEFORE _ready/setup run the rest of the lazy init cluster. The helper's
	# _dock.setup() then triggers _ensure_editor_dialogs_initialized() exactly as the inline body did.
	_sheet_io.init(self)
	# Same reason as _sheet_io: a test may apply an ACE (or exercise drag-drop) on a fresh .new()
	# editor before _ready. init() only stores _dock, so wiring it here (and again in the cluster) is safe.
	_ui_builder.init(self)
	_input_dispatch.init(self)
	_code_panel_glue.init(self)
	_providers_glue.init(self)
	_sheet_type_glue.init(self)
	_head_actions.init(self)
	_queries.init(self)
	_add_rows.init(self)
	_extract_ops.init(self)
	# The public extension API (addons/eventsheet/api/eventsheets.gd) fronts this dock;
	# the region fold commands register through it as living proof the extension point
	# works - delete these four lines and only extensions lose their entries.
	EventSheets._register_dock(self)
	EventSheets.register_palette_command("Collapse All Regions", func() -> void: _viewport.set_region_folds(true))
	EventSheets.register_palette_command("Expand All Regions", func() -> void: _viewport.set_region_folds(false))
	EventSheets.register_palette_command("Collapse Everything (regions + groups)", func() -> void: _viewport.set_region_folds(true, true))
	EventSheets.register_palette_command("Expand Everything", func() -> void: _viewport.set_region_folds(false, true))
	EventSheets.register_palette_command("Collapse All", func() -> void: _viewport.collapse_all())
	EventSheets.register_palette_command("Expand All", func() -> void: _viewport.expand_all())
	EventSheets.register_palette_command("Expand To Level 1", func() -> void: _viewport.expand_to_level(1))
	EventSheets.register_palette_command("Expand To Level 2", func() -> void: _viewport.expand_to_level(2))
	EventSheets.register_palette_command("Expand To Level 3", func() -> void: _viewport.expand_to_level(3))
	EventSheets.register_palette_command("Save Studio", func() -> void: _open_save_studio())
	EventSheets.register_palette_command("Translation Studio", func() -> void: _open_translation_studio(), "Translation")
	_ace_apply.init(self)
	_editor_tool_bar.init(self)
	_this_editor_bar.init(self)
	# Row/ACE edit-ops helper: same fresh-.new()-before-_ready reasoning - tests exercise ops like
	# _bulk_set_enabled_on / _toggle_selected_enabled / _indent_selected_event before the tree init runs.
	_row_edit_ops.init(self)
	# Preview-glue helper MUST be wired before _build_ui(): _build_ui calls
	# _preview_glue.build_preview_banner(), which assigns _preview_banner/_preview_label back on the dock.
	_preview_glue.init(self)
	# T13 / T15 / T18 - all three are reached from _build_ui() (the View items, the Preview buttons
	# and the beginner strip), so their back-references have to be wired before it. init() only
	# stores _dock; nothing here builds or scans anything.
	_project_bar_glue.init(self)
	_run_controls.init(self)
	_beginner_toolbar.init(self)
	_verb_properties.init(self)
	_object_properties.init(self)
	_instance_variables.init(self)
	_hierarchy_edits.init(self)
	_global_variables.init(self)
	_find_results.init(self)
	_properties_bar.init(self)
	# Same rule as _preview_glue: _build_ui() calls _open_progress.build(), so the back-reference
	# has to be wired before it (init() only stores _dock - nothing tree-bound).
	_open_progress.init(self)
	# Theme-manager MUST be wired before _build_ui() too: _build_ui() calls
	# _theme_manager.build_theme_file_dialog() (via the dock delegate). init() only stores _dock.
	_theme_manager.init(self)
	_raw_call_namer.init(self)
	# The three retarget/round-trip dialogs: init() only stores _dock (nothing tree-bound), and the
	# suite drives them on a fresh .new() editor before _ready, so they are wired here with the rest.
	_variable_retype_dialog.init(self)
	_pattern_adopt_dialog.init(self)
	_grid_csv_dialog.init(self)
	_paste_special_dialog.init(self)
	# The translation seams follow the same rule: init() only stores _dock, and the suite drives the
	# Studio's buttons and the key-rename offer on a fresh .new() editor before _ready.
	_translation_studio.init(self)
	_translation_key_dialog.init(self)
	_language_variants_dialog.init(self)
	# The row item rides the shipped extension seam rather than a new menu const: the context-menu
	# builder already appends every registered item whose filter accepts the clicked row.
	EventSheets.register_row_menu_item("Language Variants…",
		func(resource: Resource) -> bool:
			return EventSheetLanguageVariantsDialog.names_an_asset(resource),
		func(resource: Resource) -> void:
			_language_variants_dialog.open(resource))
	# "What does this do?" rides the same seam: the reference panel is a caller of the public
	# extension point, not a new hard-wired menu const, so the seam stays dogfooded. The filter
	# keeps the entry off a comment or an empty group - a row that names no verb has nothing to
	# explain, and an entry that opens a blank page is worse than no entry.
	_docs.init(self)
	EventSheets.register_row_menu_item("What does this do?",
		func(resource: Resource) -> bool:
			return EventSheetDocExplain.can_explain(resource),
		func(resource: Resource) -> void:
			explain_row(resource))
	_build_ui()

var _editor_dialogs_initialized: bool = false


func _ensure_editor_dialogs_initialized() -> void:
	_ui_builder.ensure_editor_dialogs_initialized()



func _ready() -> void:
	# The plugin's translation domain covers the whole dock subtree (windows and dialogs parent
	# here, so they inherit it): every Control string auto-translates when a non-English language
	# is picked, and stays English (the source text) by default. See editor/l10n.gd.
	EventSheetL10n.apply_to(self)
	# Drop-in translations reload live: dropping/editing/removing a CSV (or .translation) in a
	# scan folder re-reads the catalogs on the editor's next filesystem scan and re-translates
	# the open UI - no restart, and a newly dropped locale is immediately pickable.
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var filesystem: Object = Engine.get_singleton("EditorInterface").call("get_resource_filesystem")
		if filesystem != null and filesystem.has_signal("filesystem_changed") \
				and not filesystem.is_connected("filesystem_changed", _on_translations_maybe_changed):
			filesystem.connect("filesystem_changed", _on_translations_maybe_changed)
	# Project Settings is the OTHER way the facts behind a row change: adding an input action there
	# never touches the filesystem scan, so without this the Object bar kept naming yesterday's
	# actions until a restart.
	if Engine.is_editor_hint() and ProjectSettings.has_signal("settings_changed") \
			and not ProjectSettings.is_connected("settings_changed", _on_project_settings_changed):
		ProjectSettings.connect("settings_changed", _on_project_settings_changed)
	# The Scene dock's selection is the other half of the two-way link, and following it needs the
	# editor's own EditorSelection - which only exists in the editor.
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		_ensure_scene_link().init_selection(EditorInterface.get_selection())
	_build_ui()
	_ensure_editor_dialogs_initialized()
	_refresh_ace_registry()
	# Restore last session's tabs FIRST (editor only; headless tests drive setup() directly). Only fall
	# back to a blank starting sheet when nothing came back - otherwise an untitled sheet stacks on top
	# of the user's real tabs. The plugin ALSO calls setup() right after add_child() (which already ran
	# this _ready), so the setup() below is a no-op once tabs exist - see setup()'s guard. This is what
	# stopped the "two untitled sheets on open" (one from _ready + one from the plugin's setup()).
	if Engine.is_editor_hint() and is_inside_tree():
		_restore_session()
	if _open_tabs.is_empty():
		if _current_sheet == null:
			_current_sheet = _build_blank_sheet()
			_viewport.set_debug_overlay_states({})
		setup(_current_sheet)


## Editor filesystem ping: cheap fingerprint check inside; only a REAL translation-folder
## change reloads catalogs and re-translates the live UI (and redraws the canvas-drawn strings).
func _on_translations_maybe_changed() -> void:
	# Q1/Q9/Q10 - the object facts, the signal fan-out and the thumbnails are all reads of files that
	# just changed, so they are dropped here rather than kept for a session that has outlived them.
	# Each rebuilds lazily on the next question, which costs one scan and never a wrong answer.
	EventSheetObjectFacts.clear_cache()
	EventSheetSignalFanout.clear_cache()
	EventSheetObjectThumbnails.clear_cache()
	# The behaviour-pack index is the same kind of read - the heads of every pack file - so it is
	# dropped with them; a pack dropped into the project appears on the next row that asks.
	EventSheetViewportReadingRows.clear_pack_index()
	EventSheetEditorToolCensus.clear_cache()
	# T13 - the Project bar keeps no watcher of its own: it listens to exactly this ping, and only
	# when it is open, so a hidden bar costs nothing on a filesystem change.
	_project_bar_glue.on_filesystem_changed()
	# The project-wide scene index (which .tscn a script is the ROOT of) is what names an object on a
	# row, a sheet title and a thumbnail, and it was built ONCE per session: a scene saved, added or
	# re-pointed mid-session went on reading as the object it used to be until a restart.
	ViewportRowBuilder.clear_scene_script_index()
	# The Input Map is read out of project.godot as TEXT, so an action added in Project Settings (or
	# by another tool writing the file) only lands here when the read is dropped. The editor rescans
	# on both, so this hook covers the settings change as well as the file one.
	EventSheetInputMapFacts.clear_cache()
	if EventSheetL10n.reload_if_changed():
		propagate_notification(MainLoop.NOTIFICATION_TRANSLATION_CHANGED)
		if _viewport != null:
			_viewport.queue_redraw()


## Project Settings changed: the Input Map lives there, and every row that names an action reads it.
## Dropping the cached read is the whole fix - the next row that asks re-reads project.godot.
func _on_project_settings_changed() -> void:
	EventSheetInputMapFacts.clear_cache()
	if _viewport != null:
		_viewport.queue_redraw()


func setup(sheet: EventSheetResource = null) -> void:
	_build_ui()
	_ensure_editor_dialogs_initialized()
	# Idempotent initial state: a null setup() asks for "a blank starting sheet". If tabs already exist
	# (the plugin calls setup() right after add_child(), which already ran _ready), don't stack a second
	# untitled sheet - keep what is open. A null setup() with no tabs still seeds one blank sheet.
	if sheet == null and not _open_tabs.is_empty():
		return
	var target_sheet: EventSheetResource = sheet if sheet != null else _build_blank_sheet()
	var target_path: String = sheet.resource_path if sheet != null else ""
	_open_sheet_in_tab(target_sheet, target_path)


## Opens a sheet in a tab - activating its existing tab if already open, else adding one.
func _open_sheet_in_tab(sheet: EventSheetResource, path: String) -> void:
	for i in range(_open_tabs.size()):
		if _open_tabs[i].get("sheet") == sheet:
			_activate_tab(i)
			return
	_sync_active_tab_state()
	_open_tabs.append({"sheet": sheet, "path": path, "dirty": false})
	_activate_tab(_open_tabs.size() - 1)


## Makes the tab at index active, loading its sheet into the shared viewport.
func _activate_tab(index: int) -> void:
	if index < 0 or index >= _open_tabs.size():
		return
	if index != _active_tab_index:
		_sync_active_tab_state()
	_active_tab_index = index
	var tab: Dictionary = _open_tabs[index]
	_current_sheet = tab.get("sheet")
	_current_sheet_path = str(tab.get("path", ""))
	_dirty = bool(tab.get("dirty", false))
	_viewport.set_debug_overlay_states({})
	_clear_undo_history()
	_refresh_ace_registry()
	_viewport.set_sheet(_current_sheet)
	_apply_minimap_pref()
	_sync_split_sheet()
	_refresh_anatomy_panel()
	_refresh_functions_list()
	_theme_manager._sync_active_theme_binding()
	_refresh_title_strip()
	_theme_manager._refresh_theme_picker_selection()
	_refresh_exposed_node()
	_refresh_tab_bar()
	# Godot-native default (welcome panel choice): the generated-GDScript panel rides
	# along with every sheet, so the honest output is always in view.
	if bool(ProjectSettings.get_setting("eventsheets/editor/open_code_panel_by_default", false)) and not is_code_panel_visible():
		_toggle_code_panel()
	# If the GDScript panel is already open, recompile it for the sheet we just switched to so it
	# never shows the previous sheet's output. Self-guards on visibility, so it's a no-op when hidden.
	_refresh_code_panel()
	var label: String = _current_sheet_path.get_file() if not _current_sheet_path.is_empty() else "(unsaved EventSheet)"
	_set_status("Loaded: %s" % label)
	_persist_session()


## Opens `sheet` as a SCRATCH tab - the sandbox the Manual's examples and tutorials run in. It is an
## ordinary in-memory sheet with no path, which is what gives it every property the reader was
## promised without a single special case: nothing writes it, the session store skips it (it only
## records tabs that have a path), and closing it asks nothing.
##
## A null sheet opens an empty one, which is what a tutorial wants: somewhere to press the buttons.
## Reading mode is turned OFF, because a scratch sheet is for authoring rather than for reading.
func open_scratch_sheet(example_name: String, sheet: EventSheetResource = null) -> bool:
	var scratch: EventSheetResource = sheet
	if scratch == null:
		scratch = EventSheetStarterTemplates.build_starter(0)
	if scratch == null:
		return false
	scratch.read_only = false
	EventSheetDocScratch.mark(scratch, example_name)
	_sync_active_tab_state()
	_open_tabs.append({"sheet": scratch, "path": "", "dirty": false})
	_activate_tab(_open_tabs.size() - 1)
	if is_simple_mode():
		set_simple_mode(false)
	_set_status("Scratch sheet - in memory only, never written to your project unless you Save As.")
	return true


## Makes a real toolbar control pulse, so a tutorial step that says "click Add Action" points at the
## button rather than describing where it is.
##
## Resolved by the control's own LABEL rather than through a map of keys to buttons, and that is the
## whole design: the tutorial names the words the reader can see, the toolbar already carries those
## words, and there is no third list for either of them to fall out of step with. False when this
## toolbar carries no such control, so a caller can say so instead of pulsing nothing.
func pulse_control(control_label: String) -> bool:
	var wanted: String = control_label.strip_edges()
	if wanted.is_empty() or _toolbar == null:
		return false
	for child: Node in _toolbar.get_children():
		var button: Button = child as Button
		if button == null or button.text.strip_edges() != wanted:
			continue
		# Three slow breaths of the editor's accent over the button, then back to itself. A Tween
		# rather than a Timer so it finishes cleanly if the reader closes the dock mid-pulse. Under
		# Reduced Motion the button is simply left alone: the caller still gets its true, and the
		# thing being pointed at is still where it was.
		if EventSheetAccessibility.reduced_motion():
			return true
		var tween: Tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(button, "modulate", EventSheetPopupUI.accent_color().lightened(0.3), 0.45)
		tween.tween_property(button, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.45)
		return true
	return false


## Persists the live active-tab state (_current_sheet/path/dirty) back into _open_tabs.
func _sync_active_tab_state() -> void:
	if _active_tab_index < 0 or _active_tab_index >= _open_tabs.size():
		return
	# V15 - the workspace this tab was opened as part of is the tab's own, not the live state's, so
	# it is carried across rather than dropped on every sync.
	var group: String = str((_open_tabs[_active_tab_index] as Dictionary).get("group", ""))
	_open_tabs[_active_tab_index] = {"sheet": _current_sheet, "path": _current_sheet_path,
		"dirty": _dirty, "group": group}


## Closes the tab at index, activating a neighbour (or a fresh demo sheet when none remain).
func _close_tab(index: int) -> void:
	if index < 0 or index >= _open_tabs.size():
		return
	_remember_closed_path(str(_open_tabs[index].get("path", "")))
	_open_tabs.remove_at(index)
	_active_tab_index = -1
	if _open_tabs.is_empty():
		setup(null)
		_persist_session()
		return
	_activate_tab(mini(index, _open_tabs.size() - 1))


func _refresh_tab_bar() -> void:
	if _tab_bar == null:
		return
	_suppress_tab_signal = true
	_tab_bar.clear_tabs()
	# Q4 - a tab is named for what the sheet is ABOUT, with the object's own picture; the FILE it is
	# stored in rides on the tooltip, which is where a storage detail belongs.
	var name_counts: Dictionary = {}
	for tab: Dictionary in _open_tabs:
		var counted: String = str(EventSheetObjectFacts.sheet_object_title(
			tab.get("sheet"), str(tab.get("path", ""))).get("name", ""))
		name_counts[counted] = int(name_counts.get(counted, 0)) + 1
	for tab_index in range(_open_tabs.size()):
		var tab: Dictionary = _open_tabs[tab_index]
		var path: String = str(tab.get("path", ""))
		var sheet: EventSheetResource = tab.get("sheet")
		var title: Dictionary = EventSheetObjectFacts.sheet_object_title(sheet, path)
		var shown: String = _format_tab_title(sheet, path, bool(tab.get("dirty", false)))
		# Two objects with one name get the file added, because a pair of identical tabs is worse
		# than a long one.
		if int(name_counts.get(str(title.get("name", "")), 0)) > 1:
			shown = "%s · %s" % [shown, str(title.get("file", path)).get_file()]
		_tab_bar.add_tab(shown)
		# V15 - a tab opened as part of a scene workspace says which group it belongs to, where the
		# rest of the storage details already live.
		var group_note: String = str(tab.get("group", "")).strip_edges()
		var tooltip: String = _tab_tooltip(title, path)
		if not group_note.is_empty():
			tooltip = "%s · %s" % [tooltip, group_note]
		_tab_bar.set_tab_tooltip(tab_index, tooltip)
		var mark: Texture2D = _tab_icon(title)
		if mark != null:
			_tab_bar.set_tab_icon(tab_index, mark)
	if _active_tab_index >= 0 and _active_tab_index < _tab_bar.get_tab_count():
		_tab_bar.current_tab = _active_tab_index
	_tab_bar.visible = _open_tabs.size() >= 1
	_suppress_tab_signal = false
	open_tabs_changed.emit()


func _update_active_tab_title() -> void:
	if _tab_bar == null or _active_tab_index < 0 or _active_tab_index >= _tab_bar.get_tab_count():
		return
	_suppress_tab_signal = true
	_tab_bar.set_tab_title(_active_tab_index, _format_tab_title(_current_sheet, _current_sheet_path, _dirty))
	_suppress_tab_signal = false
	open_tabs_changed.emit()


## Push a just-closed sheet's path onto the recently-closed MRU (deduped, capped). Unsaved /
## empty paths are skipped - there's nothing to reopen.
func _remember_closed_path(path: String) -> void:
	if path.strip_edges().is_empty():
		return
	_recent_closed_paths.erase(path)
	_recent_closed_paths.push_front(path)
	while _recent_closed_paths.size() > 12:
		_recent_closed_paths.pop_back()


## ── Open Sheets dock API (a left editor dock; see open_sheets_dock.gd) ───────────────
## A read-only snapshot of the tab strip: each open tab's display title / path / dirty flag,
## the active index, and recently-closed paths not currently open (offered as "reopen").
func get_open_sheets_state() -> Dictionary:
	var open: Array = []
	var open_paths: Dictionary = {}
	for tab: Dictionary in _open_tabs:
		var p: String = str(tab.get("path", ""))
		if not p.is_empty():
			open_paths[p] = true
		open.append({
			"title": _format_tab_title(tab.get("sheet"), p, bool(tab.get("dirty", false))),
			"path": p,
			"dirty": bool(tab.get("dirty", false)),
			# V20 - the health card's first line on the hover, where sheets are picked. Only this
			# line: the rest of the card asks the Doctor, and a hover must never sweep the project.
			"health": EventSheetReadingCoverage.chip_text(tab.get("sheet")),
			"group": str(tab.get("group", "")),
		})
	var recent: Array[String] = []
	for p2: String in _recent_closed_paths:
		if not open_paths.has(p2):
			recent.append(p2)
	return {"open": open, "active": _active_tab_index, "recent": recent}


## Switch to an open tab by index (Open Sheets dock click). A one-click reselect of the
## already-active sheet must re-focus, not reload - reloading clears the viewport and wipes
## the sheet's undo/redo history, so swallow the no-op here (the dock allows reselect).
func activate_open_tab(index: int) -> void:
	if index == _active_tab_index:
		return
	_activate_tab(index)


## Reopen a recently-closed sheet by path (Open Sheets dock click). Drops it from the MRU
## first - _load_sheet_from_path opens or re-focuses it as a tab.
func reopen_sheet_path(path: String) -> void:
	if path.strip_edges().is_empty():
		return
	_recent_closed_paths.erase(path)
	# Drop the row from the dock now, so a failed load (a deleted/renamed file) can't leave a
	# dead "recently closed" entry behind. A successful load re-emits via _refresh_tab_bar.
	open_tabs_changed.emit()
	_load_sheet_from_path(path)


## Q4 - the file behind a tab, plus the note that says what kind of sheet it is ("addon pack",
## "global"). The hover is where a reader asks "which file is this, again?".
static func _tab_tooltip(title: Dictionary, path: String) -> String:
	var file_path: String = str(title.get("file", "")).strip_edges()
	if file_path.is_empty():
		file_path = path
	var note: String = str(title.get("note", ""))
	if file_path.is_empty():
		return note
	return file_path if note.is_empty() else "%s · %s" % [file_path, note]


## Q4/Q10 - the tab's mark: the object's own sprite when its scene has one, else its class icon.
static func _tab_icon(title: Dictionary) -> Texture2D:
	var icon_class: String = str(title.get("icon_class", ""))
	var picture: Texture2D = EventSheetObjectThumbnails.thumbnail_for(
		{"kind": "script", "label": str(title.get("name", ""))}, str(title.get("file", "")))
	if picture != null:
		return picture
	return ACEPickerDialog.editor_icon(icon_class) if not icon_class.is_empty() else null


func _format_tab_title(sheet: EventSheetResource, path: String, dirty: bool) -> String:
	# A scratch sheet from the Manual is named for the EXAMPLE it holds, not for the object it
	# would compile to: it has no file, it is never saved, and "Scratch - Wait For Signal" is the
	# only thing about it a reader needs to recognise in a tab strip.
	if EventSheetDocScratch.is_scratch(sheet):
		return EventSheetDocScratch.tab_title(EventSheetDocScratch.example_name(sheet))
	var title: String = _format_sheet_title(sheet, path)
	# Sheet-type badges: ⚙ behavior, ◆ custom node (event-sheet users expect typed tabs).
	if sheet != null and sheet.behavior_mode:
		title = "⚙ " + title
	elif sheet != null and not sheet.custom_class_name.strip_edges().is_empty():
		title = "◆ " + title
	return ("● " + title) if dirty else title


func _on_tab_selected(index: int) -> void:
	if not _suppress_tab_signal:
		_activate_tab(index)


func _on_tab_close_pressed(index: int) -> void:
	if _suppress_tab_signal:
		return
	# Guard against losing work: a dirty tab asks Save / Discard / Cancel before it closes. A SCRATCH
	# tab is the exception, and not as a convenience: it has no file to save to, so the prompt would
	# be offering a choice that does not exist.
	if is_tab_dirty(index) and not EventSheetDocScratch.closes_without_asking(
			_open_tabs[index].get("sheet") as EventSheetResource):
		_pending_close_index = index
		_ensure_unsaved_close_dialog()
		var tab: Dictionary = _open_tabs[index]
		var tab_title: String = _format_sheet_title(tab.get("sheet"), str(tab.get("path", "")))
		_unsaved_close_dialog.dialog_text = "\"%s\" has unsaved changes.\n\nSave before closing?" % tab_title
		_unsaved_close_dialog.popup_centered(Vector2i(440, 150))
		return
	_close_tab(index)

## 3-way "you have unsaved changes" guard for closing a dirty tab (Save / Discard / Cancel).
var _unsaved_close_dialog: ConfirmationDialog = null
var _pending_close_index: int = -1


func _ensure_unsaved_close_dialog() -> void:
	if _unsaved_close_dialog != null:
		return
	_unsaved_close_dialog = ConfirmationDialog.new()
	_unsaved_close_dialog.title = "Unsaved Changes"
	_unsaved_close_dialog.ok_button_text = "Discard"
	_unsaved_close_dialog.cancel_button_text = "Cancel"
	# A third action button so Save-and-close is one step; Cancel (the default) just aborts.
	_unsaved_close_dialog.add_button("Save", false, "save")
	_unsaved_close_dialog.confirmed.connect(_on_unsaved_close_discard)
	_unsaved_close_dialog.custom_action.connect(_on_unsaved_close_action)
	add_child(_unsaved_close_dialog)


## Discard (the OK button): close the tab, losing its unsaved edits.
func _on_unsaved_close_discard() -> void:
	var index: int = _pending_close_index
	_pending_close_index = -1
	if index >= 0:
		_close_tab(index)


## Save (the custom button): activate the target tab, save it, and close only if the save succeeded
## (a failed compile leaves the tab open with its error in the status bar, so nothing is lost).
func _on_unsaved_close_action(action: StringName) -> void:
	if action != &"save":
		return
	_unsaved_close_dialog.hide()
	var index: int = _pending_close_index
	_pending_close_index = -1
	if index < 0 or index >= _open_tabs.size():
		return
	if index != _active_tab_index:
		_activate_tab(index)
	_on_save_requested()
	if not _dirty:
		_close_tab(index)


## Whether any open tab has unsaved changes (for an editor-level "discard all?" prompt).
func has_unsaved_tabs() -> bool:
	for tab: Dictionary in _open_tabs:
		if bool(tab.get("dirty", false)):
			return true
	return false


## Number of open sheet tabs.
func get_open_tab_count() -> int:
	return _open_tabs.size()


## Index of the active tab (-1 when none).
func get_active_tab_index() -> int:
	return _active_tab_index


## Activates a tab by index (public entry point for tab navigation).
func activate_tab(index: int) -> void:
	_activate_tab(index)


## Whether the tab at index has unsaved changes.
func is_tab_dirty(index: int) -> bool:
	if index < 0 or index >= _open_tabs.size():
		return false
	return bool(_open_tabs[index].get("dirty", false))


func get_viewport_control() -> EventSheetViewport:
	return _viewport


func get_ace_registry() -> EventSheetACERegistry:
	return _ace_registry


func get_current_sheet() -> EventSheetResource:
	return _current_sheet


func get_editor_param_store() -> EditorParamStore:
	return _editor_param_store


func get_exposed_node() -> EventSheetExposedNode:
	return _exposed_node


# ── Editor theme (load/apply/pick style + file dialog + theme editor + live-reload binding)
# → dock/theme_manager.gd. The dock keeps thin delegates (same names/signatures) for the tests
# (dock.use_default_theme / .load_theme_style_from_path / .reload_active_theme), menu_bar.gd, and
# theme_editor_dialog.gd (which does _dock.call("apply_theme_style", …)).
func use_default_theme() -> bool:  # event_sheet_style_test
	return _theme_manager.use_default_theme()


func load_theme_style_from_path(path: String) -> bool:  # event_sheet_style_test
	return _theme_manager.load_theme_style_from_path(path)


func reload_active_theme() -> bool:  # event_sheet_style_test
	return _theme_manager.reload_active_theme()


func set_undo_redo_manager(undo_redo: Variant) -> void:
	if undo_redo == null:
		return
	_undo_redo_adapter.set_manager(undo_redo)
	if _exposed_node != null:
		_exposed_node.set_undo_redo_manager(_undo_redo_adapter.get_manager())
	if not _exposed_node.row_param_changed.is_connected(_on_exposed_row_param_changed):
		_exposed_node.row_param_changed.connect(_on_exposed_row_param_changed)


func set_auto_ace_sources(sources: Array[Object]) -> void:
	_providers_glue.set_auto_ace_sources(sources)



func add_ace_provider_script(path: String) -> bool:
	return _providers_glue.add_ace_provider_script(path)



func remove_ace_provider_script(path: String) -> bool:
	return _providers_glue.remove_ace_provider_script(path)



func get_ace_provider_scripts() -> PackedStringArray:
	return _providers_glue.get_ace_provider_scripts()



func _on_manage_ace_providers_requested() -> void:
	_providers_glue.on_manage_ace_providers_requested()



## "Teach a Verb" (Sheet menu): share this sheet's published verbs project-wide.
func _share_verbs_with_project_requested() -> void:
	_providers_glue.share_verbs_with_project()



## "Inspector Designer" (Sheet menu): the whole sheet's Inspector as one live view - every
## exported variable with its decor, grouping, and widget, through the shared preview cards.
## Editing routes BACK through the dock: ✎ opens the shared Variable dialog, ▲ reorders through
## the undo funnel - the Designer itself never mutates the sheet.
func _open_inspector_designer() -> void:
	if _inspector_designer_dialog == null:
		_inspector_designer_dialog = EventSheetInspectorDesignerDialog.new()
		_inspector_designer_dialog.wire_editing(
			_designer_edit_variable,
			_designer_move_variable_up,
			func() -> EventSheetResource: return _current_sheet
		)
		add_child(_inspector_designer_dialog)
	_inspector_designer_dialog.open_for_sheet(_current_sheet)


## Designer ✎: route the entry into the SAME context-edit path the viewport uses, resolved LIVE
## by name (never a cached resource - the funnel replaces them on every commit). The Designer
## refreshes once the dialog confirms.
func _designer_edit_variable(entry: Dictionary) -> void:
	if _current_sheet == null:
		return
	var var_name: String = str(entry.get("name", ""))
	var metadata: Dictionary = {"kind": "variable", "variable_name": var_name, "variable_scope": str(entry.get("scope", "global"))}
	var row_data: EventRowData = EventRowData.new()
	row_data.source_resource = _current_sheet
	if str(entry.get("scope", "")) == "tree":
		for sheet_entry: Variant in _current_sheet.events:
			if sheet_entry is LocalVariable and (sheet_entry as LocalVariable).name == var_name:
				row_data.source_resource = sheet_entry
				break
		if not (row_data.source_resource is LocalVariable):
			return
	if not _variable_dlg.variable_confirmed.is_connected(_refresh_inspector_designer_after_edit):
		_variable_dlg.variable_confirmed.connect(_refresh_inspector_designer_after_edit, CONNECT_ONE_SHOT)
	_variables._on_viewport_variable_edit_requested(row_data, metadata)


## Deferred so the funnel's commit (which replaces sheet resources) fully lands first.
func _refresh_inspector_designer_after_edit(_n: Variant = null, _t: Variant = null, _d: Variant = null, _s: Variant = null, _c: Variant = null, _k: Variant = null, _e: Variant = null, _o: Variant = null, _a: Variant = null, _r: Variant = null) -> void:
	if _inspector_designer_dialog != null and _inspector_designer_dialog.visible:
		_inspector_designer_dialog.call_deferred("refresh")


## Designer ▲: swap the tree variable with the PREVIOUS tree variable in emission order - one
## undo step. Sheet-level (dict) variables emit alphabetically, so only tree variables reorder.
func _designer_move_variable_up(var_name: String) -> void:
	_perform_undoable_sheet_edit("Move Variable Up", func() -> bool:
		var previous_index: int = -1
		for index: int in range(_current_sheet.events.size()):
			var sheet_entry: Variant = _current_sheet.events[index]
			if not (sheet_entry is LocalVariable):
				continue
			if (sheet_entry as LocalVariable).name == var_name:
				if previous_index < 0:
					return false
				var moved: Variant = _current_sheet.events[index]
				_current_sheet.events[index] = _current_sheet.events[previous_index]
				_current_sheet.events[previous_index] = moved
				return true
			previous_index = index
		return false)



func _build_provider_dialog() -> void:
	_ui_builder.build_provider_dialog()



func _refresh_provider_list() -> void:
	_providers_glue.refresh_provider_list()



func _on_provider_add_pressed() -> void:
	_providers_glue.on_provider_add_pressed()



func _on_provider_file_selected(path: String) -> void:
	_providers_glue.on_provider_file_selected(path)


## Renders "what this script publishes" into the provider dialog. offer_register is true for a script
## the user just browsed to (not registered yet), false when reading an already-registered one.
func _preview_provider_script(path: String, offer_register: bool) -> void:
	_providers_glue.preview_provider_script(path, offer_register)


func _on_provider_register_pressed() -> void:
	_providers_glue.on_provider_register_pressed()



func _on_provider_curate_pressed() -> void:
	_providers_glue.on_provider_curate_pressed()



func _on_provider_params_pressed() -> void:
	_providers_glue.on_provider_params_pressed()



func _on_provider_shim_pressed() -> void:
	_providers_glue.on_provider_shim_pressed()



func _on_provider_remove_pressed() -> void:
	_providers_glue.on_provider_remove_pressed()



func _build_ui() -> void:
	_ui_builder.build_ui()



func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Disconnect the active theme style's `changed` signal + null the field. The live-reload
		# binding is owned by EventSheetThemeManager, so its teardown lives there too.
		_theme_manager.teardown_theme_binding()
		_release_ace_sources()
		# A .gd still opening: join its worker before the job (and its Thread) is freed with us.
		_sheet_io._abandon_open_job()
		# The Scene dock outlives this dock: a selection_changed connection left behind would call
		# into a freed Control on the reader's very next click there.
		if _scene_link != null:
			_scene_link.teardown()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# GDScript-backed sheets: refocusing the editor is the moment external edits (the
		# script editor, another tool, git) usually land - offer to reload from disk. This is also
		# what carries "Open in Godot" edits back into a backed sheet (the .gd changed on disk).
		_prompt_external_reload_if_changed()
	elif what == NOTIFICATION_THEME_CHANGED and is_inside_tree():
		# The user switched their editor theme - re-derive the "Match Editor" default
		# (no-op when an explicit sheet theme is active) and re-skin the code panel.
		# apply_zoom=false: never reset the user's manual zoom on a theme change.
		_apply_editor_native_defaults()
		if _code_edit != null:
			_apply_editor_code_settings(_code_edit)

# ── External sheet file watching (GDScript-backed sheets; see EventSheetExternalWatcher) ──────
# mtime of the active external .gd at open/save time; divergence = changed on disk. Kept on the
# dock because it's written from several load/save sites here; the watcher reads/writes it through us.
var _external_mtime: int = 0


## True when the active GDScript-backed sheet's file changed on disk since open/save.
func _external_sheet_changed_on_disk() -> bool:
	return _external_watcher.sheet_changed_on_disk()


## Re-imports the active external sheet from disk (fresh lossless import + ACE lift).
func _reload_external_sheet() -> void:
	_external_watcher.reload_external_sheet()


func _prompt_external_reload_if_changed() -> void:
	_external_watcher.prompt_external_reload_if_changed()


func _build_preview_window() -> void:
	if _preview_window != null:
		return
	_preview_window = Window.new()
	_preview_window.name = "ACEPreviewWindow"
	_preview_window.title = "Dropped Node Preview"
	_preview_window.visible = false
	_preview_window.min_size = Vector2i(480, 280)
	_preview_window.close_requested.connect(func() -> void:
		if _preview_window != null:
			_preview_window.hide()
	)
	add_child(_preview_window)

	var content: VBoxContainer = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_window.add_child(content)

	_preview_title = Label.new()
	_preview_title.name = "ACEPreviewTitle"
	_preview_title.text = "Dropped Node Preview"
	content.add_child(_preview_title)

	_preview_list = ItemList.new()
	_preview_list.name = "ACEPreviewList"
	_preview_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_preview_list)


func _build_theme_file_dialog() -> void:  # called by _build_ui() - theme file dialog now in dock/theme_manager.gd
	_theme_manager.build_theme_file_dialog()


func _unhandled_key_input(event: InputEvent) -> void:
	_input_dispatch.unhandled_key_input(event)


## W19 - "show the events behind this". Ctrl+Shift+Alt on any control the plugin built opens the
## sheet that built it, scrolled to the row. Handled here rather than on each control because the
## question is asked OF a control and answered BY the dock, and because a chord this deliberate must
## work over the whole editor rather than only where somebody remembered to connect it.
##
## Silent everywhere else: outside the editor's own repo nothing is marked, so this finds nothing and
## the click goes where it always went.
func _input(event: InputEvent) -> void:
	if not EventSheetBuiltHere.is_show_source_click(event):
		return
	var view: Viewport = get_viewport()
	if view == null:
		return
	var source: Dictionary = EventSheetBuiltHere.source_for(view.gui_get_hovered_control())
	if source.is_empty():
		return
	get_viewport().set_input_as_handled()
	open_built_here(str(source.get("path", "")), str(source.get("marker", "")))


## Opens the editor's own file that built a control, and lands on the row that names it. Public so a
## test can walk the same path without a mouse.
##
## Opening a .gd is asynchronous - the lift runs while the tab is already there - so the jump is
## RECORDED and finished when the file lands. Revealing straight away would search the sheet that was
## open a moment ago and answer about the wrong file.
func open_built_here(source_path: String, marker: String) -> void:
	if source_path.is_empty():
		return
	_pending_built_here = {"path": source_path, "marker": marker}
	_navigate.record_current()
	_navigate.open_or_focus(source_path)
	if _current_sheet != null and str(_current_sheet.external_source_path) == source_path:
		# Already open: refocusing a tab is immediate, so there is nothing to wait for.
		_complete_built_here(_current_sheet, source_path)


## Finishes a recorded "show the events behind this" once its file is open. Called by the open path.
func _complete_built_here(sheet: EventSheetResource, path: String) -> void:
	if str(_pending_built_here.get("path", "")) != path:
		return
	var marker: String = str(_pending_built_here.get("marker", ""))
	_pending_built_here = {}
	var row: Resource = EventSheetBuiltHere.find_row(sheet, marker)
	if row != null:
		_active_view().reveal_resource(row)
	_set_status(EventSheetBuiltHere.landed_text(path, marker, row != null))



## True when a text-input control owns keyboard focus (so authoring shortcuts are paused).
func _text_field_has_focus() -> bool:
	var view: Viewport = get_viewport()
	if view == null:
		return false
	var focus_owner: Control = view.gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is SpinBox


## Closes the ACE picker when the user clicks anywhere outside the popup rect.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _ace_picker.is_open():
		return
	if _ace_picker.get_popup_rect().has_point(get_global_mouse_position()):
		return
	_ace_picker.close()


func _on_open_requested() -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.title = "Open EventSheet"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(EVENT_SHEET_FILTERS)
	dialog.current_dir = _suggest_sheet_directory()
	dialog.file_selected.connect(func(path: String) -> void:
		_load_sheet_from_path(path)
		dialog.call_deferred("queue_free")
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(860, 580))


# Theme delegates → dock/theme_manager.gd. menu_bar.gd's View menu drives _on_load_theme_requested /
# _on_reload_theme_requested; the toolbar picker connects _on_theme_preset_selected + calls
# _populate_theme_picker / _refresh_theme_picker_selection back through the dock.
func _on_load_theme_requested() -> void:  # menu_bar.gd View menu
	_theme_manager._on_load_theme_requested()


func _on_set_default_theme_requested() -> void:
	_theme_manager._on_set_default_theme_requested()


func _on_reload_theme_requested() -> void:  # menu_bar.gd View menu
	_theme_manager._on_reload_theme_requested()


func _populate_theme_picker() -> void:  # menu_bar.gd (after building the toolbar theme picker)
	_theme_manager._populate_theme_picker()


func _refresh_theme_picker_selection() -> void:
	_theme_manager._refresh_theme_picker_selection()


func _on_theme_preset_selected(index: int) -> void:  # menu_bar.gd theme-picker item_selected
	_theme_manager._on_theme_preset_selected(index)


# Sheet FILE-IO delegates → dock/sheet_io.gd (EventSheetSheetIO). Bodies live there; the dock keeps
# these thin forwarders so external callers (plugin.gd, the dock/ helpers, menu_bar, command_palette)
# and the tests reach the same names + signatures unchanged. Methods called only from within the IO
# helper (_exported_script_basename, _suggest_sheet_filename, _build_initial_save_path) have no delegate.
func _load_sheet_from_path(path: String) -> void:
	_sheet_io._load_sheet_from_path(path)


## Opens a freshly-created .gd editable (not the read-only preview a casual Open gives). The plugin's
## "Create New > Event Sheet" glue calls this after writing + rescanning the new file.
func open_new_sheet(path: String) -> void:
	_sheet_io._open_new_sheet(path)


## Compiles a GDScript-backed sheet to its .gd source. Returns whether the compile succeeded (and
## sets a failure status when it does not). Shared by Save and "Open in Godot" so the latter can
## refuse to open a stale source when the sheet doesn't currently compile.
func _save_backed_sheet() -> bool:
	return _sheet_io._save_backed_sheet()


func _on_save_requested() -> void:
	_sheet_io._on_save_requested()


func _on_save_as_requested() -> void:
	_sheet_io._on_save_as_requested()


## "Eject" affordance: writes the sheet's compiled, standalone GDScript to a file the user
## chooses. The output depends on no EventForge/EventSheet class (parity covenant), so this
## is the concrete proof a Godot dev can adopt the plugin without lock-in - take the .gd and
## go. Distinct from Save (which keeps the paired generated script alongside the .tres).
## Activate/deactivate the MCP server (AI tools) at will. The server is a separate process,
## so we flip a marker file it re-checks live - toggling off makes a connected AI client's
## tools vanish (and any in-flight call refuse) without a reconnect. Per-machine, uncommitted.
func _toggle_mcp_server(view_popup: PopupMenu) -> void:
	var marker: String = EventSheetMCPServer.DISABLED_MARKER
	if FileAccess.file_exists(marker):
		DirAccess.remove_absolute(marker)  # was off → turn on
	else:
		var file: FileAccess = FileAccess.open(marker, FileAccess.WRITE)  # turn off
		if file != null:
			file.store_string("MCP server disabled via the EventSheets dock (View ▸ MCP Server). Delete to re-enable.")
			file.close()
	var enabled: bool = EventSheetMCPServer.is_enabled()
	if view_popup != null:
		view_popup.set_item_checked(view_popup.get_item_index(12), enabled)
	_set_status("MCP server (AI tools) is now %s." % ("ON" if enabled else "OFF"))


## Extract Selection to Include: moves the selected top-level events into a NEW library sheet
## and wires the current sheet to include it - copy-paste becomes modularization in one step.
func _extract_to_include_requested() -> void:
	if _current_sheet == null:
		_set_status("Open or create a sheet first.", true)
		return
	var rows: Array[Resource] = _selected_top_level_rows()
	if rows.is_empty():
		_set_status("Select one or more top-level events to extract into a library sheet.", true)
		return
	var dialog: FileDialog = FileDialog.new()
	dialog.title = "Extract %d row(s) to a new included sheet" % rows.size()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.tres ; EventSheet library"])
	dialog.current_path = "res://shared_logic.tres"
	dialog.file_selected.connect(func(path: String) -> void:
		_do_extract_to_include(path, rows)
		dialog.call_deferred("queue_free"))
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(860, 580))


## The selection's TOP-LEVEL source rows (extraction operates on whole top-level events).
func _selected_top_level_rows() -> Array[Resource]:
	var rows: Array[Resource] = []
	for row_data: EventRowData in _get_selected_rows_from_context():
		var resource: Resource = row_data.source_resource
		if resource != null and _current_sheet.events.has(resource) and not rows.has(resource):
			rows.append(resource)
	return rows


func _do_extract_to_include(path: String, rows: Array[Resource]) -> void:
	_extract_ops.do_extract_to_include(path, rows)



static func _scope_capture_offender(event: EventRow, actions: Array) -> String:
	return EventSheetExtractOps._scope_capture_offender(event, actions)



static func extract_actions_to_function(sheet: EventSheetResource, event: EventRow, actions_to_extract: Array, raw_name: String) -> EventFunction:
	return EventSheetExtractOps.extract_actions_to_function(sheet, event, actions_to_extract, raw_name)



## Turns arbitrary entered text into a valid snake_case GDScript identifier - so a user typing
## "Apply Physics" yields the method `apply_physics` (while ace_display_name keeps the readable text).
static func _sanitize_function_name(raw: String) -> String:
	var cleaned: String = ""
	for ch: String in raw.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			cleaned += ch
		elif cleaned.length() > 0 and not cleaned.ends_with("_"):
			cleaned += "_"
	cleaned = cleaned.trim_suffix("_")
	if cleaned.is_empty():
		return "extracted_action"
	if cleaned[0] >= "0" and cleaned[0] <= "9":
		cleaned = "_" + cleaned
	return cleaned


## True when `candidate` can't be the extracted method's name - because it's a GDScript reserved word, an
## existing sheet function, or a method ALREADY on the host/base class. Each of those would emit a .gd
## that fails to parse (`func if():`, a `queue_free` override under warnings-as-errors) or silently
## shadows a built-in - so the uniquifier skips past them, keeping the generated script valid (the
## load-bearing invariant). Reuses the shared keyword list the variable/enum dialogs already guard with.
static func _function_name_is_taken(sheet: EventSheetResource, candidate: String) -> bool:
	if EventSheetIdentifierRules.RESERVED.has(candidate):
		return true
	for function_resource: Variant in sheet.functions:
		if function_resource is EventFunction and (function_resource as EventFunction).function_name == candidate:
			return true
	var host: String = sheet.host_class.strip_edges()
	# no_inheritance = false (default) so inherited methods like Node.queue_free count too.
	if not host.is_empty() and ClassDB.class_exists(host) and ClassDB.class_has_method(host, candidate):
		return true
	return false


## A function name that is valid AND free (not reserved, not an existing function, not a host method) -
## extracted_action, apply_physics_2, queue_free_2, func_2, …
static func _unique_extracted_function_name(sheet: EventSheetResource, base: String) -> String:
	if not _function_name_is_taken(sheet, base):
		return base
	var suffix: int = 2
	while _function_name_is_taken(sheet, "%s_%d" % [base, suffix]):
		suffix += 1
	return "%s_%d" % [base, suffix]


func _extract_to_function_requested() -> void:
	_extract_ops.extract_to_function_requested()



func _prompt_extract_function_name(callback: Callable) -> void:
	_extract_ops.prompt_extract_function_name(callback)



func _set_breakpoint_condition_requested() -> void:
	_quick_prompts.set_breakpoint_condition_requested()


## Find References (whole-symbol uses across every sheet, with jump-to-sheet) - see EventSheetFindReferencesPanel.
func _find_references_requested() -> void:
	_find_refs.open()


## Generate Events from a Description (AI) → dock/ai_generate_window.gd ──
func _open_ai_generate() -> void:  # Edit menu
	_ai.open()


## Ask (View menu, id 42) → dock/ask_window.gd. Off until the project turns it on; the window
## itself says so before a word is typed.
func _open_ask() -> void:
	_ask.open()


## Reduced Motion (View menu, id 43). Nothing about the sheet changes except that it stops moving:
## pulses land at full strength, fades land at their end value, and every row still says what it said.
func _toggle_reduced_motion(view_popup: PopupMenu) -> void:
	var enabled: bool = not EventSheetAccessibility.reduced_motion()
	EventSheetAccessibility.set_reduced_motion(enabled)
	if view_popup != null:
		view_popup.set_item_checked(view_popup.get_item_index(43), enabled)
	_set_status("Reduced motion is %s." % ("on" if enabled else "off"))


## Speak This Row (View menu, id 44). The keyboard twin of reading the canvas: the selected row's
## own sentence, said aloud through the platform's voice. Says so plainly when the machine has none.
func _speak_selected_row() -> void:
	var sentence: String = _viewport.accessible_name_for_selected_row() if _viewport != null else ""
	if sentence.is_empty():
		_set_status("Select a row first.", true)
		return
	if not EventSheetAccessibility.speak(sentence):
		_set_status("This machine has no voice to read with: %s" % sentence, true)
		return
	_set_status(sentence)


## Object Properties (View menu, id 45). Clicking a row's object name opens its popup; a keyboard
## has no pointer, so the same popup opens from the selected row here.
func _open_properties_for_selected_row() -> void:
	var object_label: String = _viewport.object_label_for_selected_row() if _viewport != null else ""
	if object_label.is_empty():
		_set_status("Select a row that names an object first.", true)
		return
	open_object_properties(object_label)


## Manage Includes (browse/add/remove/reorder included library sheets) - see EventSheetIncludeManager.
func _open_include_manager() -> void:
	_includes.open()


func _export_gdscript_requested() -> void:
	_sheet_io._export_gdscript_requested()


func _save_sheet_as_text_requested() -> void:
	_sheet_io._save_sheet_as_text_requested()


func _write_exported_gdscript(path: String) -> void:
	_sheet_io._write_exported_gdscript(path)


func _save_sheet_to_path(path: String) -> void:
	_sheet_io._save_sheet_to_path(path)


## Saves the sheet as a plain .gd (no .tres): compiles it to that path, then re-opens the .gd as the
## GDScript-backed source of truth, so the file IS the sheet and future edits round-trip through it.
## Returns whether it saved.
func _save_sheet_as_gdscript(path: String) -> bool:
	return _sheet_io._save_sheet_as_gdscript(path)


func _on_add_event_requested() -> void:
	_add_rows.on_add_event_requested()



func _on_add_signal_event_requested() -> void:
	_add_rows.on_add_signal_event_requested()



func _on_add_condition_requested() -> void:
	_add_rows.on_add_condition_requested()



func _on_add_action_requested() -> void:
	_add_rows.on_add_action_requested()



func _on_add_comment_requested() -> void:
	_add_rows.on_add_comment_requested()



func _on_add_group_requested() -> void:
	_add_rows.on_add_group_requested()



func _begin_group_rename(group: EventGroup) -> void:
	_add_rows.begin_group_rename(group)



func _on_group_edit_requested(group: EventGroup) -> void:
	_add_rows.on_group_edit_requested(group)



func apply_group_edit(group: EventGroup, new_name: String, new_desc: String, extras: Dictionary = {}) -> bool:
	return _add_rows.apply_group_edit(group, new_name, new_desc, extras)



static func set_group_fields(group: EventGroup, new_name: String, new_desc: String, extras: Dictionary = {}) -> String:
	return EventSheetQuickPromptDialogs.set_group_fields(group, new_name, new_desc, extras)


func _on_duplicate_requested() -> void:
	_add_rows.on_duplicate_requested()



## A fresh 8-hex-digit token for a baked `{uid}` local. The previous random-only draw could repeat
## within one event body (two ACEs → two identical locals → invalid GDScript); this tracks every
## token minted this session and re-draws on a clash, so two mints never collide. Full 32-bit (no
## top-bit mask) keeps the keyspace whole for cross-session distinctness, and the 8-hex width
## matches the re-bake regex `__[a-z_]+_([0-9a-f]{8})`.
static var _minted_uid_tokens: Dictionary = {}


static func _fresh_uid_token() -> String:
	var token: String = "%08x" % randi()
	while _minted_uid_tokens.has(token):
		token = "%08x" % randi()
	_minted_uid_tokens[token] = true
	return token


func _assign_fresh_event_uids(row: EventRow) -> void:
	_add_rows.assign_fresh_event_uids(row)



# ── Sheet zoom ──────────────────────────────────────────────────────────────────────
# Ctrl+wheel, Ctrl+= / Ctrl+-, Ctrl+0 and the status-bar pill are four ways into ONE value: the
# sheet zoom, 50% to 200%, remembered per LAYOUT and not per file - open a second sheet and it is
# already at the zoom you were reading at. Row density (Comfortable / Compact) stays its own
# choice: density trades whitespace for rows, zoom changes how big everything is drawn.
var _zoom_pill: MenuButton = null


## The status-bar zoom pill: the current percentage, and the six steps plus Reset behind it.
func _build_zoom_pill() -> MenuButton:
	_zoom_pill = MenuButton.new()
	_zoom_pill.name = "EventSheetZoomPill"
	_zoom_pill.flat = true
	_zoom_pill.tooltip_text = "Zoom the sheet (Ctrl + mouse wheel, Ctrl + + / Ctrl + -, Ctrl + 0 for 100%). Remembered for every sheet you open."
	var popup: PopupMenu = _zoom_pill.get_popup()
	for level_index: int in range(EventSheetPalette.SHEET_ZOOM_LEVELS.size()):
		popup.add_item(EventSheetPalette.sheet_zoom_label(EventSheetPalette.SHEET_ZOOM_LEVELS[level_index]), level_index)
	popup.add_separator()
	popup.add_item("Reset zoom", 100)
	popup.id_pressed.connect(func(id: int) -> void:
		if id == 100:
			_on_zoom_reset_requested()
		elif id >= 0 and id < EventSheetPalette.SHEET_ZOOM_LEVELS.size():
			_apply_sheet_zoom(EventSheetPalette.SHEET_ZOOM_LEVELS[id]))
	_refresh_zoom_pill()
	return _zoom_pill


func _refresh_zoom_pill() -> void:
	if _zoom_pill == null:
		return
	_zoom_pill.text = EventSheetPalette.sheet_zoom_label(EventSheetPalette.sheet_zoom())


## Sets the zoom on every open view at once and remembers it, then says it in the status line.
func _apply_sheet_zoom(factor: float) -> void:
	EventSheetPalette.set_sheet_zoom(factor)
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view != null:
			view.set_zoom_factor(EventSheetPalette.sheet_zoom())
	_refresh_zoom_pill()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var settings: EditorSettings = EditorInterface.get_editor_settings()
		if settings != null:
			settings.set_project_metadata("eventsheets", "sheet_zoom", EventSheetPalette.sheet_zoom())
	_set_status("Zoom: %s" % EventSheetPalette.sheet_zoom_label(EventSheetPalette.sheet_zoom()))


## A view zoomed itself (Ctrl+wheel on the canvas): carry the new factor everywhere else.
func _on_viewport_zoom_changed(factor: float) -> void:
	if is_equal_approx(factor, EventSheetPalette.sheet_zoom()):
		return
	_apply_sheet_zoom(factor)


## Restores the remembered zoom at startup, and onto a view that was only just created.
func _apply_sheet_zoom_pref() -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var settings: EditorSettings = EditorInterface.get_editor_settings()
		if settings != null:
			EventSheetPalette.set_sheet_zoom(float(settings.get_project_metadata("eventsheets", "sheet_zoom", 1.0)))
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view != null:
			view.set_zoom_factor(EventSheetPalette.sheet_zoom())
	_refresh_zoom_pill()


func _on_zoom_in_requested() -> void:
	_apply_sheet_zoom(EventSheetPalette.step_sheet_zoom(EventSheetPalette.sheet_zoom(), 1))


func _on_zoom_out_requested() -> void:
	_apply_sheet_zoom(EventSheetPalette.step_sheet_zoom(EventSheetPalette.sheet_zoom(), -1))


func _on_zoom_reset_requested() -> void:
	_apply_sheet_zoom(1.0)


## View ▸ Properties Bar: show/hide the bar beside the sheet and tick the menu to match.
func _toggle_properties_bar(view_popup: PopupMenu) -> void:
	var open: bool = not _properties_bar.is_open()
	_properties_bar.set_open(open)
	if view_popup != null:
		var item_index: int = view_popup.get_item_index(41)
		if item_index >= 0:
			view_popup.set_item_checked(item_index, open)
	_set_status("Properties bar %s." % ("shown" if open else "hidden"))


# ── Clipboard / copy-paste → dock/clipboard.gd ──────────────────────────────────────
# The copy/paste cluster (internal clipboard + portable snippets + raw-GDScript paste) lives in
# EventSheetClipboard, which also OWNS the internal `_clipboard` state (no external reader). Thin
# delegates keep the original names/signatures so menu_bar (_dock._on_copy_requested /
# _dock._on_paste_requested), author_actions (_dock._top_level_selected_resources /
# _dock._paste_snippet_text), gdscript_paste_test (editor._paste_gdscript_text),
# inflow_gdscript_test (editor._add_gdscript_action_to_context_row) and the copy/paste tests resolve
# unchanged. `_ensure_sheet_for_editing` / `_ensure_selected_event` (the pre-edit guards that sat
# interleaved right after this block) stay on the dock, just below.
func _on_copy_requested() -> void:  # menu_bar Edit menu + event_sheet_editor_test
	_clipboard_glue._on_copy_requested()


func _top_level_selected_resources() -> Array:  # author_actions + bulk row ops
	return _clipboard_glue._top_level_selected_resources()


func _on_paste_requested() -> void:  # menu_bar Edit menu + event_sheet_editor_test
	_clipboard_glue._on_paste_requested()


func _paste_snippet_text(text: String, action_name: String = "Paste Snippet") -> bool:  # author_actions _insert_snippet_path + snippet_share_test + EventSheets.insert_snippet
	return _clipboard_glue._paste_snippet_text(text, action_name)


func _add_gdscript_action_to_context_row() -> void:  # row context menu + inflow_gdscript_test
	_clipboard_glue._add_gdscript_action_to_context_row()


func _paste_gdscript_text(text: String) -> bool:  # paste flow + gdscript_paste_test
	return _clipboard_glue._paste_gdscript_text(text)


func _ensure_sheet_for_editing() -> bool:
	if _current_sheet != null:
		return true
	_set_status("Create or open an EventSheet first.", true)
	return false


func _ensure_selected_event() -> bool:
	if not _ensure_sheet_for_editing():
		return false
	var selected: Resource = _active_view().get_selected_context().get("source_resource", null)
	if selected is EventRow:
		return true
	_set_status("Select an event row first.", true)
	return false


## The selected event (or the event owning a selected condition/action), for actions that need a
## target event without a right-click context - the toolbar/menu "Add Code (GDScript)" path.
func _selected_event_for_action() -> EventRow:
	var context: Dictionary = _active_view().get_selected_context()
	var selected: Resource = context.get("source_resource", null)
	return selected as EventRow if selected is EventRow else null


## Toolbar/menu "Add Code (GDScript)": event-sheet script action on the selected event.
func _on_add_gdscript_action_requested() -> void:
	if not _ensure_sheet_for_editing():
		return
	_clipboard_glue._add_gdscript_action_to_event(null)

# ── ACE application + drag-drop - delegates to EventSheetACEApply ─────────────
# The ACE-application + row/ACE drag-drop bodies now live in dock/ace_apply.gd. These thin
# forwarders keep the original names + signatures so the connect() sites above, the sibling
# dock/ helpers (variables_manager / comment_and_scope_dialogs reach _find_resource_location /
# _group_children_array), multi_view_manager (connects _on_viewport_ace_picker_requested /
# _on_viewport_ace_edit_requested by name), and the tests all resolve unchanged.


func _on_ace_picker_selected(definition: ACEDefinition, context: Dictionary) -> void:
	_ace_apply._on_ace_picker_selected(definition, context)


## S27. The Add event dialog's "(none - runs every tick)" entry: a blank event, which is a real
## event that runs every tick.
func _on_picker_blank_event_selected(context: Dictionary) -> void:
	_ace_apply.add_blank_event(context)


func _on_ace_params_back_requested(definition: ACEDefinition, context: Dictionary) -> void:
	_ace_apply._on_ace_params_back_requested(definition, context)


func _unlock_preview_for_edit() -> void:
	_ace_apply._unlock_preview_for_edit()


func _on_viewport_ace_picker_requested(row_data: EventRowData, lane: String) -> void:
	_ace_apply._on_viewport_ace_picker_requested(row_data, lane)


func _on_viewport_ace_edit_requested(row_data: EventRowData, span_index: int, metadata: Dictionary) -> void:
	_ace_apply._on_viewport_ace_edit_requested(row_data, span_index, metadata)


func _on_ace_params_confirmed(definition: ACEDefinition, values: Dictionary, context: Dictionary) -> void:
	_ace_apply._on_ace_params_confirmed(definition, values, context)


## K2 - the Compare dialog confirmed. It answers with an ACE ID rather than a definition, because
## which of the five comparison conditions the row becomes is exactly what the dialog decides; the
## row is then applied through the ordinary path, so undo, replace-in-place and the picker's context
## all behave as they do for any other condition.
func _on_compare_confirmed(ace_id: String, params: Dictionary, negated: bool, context: Dictionary) -> void:
	_ace_apply._on_compare_confirmed(ace_id, params, negated, context)


func _apply_ace_definition(definition: ACEDefinition, params: Dictionary, context: Dictionary) -> void:
	_ace_apply._apply_ace_definition(definition, params, context)


func _bake_trigger_signature(event_row: EventRow, definition: ACEDefinition) -> void:
	_ace_apply._bake_trigger_signature(event_row, definition)


func _create_condition_from_definition(definition: ACEDefinition, params: Dictionary) -> ACECondition:
	return _ace_apply._create_condition_from_definition(definition, params)


func _create_action_from_definition(definition: ACEDefinition, params: Dictionary) -> ACEAction:
	return _ace_apply._create_action_from_definition(definition, params)


func _baked_template_for(definition: ACEDefinition) -> String:
	return _ace_apply._baked_template_for(definition)


func _resolve_definition_params(definition: ACEDefinition, row_params: Dictionary) -> Dictionary:
	return _ace_apply._resolve_definition_params(definition, row_params)


func _insert_row_below_selection(row_resource: Resource, explicit_selected_resource: Resource = null) -> void:
	_ace_apply._insert_row_below_selection(row_resource, explicit_selected_resource)


func _insert_row_above_selection(row_resource: Resource, explicit_selected_resource: Resource = null) -> void:
	_ace_apply._insert_row_above_selection(row_resource, explicit_selected_resource)


func _find_resource_location(target: Resource) -> Dictionary:
	return _ace_apply._find_resource_location(target)


func _find_resource_location_in_array(target: Resource, container: Array) -> Dictionary:
	return _ace_apply._find_resource_location_in_array(target, container)


func _group_children_array(group: EventGroup) -> Array:
	return _ace_apply._group_children_array(group)


func _on_row_drop_requested(source_row: EventRowData, target_row: EventRowData, drop_mode: String = "before", copy_mode: bool = false) -> void:
	_ace_apply._on_row_drop_requested(source_row, target_row, drop_mode, copy_mode)


func _on_rows_drop_requested(source_rows: Array, target_row: EventRowData, drop_mode: String = "before", copy_mode: bool = false) -> void:
	_ace_apply._on_rows_drop_requested(source_rows, target_row, drop_mode, copy_mode)


func _move_rows(source_rows: Array, target_row: EventRowData, drop_mode: String, copy_mode: bool = false) -> void:
	_ace_apply._move_rows(source_rows, target_row, drop_mode, copy_mode)


func _on_viewport_ace_drop_requested(source_entries: Array, target_row: EventRowData, target_lane: String, target_ace_index: int, insert_mode: String, copy_mode: bool = false) -> void:
	_ace_apply._on_viewport_ace_drop_requested(source_entries, target_row, target_lane, target_ace_index, insert_mode, copy_mode)


func _normalize_ace_drag_entries(source_entries: Array, lane: String) -> Array:
	return _ace_apply._normalize_ace_drag_entries(source_entries, lane)


func _remove_drag_entry_from_source(entry: Dictionary) -> void:
	_ace_apply._remove_drag_entry_from_source(entry)


func _drag_entry_is_trigger_like(entry: Dictionary) -> bool:
	return _ace_apply._drag_entry_is_trigger_like(entry)


func _event_has_trigger_like(event_row: EventRow, excluded_resources: Array = []) -> bool:
	return _ace_apply._event_has_trigger_like(event_row, excluded_resources)


func _is_trigger_condition(condition: ACECondition) -> bool:
	return _ace_apply._is_trigger_condition(condition)


func _event_ace_array(event_row: EventRow, lane: String) -> Array:
	return _ace_apply._event_ace_array(event_row, lane)


func _resolve_event_ace_resource(event_row: EventRow, lane: String, ace_index: int) -> Resource:
	return _ace_apply._resolve_event_ace_resource(event_row, lane, ace_index)


func _on_ace_preview_requested(source_label: String, definitions: Array[ACEDefinition]) -> void:
	_ace_apply._on_ace_preview_requested(source_label, definitions)


func _ace_type_label(ace_type: int) -> String:
	return _ace_apply._ace_type_label(ace_type)


func _on_viewport_drag_status_requested(message: String, is_error: bool) -> void:
	_ace_apply._on_viewport_drag_status_requested(message, is_error)


## Returns the best available EventSheet file name suggestion for save dialogs.
## Returns the preferred directory for open/save dialogs, defaulting to res:// (open + theme dialogs).
func _suggest_sheet_directory() -> String:
	return _sheet_io._suggest_sheet_directory()


## Ensures save paths always include a valid filename and EventSheet resource extension.
func _normalize_sheet_save_path(path: String) -> String:
	return _sheet_io._normalize_sheet_save_path(path)

var _raw_code_dialog: ConfirmationDialog = null
var _raw_code_edit: CodeEdit = null
var _raw_code_target: RawCodeRow = null
var _raw_code_in_flow: bool = false
var _raw_code_hint: Label = null
var _raw_code_lint_label: Label = null

# ── "Open in Godot" ──────────────────────────────────────────────────────────
# Hands GDScript to Godot's own script editor - always a REAL file: a custom-ACE provider script, or
# a code-backed sheet's .gd source (which the block/generated actions compile to and then open).
# Sheets with no .gd source (.tres) have nothing to open, so those actions nudge the user to Save As.

# ── GDScript provenance panel ────────────────────────────────────────────────
# Read-only side panel showing the generated GDScript; selecting a sheet row highlights the
# exact lines it compiles to (sheet → code provenance, via the compiler's source_map).
var _code_edit: CodeEdit = null
var _code_source_map: Array = []
var _code_panel_highlight: Vector2i = Vector2i(-1, -1)
const CODE_PANEL_HIGHLIGHT_COLOR := Color(0.35, 0.55, 0.95, 0.18)


func _refresh_open_sheets_panel() -> void:
	_code_panel_glue.refresh_open_sheets_panel()



func _toggle_open_sheets_panel(view_popup: PopupMenu) -> void:
	_code_panel_glue.toggle_open_sheets_panel(view_popup)



func _refresh_anatomy_panel() -> void:
	_code_panel_glue.refresh_anatomy_panel()



func _on_open_sheets_panel_collapsed(collapsed: bool) -> void:
	_code_panel_glue.on_open_sheets_panel_collapsed(collapsed)



func _read_open_sheets_panel_prefs() -> Dictionary:
	return _code_panel_glue.read_open_sheets_panel_prefs()



func _save_open_sheets_panel_prefs() -> void:
	_code_panel_glue.save_open_sheets_panel_prefs()



func _apply_open_sheets_panel_prefs() -> void:
	_code_panel_glue.apply_open_sheets_panel_prefs()



func _toggle_code_panel() -> void:
	_code_panel_glue.toggle_code_panel()



func is_code_panel_visible() -> bool:
	return _side_panel != null and _side_panel.visible


func _ensure_code_panel() -> void:
	_ui_builder.ensure_code_panel()



func _apply_editor_code_settings(code_edit: CodeEdit) -> void:
	_code_panel_glue.apply_editor_code_settings(code_edit)



func _refresh_code_panel() -> void:
	_code_panel_glue.refresh_code_panel()



func _refresh_functions_list() -> void:
	_code_panel_glue.refresh_functions_list()



func _format_function_signature(function: EventFunction) -> String:
	return _code_panel_glue.format_function_signature(function)



func _on_functions_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	_code_panel_glue.on_functions_list_item_clicked(index, at_position, mouse_button_index)



func _on_functions_menu_id_pressed(id: int) -> void:
	_code_panel_glue.on_functions_menu_id_pressed(id)



func _delete_selected_function() -> void:
	_code_panel_glue.delete_selected_function()



func _update_code_panel_highlight() -> void:
	_code_panel_glue.update_code_panel_highlight()



func _on_code_panel_gui_input(event: InputEvent) -> void:
	_code_panel_glue.on_code_panel_gui_input(event)



func goto_generated_line(line: int) -> void:
	_code_panel_glue.goto_generated_line(line)



func _select_sheet_row_for_code_line(line: int) -> void:
	_code_panel_glue.select_sheet_row_for_code_line(line)



func _on_viewport_raw_code_edit_requested(raw_resource: Resource, in_flow: bool) -> void:
	_code_panel_glue.on_viewport_raw_code_edit_requested(raw_resource, in_flow)


func _on_data_class_field_edit_requested(raw_row: Resource, field_index: int, part: String, current_text: String) -> void:  # viewport data_class_field_edit_requested
	_inline_params.on_data_class_field_edit_requested(raw_row, field_index, part, current_text)



func _ensure_raw_code_dialog() -> void:
	_ui_builder.ensure_raw_code_dialog()



func _validate_raw_code() -> void:
	_code_panel_glue.validate_raw_code()



func _populate_raw_code_completion() -> void:
	_code_panel_glue.populate_raw_code_completion()



## The current line's text up to the caret (what context completion/hints parse).
static func _text_before_caret(edit: CodeEdit) -> String:
	return edit.get_line(edit.get_caret_line()).substr(0, edit.get_caret_column())


func _on_raw_code_dialog_confirmed() -> void:
	_code_panel_glue.on_raw_code_dialog_confirmed()



# ── Visual theme editor → dock/theme_manager.gd ────────────────────────────────
# menu_bar.gd's View menu opens the editor; theme_editor_dialog.gd's "Apply To Current Sheet" reaches
# apply_theme_style via _dock.has_method("apply_theme_style") + _dock.call("apply_theme_style", …), so
# both keep dock delegates.
func _open_theme_editor() -> void:  # menu_bar.gd View menu
	_theme_manager._open_theme_editor()


func apply_theme_style(style: EventSheetEditorStyle) -> void:  # theme_editor_dialog.gd Apply-To-Current-Sheet
	_theme_manager.apply_theme_style(style)

# ── Inspector per-row param edits ───────────────────────────────────


## The Inspector's "Selected ACE" section delegates writes here: the dock owns the
## undoable sheet edit and the viewport refresh.
func _on_exposed_row_param_changed(target: Resource, param_id: String, value: Variant) -> void:
	if target == null or param_id.is_empty():
		return
	var changed: bool = _perform_undoable_sheet_edit("Edit Param (Inspector)", func() -> bool:
		var params: Dictionary = target.get("params")
		params[param_id] = value
		target.set("params", params)
		return true
	)
	if changed:
		_refresh_after_edit()
		_mark_dirty("Parameter updated from the Inspector.")


# ── Enum / Signal / Match row editors → dock/struct_row_dialogs.gd ──
func _open_enum_dialog(enum_resource: Resource) -> void:  # viewport enum_edit_requested
	_open_block_editor(enum_resource)


func _open_signal_dialog(signal_resource: Resource) -> void:  # viewport signal_edit_requested
	_open_block_editor(signal_resource)


## THE block edit dispatcher: every registered kind may own its editor (kind.edit returns
## true); anything else built on CustomBlockRow gets the generic schema dialog. Built-ins
## (enum, signal) and pack kinds dispatch identically - the registry is the single seam.
func _open_block_editor(entry: Resource) -> void:
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.kind_for(entry)
	if kind != null and kind.edit(self, entry):
		return
	if entry is CustomBlockRow:
		_custom_block_dialog.open_edit(entry)


# Custom Block API rows (dock/custom_block_dialog.gd): edit on double-click, add from the Add menu.
func _open_custom_block_dialog(block_resource: Resource) -> void:  # viewport custom_block_edit_requested
	_open_block_editor(block_resource)


func _open_custom_block_add(kind_id: String) -> void:  # Add menu
	_custom_block_dialog.open_add(kind_id)


func _open_match_dialog(match_resource: Resource) -> void:  # viewport match_edit_requested
	_struct_rows.open_match_dialog(match_resource)


# ── Rename refactoring (variable rename engine + "Rename Everywhere" dialog) → event_sheet_rename_refactor.gd ──
func _rename_variable_references(old_name: String, new_name: String) -> int:  # variables tree (2 sites)
	return _rename.rename_variable_references(old_name, new_name)


func _open_rename_dialog(old_name: String) -> void:  # variable context menu
	_rename.open(old_name)


func _rename_in_includers(old_name: String, new_name: String, candidate_paths: PackedStringArray) -> PackedStringArray:  # tedium_test
	return _rename.rename_in_includers(old_name, new_name, candidate_paths)


# ── Variables manager (global/local/tree variable authoring + usage scan) → dock/variables_manager.gd ──
# Thin delegates preserve the original public names/signatures so callers and tests don't change.
static func _tree_group_attributes(source: Dictionary) -> Dictionary:  # variable_group_roundtrip_test (static, by class name)
	return EventSheetVariablesManager._tree_group_attributes(source)


func _on_variable_dialog_confirmed(var_name: String, type_name: String, default_value: Variant, scope: String, context: Dictionary = {}, is_constant: bool = false, exported: bool = true, combo_options: PackedStringArray = PackedStringArray(), attributes: Dictionary = {}, onready: bool = false, is_static: bool = false) -> void:  # _variable_dlg.variable_confirmed
	_variables._on_variable_dialog_confirmed(var_name, type_name, default_value, scope, context, is_constant, exported, combo_options, attributes, onready, is_static)


func _on_add_global_variable_requested() -> void:
	_variables._on_add_global_variable_requested()


func _on_add_project_global_requested() -> void:  # Add ▸ Global Variable… (V)
	# G3 - with a group head selected, V means what it means everywhere else: "declare something
	# HERE". Here is the group, so the variable is one of its locals rather than a project global.
	var selected: Resource = _active_view().get_selected_context().get("source_resource", null) if _active_view() != null else null
	if selected is EventGroup:
		_context_row = _active_view().get_selected_context().get("row_data", _context_row)
		_add_group_local_variable_for(selected as EventGroup)
		return
	_global_variables.open()


## V5 - the Add variable dialog was confirmed with Scope ▸ Global: the answers it collected go to the
## global writer, which opens the chosen autoload and adds the line there in one undo step.
func _on_variable_dialog_global_requested(var_name: String, type_name: String, value_text: String, target: Dictionary) -> void:  # _variable_dlg.project_global_requested
	_global_variables.add_global(var_name, type_name, value_text, target)


func _on_add_local_variable_requested() -> void:
	_variables._on_add_local_variable_requested()


func _on_add_instance_variable_requested() -> void:
	_variables._on_add_instance_variable_requested()


func _add_tree_variable_below_context_row() -> void:
	_variables._add_tree_variable_below_context_row()


func _on_viewport_variable_edit_requested(row_data: EventRowData, metadata: Dictionary) -> void:
	_variables._on_viewport_variable_edit_requested(row_data, metadata)


func _on_variable_context_menu_id_pressed(id: int) -> void:
	_variables._on_variable_context_menu_id_pressed(id)


func _create_variable_quickfix(variable_name: String) -> bool:
	return _variables._create_variable_quickfix(variable_name)


func _collect_sheet_variable_names() -> PackedStringArray:
	return _variables._collect_sheet_variable_names()


func _context_variable_entry_from_metadata(row_data: EventRowData, metadata: Dictionary) -> Dictionary:
	return _variables._context_variable_entry_from_metadata(row_data, metadata)


func _toggle_context_variable_constant() -> void:
	_variables._toggle_context_variable_constant()


func _convert_variable_scope(entry: Dictionary, target_scope: String, target_event_uid: String = "") -> bool:
	return _variables._convert_variable_scope(entry, target_scope, target_event_uid)


func _edit_context_variable() -> void:
	_variables._edit_context_variable()

# ── Multi-view: split view (same sheet, two panes - VSCode-style) → dock/multi_view_manager.gd ──
# The split widgets + split-pane lifecycle live on _multi_view; the view-access core below
# (_active_view / _active_viewport_ref / _mirroring_selection) stays here because it's shared by
# the primary, split, AND detached panes. The split methods keep one-line delegates further down.
# The pane whose selection drives selection-based ops (toolbar copy/paste, Ctrl+/,
# Alt+arrows, dialogs opened from the toolbar). Updated whenever a pane's selection
# changes; falls back to the primary.
var _active_viewport_ref: EventSheetViewport = null


func _active_view() -> EventSheetViewport:
	if _active_viewport_ref != null and is_instance_valid(_active_viewport_ref):
		return _active_viewport_ref
	return _viewport


# ── Command palette (Ctrl+P): list + fuzzy filter + popup shell → dock/command_palette.gd ──
# Thin delegates preserve the original names/signatures so the shortcut caller and tests don't change.
# filter_commands is static-by-class-name (tests call EventSheetDock.filter_commands); it forwards to the helper's static.
static func filter_commands(commands: Array, query: String) -> Array:  # event_sheet_editor_test (static, by class name)
	return EventSheetCommandPalette.filter_commands(commands, query)


func _command_palette_commands() -> Array[Dictionary]:  # event_sheet_editor_test
	return _command_palette._command_palette_commands()


func _open_command_palette() -> void:  # Ctrl+P shortcut (_gui_input)
	_command_palette._open_command_palette()


## True when beginner-friendly Simple mode is active (advanced/code menu entries hidden).
func is_simple_mode() -> bool:
	return _simple_mode


## Toggle/set Simple mode: persists the choice per-project, updates the View-menu check,
## and rebuilds the context menus so the next right-click reflects the new surface.
func set_simple_mode(enabled: bool) -> void:
	_simple_mode = enabled
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var settings: EditorSettings = EditorInterface.get_editor_settings()
		if settings != null:
			settings.set_project_metadata("eventsheets", "simple_mode", enabled)
	if _view_popup != null:
		var idx: int = _view_popup.get_item_index(11)
		if idx >= 0:
			_view_popup.set_item_checked(idx, enabled)
	if _simple_mode_button != null:
		_simple_mode_button.set_pressed_no_signal(enabled)
	# Simple Mode doubles as the READING lens: body comments render as italic captions (intent
	# first, mechanics under it) on every open view. View state only - toggling back restores
	# the programmer look instantly and no row is touched.
	for reading_view: EventSheetViewport in _multi_view.all_views():
		if reading_view != null:
			reading_view.set_reading_mode(enabled)
	_apply_simple_mode_gates()
	_set_status("Simple mode ON - advanced entries hidden." if enabled else "Expert mode - all entries shown.")


## Applies Simple Mode to the always-visible surfaces it gates: the toolbar's deliberate
## drop-to-code button hides, and the Add menu's code item disables with a pointer to the toggle.
## (The picker and the right-click menus apply their own gates when they open.)
func _apply_simple_mode_gates() -> void:
	# The Properties bar is an expert surface: a beginner's sheet is the sheet. View ▸ Properties
	# Bar brings it back at any time.
	_properties_bar.set_open(not _simple_mode)
	# T13 / T18 - Simple mode is the audience flag, so it is what decides these two by default. An
	# explicit View-menu choice still wins; these only re-resolve the "nobody said" case.
	_project_bar_glue.apply_visibility()
	_beginner_toolbar.apply_visibility()
	# V13 - Simple Mode pins the variable dial at the sentence. Expert mode does not push it back:
	# the reader's own choice of dial is theirs to keep.
	if _simple_mode:
		set_variable_row_view(EventSheetCodeEcho.VIEW_SENTENCE)
	if _add_code_button != null:
		_add_code_button.visible = not _simple_mode
	if _add_menu_popup != null:
		var code_index: int = _add_menu_popup.get_item_index(4)
		if code_index >= 0:
			_add_menu_popup.set_item_disabled(code_index, _simple_mode)
			_add_menu_popup.set_item_tooltip(code_index, "Turn off Simple Mode (toolbar) to add script blocks." if _simple_mode else "")


func _load_simple_mode_preference() -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings != null:
		_simple_mode = bool(settings.get_project_metadata("eventsheets", "simple_mode", false))
	# Row density rides the same startup read: applied before the first layout, so a
	# Compact-preferring project never flashes Comfortable.
	_apply_compact_rows_pref()
	_apply_humanized_names_pref()
	_apply_familiar_words_pref()
	_apply_patterns_lens_pref()
	# The sheet zoom rides the same startup read: it belongs to the layout, so the first sheet
	# opens at the size the last one was being read at.
	_apply_sheet_zoom_pref()


## Declutter toggle: show/hide the trailing "+ Add event…" affordance rows across every
## live view, and reflect the new state in the View menu checkbox.
## View > Object Icons: show/hide the icons before object/module names (rows + group folders).
## Icons live in span metadata, so a rebuild (set_sheet) applies the flip; the icon cache stays
## warm for flipping back.
## View > Event Numbers: event rows show their stable event-sheet number (sheet order) in the
## gutter (default); off restores the flat row index on every row.
func _toggle_event_numbers(view_popup: PopupMenu) -> void:
	var show_numbers: bool = true
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view == null:
			continue
		view.show_event_numbers = not view.show_event_numbers
		show_numbers = view.show_event_numbers
		view.queue_redraw()
	if view_popup != null:
		view_popup.set_item_checked(view_popup.get_item_index(16), show_numbers)


## Go to Event N (the Command Palette entry): jump to the stable event number.
func _open_go_to_event_dialog() -> void:
	if _current_sheet == null:
		_set_status("Open a sheet first.", true)
		return
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Go to event"
	dialog.ok_button_text = "Go"
	var number_edit: SpinBox = SpinBox.new()
	number_edit.min_value = 1
	number_edit.max_value = 99999
	number_edit.value = 1
	dialog.add_child(EventSheetPopupUI.titled_card("Event number", EventSheetPopupUI.form_row("Go to event", number_edit)))
	dialog.confirmed.connect(func() -> void:
		var target: EventRow = EventSheetViewport.event_by_number(_current_sheet.events, int(number_edit.value))
		if target == null:
			_set_status("There is no event %d." % int(number_edit.value), true)
		elif _viewport != null:
			_viewport.reveal_resource(target)
			_viewport.select_resource(target))
	# The dialog frees on ANY exit - confirm auto-hides, cancel/Esc, or the titlebar X.
	# Freeing only on the success branch leaked one hidden AcceptDialog per dismissal.
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	EventSheetL10n.apply_to(dialog)
	add_child(dialog)
	dialog.popup_centered(Vector2i(320, 160))
	number_edit.get_line_edit().grab_focus()


## True when the object-name column is ALIGNED (a fixed width, so every row's text starts at the same
## edge) rather than in flow mode, where the text follows each label. Read by the View menu to seed
## its check mark; the conditions lane is the one asked, since the toggle moves both together.
## View ▾ "Compact Rows": Comfortable (default, byte-identical to the pre-toggle layout) or
## Compact - EventSheetPalette.row_density() shrinks line padding, the row-height floor and the
## event-block gap, never the text (theme font) and never the chrome (ui_scale). Per-project,
## per-user (editor metadata, not repo state).
func _compact_rows_enabled() -> bool:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		return bool(EditorInterface.get_editor_settings().get_project_metadata("eventsheets", "compact_rows", false))
	return false


func _apply_compact_rows_pref() -> void:
	EventSheetPalette.set_row_density(EventSheetPalette.COMPACT_ROW_DENSITY if _compact_rows_enabled() else 1.0)


func _toggle_compact_rows(view_popup: PopupMenu) -> void:
	var compact: bool = not _compact_rows_enabled()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata("eventsheets", "compact_rows", compact)
	EventSheetPalette.set_row_density(EventSheetPalette.COMPACT_ROW_DENSITY if compact else 1.0)
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view == null:
			continue
		# Geometry changed, spans did not - the same invalidation a live column drag uses.
		view._update_layout_style_signature(view._get_font_size())
		view._layout_cache.clear()
		view.queue_redraw()
	if view_popup != null:
		var item_index: int = view_popup.get_item_index(19)
		if item_index >= 0:
			view_popup.set_item_checked(item_index, compact)
	_set_status("Compact rows - more events on screen, same text size." if compact
		else "Comfortable rows - the default breathing room.")


## M9 - View ▾ "Humanized Names". Three states, two of them the user's: AUTO (nothing stored, the
## default) means the lens follows the surface - on where a sheet is being READ (an opened pack, a
## .gd preview, the Reading lens), off where one is being AUTHORED - and an explicit choice, once
## made, applies everywhere and persists per-project per-user (editor metadata, not repo state),
## exactly like Compact Rows. Stored as an int so "no choice yet" stays distinguishable from "off".
const HUMANIZED_NAMES_AUTO := -1


func _humanized_names_override() -> int:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		return int(EditorInterface.get_editor_settings().get_project_metadata("eventsheets", "humanized_names", HUMANIZED_NAMES_AUTO))
	return HUMANIZED_NAMES_AUTO


## What the View menu's check mark shows: the lens as it is actually running right now, which
## under AUTO is whatever the current view resolves it to.
func _humanized_names_enabled() -> bool:
	if _viewport != null:
		return _viewport.humanize_names_enabled()
	return _humanized_names_override() == 1


func _apply_humanized_names_pref() -> void:
	var stored: int = _humanized_names_override()
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view != null:
			view.humanize_names_override = stored


func _toggle_humanized_names(view_popup: PopupMenu) -> void:
	var humanized: bool = not _humanized_names_enabled()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata("eventsheets", "humanized_names", 1 if humanized else 0)
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view == null:
			continue
		view.humanize_names_override = 1 if humanized else 0
		# Names are baked into span TEXT at build time, so the lens needs a span rebuild, not a
		# redraw - the same reason Object Icons re-sets the sheet rather than queueing a repaint.
		view.set_sheet(_current_sheet)
	if view_popup != null:
		var item_index: int = view_popup.get_item_index(20)
		if item_index >= 0:
			view_popup.set_item_checked(item_index, humanized)
	_set_status("Humanized names - variables read as words; the raw name is on hover." if humanized
		else "Raw names - variables read exactly as they are spelled in the file.")


## M46 - View ▾ "Familiar Words". OFF by default and stored as a plain on/off (unlike the
## humanized-names lens, which has an AUTO state): this one does not respell the user's own names, it
## swaps a handful of Godot nouns for the words other event-sheet editors use - scene becomes
## layout, pausing becomes a time scale of 0, a CanvasLayer becomes a layer - with the Godot word
## still on hover. Persisted per project per user in editor metadata, exactly like Compact Rows.
func _familiar_words_enabled() -> bool:
	if _viewport != null:
		return _viewport.familiar_words_enabled()
	return _stored_familiar_words()


## S24 - whether the sheet NAMES the patterns its readings claimed. On by default, because naming
## the pattern is the teaching moment and a beginner is exactly who needs it; turning it off shows
## the plain statement sentences underneath, which is how a doubter checks the claim. Persisted per
## project per user in editor metadata, exactly like Familiar Words.
func _patterns_lens_enabled() -> bool:
	if _viewport != null:
		return _viewport.patterns_lens_enabled()
	return _stored_patterns_lens()


func _stored_patterns_lens() -> bool:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		return bool(EditorInterface.get_editor_settings().get_project_metadata("eventsheets", "patterns_lens", true))
	return true


func _apply_patterns_lens_pref() -> void:
	var stored: bool = _stored_patterns_lens()
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view != null:
			view.patterns_lens = stored


func _toggle_patterns_lens(view_popup: PopupMenu) -> void:
	var showing: bool = not _patterns_lens_enabled()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata("eventsheets", "patterns_lens", showing)
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view == null:
			continue
		view.patterns_lens = showing
		# The chip is a SPAN built at row-build time, so the lens needs a span rebuild rather than a
		# redraw - the same reason the Familiar Words toggle re-sets the sheet.
		view.set_sheet(_current_sheet)
	if view_popup != null:
		var item_index: int = view_popup.get_item_index(27)
		if item_index >= 0:
			view_popup.set_item_checked(item_index, showing)
	_set_status("Patterns - an event that is a known shape says which one, and its hover says why." if showing
		else "Patterns off - every event reads as its own plain sentences.")


func _stored_familiar_words() -> bool:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		return bool(EditorInterface.get_editor_settings().get_project_metadata("eventsheets", "familiar_words", false))
	return false


func _apply_familiar_words_pref() -> void:
	var stored: bool = _stored_familiar_words()
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view != null:
			view.familiar_words = stored
	# T13 - the Project bar's headings follow the same toggle the rows do, so the reader never sees
	# one surface using Godot's word while the other uses theirs.
	_project_bar_glue.refresh_reading_prefs()


func _toggle_familiar_words(view_popup: PopupMenu) -> void:
	var familiar: bool = not _familiar_words_enabled()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata("eventsheets", "familiar_words", familiar)
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view == null:
			continue
		view.familiar_words = familiar
		# The words are baked into span TEXT at build time, so the glossary needs a span rebuild, not
		# a redraw - the same reason the humanized-names toggle re-sets the sheet.
		view.set_sheet(_current_sheet)
	if view_popup != null:
		var item_index: int = view_popup.get_item_index(21)
		if item_index >= 0:
			view_popup.set_item_checked(item_index, familiar)
	_project_bar_glue.refresh_reading_prefs()
	_set_status("Familiar words - layout, time scale, layer; the Godot word is on hover." if familiar
		else "Godot words - scenes, pausing and CanvasLayers read by their Godot names.")


func _object_columns_aligned() -> bool:
	if _viewport == null:
		return false
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	# No style means nothing is aligned. Reporting "aligned" here made the first click of the toggle
	# switch TO flow on a sheet that was never aligned - the two functions must agree on what null is.
	return event_style != null and event_style.condition_object_column_width > 0


## View ▾ "Aligned Object Columns": flips the event-sheet object column between ALIGNED (the default -
## every row's text starts at the same edge, so a sheet scans as a table) and FLOW (each row's text
## follows its own object name, so it starts somewhere different on every row). The condition lane is
## written through the same handler a divider DRAG uses, so a default-themed sheet is promoted to a
## concrete style, persisted and marked dirty exactly as dragging the column would; the actions lane
## then rides that same promoted style. A hand-dragged width is what turning it back on restores to.
func _toggle_object_column_alignment(view_popup: PopupMenu) -> void:
	if _viewport == null:
		return
	var aligning: bool = not _object_columns_aligned()
	var width: int = EventSheetPalette.OBJECT_COLUMN_WIDTH if aligning else 0
	if _current_sheet == null:
		_set_status("Open a sheet first - there is nothing to store the column setting on.", true)
		return
	_on_viewport_object_column_width_changed("condition", width)
	if _current_sheet.editor_style != null:
		_current_sheet.editor_style.get_event_style().action_object_column_width = width
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view == null:
			continue
		var view_style: EventSheetEventStyle = view._get_event_style()
		if view_style != null:
			view_style.condition_object_column_width = width
			view_style.action_object_column_width = width
		# Geometry changed, spans did not - the same invalidation the live column drag uses.
		view._update_layout_style_signature(view._get_font_size())
		view._layout_cache.clear()
		view.queue_redraw()
	if view_popup != null:
		var aligned_index: int = view_popup.get_item_index(18)
		if aligned_index >= 0:
			view_popup.set_item_checked(aligned_index, aligning)
	_set_status(
		"Object columns aligned - every row's text starts at the same edge."
		if aligning
		else "Object columns flow - each row's text follows its own object name."
	)


func _toggle_object_icons(view_popup: PopupMenu) -> void:
	var show_icons: bool = true
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view == null:
			continue
		view.show_object_icons = not view.show_object_icons
		show_icons = view.show_object_icons
		view.set_sheet(_current_sheet)
	if view_popup != null:
		var icons_index: int = view_popup.get_item_index(15)
		if icons_index >= 0:
			view_popup.set_item_checked(icons_index, show_icons)
	_set_status("Object icons shown." if show_icons else "Object icons hidden (text-only sheet).")


func _toggle_add_event_rows(view_popup: PopupMenu) -> void:
	var show_rows: bool = true
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view == null:
			continue
		view.show_add_event_footers = not view.show_add_event_footers
		show_rows = view.show_add_event_footers
		view.set_sheet(_current_sheet)
	if view_popup != null:
		var idx: int = view_popup.get_item_index(9)
		if idx >= 0:
			view_popup.set_item_checked(idx, show_rows)
	_set_status("Add-event rows shown." if show_rows else "Add-event rows hidden for a cleaner sheet.")


# Split-view delegates → dock/multi_view_manager.gd (split widgets + lifecycle live there).
func _toggle_split_view() -> void:
	_multi_view._toggle_split_view()


func _connect_view_signals(view: EventSheetViewport) -> void:  # also reused by the detached pane below
	_multi_view._connect_view_signals(view)


func _open_row_in_split(row_data: EventRowData) -> void:
	_multi_view._open_row_in_split(row_data)

# ── Multi-view P2: detached window (a pane on another monitor) ────────────────────────
var _detached_window: Window = null
var _detached_viewport: EventSheetViewport = null


## Toggles a floating OS window hosting another full-editing pane over the same sheet -
## drag it to a second monitor while debugging. Same shared state + refresh bus as the
## split pane.
func _toggle_detached_view() -> void:
	if _detached_window != null:
		_close_detached_view()
		_set_status("Detached view closed.")
		return
	if _viewport == null:
		return
	_detached_window = Window.new()
	_detached_window.title = "Event Sheet - detached view"
	_detached_window.size = Vector2i(960, 640)
	_detached_window.close_requested.connect(_close_detached_view)
	var detached_scroll: ScrollContainer = ScrollContainer.new()
	detached_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detached_window.add_child(detached_scroll)
	_detached_viewport = EventSheetViewport.new()
	_detached_viewport.name = "EventSheetDetachedViewport"
	_detached_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detached_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detached_viewport.set_ace_registry(_ace_registry)
	_detached_viewport.adopt_shared_state(_viewport.get_shared_state())
	# The hit-counts lens is a per-pane flag; a new pane inherits the choice already made.
	_detached_viewport.show_hit_counts = _viewport.show_hit_counts
	detached_scroll.add_child(_detached_viewport)
	_connect_view_signals(_detached_viewport)
	add_child(_detached_window)
	_detached_viewport.set_sheet(_current_sheet)
	if is_inside_tree():
		_detached_window.popup_centered(Vector2i(960, 640))
	_set_status("Detached view opened - drag it anywhere; both panes edit the same sheet.")


func _close_detached_view() -> void:
	if _detached_window == null:
		return
	if _active_viewport_ref == _detached_viewport:
		_active_viewport_ref = null
	_detached_window.queue_free()
	_detached_window = null
	_detached_viewport = null

# ── Multi-view P3: linked panes (follow selection) ─────────────────────────────────────
var _linked_views: bool = false
var _mirroring_selection: bool = false


## Toggles follow-selection: selecting a row in one pane scrolls/selects it in the
## others - e.g. keep the split zoomed out as an overview and click rows to focus them
## in the detail pane.
func _toggle_linked_views() -> void:
	_linked_views = not _linked_views
	_set_status("Linked panes: selection now follows across views." if _linked_views else "Panes unlinked.")


# Split-view delegates → dock/multi_view_manager.gd. _mirror_selection reads the dock's
# linked/mirroring flags (kept above) and is also called from the primary pane's _build_ui lambda.
func _mirror_selection(from_view: EventSheetViewport, row_data: EventRowData) -> void:
	_multi_view._mirror_selection(from_view, row_data)


func _close_split_view() -> void:
	_multi_view._close_split_view()


func _sync_split_sheet() -> void:
	_multi_view._sync_split_sheet()


# ── Export as Addon Pack (coverage Phase C) → dock/export_pack.gd ─────────────────────
# (Body lives in the helper; this delegate keeps the name the menu_bar Sheet menu (id 6), the
# command palette, and the phase-c / addon-composition tests reach by.)
func _export_addon_pack(base_dir_override: String = "") -> void:
	_export_pack._export_addon_pack(base_dir_override)

# ── Godot-feel: find bar, keyboard row ops, editor-native defaults ─# ── Godot-feel: find bar, keyboard row ops, editor-native defaults ─# ── Godot-feel: find bar, keyboard row ops, editor-native defaults ────────────────────
var _find_bar: HBoxContainer = null
var _lens_button: Button = null


var _replace_object_dialog: AcceptDialog = null


## Replace Object References (the event-sheet gesture, param-aware): pick a reference the
## selection actually uses, give the new one, and every matching token across the selected
## rows' params, With-Node scopes, pick filters, and raw code rewrites - token-safe
## ($Enemy never touches $EnemySpawner), one undo step.
func _open_replace_object_dialog() -> void:
	var targets: Array = _top_level_selected_resources()
	if targets.is_empty() and _context_row != null and _context_row.source_resource != null:
		targets = [_context_row.source_resource]
	if targets.is_empty():
		_set_status("Select the rows to retarget first.", true)
		return
	var references: Array[String] = EventSheetRefactor.collect_node_references(targets)
	if references.is_empty():
		_set_status("The selection has no node references ($Path, %Unique, self) to replace.", true)
		return
	if _replace_object_dialog != null and is_instance_valid(_replace_object_dialog):
		_replace_object_dialog.queue_free()
	_replace_object_dialog = AcceptDialog.new()
	_replace_object_dialog.title = "Replace Object References"
	_replace_object_dialog.ok_button_text = "Replace"
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.add_child(EventSheetPopupUI.hint_label("Every matching reference across the %d selected row(s) rewrites - params, With-Node scopes, pick filters, and script blocks. Token-safe: $Enemy never touches $EnemySpawner." % targets.size(), 420.0))
	var from_options: OptionButton = OptionButton.new()
	for reference: String in references:
		from_options.add_item(reference)
	content.add_child(EventSheetPopupUI.form_row("From", from_options))
	var to_edit: LineEdit = LineEdit.new()
	to_edit.placeholder_text = "$NewNode, %UniqueName, or self"
	to_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replace_object_dialog.register_text_enter(to_edit)
	# Autocomplete for the target: every reference the whole sheet uses + the edited
	# scene's own nodes ($children, %uniques) + self - typed text filters, free text wins.
	# Objects that have the SAME conditions and actions come first: those are the swaps that will
	# still read the same afterwards.
	var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	var to_suggestions: PackedStringArray = EventSheetReplaceObject.rank_suggestions(
		PackedStringArray(EventSheetRefactor.reference_suggestions(_current_sheet.events if _current_sheet != null else [], scene_root)),
		references[0] if not references.is_empty() else "", scene_root)
	var to_row: HBoxContainer = HBoxContainer.new()
	to_row.add_theme_constant_override("separation", 4)
	to_row.add_child(to_edit)
	var to_picker: MenuButton = EventSheetPopupUI.autocomplete_combo(to_edit, func() -> PackedStringArray: return to_suggestions)
	to_picker.tooltip_text = "Suggestions: references this sheet uses + the open scene's nodes. You can still type any value."
	to_row.add_child(to_picker)
	content.add_child(EventSheetPopupUI.form_row("To", to_row))
	_replace_object_dialog.add_child(EventSheetPopupUI.titled_card("Retarget the selection", content))
	_replace_object_dialog.confirmed.connect(func() -> void:
		var from_ref: String = from_options.get_item_text(from_options.selected) if from_options.selected >= 0 else ""
		var to_ref: String = to_edit.text.strip_edges()
		if from_ref.is_empty() or to_ref.is_empty():
			_set_status("Pick a reference and give its replacement.", true)
			return
		var counter: Dictionary = {"count": 0}
		var changed: bool = _perform_undoable_sheet_edit("Replace Object References", func() -> bool:
			counter["count"] = EventSheetRefactor.replace_node_reference(targets, from_ref, to_ref)
			return int(counter["count"]) > 0)
		if changed:
			# A parameter that named one of A's instance variables the new object does not have
			# still compiles, and then fails at runtime - so it is said here and recorded for the
			# Doctor rather than left to be discovered by a crash.
			var missing: PackedStringArray = EventSheetReplaceObject.missing_members(targets, from_ref, to_ref, scene_root)
			EventSheetReplaceObject.last_missing = {"from": from_ref, "to": to_ref, "members": missing, "path": _current_sheet_path}
			# Registered only while there IS something to report, so a clean project never carries
			# a check that can only answer "nothing".
			if missing.is_empty():
				EventSheetProjectDoctor.unregister_check("replace-object-members")
			else:
				EventSheetProjectDoctor.register_check("replace-object-members", EventSheetReplaceObject.doctor_check)
			_refresh_after_edit()
			var missing_note: String = "" if missing.is_empty() else " %s does not have %s - see the Doctor." % [to_ref, ", ".join(missing)]
			_mark_dirty("Replaced %d reference(s): %s becomes %s.%s" % [int(counter["count"]), from_ref, to_ref, missing_note])
		else:
			_set_status("Nothing matched %s in the selection." % from_ref, true))
	EventSheetL10n.apply_to(_replace_object_dialog)
	add_child(_replace_object_dialog)
	_replace_object_dialog.popup_centered(Vector2i(480, 260))
	to_edit.grab_focus()


var _batch_edit_menu: PopupMenu = null
var _data_class_field_dialog: AcceptDialog = null


## The data-class row this context click concerns - delegates to the ONE resolver the menu
## builder also uses (context_menus._data_class_row_target), so menu visibility and the
## Add/Remove Field handlers can never disagree about the target.
func _data_class_context_raw_row() -> RawCodeRow:
	return _context_menus._data_class_row_target(_context_row)


## Add Field (the "add an action" gesture, for data classes): a small Name / Type / Default
## dialog appends a canonical `var name: Type = default` line through the structured model,
## as one undo step. The transform refuses non-lifting classes and duplicate names.
func _open_data_class_add_field() -> void:
	var raw_row: RawCodeRow = _data_class_context_raw_row()
	if raw_row == null or not ViewportRowBuilder.data_class_lifts(raw_row.code):
		_set_status("Right-click a data-class block to add a field.", true)
		return
	if _data_class_field_dialog != null and is_instance_valid(_data_class_field_dialog):
		_data_class_field_dialog.queue_free()
	_data_class_field_dialog = AcceptDialog.new()
	_data_class_field_dialog.title = "Add Field"
	_data_class_field_dialog.ok_button_text = "Add"
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	var name_edit: LineEdit = LineEdit.new()
	name_edit.placeholder_text = "field_name"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(EventSheetPopupUI.form_row("Name", name_edit))
	var type_edit: LineEdit = LineEdit.new()
	type_edit.text = "int"
	type_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(EventSheetPopupUI.form_row("Type", type_edit))
	var default_edit: LineEdit = LineEdit.new()
	default_edit.placeholder_text = "(optional)"
	default_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_data_class_field_dialog.register_text_enter(default_edit)
	content.add_child(EventSheetPopupUI.form_row("Default", default_edit))
	_data_class_field_dialog.add_child(EventSheetPopupUI.titled_card("New field on this data class", content))
	_data_class_field_dialog.confirmed.connect(func() -> void:
		var new_code: String = ViewportRowBuilder.data_class_add_field(raw_row.code, name_edit.text.strip_edges(), type_edit.text, default_edit.text.strip_edges())
		if new_code.is_empty():
			_set_status("Couldn't add the field - use a plain identifier name that isn't taken, and give a type.", true)
			return
		var changed: bool = _perform_undoable_sheet_edit("Add Field", func() -> bool:
			var live_code: String = ViewportRowBuilder.data_class_add_field(raw_row.code, name_edit.text.strip_edges(), type_edit.text, default_edit.text.strip_edges())
			if live_code.is_empty():
				return false
			raw_row.code = live_code
			return true)
		if changed:
			_refresh_after_edit()
			_mark_dirty("Added field %s." % name_edit.text.strip_edges()))
	EventSheetL10n.apply_to(_data_class_field_dialog)
	add_child(_data_class_field_dialog)
	_data_class_field_dialog.popup_centered(Vector2i(420, 240))
	name_edit.grab_focus()


func _remove_data_class_field_from_context() -> void:
	var raw_row: RawCodeRow = _data_class_context_raw_row()
	var field_index: int = _context_menus._data_class_field_index(_context_row)
	if raw_row == null or field_index < 0:
		_set_status("Right-click a field row to remove it.", true)
		return
	var changed: bool = _perform_undoable_sheet_edit("Remove Field", func() -> bool:
		var live_code: String = ViewportRowBuilder.data_class_remove_field(raw_row.code, field_index)
		if live_code.is_empty():
			return false
		raw_row.code = live_code
		return true)
	if changed:
		_refresh_after_edit()
		_mark_dirty("Removed the field.")


## Batch param edit (the event-sheet edit-many reflex): any condition/action that appears more than
## once across the selected rows can be edited ONCE - the params dialog opens pre-filled
## from the first instance and OK applies those values to every matching instance as a
## single undo step. With several repeated ACEs, a small menu picks which one to edit.
func _open_batch_param_edit() -> void:
	var targets: Array = _top_level_selected_resources()
	if targets.is_empty() and _context_row != null and _context_row.source_resource != null:
		targets = [_context_row.source_resource]
	var groups: Array = EventSheetACEApply.batch_edit_groups(targets)
	if groups.is_empty():
		_set_status("No action or condition appears more than once across the selection.", true)
		return
	if groups.size() == 1:
		_open_batch_param_group(groups[0])
		return
	if _batch_edit_menu != null and is_instance_valid(_batch_edit_menu):
		_batch_edit_menu.queue_free()
	_batch_edit_menu = PopupMenu.new()
	for group_index: int in range(groups.size()):
		var group: Dictionary = groups[group_index]
		var definition: ACEDefinition = _find_definition(str(group.get("provider_id", "")), str(group.get("ace_id", "")))
		var display: String = definition.display_name if definition != null else str(group.get("ace_id", ""))
		_batch_edit_menu.add_item("%s (%d %s)" % [display, (group.get("targets", []) as Array).size(), str(group.get("kind", "action")) + "s"], group_index)
	_batch_edit_menu.id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < groups.size():
			_open_batch_param_group(groups[id]))
	add_child(_batch_edit_menu)
	_batch_edit_menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i.ONE))


func _open_batch_param_group(group: Dictionary) -> void:
	var definition: ACEDefinition = _find_definition(str(group.get("provider_id", "")), str(group.get("ace_id", "")))
	if definition == null:
		_set_status("Couldn't load this ACE's definition (is its pack still installed?).", true)
		return
	if definition.parameters.is_empty():
		_set_status("%s has no parameters to edit." % definition.display_name, true)
		return
	var group_targets: Array = group.get("targets", [])
	var first_params: Dictionary = {}
	if not group_targets.is_empty():
		var first_target: Dictionary = group_targets[0]
		var first_event: EventRow = first_target.get("event", null) as EventRow
		var first_index: int = int(first_target.get("index", -1))
		var lane: Array = first_event.conditions if str(group.get("kind", "")) == "condition" else first_event.actions
		if first_event != null and first_index >= 0 and first_index < lane.size():
			first_params = (lane[first_index].get("params") as Dictionary).duplicate(true)
	_ace_params.open_with_values(definition, {
		"mode": "batch_edit_params",
		"batch_kind": str(group.get("kind", "action")),
		"batch_targets": group_targets,
		"batch_count": group_targets.size()
	}, first_params)


## Applies the live filter lens on the active viewport ("" clears) and reports the hidden
## count in the status line, so the collapsed view never reads as missing data.
func _apply_lens(query: String) -> void:
	if _viewport == null:
		return
	_viewport.set_lens(query)
	if _viewport.lens_active():
		_set_status("Filter: showing only events matching \"%s\" - %d hidden. Esc clears." % [_viewport.lens_query(), _viewport.lens_hidden_count()])
	else:
		if _lens_button != null:
			_lens_button.set_pressed_no_signal(false)
		_set_status("Filter cleared - all events visible.")
var _find_edit: LineEdit = null
var _find_count_label: Label = null
var _replace_edit: LineEdit = null
var _find_resource_matches: Array[Resource] = []
var _find_cursor: int = -1

# ── Live Values panel - extracted to dock/live_values_panel.gd ───────────────────────
var _live_values_panel: EventSheetLiveValuesPanel = null


func _ensure_live_values_panel() -> EventSheetLiveValuesPanel:
	if _live_values_panel == null:
		_live_values_panel = EventSheetLiveValuesPanel.new(self)
	return _live_values_panel

# Forwarding properties: tests (and the plugin) reach these through the dock.
var _live_values_tree: Tree:
	get: return _ensure_live_values_panel().tree
var _live_values_label: RichTextLabel:
	get: return _ensure_live_values_panel().label
var _live_values_window: Window:
	get: return _ensure_live_values_panel().window


func set_live_values_debugger(debugger: EventSheetLiveValuesDebugger) -> void:
	_ensure_live_values_panel().debugger = debugger
	# Self live grounding: the Expressions dictionary queries the RUNNING game for the sheet's
	# real behaviour children through the same session, and upgrades its Behaviours subgroup
	# when the report lands.
	if debugger != null:
		_ace_params._expression_picker.live_query = debugger.send_query_children
		debugger.children_report_received.connect(_ace_params._expression_picker._on_live_children_report)
		debugger.session_ended.connect(_on_debug_session_ended)


## The debug session ended: the last streamed frame stops counting as live values. Without this the
## Why didn't this fire? panel would keep answering from a stopped game's final frame - the case a
## reader is most likely to hit, since you stop the game and THEN ask why.
func _on_debug_session_ended() -> void:
	_ensure_live_values_panel().clear_live_values()
	if _debugger_window != null:
		_debugger_window.clear_live_values()


# ── The Debugger window (Inspect · Watch · Profile · Breakpoints) ───────────────────────
## One window over four seams that already shipped. Built the first time it is asked for and kept
## afterwards, like every other detached window here.
var _debugger_window: EventSheetDebuggerWindow = null


func _ensure_debugger_window() -> EventSheetDebuggerWindow:
	if _debugger_window == null:
		_debugger_window = EventSheetDebuggerWindow.new(self)
	return _debugger_window


## View ▸ Debugger, and the sheet's Debug-layout gesture. `tab` names which tab to land on, so
## arming the debugger and running can open straight onto Profile while the menu opens it where the
## reader left it.
func open_debugger(tab: String = "") -> void:
	_ensure_debugger_window().open(tab)


## Event-trace timings sink (wired by the plugin): the stamps beside the fires reported a moment
## ago. Kept beside the hit counts, which are the other half of the same tally - the fired-events
## message always arrives first, so the uids of THIS window are the ones just counted.
func update_event_times(window: Dictionary) -> void:
	EventSheetTraceTimings.note_window(_last_fired_uids, window.get("stamps", PackedInt64Array()),
		window.get("markers", PackedInt32Array()), int(window.get("flush", 0)))
	if _debugger_window != null:
		_debugger_window.refresh()


## The uids of the last streamed trace window, held for exactly as long as it takes the timings
## message that belongs to them to arrive (the same flush sends both, fires first).
var _last_fired_uids: PackedStringArray = PackedStringArray()


func _toggle_live_values() -> void:
	_ensure_live_values_panel().toggle()


func _ensure_live_values_window() -> void:
	_ensure_live_values_panel().ensure_window()


func update_live_values(values: Dictionary) -> void:
	_ensure_live_values_panel().update_values(values)
	if _debugger_window != null:
		_debugger_window.update_values(values)


## Paused-at-row sink (wired by the plugin): the running game announced it is pausing at a sheet
## breakpoint - find that event across the open tabs (by its stable event_uid), switch to its tab
## if needed, and reveal the row, so the pause lands on the EVENT rather than on generated code.
func reveal_paused_row(uid: String) -> void:
	if uid.is_empty():
		return
	for tab_index: int in range(_open_tabs.size()):
		var tab_sheet: EventSheetResource = _open_tabs[tab_index].get("sheet")
		var paused_event: EventRow = _find_event_by_uid(tab_sheet.events if tab_sheet != null else [], uid)
		if paused_event == null:
			continue
		if tab_index != _active_tab_index:
			_activate_tab(tab_index)
		var view: EventSheetViewport = _active_view()
		if view != null:
			view.reveal_resource(paused_event)
		_paused_row_uid = uid
		_set_status("⏸ Paused at this row (sheet breakpoint).")
		return


## ── The runtime-error strip (a failure in the running game, re-said as the row said it) ────────
##
## The engine reports a crash in the vocabulary of the file it crashed in. The sheet knows the
## other half: the source map says which row that generated line came from, and the row's own
## reading says what it was trying to do. So the failure is said once more as the row said it -
## "player.gd · event 12 · Enemy ▸ Call Hit: target is empty (nothing was picked before this
## action)" - in the Output panel and on the strip under the sheet, with Jump to event, Explain,
## and Godot's own words one button away. Nothing is hidden and nothing is invented: a message the
## table does not recognise is repeated verbatim and gets no Explain.
var _runtime_error_strip: HBoxContainer = null
var _runtime_error_label: Label = null
var _runtime_error_jump_button: Button = null
var _runtime_error_explain_button: Button = null
## The last report, as EventSheetRuntimeErrorWords.report() built it, plus the row it resolved to.
var _runtime_error_report: Dictionary = {}
## The event the running game announced it is paused at, kept rather than only revealed: the
## debugger's Breakpoints tab shows WHERE the pause is, and a reveal that was already scrolled past
## answers nothing.
var _paused_row_uid: String = ""


## One runtime error from the running game (or pasted by the reader) -> the sheet's words. Returns
## the report so a caller - and the suite - can read what was said without looking at a Control.
func report_runtime_error(message: String, script_path: String, line: int = 0) -> Dictionary:
	var located: Dictionary = _locate_runtime_error_row(script_path, line)
	var report: Dictionary = EventSheetRuntimeErrorWords.report(message, script_path,
		int(located.get("event_number", 0)), str(located.get("reading", "")))
	report["row_resource"] = located.get("resource")
	report["line"] = line
	_runtime_error_report = report
	for output_line: String in EventSheetRuntimeErrorWords.output_lines(report):
		print(output_line)
	_set_status(str(report.get("sentence", "")), true)
	if _runtime_error_strip != null and _runtime_error_label != null:
		_runtime_error_label.text = str(report.get("sentence", ""))
		_runtime_error_label.tooltip_text = str(report.get("original", ""))
		_runtime_error_strip.visible = true
	if _runtime_error_jump_button != null:
		_runtime_error_jump_button.disabled = report.get("row_resource") == null
	if _runtime_error_explain_button != null:
		_runtime_error_explain_button.disabled = not EventSheetRuntimeErrorWords.can_explain(report)
	return report


## The row a generated line belongs to, as {resource, event_number, reading}. Empty parts rather
## than a refusal: a failure in a file this tab is not showing still gets its sentence, it just has
## less of an address in front of it.
func _locate_runtime_error_row(script_path: String, line: int) -> Dictionary:
	var located: Dictionary = {"resource": null, "event_number": 0, "reading": ""}
	var view: EventSheetViewport = _active_view()
	if view == null or line <= 0:
		return located
	var wanted: String = script_path.strip_edges()
	if not wanted.is_empty() and not _current_sheet_path.is_empty() \
			and wanted.get_file() != _current_sheet_path.get_file():
		return located
	for entry: Variant in EventSheetLineRowMapper.entries_for_line(_code_source_map, line):
		var resource: Resource = instance_from_id(
			int(str((entry as Dictionary).get("uid", "0")))) as Resource
		if resource == null:
			continue
		for flat: Variant in view.get_flat_rows():
			var row_data: EventRowData = (flat as Dictionary).get("row")
			if row_data == null or row_data.source_resource != resource:
				continue
			located["resource"] = resource
			located["event_number"] = row_data.event_number
			located["reading"] = row_reading(row_data)
			return located
	return located


## One row read back as the phrase the error sentence puts in front of the failure. The collapsed
## block's summary is nearly this, but not quite: it keeps the "+ Add condition" / "+ Add action"
## affordances, which are click targets rather than anything the row says, and an error message
## reading "event 3 - + Add condition -> Subtract 1 from hp - + Add action: target is empty" says
## the row's furniture back to the reader instead of the row.
##
## Static and pure over the row so the suite pins the words without a viewport.
static func row_reading(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	var conditions: PackedStringArray = PackedStringArray()
	var actions: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		var text: String = span.text.strip_edges()
		if text.is_empty() or not (span.metadata is Dictionary):
			continue
		var metadata: Dictionary = span.metadata as Dictionary
		var kind: String = str(metadata.get("kind", ""))
		if kind == "add_condition" or kind == "add_action":
			continue
		match str(metadata.get("lane", "")):
			"condition":
				conditions.append(text)
			"action":
				actions.append(text)
	if not conditions.is_empty() and not actions.is_empty():
		return "%s ▸ %s" % [" - ".join(conditions), " - ".join(actions)]
	if not conditions.is_empty():
		return " - ".join(conditions)
	return " - ".join(actions)


## Jump to event: the deep-link that already existed, aimed at the row the failure came from.
func _jump_to_runtime_error_row() -> void:
	var resource: Variant = _runtime_error_report.get("row_resource")
	var view: EventSheetViewport = _active_view()
	if resource == null or view == null:
		goto_generated_line(int(_runtime_error_report.get("line", 0)))
		return
	if not view.select_resource(resource as Resource):
		view.reveal_resource(resource as Resource)


## Explain: the Manual page that answers the question this failure raises - picking and existence
## for an empty target, lists for a position that is not there, objects for a name nothing has.
func _explain_runtime_error() -> void:
	var page: String = str(_runtime_error_report.get("explain", "")).strip_edges()
	if page.is_empty():
		return
	EventSheets.open_docs(page)


## Godot's words: the original message, never hidden and never rewritten - it is what every search
## and every issue tracker speaks.
func _show_runtime_error_original() -> void:
	var original: String = str(_runtime_error_report.get("original", "")).strip_edges()
	if original.is_empty():
		return
	_set_status("%s: %s" % [EventSheetRuntimeErrorWords.GODOT_WORDS_LABEL, original], true)


## The strip goes away when the reader dismisses it, and whenever a new run starts - a failure from
## the last run stamped over this one would be answering a question nobody asked twice.
func clear_runtime_error() -> void:
	_runtime_error_report = {}
	if _runtime_error_strip != null:
		_runtime_error_strip.visible = false


static func _find_event_by_uid(rows: Array, uid: String) -> EventRow:
	for row: Variant in rows:
		if row is EventRow:
			if (row as EventRow).event_uid == uid:
				return row as EventRow
			var in_sub: EventRow = _find_event_by_uid((row as EventRow).sub_events, uid)
			if in_sub != null:
				return in_sub
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			var found: EventRow = _find_event_by_uid(group.events if not group.events.is_empty() else group.rows, uid)
			if found != null:
				return found
	return null


## Live event-trace sink (wired by the plugin): highlight the firing rows in every pane.
func update_fired_events(uids: PackedStringArray) -> void:
	# The streamed window is a TALLY (one entry per fire, repeats included), so it is counted
	# before it is deduped into the highlight. Counting always; DRAWING only when the reader
	# ticks View > Row Hit Counts, or hovers one event number.
	EventSheetTraceHitCounts.note_fired(uids)
	# Held for the timings message of the same flush, which arrives right after this one and needs
	# to know WHICH fires its stamps belong to.
	_last_fired_uids = uids
	for pane: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if pane != null:
			pane.set_fired_events(uids)


## Tools ▸ Event Trace - highlights the rows whose events fire during a debug run (rung 3). It
## rides the Live Values stream, so it turns that on too. Recompile + run to start.
func _toggle_event_trace() -> void:
	if _current_sheet == null:
		return
	_current_sheet.emit_event_trace = not _current_sheet.emit_event_trace
	if _current_sheet.emit_event_trace:
		_current_sheet.emit_live_values = true
		_set_status("Event Trace ON: recompile and run - firing events highlight live (needs variables to stream).")
	else:
		for pane: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
			if pane != null:
				pane.set_fired_events(PackedStringArray())
		_set_status("Event Trace OFF (recompile to remove the instrumentation).")


# ── Row hit counts + Why didn't this fire? (the trace read as numbers, and one row explained) ──
## The View menu id the Row Hit Counts check item is registered under (menu_bar.gd), kept here
## so the toggle and the tick can never drift onto two different items.
const HIT_COUNTS_VIEW_ID := 9601

## The View-menu ids the Project bar (T13) and the beginner Add toolbar (T18) are registered under,
## kept beside the one above for the same reason: the toggle and the tick must never drift apart.
const PROJECT_BAR_VIEW_ID := 9603
const ADD_TOOLBAR_VIEW_ID := 9604


# ── T13 / T14 / T15 / T18: the project-level surfaces ─────────────────────────────────────────
## View ▸ Project bar. The bar is a TAB of the Object bar, not a dock of its own.
func _toggle_project_bar() -> void:
	_project_bar_glue.set_shown(_project_bar_glue.bar() == null)


## View ▸ Add toolbar - the eight Add gestures as buttons above the canvas.
func _toggle_add_toolbar() -> void:
	var strip: Control = _beginner_toolbar_strip()
	_beginner_toolbar.set_shown(strip == null or not strip.visible)


func _beginner_toolbar_strip() -> Control:
	return find_child("EventSheetBeginnerToolbar", true, false) as Control


## Collapse or expand the selected block - the same fold Left / Right do, on one rebindable key so
## the "Another event-sheet editor" preset can put it where that editor's authors expect it.
func _toggle_selected_collapse() -> void:
	var view: EventSheetViewport = _active_view()
	if view != null:
		view._toggle_row_fold(view._selected_row_index)


## Sheet ▸ Start page. Loaded by path so the editor's boot never carries the help corpus.
func _open_start_page() -> void:
	if _start_page == null:
		_start_page = load("res://addons/eventsheet/editor/dock/start_page.gd").new()
		_start_page.init(self)
	_start_page.open()


## View > Row Hit Counts: the gutter chip that says how many times each event fired since Run.
## SHIPS UNTICKED, and that is the design - with it off the sheet is the program and nothing else.
func _toggle_row_hit_counts(view_popup: PopupMenu) -> void:
	# ONE target state for every pane, decided from the main viewport. Flipping each pane's own flag
	# would desynchronise them the moment a split pane is opened while the lens is on (a fresh pane
	# ships OFF), and the tick would then report whichever pane happened to be iterated last.
	var showing: bool = not (_viewport != null and _viewport.show_hit_counts)
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view == null:
			continue
		view.show_hit_counts = showing
		view.queue_redraw()
	if view_popup != null:
		view_popup.set_item_checked(view_popup.get_item_index(HIT_COUNTS_VIEW_ID), showing)
	if not showing:
		_set_status("Row Hit Counts off - the gutter is back to event numbers only.")
	elif EventSheetTraceHitCounts.has_run():
		_set_status("Row Hit Counts on: x-counts in the gutter, warm for the busiest rows, x0 for never fired since Run.")
	else:
		_set_status("Row Hit Counts on - no traced run yet. Tools > Event Trace (live highlight), then run the game.")


## Tools > Reset Hit Counts: start the tally over without restarting the game (the "now do it
## again and watch" gesture - reset, trigger the thing, see exactly which rows moved).
func _reset_row_hit_counts() -> void:
	EventSheetTraceHitCounts.reset()
	# The timings are the other half of the same tally: a profile kept from before the reset would
	# be answering about the run the reader just said they were done with.
	EventSheetTraceTimings.reset()
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view != null:
			view.queue_redraw()
	if _debugger_window != null:
		_debugger_window.refresh()
	_set_status("Hit counts reset - counting starts again from the next streamed window.")


## Row menu > Why didn't this fire?: one row, each condition's verdict against the values the
## Live Values stream is already carrying. Opens a panel and leaves NOTHING on the sheet.
func _open_why_didnt_this_fire() -> void:
	var row: EventRow = _context_row.source_resource as EventRow if _context_row != null else null
	if row == null:
		_set_status("Pick an event row first.", true)
		return
	var panel: GDScript = load("res://addons/eventsheet/editor/docs/doc_why_panel.gd")
	if panel == null:
		return
	panel.open_for_row(self, row, _ensure_live_values_panel()._last_values)


## S24 - Row menu > Explain this reading: opens the pattern's Manual page, where the hand-written
## shape and the events it reads as sit side by side. A pattern reading is a claim spanning several
## lines, and this is the reader's way to go and check it.
func explain_pattern_reading() -> void:
	var claim: Dictionary = _context_pattern_claim()
	if claim.is_empty():
		_set_status("Pick an event with a pattern marker first.", true)
		return
	EventSheetPatternManual.open_page(str(claim.get("pattern", "")))


## S20 - Row menu > Adopt behavior: the preview-first swap of a hand-written pattern for the shipped
## one. Nothing changes until the reader has read what would.
func adopt_pattern_behavior() -> void:
	var claim: Dictionary = _context_pattern_claim(true)
	if claim.is_empty():
		_set_status("Pick an event with a behavior to adopt first.", true)
		return
	_pattern_adopt_dialog.open(claim)


## The claim behind the row that was right-clicked, or {} when there is none. `adoptable_only`
## narrows it to a claim this build can actually rewrite, which is what the Adopt item was offered
## for in the first place.
func _context_pattern_claim(adoptable_only: bool = false) -> Dictionary:
	var row: EventRow = _context_row.source_resource as EventRow if _context_row != null else null
	if row == null or _current_sheet == null:
		return {}
	for entry: Variant in EventSheetPatternFacts.claims_for_row(_current_sheet, row.event_uid):
		if adoptable_only and not EventSheetPatternAdopt.is_adoptable(entry as Dictionary):
			continue
		return entry as Dictionary
	return {}


# ── Single-param inline editing (double-click value / colour swatch / node drop) → dock/inline_param_editor.gd ──
func _on_param_value_edit_requested(ace: Resource, param_id: String, current_text: String) -> void:  # viewport param_value_edit_requested
	_inline_params.on_param_value_edit_requested(ace, param_id, current_text)


func _on_color_swatch_edit_requested(ace: Resource, param_id: String, current_color: Color) -> void:  # viewport color_swatch_edit_requested
	_inline_params.on_color_swatch_edit_requested(ace, param_id, current_color)


func _on_param_node_drop_requested(ace: Resource, param_id: String, node_reference: String) -> void:  # viewport param_node_drop_requested
	_inline_params.on_param_node_drop_requested(ace, param_id, node_reference)


## Toggles debug compiles: gutter breakpoints (F9) emit real `breakpoint` statements.
func _toggle_breakpoint_emission() -> void:
	if _current_sheet == null:
		return
	_current_sheet.emit_breakpoints = not _current_sheet.emit_breakpoints
	_set_status("Debug compile ON: breakpointed events emit `breakpoint` (recompile to apply)." if _current_sheet.emit_breakpoints else "Debug compile OFF: breakpoints render only.")


# ── Find & Replace bar → dock/find_bar.gd ───────────────────────────────────────────
# The Ctrl+F find bar + Replace-All-across-the-sheet cluster lives in EventSheetFindBar. The
# find-bar WIDGET members (_find_bar/_find_edit/_find_count_label/_replace_edit) and the match
# cursor state (_find_resource_matches/_find_cursor) stay declared on the dock; the helper's
# _ensure_find_bar() constructs the widgets and assigns them back. Thin delegates keep the
# original names/signatures so the in-file .connect(_show_find_bar) site, multi_view_manager
# (_dock._show_find_bar / _dock._find_step), project_find (_dock._ensure_find_bar /
# _dock._replace_in_rows / _dock._replace_all_in_sheet) and the tests resolve unchanged.
func _show_find_bar() -> void:  # _viewport.find_requested + multi_view_manager
	_find_bar_glue._show_find_bar()


func _ensure_find_bar() -> void:  # project_find + tests
	_find_bar_glue._ensure_find_bar()


func _on_find_text_changed(text: String) -> void:  # _find_edit.text_changed + godot_feel_test
	_find_bar_glue._on_find_text_changed(text)


func _find_step(direction: int) -> void:  # multi_view find_step_requested + tests
	# While the Find results bar is open, F3 / Shift+F3 walk THOSE results - it is the list the
	# user is looking at. Closed, they step the find bar's matches as before.
	if _find_results.is_open():
		_find_results.step(direction)
		return
	_find_bar_glue._find_step(direction)


## Right-click ▸ Find all references: every place the clicked variable / function / object /
## signal / behavior is used, in the Find results bar under the sheet.
func open_find_all_references() -> void:
	_find_results.open(_find_reference_symbol())


## The symbol the right-click was about: the clicked variable or object name first (a span knows
## exactly what it is), then the row's own identity, then its leading words.
func _find_reference_symbol() -> String:
	var metadata: Dictionary = _context_hit.get("span_metadata", {}) if _context_hit is Dictionary else {}
	var variable_name: String = str(metadata.get("variable_name", "")).strip_edges()
	if not variable_name.is_empty():
		return variable_name
	if not _variables._context_variable.is_empty():
		return str(_variables._context_variable.get("name", "")).strip_edges()
	var object_label: String = str(metadata.get("object_label", "")).strip_edges()
	if not object_label.is_empty():
		return object_label
	var target: Resource = _context_row.source_resource if _context_row != null else null
	if target is LocalVariable:
		return (target as LocalVariable).name
	if target is SignalRow:
		return (target as SignalRow).signal_name
	if target is EventFunction:
		return (target as EventFunction).function_name
	if target is EventGroup:
		return (target as EventGroup).group_name
	if _context_row != null and not _context_row.spans.is_empty():
		return str(_context_row.spans[0].text).get_slice(":", 0).strip_edges()
	return ""


func _replace_all_in_sheet() -> void:  # Replace All button + project_find + tests
	_find_bar_glue._replace_all_in_sheet()


func _replace_in_rows(rows: Array, find_text: String, replace_text: String, counter: Dictionary) -> void:  # project_find + with_node_editor_test
	_find_bar_glue._replace_in_rows(rows, find_text, replace_text, counter)

# ── Group color tags ──────────────────────────────────────────────────────────────────
var _group_color_popup: PopupPanel = null
var _group_color_picker: ColorPickerButton = null
var _group_color_target: Resource = null


## G2 - a mark on a group head was clicked. The switch turns the group on and off; the ring before
## it makes the group switchable at runtime, which is what Set group active needs to reach it.
func _on_group_action_requested(action: String, group: EventGroup) -> void:  # _viewport.group_action_requested
	if group == null:
		return
	match action:
		"enabled":
			_context_row = _active_view().get_selected_context().get("row_data", _context_row) if _active_view() != null else _context_row
			_toggle_group_enabled()
		"toggleable":
			_set_group_runtime_toggleable(group, not group.runtime_toggleable)


## The group the row menu is acting on, or null when the clicked row is not a group head.
func _context_group() -> EventGroup:
	return (_context_row.source_resource as EventGroup) if _context_row != null else null


## G4 - Edit group…: everything a group is, in the one dialog.
func _open_group_editor_for_context() -> void:
	var group: EventGroup = _context_group()
	if group == null:
		_set_status("Select a group to edit it.", true)
		return
	_on_group_edit_requested(group)


## G4 - Active on start, straight off the head's own switch. Off compiles the group out.
func _toggle_group_enabled() -> void:
	var group: EventGroup = _context_group()
	if group == null:
		_set_status("Select a group to switch it on or off.", true)
		return
	var switched_on: bool = not group.enabled
	var changed: bool = _perform_undoable_sheet_edit("Active On Start", func() -> bool:
		group.enabled = switched_on
		return true
	)
	if changed:
		_refresh_after_edit()
		_mark_dirty("Group \"%s\" is %s." % [group.group_name, "active on start" if switched_on else "off - it and its rows compile out"])


## G4 - Open all / Close all groups: one gesture for the whole sheet, folding when anything is open
## and opening when everything is shut, so the key is a toggle rather than two commands.
func _toggle_all_group_folds() -> void:
	var view: EventSheetViewport = _active_view()
	if view == null:
		return
	# Read BEFORE folding: the call rewrites the fold state, so asking again afterwards answers
	# about the sheet this gesture just made, not the one it was asked about.
	var opening: bool = not view.any_group_open()
	view.set_group_folds(not opening)
	_set_status("Groups opened." if opening else "Groups closed.")


## G3 - V (or Add local variable…) with a group head selected: a Local of THIS group, which the
## compiler emits as a class member under the group's own header.
func _add_group_local_variable() -> void:
	var group: EventGroup = _context_group()
	if group == null:
		_set_status("Select a group to add a local variable to it.", true)
		return
	_add_group_local_variable_for(group)


## Opens the Add variable dialog scoped to one group: the answers land in that group's
## `local_variables`, which the compiler emits as class members under the group's own header.
func _add_group_local_variable_for(group: EventGroup) -> void:
	if group == null or not _ensure_sheet_for_editing():
		return
	_variable_dlg.open_for_edit("local", {"group": group}, "", "int", "0", false, "Add Variable")


## G4 - Ungroup: the rows the group held move up into its place, in order, and the group itself
## goes. One undo step, and nothing inside it changes.
func _ungroup_context_group() -> void:
	var group: EventGroup = _context_group()
	if group == null:
		_set_status("Select a group to ungroup it.", true)
		return
	var moved: int = EventSheetGroupFacts.children(group).size()
	var location: Dictionary = _find_resource_location(group)
	if location.is_empty():
		_set_status("Couldn't locate that group.", true)
		return
	var changed: bool = _perform_undoable_sheet_edit("Ungroup", func() -> bool:
		var container: Array = location.get("container")
		var at: int = container.find(group)
		if at < 0:
			return false
		container.remove_at(at)
		for entry: Variant in EventSheetGroupFacts.children(group):
			container.insert(at, entry)
			at += 1
		return true
	)
	if changed:
		_mark_dirty("Ungrouped \"%s\" - %d row(s) kept." % [group.group_name, moved])


## G2 - the "Make switchable" offer in the Set/Is Group Active dialog: the row names a group of this
## sheet that cannot be switched yet, and one click makes it one. Takes the value the field holds
## (the quoted snake_case the template concatenates) and answers whether anything changed.
func _make_group_switchable(value: String) -> bool:
	var group: EventGroup = EventSheetGroupFacts.group_for_value(_current_sheet, value)
	if group == null or group.runtime_toggleable:
		return false
	return _set_group_runtime_toggleable(group, true)


## The one writer for a group's runtime toggle: one undo step, one status line saying what the two
## group rows can now reach.
func _set_group_runtime_toggleable(group: EventGroup, switchable: bool) -> bool:
	if group == null:
		return false
	var changed: bool = _perform_undoable_sheet_edit("Runtime Toggleable", func() -> bool:
		group.runtime_toggleable = switchable
		return true
	)
	if changed:
		_refresh_after_edit()
		_mark_dirty("Group \"%s\" is %s - Set Group Active targets %s." % [
			group.group_name,
			"switchable at runtime" if switchable else "compile-time only again",
			EventSheetGroupFacts.guard_value(group)
		])
	return changed


## Event-sheet-style group colors: tint the selected group's accent/background (clear = theme).
## R2 - a region's colour comes through the same picker: it is the same gesture on the same kind of
## row, and the only difference is that a fence stores its colour as the `#rrggbb` its marker line
## carries rather than as a Color.
func _open_group_color_picker() -> void:
	var target: Resource = _context_row.source_resource if _context_row != null else null
	if not (target is EventGroup) and not EventSheetRegionFacts.is_opening_fence(target):
		_set_status("Right-click a group or a region to color it.", true)
		return
	if _group_color_popup == null:
		_group_color_popup = PopupPanel.new()
		var color_box: HBoxContainer = HBoxContainer.new()
		_group_color_picker = ColorPickerButton.new()
		_group_color_picker.custom_minimum_size = Vector2(120.0, 0.0)
		_group_color_picker.color_changed.connect(func(value: Color) -> void: _apply_group_color(value))
		color_box.add_child(_group_color_picker)
		var clear_button: Button = Button.new()
		clear_button.text = "Theme default"
		clear_button.pressed.connect(func() -> void:
			_apply_group_color(Color(0.0, 0.0, 0.0, 0.0))
			_group_color_popup.hide()
		)
		color_box.add_child(clear_button)
		_group_color_popup.add_child(color_box)
		add_child(_group_color_popup)
	_group_color_target = target
	_group_color_picker.color = _structure_color_of(target)
	_group_color_popup.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), Vector2i(220, 42)))


## What the picker opens on: the group's or fence's own colour, or the default tint when it carries
## none (clearing writes a fully transparent colour, which both structures read as "use the theme").
func _structure_color_of(target: Resource) -> Color:
	if target is EventGroup and (target as EventGroup).custom_color.a > 0.0:
		return (target as EventGroup).custom_color
	var stored: String = EventSheetRegionFacts.accent_hex(target)
	if not stored.is_empty():
		return Color.html(stored)
	return DEFAULT_STRUCTURE_COLOR


func _apply_group_color(value: Color) -> void:
	if _group_color_target == null:
		return
	var target: Resource = _group_color_target
	var changed: bool = _perform_undoable_sheet_edit("Group Color", func() -> bool:
		if target is EventGroup:
			if (target as EventGroup).custom_color == value:
				return false
			(target as EventGroup).custom_color = value
			return true
		var fence: CustomBlockRow = target as CustomBlockRow
		var written: String = "" if value.a <= 0.0 else "#%s" % value.to_html(false)
		if str(fence.fields.get("color", "")) == written:
			return false
		fence.fields["color"] = written
		return true
	)
	if changed:
		_refresh_after_edit()
		_mark_dirty("Color updated.")

# ── R2/R3: the region verbs ────────────────────────────────────────────────────────────────────


## The opening fence the row menu is acting on, or null when the clicked row is not one.
func _context_region() -> CustomBlockRow:
	if _context_row == null:
		return null
	var fence: CustomBlockRow = _context_row.source_resource as CustomBlockRow
	return fence if EventSheetRegionFacts.is_opening_fence(fence) else null


## R2 - Rename Region: the fence's own name, edited in place on the row (the same edit F2 reaches
## once the title is selected). Only the label changes; the file gains no line and loses none.
func _begin_region_rename() -> void:
	var opener: CustomBlockRow = _context_region()
	if opener == null:
		_set_status("Right-click a region's opening fence to rename it.", true)
		return
	var view: EventSheetViewport = _active_view()
	if view == null:
		return
	view.select_resource(opener)
	if not view.begin_edit_selected():
		_set_status("Couldn't start renaming that region.", true)


## R2 - Turn Into Group: the fenced rows become an EventGroup and the two fence lines go. One undo
## step, and nothing inside moves.
func _turn_region_into_group() -> void:
	var opener: CustomBlockRow = _context_region()
	if opener == null:
		_set_status("Right-click a region's opening fence to turn it into a group.", true)
		return
	var location: Dictionary = _find_resource_location(opener)
	if location.is_empty():
		_set_status("Couldn't locate that region.", true)
		return
	var made: Array[EventGroup] = []
	var changed: bool = _perform_undoable_sheet_edit("Turn Into Group", func() -> bool:
		var group: EventGroup = EventSheetRefactor.region_to_group(location.get("container"), opener)
		if group == null:
			return false
		made.append(group)
		return true
	)
	if not changed:
		_set_status("That region has no closing #endregion, so there is nothing to wrap.", true)
		return
	_mark_dirty("\"%s\" is a group now - the rows are unchanged." % made[0].display_name())


## R2 - Turn Into Region: the group's header goes and its rows sit between two fences instead. The
## menu item already said why it could not happen, so the refusal here is only a backstop.
func _turn_group_into_region() -> void:
	var group: EventGroup = _context_group()
	if group == null:
		_set_status("Select a group to turn it into a region.", true)
		return
	var problem: String = EventSheetRefactor.group_to_region_problem(group)
	if not problem.is_empty():
		_set_status("\"%s\" %s, and a region cannot carry that." % [group.display_name(), problem], true)
		return
	var location: Dictionary = _find_resource_location(group)
	if location.is_empty():
		_set_status("Couldn't locate that group.", true)
		return
	var name_before: String = group.display_name()
	var changed: bool = _perform_undoable_sheet_edit("Turn Into Region", func() -> bool:
		return EventSheetRefactor.group_to_region(location.get("container"), group)
	)
	if changed:
		_mark_dirty("\"%s\" is a #region now - the rows are unchanged." % name_before)


## R2 - Remove Region: both fences go, everything they held stays exactly where it was.
func _remove_context_region() -> void:
	var opener: CustomBlockRow = _context_region()
	if opener == null:
		_set_status("Right-click a region's opening fence to remove it.", true)
		return
	var location: Dictionary = _find_resource_location(opener)
	if location.is_empty():
		_set_status("Couldn't locate that region.", true)
		return
	var kept: Array[int] = []
	var changed: bool = _perform_undoable_sheet_edit("Remove Region", func() -> bool:
		var moved: int = EventSheetRefactor.remove_region_keep_rows(location.get("container"), opener)
		if moved < 0:
			return false
		kept.append(moved)
		return true
	)
	if not changed:
		_set_status("That region has no closing #endregion, so there is no pair to remove.", true)
		return
	_mark_dirty("Region removed - %d row(s) kept." % kept[0])


## R2 - Fold all / Unfold all regions: one gesture for the whole sheet, folding when anything is
## open and opening when everything is shut, so the item is a toggle rather than two commands.
func _toggle_all_region_folds() -> void:
	var view: EventSheetViewport = _active_view()
	if view == null:
		return
	var opening: bool = not view.any_region_open()
	view.set_region_folds(not opening)
	_set_status("Regions opened." if opening else "Regions closed.")


## R3 - the fix on an unmatched opener's amber note: writes the missing `#endregion` after the last
## row before the next head. The note stands for no resource of its own, so the fence it is about is
## resolved from the row's uid - the same uid the note was built with.
func _close_orphan_region(note_row: EventRowData) -> void:
	if note_row == null or _current_sheet == null:
		return
	var opener: CustomBlockRow = _orphan_region_for(note_row.row_uid)
	if opener == null:
		_set_status("That fence is closed already.", true)
		return
	var location: Dictionary = _find_resource_location(opener)
	if location.is_empty():
		_set_status("Couldn't locate that region.", true)
		return
	var changed: bool = _perform_undoable_sheet_edit("Close Region", func() -> bool:
		var container: Array = location.get("container")
		var at: int = EventSheetRegionFacts.closer_insert_index(container, container.find(opener))
		if at < 0:
			return false
		var closer := CustomBlockRow.new()
		closer.kind_id = EventSheetRegionFacts.KIND_ID
		closer.fields = {"label": "", "is_end": true}
		container.insert(at, closer)
		return true
	)
	if changed:
		_mark_dirty("\"%s\" closes now." % EventSheetRegionFacts.display_name(opener))


## The unmatched opening fence one orphan note is about, found by the uid the note was built with.
func _orphan_region_for(note_uid: String) -> CustomBlockRow:
	var view: EventSheetViewport = _active_view()
	if view == null:
		return null
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null or not EventSheetRegionFacts.is_opening_fence(row_data.source_resource):
			continue
		if note_uid == "region_orphan_%s" % str(row_data.source_resource.get_instance_id()):
			return row_data.source_resource as CustomBlockRow
	return null


# ── Autoload (Singleton) sheets ───────────────────────────────────────────────────────


## One click: compile the autoload sheet and register the generated script in
## ProjectSettings. Guarded: needs the type, a name, a saved sheet, and a free slot.
func _register_autoload() -> void:
	if _current_sheet == null or not _current_sheet.autoload_mode:
		_set_status("Set the sheet type to Autoload (Singleton) first (Sheet Type…).", true)
		return
	var problem: String = _register_autoload_entry(_current_sheet, _current_sheet_path)
	if problem.is_empty():
		_set_status("Registered autoload \"%s\" - every sheet (and script) can call it now." % _current_sheet.autoload_name)
	else:
		_set_status(problem, true)


## The testable core: compiles next to the sheet and writes the autoload entry.
## Returns "" on success or the user-facing problem.
func _register_autoload_entry(sheet: EventSheetResource, sheet_path: String) -> String:
	var autoload_name: String = sheet.autoload_name.strip_edges()
	if autoload_name.is_empty() or not EventSheetIdentifierRules.is_valid(autoload_name):
		return "Autoload needs a valid name (Sheet Type… → Autoload name)."
	if sheet_path.is_empty():
		return "Save the sheet first - the autoload entry must point at a real file."
	var output_path: String = sheet_path.get_basename() + ".gd"
	var compile_result: Dictionary = SheetCompiler.compile(sheet, output_path)
	if not bool(compile_result.get("success", false)):
		return "Autoload not registered: the sheet doesn't compile (%s)." % str(compile_result.get("errors"))
	var setting_name: String = "autoload/%s" % autoload_name
	var target_value: String = "*%s" % output_path
	if ProjectSettings.has_setting(setting_name) and str(ProjectSettings.get_setting(setting_name)) != target_value:
		return "An autoload named \"%s\" already exists and points elsewhere - pick another name." % autoload_name
	ProjectSettings.set_setting(setting_name, target_value)
	if Engine.is_editor_hint():
		ProjectSettings.save()
	return ""

# ── Addon-author loop - extracted to dock/author_loop.gd ─────────────────────────────
var _author_loop: EventSheetAuthorLoop = null


func _ensure_author_loop() -> EventSheetAuthorLoop:
	if _author_loop == null:
		_author_loop = EventSheetAuthorLoop.new(self)
	return _author_loop


func _collect_publish_surface(sheet: EventSheetResource) -> Dictionary:
	return EventSheetAuthorLoop.collect_publish_surface(sheet)


static func publish_surface_text(surface: Dictionary) -> String:
	return EventSheetAuthorLoop.publish_surface_text(surface)


func _generate_pack_readme(sheet: EventSheetResource) -> String:
	return EventSheetAuthorLoop.generate_pack_readme(sheet)


func _open_publish_preview() -> void:
	_ensure_author_loop().open_publish_preview()


func _open_test_bench() -> void:
	_ensure_author_loop().open_test_bench()


func _build_test_bench(sheet: EventSheetResource, scene_path: String) -> String:
	return _ensure_author_loop().build_test_bench(sheet, scene_path)

# ── Project-wide find / replace / usages - extracted to dock/project_find.gd ─────────
# (Dock decomposition arc: state + logic live in the helper; these delegates keep the
# public/test surface stable.)
var _project_find: EventSheetProjectFind = null


func _open_project_find(initial_query: String = "") -> void:
	if _project_find == null:
		_project_find = EventSheetProjectFind.new(self)
	_project_find.open(initial_query)


# ── Project Doctor - health-audit window → dock/project_doctor_panel.gd ──
func _open_project_doctor() -> void:  # Tools menu (id 7)
	_doctor.open()


## Runs EventSheetDiagnostics over the current sheet, paints per-row error markers on the active
## view, and jumps to the first flagged row. Returns the flagged-row count. The "error → row"
## deep-link: a bad ƒx expression or GDScript block lands you ON the offending row, not a status
## line you then have to hunt down. Clears markers (and returns 0) when the sheet is clean.
func _run_diagnostics() -> int:
	if _current_sheet == null:
		return 0
	var view: EventSheetViewport = _active_view()
	if view == null:
		return 0
	var diagnostics: Array = EventSheetDiagnostics.analyze(_current_sheet, _ace_registry)
	var count: int = view.set_row_diagnostics(diagnostics)
	if count > 0:
		view.reveal_and_select_first_diagnostic()
	# Push the result to the banner's health chip - save-time / on-demand only, so the chip
	# reflects a real check, never an ambient recompile.
	if _identity_banner != null:
		_identity_banner.set_health(count)
	return count


## Tools ▸ Check Sheet for Errors - run diagnostics on demand and report.
func _run_diagnostics_action() -> void:
	if _current_sheet == null:
		_set_status("Open or create a sheet first.", true)
		return
	var count: int = _run_diagnostics()
	if count > 0:
		_set_status("%d row(s) need attention - jumped to the first (hover the red rows for details)." % count, true)
	else:
		_set_status("No issues found - every ƒx expression and script block compiles.")

## Fixed structural keys (not rebindable - they're grammar, not preference): shown read-only in the
## Keyboard Shortcuts editor as [keys, action], for reference. The rebindable authoring keys come
## live from EventSheetShortcuts so the editor always shows the user's actual bindings.
const FIXED_KEYS: Array = [
	["Enter / F2", "Edit the selected row"],
	["Tab / Shift+Tab", "Nest / un-nest the event"],
	["Alt + Up / Down", "Move the row up / down"],
	["Left / Right", "Collapse / expand a group"],
	["Up / Down", "Select previous / next row"],
	["Shift + Up / Down", "Extend the row selection"],
	["Delete", "Delete the selection"],
	["Ctrl + F", "Find & Replace"],
	["F3 / Shift+F3", "Find next / previous"],
	["Ctrl + P", "Command Palette"],
	["Ctrl + G", "Go to event"],
	["F9 / Ctrl+B", "Toggle breakpoint"],
	["Ctrl + M", "Toggle bookmark"],
	["Ctrl + +  /  Ctrl + -", "Zoom in / out (also Ctrl + mouse wheel)"],
	["Ctrl + 0", "Reset zoom to 100%"],
	["Esc", "Close a popup / cancel an edit"],
]


# ── Keyboard Shortcuts editor (Tools menu; FIXED_KEYS above stays here) → event_sheet_shortcuts_dialog.gd ──
func _open_shortcuts_help() -> void:
	_shortcuts.open()


## Tools ▸ Manual…, F1, and EventSheets.open_docs all land here. With no id, whatever the reader
## has SELECTED answers - a condition or action row with its entry, an object label with the
## object's reference page, a group with the Manual's page on groups, a behavior's Include bar
## with that behavior's reference - which is what makes F1 "help for this", not "open the manual".
## Returns false when the id names nothing, so the caller can say so.
func open_documentation(doc_id: String = "", anchor: String = "") -> bool:
	var target: String = doc_id
	if target.is_empty():
		target = _selected_row_doc_id()
	if _docs.open(target, anchor):
		return true
	if target.is_empty():
		return false
	# A verb the live registry no longer offers (a pack removed since the sheet was written):
	# say so and fall back to the index rather than leaving the reader on a stale page. The
	# ANSWER is still false - the reader gets a page, but the caller asked whether THAT id is
	# documented, and reporting the index as a hit is how a renamed guide ships unnoticed.
	_set_status("No documentation for that row - what it uses is not in this project's vocabulary.", true)
	_docs.open("")
	return false


## The last page the reader had open in the Manual, for Ctrl+F1 - "take me back to what I was
## reading" rather than "explain this row". "" when they have not opened it yet, which lands them on
## the index, and that is the right answer: there is nothing to go back to.
func last_read_doc_id() -> String:
	var history: Script = load("res://addons/eventsheet/editor/docs/doc_history.gd") as Script
	return "" if history == null else str(history.call("current"))


## The row menu's "What does this do?". The CLICKED SPAN decides: right-clicking the third
## condition explains that condition, not the row's trigger. The span metadata is the same
## context the row menu itself was built from, so the entry and the page can never disagree.
func explain_row(resource: Resource) -> void:
	open_documentation(EventSheetDocExplain.doc_id_for_row(resource, _context_hit.get("span_metadata", {})))


## The doc id of the first selected row that names a verb, or "" when the selection explains
## nothing (a comment, a blank group, or no selection at all).
func _selected_row_doc_id() -> String:
	if _viewport == null:
		return ""
	for row_data: EventRowData in _viewport.get_selected_rows():
		if row_data == null:
			continue
		# The whole selection is offered, not only its verb: an object label, a group band and a
		# behavior's Include bar each have their own page, and one router decides which.
		var doc_id: String = EventSheetDocHelpTarget.doc_id_for(_current_sheet,
			row_data.source_resource, _selection_span_metadata(row_data))
		if not doc_id.is_empty():
			return doc_id
	return ""


## The span metadata F1 answers from. A click has one (the exact condition, the object label that
## was pointed at); a KEY does not, so the row's own leading object label stands in - which is what
## a reader pressing F1 on a row about the player means by "this".
func _selection_span_metadata(row_data: EventRowData) -> Dictionary:
	if row_data == null:
		return {}
	for span: SemanticSpan in row_data.spans:
		# A span's metadata is a Variant and is routinely null, so it is asked what it IS before it
		# is asked anything else.
		if span == null or not (span.metadata is Dictionary):
			continue
		var metadata: Dictionary = span.metadata as Dictionary
		if not str(metadata.get("object_label", "")).strip_edges().is_empty():
			return metadata
		if str(metadata.get("kind", "")) == "pack_include":
			return metadata
	return {}


## The Manual, kept beside the sheet and following the reader. Called on every selection change:
## with Follow selection on, the docked Manual answers for whatever is now selected without a key
## being pressed. Silent when the Manual is not docked, not open, or not following - a reader who
## has not asked for this must never have a page change under them.
func _follow_selection_in_manual() -> void:
	var manual: EventSheetDocDock = EventSheetDocDock.active_dock()
	if manual == null or not manual.is_following():
		return
	var doc_id: String = _selected_row_doc_id()
	if doc_id.is_empty():
		return
	manual.follow_documentation(doc_id)


## The picker's "read more" affordance: the highlighted verb's pack guide. Routed through the
## public "addon:<pack>" doc id rather than straight at a URL, so this caller needs no edit the
## day that id starts resolving to something other than a browser tab. The picker emits and
## never navigates itself.
## The picker's per-entry "?". It opens the verb's entry in the Manual - docked and following when
## the reader keeps it there, a window otherwise - and the picker stays open behind it, because the
## reader was in the middle of choosing something.
func _on_picker_help_requested(definition: ACEDefinition) -> void:
	if definition == null:
		return
	open_documentation(EventSheetDocExplain.doc_id_for_definition(definition))


func _on_picker_guide_requested(definition: ACEDefinition) -> void:
	if definition == null:
		return
	var pack_dir: String = EventSheets.addon_pack_directory(definition.provider_id)
	if pack_dir.is_empty() or not EventSheets.open_docs("addon:%s" % pack_dir):
		return
	_set_status("Opened %s in your browser." % EventSheets.addon_guide_for_pack(pack_dir).get_file())


## The addon's issue tracker. A plain constant rather than a project setting: it is where THIS
## plugin's bugs go, and a fork that wants its own tracker is editing the plugin anyway.
const ISSUES_URL: String = "https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/issues/new"


## The report skeleton the tracker opens with. Static and pure so the exact text that travels is
## testable without opening a browser. A report that names the plugin build, the Godot build and the
## platform is one a maintainer can act on immediately; asking for them afterwards costs a round trip
## and usually loses the reporter. Exactly those three facts travel - deliberately no project name,
## no file paths, no user name, nothing out of the user's sheets.
static func issue_report_body() -> String:
	return "\n".join([
		"### What happened",
		"",
		"",
		"### What you expected instead",
		"",
		"",
		"### Steps to reproduce",
		"",
		"1. ",
		"2. ",
		"",
		"### Environment",
		"",
		"- EventSheets: %s" % SheetCompiler.VERSION,
		"- Godot: %s" % str(Engine.get_version_info().get("string", "unknown")),
		"- Platform: %s" % OS.get_name(),
	])


## Tools ▾ "Report an Issue…" (and the Welcome window's footer): opens the tracker in the browser
## with the skeleton above pre-filled. The browser shows the whole report before anything is sent,
## so nothing leaves the machine without the user reading it and pressing submit.
func _report_issue() -> void:
	OS.shell_open("%s?body=%s" % [ISSUES_URL, issue_report_body().uri_encode()])
	_set_status("Opened the issue tracker in your browser - your Godot and plugin versions are pre-filled.")


## Writes the always-current project vocabulary reference (EventSheetVocabularyDoc) -
## the answer to "what can I say in this project?" as one committed markdown file.
func _generate_vocabulary_doc() -> void:
	var doc_path: String = EventSheetVocabularyDoc.write()
	if doc_path.is_empty():
		_set_status("Couldn't write the vocabulary doc to %s." % EventSheetVocabularyDoc.doc_path(), true)
		return
	if Engine.is_editor_hint() and is_inside_tree():
		EditorInterface.get_resource_filesystem().scan()
	_set_status("Vocabulary doc written to %s." % doc_path)


## Tools ▸ Save Studio: format preview, slot browser/export, and the save_state()/
## load_state() generator for addon authors (dock/save_studio.gd).
func _open_save_studio() -> void:
	_save_studio.open()


## Tools ▸ Translation Studio: the whole handoff to a translator - extract the strings, read the
## notes each key travels with, merge a returned file and register the catalogs
## (dock/translation_studio.gd).
func _open_translation_studio() -> void:
	_translation_studio.open()


## View ▸ Preview In Language: renders every globe-marked value in the sheet in the chosen locale
## (or in pseudo), and points Godot's own locale test setting at it so the next Play speaks it too.
## A lens over the SHEET - the sheet on disk is untouched and clearing puts every row back. It is not
## a lens over the PROJECT: `persist` really does write Godot's locale test setting into
## project.godot, which is the point (the next Play speaks the previewed language), so the status
## line says so and picking "As authored" removes the setting again rather than storing an empty one.
## `persist` writes Godot's own locale test setting to project.godot, which is what makes the NEXT
## Play speak the previewed language. The suite drives the same path with it off, so previewing in a
## test can never leave a setting behind in the user's project file.
func _preview_in_language(locale: String, persist: bool = true) -> void:
	if locale.is_empty():
		EventSheetGameCatalog.clear_preview()
		EventSheetGameCatalog.set_test_locale("", persist)
		_refresh_after_edit()
		_set_status("Rows read as you wrote them again, and Godot's Locale > Test setting is cleared.")
		return
	var catalog_path: String = _translation_studio.catalog_path()
	var messages: Dictionary = {}
	if locale != EventSheetGameCatalog.PSEUDO_LOCALE:
		var catalog: Dictionary = EventSheetTranslationScan.read_catalog(catalog_path)
		for row: Variant in (catalog.get("rows", []) as Array):
			var text: String = str((row as Dictionary).get(locale, "")).strip_edges()
			if not text.is_empty():
				messages[str((row as Dictionary).get(EventSheetTranslationScan.KEY_COLUMN, ""))] = text
	EventSheetGameCatalog.set_preview(locale, messages, catalog_path)
	EventSheetGameCatalog.set_test_locale(locale, persist)
	_refresh_after_edit()
	if locale == EventSheetGameCatalog.PSEUDO_LOCALE:
		_set_status("Previewing pseudo - a label that clips here clips in German. The sheet is untouched; Godot's Locale > Test setting now points at pseudo, so the next Play speaks it too. Pick \"As authored\" to put both back.")
		return
	_set_status("Previewing %s - %d translated string(s) from %s. The sheet is untouched; Godot's Locale > Test setting now points at %s, so the next Play speaks it too. Pick \"As authored\" to put both back." % [
		locale, messages.size(), catalog_path, locale])


## Refills the View ▸ Preview In Language submenu from the catalog on disk, so a language column a
## translator just added is pickable without reopening the workspace. Item 0 is always "as
## authored" - the way back, which is what makes previewing safe to try.
func _rebuild_preview_language_menu() -> void:
	if _preview_language_menu == null:
		return
	_preview_language_menu.clear()
	var active: String = EventSheetGameCatalog.preview_locale()
	_preview_language_menu.add_radio_check_item("As authored (English)", 0)
	_preview_language_menu.set_item_checked(0, active.is_empty())
	var languages: PackedStringArray = _preview_languages()
	for index: int in range(languages.size()):
		var locale: String = languages[index]
		var label: String = "Pseudo (finds clipped labels)" if locale == EventSheetGameCatalog.PSEUDO_LOCALE \
			else "%s  (%s)" % [TranslationServer.get_locale_name(locale), locale]
		_preview_language_menu.add_radio_check_item(label, index + 1)
		_preview_language_menu.set_item_checked(index + 1, locale == active)


## Every language the sheet can be previewed in: the catalog's own columns plus pseudo.
func _preview_languages() -> PackedStringArray:
	var languages: PackedStringArray = PackedStringArray()
	var catalog: Dictionary = EventSheetTranslationScan.read_catalog(_translation_studio.catalog_path())
	for locale: String in (catalog.get("locales", PackedStringArray()) as PackedStringArray):
		if locale != EventSheetTranslationScan.SOURCE_COLUMN and not languages.has(locale):
			languages.append(locale)
	if not languages.has(EventSheetGameCatalog.PSEUDO_LOCALE):
		languages.append(EventSheetGameCatalog.PSEUDO_LOCALE)
	return languages


# ── Sheet backups - the save-time ring (core in EventSheetBackups) ────────────────────
var _backups_window: Window = null
var _backups_list: ItemList = null


func _open_sheet_backups() -> void:
	if _current_sheet == null or _current_sheet_path.is_empty():
		_set_status("Backups track saved sheets - save this sheet first.", true)
		return
	if _backups_window == null:
		_backups_window = Window.new()
		_backups_window.title = "Sheet Backups"
		_backups_window.size = Vector2i(460, 360)
		_backups_window.close_requested.connect(func() -> void: _backups_window.hide())
		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		_backups_list = ItemList.new()
		_backups_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_backups_list.item_activated.connect(func(_index: int) -> void: _on_restore_backup_pressed())
		var list_card: PanelContainer = EventSheetPopupUI.panel_section(_backups_list)
		list_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(list_card)
		var restore_button: Button = Button.new()
		restore_button.text = "Restore into editor (unsaved - Save to keep)"
		restore_button.pressed.connect(_on_restore_backup_pressed)
		box.add_child(restore_button)
		var body: MarginContainer = EventSheetPopupUI.margined(box)
		body.set_anchors_preset(Control.PRESET_FULL_RECT)
		_backups_window.add_child(body)
		add_child(_backups_window)
	_backups_list.clear()
	for backup_path: String in EventSheetBackups.list_backups(_current_sheet_path):
		var stamp: String = Time.get_datetime_string_from_unix_time(int(FileAccess.get_modified_time(backup_path))).replace("T", " ")
		_backups_list.add_item("%s - %s" % [stamp, backup_path.get_file()])
		_backups_list.set_item_metadata(_backups_list.item_count - 1, backup_path)
	if _backups_list.item_count == 0:
		_backups_list.add_item("(no backups yet - they appear from the second save on)")
		_backups_list.set_item_disabled(0, true)
	_backups_window.popup_centered()


func _on_restore_backup_pressed() -> void:
	var selected: PackedInt32Array = _backups_list.get_selected_items()
	if selected.is_empty() or _backups_list.get_item_metadata(selected[0]) == null:
		return
	_restore_backup_path(str(_backups_list.get_item_metadata(selected[0])))
	_backups_window.hide()


## Restores a backup INTO the editor as an unsaved change: every storage property of
## the backup is copied onto the open sheet (same object - tabs, viewport and code
## panel stay coherent), the user reviews and saves to keep it. Nothing on disk
## changes until that save, and the save itself backs up the pre-restore state.
func _restore_backup_path(backup_path: String) -> void:
	var backup: EventSheetResource = null
	if backup_path.get_extension() == "gd":
		# A GDScript-backed sheet's backup IS plain source: re-import it through the lifter,
		# then keep the OPEN sheet's source path + read-only state (the imported copy has
		# neither, and the property loop below would otherwise blank them).
		backup = GDScriptImporter.new().import_external_source(FileAccess.get_file_as_string(backup_path))
		if backup != null:
			backup.external_source_path = _current_sheet.external_source_path
			backup.read_only = _current_sheet.read_only
	else:
		backup = ResourceLoader.load(backup_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
	if backup == null:
		_set_status("Couldn't load that backup.", true)
		return
	for property: Dictionary in backup.get_property_list():
		var property_name: String = str(property.get("name"))
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) != 0 \
				and not property_name.begins_with("resource_") and property_name != "script":
			_current_sheet.set(property_name, backup.get(property_name))
	_dirty = true
	_clear_undo_history()
	_refresh_after_edit()
	_refresh_title_strip()
	_set_status("Backup restored into the editor (unsaved) - Save to keep it, reopen the sheet to discard.")


## Writes a deep copy of the current sheet into the project templates dir (never
## overwrites - an existing name gets a -2/-3 suffix). It joins the New… menu
## immediately (the menu rescans on every open).
func _save_as_project_template() -> void:
	if _current_sheet == null:
		return
	var dir_path: String = EventSheetTemplates.templates_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var base_name: String = _current_sheet.custom_class_name.to_snake_case()
	if base_name.is_empty():
		base_name = _current_sheet_path.get_file().get_basename() if not _current_sheet_path.is_empty() else "template"
	var target: String = dir_path.path_join(base_name + ".tres")
	var suffix: int = 2
	while FileAccess.file_exists(target):
		target = dir_path.path_join("%s-%d.tres" % [base_name, suffix])
		suffix += 1
	if ResourceSaver.save(_current_sheet.duplicate(true), target) != OK:
		_set_status("Couldn't write the template to %s." % target, true)
		return
	if Engine.is_editor_hint() and is_inside_tree():
		EditorInterface.get_resource_filesystem().scan()
	_set_status("Template saved: %s - it's in the New… menu now." % target)


static func list_project_sheets() -> PackedStringArray:
	return EventSheetProjectFind.list_project_sheets()


static func find_in_sheet(sheet: EventSheetResource, needle: String) -> Array:
	return EventSheetProjectFind.find_in_sheet(sheet, needle)


## Find-bar "Open in Split" → dock/multi_view_manager.gd (jumps the split pane to the current match).
func _open_match_in_split() -> void:
	_multi_view._open_match_in_split()

# ── Bookmarks panel - extracted to dock/bookmarks_panel.gd ───────────────────────────
var _bookmarks_panel: EventSheetBookmarksPanel = null


func _ensure_bookmarks_panel() -> EventSheetBookmarksPanel:
	if _bookmarks_panel == null:
		_bookmarks_panel = EventSheetBookmarksPanel.new(self)
	return _bookmarks_panel

# ── U16 the minimap column - drawn by dock/minimap.gd ────────────────────────────────
# Three states, two of them the user's: AUTO (nothing stored, the default) shows the column on a
# sheet long enough to need one and hides it on a short one, and an explicit choice, once made,
# holds for every sheet and persists per-project per-user (editor metadata, never repo state).
const MINIMAP_AUTO := -1
const _MINIMAP_META: String = "minimap"


## Whether the column should be on RIGHT NOW: the user's choice if they made one, else the sheet's
## own length. Pure over the count, so the auto rule is pinned without an editor.
static func minimap_shown_for(choice: int, event_count: int) -> bool:
	if choice == MINIMAP_AUTO:
		return event_count > EventSheetMinimap.AUTO_SHOW_EVENT_COUNT
	return choice == 1


func _minimap_choice() -> int:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		return int(EditorInterface.get_editor_settings().get_project_metadata("eventsheets", _MINIMAP_META, MINIMAP_AUTO))
	return MINIMAP_AUTO


func _minimap_enabled() -> bool:
	var event_count: int = _viewport.get_total_row_count() if _viewport != null else 0
	return minimap_shown_for(_minimap_choice(), event_count)


## Re-decides the column's visibility after a sheet is opened or rebuilt. Hidden costs nothing:
## a hidden Control never draws, and the column holds no state of its own.
func _apply_minimap_pref() -> void:
	if _minimap == null:
		return
	_minimap.set_source(_viewport)
	_minimap.visible = _minimap_enabled()
	if _minimap.visible:
		_minimap.queue_redraw()


func _toggle_minimap(view_popup: PopupMenu) -> void:
	var shown: bool = not _minimap_enabled()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata("eventsheets", _MINIMAP_META, 1 if shown else 0)
	if _minimap != null:
		_minimap.set_source(_viewport)
		_minimap.visible = shown
		_minimap.queue_redraw()
	if view_popup != null:
		var item_index: int = view_popup.get_item_index(46)  # View ▸ Minimap (27 is the Patterns lens)
		if item_index >= 0:
			view_popup.set_item_checked(item_index, shown)
	_set_status("Minimap on - the whole sheet down the right edge." if shown
		else "Minimap off.")


# ── Outline panel - extracted to dock/outline_panel.gd ───────────────────────────────
var _outline_panel: EventSheetOutlinePanel = null


func _ensure_outline_panel() -> EventSheetOutlinePanel:
	if _outline_panel == null:
		_outline_panel = EventSheetOutlinePanel.new(self)
	return _outline_panel


func _open_outline_panel() -> void:
	_ensure_outline_panel().open()


# ── U18 History panel - extracted to dock/history_panel.gd ───────────────────────────
var _history_panel: EventSheetHistoryPanel = null


func _ensure_history_panel() -> EventSheetHistoryPanel:
	if _history_panel == null:
		_history_panel = EventSheetHistoryPanel.new(self)
	return _history_panel


func _open_history_panel() -> void:
	_ensure_history_panel().open()


# ── U17 Sheet map - extracted to dock/sheet_map_panel.gd ─────────────────────────────
var _sheet_map_panel: EventSheetSheetMapPanel = null


func _ensure_sheet_map_panel() -> EventSheetSheetMapPanel:
	if _sheet_map_panel == null:
		_sheet_map_panel = EventSheetSheetMapPanel.new(self)
	return _sheet_map_panel


func _open_sheet_map_panel() -> void:
	_ensure_sheet_map_panel().open()


var _outline_tree: Tree:
	get: return _ensure_outline_panel().tree
	set(value): _ensure_outline_panel().tree = value


# Forwarding properties (tests reach these directly - keep them settable).
var _bookmarks_window: Window:
	get: return _ensure_bookmarks_panel().window
	set(value): _ensure_bookmarks_panel().window = value
var _bookmarks_tree: Tree:
	get: return _ensure_bookmarks_panel().tree
	set(value): _ensure_bookmarks_panel().tree = value


func _open_bookmarks_panel() -> void:
	_ensure_bookmarks_panel().open()


func _refresh_bookmarks_list() -> void:
	_ensure_bookmarks_panel().refresh()


## Ctrl+/: toggles the selected rows' enabled state (the sheet's "comment out").
func _toggle_selected_rows_enabled() -> void:
	if _viewport == null or _current_sheet == null:
		return
	var targets: Array[Resource] = []
	for row_data: EventRowData in _active_view().get_selected_rows():
		if row_data != null and row_data.source_resource != null:
			targets.append(row_data.source_resource)
	if targets.is_empty():
		return
	var changed: bool = _perform_undoable_sheet_edit("Toggle Row Enabled", func() -> bool:
		for target: Resource in targets:
			target.set("enabled", not bool(target.get("enabled")))
		return true
	)
	if changed:
		_refresh_after_edit()
		_mark_dirty("Toggled %d row(s)." % targets.size())


## Alt+Up/Down: moves the selected row past its flat neighbor (reuses the drag machinery).
func _move_selected_row(direction: int) -> void:
	if _viewport == null:
		return
	var selected_index: int = _active_view().get_selected_context().get("row_index", -1)
	var row_data: EventRowData = _active_view().get_selected_row_data()
	if row_data == null or selected_index < 0:
		return
	var target_index: int = selected_index + direction
	if target_index < 0 or target_index >= _viewport.get_flat_rows().size():
		return
	var target_row: EventRowData = _viewport.get_flat_rows()[target_index].get("row")
	if target_row == null or target_row.source_resource == null:
		return
	_move_rows([row_data], target_row, "before" if direction < 0 else "after")


## Editor-native defaults: inherit the user's editor theme when no explicit sheet theme was chosen
## (presets / per-sheet themes still override). DISPLAY SCALE is deliberately NOT applied here - the
## canvas font comes from get_theme_default_font_size(), into which the editor theme has already
## multiplied the display scale (Godot bakes EDSCALE into every fixed size it generates). Zooming the
## canvas by the scale on top of that applied it TWICE: on a Retina Mac at 200% the sheet drew its text
## about 1.8x the size of the surrounding editor chrome (1.8 rather than 2 because MAX_ZOOM_FACTOR
## clamped it, which also left Zoom In dead from the very first frame). Zoom is a USER control and
## starts at 1.0; HiDPI reaches the canvas through the font, as it does for every other editor Control.
func _apply_editor_native_defaults() -> void:
	if not Engine.is_editor_hint() or _viewport == null:
		return
	# The active style lives on EventSheetThemeManager now; read it through the getter to decide
	# whether to derive the "Match Editor" default (apply_theme_style is the dock's delegate below).
	if _theme_manager.get_active_theme_style() == null:
		var derived: EventSheetEditorStyle = EventSheetEditorThemeDeriver.derive_from_editor()
		if derived != null:
			apply_theme_style(derived)


# ── Quick-add bar ("type to insert") - bodies in EventSheetAuthorActions (dock/author_actions.gd).
# The WIDGET stays declared here (menu_bar.gd builds it and assigns it back; its text_submitted
# closure calls the _quick_add delegate below). The match+apply brain delegates to _author_actions.
var _quick_add_edit: LineEdit = null


func _quick_match(query: String) -> Dictionary:  # intellisense_test
	return _author_actions._quick_match(query)


func _quick_add(query: String) -> bool:  # menu_bar.gd quick-add closure + intellisense_test
	return _author_actions._quick_add(query)


func _quick_match_ranked(query: String, limit: int = 5, prefer_type: int = -1) -> Array:  # dock/ghost_row.gd suggestion list
	return _author_actions._quick_match_ranked(query, limit, prefer_type)


func _quick_suggestions(origin: String, limit: int = 4) -> Array:  # dock/ghost_row.gd chips
	return _author_actions.suggested_definitions(origin, limit)


# The E/C/A single keys open the Ghost Row (type-a-sentence add at the selected row, zero dialogs);
# the toolbar buttons + the Ctrl chords keep the classic full pickers, and Ctrl+Enter inside the ghost
# row reaches them too - the browsable catalog is never more than one keystroke away.
func _open_ghost_event() -> void:
	_ghost_row.open("event")


func _open_ghost_condition() -> void:
	_ghost_row.open("condition")


func _open_ghost_action() -> void:
	_ghost_row.open("action")


# ── Pick-filter dialog ("for each" picking) → dock/pick_filter_dialog.gd ──
func _open_pick_filter_dialog(event_resource: Resource, pick_index: int = -1) -> void:  # viewport/view pick_filter_edit_requested + row menu
	_pick.open(event_resource, pick_index)


# ── Comment + With-node dialogs + comment<->action conversion → dock/comment_and_scope_dialogs.gd ──
func _open_comment_dialog(comment_resource: Resource) -> void:  # viewport comment_edit_requested + row menu
	_comments.open_comment_dialog(comment_resource)


func _open_with_node_dialog(event_resource: Resource) -> void:  # viewport with_node_edit_requested
	_comments.open_with_node_dialog(event_resource)


func _attach_comment_to_event_above(comment_row: CommentRow) -> void:  # row context menu
	_comments.attach_comment_to_event_above(comment_row)


func _detach_comment_to_row(comment_row: CommentRow) -> void:  # action-cell context menu
	_comments.detach_comment_to_row(comment_row)


func _open_sheet_type_dialog() -> void:
	_sheet_type_glue.open_sheet_type_dialog()



func _add_sheet_type_field(form: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
	return _sheet_type_glue.add_sheet_type_field(form, label_text, placeholder)



func _add_sheet_type_multiline_field(form: VBoxContainer, label_text: String, placeholder: String) -> TextEdit:
	return _sheet_type_glue.add_sheet_type_multiline_field(form, label_text, placeholder)



func _apply_sheet_type_settings(type_index: int, class_name_text: String, icon_path: String, host_class_text: String, tool_enabled: bool = false, addon_tags: PackedStringArray = PackedStringArray(), include_paths: PackedStringArray = PackedStringArray(), uses_classes: PackedStringArray = PackedStringArray(), requires_classes: PackedStringArray = PackedStringArray(), autoload_name_text: String = "", class_description_text: String = "", family_enabled: bool = false) -> void:
	_sheet_type_glue.apply_sheet_type_settings(type_index, class_name_text, icon_path, host_class_text, tool_enabled, addon_tags, include_paths, uses_classes, requires_classes, autoload_name_text, class_description_text, family_enabled)



## Footer "Add event…" rows: opens the event picker; the new event is appended into the
## clicked footer's owner (a group, or the sheet end).
func _on_viewport_add_event_requested(owner_resource: Resource) -> void:
	if not _ensure_sheet_for_editing():
		return
	_ace_picker.open(
		"new_condition_event",
		false,
		null,
		{"mode": "new_condition_event", "insert_into": owner_resource}
	)


## Persists a lane-divider resize. A default-themed sheet is promoted to a concrete editor
## style so the ratio saves with the sheet; an already-styled sheet is edited in place.
func _on_viewport_lane_ratio_changed(ratio: float) -> void:
	if _current_sheet == null:
		return
	if _current_sheet.editor_style == null:
		var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
		style.ensure_defaults()
		style.get_event_style().condition_lane_ratio = ratio
		_current_sheet.editor_style = style
		_viewport.apply_editor_style(style)
	else:
		_current_sheet.editor_style.get_event_style().condition_lane_ratio = ratio
	_mark_dirty("Resized conditions/actions lane to %d%%." % int(round(ratio * 100.0)))


## Persists an object-column resize (the event-sheet sub-lane between object names and display text),
## same promote-or-edit flow as the lane ratio so the width saves with the sheet.
func _on_viewport_object_column_width_changed(lane: String, width: int) -> void:
	if _current_sheet == null:
		return
	if _current_sheet.editor_style == null:
		var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
		style.ensure_defaults()
		_current_sheet.editor_style = style
		_viewport.apply_editor_style(style)
	var event_style: EventSheetEventStyle = _current_sheet.editor_style.get_event_style()
	if lane == "condition":
		event_style.condition_object_column_width = width
	else:
		event_style.action_object_column_width = width
	_mark_dirty("Resized the %s lane's object column to %dpx." % [lane, width])


func _on_viewport_context_menu_requested(row_data: EventRowData, hit: Dictionary, global_position: Vector2) -> void:
	_context_row = row_data
	_context_hit = hit.duplicate(true)
	_variables._context_variable = {}
	if row_data == null:
		return
	var metadata: Dictionary = hit.get("span_metadata", {})
	if str(metadata.get("kind", "")) == "variable":
		_variables._context_variable = _context_variable_entry_from_metadata(row_data, metadata)
		if not _variables._context_variable.is_empty():
			_show_popup_menu(_variable_context_menu, global_position)
			return
	var kind: String = str(metadata.get("kind", ""))
	if kind in ["condition", "trigger"]:
		_show_popup_menu(_condition_context_menu, global_position)
		return
	if kind == "action":
		_refresh_convert_to_verb_item()
		_refresh_collection_decl_items()
		_refresh_timeline_items()
		_show_popup_menu(_action_context_menu, global_position)
		return
	# Everything else - including data_class_field spans - routes to the row menu: the
	# builder scopes a synthetic FIELD row's menu to Add/Remove Field only (an early
	# return that used to swallow field-span clicks here left Remove Field unreachable).
	_build_row_context_menu(row_data)
	_show_popup_menu(_row_context_menu, global_position)


# Row context menu + its Insert ▸ / More ▸ submenus are built by EventSheetContextMenus
# (dock/context_menus.gd). Thin delegates: the viewport row-menu site + tests still call
# _build_row_context_menu / _build_row_more_submenu on the dock by name. _build_row_insert_submenu
# is internal to the helper (only _build_row_context_menu calls it), so it keeps no delegate.
func _build_row_context_menu(row_data: EventRowData) -> void:
	_context_menus._build_row_context_menu(row_data)


func _build_row_more_submenu(is_event: bool) -> void:
	_context_menus._build_row_more_submenu(is_event)


func _on_viewport_empty_space_double_clicked() -> void:
	# With NO sheet open, the empty state invites this exact gesture - honor it. The old path died
	# inside _ensure_sheet_for_editing with only a status-bar warning, which read as a broken
	# promise to a first-time user. Opening the starter menu makes the double-click CREATE the
	# sheet it needs instead of scolding.
	if _current_sheet == null:
		_open_template_menu()
		return
	if not _ensure_sheet_for_editing():
		return
	# Double-clicking empty space reads as "I want a new event here" - open the ACE picker in new-event
	# mode so the user picks the first condition/trigger immediately, rather than dropping a blank event
	# they then have to fill. Selection is cleared first so the new event lands at the end (where they
	# clicked), not nested under whatever happened to be selected. Mirrors the "Add Event" toolbar button
	# and the "+ Add event…" footer, so every "make a new event" path opens the same picker.
	if _viewport != null:
		_viewport.clear_selection()
	# The event-sheet gesture in full: double-click empty space leads with OBJECT cards (System,
	# behaviors, packs), then that object's verbs. Toolbar/footer adds keep the classic tree.
	_ace_picker.open("new_event", false, null, {"object_first": true})


func _on_viewport_empty_space_context_menu_requested(global_position: Vector2) -> void:
	_context_row = null
	_context_hit = {}
	_variables._context_variable = {}
	_show_popup_menu(_empty_space_context_menu, global_position)


func _on_empty_space_context_menu_id_pressed(id: int) -> void:
	match id:
		EMPTY_MENU_NEW_EVENT:
			_on_viewport_empty_space_double_clicked()
		EMPTY_MENU_NEW_CONDITION:
			if _viewport != null:
				_viewport.clear_selection()
			_on_add_condition_requested()
		EMPTY_MENU_ADD_VARIABLE:
			_on_add_global_variable_requested()
		EMPTY_MENU_ADD_LOCAL_VARIABLE:
			_on_add_local_variable_requested()
		EMPTY_MENU_ADD_INSTANCE_VARIABLE:
			_on_add_instance_variable_requested()
		EMPTY_MENU_ADD_INSPECTOR_BUTTON:
			_quick_prompts.prompt_inspector_button(add_inspector_button)
		EMPTY_MENU_INSERT_SNIPPET:
			_open_insert_snippet()


## R32. The `@export_tool_button` line and the empty function it calls, in ONE undo step. The button
## is a labelled function, which is the shape the sheet already emits for one - so nothing new is
## written to the file and the line round-trips exactly as an authored button always has.
func add_inspector_button(label: String) -> bool:
	var button_label: String = label.strip_edges()
	if button_label.is_empty() or _current_sheet == null:
		return false
	var function_name: String = _unique_extracted_function_name(_current_sheet, button_label.to_snake_case())
	var changed: bool = _perform_undoable_sheet_edit("Add Inspector Button", func() -> bool:
		var event_function: EventFunction = EventFunction.new()
		event_function.function_name = function_name
		event_function.tool_button_label = button_label
		_current_sheet.functions.append(event_function)
		return true)
	if changed:
		var note: String = "Added the Inspector button \"%s\" and the function it calls." % button_label
		if not _current_sheet.tool_mode:
			note += "  (turn on Tool in the Sheet Type dialog for it to run in the editor.)"
		_mark_dirty(note)
	return changed


## The "New Function ▸" submenu: a plain helper, or a published Action / Condition / Expression - each
## opens the function dialog pre-configured, so "New Action" lands on the Action card with Publish ticked.
func _on_new_function_submenu_id_pressed(id: int) -> void:
	match id:
		NEW_FUNCTION_MENU_PLAIN:
			_function_dialog_glue._open_function_dialog_new("", false)
		NEW_FUNCTION_MENU_ACTION:
			_function_dialog_glue._open_function_dialog_new("action", true)
		NEW_FUNCTION_MENU_CONDITION:
			_function_dialog_glue._open_function_dialog_new("condition", true)
		NEW_FUNCTION_MENU_EXPRESSION:
			_function_dialog_glue._open_function_dialog_new("expression", true)


# Context-menu popup + per-click configuration live in EventSheetContextMenus (dock/context_menus.gd).
# Thin delegates: the viewport context-menu sites + tests still call _show_popup_menu / _configure_context_menu
# on the dock by name. _configure_context_menu reads live dock state (_context_row, _context_hit,
# _variables._context_variable, the selection) to relabel/enable per-row-type items each time.
func _show_popup_menu(menu: PopupMenu, global_position: Vector2) -> void:
	_context_menus._show_popup_menu(menu, global_position)


func _configure_context_menu(menu: PopupMenu) -> void:
	_context_menus._configure_context_menu(menu)


func _on_condition_context_menu_id_pressed(id: int) -> void:
	if _context_row == null or not (_context_row.source_resource is EventRow):
		return
	match id:
		CONDITION_MENU_EDIT:
			_on_viewport_ace_edit_requested(_context_row, int(_context_hit.get("span_index", -1)), _context_hit.get("span_metadata", {}))
		CONDITION_MENU_ADD:
			_ace_picker.open("append_condition", false, _context_row.source_resource)
		CONDITION_MENU_REPLACE:
			var replace_context: Dictionary = _build_ace_edit_context(_context_row.source_resource as EventRow, int(_context_hit.get("span_index", -1)), _context_hit.get("span_metadata", {}))
			if not replace_context.is_empty():
				var replace_def: ACEDefinition = replace_context.get("definition", null)
				if replace_def != null:
					replace_context["preselect_ace_id"] = replace_def.id
				_ace_picker.open(str(replace_context.get("mode", "replace_condition")), false, _context_row.source_resource, replace_context)
		CONDITION_MENU_INVERT:
			_toggle_context_condition_inversion()
		CONDITION_MENU_EDIT_ACE_COMMENT:
			_open_ace_comment_dialog(_context_ace_resource("condition"))
		CONDITION_MENU_TOGGLE_ENABLED:
			_toggle_context_ace_enabled()
		ACE_MENU_SELECT_ALL_MATCHING:
			_select_all_matching_from_context("condition")
		CONDITION_MENU_DELETE:
			_delete_context_ace()


## Shows "Convert to <verb>" only when the right-clicked raw call matches exactly one of the
## project's own verbs - a permanently greyed item on every other action would be clutter,
## and a wrong offer is worse than none.
func _refresh_convert_to_verb_item() -> void:
	if _action_context_menu == null:
		return
	var existing: int = _action_context_menu.get_item_index(ACTION_MENU_CONVERT_TO_VERB)
	if existing >= 0:
		_action_context_menu.remove_item(existing)
	var suggestion: Dictionary = suggested_verb_for_action(_context_ace_resource("action"))
	if suggestion.is_empty():
		return
	_action_context_menu.add_item("Convert to %s ▸ %s" % [str(suggestion["provider_id"]),
		str(suggestion["display_name"])], ACTION_MENU_CONVERT_TO_VERB)
	_action_context_menu.set_item_tooltip(_action_context_menu.get_item_index(ACTION_MENU_CONVERT_TO_VERB),
		"This raw call matches one of your project's actions. Converting names the row and gives it that action's parameter fields; the emitted code is unchanged.")


## Option 2 of the collection-declaration work: entry verbs on the action menu, shown only
## when the right-clicked action IS a Declare row (a permanently greyed trio elsewhere would
## be clutter). Edit/Remove appear only when the click landed on an entry line.
func _refresh_collection_decl_items() -> void:
	if _action_context_menu == null:
		return
	for decl_id: int in [ACTION_MENU_DECL_ADD_ENTRY, ACTION_MENU_DECL_EDIT_ENTRY, ACTION_MENU_DECL_REMOVE_ENTRY]:
		var existing_index: int = _action_context_menu.get_item_index(decl_id)
		if existing_index >= 0:
			_action_context_menu.remove_item(existing_index)
	var decl: CollectionDeclRow = _context_ace_resource("action") as CollectionDeclRow
	if decl == null:
		return
	_action_context_menu.add_item("Add Entry…", ACTION_MENU_DECL_ADD_ENTRY)
	var entry_index: int = _context_decl_entry_index()
	if entry_index >= 0 and entry_index < decl.entry_values.size():
		_action_context_menu.add_item("Edit Entry…", ACTION_MENU_DECL_EDIT_ENTRY)
		_action_context_menu.add_item("Remove Entry", ACTION_MENU_DECL_REMOVE_ENTRY)


## "Add Step..." appears on the action menu whenever the context click targets a Timeline
## (its caption or one of its beat rows). Mirrors the Declare entry-menu wiring.
func _refresh_timeline_items() -> void:
	if _action_context_menu == null:
		return
	var existing_index: int = _action_context_menu.get_item_index(ACTION_MENU_TIMELINE_ADD_STEP)
	if existing_index >= 0:
		_action_context_menu.remove_item(existing_index)
	if _context_timeline() == null:
		return
	_action_context_menu.add_item("Add Step…", ACTION_MENU_TIMELINE_ADD_STEP)


## The Timeline the context click targets: the right-clicked ACTION when it is one, else the
## row's own resource (a beat child row carries its TimelineRow as source_resource).
func _context_timeline() -> TimelineRow:
	var action_timeline: TimelineRow = _context_ace_resource("action") as TimelineRow
	if action_timeline != null:
		return action_timeline
	if _context_row != null:
		return _context_row.source_resource as TimelineRow
	return null


## Appends one beat through the undo funnel; the schedule stays time-sorted.
func _apply_timeline_step(timeline: TimelineRow, at_seconds: float, code_line: String) -> void:
	if timeline == null or code_line.strip_edges().is_empty():
		return
	var changed: bool = _perform_undoable_sheet_edit("Add Timeline Step", func() -> bool:
		var step_action: RawCodeRow = RawCodeRow.new()
		step_action.code = code_line.strip_edges()
		timeline.add_step(maxf(at_seconds, 0.0), step_action)
		return true)
	if changed:
		_mark_dirty("Added a timeline step.")


## The declaration the context click targets: the right-clicked ACTION when it is one (the
## in-body form), else the row's own resource (the top-level form). One resolver so the action
## menu and the row menu share the same three handlers.
func _context_decl() -> CollectionDeclRow:
	var action_decl: CollectionDeclRow = _context_ace_resource("action") as CollectionDeclRow
	if action_decl != null:
		return action_decl
	if _context_row != null:
		return _context_row.source_resource as CollectionDeclRow
	return null


## The entry line the context click landed on, or -1 (the header line carries no entry index).
func _context_decl_entry_index() -> int:
	var metadata: Variant = _context_hit.get("span_metadata", {})
	if not (metadata is Dictionary):
		return -1
	return int((metadata as Dictionary).get("decl_entry_index", -1))


## Removes one entry of a Declare row undoably. Add/Edit go through the quick-prompt dialog;
## removal needs no input, so it applies directly.
func _remove_collection_entry(decl: CollectionDeclRow, entry_index: int) -> void:
	if decl == null or entry_index < 0 or entry_index >= decl.entry_values.size():
		return
	var removed: bool = _perform_undoable_sheet_edit("Remove Entry", func() -> bool:
		decl.entry_keys.remove_at(entry_index)
		decl.entry_values.remove_at(entry_index)
		return true
	)
	if removed:
		_mark_dirty("Removed entry.")


## The project verb a raw Call Method row looks like, or {} when there is no single answer.
## Reads the action's own params, so it works on any generic call however it got here (typed
## by hand, pasted, or lifted from foreign GDScript).
func suggested_verb_for_action(action: Resource) -> Dictionary:
	if action == null or str(action.get("ace_id")) != "CallMethod":
		return {}
	var params: Dictionary = action.get("params")
	var class_id: String = EventSheetVerbSuggestion.class_from_target(str(params.get("target", "")))
	if class_id.is_empty():
		return {}
	var candidates: Array = []
	# A class that publishes through `@ace_*` annotations (a behaviour pack, or your own
	# annotated script) is NOT in the reflected scan - it is already in the registry, with the
	# author's own names. Those are the best conversions available, so they are searched
	# first: `$Health.take_damage(10)` should become the Health pack's own Take Damage.
	if _ace_registry != null:
		for definition: ACEDefinition in _ace_registry.get_all_definitions():
			if str(definition.provider_id) == class_id:
				candidates.append(definition)
	if candidates.is_empty():
		for entry: Dictionary in EventSheetProjectScanner.list_project_classes():
			if str(entry.get("name", "")) != class_id:
				continue
			candidates = EventSheetVocabularyCatalog.apply(
				EventSheetClassDBSource.definitions_for_class(class_id, str(entry.get("autoload", ""))))
			break
	if candidates.is_empty():
		return {}
	return EventSheetVerbSuggestion.suggest(str(params.get("target", "")), str(params.get("method", "")),
		str(params.get("args", "")), candidates)


## Converts the right-clicked raw call into the verb it matches, through the ORDINARY apply
## path - so the template bakes at apply time and the row is indistinguishable from one
## picked out of the picker. One undo step, and never automatic: the user asked for it.
func _convert_context_action_to_verb() -> void:
	var action: Resource = _context_ace_resource("action")
	var suggestion: Dictionary = suggested_verb_for_action(action)
	if suggestion.is_empty():
		return
	var definition: ACEDefinition = _ace_registry.find_definition(
		str(suggestion["provider_id"]), str(suggestion["ace_id"])) if _ace_registry != null else null
	if definition == null:
		# Reflected verbs are not in the registry - resolve from the same source the
		# suggestion came from.
		for candidate: ACEDefinition in EventSheetClassDBSource.definitions_for_class(str(suggestion["provider_id"])):
			if str(candidate.id) == str(suggestion["ace_id"]):
				definition = candidate
				break
	if definition == null:
		return
	var params: Dictionary = EventSheetVerbSuggestion.mapped_params(definition, suggestion["arguments"])
	if params.is_empty() and definition.parameters.size() > 0:
		return
	_apply_ace_definition(definition, params, {
		"mode": "replace_action",
		"selected_resource": _context_row.source_resource,
		"ace_index": int(_context_hit.get("ace_index", -1)),
	})
	_set_status("Converted to %s." % str(suggestion["display_name"]))


## Sheet > Name Raw Calls...: the whole-sheet twin of the row-by-row conversion above. Same
## conservatism (one candidate or nothing), plus a per-row byte gate, one undo step, and a
## count of what it left alone. Never automatic - the user asks for it.
func _name_raw_calls_requested() -> void:
	_raw_call_namer.run()


func _on_action_context_menu_id_pressed(id: int) -> void:
	if _context_row == null or not (_context_row.source_resource is EventRow):
		return
	match id:
		ACTION_MENU_EDIT:
			_on_viewport_ace_edit_requested(_context_row, int(_context_hit.get("span_index", -1)), _context_hit.get("span_metadata", {}))
		ACTION_MENU_ADD:
			_ace_picker.open("append_action", false, _context_row.source_resource)
		ACTION_MENU_REPLACE:
			var replace_context: Dictionary = _build_ace_edit_context(_context_row.source_resource as EventRow, int(_context_hit.get("span_index", -1)), _context_hit.get("span_metadata", {}))
			if not replace_context.is_empty():
				var replace_def: ACEDefinition = replace_context.get("definition", null)
				if replace_def != null:
					replace_context["preselect_ace_id"] = replace_def.id
				_ace_picker.open("replace_action", false, _context_row.source_resource, replace_context)
		ACTION_MENU_CONVERT_TO_VERB:
			_convert_context_action_to_verb()
		ACTION_MENU_EDIT_ACE_COMMENT:
			_open_ace_comment_dialog(_context_ace_resource("action"))
		ACTION_MENU_TOGGLE_ENABLED:
			_toggle_context_ace_enabled()
		ACE_MENU_SELECT_ALL_MATCHING:
			_select_all_matching_from_context("action")
		ACTION_MENU_DETACH_COMMENT:
			var detach_index: int = int(_context_hit.get("ace_index", -1))
			var context_event: EventRow = _context_row.source_resource as EventRow
			if context_event != null and detach_index >= 0 and detach_index < context_event.actions.size() and context_event.actions[detach_index] is CommentRow:
				_detach_comment_to_row(context_event.actions[detach_index] as CommentRow)
			else:
				_set_status("Right-click an action-cell comment to detach it.", true)
		ACTION_MENU_DELETE:
			_delete_context_ace()
		ACTION_MENU_EXTRACT_FN:
			_extract_to_function_requested()
		ACTION_MENU_DECL_ADD_ENTRY:
			_quick_prompts.prompt_collection_entry(_context_decl(), -1)
		ACTION_MENU_DECL_EDIT_ENTRY:
			_quick_prompts.prompt_collection_entry(_context_decl(), _context_decl_entry_index())
		ACTION_MENU_DECL_REMOVE_ENTRY:
			_remove_collection_entry(_context_decl(), _context_decl_entry_index())
		ACTION_MENU_TIMELINE_ADD_STEP:
			_quick_prompts.prompt_timeline_step(_context_timeline())


func _on_row_context_menu_id_pressed(id: int) -> void:
	_input_dispatch.on_row_context_menu_id_pressed(id)


## Select All Matching (the event-sheet "find my other uses" reflex): selects every event in the
## sheet that uses the right-clicked cell's ACE - as trigger, condition, or action - so
## Replace Object References and Edit Values Across Selection have their rows one click
## later. Pure view-layer: nothing is mutated.
func _select_all_matching_from_context(lane: String) -> void:
	if _current_sheet == null or _viewport == null:
		return
	var provider_id: String = ""
	var ace_id: String = ""
	var ace: Resource = _context_ace_resource(lane)
	if ace != null:
		provider_id = str(ace.get("provider_id"))
		ace_id = str(ace.get("ace_id"))
	elif lane == "condition" and _context_row != null and _context_row.source_resource is EventRow:
		# A baked trigger row can have ids without a trigger resource - still matchable.
		provider_id = (_context_row.source_resource as EventRow).trigger_provider_id
		ace_id = (_context_row.source_resource as EventRow).trigger_id
	if provider_id.is_empty() or ace_id.is_empty():
		_set_status("Right-click a condition or action cell to select its other uses.", true)
		return
	var matches: Array = EventSheetACEApply.matching_event_rows(_current_sheet.events, provider_id, ace_id)
	var selected: int = _viewport.select_resources(matches)
	if selected == 0:
		_set_status("No events use %s.%s." % [provider_id, ace_id], true)
		return
	var definition: ACEDefinition = _find_definition(provider_id, ace_id)
	_set_status("Selected %d event(s) using %s." % [selected, definition.display_name if definition != null else ace_id])



# ── Bulk operations on the multi-selection - bodies in EventSheetRowEditOps (dock/row_edit_ops.gd).
# Thin delegates: the toolbar bulk actions + tedium_test call these on the dock by name.
func _bulk_set_enabled_on(targets: Array) -> void:
	_row_edit_ops._bulk_set_enabled_on(targets)


func _bulk_duplicate_rows(targets: Array) -> void:
	_row_edit_ops._bulk_duplicate_rows(targets)


func _bulk_group_rows(targets: Array) -> String:
	return _row_edit_ops._bulk_group_rows(targets)


## Fresh uids on a duplicated row tree (groups recurse; EventRows re-bake stateful
## member uids - the paste contract).
func _refresh_clone_uids(resource: Resource) -> void:
	if resource is EventRow:
		_assign_fresh_event_uids(resource as EventRow)
	elif resource is EventGroup:
		var group: EventGroup = resource as EventGroup
		for child: Variant in (group.events if not group.events.is_empty() else group.rows):
			if child is Resource:
				_refresh_clone_uids(child as Resource)

# ── Asset drops with intent (the drag-into-layout reflex, grafted onto events):
# a scene dropped on an event row spawns, a sound plays - pre-filled, undoable. ───────


## Inspector property dropped on the sheet: build a Set Property action targeting that
## node + property, current value pre-filled - on the row it landed on, or as a new event.
func _apply_property_drop(target_event: Resource, node_reference: String, property_name: String, value_literal: String) -> void:
	if property_name.is_empty() or not _ensure_sheet_for_editing():
		return
	var definition: ACEDefinition = _find_definition("Core", "SetProperty")
	if definition == null:
		_set_status("The Set Property action is unavailable - is the Helpers module disabled?", true)
		return
	var params: Dictionary = {
		"target": node_reference,
		"property": property_name,
		"value": value_literal if not value_literal.is_empty() else str(definition.parameters[2].get("default_value", "null")),
	}
	var mode: String = "append_action" if target_event is EventRow else "new_event"
	_ace_apply._apply_ace_definition(definition, params, {"mode": mode, "selected_resource": target_event})


## Routes each dropped file through the EventSheets asset-drop seam (the built-in
## handlers register there too - scenes spawn, sounds play, images and resources/scripts
## preload, JSON loads into a variable). ACEActions land on the event row the file hit, or
## open a fresh On Ready event on an empty-space drop; any other row resource (the preload
## block) is a top-level declaration. One undo step either way. The generated sheet must
## always compile, so an action that assigns to a variable auto-declares it, and a preload
## const can never redefine an existing top-level name (deduped by path, suffixed on clash).
func _apply_asset_drop(target_event: Resource, asset_paths: PackedStringArray) -> void:
	# P4 - ONE scene dropped on the empty space of a READING opens that scene as a sheet. On an
	# editable sheet a dropped scene means what it always meant (the action that creates it), and on a
	# row it names that row's target; but a reading cannot take an action at all, so there the gesture
	# can only mean "read this scene too".
	if target_event == null and asset_paths.size() == 1 and asset_paths[0].get_extension().to_lower() == "tscn" \
			and (_current_sheet == null or _current_sheet.read_only):
		_load_sheet_from_path(asset_paths[0])
		return
	if not _ensure_sheet_for_editing():
		return
	var counters: Dictionary = {"added": 0}
	var changed: bool = _perform_undoable_sheet_edit("Drop Asset", func() -> bool:
		var event_target: EventRow = target_event as EventRow
		for asset_path: String in asset_paths:
			var build: Callable = EventSheets.asset_drop_builder_for(asset_path.get_extension())
			if not build.is_valid():
				continue
			var built: Resource = build.call(asset_path, target_event)
			if built is ACEAction:
				# A dropped action can assign to a variable (Load JSON -> a variable); auto-declare
				# any it names but the sheet doesn't have, so the generated script still compiles.
				_ensure_action_variables_declared(built as ACEAction)
				# The effect maps onto the ACTION lane: dropped on a row it joins that
				# event; on empty space it starts a fresh On Ready event (shared by every
				# action in this drop, so a multi-file drop reads as one event).
				if event_target == null:
					event_target = EventRow.new()
					event_target.trigger_provider_id = "Core"
					event_target.trigger_id = "OnReady"
					_current_sheet.events.append(event_target)
				event_target.actions.append(built)
				counters["added"] = int(counters["added"]) + 1
			elif built is CustomBlockRow and (built as CustomBlockRow).kind_id == "preload":
				# A preload declaration: skip an exact-path duplicate, and never let its const
				# name redefine an existing declaration (suffix it), or the sheet won't compile.
				if _adopt_preload_block(built as CustomBlockRow):
					counters["added"] = int(counters["added"]) + 1
			elif built != null:
				# Any other declaration row - top level.
				_current_sheet.events.append(built)
				counters["added"] = int(counters["added"]) + 1
		return int(counters["added"]) > 0)
	if changed:
		_mark_dirty("Added %d row(s) from the dropped asset(s)." % int(counters["added"]))
	else:
		_set_status("Nothing to add for that file type - drop scenes, sounds, images, JSON, or resources.", true)


## Declares (as an internal Variant, null default) any variable an action ASSIGNS to via a
## variable_reference param but the sheet doesn't already have - so a dropped Load JSON row
## whose "data" target doesn't exist can't emit an assignment to an undeclared identifier.
func _ensure_action_variables_declared(action: ACEAction) -> void:
	var definition: ACEDefinition = _find_definition(action.provider_id, action.ace_id)
	if definition == null:
		return
	for param: Dictionary in definition.parameters:
		if not str(param.get("hint", "")).begins_with("variable_reference"):
			continue
		var var_name: String = str(action.params.get(str(param.get("id", "")), "")).strip_edges()
		if var_name.is_empty() or not EventSheetIdentifierRules.is_valid(var_name):
			continue
		if not (_current_sheet.variables is Dictionary and (_current_sheet.variables as Dictionary).has(var_name)):
			if not (_current_sheet.variables is Dictionary):
				_current_sheet.variables = {}
			_current_sheet.variables[var_name] = {"type": "Variant", "default": null, "exported": false}


## Inserts a preload block unless the sheet already preloads that exact path (returns false,
## nothing added); if only the const NAME collides with an existing top-level declaration, the
## name is suffixed (_2, _3, ...) so `const X := preload(...)` can never be redefined.
func _adopt_preload_block(block: CustomBlockRow) -> bool:
	var path: String = str(block.fields.get("path", ""))
	var taken_names: Dictionary = {}
	for entry: Variant in _current_sheet.events:
		if entry is CustomBlockRow and (entry as CustomBlockRow).kind_id == "preload":
			if str((entry as CustomBlockRow).fields.get("path", "")) == path:
				return false  # already preloaded - a second identical drop adds nothing
			taken_names[str((entry as CustomBlockRow).fields.get("name", ""))] = true
	if _current_sheet.variables is Dictionary:
		for existing_name: Variant in (_current_sheet.variables as Dictionary).keys():
			taken_names[str(existing_name)] = true
	var base_name: String = str(block.fields.get("name", "Res"))
	var unique_name: String = base_name
	var suffix: int = 2
	while taken_names.has(unique_name):
		unique_name = "%s_%d" % [base_name, suffix]
		suffix += 1
	block.fields = block.fields.duplicate(true)
	block.fields["name"] = unique_name
	_current_sheet.events.append(block)
	return true

# ── .gd preview / open-in-Godot / lift report - delegates to EventSheetPreviewGlue ────────
# The read-only .gd-preview banner, the "Edit Events" unlock, the glue that hands scripts/paths to
# Godot's own script editor (EditorInterface.edit_script), and the lift-report window now live in
# dock/preview_glue.gd. These thin forwarders keep the original names + signatures + returns so the
# in-file .connect() sites (below), the tests, and the sibling dock/ helpers (menu_bar →
# _open_lift_report; sheet_io + session_store → _refresh_preview_banner; new_addon_panel →
# _open_gdscript_path_in_godot; ace_apply → _on_preview_edit_requested) all resolve unchanged.
#
# WIDGETS STAY ON THE DOCK: `_preview_banner` + `_preview_label` (declared up top) - the glue's
# build_preview_banner() constructs the panel and assigns them back, so _refresh_title_strip + the
# tests keep reading them by name.


func _refresh_preview_banner() -> void:
	_preview_glue._refresh_preview_banner()


func _on_preview_edit_requested() -> void:
	_preview_glue._on_preview_edit_requested()


func _open_gdscript_path_in_godot(path: String, line: int = -1) -> bool:
	return _preview_glue._open_gdscript_path_in_godot(path, line)


func _open_raw_code_block_in_godot() -> void:
	_preview_glue._open_raw_code_block_in_godot()


func _open_generated_in_godot() -> void:
	_preview_glue._open_generated_in_godot()


func _on_provider_open_in_godot_pressed() -> void:
	_preview_glue._on_provider_open_in_godot_pressed()


func _open_lift_report() -> void:
	_preview_glue._open_lift_report()


# ── Sheet functions: the Add ▾ → Function… dialog glue → dock/function_dialog.gd ─────
# (Bodies live in EventSheetFunctionDialogGlue; these delegates keep the names reached from
# outside: the in-file Add-Function button + menu_bar Add menu (id 3) + command palette hit
# _open_function_dialog, and the function_dialog + godot_workflow tests call _apply_function_data.)
func _open_function_dialog() -> void:
	_function_dialog_glue._open_function_dialog()


func _apply_function_data(data: Dictionary) -> void:
	_function_dialog_glue._apply_function_data(data)


# ── ACE properties: a published verb's header click → dock/verb_properties_popup.gd ─────
## Clicking a verb's Function-block header opens its ACE properties (kind, category, inputs, what it
## gives back, description, picker entry, the line it inserts, the function behind it).
func open_verb_properties(event_function: Resource) -> void:
	_verb_properties.open_for(event_function)


## N10 - a click on a row's object name opens that object's popup.
func open_object_properties(object_label: String) -> void:
	_object_properties.open_for(object_label)


## V12 - the "Use hp" beside an unknown-variable note. One undo step that rewrites every use of the
## misspelled name in the sheet to the one it declares - the same rename the variable row's menu
## does, aimed at a name that was never a variable in the first place.
func _apply_variable_note_fix(note_row: EventRowData) -> void:
	if note_row == null or _current_sheet == null:
		return
	var wrong: String = ""
	var right: String = ""
	for span: SemanticSpan in note_row.spans:
		if not (span.metadata is Dictionary):
			continue
		var metadata: Dictionary = span.metadata as Dictionary
		wrong = str(metadata.get("variable_note_name", wrong))
		right = str(metadata.get("variable_note_to", right))
	if wrong.is_empty() or right.is_empty() or wrong == right:
		return
	var counted: Dictionary = {"renamed": 0}
	# One undo step, through the funnel every other mutation takes - nothing is held across it.
	if not _perform_undoable_sheet_edit(EventSheetL10n.translate("Use %s") % right, func() -> bool:
			counted["renamed"] = _rename_variable_references(wrong, right)
			return int(counted["renamed"]) > 0):
		_set_status(EventSheetL10n.translate("Nothing to rename."))
		return
	_set_status(EventSheetL10n.translate("Renamed %s to %s.") % [wrong, right])


## V10 - the Inspector's "Instance variables · N" lands here: the open sheet's own object popup,
## which is where the instance-variable table lives. Named on the dock (not reached through the
## popup helper) because the plugin calls it by name from outside the editor.
func open_instance_variables() -> void:
	open_object_properties(EventSheetVariableOwners.owner_of_sheet(_current_sheet))


## X15 - the four Hierarchy-pane gestures. Thin delegates so the pane, the canvas drop and any test
## all reach the same writer (dock/hierarchy_edits.gd).
func hierarchy_add_child(parent_label: String, child_label: String) -> void:
	if _ensure_sheet_for_editing():
		_hierarchy_edits.add_child_requested(parent_label, child_label)


func hierarchy_edit_flags(parent_label: String, child_label: String) -> void:
	if _ensure_sheet_for_editing():
		_hierarchy_edits.flags_requested(parent_label, child_label)


## X11 - the flags chip on an Add child ROW. The pane's gesture writes a new run; this one edits
## the run the chip sits on, in place.
func hierarchy_edit_row_flags(payload: Dictionary) -> void:
	if _ensure_sheet_for_editing():
		_hierarchy_edits.row_flags_requested(payload)


func hierarchy_unparent(child_label: String) -> void:
	if _ensure_sheet_for_editing():
		_hierarchy_edits.unparent_requested(child_label)


func hierarchy_edit_scene(child_label: String) -> void:
	_hierarchy_edits.edit_scene_requested(child_label)


## N10 - show only the rows that use one object, through the SAME filter lens the Filter button
## drives, so there is one notion of "the sheet is filtered" and one way out of it. Asking for the
## object that is already highlighted clears the filter, which is what makes the rail entry a toggle.
func highlight_object_rows(object_label: String) -> void:
	var wanted: String = object_label.strip_edges()
	if _viewport == null or wanted.is_empty():
		return
	if _viewport.lens_active() and _viewport.lens_query() == wanted:
		_apply_lens("")
		if _objects_panel != null:
			_objects_panel.tree.deselect_all()
		return
	_apply_lens(wanted)


## The Scene dock's "Show events", and the offer a scene selection makes: filter the sheet to one
## object, without the toggle-off half. Separate from highlight_object_rows for exactly that
## reason - arriving from another dock, "filter to this" must SET the filter, never clear a filter
## that happens to already be on that object.
func filter_events_to_object(object_label: String) -> void:
	var wanted: String = object_label.strip_edges()
	if _viewport == null or wanted.is_empty():
		return
	_apply_lens(wanted)
	if _objects_panel != null:
		_objects_panel.highlight_object(wanted)


## ── The Scene dock and the sheet on one selection (the two-way link) ───────────────────────────
## Built with the dock and torn down with it. The class holds the ping-pong guard; the dock only
## owns the lifetime and the menu toggle.
var _scene_link: EventSheetSceneSelectionLink = null


func _ensure_scene_link() -> EventSheetSceneSelectionLink:
	if _scene_link == null:
		_scene_link = EventSheetSceneSelectionLink.new(self)
	return _scene_link


## View ▸ Follow Scene Selection. Writes the project setting (so the choice outlives the session)
## and re-ticks the item from what the setting now says, rather than from what this code assumed.
func _toggle_follow_scene_selection(view_popup: PopupMenu) -> void:
	var now_on: bool = not EventSheetSceneSelectionLink.follow_enabled()
	ProjectSettings.set_setting(EventSheetSceneSelectionLink.FOLLOW_SETTING, now_on)
	ProjectSettings.save()
	if view_popup != null:
		# 9805 is View ▸ Follow Scene Selection; 9801 is Auto-apply while debugging.
		view_popup.set_item_checked(view_popup.get_item_index(9805),
			EventSheetSceneSelectionLink.follow_enabled())
	_set_status("Follow Scene Selection %s." % ("ON" if now_on else "OFF"))


## Q12 - HOVER previews before a click pins: the object's rows glow while the pointer rests on its
## bar entry and forget the moment it leaves, so a reader can sweep the bar without committing to
## anything. A preview never touches the filter lens, which is what makes it a preview.
func preview_object_rows(object_label: String) -> void:
	if _viewport == null:
		return
	_viewport.set_object_preview(object_label.strip_edges())


## Q1/Q12 - Add condition / Add action for ONE object: the picker opens with the object step already
## answered, so the row lands on that object instead of on whatever the reader picks next. The scope
## is the object's CLASS, because that is what the picker's verbs are grouped by.
func add_row_for_object(object_label: String, as_action: bool) -> void:
	if not _ensure_sheet_for_editing():
		return
	var entry: Dictionary = EventSheetObjectProperties.find_entry(_current_sheet, object_label)
	var context: Dictionary = {
		"object_scope": str(entry.get("class", "")).strip_edges(),
		"object_label": object_label
	}
	var selected_resource: Resource = _active_view().get_selected_context().get("source_resource", null)
	if as_action:
		_ace_picker.open("append_action" if selected_resource is EventRow else "new_event",
			false, selected_resource, context)
		return
	_ace_picker.open("append_condition" if selected_resource is EventRow else "new_condition_event",
		false, selected_resource, context)


## Q12 - an object dragged off the Object bar and dropped on the canvas: the sheet's way of "start
## using an object". The drop selects where it lands, then opens the picker already scoped to that
## object - Add action when it landed in an event's action lane, Add condition anywhere else.
func apply_object_bar_drop(object_label: String, target_event: Resource, on_action_lane: bool) -> void:
	if not _ensure_sheet_for_editing():
		return
	if target_event != null and _active_view() != null:
		_active_view().select_resource(target_event)
	# X25 - an object the reader marked `secret` in its properties has one event worth writing, so
	# dropping it OFFERS that event first. An offer, not a rule: dismissing the dialog falls through
	# to the picker the drop has always opened, and nothing is written until the reader says yes.
	if EventSheetObjectProperties.is_secret(_source_path_for_secrets(), object_label):
		_open_secret_counter_offer(object_label, on_action_lane)
		return
	# Y16 - the same offer for a door: a body the reader named a key for wants the event that TRIES
	# it when the player walks in, which is the one row that both opens it and refuses it.
	if not EventSheetObjectProperties.needs_key_of(_source_path_for_secrets(), object_label).is_empty():
		_open_locked_door_offer(object_label, on_action_lane)
		return
	# Y11 - the same offer for the second mark: an area marked `water` has two events worth writing,
	# the way in and the way out, and dropping it offers the pair before the picker.
	if EventSheetObjectProperties.is_water(_source_path_for_secrets(), object_label):
		_open_water_rows_offer(object_label, on_action_lane)
		return
	add_row_for_object(object_label, on_action_lane)


## The file the secret marks are keyed against - the sheet being edited, matching the source path
## the object popup passes when it writes the mark.
func _source_path_for_secrets() -> String:
	return str(_current_sheet.resource_path) if _current_sheet != null else ""


var _secret_offer_dialog: ConfirmationDialog = null
var _secret_offer_line: Label = null
var _secret_offer_label: String = ""
var _secret_offer_on_action_lane: bool = false


## The offer a secret area's drop opens: one sentence saying what the event would be, "Count it" to
## add it, and Cancel to get the ordinary drop instead. Built with the shared popup helpers so it
## wears the same card look as every other dialog here.
func _open_secret_counter_offer(object_label: String, on_action_lane: bool) -> void:
	_secret_offer_label = object_label
	_secret_offer_on_action_lane = on_action_lane
	if _secret_offer_dialog == null:
		_secret_offer_dialog = ConfirmationDialog.new()
		_secret_offer_dialog.title = EventSheetL10n.translate("Count This Secret")
		_secret_offer_dialog.ok_button_text = EventSheetL10n.translate("Count it")
		_secret_offer_dialog.get_cancel_button().text = EventSheetL10n.translate("Just add a row")
		_secret_offer_dialog.confirmed.connect(_on_secret_counter_offer_accepted)
		_secret_offer_dialog.canceled.connect(func() -> void:
			add_row_for_object(_secret_offer_label, _secret_offer_on_action_lane))
		var body: VBoxContainer = EventSheetPopupUI.form_box()
		_secret_offer_line = EventSheetPopupUI.hint_label("")
		body.add_child(_secret_offer_line)
		_secret_offer_dialog.add_child(EventSheetPopupUI.margined(body))
		add_child(_secret_offer_dialog)
		EventSheetL10n.apply_to(_secret_offer_dialog)
	# The dialog is built once and reused, so the object it is about is written on it EVERY open.
	_secret_offer_line.text = EventSheetL10n.translate(
		"%s is marked a secret. Add the event that counts it the first time the player walks in?") \
		% object_label
	_secret_offer_dialog.popup_centered(Vector2i(460, 150))


## "Count it": the secret's own walked-into event with the shipped Mark Secret Found row in it, plus
## the list it counts into when the sheet does not declare one yet. One undo step.
func _on_secret_counter_offer_accepted() -> void:
	var object_label: String = _secret_offer_label
	var entry: Dictionary = EventSheetObjectProperties.find_entry(_current_sheet, object_label)
	var host_class: String = str(entry.get("class", "")).strip_edges()
	var changed: bool = _perform_undoable_sheet_edit("Count Secret", func() -> bool:
		if not _current_sheet.variables.has(EventSheetStarterEvents.SECRETS_VARIABLE):
			_current_sheet.variables[EventSheetStarterEvents.SECRETS_VARIABLE] = \
				EventSheetStarterEvents.secrets_variable_entry()
		_current_sheet.events.append(EventSheetStarterEvents.secret_counter_event(
			object_label, host_class if not host_class.is_empty() else "Area3D"))
		return true)
	if not changed:
		return
	_refresh_after_edit()
	_mark_dirty(EventSheetL10n.translate("Counting %s as a secret.") % object_label)


var _door_offer_dialog: ConfirmationDialog = null
var _door_offer_line: Label = null
var _door_offer_label: String = ""
var _door_offer_on_action_lane: bool = false


## Y16. The offer a locked door's drop opens, built exactly like the secret one above: one sentence
## naming the key it wants, "Add the door event" to write it, and Cancel to get the ordinary drop.
func _open_locked_door_offer(object_label: String, on_action_lane: bool) -> void:
	_door_offer_label = object_label
	_door_offer_on_action_lane = on_action_lane
	if _door_offer_dialog == null:
		_door_offer_dialog = ConfirmationDialog.new()
		_door_offer_dialog.title = EventSheetL10n.translate("Try This Door")
		_door_offer_dialog.ok_button_text = EventSheetL10n.translate("Add the door event")
		_door_offer_dialog.get_cancel_button().text = EventSheetL10n.translate("Just add a row")
		_door_offer_dialog.confirmed.connect(_on_locked_door_offer_accepted)
		_door_offer_dialog.canceled.connect(func() -> void:
			add_row_for_object(_door_offer_label, _door_offer_on_action_lane))
		var body: VBoxContainer = EventSheetPopupUI.form_box()
		_door_offer_line = EventSheetPopupUI.hint_label("")
		body.add_child(_door_offer_line)
		_door_offer_dialog.add_child(EventSheetPopupUI.margined(body))
		add_child(_door_offer_dialog)
		EventSheetL10n.apply_to(_door_offer_dialog)
	# The dialog is built once and reused, so the door it is about is written on it EVERY open.
	_door_offer_line.text = EventSheetL10n.translate(
		"%s wants the %s key. Add the event that tries it when the player walks in?") \
		% [object_label, EventSheetObjectProperties.needs_key_of(_source_path_for_secrets(), object_label)]
	_door_offer_dialog.popup_centered(Vector2i(460, 150))


## "Add the door event": the door's own walked-into event with the shipped Try Door row in it, plus
## the key list it reads when the sheet does not declare one yet. One undo step.
func _on_locked_door_offer_accepted() -> void:
	var object_label: String = _door_offer_label
	var entry: Dictionary = EventSheetObjectProperties.find_entry(_current_sheet, object_label)
	var host_class: String = str(entry.get("class", "")).strip_edges()
	var changed: bool = _perform_undoable_sheet_edit("Add Door Event", func() -> bool:
		if not _current_sheet.variables.has(EventSheetStarterEvents.KEYS_VARIABLE):
			_current_sheet.variables[EventSheetStarterEvents.KEYS_VARIABLE] = \
				EventSheetStarterEvents.keys_variable_entry()
		_current_sheet.events.append(EventSheetStarterEvents.locked_door_event(
			object_label, host_class if not host_class.is_empty() else "StaticBody3D"))
		return true)
	if not changed:
		return
	_refresh_after_edit()
	_mark_dirty(EventSheetL10n.translate("Trying %s when the player walks in.") % object_label)


var _water_offer_dialog: ConfirmationDialog = null
var _water_offer_line: Label = null
var _water_offer_label: String = ""
var _water_offer_on_action_lane: bool = false


## Y11. The offer a water volume's drop opens: one sentence saying what the two rows would be, "Add
## them" to write the pair, and Cancel to get the ordinary drop instead. Same shape as the secret
## offer, built with the shared popup helpers.
func _open_water_rows_offer(object_label: String, on_action_lane: bool) -> void:
	_water_offer_label = object_label
	_water_offer_on_action_lane = on_action_lane
	if _water_offer_dialog == null:
		_water_offer_dialog = ConfirmationDialog.new()
		_water_offer_dialog.title = EventSheetL10n.translate("Add The Water Rows")
		_water_offer_dialog.ok_button_text = EventSheetL10n.translate("Add them")
		_water_offer_dialog.get_cancel_button().text = EventSheetL10n.translate("Just add a row")
		_water_offer_dialog.confirmed.connect(_on_water_rows_offer_accepted)
		_water_offer_dialog.canceled.connect(func() -> void:
			add_row_for_object(_water_offer_label, _water_offer_on_action_lane))
		var body: VBoxContainer = EventSheetPopupUI.form_box()
		_water_offer_line = EventSheetPopupUI.hint_label("")
		body.add_child(_water_offer_line)
		_water_offer_dialog.add_child(EventSheetPopupUI.margined(body))
		add_child(_water_offer_dialog)
		EventSheetL10n.apply_to(_water_offer_dialog)
	# The dialog is built once and reused, so the object it is about is written on it EVERY open.
	_water_offer_line.text = EventSheetL10n.translate(
		"%s is marked water. Add the two rows that raise the flag on the way in and lower it on the way out?") \
		% object_label
	_water_offer_dialog.popup_centered(Vector2i(460, 150))


## "Add them": the two events that hold the sheet's in-water flag, plus the flag itself when the
## sheet does not declare one yet. One undo step.
func _on_water_rows_offer_accepted() -> void:
	var object_label: String = _water_offer_label
	var entry: Dictionary = EventSheetObjectProperties.find_entry(_current_sheet, object_label)
	var host_class: String = str(entry.get("class", "")).strip_edges()
	var changed: bool = _perform_undoable_sheet_edit("Add Water Rows", func() -> bool:
		if not _current_sheet.variables.has(EventSheetStarterEvents.WATER_VARIABLE):
			_current_sheet.variables[EventSheetStarterEvents.WATER_VARIABLE] = \
				EventSheetStarterEvents.water_variable_entry()
		for event: EventRow in EventSheetStarterEvents.water_volume_events(
				object_label, host_class if not host_class.is_empty() else "Area3D"):
			_current_sheet.events.append(event)
		return true)
	if not changed:
		return
	_refresh_after_edit()
	_mark_dirty(EventSheetL10n.translate("Marking %s as water.") % object_label)


## T13 - something dragged off the PROJECT bar and dropped on the canvas. The bar already decided what
## dropping it MEANS (it refuses the drag for anything the sheet has no gesture for); this turns that
## into the picker the reader would have opened by hand, with the object step already answered:
##   a class or base class -> start an event on it
##   a sound               -> a Play sound action
##   a scene               -> a Go to layout action
func apply_project_entry_drop(payload: Dictionary, target_event: Resource) -> void:
	if not _ensure_sheet_for_editing():
		return
	if target_event != null and _active_view() != null:
		_active_view().select_resource(target_event)
	var label: String = str(payload.get("label", "")).strip_edges()
	match str(payload.get("intent", "")):
		"start_event":
			# The class IS the object scope the picker groups its verbs by, so the entry's own name
			# answers the object step outright.
			_ace_picker.open("new_event", false, null, {"object_scope": label, "object_label": label})
			_set_status("Starting an event on %s." % label)
		"play_sound":
			_quick_add("play sound %s" % str(payload.get("path", "")))
			_set_status("Added a Play sound action for %s." % label)
		"go_to_layout":
			_quick_add("change scene %s" % str(payload.get("path", "")))
			_set_status("Added a Go to layout action for %s." % label)


## R23 - an Input Map action dragged off the bar's INPUT section and dropped on the canvas. An action
## is not an object: there is exactly one thing a reader means by dropping "jump" on a sheet, so this
## writes that event outright instead of opening the picker. It lands after the event it was dropped
## on, or at the end when it was dropped on empty canvas.
func apply_input_action_drop(action_name: String, target_event: Resource) -> void:
	if not _ensure_sheet_for_editing():
		return
	var clean: String = action_name.strip_edges()
	if clean.is_empty():
		return
	var changed: bool = _perform_undoable_sheet_edit("Add Input Action Event", func() -> bool:
		return _insert_input_action_event(clean, target_event))
	if changed:
		_set_status("Added On %s pressed." % clean)


## The event the drop writes: the sheet's own "On <action> pressed" condition, nothing else, so what
## lands is exactly what the picker's Add condition would have produced.
func _insert_input_action_event(action_name: String, target_event: Resource) -> bool:
	var event_row: EventRow = EventRow.new()
	var pressed: ACECondition = ACECondition.new()
	pressed.provider_id = "Core"
	pressed.ace_id = "IsActionJustPressed"
	pressed.codegen_template = "Input.is_action_just_pressed(&{action})"
	pressed.params = {"action": "\"%s\"" % action_name}
	event_row.conditions.append(pressed)
	var at: int = _current_sheet.events.find(target_event)
	if at >= 0:
		_current_sheet.events.insert(at + 1, event_row)
	else:
		_current_sheet.events.append(event_row)
	return true


## Q1 - open the file that says what an object IS, as a sheet. Goes through the same navigation the
## Include bar's "open as a sheet" uses, so Alt+Left walks back the way a reader expects.
func open_object_file_as_sheet(script_path: String) -> void:
	var path: String = script_path.strip_edges()
	if path.is_empty():
		_set_status("This object has no script of its own to open.", true)
		return
	_navigate.record_current()
	_navigate.open_or_focus(path)


## N10 - reveal an object in the Godot scene dock. Only meaningful while the scene holding it is the
## one open in the editor, which is why the popup's button is disabled otherwise; this still guards,
## because a scene can be closed between the popup opening and the button being pressed.
func select_object_in_scene(node_path: String) -> void:
	var path: String = node_path.strip_edges().trim_prefix("$").trim_prefix("%")
	if path.is_empty() or not Engine.has_singleton("EditorInterface"):
		return
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	if edited_root == null:
		_set_status("Open the scene this object lives in to select it there.", true)
		return
	var found: Node = edited_root.get_node_or_null(NodePath(path))
	if found == null:
		found = edited_root.find_child(path.get_file(), true, false)
	if found == null:
		_set_status("No node named %s in the open scene." % path, true)
		return
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(found)


## N10 - open the .gd behind the sheet at the first line that names the object, so "Show in code"
## lands ON the object rather than at the top of the file.
func show_object_in_code(object_label: String) -> void:
	if _current_sheet == null or _current_sheet.external_source_path.is_empty():
		_set_status("This sheet has no .gd file behind it - Save As… a .gd to read its code.", true)
		return
	_open_gdscript_path_in_godot(_current_sheet.external_source_path,
		_first_line_naming(_current_sheet.external_source_path, object_label))


## The 1-based line a file first names an object on, or -1 when it never does (or cannot be read).
static func _first_line_naming(source_path: String, object_label: String) -> int:
	var wanted: String = object_label.strip_edges()
	if source_path.is_empty() or wanted.is_empty():
		return -1
	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return -1
	var line_number: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_number += 1
		# Comment lines are skipped for the same reason the census skips them: prose that MENTIONS
		# the object is not the line a reader asked to be taken to.
		if not line.strip_edges().begins_with("#") and line.contains(wanted):
			file.close()
			return line_number
	file.close()
	return -1


## The popup's "Edit…": the existing verb dialog, pre-filled - the ONE place a verb's name, category,
## description, parameters and featured flag are edited, reached from here instead of duplicated.
func edit_function(event_function: Resource) -> void:
	if event_function == null:
		return
	_function_dialog_glue._open_function_dialog_for(event_function)


## The popup's "Open guide": the guide of the pack the open sheet came from, through the same public
## "addon:<pack>" doc id the picker's read-more link uses.
func open_pack_guide_for_sheet() -> bool:
	if _current_sheet == null:
		return false
	# The pack a .gd-backed sheet belongs to IS the folder it was opened from - no registry lookup
	# needed, and it answers for a pack whose provider has not been scanned yet.
	var pack_dir: String = _current_sheet.external_source_path.get_base_dir()
	if not pack_dir.begins_with("res://eventsheet_addons/"):
		pack_dir = ""
	if pack_dir.is_empty():
		_set_status("This sheet is not part of an addon pack, so it has no pack guide.", true)
		return false
	return EventSheets.open_docs("addon:%s" % pack_dir)


## The popup's "Show in code": the verb's own function in Godot's script editor. Falls back to the top
## of the file when the line cannot be found - landing in the right file always beats not opening.
func show_verb_in_code(event_function: Resource) -> void:
	if _current_sheet == null or _current_sheet.external_source_path.is_empty():
		_set_status("This sheet has no .gd file behind it - Save As… a .gd to read its code.", true)
		return
	var verb: EventFunction = event_function as EventFunction
	var line: int = -1
	if verb != null:
		line = EventSheetVerbProperties.function_line_in(_current_sheet.external_source_path, verb.function_name)
	_open_gdscript_path_in_godot(_current_sheet.external_source_path, line)


# ── Welcome (Tools → Welcome…) - the window lives in dock/welcome_window.gd ──
func show_welcome_if_first_run() -> void:  # plugin calls this at editor startup (first run pops it)
	_welcome.show_if_first_run()


func show_welcome() -> void:  # Tools menu (id 13) + command palette ("Open Welcome")
	_welcome.show()


func start_tour() -> void:  # Tools menu (id 17) + the Welcome window's tour button
	_tour.start()


func toggle_behavior_preview() -> void:  # Tools menu (id 18) + command palette
	_behavior_preview.toggle()

# ── Loop closers: attach the behavior where you're looking, run the scene that
# uses this sheet (core lookups are headless; playing needs the editor) ───────────────


func _attach_behavior_to_selection() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var selected: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	var result: Dictionary = EventSheetAuthorLoop.attach_behavior(_current_sheet, selected[0] if not selected.is_empty() else null)
	if bool(result.get("ok", false)):
		EditorInterface.mark_scene_as_unsaved()
	_set_status(str(result.get("message", "")), not bool(result.get("ok", false)))


# ── Run Scene ("sheet → playing game") - bodies in EventSheetAuthorActions (dock/author_actions.gd) ──
func _run_from_sheet() -> void:  # command_palette.gd + menu_bar.gd Run-Scene button + tedium_test
	_author_actions._run_from_sheet()


func _run_target_script_path() -> String:  # godot_workflow_test
	return _author_actions._run_target_script_path()


# ── Session restore (open tabs survive an editor restart) → event_sheet_session_store.gd ──
func _persist_session() -> void:  # startup, tab edits, "Edit Events" unlock + session tests
	_session.persist()


func _restore_session() -> void:  # called once on setup
	_session.restore()


# ── Row snippets (Save Selection / Insert) - bodies in EventSheetAuthorActions
# (dock/author_actions.gd). _insert_snippet_path reaches _paste_snippet_text (which STAYS on the
# dock, in the copy/paste cluster) via _dock. ─────────────
func _open_save_snippet_dialog() -> void:  # in-file row context-menu dispatcher
	_author_actions._open_save_snippet_dialog()


func _save_selection_snippet_named(snippet_name: String) -> String:  # testable save core
	return _author_actions._save_selection_snippet_named(snippet_name)


func _open_insert_snippet() -> void:  # in-file context-menu dispatchers
	_author_actions._open_insert_snippet()


func _insert_snippet_path(snippet_path: String) -> void:  # tedium_test
	_author_actions._insert_snippet_path(snippet_path)


# ── Context-driven row/ACE edit ops - bodies in EventSheetRowEditOps (dock/row_edit_ops.gd).
# The four dispatchers below (_on_*_context_menu_id_pressed) call these by bare name, context_menus.gd
# reads the is-disabled / is-negated probes via _dock.<name>, multi_view_manager wires
# _delete_selected_content, and the tests call the enable/indent/outdent/insert ops directly - so the
# dock keeps a thin one-line delegate (original name + signature) for each. The ops read the shared
# _context_row / _context_hit state (which stays on this dock) back through _dock inside the helper.
func _delete_context_ace() -> void:
	_row_edit_ops._delete_context_ace()


func _toggle_context_condition_inversion() -> void:
	_row_edit_ops._toggle_context_condition_inversion()


func _context_ace_resource(lane: String) -> Resource:
	return _row_edit_ops._context_ace_resource(lane)


func _context_ace_is_disabled() -> bool:
	return _row_edit_ops._context_ace_is_disabled()


func _toggle_context_ace_enabled() -> void:
	_row_edit_ops._toggle_context_ace_enabled()


func _toggle_selected_enabled() -> void:
	_row_edit_ops._toggle_selected_enabled()


func _context_row_is_disabled() -> bool:
	return _row_edit_ops._context_row_is_disabled()


func _toggle_context_row_enabled() -> void:
	_row_edit_ops._toggle_context_row_enabled()


func _toggle_context_condition_block() -> void:
	_row_edit_ops._toggle_context_condition_block()


func _set_context_else_mode(mode: int) -> void:
	_row_edit_ops._set_context_else_mode(mode)


func _toggle_context_group_fold() -> void:
	_row_edit_ops._toggle_context_group_fold()


func _delete_selected_content() -> void:
	_row_edit_ops._delete_selected_content()


func _delete_selected_rows() -> void:
	_row_edit_ops._delete_selected_rows()


func _insert_child_event_for_context_row() -> void:
	_row_edit_ops._insert_child_event_for_context_row()


func _insert_child_comment_for_context_row() -> void:
	_row_edit_ops._insert_child_comment_for_context_row()


# ── Single-key reflexes: B blank sub-event · I invert · R replace ─────────────
## Seeds the context-menu state (_context_row/_context_hit) from the CURRENT selection, so the
## single-key reflexes reuse the right-click handlers verbatim - one behavior, two entry points.
## False when no row is selected.
func _seed_context_from_selection() -> bool:
	var view: EventSheetViewport = _active_view()
	if view == null:
		return false
	var context: Dictionary = view.get_selected_context()
	if context.get("row_data") == null:
		return false
	_context_row = context.get("row_data")
	_context_hit = {"span_index": int(context.get("span_index", -1)), "span_metadata": context.get("span_metadata", {})}
	return true


## B - add a blank sub-event under the selected event (the context menu's Add Sub-Event, keyed).
func _on_add_blank_subevent_key() -> void:
	if not _seed_context_from_selection() or _context_row == null or not (_context_row.source_resource is EventRow):
		_set_status("Select an event first - B adds a blank sub-event under it.", true)
		return
	_insert_child_event_for_context_row()


## Add ▸ Make 'Or' block: the right-click command, driven from the SELECTION rather than a
## right-clicked row, so the Add menu and the row menu do the same thing in the same words.
## On an opened .gd this rewrites the event's joined condition (`a and b` <-> `a or b`) and
## nothing else in the file - the mode is what the emitter joins the conditions with.
func _make_or_block_from_selection() -> void:
	if not _seed_context_from_selection() or _context_row == null or not (_context_row.source_resource is EventRow):
		_set_status("Select an event first - an 'Or' block joins that event's conditions.", true)
		return
	_toggle_context_condition_block()


## Add ▸ Add 'Else': the same command as the row menu's, driven from the selection.
func _make_else_from_selection() -> void:
	if not _seed_context_from_selection() or _context_row == null or not (_context_row.source_resource is EventRow):
		_set_status("Select an event first - 'Else' runs when the event above it did not.", true)
		return
	_set_context_else_mode(EventRow.ElseMode.ELSE)


## S - add a picker-backed sub-event under the selected event (the event-sheet add-sub-event key).
func _on_add_sub_condition_key() -> void:
	if not _seed_context_from_selection() or _context_row == null or not (_context_row.source_resource is EventRow):
		_set_status("Select an event first - S adds a sub-event under it.", true)
		return
	_open_sub_condition_picker_for_context_row()


## I - invert the selected condition (click its cell, then press I; compiles as `not (…)`).
func _on_invert_condition_key() -> void:
	var kind: String = ""
	if _seed_context_from_selection():
		kind = str((_context_hit.get("span_metadata", {}) as Dictionary).get("kind", ""))
	if kind == "trigger":
		_set_status("Triggers can't be inverted - there's no \"not On X\".", true)
		return
	if kind != "condition":
		_set_status("Select a condition cell first - I inverts it.", true)
		return
	_toggle_context_condition_inversion()


## R - replace the selected trigger / condition / action via the picker, pre-selected on the current
## ACE and keeping params whose ids match (the context menu's Replace, keyed).
func _on_replace_ace_key() -> void:
	if not _seed_context_from_selection() or _context_row == null or not (_context_row.source_resource is EventRow):
		_set_status("Select a trigger, condition, or action cell first - R replaces it.", true)
		return
	var replace_context: Dictionary = _build_ace_edit_context(_context_row.source_resource as EventRow, int(_context_hit.get("span_index", -1)), _context_hit.get("span_metadata", {}))
	if replace_context.is_empty():
		_set_status("Select a trigger, condition, or action cell first - R replaces it.", true)
		return
	var replace_def: ACEDefinition = replace_context.get("definition", null)
	if replace_def != null:
		replace_context["preselect_ace_id"] = replace_def.id
	_ace_picker.open(str(replace_context.get("mode", "replace_condition")), false, _context_row.source_resource, replace_context)


func _open_sub_condition_picker_for_context_row() -> void:
	_row_edit_ops._open_sub_condition_picker_for_context_row()


func _indent_selected_event() -> bool:
	return _row_edit_ops._indent_selected_event()


func _outdent_selected_event() -> bool:
	return _row_edit_ops._outdent_selected_event()


func _insert_context_row_below(resource_entry: Resource, message: String) -> void:
	_row_edit_ops._insert_context_row_below(resource_entry, message)


func _insert_context_row_above(resource_entry: Resource, message: String) -> void:
	_row_edit_ops._insert_context_row_above(resource_entry, message)


## Cut = Copy + Delete: the copy is clipboard-only state, so the delete is the ONE undo step
## (undoing a Cut restores the rows and the clipboard still holds the copy - the event-sheet behaviour).
func _cut_selected_rows() -> void:
	_on_copy_requested()
	_delete_selected_rows()


func _copy_selection_as_text() -> void:
	_clipboard_glue._copy_selection_as_text()


func _context_condition_is_negated() -> bool:
	return _row_edit_ops._context_condition_is_negated()

# ── Per-ACE comments (condition/action notes) ──────────────────────────────────────
var _ace_comment_dialog: ConfirmationDialog = null
var _ace_comment_edit: LineEdit = null
var _ace_comment_target: Resource = null


## Event-sheet-style per-condition/action note: shown dimmed after the ACE text in the sheet.
func _open_ace_comment_dialog(target: Resource) -> void:
	if target == null:
		_set_status("Right-click a condition or action to comment it.", true)
		return
	if _ace_comment_dialog == null:
		_ace_comment_dialog = ConfirmationDialog.new()
		_ace_comment_dialog.title = "Row Comment"
		_ace_comment_edit = LineEdit.new()
		_ace_comment_edit.placeholder_text = "Why this condition/action exists…"
		_ace_comment_edit.custom_minimum_size = Vector2(360.0, 0.0)
		var body_box: VBoxContainer = EventSheetPopupUI.form_box()
		body_box.add_child(_ace_comment_edit)
		_ace_comment_dialog.add_child(EventSheetPopupUI.margined(body_box))
		_ace_comment_dialog.confirmed.connect(_on_ace_comment_confirmed)
		add_child(_ace_comment_dialog)
	_ace_comment_target = target
	_ace_comment_edit.text = str(target.get("comment"))
	_ace_comment_dialog.popup_centered(Vector2i(420, 110))


func _on_ace_comment_confirmed() -> void:
	if _ace_comment_target == null:
		return
	var target: Resource = _ace_comment_target
	var new_comment: String = _ace_comment_edit.text.strip_edges()
	var changed: bool = _perform_undoable_sheet_edit("Edit Cell Note", func() -> bool:
		target.set("comment", new_comment)
		return true
	)
	if changed:
		_refresh_after_edit()
		_mark_dirty("Cell note saved.")


# ── Starter templates ("new from template") - menu + sheet construction in dock/starter_templates.gd ──
func _open_template_menu() -> void:  # New-Sheet shortcut (id 0) + command palette + Welcome button
	_starter.open_menu()


func _on_viewport_selection_changed(_row_data: EventRowData) -> void:
	_update_row_address_status()
	_update_code_panel_highlight()
	_follow_selection_in_manual()
	# The Scene dock's half of the two-way link: the node this row is about is selected there (and
	# in the 2D view), so the two surfaces stay on one selection.
	_ensure_scene_link().follow_row(_row_data)
	if _exposed_node != null and _viewport != null:
		_exposed_node.set_row_context(_active_view().get_selected_ace_resource())
	_properties_bar.refresh()


## V12 - writes a variable's initial value from the row's own inline field, through the undo funnel.
## Refuses a literal the declared type cannot hold and says why, because the row must never show a
## value the file does not have. Handles both kinds of declaration: a sheet-level entry in the
## variables dictionary, and a `var` line placed in the event list.
func _apply_variable_value_edit(row_data: EventRowData, new_value: String) -> void:
	if row_data == null or row_data.spans.is_empty():
		return
	var metadata: Dictionary = row_data.spans[0].metadata if row_data.spans[0].metadata is Dictionary else {}
	var var_name: String = str(metadata.get("variable_name", "")).strip_edges()
	var declared_type: String = ""
	for span: SemanticSpan in row_data.spans:
		var span_meta: Dictionary = span.metadata if span.metadata is Dictionary else {}
		if bool(span_meta.get("variable_value_span", false)):
			declared_type = str(span_meta.get("variable_type_name", ""))
	if var_name.is_empty():
		return
	if not EventSheetVariableSentence.value_fits(declared_type, new_value):
		_set_status(EventSheetL10n.translate("%s is a %s - it cannot hold %s.") % [
			var_name, ViewportRowBuilder.friendly_type_word(declared_type), new_value], true)
		return
	var declaring: LocalVariable = row_data.source_resource as LocalVariable
	var written: bool = _perform_undoable_sheet_edit("Edit Variable Value", func() -> bool:
		if declaring != null:
			declaring.default_value = str(new_value) if declaring.expression_default or declaring.inferred_type \
				else EventSheetVariableSentence.parse_value(declared_type, new_value)
			return true
		if _current_sheet == null or not _current_sheet.variables.has(var_name):
			return false
		var descriptor: Dictionary = (_current_sheet.variables[var_name] as Dictionary).duplicate(true)
		descriptor["default"] = EventSheetVariableSentence.parse_value(declared_type, new_value)
		_current_sheet.variables[var_name] = descriptor
		return true
	)
	if written:
		_mark_dirty(EventSheetL10n.translate("%s starts at %s.") % [var_name, new_value])


func _on_viewport_span_edit_requested(row_data: EventRowData, edit_kind: String, old_value: String, new_value: String) -> void:
	if row_data == null:
		return
	if old_value == new_value:
		return
	# The head's `##` band is an inert row (a band owns no resource of its own), so it is
	# answered BEFORE the source-resource guard: the block it rewrites travels in span metadata.
	if edit_kind == "sheet_description":
		_head_actions.apply_band_value(EventSheetHeadBands.BAND_DESCRIPTION, new_value)
		return
	if row_data.source_resource == null:
		return
	if edit_kind.begins_with("decl_entry_line:"):
		var entry_updated: bool = _perform_undoable_sheet_edit("Edit Entry", func() -> bool:
			return EventSheetViewport._apply_decl_entry_edit(row_data.source_resource, edit_kind, new_value)
		)
		if entry_updated:
			_mark_dirty("Updated entry.")
		return
	# W12 - the same edit for a table or list written as a VALUE, whose entries are still one
	# verbatim row each: the chip rewrites that row's line and leaves every other line alone.
	if edit_kind.begins_with("literal_entry_line:"):
		var literal_updated: bool = _perform_undoable_sheet_edit("Edit Entry", func() -> bool:
			return EventSheetValueLiteralRows.apply_entry_edit(row_data.source_resource, edit_kind, new_value)
		)
		if literal_updated:
			_mark_dirty("Updated entry.")
		return
	# V12 - a variable's value, edited in place on its row. The type word beside it is the guide rail:
	# a literal that does not fit is refused here rather than written as something the row does not
	# say (the field already turned amber while it was being typed).
	if edit_kind == "variable_value":
		_apply_variable_value_edit(row_data, new_value)
		return
	var updated: bool = _perform_undoable_sheet_edit("Edit Row Text", func() -> bool:
		match edit_kind:
			"group_name":
				if row_data.source_resource is EventGroup:
					var group: EventGroup = row_data.source_resource as EventGroup
					group.name = new_value
					group.group_name = new_value
					return true
			"comment_text":
				if row_data.source_resource is CommentRow:
					(row_data.source_resource as CommentRow).text = new_value
					return true
			"group_description":
				if row_data.source_resource is EventGroup:
					(row_data.source_resource as EventGroup).description = new_value
					return true
			"region_name":
				if EventSheetRegionFacts.is_opening_fence(row_data.source_resource):
					(row_data.source_resource as CustomBlockRow).fields["label"] = new_value.strip_edges()
					return true
			"event_comment":
				if row_data.source_resource is EventRow:
					(row_data.source_resource as EventRow).comment = new_value
					return true
			# A published verb's picker metadata, edited inline on its row. The empty string is a valid
			# new value (it clears the field, so the row and compiler fall back to the function name / no
			# annotation). Each case compares against the CURRENT field, not old_value, because an empty
			# field draws a "+ ..." placeholder whose span text is not the value - so the outer
			# old==new guard cannot see a genuine no-op, and a spurious change would rewrite an opened .gd.
			"verb_display_name":
				if row_data.source_resource is EventFunction:
					var fn_name: EventFunction = row_data.source_resource as EventFunction
					if fn_name.ace_display_name == new_value.strip_edges():
						return false
					fn_name.ace_display_name = new_value.strip_edges()
					return true
			"verb_description":
				if row_data.source_resource is EventFunction:
					var fn_desc: EventFunction = row_data.source_resource as EventFunction
					if fn_desc.description == new_value.strip_edges():
						return false
					fn_desc.description = new_value.strip_edges()
					return true
			"verb_category":
				if row_data.source_resource is EventFunction:
					var fn_cat: EventFunction = row_data.source_resource as EventFunction
					if fn_cat.ace_category == new_value.strip_edges():
						return false
					fn_cat.ace_category = new_value.strip_edges()
					return true
		return false
	)
	if updated:
		_mark_dirty("Updated row text.")


func _collect_event_row_options() -> Array[Dictionary]:
	return _queries.collect_event_row_options()



func _collect_event_rows_recursive(resources: Array, output: Array[EventRow]) -> void:
	_queries.collect_event_rows_recursive(resources, output)



func _format_event_target_label(event_row: EventRow) -> String:
	return _queries.format_event_target_label(event_row)



func _find_event_row_by_uid(event_uid: String) -> EventRow:
	return _queries.find_event_row_by_uid(event_uid)



func _type_from_name(type_name: String) -> int:
	return _queries.type_from_name(type_name)



func _event_row_uses_or_mode(event_row: EventRow) -> bool:
	return _queries.event_row_uses_or_mode(event_row)



func _event_rows_use_or_mode(event_rows: Array[EventRow]) -> bool:
	return _queries.event_rows_use_or_mode(event_rows)



func _get_selected_rows_from_context() -> Array[EventRowData]:
	return _queries.get_selected_rows_from_context()



func _get_selected_event_rows_from_context() -> Array[EventRow]:
	return _queries.get_selected_event_rows_from_context()



func _build_ace_edit_context(event_row: EventRow, span_index: int, metadata: Dictionary) -> Dictionary:
	return _queries.build_ace_edit_context(event_row, span_index, metadata)



func _find_definition(provider_id: String, ace_id: String) -> ACEDefinition:
	return _queries.find_definition(provider_id, ace_id)



func _find_first_event_row_resource() -> EventRow:
	return _queries.find_first_event_row_resource()



func _select_first_event_row() -> void:
	_queries.select_first_event_row()



func _surround_selection_with_region() -> void:
	_input_dispatch.surround_selection_with_region()



func _refresh_after_edit() -> void:
	if _viewport == null:
		return
	_viewport.set_sheet(_current_sheet)
	_sync_split_sheet()
	_theme_manager._sync_active_theme_binding()
	_refresh_exposed_node()
	_refresh_code_panel()
	_refresh_anatomy_panel()
	_refresh_functions_list()
	_properties_bar.refresh()
	_apply_minimap_pref()


# Live-reload binding to the active theme .tres → dock/theme_manager.gd. Called from _activate_tab /
# _refresh_after_edit (via _theme_manager._sync_active_theme_binding directly); the delegate stays for
# any external caller reaching the original name.
func _sync_active_theme_binding() -> void:
	_theme_manager._sync_active_theme_binding()


func _mark_dirty(message: String) -> void:
	_dirty = true
	_refresh_title_strip()
	_set_status("%s%s" % [message, " *" if _dirty else ""])
	# Live edit (V8): an edit made while a game is running is one keystroke from being in it. The
	# offer re-words itself here rather than on a timer, so it is never stale and never guessed at.
	_live_edit_bar.refresh()
	if EventSheetLiveEdit.is_running() and EventSheetLiveEdit.auto_apply_enabled():
		_live_edit_bar.apply()


func _set_status(text: String, is_error: bool = false) -> void:
	if _status_label == null:
		return
	# A leading ⚠ marks errors textually (not just by colour - colour-blind-safe and more salient so
	# a "won't compile / save failed" isn't missed). The full text is on the tooltip since the status
	# bar truncates long messages.
	_status_label.text = ("⚠  %s" % text) if is_error else text
	_status_label.tooltip_text = text
	_status_label.modulate = EventSheetActiveTheme.chrome().status_error_color if is_error else EventSheetActiveTheme.chrome().status_text_color
	# Tiered presence: an error keeps its full-strength red until something replaces it, while an
	# informational message fades to muted after a few seconds - a stale tip should never carry
	# the same visual weight as fresh feedback (236 call sites share this one label).
	if _status_fade_tween != null:
		_status_fade_tween.kill()
		_status_fade_tween = null
	if not is_error and is_inside_tree() and not EventSheetAccessibility.reduced_motion():
		_status_fade_tween = create_tween()
		_status_fade_tween.tween_interval(6.0)
		_status_fade_tween.tween_property(_status_label, "modulate:a", 0.45, 1.5)


## The right-hand half of the status bar: where the selected row sits, said the way an event
## sheet says it - "event 4 of 61 · line 38". The number is the sheet's own margin number
## (stable through folds and filters), the count is how many events the sheet has, and the line
## is the file line the row came from (omitted on a sheet that has no file behind it). A row
## that is not an event (a comment, a group bar, a variable) keeps the last event's address
## empty rather than inventing one, so the bar never names a row the margin does not number.
func _update_row_address_status() -> void:
	if _row_address_label == null:
		return
	_row_address_label.text = row_address_text(
		_viewport.get_selected_row_data() if _viewport != null else null,
		_current_sheet)
	_row_address_label.tooltip_text = _row_address_label.text


## The status bar's address sentence for one row, as a pure function so tests can pin the words.
static func row_address_text(row_data: EventRowData, sheet: EventSheetResource) -> String:
	if row_data == null or sheet == null or row_data.event_number <= 0:
		return ""
	var total: int = EventSheetViewport.event_numbers_for(sheet.events).size()
	var text: String = EventSheetL10n.translate("event %d of %d") % [row_data.event_number, total]
	if row_data.line_number > 0:
		text += " · " + EventSheetL10n.translate("line %d") % row_data.line_number
	return text


func _refresh_title_strip() -> void:
	# Keep the active tab's persisted state and tab title in sync with the live state.
	_sync_active_tab_state()
	_update_active_tab_title()
	if _title_tab_label == null or _title_path_label == null or _title_dirty_dot == null:
		return
	_title_tab_label.text = _format_sheet_title(_current_sheet, _current_sheet_path)
	_title_path_label.text = _format_sheet_path_hint(_current_sheet, _current_sheet_path)
	_title_dirty_dot.visible = _dirty and _current_sheet != null
	if _identity_banner != null:
		_identity_banner.update_from_sheet(_current_sheet, _current_sheet_path)
	_refresh_preview_banner()


## Q4 - a sheet is named for the OBJECT it is about, not for the file it is stored in: the tab, the
## Open Sheets list, the window title and the recents all read "Player" where they read "player.gd".
## The file is still one hover away (_tab_tooltip / _format_sheet_path_hint).
static func _format_sheet_title(sheet: EventSheetResource, explicit_path: String) -> String:
	if sheet == null:
		return "No Sheet Loaded"
	# P4 - a scene opened as one sheet is named after the SCENE, extension and all: it is not one
	# script's tab, and the file name is the thing the reader picked in the FileSystem.
	if EventSheetSceneSheet.is_scene_sheet(sheet):
		return EventSheetSceneSheet.scene_path_of(sheet).get_file()
	var resolved_path: String = _resolve_sheet_path(sheet, explicit_path)
	if resolved_path.is_empty():
		return "Untitled EventSheet"
	var object_name: String = str(EventSheetObjectFacts.sheet_object_title(sheet, resolved_path).get("name", ""))
	return object_name if not object_name.is_empty() else resolved_path.get_file().get_basename()


static func _format_sheet_path_hint(sheet: EventSheetResource, explicit_path: String) -> String:
	if sheet == null:
		return "Open or create a sheet to begin"
	var resolved_path: String = _resolve_sheet_path(sheet, explicit_path)
	if resolved_path.is_empty():
		return "Unsaved (in-memory)"
	return resolved_path


static func _resolve_sheet_path(sheet: EventSheetResource, explicit_path: String) -> String:
	if sheet == null:
		return explicit_path
	if not explicit_path.is_empty():
		return explicit_path
	return sheet.resource_path


func _refresh_ace_registry() -> void:
	if _ace_registry == null:
		_ace_registry = EventSheetACERegistry.new()
	_release_ace_sources()
	var owned_sources: Array[Object] = _build_sheet_ace_sources()
	var combined_sources: Array[Object] = owned_sources.duplicate()
	combined_sources.append_array(_manual_ace_sources)
	if combined_sources.is_empty():
		owned_sources = _build_default_ace_sources()
		combined_sources = owned_sources.duplicate()
	# Zero-config addons: scripts under res://eventsheet_addons/ register project-wide
	# automatically - purely additive (they never displace the default vocabulary or the
	# sheet's own providers; deduped against the sheet's provider list).
	var addon_sources: Array[Object] = _build_addon_ace_sources()
	owned_sources.append_array(addon_sources)
	combined_sources.append_array(addon_sources)
	_ace_sources = owned_sources
	_ace_registry.refresh_from_sources(combined_sources, true)
	if _viewport != null:
		_viewport.set_ace_registry(_ace_registry)
	_ace_picker.set_registry(_ace_registry)
	_refresh_exposed_node()


## Instantiates the current sheet's registered provider scripts into reflectable sources.
func _build_sheet_ace_sources() -> Array[Object]:
	var sources: Array[Object] = []
	if _current_sheet == null:
		return sources
	for path: Variant in _current_sheet.ace_provider_scripts:
		var instance: Object = _instantiate_provider_script(str(path))
		if instance != null:
			sources.append(instance)
	return sources


## Instantiates every scanned zero-config addon script (res://eventsheet_addons/), skipping
## paths the sheet already registers explicitly.
func _build_addon_ace_sources() -> Array[Object]:
	var sources: Array[Object] = []
	# Same scan, second registry: pack-defined Custom Block kinds (scripts extending
	# EventSheetBlockKind) register here so a newly dropped kind is usable without a restart.
	EventSheetBlockRegistry.rescan_pack_kinds()
	var sheet_paths: Array = _current_sheet.ace_provider_scripts if _current_sheet != null else []
	# Folder scan + code-registered providers (EventForgeBridge.register_script_as_provider
	# lets other plugins/tools extend the vocabulary without touching eventsheet_addons/).
	var provider_paths: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	for registered_path: String in EventForgeBridgeRuntime.get_registered_provider_scripts():
		if not provider_paths.has(registered_path):
			provider_paths.append(registered_path)
	# Taught verbs: sheets shared via "Teach a Verb" persist project-wide through this
	# setting (durable across sessions, unlike the bridge's in-memory registrations) -
	# every listed script's exposed verbs join the picker exactly like a pack's.
	for taught_path: Variant in ProjectSettings.get_setting(TAUGHT_PROVIDERS_SETTING, PackedStringArray()):
		var taught: String = str(taught_path)
		if not taught.is_empty() and not provider_paths.has(taught) and ResourceLoader.exists(taught):
			provider_paths.append(taught)
	# Registered autoloads with annotated scripts publish project-wide (event buses,
	# game state) - zero-config, like eventsheet_addons/.
	_autoload_provider_names.clear()
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = str(property_info.get("name", ""))
		if not setting_name.begins_with("autoload/"):
			continue
		var autoload_path: String = str(ProjectSettings.get_setting(setting_name, "")).trim_prefix("*")
		if not autoload_path.ends_with(".gd"):
			continue
		# Only ANNOTATED autoloads publish (reflection would otherwise dump every
		# public method of e.g. the plugin's own bridge into every picker - silent
		# vocabulary pollution). The regex anchors on the annotation form so a passing
		# doc-comment mention of "@ace_*" doesn't count.
		var autoload_source: String = FileAccess.get_file_as_string(autoload_path)
		if _autoload_annotation_regex == null:
			_autoload_annotation_regex = RegEx.new()
			_autoload_annotation_regex.compile("(?m)^\\s*## @ace_")
		if _autoload_annotation_regex.search(autoload_source) == null:
			continue
		var autoload_script: Script = load(autoload_path) if ResourceLoader.exists(autoload_path) else null
		if autoload_script == null:
			continue
		# Map class -> singleton name even when the script is ALREADY scanned (an addon
		# registered as an autoload still needs bus-style trigger baking).
		var provider_class: String = str(autoload_script.get_global_name())
		if provider_class.is_empty():
			# Must match get_provider_id's fallback (to_pascal_case(), "MyBus") - the trigger
			# baking looks this map up BY definition.provider_id, so a key in any other shape
			# here silently skipped autoload trigger baking for class_name-less scripts.
			provider_class = autoload_path.get_file().get_basename().to_pascal_case()
		_autoload_provider_names[provider_class] = setting_name.trim_prefix("autoload/")
		if not provider_paths.has(autoload_path):
			provider_paths.append(autoload_path)
	for path: String in provider_paths:
		if sheet_paths.has(path):
			continue
		var instance: Object = _instantiate_provider_script(path)
		if instance != null:
			sources.append(instance)
	return sources


## Loads and instantiates a provider script (Node/Resource/RefCounted) for reflection.
## Returns null when the path is not an instantiable script.
func _instantiate_provider_script(path: String) -> Object:
	if path.strip_edges().is_empty() or not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	if not (resource is Script):
		return null
	var script: Script = resource as Script
	if not script.can_instantiate():
		return null
	var instance: Variant = script.new()
	return instance if instance is Object else null


func _build_default_ace_sources() -> Array[Object]:
	var demo_script: Script = load("res://addons/eventsheet/runtime/demo_gameplay_actor.gd")
	if demo_script == null or not demo_script.can_instantiate():
		return []
	var demo_source: Variant = demo_script.new()
	if demo_source is Object:
		return [demo_source]
	return []


## The starting sheet when there is nothing to restore: EMPTY, on purpose.
##
## This used to hand back a fabricated example (health/score variables and an On Process row that
## counted them), so the dock could never be seen empty - every fresh open landed on rows the user had
## not written and had to delete before starting. An empty sheet lets the viewport's own empty state do
## the teaching instead: it draws the "add your first event" call to action and the starter-template
## shortcut, which is the guidance the example was standing in for.
func _build_blank_sheet() -> EventSheetResource:
	return EventSheetResource.new()


func _release_ace_sources() -> void:
	for source_object in _ace_sources:
		if source_object is Node:
			(source_object as Node).free()
	_ace_sources.clear()


func _refresh_exposed_node() -> void:
	if _exposed_node == null:
		return
	_exposed_node.setup(_ace_registry, _editor_param_store, _current_sheet, _param_resolver)
	_exposed_node.set_undo_redo_manager(_undo_redo_adapter.get_manager())
	_exposed_node.on_registry_refreshed()


func _on_undo_requested() -> void:
	if not _undo_redo_adapter.has_undo():
		_set_status("Nothing to undo.", true)
		return
	_undo_redo_adapter.undo()


func _on_redo_requested() -> void:
	if not _undo_redo_adapter.has_redo():
		_set_status("Nothing to redo.", true)
		return
	_undo_redo_adapter.redo()


func _capture_sheet_snapshot() -> EventSheetResource:
	if _current_sheet == null:
		return null
	return _current_sheet.duplicate(true)


func _restore_sheet_snapshot(snapshot: EventSheetResource) -> void:
	if snapshot == null:
		return
	# U18 - the History marker follows the snapshot, so Ctrl+Z from anywhere moves it too.
	_ensure_history_panel().note_restored(snapshot)
	_current_sheet = snapshot.duplicate(true)
	if not _current_sheet_path.is_empty():
		_current_sheet.take_over_path(_current_sheet_path)
	_refresh_after_edit()
	_mark_dirty("Applied undo/redo.")


func _perform_undoable_sheet_edit(action_name: String, operation: Callable) -> bool:
	if _current_sheet == null or not operation.is_valid():
		return false
	# A .gd preview unlocks on the first real edit (this is the mutation funnel), so editing your
	# own sheet never hits a "click Edit Events" wall. Saving keeps its own read-only guard, so a
	# casual look + Ctrl+S still can't overwrite a file you only opened to view.
	_unlock_preview_for_edit()
	var before: EventSheetResource = _capture_sheet_snapshot()
	var changed: bool = bool(operation.call())
	if not changed:
		return false
	var after: EventSheetResource = _capture_sheet_snapshot()
	if before == null or after == null:
		return false
	if not _undo_redo_adapter.has_manager():
		_refresh_after_edit()
		return true
	_undo_redo_adapter.create_action(action_name)
	_undo_redo_adapter.add_do_method(self, "_restore_sheet_snapshot", [after])
	_undo_redo_adapter.add_undo_method(self, "_restore_sheet_snapshot", [before])
	_undo_redo_adapter.commit_action()
	# U18 - the same step, written into the History panel's log in the name the edit gave itself.
	_ensure_history_panel().record(action_name, before, after, _selected_event_number())
	return true


## The event number the edit was made on, 0 when nothing was selected. It is what turns a bare
## "Add Group" in the History list into "Add Group   event 12".
func _selected_event_number() -> int:
	if _viewport == null:
		return 0
	var row_data: EventRowData = _viewport.get_row_data(_viewport.get_selected_row_index())
	return row_data.event_number if row_data != null else 0


func _clear_undo_history() -> void:
	_undo_redo_adapter.clear_history()
	_ensure_history_panel().clear()


func _resource_contains_descendant(source: Resource, candidate: Resource) -> bool:
	if source == null or candidate == null:
		return false
	if source == candidate:
		return true
	if source is EventRow:
		for child in (source as EventRow).sub_events:
			if _resource_contains_descendant(child, candidate):
				return true
	elif source is EventGroup:
		var group: EventGroup = source as EventGroup
		var children: Array = group.events if not group.events.is_empty() else group.rows
		for child in children:
			if _resource_contains_descendant(child, candidate):
				return true
	return false


# ── Settings ▸ Words, Tools ▸ Addon manager, Object bar ▸ Add behavior… ────────────────────────
# Three windows over the same idea: the vocabulary is a choice, the installed packs are a list,
# and adding a pack to an object is one gesture. Each is built on first open and kept, because
# a session that never opens one should pay nothing for it.
var _words_settings_dialog: EventSheetWordsSettingsDialog = null
var _addon_manager_dialog: EventSheetAddonManagerDialog = null
var _add_behavior_dialog: EventSheetAddBehaviorDialog = null


## Settings ▸ Words: every choosable word on one page. A change is baked into row TEXT at build
## time, so every open view is rebuilt rather than redrawn.
func open_words_settings() -> void:
	if _words_settings_dialog == null:
		_words_settings_dialog = EventSheetWordsSettingsDialog.new()
		_words_settings_dialog.words_changed.connect(_on_words_changed)
		add_child(_words_settings_dialog)
	_words_settings_dialog.refresh()
	_words_settings_dialog.popup_centered(Vector2i(680, 560))


func _on_words_changed() -> void:
	for view: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if view != null:
			view.set_sheet(_current_sheet)


## Tools ▸ Addon manager: the installed packs, their versions, and the switch.
func open_addon_manager() -> void:
	if _addon_manager_dialog == null:
		_addon_manager_dialog = EventSheetAddonManagerDialog.new()
		_addon_manager_dialog.configure(
			func() -> void: _refresh_ace_registry(),
			func(page_id: String) -> void: open_documentation(page_id),
			func(script_path: String) -> void: EventSheets.open_sheet(script_path))
		add_child(_addon_manager_dialog)
	_addon_manager_dialog.refresh()
	_addon_manager_dialog.popup_centered(Vector2i(760, 500))


## Object bar ▸ right-click an object ▸ Add behavior…: every pack, in one dialog.
func open_add_behavior_dialog(object_label: String) -> void:
	if _add_behavior_dialog == null:
		_add_behavior_dialog = EventSheetAddBehaviorDialog.new()
		_add_behavior_dialog.configure(_apply_add_behavior)
		add_child(_add_behavior_dialog)
	_add_behavior_dialog.open_for(object_label)


## The Add button's landing: the node path goes into the open scene, the inline path goes through
## the undo funnel like every other sheet edit.
func _apply_add_behavior(pack: Dictionary, values: Dictionary, inline: bool, object_label: String) -> void:
	if inline:
		var written: Dictionary = {}
		var ok: bool = _perform_undoable_sheet_edit("Add behavior %s" % str(pack.get("name", "")), func() -> bool:
			written = EventSheetAddBehavior.write_into_sheet(pack, _current_sheet, values)
			return bool(written.get("ok", false)))
		_set_status(str(written.get("message", "Nothing was written.")), not ok)
		return
	var host: Node = _scene_node_for_object(object_label)
	var result: Dictionary = EventSheetAddBehavior.attach_node(pack, host, values)
	if bool(result.get("ok", false)) and Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.mark_scene_as_unsaved()
	_refresh_ace_registry()
	_set_status(str(result.get("message", "")), not bool(result.get("ok", false)))


## The node an Object bar label stands for in the open scene, or null when the scene is not open.
func _scene_node_for_object(object_label: String) -> Node:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	if edited_root == null:
		return null
	var path: String = str(EventSheetObjectProperties.find_entry(
		_current_sheet, object_label).get("path", object_label)).strip_edges().trim_prefix("$").trim_prefix("%")
	if path.is_empty():
		return null
	var found: Node = edited_root.get_node_or_null(NodePath(path))
	if found == null:
		found = edited_root.find_child(path.get_file(), true, false)
	return found


# ── V12. Arrange by, and saved views (appended block - keep together) ─────────────────────────
# Display only from end to end: the arrangement re-groups the ROWS a view has built, never the
# sheet, so the events array keeps its order, the emitted GDScript cannot move and the byte
# round-trip is untouched. Every pane of the same sheet is arranged together, because "arranged by
# Object" is a way of reading the sheet, not a property of one pane.


## The arrangement the sheet is being read under right now (file order unless asked otherwise).
func arrangement_mode() -> int:
	var view: EventSheetViewport = _active_view()
	return view.arrangement_mode if view != null else EventSheetArrangement.MODE_FILE_ORDER


## V13 - the View dial for variable rows: sentence / both / code. Per view, like every other lens.
func variable_row_view() -> int:
	var view: EventSheetViewport = _active_view()
	return view.variable_row_view if view != null else EventSheetCodeEcho.VIEW_BOTH


## Reads every variable row at `mode` in every open pane. Simple Mode pins the dial at the sentence:
## a beginner's sheet is the sheet, and the declaration is what they came here NOT to write.
func set_variable_row_view(mode: int) -> void:
	var wanted: int = EventSheetCodeEcho.VIEW_SENTENCE if _simple_mode else mode
	for view: Variant in _multi_view.all_views():
		var pane: EventSheetViewport = view as EventSheetViewport
		if pane != null:
			pane.set_variable_row_view(wanted)
	_set_status(EventSheetL10n.translate("Variable rows: %s.") % EventSheetCodeEcho.VIEW_LABELS[wanted])


## Reads the sheet arranged by `mode`, in every open pane, and points the Outline at it too.
func set_arrangement_mode(mode: int) -> void:
	for view: Variant in _multi_view.all_views():
		var pane: EventSheetViewport = view as EventSheetViewport
		if pane != null:
			pane.set_arrangement_mode(mode)
	if _outline_panel != null:
		_outline_panel.refresh()
	if mode == EventSheetArrangement.MODE_FILE_ORDER:
		_set_status(EventSheetL10n.translate("Reading in file order."))
	else:
		_set_status(EventSheetL10n.translate("Arranged by %s. The file is unchanged.") % EventSheetL10n.translate(EventSheetArrangement.mode_label(mode)))


## The reading lenses a saved view remembers alongside the arrangement and the filter.
func current_view_lenses() -> Dictionary:
	var view: EventSheetViewport = _active_view()
	return {
		"humanized_names": _humanized_names_enabled(),
		"familiar_words": _familiar_words_enabled(),
		"compact_rows": _compact_rows_enabled(),
		"event_numbers": view != null and view.show_event_numbers,
		"object_icons": view != null and view.show_object_icons,
	}


## Puts a saved view back: its arrangement, its filter, and each lens it named.
func apply_saved_view(name: String) -> void:
	var blob: Dictionary = EventSheetSavedViews.view(name)
	if blob.is_empty():
		_set_status(EventSheetL10n.translate("No saved view by that name."), true)
		return
	set_arrangement_mode(EventSheetSavedViews.arrangement_of(blob))
	_apply_lens(EventSheetSavedViews.filter_of(blob))
	var lenses: Dictionary = EventSheetSavedViews.lenses_of(blob)
	for pane_entry: Variant in _multi_view.all_views():
		var pane: EventSheetViewport = pane_entry as EventSheetViewport
		if pane == null:
			continue
		if lenses.has("event_numbers"):
			pane.show_event_numbers = bool(lenses["event_numbers"])
		if lenses.has("object_icons"):
			pane.show_object_icons = bool(lenses["object_icons"])
		pane.queue_redraw()
	_set_status(EventSheetL10n.translate("View: %s") % name)


var _save_view_dialog: ConfirmationDialog = null
var _save_view_edit: LineEdit = null


## Names the way the sheet is being read right now and keeps it in the View menu.
func save_current_view_requested() -> void:
	if _save_view_dialog == null:
		_save_view_dialog = ConfirmationDialog.new()
		_save_view_dialog.title = "Save View"
		_save_view_edit = LineEdit.new()
		_save_view_edit.placeholder_text = "Name this way of reading the sheet…"
		_save_view_edit.custom_minimum_size = Vector2(360.0, 0.0)
		var body_box: VBoxContainer = EventSheetPopupUI.form_box()
		body_box.add_child(_save_view_edit)
		_save_view_dialog.add_child(EventSheetPopupUI.margined(body_box))
		_save_view_dialog.confirmed.connect(_on_save_view_confirmed)
		add_child(_save_view_dialog)
		EventSheetL10n.apply_to(_save_view_dialog)
	_save_view_edit.text = ""
	_save_view_dialog.popup_centered(Vector2i(420, 110))


func _on_save_view_confirmed() -> void:
	var name: String = _save_view_edit.text.strip_edges()
	var view: EventSheetViewport = _active_view()
	var blob: Dictionary = EventSheetSavedViews.describe(arrangement_mode(),
		view.lens_query() if view != null else "", current_view_lenses())
	if EventSheetSavedViews.save_view(name, blob):
		_set_status(EventSheetL10n.translate("Saved the view %s.") % name)
	else:
		_set_status(EventSheetL10n.translate("A view needs a name."), true)


## Forgets a saved view.
func delete_saved_view(name: String) -> void:
	if EventSheetSavedViews.delete_view(name):
		_set_status(EventSheetL10n.translate("Forgot the view %s.") % name)


# ── V13. Starter events per object, and the same events for another object (appended block) ───
# Two gestures on the Object bar's right-click menu. Both are ordinary sheet edits through the one
# undo funnel - the starters ADD events (a trigger each, and the sheet's own "+ Add action"
# placeholder waiting under it), the duplicate COPIES the events an object already has and points
# each copy at another object.


## The class the sheet knows this object is, and the triggers any behaviour pack on it fires.
func _object_starter_facts(object_label: String) -> Dictionary:
	var entry: Dictionary = EventSheetObjectProperties.find_entry(_current_sheet, object_label)
	var host_class: String = str(entry.get("class", "")).strip_edges()
	if host_class.is_empty() and _current_sheet != null:
		host_class = str(_current_sheet.host_class).strip_edges()
	var pack_triggers: PackedStringArray = PackedStringArray()
	var declared: Variant = entry.get("signals", PackedStringArray())
	if declared is PackedStringArray:
		pack_triggers = declared as PackedStringArray
	elif declared is Array:
		for name_entry: Variant in (declared as Array):
			pack_triggers.append(str(name_entry))
	return {"class": host_class, "pack_triggers": pack_triggers}


## Adds the events this object's class is usually given - one event per starter trigger, with an
## empty action lane, plus a declaration for any signal the starters name that the sheet does not
## declare yet. One undo step.
func add_common_events_for(object_label: String) -> void:
	if not _ensure_sheet_for_editing():
		return
	var facts: Dictionary = _object_starter_facts(object_label)
	var starters: Array = EventSheetStarterEvents.starters_for(str(facts.get("class", "")),
		facts.get("pack_triggers", PackedStringArray()))
	if starters.is_empty():
		_set_status(EventSheetL10n.translate("No common events are known for %s.") % object_label, true)
		return
	var added: Dictionary = {"events": 0, "signals": 0}
	var changed: bool = _perform_undoable_sheet_edit("Add Common Events", func() -> bool:
		for declaration: Variant in EventSheetStarterEvents.missing_signal_rows(starters, _current_sheet):
			_current_sheet.events.append(declaration)
			added["signals"] = int(added["signals"]) + 1
		for starter: Variant in starters:
			_current_sheet.events.append(EventSheetStarterEvents.build_event(starter as Dictionary))
			added["events"] = int(added["events"]) + 1
		return int(added["events"]) > 0)
	if not changed:
		return
	_refresh_after_edit()
	var words: PackedStringArray = PackedStringArray()
	for starter: Variant in starters:
		words.append(str((starter as Dictionary).get("label", "")))
	_mark_dirty(EventSheetL10n.translate("Added %s.") % ", ".join(words))


var _duplicate_events_dialog: ConfirmationDialog = null
var _duplicate_events_edit: LineEdit = null
var _duplicate_events_source: String = ""


## "Duplicate events for…": every event that names this object, copied once per object you list,
## each copy pointing at that object instead. One undo step for the whole batch.
func open_duplicate_events_dialog(object_label: String) -> void:
	if not _ensure_sheet_for_editing():
		return
	if _duplicate_events_dialog == null:
		_duplicate_events_dialog = ConfirmationDialog.new()
		_duplicate_events_dialog.title = "Duplicate Events For"
		_duplicate_events_edit = LineEdit.new()
		_duplicate_events_edit.placeholder_text = "Enemy2, Enemy3"
		_duplicate_events_edit.custom_minimum_size = Vector2(360.0, 0.0)
		var body_box: VBoxContainer = EventSheetPopupUI.form_box()
		body_box.add_child(_duplicate_events_edit)
		_duplicate_events_dialog.add_child(EventSheetPopupUI.margined(body_box))
		_duplicate_events_dialog.confirmed.connect(_on_duplicate_events_confirmed)
		add_child(_duplicate_events_dialog)
		EventSheetL10n.apply_to(_duplicate_events_dialog)
	_duplicate_events_source = object_label
	_duplicate_events_edit.text = ""
	# The dialog is built once and reused, so the object it is about has to be written on it EVERY
	# open. Without this it reads "Duplicate Events For" over an empty box, and a sheet with four
	# objects gives the reader no way to tell which one's events are about to be copied.
	_duplicate_events_dialog.title = "%s %s" % [
		EventSheetL10n.translate("Duplicate Events For"), object_label]
	_duplicate_events_dialog.popup_centered(Vector2i(440, 120))


func _on_duplicate_events_confirmed() -> void:
	var targets: PackedStringArray = PackedStringArray()
	for piece: String in _duplicate_events_edit.text.split(","):
		var clean: String = piece.strip_edges()
		if not clean.is_empty():
			targets.append(clean)
	if targets.is_empty():
		_set_status(EventSheetL10n.translate("Name at least one object to duplicate for."), true)
		return
	var source: String = _duplicate_events_source
	var made: Dictionary = {"count": 0}
	var changed: bool = _perform_undoable_sheet_edit("Duplicate Events For", func() -> bool:
		var source_reference: String = EventSheetDuplicateEvents.reference_for(_current_sheet, source)
		for target: String in targets:
			var copies: Array = EventSheetDuplicateEvents.copies_for(_current_sheet, source_reference, target)
			for copy: Variant in copies:
				_assign_fresh_event_uids(copy as Resource)
				_current_sheet.events.append(copy)
				made["count"] = int(made["count"]) + 1
		return int(made["count"]) > 0)
	if not changed:
		_set_status(EventSheetL10n.translate("No events name %s.") % source, true)
		return
	_refresh_after_edit()
	_mark_dirty(EventSheetL10n.translate("Duplicated %d event(s).") % int(made["count"]))


# ── V15. Scene workspaces (appended block - keep together) ────────────────────────────────────
# The unit of work is the scene, so it opens as one: the scene-as-sheet plus every script in it, in
# tree order, as a named tab group that is remembered. Tabs stay individually closable - a
# workspace is a way of OPENING, never a cage - and nothing is written into the project.


## Opens every sheet of one scene as a named tab group, and remembers the group.
func open_scene_workspace(scene_path: String) -> void:
	var name: String = EventSheetWorkspaces.remember_scene(scene_path)
	if name.is_empty():
		_set_status(EventSheetL10n.translate("That scene has no sheets to open."), true)
		return
	_open_workspace_paths(name, EventSheetWorkspaces.members_of_scene(scene_path))


## Reopens a remembered workspace by name.
func open_workspace(name: String) -> void:
	var paths: PackedStringArray = EventSheetWorkspaces.paths_of(name)
	if paths.is_empty():
		_set_status(EventSheetL10n.translate("That workspace has nothing left to open."), true)
		return
	_open_workspace_paths(name, paths)


## Forgets a remembered workspace (the sheets themselves are untouched).
func forget_workspace(name: String) -> void:
	if EventSheetWorkspaces.forget(name):
		_set_status(EventSheetL10n.translate("Forgot the workspace %s.") % name)


func _open_workspace_paths(name: String, paths: PackedStringArray) -> void:
	var opened: int = 0
	for path: String in paths:
		if not FileAccess.file_exists(path):
			continue
		_load_sheet_from_path(path)
		opened += 1
	if opened == 0:
		_set_status(EventSheetL10n.translate("That workspace has nothing left to open."), true)
		return
	for tab: Dictionary in _open_tabs:
		if Array(paths).has(str(tab.get("path", ""))):
			tab["group"] = name
	_refresh_tab_bar()
	_persist_session()
	_set_status(EventSheetL10n.translate("Workspace %s: %d sheet(s).") % [name, opened])


# ── V16. Export the sheet as a picture (appended block - keep together) ───────────────────────
# Sheet ▸ Export ▸ Image (PNG) / PDF / Markdown with figures. The picture is the CANVAS, captured
# as it is being read - current theme, density, arrangement, lenses, event numbers - so an exported
# sheet and the sheet on screen can never be two different readings of the same file. The canvas is
# virtualized (it only ever draws what is on screen), so the whole sheet is captured a screenful at
# a time and stitched; everything that follows from that picture - the page split, the PDF, the
# Markdown - is arithmetic and lives in EventSheetSheetExport.

var _export_picture_dialog: EditorFileDialog = null
var _export_picture_kind: String = "png"


## Opens the save dialog for one export kind ("png", "pdf" or "md").
func export_sheet_picture_requested(kind: String) -> void:
	if _active_view() == null:
		_set_status(EventSheetL10n.translate("Open a sheet first."), true)
		return
	_export_picture_kind = kind
	if _export_picture_dialog == null:
		_export_picture_dialog = EditorFileDialog.new()
		_export_picture_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		_export_picture_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
		_export_picture_dialog.file_selected.connect(_on_export_picture_path_chosen)
		add_child(_export_picture_dialog)
		EventSheetL10n.apply_to(_export_picture_dialog)
	match kind:
		"pdf":
			_export_picture_dialog.filters = PackedStringArray(["*.pdf ; PDF"])
			_export_picture_dialog.title = "Export the sheet as a PDF"
		"md":
			_export_picture_dialog.filters = PackedStringArray(["*.md ; Markdown"])
			_export_picture_dialog.title = "Export the sheet as Markdown with figures"
		_:
			_export_picture_dialog.filters = PackedStringArray(["*.png ; PNG image"])
			_export_picture_dialog.title = "Export the sheet as an image"
	_export_picture_dialog.current_file = "%s.%s" % [_sheet_io._exported_script_basename(), kind]
	_export_picture_dialog.popup_centered_ratio(0.6)


func _on_export_picture_path_chosen(path: String) -> void:
	_write_sheet_picture(path, _export_picture_kind)


## Captures the sheet and writes it in the asked-for shape. A capture that could not happen (a
## headless build, no window to draw in) says so rather than writing an empty file.
func _write_sheet_picture(path: String, kind: String) -> void:
	_set_status(EventSheetL10n.translate("Rendering the sheet…"))
	var picture: Image = await capture_sheet_picture()
	if picture == null:
		_set_status(EventSheetL10n.translate("The sheet could not be rendered here."), true)
		return
	match kind:
		"pdf":
			var pages: Array = EventSheetSheetExport.split_pages(picture)
			var bytes: PackedByteArray = EventSheetSheetExport.pdf_bytes(pages)
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				_set_status(EventSheetL10n.translate("Could not write %s.") % path, true)
				return
			file.store_buffer(bytes)
			file.close()
			_set_status(EventSheetL10n.translate("Exported %d page(s) to %s.") % [pages.size(), path])
		"md":
			var figures: Array = _write_sheet_figures(path, picture)
			var text: String = EventSheetSheetExport.markdown_with_figures(
				_active_view().get_row_tree(), _sheet_io._exported_script_basename(), figures)
			var document: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if document == null:
				_set_status(EventSheetL10n.translate("Could not write %s.") % path, true)
				return
			document.store_string(text)
			document.close()
			_set_status(EventSheetL10n.translate("Exported %s with %d figure(s).") % [path, figures.size()])
		_:
			if picture.save_png(path) != OK:
				_set_status(EventSheetL10n.translate("Could not write %s.") % path, true)
				return
			_set_status(EventSheetL10n.translate("Exported the sheet to %s.") % path)


## One figure per group, cropped out of the whole-sheet picture and written beside the document.
## A sheet with no groups gets one figure of the whole thing, which is the honest answer to "a
## figure per group" when the sheet IS one group.
func _write_sheet_figures(document_path: String, picture: Image) -> Array:
	var figures: Array = []
	var view: EventSheetViewport = _active_view()
	var bands: Array = view.group_row_bands() if view.has_method("group_row_bands") else []
	if bands.is_empty():
		bands = [{"title": _sheet_io._exported_script_basename(), "from": 0, "to": picture.get_height()}]
	var folder: String = document_path.get_base_dir()
	for band_index: int in bands.size():
		var band: Dictionary = bands[band_index]
		var from_y: int = clampi(int(band.get("from", 0)), 0, picture.get_height())
		var to_y: int = clampi(int(band.get("to", 0)), from_y, picture.get_height())
		if to_y - from_y <= 0:
			continue
		var title: String = str(band.get("title", ""))
		var file_name: String = EventSheetSheetExport.figure_file_name(document_path, title, band_index)
		var figure: Image = picture.get_region(Rect2i(0, from_y, picture.get_width(), to_y - from_y))
		if figure.save_png("%s/%s" % [folder, file_name]) == OK:
			figures.append({"title": title, "path": file_name})
	return figures


## The whole sheet as one tall picture: the canvas captured a screenful at a time and stitched,
## because a virtualized canvas only ever draws what is on screen. Null when there is no window to
## draw in (a headless build).
func capture_sheet_picture() -> Image:
	var view: EventSheetViewport = _active_view()
	if view == null or DisplayServer.get_name() == "headless":
		return null
	var scroll: ScrollContainer = view._get_scroll_container()
	var window: Viewport = get_viewport()
	if scroll == null or window == null:
		return null
	var band: Rect2i = Rect2i(scroll.get_global_rect())
	var total_height: int = maxi(int(scroll.get_v_scroll_bar().max_value), band.size.y)
	if band.size.x <= 0 or band.size.y <= 0:
		return null
	var stitched: Image = Image.create_empty(band.size.x, total_height, false, Image.FORMAT_RGBA8)
	var restore_to: int = scroll.scroll_vertical
	var cursor: int = 0
	while cursor < total_height:
		scroll.scroll_vertical = cursor
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var screen: Image = EventSheetSheetExport.matched_to(window.get_texture().get_image(),
			stitched.get_format())
		var visible: Rect2i = band.intersection(Rect2i(Vector2i.ZERO, screen.get_size()))
		if visible.size.x <= 0 or visible.size.y <= 0:
			break
		# The last band overlaps the one before it (the scroll simply stops), so only the part that
		# has not been stitched yet is copied.
		var taken: int = mini(visible.size.y, total_height - cursor)
		var actual: int = scroll.scroll_vertical
		stitched.blit_rect(screen,
			Rect2i(visible.position, Vector2i(visible.size.x, taken)), Vector2i(0, actual))
		if actual < cursor:
			break
		cursor = actual + taken
	scroll.scroll_vertical = restore_to
	return stitched


# ── V20. The sheet's health card (appended block - keep together) ─────────────────────────────
# How this sheet is doing, at a glance: how much of it reads as events, its patterns and which of
# them a shipped behaviour could take over, what the Doctor says about it, its Test Sheets and how
# they last went, and how much of it nothing uses. Every line clicks through to the panel that owns
# it, so the card stays a summary rather than becoming a sixth place where things live. Also the
# hover on an entry in the Open Sheets panel, which is where a sheet is picked.

var _health_dialog: AcceptDialog = null


## The card for the sheet in front of the reader, with the Doctor's own findings folded in.
func sheet_health_card() -> Dictionary:
	var findings: Array = []
	var report: Dictionary = EventSheets.doctor()
	if report.get("findings") is Array:
		findings = report["findings"]
	return EventSheetHealthCard.card_for(_current_sheet, _health_sheet_path(), findings)


## The file this sheet IS, which for an opened .gd is its source rather than its resource path.
func _health_sheet_path() -> String:
	if _current_sheet == null:
		return ""
	var external: String = str(_current_sheet.get("external_source_path")).strip_edges()
	if not external.is_empty():
		return external
	return _current_sheet_path if not _current_sheet_path.is_empty() else str(_current_sheet.resource_path)


## Sheet ▸ Health… - the card as a small window, one clickable line per panel behind it.
func open_sheet_health() -> void:
	if _current_sheet == null:
		_set_status(EventSheetL10n.translate("Open a sheet first."), true)
		return
	var card: Dictionary = sheet_health_card()
	var lines: VBoxContainer = EventSheetPopupUI.form_box()
	for entry: Variant in EventSheetHealthCard.card_lines(card):
		var line: Dictionary = entry
		var button: Button = Button.new()
		button.text = str(line.get("text", ""))
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var panel: String = str(line.get("panel", ""))
		button.pressed.connect(func() -> void: open_health_panel(panel))
		lines.add_child(button)
	if _health_dialog != null:
		_health_dialog.queue_free()
	_health_dialog = AcceptDialog.new()
	_health_dialog.title = "Sheet Health"
	_health_dialog.add_child(EventSheetPopupUI.margined(
		EventSheetPopupUI.titled_card(str(card.get("title", "")), lines)))
	add_child(_health_dialog)
	EventSheetL10n.apply_to(_health_dialog)
	_health_dialog.popup_centered(Vector2i(EventSheetPalette.scaled(460), EventSheetPalette.scaled(240)))


## Clicking a line of the card opens the panel that owns that line.
func open_health_panel(panel: String) -> void:
	if _health_dialog != null:
		_health_dialog.hide()
	match panel:
		"coverage":
			_open_lift_report()
		"doctor":
			_open_project_doctor()
		"tests":
			_menu_bar._open_run_tests()
		"loose_ends":
			_open_loose_ends_panel()


var _loose_ends_health_panel: EventSheetLooseEndsPanel = null


func _open_loose_ends_panel() -> void:
	if _loose_ends_health_panel == null:
		_loose_ends_health_panel = EventSheetLooseEndsPanel.new()
		_loose_ends_health_panel.init(self)
	_loose_ends_health_panel.open()
