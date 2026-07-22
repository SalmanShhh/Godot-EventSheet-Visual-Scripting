@tool
class_name EventSheetDock
extends Control

# .gd is listed first so it is the default format for New Sheet / Save As - a sheet is just plain
# GDScript (no .tres needed). .tres/.res stay available (e.g. library sheets used via Includes).
const EVENT_SHEET_FILTERS: Array[String] = ["*.gd ; GDScript EventSheet", "*.tres ; EventSheetResource", "*.res ; EventSheetResource"]
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
const ROW_MENU_EDIT_GROUP_DESC := 20
const ROW_MENU_GROUP_COLOR := 27
const ROW_MENU_GROUP_RUNTIME := 28
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
const VARIABLE_MENU_EDIT := 1
const VARIABLE_MENU_CONVERT_SCOPE := 2
const VARIABLE_MENU_TOGGLE_CONST := 3
const VARIABLE_MENU_RENAME := 4
const VARIABLE_MENU_GROUP := 5
const EMPTY_MENU_NEW_EVENT := 1
const EMPTY_MENU_NEW_CONDITION := 2
const EMPTY_MENU_ADD_VARIABLE := 3
const EMPTY_MENU_INSERT_SNIPPET := 4
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
var _theme_picker: OptionButton = null
var _provider_dialog: Window = null
var _provider_list: ItemList = null
var _provider_file_dialog: FileDialog = null
var _split: HSplitContainer = null
var _scroll: ScrollContainer = null
# Open Sheets panel: a left in-workspace pane (the "Filter Scripts"-style list). _workspace_body
# is a stable HSplit holding [_open_sheets_panel | _content_host]; _content_host wraps _scroll, so
# the code-panel/split-view machinery (which reparents _scroll relative to its parent) stays inside
# it and never disturbs the panel. Toggled from the View menu; collapsible to a strip.
var _workspace_body: HSplitContainer = null
var _content_host: VBoxContainer = null
var _open_sheets_panel: EventSheetOpenSheetsDock = null
var _anatomy_panel: BehaviourAnatomyPanel = null  # left rail, under Open Sheets (behaviour_anatomy_panel.gd)
var _functions_panel: EventSheetFunctionsPanel = null  # left rail, dockable fold-expand Functions overview (functions_panel.gd)
const _OPEN_SHEETS_PANEL_META: String = "eventsheets_open_sheets_panel"  # editor metadata: {shown, collapsed}
var _column_header: SheetColumnHeader = null
var _identity_banner: SheetIdentityBanner = null
var _preview_banner: PanelContainer = null
var _preview_label: Label = null
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
var _ai: EventSheetAIGenerateWindow = EventSheetAIGenerateWindow.new()  # Edit ▸ Generate from Description… window (dock/ai_generate_window.gd)
var _sheet_type: EventSheetSheetTypeDialog = EventSheetSheetTypeDialog.new()  # Sheet ▸ Sheet Type… dialog shell (dock/sheet_type_dialog.gd)
var _session: EventSheetSessionStore = EventSheetSessionStore.new()  # open-tabs restore across restarts (event_sheet_session_store.gd)
var _shortcuts: EventSheetShortcutsDialog = EventSheetShortcutsDialog.new()  # Tools ▸ Keyboard Shortcuts editor (event_sheet_shortcuts_dialog.gd)
var _rename: EventSheetRenameRefactor = EventSheetRenameRefactor.new()  # variable rename engine + "Rename Everywhere" dialog (event_sheet_rename_refactor.gd)
var _variables: EventSheetVariablesManager = EventSheetVariablesManager.new()  # global/local/tree variable authoring + usage scan (dock/variables_manager.gd)
var _multi_view: EventSheetMultiViewManager = EventSheetMultiViewManager.new()  # split-view subsystem: second pane over the same sheet (dock/multi_view_manager.gd)
var _command_palette: EventSheetCommandPalette = EventSheetCommandPalette.new()  # Ctrl+P command palette: list + fuzzy filter + popup shell (dock/command_palette.gd)
var _sheet_diff: EventSheetSheetDiff = EventSheetSheetDiff.new()  # "What Changed Since Save" - rows a save would touch (dock/sheet_diff.gd)
var _variable_grouping: EventSheetVariableGrouping = EventSheetVariableGrouping.new()  # drag-onto-variable folders + rename popup (dock/variable_grouping.gd)
var _menu_bar: EventSheetMenuBar = EventSheetMenuBar.new()  # top toolbar + grouped Sheet/Add/Edit/View/Tools menus + theme picker + quick-add (dock/menu_bar.gd)
var _context_menus: EventSheetContextMenus = EventSheetContextMenus.new()  # right-click context menus: condition/action/row/variable/empty-space build + per-click configure (dock/context_menus.gd)
var _external_watcher: EventSheetExternalWatcher = EventSheetExternalWatcher.new()  # GDScript-backed sheet file-watch + reload-on-disk-change dialog (dock/external_watcher.gd)
var _sheet_io: EventSheetSheetIO = EventSheetSheetIO.new()  # sheet FILE-IO: open-from-disk + every write-back path (Save/Save As/Export/Save-as-.gd) (dock/sheet_io.gd)
var _ui_builder: EventSheetDockUIBuilder = EventSheetDockUIBuilder.new()
var _input_dispatch: EventSheetDockInputDispatch = EventSheetDockInputDispatch.new()
var _code_panel_glue: EventSheetCodePanelGlue = EventSheetCodePanelGlue.new()
var _providers_glue: EventSheetProviderRegistryGlue = EventSheetProviderRegistryGlue.new()  # dock/provider_registry_glue.gd
var _sheet_type_glue: EventSheetTypeGlue = EventSheetTypeGlue.new()  # dock/sheet_type_glue.gd
var _queries: EventSheetDockQueries = EventSheetDockQueries.new()  # dock/sheet_queries.gd
var _add_rows: EventSheetAddRowRequests = EventSheetAddRowRequests.new()
var _extract_ops: EventSheetExtractOps = EventSheetExtractOps.new()  # extract-to-function / extract-to-include (dock/extract_ops.gd)  # dock/add_row_requests.gd  # code/provenance + open-sheets panel behavior (dock/code_panel_glue.gd)  # menu/shortcut routing (dock/dock_input_dispatch.gd)  # UI construction pass (dock/dock_ui_builder.gd)
var _ace_apply: EventSheetACEApply = EventSheetACEApply.new()  # ACE application (condition/action/trigger baking + insert) + row/ACE drag-drop reorder (dock/ace_apply.gd)
var _row_edit_ops: EventSheetRowEditOps = EventSheetRowEditOps.new()  # context-menu row/ACE edit ops: enable/disable, delete, indent/outdent, else, insert, bulk-selection, invert/OR-AND (dock/row_edit_ops.gd)
var _preview_glue: EventSheetPreviewGlue = EventSheetPreviewGlue.new()  # .gd-preview banner + "Edit Events" unlock + Open-in-Godot script-editor glue + lift-report window (dock/preview_glue.gd)
var _author_actions: EventSheetAuthorActions = EventSheetAuthorActions.new()  # author quick-actions: quick-add match+apply + Run Scene + Save/Insert row snippets (dock/author_actions.gd)
var _ghost_row: EventSheetGhostRow = EventSheetGhostRow.new()  # zero-dialog add: E/C/A open a type-a-sentence popup at the selected row (dock/ghost_row.gd)
var _navigate: EventSheetNavigate = EventSheetNavigate.new()  # Ctrl+Click go-to-definition: addon verbs open their behaviour as a sheet (dock/navigate.gd)
var _export_pack: EventSheetExportPack = EventSheetExportPack.new()  # Sheet ▸ Export Addon Pack: writes eventsheet_addons/<class>/ (.tres + .gd + README, bundles includes) (dock/export_pack.gd)
var _save_studio: EventSheetSaveStudio = EventSheetSaveStudio.new()  # Tools ▸ Save Studio: format preview + slot browser/export + save_state generator (dock/save_studio.gd)
var _function_dialog_glue: EventSheetFunctionDialogGlue = EventSheetFunctionDialogGlue.new()  # Add ▾ ▸ Function… dialog wiring + apply-to-sheet (dock/function_dialog.gd)
var _theme_manager: EventSheetThemeManager = EventSheetThemeManager.new()  # editor theme: load/apply/pick style + theme file dialog + theme editor + live-reload binding to the active .tres (dock/theme_manager.gd)
var _find_bar_glue: EventSheetFindBar = EventSheetFindBar.new()  # Ctrl+F find bar + Replace-All across the sheet + _replace_in_rows recursion (dock/find_bar.gd)
var _clipboard_glue: EventSheetClipboard = EventSheetClipboard.new()  # copy/paste: internal clipboard + portable snippets + raw-GDScript paste (owns _clipboard state) (dock/clipboard.gd)
var _quick_prompts: EventSheetQuickPromptDialogs = EventSheetQuickPromptDialogs.new()  # one-field prompt popups: Extract-to-Function name + Conditional Breakpoint + Group editor (dock/quick_prompt_dialogs.gd)
var _custom_block_dialog: EventSheetCustomBlockDialog = EventSheetCustomBlockDialog.new()  # Custom Block API: schema-driven add/edit dialog for registered kinds (dock/custom_block_dialog.gd)
var _condition_context_menu: PopupMenu = null
var _action_context_menu: PopupMenu = null
var _row_context_menu: PopupMenu = null
var _row_insert_submenu: PopupMenu = null
var _row_more_submenu: PopupMenu = null
var _variable_context_menu: PopupMenu = null
var _empty_space_context_menu: PopupMenu = null
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
	_queries.init(self)
	_add_rows.init(self)
	_extract_ops.init(self)
	# The public extension API (addons/eventsheet/api/eventsheets.gd) fronts this dock;
	# the region fold commands register through it as living proof the extension point
	# works - delete these four lines and only extensions lose their entries.
	EventSheets._register_dock(self)
	EventSheets.register_palette_command("Fold All Regions", func() -> void: _viewport.set_region_folds(true))
	EventSheets.register_palette_command("Unfold All Regions", func() -> void: _viewport.set_region_folds(false))
	EventSheets.register_palette_command("Fold Everything (regions + groups)", func() -> void: _viewport.set_region_folds(true, true))
	EventSheets.register_palette_command("Unfold Everything", func() -> void: _viewport.set_region_folds(false, true))
	EventSheets.register_palette_command("Save Studio", func() -> void: _open_save_studio())
	_ace_apply.init(self)
	# Row/ACE edit-ops helper: same fresh-.new()-before-_ready reasoning - tests exercise ops like
	# _bulk_set_enabled_on / _toggle_selected_enabled / _indent_selected_event before the tree init runs.
	_row_edit_ops.init(self)
	# Preview-glue helper MUST be wired before _build_ui(): _build_ui calls
	# _preview_glue.build_preview_banner(), which assigns _preview_banner/_preview_label back on the dock.
	_preview_glue.init(self)
	# Theme-manager MUST be wired before _build_ui() too: _build_ui() calls
	# _theme_manager.build_theme_file_dialog() (via the dock delegate). init() only stores _dock.
	_theme_manager.init(self)
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
	_build_ui()
	_ensure_editor_dialogs_initialized()
	_refresh_ace_registry()
	# Restore last session's tabs FIRST (editor only; headless tests drive setup() directly). Only fall
	# back to a blank starting sheet when nothing came back - otherwise an untitled demo stacks on top of
	# the user's real tabs. The plugin ALSO calls setup() right after add_child() (which already ran this
	# _ready), so the setup() below is a no-op once tabs exist - see setup()'s guard. This is what stopped
	# the "two untitled sheets on open" (a demo from _ready + a demo from the plugin's setup()).
	if Engine.is_editor_hint() and is_inside_tree():
		_restore_session()
	if _open_tabs.is_empty():
		if _current_sheet == null:
			_current_sheet = _build_demo_sheet()
			_viewport.set_debug_overlay_states({})
		setup(_current_sheet)


## Editor filesystem ping: cheap fingerprint check inside; only a REAL translation-folder
## change reloads catalogs and re-translates the live UI (and redraws the canvas-drawn strings).
func _on_translations_maybe_changed() -> void:
	if EventSheetL10n.reload_if_changed():
		propagate_notification(MainLoop.NOTIFICATION_TRANSLATION_CHANGED)
		if _viewport != null:
			_viewport.queue_redraw()


func setup(sheet: EventSheetResource = null) -> void:
	_build_ui()
	_ensure_editor_dialogs_initialized()
	# Idempotent initial state: a null setup() asks for "a blank starting sheet". If tabs already exist
	# (the plugin calls setup() right after add_child(), which already ran _ready), don't stack a second
	# untitled demo - keep what's open. A null setup() with no tabs still seeds one demo, as before.
	if sheet == null and not _open_tabs.is_empty():
		return
	var target_sheet: EventSheetResource = sheet if sheet != null else _build_demo_sheet()
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
	_sync_split_sheet()
	_refresh_anatomy_panel()
	_refresh_functions_list()
	_theme_manager._sync_active_theme_binding()
	_refresh_title_strip()
	_theme_manager._refresh_theme_picker_selection()
	_refresh_exposed_node()
	_refresh_variable_panel()
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


## Persists the live active-tab state (_current_sheet/path/dirty) back into _open_tabs.
func _sync_active_tab_state() -> void:
	if _active_tab_index < 0 or _active_tab_index >= _open_tabs.size():
		return
	_open_tabs[_active_tab_index] = {"sheet": _current_sheet, "path": _current_sheet_path, "dirty": _dirty}


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
	for tab: Dictionary in _open_tabs:
		_tab_bar.add_tab(_format_tab_title(tab.get("sheet"), str(tab.get("path", "")), bool(tab.get("dirty", false))))
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


func _format_tab_title(sheet: EventSheetResource, path: String, dirty: bool) -> String:
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
	# Guard against losing work: a dirty tab asks Save / Discard / Cancel before it closes.
	if is_tab_dirty(index):
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


## Manage Includes (browse/add/remove/reorder included library sheets) - see EventSheetIncludeManager.
func _open_include_manager() -> void:
	_includes.open()


func _export_gdscript_requested() -> void:
	_sheet_io._export_gdscript_requested()


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



func apply_group_edit(group: EventGroup, new_name: String, new_desc: String) -> bool:
	return _add_rows.apply_group_edit(group, new_name, new_desc)



static func set_group_fields(group: EventGroup, new_name: String, new_desc: String) -> String:
	return EventSheetQuickPromptDialogs.set_group_fields(group, new_name, new_desc)


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



func _on_zoom_in_requested() -> void:
	if _viewport == null:
		return
	_viewport.zoom_in()
	_set_status("Zoom: %d%%" % int(round(_viewport.get_zoom_factor() * 100.0)))


func _on_zoom_out_requested() -> void:
	if _viewport == null:
		return
	_viewport.zoom_out()
	_set_status("Zoom: %d%%" % int(round(_viewport.get_zoom_factor() * 100.0)))


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


func _paste_snippet_text(text: String) -> bool:  # author_actions _insert_snippet_path + snippet_share_test
	return _clipboard_glue._paste_snippet_text(text)


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


## Toolbar/menu "Add Code (GDScript)": C3-style script action on the selected event.
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


func _on_variable_dialog_confirmed(var_name: String, type_name: String, default_value: Variant, scope: String, context: Dictionary = {}, is_constant: bool = false, exported: bool = true, combo_options: PackedStringArray = PackedStringArray(), attributes: Dictionary = {}, onready: bool = false) -> void:  # _variable_dlg.variable_confirmed
	_variables._on_variable_dialog_confirmed(var_name, type_name, default_value, scope, context, is_constant, exported, combo_options, attributes, onready)


func _on_add_global_variable_requested() -> void:
	_variables._on_add_global_variable_requested()


func _on_add_local_variable_requested() -> void:
	_variables._on_add_local_variable_requested()


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


func _on_global_variable_activated(index: int) -> void:
	_variables._on_global_variable_activated(index)


func _on_local_variable_activated(index: int) -> void:
	_variables._on_local_variable_activated(index)


func _refresh_variable_panel() -> void:
	_variables._refresh_variable_panel()


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
	_apply_simple_mode_gates()
	_set_status("Simple mode ON - advanced entries hidden." if enabled else "Expert mode - all entries shown.")


## Applies Simple Mode to the always-visible surfaces it gates: the toolbar's deliberate
## drop-to-code button hides, and the Add menu's code item disables with a pointer to the toggle.
## (The picker and the right-click menus apply their own gates when they open.)
func _apply_simple_mode_gates() -> void:
	if _add_code_button != null:
		_add_code_button.visible = not _simple_mode
	if _add_menu_popup != null:
		var code_index: int = _add_menu_popup.get_item_index(4)
		if code_index >= 0:
			_add_menu_popup.set_item_disabled(code_index, _simple_mode)
			_add_menu_popup.set_item_tooltip(code_index, "Turn off Simple Mode (toolbar) to add GDScript blocks." if _simple_mode else "")


func _load_simple_mode_preference() -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings != null:
		_simple_mode = bool(settings.get_project_metadata("eventsheets", "simple_mode", false))


## Declutter toggle: show/hide the trailing "+ Add event…" affordance rows across every
## live view, and reflect the new state in the View menu checkbox.
## View > Object Icons: show/hide the icons before object/module names (rows + group folders).
## Icons live in span metadata, so a rebuild (set_sheet) applies the flip; the icon cache stays
## warm for flipping back.
## View > Event Numbers: event rows show their stable C3-style sheet-order number in the
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
	dialog.title = "Go to Event"
	dialog.ok_button_text = "Go"
	var number_edit: SpinBox = SpinBox.new()
	number_edit.min_value = 1
	number_edit.max_value = 99999
	number_edit.value = 1
	dialog.add_child(EventSheetPopupUI.titled_card("Event number", EventSheetPopupUI.form_row("Go to", number_edit)))
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
func _object_columns_aligned() -> bool:
	if _viewport == null:
		return false
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	# No style means nothing is aligned. Reporting "aligned" here made the first click of the toggle
	# switch TO flow on a sheet that was never aligned - the two functions must agree on what null is.
	return event_style != null and event_style.condition_object_column_width > 0


## View ▾ "Aligned Object Columns": flips the C3-style object column between ALIGNED (the default -
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


## Replace Object References (the Construct gesture, param-aware): pick a reference the
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
	content.add_child(EventSheetPopupUI.hint_label("Every matching reference across the %d selected row(s) rewrites - params, With-Node scopes, pick filters, and GDScript blocks. Token-safe: $Enemy never touches $EnemySpawner." % targets.size(), 420.0))
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
	var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	var to_suggestions: PackedStringArray = PackedStringArray(EventSheetRefactor.reference_suggestions(_current_sheet.events if _current_sheet != null else [], scene_root))
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
			_refresh_after_edit()
			_mark_dirty("Replaced %d reference(s): %s becomes %s." % [int(counter["count"]), from_ref, to_ref])
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


## Batch param edit (C3's edit-many reflex): any condition/action that appears more than
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


func _toggle_live_values() -> void:
	_ensure_live_values_panel().toggle()


func _ensure_live_values_window() -> void:
	_ensure_live_values_panel().ensure_window()


func update_live_values(values: Dictionary) -> void:
	_ensure_live_values_panel().update_values(values)


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
		_set_status("⏸ Paused at this row (sheet breakpoint).")
		return


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
	_find_bar_glue._find_step(direction)


func _replace_all_in_sheet() -> void:  # Replace All button + project_find + tests
	_find_bar_glue._replace_all_in_sheet()


func _replace_in_rows(rows: Array, find_text: String, replace_text: String, counter: Dictionary) -> void:  # project_find + with_node_editor_test
	_find_bar_glue._replace_in_rows(rows, find_text, replace_text, counter)

# ── Group color tags ──────────────────────────────────────────────────────────────────
var _group_color_popup: PopupPanel = null
var _group_color_picker: ColorPickerButton = null
var _group_color_target: EventGroup = null


## Opt-in runtime toggling: the group compiles a guard member that Set Group Active
## flips at runtime (feature flags, debug switches). Off = zero-cost organization.
func _toggle_group_runtime() -> void:
	var target: Resource = _context_row.source_resource if _context_row != null else null
	if not (target is EventGroup):
		_set_status("Right-click a group to make it runtime-toggleable.", true)
		return
	var group: EventGroup = target
	var changed: bool = _perform_undoable_sheet_edit("Runtime Toggleable", func() -> bool:
		group.runtime_toggleable = not group.runtime_toggleable
		return true
	)
	if changed:
		_refresh_after_edit()
		_mark_dirty("Group \"%s\" is %s - Set Group Active targets \"%s\"." % [group.group_name, "runtime-toggleable" if group.runtime_toggleable else "compile-time only again", group.group_name.to_snake_case()])


## Event-sheet-style group colors: tint the selected group's accent/background (clear = theme).
func _open_group_color_picker() -> void:
	var target: Resource = _context_row.source_resource if _context_row != null else null
	if not (target is EventGroup):
		_set_status("Right-click a group to color it.", true)
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
	_group_color_picker.color = target.custom_color if target.custom_color.a > 0.0 else Color(0.55, 0.45, 0.85, 1.0)
	_group_color_popup.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), Vector2i(220, 42)))


func _apply_group_color(value: Color) -> void:
	if _group_color_target == null:
		return
	var target: EventGroup = _group_color_target
	var changed: bool = _perform_undoable_sheet_edit("Group Color", func() -> bool:
		if target.custom_color == value:
			return false
		target.custom_color = value
		return true
	)
	if changed:
		_refresh_after_edit()
		_mark_dirty("Group color updated.")

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
		_set_status("No issues found - every ƒx expression and GDScript block compiles.")

## Fixed structural keys (not rebindable - they're grammar, not preference): shown read-only in the
## Keyboard Shortcuts editor as [keys, action], for reference. The rebindable authoring keys come
## live from EventSheetShortcuts so the editor always shows the user's actual bindings.
const FIXED_KEYS: Array = [
	["Enter / F2", "Edit the selected row"],
	["Tab / Shift+Tab", "Nest / un-nest the event"],
	["Alt + Up / Down", "Move the row up / down"],
	["Left / Right", "Fold / unfold a group"],
	["Up / Down", "Select previous / next row"],
	["Shift + Up / Down", "Extend the row selection"],
	["Delete", "Delete the selection"],
	["Ctrl + F", "Find & Replace"],
	["F3 / Shift+F3", "Find next / previous"],
	["Ctrl + P", "Command Palette"],
	["F9 / Ctrl+B", "Toggle breakpoint"],
	["Ctrl + M", "Toggle bookmark"],
	["Ctrl + +  /  Ctrl + -", "Zoom in / out"],
	["Esc", "Close a popup / cancel an edit"],
]


# ── Keyboard Shortcuts editor (Tools menu; FIXED_KEYS above stays here) → event_sheet_shortcuts_dialog.gd ──
func _open_shortcuts_help() -> void:
	_shortcuts.open()


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

# ── Outline panel - extracted to dock/outline_panel.gd ───────────────────────────────
var _outline_panel: EventSheetOutlinePanel = null


func _ensure_outline_panel() -> EventSheetOutlinePanel:
	if _outline_panel == null:
		_outline_panel = EventSheetOutlinePanel.new(self)
	return _outline_panel


func _open_outline_panel() -> void:
	_ensure_outline_panel().open()


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


func _quick_match_ranked(query: String, limit: int = 5) -> Array:  # dock/ghost_row.gd suggestion list
	return _author_actions._quick_match_ranked(query, limit)


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


## Persists an object-column resize (the C3 sub-lane between object names and display text),
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
	# The C3 gesture in full: double-click empty space leads with OBJECT cards (System,
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
		EMPTY_MENU_INSERT_SNIPPET:
			_open_insert_snippet()


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


func _on_row_context_menu_id_pressed(id: int) -> void:
	_input_dispatch.on_row_context_menu_id_pressed(id)


## Select All Matching (the C3 "find my other uses" reflex): selects every event in the
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


## S - add a picker-backed sub-event under the selected event (Construct's add-sub-event key).
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
## (undoing a Cut restores the rows and the clipboard still holds the copy - C3's behaviour).
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
	_refresh_variable_panel()
	_update_code_panel_highlight()
	if _exposed_node != null and _viewport != null:
		_exposed_node.set_row_context(_active_view().get_selected_ace_resource())


func _on_viewport_span_edit_requested(row_data: EventRowData, edit_kind: String, old_value: String, new_value: String) -> void:
	if row_data == null or row_data.source_resource == null:
		return
	if old_value == new_value:
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
			"event_comment":
				if row_data.source_resource is EventRow:
					(row_data.source_resource as EventRow).comment = new_value
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
	_refresh_variable_panel()
	_refresh_code_panel()
	_refresh_anatomy_panel()
	_refresh_functions_list()


# Live-reload binding to the active theme .tres → dock/theme_manager.gd. Called from _activate_tab /
# _refresh_after_edit (via _theme_manager._sync_active_theme_binding directly); the delegate stays for
# any external caller reaching the original name.
func _sync_active_theme_binding() -> void:
	_theme_manager._sync_active_theme_binding()


func _mark_dirty(message: String) -> void:
	_dirty = true
	_refresh_title_strip()
	_set_status("%s%s" % [message, " *" if _dirty else ""])


func _set_status(text: String, is_error: bool = false) -> void:
	if _status_label == null:
		return
	# A leading ⚠ marks errors textually (not just by colour - colour-blind-safe and more salient so
	# a "won't compile / save failed" isn't missed). The full text is on the tooltip since the status
	# bar truncates long messages.
	_status_label.text = ("⚠  %s" % text) if is_error else text
	_status_label.tooltip_text = text
	_status_label.modulate = Color(1.0, 0.48, 0.48) if is_error else Color(1.0, 1.0, 1.0)
	# Tiered presence: an error keeps its full-strength red until something replaces it, while an
	# informational message fades to muted after a few seconds - a stale tip should never carry
	# the same visual weight as fresh feedback (236 call sites share this one label).
	if _status_fade_tween != null:
		_status_fade_tween.kill()
		_status_fade_tween = null
	if not is_error and is_inside_tree():
		_status_fade_tween = create_tween()
		_status_fade_tween.tween_interval(6.0)
		_status_fade_tween.tween_property(_status_label, "modulate:a", 0.45, 1.5)


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


static func _format_sheet_title(sheet: EventSheetResource, explicit_path: String) -> String:
	if sheet == null:
		return "No Sheet Loaded"
	var resolved_path: String = _resolve_sheet_path(sheet, explicit_path)
	if resolved_path.is_empty():
		return "Untitled EventSheet"
	return resolved_path.get_file().get_basename()


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
			# Must match get_provider_id's fallback (capitalize(), "My Bus") - the trigger
			# baking looks this map up BY definition.provider_id, so a pascal-case key here
			# silently skipped autoload trigger baking for class_name-less scripts.
			provider_class = autoload_path.get_file().get_basename().capitalize()
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


func _build_demo_sheet() -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.variables["health"] = {"type": "int", "default": 100}
	sheet.variables["score"] = {"type": "int", "default": 0}

	var intro_comment := CommentRow.new()
	intro_comment.text = "Drag a node into the viewport to preview the actions and conditions it offers."
	sheet.events.append(intro_comment)

	# A tiny, fully code-free example that ALWAYS compiles, so the Generated GDScript panel matches
	# exactly what you see. Built from Core ACEs with BAKED templates (the reflected demo-actor
	# provider isn't in the compiler's registry, so its rows used to silently produce no code - the
	# preview then disagreed with the sheet). The drag-a-node-to-preview flow still showcases AutoACE.
	var tick := EventRow.new()
	tick.event_uid = "demo_tick"
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var score_up := _make_action("Core", "AddVar", {"var_name": "score", "amount": "1"})
	score_up.codegen_template = "{var_name} += {amount}"
	var health_down := _make_action("Core", "SubtractVar", {"var_name": "health", "amount": "1"})
	health_down.codegen_template = "{var_name} -= {amount}"
	tick.actions = [score_up, health_down]
	tick.comment = "Auto-generated example - every row is an event, no GDScript"
	sheet.events.append(tick)

	return sheet


func _make_action(provider_id: String, ace_id: String, params: Dictionary) -> ACEAction:
	var action := ACEAction.new()
	action.provider_id = provider_id
	action.ace_id = ace_id
	action.params = params.duplicate(true)
	return action


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
	return true


func _clear_undo_history() -> void:
	_undo_redo_adapter.clear_history()


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
