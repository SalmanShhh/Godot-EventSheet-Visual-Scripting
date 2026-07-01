@tool
class_name EventSheetDock
extends Control

# .gd is listed first so it is the default format for New Sheet / Save As — a sheet is just plain
# GDScript (no .tres needed). .tres/.res stay available (e.g. library sheets used via Includes).
const EVENT_SHEET_FILTERS: Array[String] = ["*.gd ; GDScript EventSheet", "*.tres ; EventSheetResource", "*.res ; EventSheetResource"]
const CONDITION_MENU_EDIT := 1
const CONDITION_MENU_ADD := 2
const CONDITION_MENU_REPLACE := 3
const CONDITION_MENU_INVERT := 4
const CONDITION_MENU_DELETE := 5
const CONDITION_MENU_TOGGLE_ENABLED := 6
const CONDITION_MENU_EDIT_ACE_COMMENT := 21
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
const VARIABLE_MENU_EDIT := 1
const VARIABLE_MENU_CONVERT_SCOPE := 2
const VARIABLE_MENU_TOGGLE_CONST := 3
const VARIABLE_MENU_RENAME := 4
const THEME_FILTERS: Array[String] = ["*.tres ; EventSheetEditorStyle", "*.res ; EventSheetEditorStyle"]
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
## Emitted whenever the open-tab set, the active tab, or a tab's dirty flag changes — the
## Open Sheets dock (a left editor dock) listens and re-renders its list.
signal open_tabs_changed

var _open_tabs: Array[Dictionary] = []
var _active_tab_index: int = -1
var _tab_bar: TabBar = null
var _recent_closed_paths: Array[String] = []  # MRU of recently-closed tab paths (capped) — the Open Sheets dock offers to reopen them
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
var _clipboard: Dictionary = {}
var _undo_redo_adapter: EventSheetUndoRedoAdapter = EventSheetUndoRedoAdapter.new()

# ── Extracted sub-components ─────────────────────────────────────────────────
var _ace_picker: ACEPickerDialog = ACEPickerDialog.new()
var _ace_params: ACEParamsDialog = ACEParamsDialog.new()
var _variable_dlg: VariableDialog = VariableDialog.new()
var _new_addon_panel: EventSheetNewAddonPanel = EventSheetNewAddonPanel.new()  # Sheet ▸ New Behaviour Addon… (dock/new_addon_panel.gd)
var _welcome: EventSheetWelcomeWindow = EventSheetWelcomeWindow.new()  # Tools ▸ Welcome… onboarding window (dock/welcome_window.gd)
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
var _menu_bar: EventSheetMenuBar = EventSheetMenuBar.new()  # top toolbar + grouped Sheet/Add/Edit/View/Tools menus + theme picker + quick-add (dock/menu_bar.gd)
var _context_menus: EventSheetContextMenus = EventSheetContextMenus.new()  # right-click context menus: condition/action/row/variable/empty-space build + per-click configure (dock/context_menus.gd)
var _external_watcher: EventSheetExternalWatcher = EventSheetExternalWatcher.new()  # GDScript-backed sheet file-watch + reload-on-disk-change dialog (dock/external_watcher.gd)
var _sheet_io: EventSheetSheetIO = EventSheetSheetIO.new()  # sheet FILE-IO: open-from-disk + every write-back path (Save/Save As/Export/Save-as-.gd) (dock/sheet_io.gd)
var _ace_apply: EventSheetACEApply = EventSheetACEApply.new()  # ACE application (condition/action/trigger baking + insert) + row/ACE drag-drop reorder (dock/ace_apply.gd)
var _row_edit_ops: EventSheetRowEditOps = EventSheetRowEditOps.new()  # context-menu row/ACE edit ops: enable/disable, delete, indent/outdent, else, insert, bulk-selection, invert/OR-AND (dock/row_edit_ops.gd)
var _preview_glue: EventSheetPreviewGlue = EventSheetPreviewGlue.new()  # .gd-preview banner + "Edit Events" unlock + Open-in-Godot script-editor glue + lift-report window (dock/preview_glue.gd)
var _condition_context_menu: PopupMenu = null
var _action_context_menu: PopupMenu = null
var _row_context_menu: PopupMenu = null
var _row_insert_submenu: PopupMenu = null
var _row_more_submenu: PopupMenu = null
var _variable_context_menu: PopupMenu = null
var _empty_space_context_menu: PopupMenu = null
var _theme_file_dialog: FileDialog = null
var _context_row: EventRowData = null
var _context_hit: Dictionary = {}
var _active_theme_style: EventSheetEditorStyle = null
## Simple mode (progressive disclosure for artist-first / first-time users): trims the
## right-click menus to the everyday authoring verbs and hides the advanced/code-leaning
## entries (GDScript blocks, sub-conditions, pick filters, match, signals/enums). Persisted
## per-project in editor metadata; defaults off so existing/expert users are unaffected.
var _simple_mode: bool = false
var _view_popup: PopupMenu = null
# Command palette (Ctrl+P): keyboard-first access to every dock action — list + fuzzy filter +
# popup shell live on _command_palette (dock/command_palette.gd); the action targets stay here.

func _init() -> void:
	if not _undo_redo_adapter.has_manager():
		_undo_redo_adapter.set_manager(UndoRedo.new())
	# Wire the file-IO helper's back-reference up front (init() only stores _dock — nothing
	# tree-bound), so a delegate like _load_sheet_from_path works even when a test calls it on a
	# fresh .new() editor BEFORE _ready/setup run the rest of the lazy init cluster. The helper's
	# _dock.setup() then triggers _ensure_editor_dialogs_initialized() exactly as the inline body did.
	_sheet_io.init(self)
	# Same reason as _sheet_io: a test may apply an ACE (or exercise drag-drop) on a fresh .new()
	# editor before _ready. init() only stores _dock, so wiring it here (and again in the cluster) is safe.
	_ace_apply.init(self)
	# Row/ACE edit-ops helper: same fresh-.new()-before-_ready reasoning — tests exercise ops like
	# _bulk_set_enabled_on / _toggle_selected_enabled / _indent_selected_event before the tree init runs.
	_row_edit_ops.init(self)
	# Preview-glue helper MUST be wired before _build_ui(): _build_ui calls
	# _preview_glue.build_preview_banner(), which assigns _preview_banner/_preview_label back on the dock.
	_preview_glue.init(self)
	_build_ui()

var _editor_dialogs_initialized: bool = false

# Initializes the picker/params/variable dialogs and wires their signals + providers.
# Idempotent (guarded by _editor_dialogs_initialized) and safe to run detached: it only
# touches dialog init + signal connections + provider wiring — nothing tree-bound. Called
# from _ready() in the real editor AND from setup() so headless tests (which never enter
# the tree, so _ready never fires) still get initialized dialogs.
func _ensure_editor_dialogs_initialized() -> void:
	if _editor_dialogs_initialized:
		return
	_editor_dialogs_initialized = true
	_load_simple_mode_preference()
	_param_resolver.set_param_store(_editor_param_store)
	_ace_picker.init_dialog(self, _ace_registry)
	_ace_picker.set_simple_mode_provider(func() -> bool: return _simple_mode)
	_ace_picker.ace_selected.connect(_on_ace_picker_selected)
	_ace_params.init_dialog(self, _ace_registry, _collect_sheet_variable_names)
	_ace_params.set_lint_context_provider(func() -> EventSheetResource: return _current_sheet)
	_ace_params.set_variable_creator(_create_variable_quickfix)
	_ace_params.params_confirmed.connect(_on_ace_params_confirmed)
	_ace_params.back_requested.connect(_on_ace_params_back_requested)
	_variable_dlg.init_dialog(self)
	_new_addon_panel.init(self)
	_welcome.init(self)
	_starter.init(self)
	_comments.init(self)
	_struct_rows.init(self)
	_inline_params.init(self)
	_doctor.init(self)
	_includes.init(self)
	_find_refs.init(self)
	_pick.init(self)
	_ai.init(self)
	_sheet_type.init(self)
	_session.init(self)
	_shortcuts.init(self)
	_rename.init(self)
	_variables.init(self)
	_multi_view.init(self)
	_command_palette.init(self)
	_context_menus.init(self)
	_external_watcher.init(self)
	_sheet_io.init(self)
	_ace_apply.init(self)
	_row_edit_ops.init(self)
	_preview_glue.init(self)
	# Feed the active sheet so the name field can flag host-member shadowing (live + blocking).
	_variable_dlg.set_sheet_provider(func() -> EventSheetResource: return _current_sheet)
	_variable_dlg.variable_confirmed.connect(_on_variable_dialog_confirmed)
	# Sheet enums feed the variable dialog's one-click combo fill.
	_variable_dlg.set_enum_provider(func() -> Array:
		var sheet_enums: Array = []
		if _current_sheet != null:
			for row: Variant in _current_sheet.events:
				if row is EnumRow and (row as EnumRow).enabled:
					sheet_enums.append({"name": (row as EnumRow).enum_name, "members": (row as EnumRow).members})
		return sheet_enums)

func _ready() -> void:
	_build_ui()
	_ensure_editor_dialogs_initialized()
	_refresh_ace_registry()
	# Restore last session's tabs FIRST (editor only; headless tests drive setup() directly). Only fall
	# back to a blank starting sheet when nothing came back — otherwise an untitled demo stacks on top of
	# the user's real tabs. The plugin ALSO calls setup() right after add_child() (which already ran this
	# _ready), so the setup() below is a no-op once tabs exist — see setup()'s guard. This is what stopped
	# the "two untitled sheets on open" (a demo from _ready + a demo from the plugin's setup()).
	if Engine.is_editor_hint() and is_inside_tree():
		_restore_session()
	if _open_tabs.is_empty():
		if _current_sheet == null:
			_current_sheet = _build_demo_sheet()
			_viewport.set_debug_overlay_states({})
		setup(_current_sheet)

func setup(sheet: EventSheetResource = null) -> void:
	_build_ui()
	_ensure_editor_dialogs_initialized()
	# Idempotent initial state: a null setup() asks for "a blank starting sheet". If tabs already exist
	# (the plugin calls setup() right after add_child(), which already ran _ready), don't stack a second
	# untitled demo — keep what's open. A null setup() with no tabs still seeds one demo, as before.
	if sheet == null and not _open_tabs.is_empty():
		return
	var target_sheet: EventSheetResource = sheet if sheet != null else _build_demo_sheet()
	var target_path: String = sheet.resource_path if sheet != null else ""
	_open_sheet_in_tab(target_sheet, target_path)

## Opens a sheet in a tab — activating its existing tab if already open, else adding one.
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
	_sync_active_theme_binding()
	_refresh_title_strip()
	_refresh_theme_picker_selection()
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
## empty paths are skipped — there's nothing to reopen.
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
## already-active sheet must re-focus, not reload — reloading clears the viewport and wipes
## the sheet's undo/redo history, so swallow the no-op here (the dock allows reselect).
func activate_open_tab(index: int) -> void:
	if index == _active_tab_index:
		return
	_activate_tab(index)

## Reopen a recently-closed sheet by path (Open Sheets dock click). Drops it from the MRU
## first — _load_sheet_from_path opens or re-focuses it as a tab.
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

func use_default_theme() -> bool:
	if _current_sheet == null or _current_sheet.editor_style == null:
		return false
	# Out of undo history, like every theme switch (presentation, not content).
	_current_sheet.editor_style = null
	_refresh_after_edit()
	return true

func load_theme_style_from_path(path: String) -> bool:
	if _current_sheet == null:
		return false
	var resolved_path: String = path.strip_edges()
	if resolved_path.is_empty():
		_set_status("Theme load failed: no file selected.", true)
		return false
	var loaded: Resource = ResourceLoader.load(resolved_path)
	if not (loaded is EventSheetEditorStyle):
		_set_status("Theme load failed: %s is not an EventSheetEditorStyle." % resolved_path.get_file(), true)
		return false
	# Theme switches stay OUT of the undo history (user call: undo is for sheet
	# content — ACEs and variables — never presentation). Still marks dirty: the
	# style is persisted on the sheet.
	_current_sheet.editor_style = loaded as EventSheetEditorStyle
	_refresh_after_edit()
	_mark_dirty("Applied theme: %s." % resolved_path.get_file())
	return true

func reload_active_theme() -> bool:
	if _current_sheet == null:
		_set_status("Reload theme failed: no sheet loaded.", true)
		return false
	var active_style: EventSheetEditorStyle = _current_sheet.editor_style
	if active_style == null:
		_set_status("Reload theme failed: no active style.", true)
		return false
	var style_path: String = active_style.resource_path
	if style_path.is_empty():
		_set_status("Reload theme failed: active style is unsaved.", true)
		return false
	var reloaded: Resource = ResourceLoader.load(style_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not (reloaded is EventSheetEditorStyle):
		_set_status("Reload theme failed: could not load resource.", true)
		return false
	_current_sheet.editor_style = reloaded as EventSheetEditorStyle
	_refresh_after_edit()
	return true

func set_undo_redo_manager(undo_redo: Variant) -> void:
	if undo_redo == null:
		return
	_undo_redo_adapter.set_manager(undo_redo)
	if _exposed_node != null:
		_exposed_node.set_undo_redo_manager(_undo_redo_adapter.get_manager())
	if not _exposed_node.row_param_changed.is_connected(_on_exposed_row_param_changed):
		_exposed_node.row_param_changed.connect(_on_exposed_row_param_changed)

func set_auto_ace_sources(sources: Array[Object]) -> void:
	_manual_ace_sources = sources.duplicate()
	_refresh_ace_registry()

## Registers a GDScript file as a custom-ACE provider on the current sheet. Its annotated
## methods/signals/exported properties then appear in the ACE picker.
func add_ace_provider_script(path: String) -> bool:
	if not _ensure_sheet_for_editing():
		return false
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty() or _current_sheet.ace_provider_scripts.has(clean_path):
		return false
	var probe: Object = _instantiate_provider_script(clean_path)
	if probe == null:
		_set_status("Not a usable ACE provider script: %s" % clean_path.get_file(), true)
		return false
	if probe is Node:
		(probe as Node).free()
	var changed: bool = _perform_undoable_sheet_edit("Add ACE Provider", func() -> bool:
		_current_sheet.ace_provider_scripts.append(clean_path)
		return true
	)
	if changed:
		_refresh_ace_registry()
		_refresh_provider_list()
		_mark_dirty("Added ACE provider: %s" % clean_path.get_file())
	return changed

## Removes a registered custom-ACE provider script from the current sheet.
func remove_ace_provider_script(path: String) -> bool:
	if not _ensure_sheet_for_editing():
		return false
	if not _current_sheet.ace_provider_scripts.has(path):
		return false
	var changed: bool = _perform_undoable_sheet_edit("Remove ACE Provider", func() -> bool:
		_current_sheet.ace_provider_scripts.erase(path)
		return true
	)
	if changed:
		_refresh_ace_registry()
		_refresh_provider_list()
		_mark_dirty("Removed ACE provider: %s" % path.get_file())
	return changed

func get_ace_provider_scripts() -> PackedStringArray:
	var output: PackedStringArray = PackedStringArray()
	if _current_sheet == null:
		return output
	for path: Variant in _current_sheet.ace_provider_scripts:
		output.append(str(path))
	return output

func _on_manage_ace_providers_requested() -> void:
	if not _ensure_sheet_for_editing():
		return
	_build_provider_dialog()
	_refresh_provider_list()
	_provider_dialog.popup_centered(Vector2i(560, 420))

func _build_provider_dialog() -> void:
	if _provider_dialog != null:
		return
	_provider_dialog = Window.new()
	_provider_dialog.title = "Custom ACE Providers"
	_provider_dialog.visible = false
	_provider_dialog.min_size = Vector2i(460, 320)
	_provider_dialog.close_requested.connect(func() -> void: _provider_dialog.hide())
	add_child(_provider_dialog)

	var content: VBoxContainer = EventSheetPopupUI.form_box()
	var margin: MarginContainer = EventSheetPopupUI.margined(content)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_provider_dialog.add_child(margin)

	content.add_child(EventSheetPopupUI.hint_label("Register GDScript files whose methods, signals and exported variables become custom ACEs.\nZero-config alternative: drop scripts into res://eventsheet_addons/ and they register project-wide automatically."))

	var providers_box: VBoxContainer = EventSheetPopupUI.form_box()

	_provider_list = ItemList.new()
	_provider_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_provider_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	providers_box.add_child(_provider_list)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	providers_box.add_child(buttons)
	var add_button: Button = Button.new()
	add_button.text = "Add…"
	add_button.pressed.connect(_on_provider_add_pressed)
	buttons.add_child(add_button)
	var remove_button: Button = Button.new()
	remove_button.text = "Remove Selected"
	remove_button.pressed.connect(_on_provider_remove_pressed)
	buttons.add_child(remove_button)
	var open_in_godot_button: Button = Button.new()
	open_in_godot_button.text = "Open in Godot Script Editor"
	open_in_godot_button.tooltip_text = "Open the selected provider script in Godot's script editor."
	open_in_godot_button.pressed.connect(_on_provider_open_in_godot_pressed)
	buttons.add_child(open_in_godot_button)

	var providers_card: PanelContainer = EventSheetPopupUI.titled_card("Providers", providers_box)
	providers_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(providers_card)

	_provider_file_dialog = FileDialog.new()
	_provider_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_provider_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_provider_file_dialog.filters = PackedStringArray(["*.gd ; GDScript"])
	_provider_file_dialog.file_selected.connect(_on_provider_file_selected)
	_provider_dialog.add_child(_provider_file_dialog)

func _refresh_provider_list() -> void:
	if _provider_list == null:
		return
	_provider_list.clear()
	for path in get_ace_provider_scripts():
		_provider_list.add_item(path)

func _on_provider_add_pressed() -> void:
	if _provider_file_dialog != null:
		_provider_file_dialog.popup_centered(Vector2i(720, 520))

func _on_provider_file_selected(path: String) -> void:
	add_ace_provider_script(path)

func _on_provider_remove_pressed() -> void:
	if _provider_list == null:
		return
	var selected: PackedInt32Array = _provider_list.get_selected_items()
	if selected.is_empty():
		return
	remove_ace_provider_script(_provider_list.get_item_text(selected[0]))

func _build_ui() -> void:
	if _toolbar != null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root: VBoxContainer = VBoxContainer.new()
	root.name = "EventSheetWorkspaceRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# Toolbar redesign: grouped by purpose (Sheet / Add / Edit / View / Tools menus)
	# with only the high-frequency reflexes as one-click buttons — and it FLOWS to
	# a second row instead of clipping when the panel is narrow (the old single HBox
	# of ~28 controls overflowed past the panel edge).
	# The toolbar + grouped Sheet/Add/Edit/View/Tools menus + theme picker + quick-add
	# are built by the extracted EventSheetMenuBar; it adds _toolbar as root's FIRST child
	# and assigns _toolbar/_view_popup/_theme_picker/_quick_add_edit back onto the dock.
	_menu_bar.init(self)
	_menu_bar.build(root)

	_tab_bar = TabBar.new()
	_tab_bar.name = "EventSheetTabBar"
	_tab_bar.clip_tabs = true
	_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ALWAYS
	_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bar.tab_selected.connect(_on_tab_selected)
	_tab_bar.tab_close_pressed.connect(_on_tab_close_pressed)
	root.add_child(_tab_bar)

	_title_strip = HBoxContainer.new()
	_title_strip.name = "EventSheetTitleStrip"
	_title_strip.add_theme_constant_override("separation", 8)
	root.add_child(_title_strip)

	var title_tab_shell: PanelContainer = PanelContainer.new()
	title_tab_shell.name = "EventSheetTitleTab"
	_title_strip.add_child(title_tab_shell)

	var title_tab_content: HBoxContainer = HBoxContainer.new()
	title_tab_content.add_theme_constant_override("separation", 4)
	title_tab_shell.add_child(title_tab_content)

	_title_tab_label = Label.new()
	_title_tab_label.name = "EventSheetTitleTabLabel"
	_title_tab_label.text = "No Sheet Loaded"
	title_tab_content.add_child(_title_tab_label)

	_title_dirty_dot = Label.new()
	_title_dirty_dot.name = "EventSheetTitleDirtyDot"
	_title_dirty_dot.text = "●"
	_title_dirty_dot.modulate = Color(0.99, 0.78, 0.30, 1.0)
	_title_dirty_dot.visible = false
	title_tab_content.add_child(_title_dirty_dot)

	_title_path_label = Label.new()
	_title_path_label.name = "EventSheetTitlePath"
	_title_path_label.modulate = Color(0.72, 0.76, 0.84, 1.0)
	_title_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_path_label.clip_text = true
	_title_path_label.text = "Open or create a sheet to begin"
	_title_strip.add_child(_title_path_label)

	# Pinned Conditions/Actions column header, above the scrolling sheet (bound to the
	# viewport once it exists). Kept outside the scroll so the scroll still has a single child.
	_identity_banner = SheetIdentityBanner.new()
	root.add_child(_identity_banner)
	_identity_banner.edit_requested.connect(_open_sheet_type_dialog)

	# Read-only preview banner (a .gd opened just to look at it) — hidden for normal sheets.
	_preview_banner = _preview_glue.build_preview_banner()
	root.add_child(_preview_banner)

	_column_header = SheetColumnHeader.new()
	root.add_child(_column_header)

	_scroll = ScrollContainer.new()
	_scroll.name = "EventSheetScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Wrap the viewport in _content_host, then sit it beside the Open Sheets panel in _workspace_body.
	_content_host = VBoxContainer.new()
	_content_host.name = "EventSheetContentHost"
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_host.add_child(_scroll)
	_open_sheets_panel = EventSheetOpenSheetsDock.new()
	_open_sheets_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_open_sheets_panel.activate_requested.connect(activate_open_tab)
	_open_sheets_panel.reopen_requested.connect(reopen_sheet_path)
	_open_sheets_panel.collapse_toggled.connect(_on_open_sheets_panel_collapsed)
	open_tabs_changed.connect(_refresh_open_sheets_panel)
	_workspace_body = HSplitContainer.new()
	_workspace_body.name = "EventSheetWorkspaceBody"
	_workspace_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workspace_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workspace_body.add_child(_open_sheets_panel)
	_workspace_body.add_child(_content_host)
	root.add_child(_workspace_body)
	_apply_open_sheets_panel_prefs()

	_viewport = EventSheetViewport.new()
	_viewport.name = "EventSheetViewport"
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(_ace_registry)
	_scroll.add_child(_viewport)
	_column_header.setup(_viewport)
	_identity_banner.setup(_viewport)

	_viewport.selection_changed.connect(_on_viewport_selection_changed)
	_viewport.selection_changed.connect(func(row_data: EventRowData) -> void:
		if _mirroring_selection:
			return  # a mirrored selection must not steal the active view
		_active_viewport_ref = _viewport
		_mirror_selection(_viewport, row_data)
	)
	_viewport.row_drop_requested.connect(_on_row_drop_requested)
	_viewport.rows_drop_requested.connect(_on_rows_drop_requested)
	_viewport.ace_preview_requested.connect(_on_ace_preview_requested)
	_viewport.asset_dropped.connect(_apply_asset_drop)
	_viewport.ace_picker_requested.connect(_on_viewport_ace_picker_requested)
	_viewport.span_edit_requested.connect(_on_viewport_span_edit_requested)
	_viewport.ace_edit_requested.connect(_on_viewport_ace_edit_requested)
	_viewport.param_value_edit_requested.connect(_on_param_value_edit_requested)
	_viewport.color_swatch_edit_requested.connect(_on_color_swatch_edit_requested)
	_viewport.param_node_drop_requested.connect(_on_param_node_drop_requested)
	_viewport.variable_edit_requested.connect(_on_viewport_variable_edit_requested)
	_viewport.comment_edit_requested.connect(_open_comment_dialog)
	_viewport.group_edit_requested.connect(_on_group_edit_requested)
	_viewport.pick_filter_edit_requested.connect(_open_pick_filter_dialog)
	_viewport.with_node_edit_requested.connect(_open_with_node_dialog)
	_viewport.enum_edit_requested.connect(_open_enum_dialog)
	_viewport.signal_edit_requested.connect(_open_signal_dialog)
	_viewport.match_edit_requested.connect(_open_match_dialog)
	_viewport.row_disable_toggle_requested.connect(_toggle_selected_rows_enabled)
	_viewport.row_move_requested.connect(_move_selected_row)
	_viewport.delete_requested.connect(_delete_selected_content)
	_viewport.find_requested.connect(_show_find_bar)
	_viewport.find_step_requested.connect(_find_step)
	_apply_editor_native_defaults()
	_viewport.ace_drop_requested.connect(_on_viewport_ace_drop_requested)
	_viewport.drag_status_requested.connect(_on_viewport_drag_status_requested)
	_viewport.lane_ratio_changed.connect(_on_viewport_lane_ratio_changed)
	_viewport.add_event_requested.connect(_on_viewport_add_event_requested)
	_viewport.raw_code_edit_requested.connect(_on_viewport_raw_code_edit_requested)
	_viewport.context_menu_requested.connect(_on_viewport_context_menu_requested)
	_viewport.empty_space_double_clicked.connect(_on_viewport_empty_space_double_clicked)
	_viewport.empty_space_context_menu_requested.connect(_on_viewport_empty_space_context_menu_requested)
	_viewport.set_external_span_edit_handler_enabled(true)

	_status_label = Label.new()
	_status_label.name = "EventSheetStatus"
	_status_label.text = "Ready"
	root.add_child(_status_label)

	_exposed_node.name = "EventSheetExposedParams"
	add_child(_exposed_node)
	_exposed_node.setup(_ace_registry, _editor_param_store, _current_sheet, _param_resolver)
	_exposed_node.set_undo_redo_manager(_undo_redo_adapter.get_manager())
	# The right-click context menus (condition/action/row/variable/empty-space) are built by the
	# extracted EventSheetContextMenus; build_all() constructs each and assigns it back onto the dock
	# (the _*_context_menu / _row_*_submenu members the dock + tests read by name). init() only stores
	# the _dock back-reference, so wiring it here — before any context-menu site runs — is enough.
	_context_menus.init(self)
	_context_menus.build_all()
	_build_preview_window()
	_build_theme_file_dialog()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _active_theme_style != null and _active_theme_style.changed.is_connected(_on_active_theme_style_changed):
			_active_theme_style.changed.disconnect(_on_active_theme_style_changed)
		_active_theme_style = null
		_release_ace_sources()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# GDScript-backed sheets: refocusing the editor is the moment external edits (the
		# script editor, another tool, git) usually land — offer to reload from disk. This is also
		# what carries "Open in Godot" edits back into a backed sheet (the .gd changed on disk).
		_prompt_external_reload_if_changed()
	elif what == NOTIFICATION_THEME_CHANGED and is_inside_tree():
		# The user switched their editor theme — re-derive the "Match Editor" default
		# (no-op when an explicit sheet theme is active) and re-skin the code panel.
		# apply_zoom=false: never reset the user's manual zoom on a theme change.
		_apply_editor_native_defaults(false)
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

func _build_theme_file_dialog() -> void:
	if _theme_file_dialog != null:
		return
	_theme_file_dialog = FileDialog.new()
	_theme_file_dialog.name = "EventSheetThemeFileDialog"
	_theme_file_dialog.title = "Load EventSheet Theme"
	_theme_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_theme_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_theme_file_dialog.filters = PackedStringArray(THEME_FILTERS)
	_theme_file_dialog.file_selected.connect(_on_theme_file_selected)
	add_child(_theme_file_dialog)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE and _ace_picker.is_open():
		_ace_picker.close()
		accept_event()
		return
	# Structural/letter shortcuts are suppressed while typing in a text field so authoring
	# keys never fire mid-edit (text fields already consume their own text shortcuts).
	var typing: bool = _text_field_has_focus()
	var shift: bool = key_event.shift_pressed
	# Rebindable shortcuts (EventSheetShortcuts — edit via Tools ▸ Keyboard Shortcuts, saved per-user):
	# exact modifier matching, so a chord never shadows its plain form. Entries:
	# [action, suppressed-while-typing, handler]. Core reflexes by default: E event,
	# C condition, A action, Q comment, G group, X toggle.
	for entry: Array in [
		["add_condition_chord", true, _on_add_condition_requested],
		["add_action_chord", true, _on_add_action_requested],
		["add_variable_chord", true, _on_add_global_variable_requested],
		["add_event_chord", true, _on_add_event_requested],
		["duplicate", true, _on_duplicate_requested],
		["save_as", false, _on_save_as_requested],
		["save", false, _on_save_requested],
		["open", false, _on_open_requested],
		["copy", false, _on_copy_requested],
		["paste", false, _on_paste_requested],
		["redo", false, _on_redo_requested],
		["undo", false, _on_undo_requested],
		["add_comment", true, _on_add_comment_requested],
		["add_event", true, _on_add_event_requested],
		["add_condition", true, _on_add_condition_requested],
		["add_action", true, _on_add_action_requested],
		["add_group", true, _on_add_group_requested],
		["toggle_enabled", true, _toggle_selected_enabled],
	]:
		if EventSheetShortcuts.matches(key_event, str(entry[0])):
			if bool(entry[1]) and typing:
				return  # let the text field keep the keystroke
			(entry[2] as Callable).call()
			accept_event()
			return
	# Fixed alternates + structural keys (grammar, not preference — never rebindable):
	# Ctrl+Y redo, Ctrl+± zoom, Tab nesting, Delete, Enter/F2 inline edit.
	if key_event.ctrl_pressed or key_event.meta_pressed:
		if key_event.keycode == KEY_P:
			_open_command_palette()
			accept_event()
		elif key_event.keycode == KEY_Y:
			_on_redo_requested()
			accept_event()
		elif key_event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
			_on_zoom_in_requested()
			accept_event()
		elif key_event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_on_zoom_out_requested()
			accept_event()
		return
	if typing:
		return
	if key_event.keycode == KEY_TAB and shift:
		# Outdent (un-nest); only consume Tab when the move actually applies so normal
		# focus traversal still works when there is nothing to outdent.
		if _outdent_selected_event():
			accept_event()
	elif key_event.keycode == KEY_TAB:
		if _indent_selected_event():
			accept_event()
	elif key_event.keycode == KEY_BACKTAB:
		if _outdent_selected_event():
			accept_event()
	elif key_event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		_delete_selected_content()
		accept_event()
	elif key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_F2]:
		if _viewport != null and _viewport.begin_edit_selected():
			accept_event()

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

func _on_load_theme_requested() -> void:
	if _theme_file_dialog == null:
		_build_theme_file_dialog()
	if _theme_file_dialog == null:
		_set_status("Theme picker unavailable.", true)
		return
	_theme_file_dialog.current_dir = _suggest_sheet_directory()
	_theme_file_dialog.popup_centered(Vector2i(760, 520))

func _on_theme_file_selected(path: String) -> void:
	load_theme_style_from_path(path)

func _on_set_default_theme_requested() -> void:
	if use_default_theme():
		_mark_dirty("Applied default theme.")
	else:
		_set_status("Default theme already active.", true)

func _on_reload_theme_requested() -> void:
	if reload_active_theme():
		_set_status("Reloaded active theme.")
	else:
		_set_status("Reload theme failed: no active style resource path.", true)

## Populates the toolbar theme switcher with "Default" plus the discovered bundled themes.
func _populate_theme_picker() -> void:
	if _theme_picker == null:
		return
	_theme_picker.clear()
	# The default IS the editor-derived style (see _apply_editor_native_defaults) —
	# label it so a Godot dev knows the sheet already matches their editor.
	_theme_picker.add_item("Match Editor (default)")
	_theme_picker.set_item_metadata(0, "")
	for preset: Dictionary in EventSheetThemePresets.list_presets():
		_theme_picker.add_item(str(preset.get("name", "Theme")))
		_theme_picker.set_item_metadata(_theme_picker.item_count - 1, str(preset.get("path", "")))
	_refresh_theme_picker_selection()

## Selects the switcher entry matching the current sheet's active theme (Default if none).
func _refresh_theme_picker_selection() -> void:
	if _theme_picker == null:
		return
	var active_path: String = ""
	if _current_sheet != null and _current_sheet.editor_style != null:
		active_path = _current_sheet.editor_style.resource_path
	var target_index: int = 0
	for i in range(_theme_picker.item_count):
		if str(_theme_picker.get_item_metadata(i)) == active_path:
			target_index = i
			break
	_theme_picker.selected = target_index

## Applies the chosen theme preset (or the built-in default) to the current sheet.
func _on_theme_preset_selected(index: int) -> void:
	if _theme_picker == null:
		return
	var path: String = str(_theme_picker.get_item_metadata(index))
	if path.is_empty():
		_on_set_default_theme_requested()
	else:
		load_theme_style_from_path(path)
	_refresh_theme_picker_selection()

# Sheet FILE-IO delegates → dock/sheet_io.gd (EventSheetSheetIO). Bodies live there; the dock keeps
# these thin forwarders so external callers (plugin.gd, the dock/ helpers, menu_bar, command_palette)
# and the tests reach the same names + signatures unchanged. Methods called only from within the IO
# helper (_exported_script_basename, _suggest_sheet_filename, _build_initial_save_path) have no delegate.
func _load_sheet_from_path(path: String) -> void:
	_sheet_io._load_sheet_from_path(path)

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
## is the concrete proof a Godot dev can adopt the plugin without lock-in — take the .gd and
## go. Distinct from Save (which keeps the paired generated script alongside the .tres).
## Activate/deactivate the MCP server (AI tools) at will. The server is a separate process,
## so we flip a marker file it re-checks live — toggling off makes a connected AI client's
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
## and wires the current sheet to include it — copy-paste becomes modularization in one step.
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
	var target: String = path if path.get_extension() == "tres" else path + ".tres"
	# Build + save the library FIRST (duplicating the rows so uids carry over), so a write
	# failure leaves the current sheet untouched.
	var library: EventSheetResource = EventSheetResource.new()
	library.host_class = _current_sheet.host_class
	library.behavior_mode = _current_sheet.behavior_mode
	for row: Resource in rows:
		library.events.append(row.duplicate(true))
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if ResourceSaver.save(library, target) != OK:
		_set_status("Could not write %s." % target.get_file(), true)
		return
	# Then remove the originals + add the include, undoably (one snapshot captures both).
	var changed: bool = _perform_undoable_sheet_edit("Extract to Include", func() -> bool:
		for row: Resource in rows:
			var index: int = _current_sheet.events.find(row)
			if index != -1:
				_current_sheet.events.remove_at(index)
		if not _current_sheet.includes.has(target):
			_current_sheet.includes.append(target)
		return true
	)
	if changed:
		_mark_dirty("Extracted %d row(s) into %s (now included)." % [rows.size(), target.get_file()])

## The first event-SCOPED identifier (an event-local variable or a For-Each iterator name) referenced by
## the given actions, or "" if none. An extracted function is a SEPARATE method, so it can't see these —
## extracting an action that uses one would emit a script that won't parse. The dock refuses with this
## name (a clear message) instead of silently producing a broken .gd. Whole-word match so "speed" doesn't
## trip on "speedometer". Scans GDScript blocks, ACE param/template text, and a Match action's subject.
static func _scope_capture_offender(event: EventRow, actions: Array) -> String:
	var scoped: PackedStringArray = PackedStringArray()
	for local_entry: Variant in event.local_variables:
		if local_entry is LocalVariable and not (local_entry as LocalVariable).name.strip_edges().is_empty():
			scoped.append((local_entry as LocalVariable).name.strip_edges())
	for filter_entry: Variant in event.pick_filters:
		if filter_entry is PickFilter and not (filter_entry as PickFilter).iterator_name.strip_edges().is_empty():
			scoped.append((filter_entry as PickFilter).iterator_name.strip_edges())
	if scoped.is_empty():
		return ""
	var text: String = ""
	for action: Variant in actions:
		if action is RawCodeRow:
			text += "\n" + (action as RawCodeRow).code
		elif action is ACEAction:
			text += "\n" + (action as ACEAction).codegen_template
			for value: Variant in (action as ACEAction).params.values():
				text += "\n" + str(value)
		elif action is MatchRow:
			text += "\n" + (action as MatchRow).match_expression
	for name: String in scoped:
		var word: RegEx = RegEx.new()
		if word.compile("\\b" + name + "\\b") == OK and word.search(text) != null:
			return name
	return ""

## Extracts the given actions of an event into a new NAMED, reusable Function (exposed as an ACE) and
## replaces them with a single Call — turning a pile of statement-level rows into one named CONCEPT (the
## "create abstraction" gesture). Unlike the old GDScript-only extractor, this works on ANY action —
## structured ACE actions AND GDScript blocks — and PRESERVES them as rows in the function body (wrapped
## in a trigger-less, condition-less event, which the shared event-body compile path emits as plain
## statements, structure intact). Static + pure (operates on the passed sheet) so it is headlessly
## testable; the dock wraps it in an undoable edit + a name prompt. Returns the new function, or null when
## there is nothing to extract.
##
## Scope note: the function compiles to a METHOD on the same class, so it can freely read sheet variables
## and host members WITHOUT parameters. It does NOT capture event-LOCAL variables or For-Each iterators
## (those are trigger/loop-scoped) — extracting actions that depend on them needs params, a later
## refinement. The actions are taken in their original event order, so a non-contiguous selection still
## extracts deterministically (consolidated where the first one was).
static func extract_actions_to_function(sheet: EventSheetResource, event: EventRow, actions_to_extract: Array, raw_name: String) -> EventFunction:
	if sheet == null or event == null or actions_to_extract.is_empty():
		return null
	# Keep only the requested actions that actually belong to this event, in their original order.
	var ordered: Array = []
	for action: Variant in event.actions:
		if actions_to_extract.has(action) and action is Resource:
			ordered.append(action)
	if ordered.is_empty():
		return null
	# Refuse if any action references an event-SCOPED name (a local variable or For-Each iterator): the
	# extracted function is a separate method that can't see those, so extracting would emit a .gd that
	# won't parse. The dock checks this first to show WHICH name; this guard makes the core safe too.
	if not _scope_capture_offender(event, ordered).is_empty():
		return null
	var insert_at: int = event.actions.find(ordered[0])
	var function_name: String = _unique_extracted_function_name(sheet, _sanitize_function_name(raw_name))
	var display_name: String = raw_name.strip_edges()
	var function: EventFunction = EventFunction.new()
	function.function_name = function_name
	function.expose_as_ace = true
	function.ace_display_name = display_name if not display_name.is_empty() else function_name.capitalize()
	function.ace_category = "Functions"
	function.description = "Extracted from an event — reusable as an ACE."
	# Function body: one trigger-less, condition-less event holding the extracted actions in order. A
	# condition-less event emits its actions directly (no `if` wrapper), so structured AND raw actions
	# both survive — and the function renders showing those same rows.
	var body_event: EventRow = EventRow.new()
	var body_actions: Array[Resource] = []
	for action: Variant in ordered:
		body_actions.append(action as Resource)
	body_event.actions = body_actions
	function.events.append(body_event)
	sheet.functions.append(function)
	# Remove the extracted actions, then drop a Call to the new function where the first one was.
	for action: Variant in ordered:
		event.actions.erase(action)
	var call_action: ACEAction = ACEAction.new()
	call_action.provider_id = "Core"
	call_action.ace_id = "CallFunction"
	call_action.codegen_template = "{function_name}({args})"
	call_action.params = {"function_name": function_name, "args": ""}
	event.actions.insert(clampi(insert_at, 0, event.actions.size()), call_action)
	return function

## Turns arbitrary entered text into a valid snake_case GDScript identifier — so a user typing
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

## True when `candidate` can't be the extracted method's name — because it's a GDScript reserved word, an
## existing sheet function, or a method ALREADY on the host/base class. Each of those would emit a .gd
## that fails to parse (`func if():`, a `queue_free` override under warnings-as-errors) or silently
## shadows a built-in — so the uniquifier skips past them, keeping the generated script valid (the
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

## A function name that is valid AND free (not reserved, not an existing function, not a host method) —
## extracted_action, apply_physics_2, queue_free_2, func_2, …
static func _unique_extracted_function_name(sheet: EventSheetResource, base: String) -> String:
	if not _function_name_is_taken(sheet, base):
		return base
	var suffix: int = 2
	while _function_name_is_taken(sheet, "%s_%d" % [base, suffix]):
		suffix += 1
	return "%s_%d" % [base, suffix]

## Right-click action: extract the event's actions into a NAMED reusable Function (the "create
## abstraction" gesture). Reachable from an action's menu or the event row menu. Extracts ALL of the
## event's actions — turning this event's "do" into one named verb — then prompts for a name and runs the
## edit undoably. (A future refinement can honour a partial action selection.)
func _extract_to_function_requested() -> void:
	if _context_row == null or not (_context_row.source_resource is EventRow):
		_set_status("Right-click an event or one of its actions to extract.", true)
		return
	var event: EventRow = _context_row.source_resource as EventRow
	if event.actions.is_empty():
		_set_status("That event has no actions to extract into a function.", true)
		return
	var to_extract: Array = event.actions.duplicate()
	# Refuse (with the offending name) rather than silently emit a script that won't parse.
	var captured: String = _scope_capture_offender(event, to_extract)
	if not captured.is_empty():
		_set_status("Can't extract: these actions use \"%s\", which lives in this event's scope (a local variable or loop iterator) — a function can't see it. Move it to a sheet variable first, then extract." % captured, true)
		return
	_prompt_extract_function_name(func(entered_name: String) -> void:
		var changed: bool = _perform_undoable_sheet_edit("Extract to Function", func() -> bool:
			return extract_actions_to_function(_current_sheet, event, to_extract, entered_name) != null
		)
		if changed:
			_refresh_functions_list()
			_mark_dirty("Extracted %d action(s) into a reusable Function — now callable as an ACE (Functions)." % to_extract.size())
	)

# ── Extract-to-Function name prompt (one field: name the new concept) ──
var _extract_function_name_dialog: ConfirmationDialog = null
var _extract_function_name_edit: LineEdit = null
var _extract_function_callback: Callable = Callable()

## Prompts for the function name, then invokes callback(name). Pre-filled with a unique default (so Enter
## just works) but selected — the user is nudged to type a real, meaningful name, because naming the
## concept ("Apply Physics") is the whole point of extracting.
func _prompt_extract_function_name(callback: Callable) -> void:
	if _extract_function_name_dialog == null:
		_extract_function_name_dialog = ConfirmationDialog.new()
		_extract_function_name_dialog.title = "Extract to Function"
		_extract_function_name_dialog.ok_button_text = "Extract"
		_extract_function_name_dialog.min_size = Vector2i(380, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		_extract_function_name_edit = LineEdit.new()
		_extract_function_name_edit.placeholder_text = "apply_physics"
		_extract_function_name_edit.text_submitted.connect(func(_t: String) -> void:
			_apply_extract_function()
			_extract_function_name_dialog.hide()
		)
		box.add_child(EventSheetPopupUI.form_row("Name this action", _extract_function_name_edit))
		var hint: Label = Label.new()
		hint.text = "These actions become one reusable verb: call it anywhere, and it appears in the picker. Type a meaningful name (e.g. \"Apply Physics\")."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(340.0, 0.0)
		hint.add_theme_color_override("font_color", EventSheetPalette.TEXT_MUTED)
		box.add_child(hint)
		_extract_function_name_dialog.add_child(EventSheetPopupUI.margined(box))
		_extract_function_name_dialog.confirmed.connect(_apply_extract_function)
		add_child(_extract_function_name_dialog)
	_extract_function_callback = callback
	_extract_function_name_edit.text = _unique_extracted_function_name(_current_sheet, "do_something") if _current_sheet != null else "do_something"
	_extract_function_name_dialog.popup_centered()
	_extract_function_name_edit.grab_focus()
	_extract_function_name_edit.select_all()

## One-shot apply: nulls the callback first so the confirmed + text_submitted signals can't double-fire.
func _apply_extract_function() -> void:
	if not _extract_function_callback.is_valid():
		return
	var entered: String = _extract_function_name_edit.text.strip_edges()
	var callback: Callable = _extract_function_callback
	_extract_function_callback = Callable()
	if entered.is_empty():
		return
	callback.call(entered)

var _breakpoint_condition_dialog: AcceptDialog = null
var _breakpoint_condition_edit: LineEdit = null
var _breakpoint_condition_target: EventRow = null

## Visual debugging: a conditional breakpoint. Prompts for a GDScript boolean expression; the
## breakpoint then fires only when it is true (compiled as `if <cond>: breakpoint`). Sets and
## enables the row breakpoint; a blank expression clears the guard (break every pass).
func _set_breakpoint_condition_requested() -> void:
	if _context_row == null or not (_context_row.source_resource is EventRow):
		_set_status("Right-click an event to set a breakpoint condition.", true)
		return
	var event: EventRow = _context_row.source_resource as EventRow
	if _breakpoint_condition_dialog == null:
		_breakpoint_condition_dialog = AcceptDialog.new()
		_breakpoint_condition_dialog.title = "Conditional Breakpoint"
		_breakpoint_condition_dialog.ok_button_text = "Set"
		_breakpoint_condition_dialog.min_size = Vector2i(440, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		box.add_child(EventSheetPopupUI.hint_label("Break only when this GDScript expression is true. Leave blank to break every pass — either way, this enables the event's breakpoint."))
		_breakpoint_condition_edit = LineEdit.new()
		_breakpoint_condition_edit.placeholder_text = "e.g. health <= 0"
		box.add_child(EventSheetPopupUI.form_row("Condition", _breakpoint_condition_edit))
		_breakpoint_condition_dialog.add_child(EventSheetPopupUI.margined(box))
		_breakpoint_condition_dialog.confirmed.connect(_apply_breakpoint_condition)
		add_child(_breakpoint_condition_dialog)
	_breakpoint_condition_target = event
	_breakpoint_condition_edit.text = event.debug_break_condition
	_breakpoint_condition_dialog.popup_centered()
	_breakpoint_condition_edit.grab_focus()

func _apply_breakpoint_condition() -> void:
	if _breakpoint_condition_target == null:
		return
	var event: EventRow = _breakpoint_condition_target
	var condition: String = _breakpoint_condition_edit.text.strip_edges()
	var changed: bool = _perform_undoable_sheet_edit("Set Breakpoint Condition", func() -> bool:
		event.debug_break = true
		event.debug_break_condition = condition
		return true
	)
	if changed:
		var note: String = ("Breakpoint will pause when: %s" % condition) if not condition.is_empty() else "Breakpoint will pause every pass."
		if _current_sheet != null and not _current_sheet.emit_breakpoints:
			note += "  (enable Tools ▸ Debug Breakpoints to emit.)"
		_mark_dirty(note)

## Find References (whole-symbol uses across every sheet, with jump-to-sheet) — see EventSheetFindReferencesPanel.
func _find_references_requested() -> void:
	_find_refs.open()

## Generate Events from a Description (AI) → dock/ai_generate_window.gd ──
func _open_ai_generate() -> void:  # Edit menu
	_ai.open()

## Manage Includes (browse/add/remove/reorder included library sheets) — see EventSheetIncludeManager.
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
	if not _ensure_sheet_for_editing():
		return
	_ace_picker.open("new_event", false, _active_view().get_selected_context().get("source_resource", null))

func _on_add_signal_event_requested() -> void:
	if not _ensure_sheet_for_editing():
		return
	_ace_picker.open("new_event", true, _active_view().get_selected_context().get("source_resource", null))

func _on_add_condition_requested() -> void:
	if not _ensure_sheet_for_editing():
		return
	var selected_resource: Resource = _active_view().get_selected_context().get("source_resource", null)
	if selected_resource is EventRow:
		_ace_picker.open("append_condition", false, selected_resource)
		return
	_ace_picker.open("new_condition_event", false, selected_resource)

func _on_add_action_requested() -> void:
	if not _ensure_selected_event():
		return
	_ace_picker.open("append_action", false, _active_view().get_selected_context().get("source_resource", null))

func _on_add_comment_requested() -> void:
	if not _ensure_sheet_for_editing():
		return
	var comment: CommentRow = CommentRow.new()
	comment.text = "Comment"
	var changed: bool = _perform_undoable_sheet_edit("Add Comment", func() -> bool:
		_insert_row_below_selection(comment)
		return true
	)
	if changed:
		_mark_dirty("Added comment.")

func _on_add_group_requested() -> void:
	if not _ensure_sheet_for_editing():
		return
	var group: EventGroup = EventGroup.new()
	group.name = "Group"
	group.group_name = group.name
	var changed: bool = _perform_undoable_sheet_edit("Add Group", func() -> bool:
		_insert_row_below_selection(group)
		return true
	)
	if changed:
		_mark_dirty("Added group.")
		# Drop straight into renaming the new group so naming it is obvious and immediate —
		# the same inline title edit you'd reach by double-clicking it or pressing Enter,
		# just triggered for you. Deferred so it runs after the viewport rebuilds.
		call_deferred("_begin_group_rename", group)

## Selects a group and opens its editor popup (used right after Add Group so the user can name it
## immediately, and on double-click / slow-click / Enter of an existing group header).
func _begin_group_rename(group: EventGroup) -> void:
	var view: EventSheetViewport = _active_view()
	if view != null:
		view.select_resource(group)
	_on_group_edit_requested(group)

var _group_edit_dialog: ConfirmationDialog = null
var _group_name_edit: LineEdit = null
var _group_desc_edit: TextEdit = null
var _group_edit_target: EventGroup = null

## Group editor popup: edit a group's name and (optional) description together. Replaces the old
## inline title edit — the description renders only as a muted second header line once it is
## non-empty, so an inline-only flow could never ADD one. Reached by double-click / slow-click /
## Enter on a group header, and right after Add Group.
func _on_group_edit_requested(group: EventGroup) -> void:
	if group == null:
		return
	if _group_edit_dialog == null:
		_group_edit_dialog = ConfirmationDialog.new()
		_group_edit_dialog.title = "Edit Group"
		_group_edit_dialog.ok_button_text = "Apply"
		_group_edit_dialog.min_size = Vector2i(420, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		_group_name_edit = LineEdit.new()
		_group_name_edit.placeholder_text = "Group name"
		# Enter in the name field applies + closes (the LineEdit consumes Enter, so the dialog's
		# own OK does not also fire); _apply_group_edit is one-shot-guarded regardless.
		_group_name_edit.text_submitted.connect(func(_submitted: String) -> void:
			_apply_group_edit()
			_group_edit_dialog.hide()
		)
		box.add_child(EventSheetPopupUI.form_row("Name", _group_name_edit))
		_group_desc_edit = TextEdit.new()
		_group_desc_edit.custom_minimum_size = Vector2(0.0, 90.0)
		_group_desc_edit.placeholder_text = "Shown as a muted second line on the group header."
		box.add_child(EventSheetPopupUI.form_row("Description", _group_desc_edit))
		_group_edit_dialog.add_child(EventSheetPopupUI.margined(box))
		_group_edit_dialog.confirmed.connect(_apply_group_edit)
		add_child(_group_edit_dialog)
	_group_edit_target = group
	_group_name_edit.text = group.group_name if not group.group_name.strip_edges().is_empty() else group.name
	_group_desc_edit.text = group.description
	_group_edit_dialog.popup_centered()
	_group_name_edit.grab_focus()
	_group_name_edit.select_all()

## One-shot apply: nulls the target first so a text-submit + dialog-OK pair can never double-apply.
func _apply_group_edit() -> void:
	if _group_edit_target == null:
		return
	var target: EventGroup = _group_edit_target
	_group_edit_target = null
	apply_group_edit(target, _group_name_edit.text, _group_desc_edit.text)

## Applies a group's name + description undoably. Wraps the pure static mutation so the popup's
## Apply and tests share one code path.
func apply_group_edit(group: EventGroup, new_name: String, new_desc: String) -> bool:
	if group == null:
		return false
	var changed: bool = _perform_undoable_sheet_edit("Edit Group", func() -> bool:
		set_group_fields(group, new_name, new_desc)
		return true
	)
	if changed:
		_mark_dirty("Updated group: %s" % group.group_name)
	return changed

## Pure mutation: trims + applies a group's name (mirrored to .name + .group_name) and its
## description; a blank name falls back to "Group". Static so it is unit-testable without the
## dialog or a display server. Returns the resolved name.
static func set_group_fields(group: EventGroup, new_name: String, new_desc: String) -> String:
	var resolved_name: String = new_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = "Group"
	group.name = resolved_name
	group.group_name = resolved_name
	group.description = new_desc.strip_edges()
	return resolved_name

func _on_duplicate_requested() -> void:
	if not _ensure_sheet_for_editing():
		return
	var selected_resource: Resource = _active_view().get_selected_context().get("source_resource", null)
	if not (selected_resource is EventRow):
		_set_status("Select an event row to duplicate.", true)
		return
	var clone: EventRow = (selected_resource as EventRow).duplicate(true)
	_assign_fresh_event_uids(clone)
	var changed: bool = _perform_undoable_sheet_edit("Duplicate Event", func() -> bool:
		_insert_row_below_selection(clone, selected_resource)
		return true
	)
	if changed:
		_mark_dirty("Duplicated event.")

## Recursively assigns fresh event UIDs to a cloned event row and its sub-events so the
## duplicate does not share selection/fold identity with the source.
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
	row.event_uid = EventRow._generate_short_uid()
	# Stateful conditions (Every X Seconds…): the COPY must own its own accumulator —
	# re-bake the member uid across all four baked fields, or both timers silently
	# share one member (copies are independent timers).
	for condition: Variant in row.conditions:
		if condition is ACECondition and not (condition as ACECondition).member_declaration.is_empty():
			var stateful: ACECondition = condition as ACECondition
			var uid_regex: RegEx = RegEx.new()
			uid_regex.compile("__[a-z_]+_([0-9a-f]{8})\\b")
			var uid_match: RegExMatch = uid_regex.search(stateful.member_declaration)
			if uid_match == null:
				continue
			var old_uid: String = uid_match.get_string(1)
			var new_uid: String = _fresh_uid_token()
			stateful.member_declaration = stateful.member_declaration.replace(old_uid, new_uid)
			stateful.codegen_template = stateful.codegen_template.replace(old_uid, new_uid)
			stateful.codegen_prelude = stateful.codegen_prelude.replace(old_uid, new_uid)
			stateful.codegen_on_true = stateful.codegen_on_true.replace(old_uid, new_uid)
	# Multi-line action templates bake `__spawn_<uid>`/`__sfx_<uid>` locals — pasting the
	# same event twice into one trigger would declare the same local twice in one
	# function body. Re-bake every baked uid the template carries.
	for action: Variant in row.actions:
		if action is ACEAction and (action as ACEAction).codegen_template.contains("__"):
			var baked: ACEAction = action as ACEAction
			var action_uid_regex: RegEx = RegEx.new()
			action_uid_regex.compile("__[a-z_]+_([0-9a-f]{8})\\b")
			var seen_uids: Dictionary = {}
			for action_match: RegExMatch in action_uid_regex.search_all(baked.codegen_template):
				seen_uids[action_match.get_string(1)] = true
			for stale_uid: Variant in seen_uids.keys():
				baked.codegen_template = baked.codegen_template.replace(str(stale_uid), _fresh_uid_token())
	for sub_event in row.sub_events:
		if sub_event is EventRow:
			_assign_fresh_event_uids(sub_event as EventRow)

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

func _on_copy_requested() -> void:
	var context: Dictionary = _active_view().get_selected_context()
	var selected_resource: Resource = context.get("source_resource", null)
	if selected_resource == null:
		_set_status("Nothing selected to copy.", true)
		return
	var metadata: Dictionary = context.get("span_metadata", {})
	if selected_resource is EventRow and not metadata.is_empty():
		var event_row: EventRow = selected_resource as EventRow
		var kind: String = str(metadata.get("kind", ""))
		var ace_index: int = int(metadata.get("ace_index", -1))
		if kind == "condition" and ace_index >= 0 and ace_index < event_row.conditions.size():
			_clipboard = {"type": "condition", "payload": event_row.conditions[ace_index].duplicate(true)}
			_set_status("Copied condition.")
			return
		if kind == "action" and ace_index >= 0 and ace_index < event_row.actions.size() and event_row.actions[ace_index] is ACEAction:
			_clipboard = {"type": "action", "payload": (event_row.actions[ace_index] as ACEAction).duplicate(true)}
			_set_status("Copied action.")
			return
		if kind == "trigger" and event_row.trigger != null:
			_clipboard = {"type": "trigger", "payload": event_row.trigger.duplicate(true)}
			_set_status("Copied trigger.")
			return
	# Row copies are written in two forms: the internal clipboard (rich, same-session
	# pastes) and a portable text snippet on the SYSTEM clipboard, so rows can be shared
	# across projects, editor instances, and forum/Discord posts (see EventSheetSnippet).
	var top_level: Array = _top_level_selected_resources()
	if top_level.is_empty():
		top_level = [selected_resource]
	DisplayServer.clipboard_set(EventSheetSnippet.serialize_rows(top_level, _current_sheet))
	_clipboard = {"type": "row", "payload": selected_resource.duplicate(true)}
	_set_status("Copied %d row(s) — shareable snippet placed on the clipboard." % top_level.size())

## Top-most selected row resources: children of a selected ancestor are skipped because
## they already travel inside their parent's serialized form.
func _top_level_selected_resources() -> Array:
	var resources: Array = []
	for row_data in _get_selected_rows_from_context():
		if row_data == null or row_data.source_resource == null:
			continue
		if not resources.has(row_data.source_resource):
			resources.append(row_data.source_resource)
	var top_level: Array = []
	for resource in resources:
		var has_selected_ancestor: bool = false
		for other in resources:
			if other != resource and _resource_contains_descendant(other, resource):
				has_selected_ancestor = true
				break
		if not has_selected_ancestor:
			top_level.append(resource)
	return top_level

func _on_paste_requested() -> void:
	# Paste priority: portable snippets (in-app copies refresh them too) → raw GDScript
	# copied from anywhere (auto-converted to events/rows) → the internal clipboard for
	# same-session rich pastes.
	if _paste_snippet_text(DisplayServer.clipboard_get()):
		return
	if _paste_gdscript_text(DisplayServer.clipboard_get()):
		return
	if _clipboard.is_empty():
		_set_status("Clipboard is empty.", true)
		return
	if not _ensure_sheet_for_editing():
		return
	var clip_type: String = str(_clipboard.get("type", ""))
	var payload: Variant = _clipboard.get("payload", null)
	var context: Dictionary = _active_view().get_selected_context()
	var selected_resource: Resource = context.get("source_resource", null)
	var result := {"label": ""}
	var changed: bool = _perform_undoable_sheet_edit("Paste", func() -> bool:
		match clip_type:
			"row":
				if payload is Resource:
					_insert_row_below_selection((payload as Resource).duplicate(true))
					result["label"] = "Pasted row."
					return true
			"condition":
				if selected_resource is EventRow and payload is ACECondition:
					(selected_resource as EventRow).conditions.append((payload as ACECondition).duplicate(true))
					result["label"] = "Pasted condition."
					return true
			"action":
				if selected_resource is EventRow and payload is ACEAction:
					(selected_resource as EventRow).actions.append((payload as ACEAction).duplicate(true))
					result["label"] = "Pasted action."
					return true
			"trigger":
				if selected_resource is EventRow and payload is ACECondition:
					(selected_resource as EventRow).trigger = (payload as ACECondition).duplicate(true)
					result["label"] = "Pasted trigger."
					return true
		return false
	)
	if not changed:
		_set_status("Paste target is not valid for clipboard payload.", true)
	else:
		_mark_dirty(str(result.get("label", "Pasted.")))

## Pastes a shareable snippet from text (see EventSheetSnippet). Returns false when the
## text is not a snippet so the caller falls back to the internal clipboard. Pasted events
## get fresh UIDs; sheet variables the snippet references are created when missing (never
## overwritten), so the pasted rows compile immediately.
func _paste_snippet_text(text: String) -> bool:
	if not EventSheetSnippet.is_snippet_text(text):
		return false
	if not _ensure_sheet_for_editing():
		return true
	var snippet: Dictionary = EventSheetSnippet.deserialize(text)
	var rows: Array = snippet.get("rows", [])
	if rows.is_empty():
		_set_status("Clipboard snippet is empty or invalid.", true)
		return true
	# Dictionary so the undoable lambda can mutate it (GDScript lambdas capture by value).
	var counters: Dictionary = {"variables_created": 0}
	var required_variables: Dictionary = snippet.get("required_variables", {})
	var changed: bool = _perform_undoable_sheet_edit("Paste Snippet", func() -> bool:
		for variable_name in required_variables.keys():
			if not _current_sheet.variables.has(variable_name):
				_current_sheet.variables[variable_name] = required_variables[variable_name]
				counters["variables_created"] = int(counters["variables_created"]) + 1
		var anchor: Resource = _active_view().get_selected_context().get("source_resource", null)
		for row in rows:
			if row is EventRow:
				_assign_fresh_event_uids(row as EventRow)
			_insert_row_below_selection(row, anchor)
			anchor = row  # keeps pasted rows in their original order, each after the last
		return true
	)
	if changed:
		var provider_names: PackedStringArray = PackedStringArray()
		for provider in snippet.get("providers", []):
			provider_names.append(str(provider))
		var provider_note: String = "" if provider_names.is_empty() else " Uses providers: %s." % ", ".join(provider_names)
		_mark_dirty("Pasted snippet: %d row(s), %d variable(s) created.%s" % [rows.size(), int(counters["variables_created"]), provider_note])
	return true

## Appends an in-flow GDScript block to the right-clicked event's actions (event-sheet-style inline
## scripting: statements emitted inside the event body).
func _add_gdscript_action_to_context_row() -> void:
	if _context_row == null or not (_context_row.source_resource is EventRow):
		_set_status("Add a GDScript action from an event row.", true)
		return
	var target_event: EventRow = _context_row.source_resource as EventRow
	var changed: bool = _perform_undoable_sheet_edit("Add GDScript Action", func() -> bool:
		var inline_raw: RawCodeRow = RawCodeRow.new()
		inline_raw.code = "pass"
		target_event.actions.append(inline_raw)
		return true
	)
	if changed:
		_mark_dirty("Added GDScript action.")

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

# ── ACE application + drag-drop — delegates to EventSheetACEApply ─────────────
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
# Hands GDScript to Godot's own script editor — always a REAL file: a custom-ACE provider script, or
# a code-backed sheet's .gd source (which the block/generated actions compile to and then open).
# Sheets with no .gd source (.tres) have nothing to open, so those actions nudge the user to Save As.

# ── GDScript provenance panel ────────────────────────────────────────────────
# Read-only side panel showing the generated GDScript; selecting a sheet row highlights the
# exact lines it compiles to (sheet → code provenance, via the compiler's source_map).
var _code_edit: CodeEdit = null
var _code_source_map: Array = []
var _code_panel_highlight: Vector2i = Vector2i(-1, -1)
const CODE_PANEL_HIGHLIGHT_COLOR := Color(0.35, 0.55, 0.95, 0.18)

## ── Open Sheets panel (the left in-workspace pane) ──────────────────────────────────────
## Push the current open-tab snapshot into the panel (on every open_tabs_changed + on build).
func _refresh_open_sheets_panel() -> void:
	if _open_sheets_panel == null:
		return
	var state: Dictionary = get_open_sheets_state()
	_open_sheets_panel.set_state(state.get("open", []), int(state.get("active", -1)), state.get("recent", []))

## View ▸ Open Sheets Panel: show/hide the whole left pane (remembered per project).
func _toggle_open_sheets_panel(view_popup: PopupMenu) -> void:
	if _open_sheets_panel == null:
		return
	_open_sheets_panel.visible = not _open_sheets_panel.visible
	if view_popup != null:
		view_popup.set_item_checked(view_popup.get_item_index(13), _open_sheets_panel.visible)
	_save_open_sheets_panel_prefs()

## The panel collapsed to / expanded from a strip: snap the split divider to match, and remember it.
func _on_open_sheets_panel_collapsed(collapsed: bool) -> void:
	if _workspace_body != null:
		_workspace_body.split_offset = 26 if collapsed else 200
	_save_open_sheets_panel_prefs()

## Per-project editor metadata for the panel's shown/collapsed state (survives editor restarts).
func _read_open_sheets_panel_prefs() -> Dictionary:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var meta: Variant = EditorInterface.get_editor_settings().get_project_metadata("eventsheets", _OPEN_SHEETS_PANEL_META, {})
		if meta is Dictionary:
			return meta
	return {}

func _save_open_sheets_panel_prefs() -> void:
	if not (Engine.is_editor_hint() and Engine.has_singleton("EditorInterface")):
		return
	EditorInterface.get_editor_settings().set_project_metadata("eventsheets", _OPEN_SHEETS_PANEL_META, {
		"shown": _open_sheets_panel != null and _open_sheets_panel.visible,
		"collapsed": _open_sheets_panel != null and _open_sheets_panel.is_collapsed(),
	})

## Apply the remembered shown/collapsed state when the workspace is built.
func _apply_open_sheets_panel_prefs() -> void:
	if _open_sheets_panel == null:
		return
	var prefs: Dictionary = _read_open_sheets_panel_prefs()
	_open_sheets_panel.visible = bool(prefs.get("shown", true))
	_open_sheets_panel.set_collapsed(bool(prefs.get("collapsed", false)))
	_refresh_open_sheets_panel()

func _toggle_code_panel() -> void:
	_ensure_code_panel()
	_side_panel.visible = not _side_panel.visible
	_split.dragger_visibility = (
		SplitContainer.DRAGGER_VISIBLE if _side_panel.visible else SplitContainer.DRAGGER_HIDDEN_COLLAPSED
	)
	if _side_panel.visible:
		_refresh_code_panel()

func is_code_panel_visible() -> bool:
	return _side_panel != null and _side_panel.visible

## Builds the panel lazily on first toggle: wraps the sheet scroll in an HSplitContainer
## (so the default tree stays untouched until the user asks for the panel) and adds the
## code view on the right.
func _ensure_code_panel() -> void:
	if _split != null:
		return
	var scroll_parent: Node = _scroll.get_parent()
	var scroll_index: int = _scroll.get_index()
	_split = HSplitContainer.new()
	_split.name = "EventSheetCodeSplit"
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_parent.remove_child(_scroll)
	scroll_parent.add_child(_split)
	scroll_parent.move_child(_split, scroll_index)
	_split.add_child(_scroll)
	_side_panel = VBoxContainer.new()
	_side_panel.name = "GeneratedGDScriptPanel"
	_side_panel.custom_minimum_size = Vector2(360.0, 0.0)
	_side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_panel.visible = false
	# Functions overview (the function list): every sheet function at a glance, so they're
	# discoverable without scrolling the rows. ＋ opens the function dialog; right-click deletes.
	var functions_header: HBoxContainer = HBoxContainer.new()
	var functions_title: Label = Label.new()
	functions_title.text = "Functions"
	functions_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	functions_header.add_child(functions_title)
	var add_function_button: Button = Button.new()
	add_function_button.text = "＋"
	add_function_button.tooltip_text = "Add a function…"
	add_function_button.pressed.connect(_open_function_dialog)
	functions_header.add_child(add_function_button)
	_side_panel.add_child(functions_header)
	_functions_list = ItemList.new()
	_functions_list.name = "EventSheetFunctionsList"
	_functions_list.custom_minimum_size = Vector2(0.0, 96.0)
	_functions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_functions_list.allow_reselect = true
	_functions_list.item_clicked.connect(_on_functions_list_item_clicked)
	_side_panel.add_child(_functions_list)
	_functions_menu = PopupMenu.new()
	_functions_menu.add_item("Delete Function", 0)
	_functions_menu.id_pressed.connect(_on_functions_menu_id_pressed)
	_functions_list.add_child(_functions_menu)
	_side_panel.add_child(HSeparator.new())
	var header: HBoxContainer = HBoxContainer.new()
	var title: Label = Label.new()
	title.text = "Generated GDScript"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var open_in_godot_button: Button = Button.new()
	open_in_godot_button.text = "Open in Godot Script Editor"
	open_in_godot_button.tooltip_text = "Open the .gd source in Godot's own script editor (code-backed sheets). For a .tres sheet, Save As… a .gd first."
	open_in_godot_button.pressed.connect(_open_generated_in_godot)
	header.add_child(open_in_godot_button)
	var copy_button: Button = Button.new()
	copy_button.text = "Copy"
	copy_button.tooltip_text = "Copy the generated script to the clipboard"
	copy_button.pressed.connect(func() -> void:
		if _code_edit != null:
			DisplayServer.clipboard_set(_code_edit.text)
	)
	header.add_child(copy_button)
	var close_button: Button = Button.new()
	close_button.text = "✕"
	close_button.tooltip_text = "Close the GDScript panel"
	close_button.pressed.connect(_toggle_code_panel)
	header.add_child(close_button)
	_side_panel.add_child(header)
	# Orientation for non-programmers: say what this panel even is before the code scares them off.
	var code_hint: Label = Label.new()
	code_hint.text = "The plain GDScript your sheet compiles to — read-only, refreshed live as you edit. Your game ships this, with no runtime dependency."
	code_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	code_hint.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_side_panel.add_child(code_hint)
	_code_edit = CodeEdit.new()
	_code_edit.editable = false
	_code_edit.gutters_draw_line_numbers = true
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# GDScriptSyntaxHighlighter is editor-only; headless test runs skip it.
	if Engine.is_editor_hint() and ClassDB.class_exists("GDScriptSyntaxHighlighter"):
		_code_edit.syntax_highlighter = ClassDB.instantiate("GDScriptSyntaxHighlighter")
	# Make the panel read like the actual script editor: its code font + the minimap.
	_apply_editor_code_settings(_code_edit)
	_code_edit.gui_input.connect(_on_code_panel_gui_input)
	_side_panel.add_child(_code_edit)
	_split.add_child(_side_panel)
	_split.split_offset = int(size.x * 0.6) if size.x > 0.0 else 600

## Adopts the editor's code-editor look on a CodeEdit (the GDScript panel): the same
## monospace code font + size the script editor uses, plus the built-in minimap and
## current-line highlight — so the panel reads as part of Godot, not a foreign box.
## No-op headless (no editor theme/settings).
func _apply_editor_code_settings(code_edit: CodeEdit) -> void:
	code_edit.minimap_draw = true
	code_edit.highlight_current_line = true
	code_edit.draw_tabs = true
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var editor_theme: Theme = EditorInterface.get_editor_theme()
	if editor_theme != null and editor_theme.has_font("source", "EditorFonts"):
		code_edit.add_theme_font_override("font", editor_theme.get_font("source", "EditorFonts"))
		if editor_theme.has_font_size("source_size", "EditorFonts"):
			code_edit.add_theme_font_size_override("font_size", editor_theme.get_font_size("source_size", "EditorFonts"))

## Recompiles the current sheet into the panel (text + source map) and re-highlights.
func _refresh_code_panel() -> void:
	if _code_edit == null or _side_panel == null or not _side_panel.visible:
		return
	_refresh_functions_list()
	if _current_sheet == null:
		_code_edit.text = ""
		_code_source_map = []
		_code_panel_highlight = Vector2i(-1, -1)
		return
	var compile_result: Dictionary = SheetCompiler.compile(_current_sheet, "user://eventforge_code_panel_preview.gd")
	_code_edit.text = str(compile_result.get("output", ""))
	_code_source_map = compile_result.get("source_map", [])
	_code_panel_highlight = Vector2i(-1, -1)
	_update_code_panel_highlight()

## Repopulates the Functions overview list from the active sheet (signature + an ✦ for ACE-exposed
## functions). Cheap; runs whenever the side panel refreshes (i.e. on any edit while it's open).
func _refresh_functions_list() -> void:
	if _functions_list == null:
		return
	_functions_list.clear()
	if _current_sheet == null:
		return
	for function_resource: Variant in _current_sheet.functions:
		if function_resource is EventFunction:
			_functions_list.add_item(_format_function_signature(function_resource as EventFunction))

## "name(a, b)" plus a trailing ✦ when the function is exposed as an ACE (a reusable action/condition/
## expression in other sheets) — the at-a-glance signature shown in the Functions list.
func _format_function_signature(function: EventFunction) -> String:
	var param_ids: PackedStringArray = PackedStringArray()
	for param_variant: Variant in function.params:
		if param_variant is ACEParam:
			param_ids.append((param_variant as ACEParam).id)
	var signature: String = "%s(%s)" % [function.function_name, ", ".join(param_ids)]
	return (signature + "  ✦") if function.expose_as_ace else signature

## Right-click a function to delete it (the list is otherwise read-only — editing is via the rows).
func _on_functions_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT or _functions_menu == null:
		return
	_functions_list.select(index)
	_functions_menu.position = Vector2i(_functions_list.get_screen_position() + at_position)
	_functions_menu.reset_size()
	_functions_menu.popup()

func _on_functions_menu_id_pressed(id: int) -> void:
	if id == 0:
		_delete_selected_function()

## Removes the selected function from the sheet (undoable) and refreshes the list + preview.
func _delete_selected_function() -> void:
	if _current_sheet == null or _functions_list == null:
		return
	var selected: PackedInt32Array = _functions_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	if index < 0 or index >= _current_sheet.functions.size():
		return
	var removed_name: String = ""
	if _current_sheet.functions[index] is EventFunction:
		removed_name = (_current_sheet.functions[index] as EventFunction).function_name
	var changed: bool = _perform_undoable_sheet_edit("Delete Function", func() -> bool:
		if index < _current_sheet.functions.size():
			_current_sheet.functions.remove_at(index)
			return true
		return false)
	if changed:
		_mark_dirty("Deleted function %s()." % removed_name)
		_refresh_functions_list()

## Highlights the generated lines for the currently selected sheet row and scrolls to them.
func _update_code_panel_highlight() -> void:
	if _code_edit == null or _side_panel == null or not _side_panel.visible:
		return
	if _code_panel_highlight.x >= 0:
		for line in range(_code_panel_highlight.x, _code_panel_highlight.y + 1):
			if line < _code_edit.get_line_count():
				_code_edit.set_line_background_color(line, Color(0, 0, 0, 0))
	_code_panel_highlight = Vector2i(-1, -1)
	var selected: Resource = _active_view().get_selected_context().get("source_resource", null) if _viewport != null else null
	if selected == null:
		return
	var uid: String = str(selected.get_instance_id())
	for entry: Variant in _code_source_map:
		if not (entry is Dictionary) or str((entry as Dictionary).get("uid", "")) != uid:
			continue
		var start_line: int = int((entry as Dictionary).get("start", 0)) - 1
		var end_line: int = mini(int((entry as Dictionary).get("end", 0)) - 1, _code_edit.get_line_count() - 1)
		if start_line < 0 or end_line < start_line:
			continue
		for line in range(start_line, end_line + 1):
			_code_edit.set_line_background_color(line, CODE_PANEL_HIGHLIGHT_COLOR)
		_code_edit.set_caret_line(start_line)
		_code_panel_highlight = Vector2i(start_line, end_line)
		return

## Reverse provenance: clicking a line of generated code selects the sheet row that
## produced it. Reacts only to mouse releases (never caret moves), so the forward
## direction — selection setting the caret in _update_code_panel_highlight — cannot loop.
func _on_code_panel_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or mouse.pressed:
		return
	# The click already moved the caret; source maps are 1-based.
	_select_sheet_row_for_code_line(_code_edit.get_caret_line() + 1)

## The script editor's "Go to Sheet Row": shows the GDScript panel, refreshes the
## source map and selects the row that emitted the given 1-based generated line —
## errors and stack traces land on rows, not on generated code.
func goto_generated_line(line: int) -> void:
	_ensure_code_panel()
	if not _side_panel.visible:
		_toggle_code_panel()
	else:
		_refresh_code_panel()
	if _code_edit != null and line > 0:
		_code_edit.set_caret_line(maxi(line - 1, 0))
	_select_sheet_row_for_code_line(line)

## Picks the most specific source-map entry containing the line (smallest range wins, so
## in-flow blocks beat their event and events beat their trigger function), then walks
## outward until something selects — inner entries may reference resources without rows of
## their own (e.g. an in-flow block inside an event's actions).
func _select_sheet_row_for_code_line(line: int) -> void:
	if _viewport == null:
		return
	var containing: Array = []
	for entry: Variant in _code_source_map:
		if not (entry is Dictionary):
			continue
		var start: int = int((entry as Dictionary).get("start", 0))
		var end: int = int((entry as Dictionary).get("end", 0))
		if line >= start and line <= end:
			containing.append(entry)
	containing.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (int(a.get("end", 0)) - int(a.get("start", 0))) < (int(b.get("end", 0)) - int(b.get("start", 0)))
	)
	for entry: Variant in containing:
		var resource: Resource = instance_from_id(int(str((entry as Dictionary).get("uid", "0")))) as Resource
		if resource != null and _viewport.select_resource(resource):
			_update_code_panel_highlight()
			return

## Double-clicking a GDScript block opens a CodeEdit dialog with compile-check linting and
## sheet-symbol completion. in_flow blocks live inside an event's actions (statements);
## class-level blocks are tree rows (helper functions, @onready vars, signals…).
func _on_viewport_raw_code_edit_requested(raw_resource: Resource, in_flow: bool) -> void:
	var raw_row: RawCodeRow = raw_resource as RawCodeRow
	if raw_row == null:
		return
	_ensure_raw_code_dialog()
	_raw_code_target = raw_row
	_raw_code_in_flow = in_flow
	_raw_code_hint.text = (
		"Runs inside this event, right after its conditions pass — full GDScript, with the sheet's variables and host in scope. Written verbatim into the .gd."
		if in_flow
		else "Top-level GDScript — helper functions, @onready vars, signals… anything no ACE covers. Written verbatim into the .gd and callable from your events."
	)
	_raw_code_edit.text = raw_row.code
	_validate_raw_code()
	_raw_code_dialog.popup_centered(Vector2i(680, 460))
	_raw_code_edit.grab_focus()

func _ensure_raw_code_dialog() -> void:
	if _raw_code_dialog != null:
		return
	_raw_code_dialog = ConfirmationDialog.new()
	_raw_code_dialog.title = "Edit GDScript Block"
	# Standard popup margins, consistent with the other plugin dialogs.
	var layout_box: VBoxContainer = EventSheetPopupUI.form_box()
	layout_box.custom_minimum_size = Vector2(640.0, 0.0)
	layout_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The hint + lint labels are autowrap but WIDTH-BOUNDED (custom_minimum_size.x): a
	# ConfirmationDialog sizes to its content's minimum, and an UNBOUNDED autowrap label reports a
	# runaway min height during the initial zero-width pass (it wraps to one glyph per line), which
	# ballooned this popup to thousands of px tall on launch. Bounding the width makes the min-size
	# pass wrap at a sane width while still letting long lint errors wrap at runtime.
	_raw_code_hint = Label.new()
	_raw_code_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_raw_code_hint.custom_minimum_size = Vector2(620.0, 0.0)
	layout_box.add_child(_raw_code_hint)
	_raw_code_edit = CodeEdit.new()
	_raw_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_raw_code_edit.custom_minimum_size = Vector2(620.0, 330.0)
	_raw_code_edit.gutters_draw_line_numbers = true
	_raw_code_edit.indent_use_spaces = false
	# GDScriptSyntaxHighlighter is editor-only; headless test runs skip it.
	if Engine.is_editor_hint() and ClassDB.class_exists("GDScriptSyntaxHighlighter"):
		_raw_code_edit.syntax_highlighter = ClassDB.instantiate("GDScriptSyntaxHighlighter")
	_raw_code_edit.code_completion_enabled = true
	EventSheetPopupUI.configure_code_editor(_raw_code_edit)  # auto-close brackets/quotes at the source
	_raw_code_edit.text_changed.connect(_validate_raw_code)
	_raw_code_edit.code_completion_requested.connect(_populate_raw_code_completion)
	layout_box.add_child(_raw_code_edit)
	_raw_code_lint_label = Label.new()
	_raw_code_lint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_raw_code_lint_label.custom_minimum_size = Vector2(620.0, 0.0)
	layout_box.add_child(_raw_code_lint_label)
	_raw_code_dialog.add_child(EventSheetPopupUI.margined(layout_box))
	_raw_code_dialog.confirmed.connect(_on_raw_code_dialog_confirmed)
	# "Open in Godot" hands the block off to Godot's own script editor (more room, full tooling); the
	# in-popup editor stays for quick inline edits. custom_action fires for non-OK/Cancel buttons.
	var open_in_godot: Button = _raw_code_dialog.add_button("Open in Godot Script Editor", false, "open_in_godot")
	open_in_godot.tooltip_text = "Edit this block in Godot's script editor — your changes return when you come back to the sheet."
	_raw_code_dialog.custom_action.connect(func(action: StringName) -> void:
		if String(action) == "open_in_godot":
			_open_raw_code_block_in_godot())
	add_child(_raw_code_dialog)

## Compile-checks the dialog's code against the sheet context (host class + sheet symbols).
func _validate_raw_code() -> void:
	if _raw_code_edit == null or _raw_code_lint_label == null:
		return
	# Live hard-block: a STRUCTURAL error (unbalanced brackets / unterminated string) disables Save
	# immediately — always wrong, so it can never lock the user out on a lint false positive (a runtime-only
	# symbol). Semantic lint errors keep Save enabled but are caught on confirm (which re-opens the dialog).
	var structural: String = EventSheetGDScriptLint.structural_syntax_error(_raw_code_edit.text)
	if _raw_code_dialog != null:
		_raw_code_dialog.get_ok_button().disabled = not structural.is_empty()
	if not structural.is_empty():
		_raw_code_lint_label.text = "✗ %s" % structural
		_raw_code_lint_label.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))
		return
	var lint_result: Dictionary = EventSheetGDScriptLint.lint(_raw_code_edit.text, _raw_code_in_flow, _current_sheet)
	if bool(lint_result.get("ok", true)):
		_raw_code_lint_label.text = "✓ Compiles"
		_raw_code_lint_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.6))
	else:
		_raw_code_lint_label.text = "✗ %s" % str(lint_result.get("error", "Does not compile."))
		_raw_code_lint_label.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))

## Supplies sheet variables/functions and host-class members as completion candidates.
func _populate_raw_code_completion() -> void:
	if _raw_code_edit == null:
		return
	# Context-aware: `host.` / typed-variable. / $Behavior. offer that type's members.
	for candidate: Dictionary in EventSheetGDScriptLint.completion_for_context(_text_before_caret(_raw_code_edit), _current_sheet):
		var label: String = str(candidate.get("label", ""))
		_raw_code_edit.add_code_completion_option(int(candidate.get("kind", CodeEdit.KIND_PLAIN_TEXT)), label, label)
	_raw_code_edit.update_code_completion_options(true)
	_raw_code_edit.set_code_hint(EventSheetGDScriptLint.signature_hint(_text_before_caret(_raw_code_edit), _current_sheet))

## The current line's text up to the caret (what context completion/hints parse).
static func _text_before_caret(edit: CodeEdit) -> String:
	return edit.get_line(edit.get_caret_line()).substr(0, edit.get_caret_column())

func _on_raw_code_dialog_confirmed() -> void:
	if _raw_code_target == null:
		return
	var target: RawCodeRow = _raw_code_target
	# Guardrail: broken GDScript never commits — the dialog reopens with the text intact.
	var commit_lint: Dictionary = EventSheetGDScriptLint.lint(_raw_code_edit.text, _raw_code_in_flow, _current_sheet)
	if not bool(commit_lint.get("ok", true)):
		_set_status("GDScript block not saved: fix the error first (or Cancel to discard).", true)
		if is_inside_tree():
			_raw_code_dialog.call_deferred("popup_centered", Vector2i(680, 420))
		return
	_raw_code_target = null
	var new_code: String = _raw_code_edit.text
	var changed: bool = _perform_undoable_sheet_edit("Edit GDScript Block", func() -> bool:
		if target.code == new_code:
			return false
		target.code = new_code
		return true
	)
	if changed:
		_refresh_after_edit()
		_mark_dirty("Updated GDScript block.")

# ── Paste GDScript as events ─────────────────────────────────────────────────

## Returns true when the clipboard text reads like GDScript (conservative: a paste that is
## not code must fall through to the internal clipboard untouched).
static func _looks_like_gdscript(text: String) -> bool:
	var code_line: RegEx = RegEx.new()
	if code_line.compile("(?m)^(func |var |@export|@onready|signal |extends |class_name |if .*:|for .*:|while .*:|match .*:)") != OK:
		return false
	return code_line.search(text) != null

## Pastes raw GDScript copied from anywhere, converted through the same pipeline that
## opens .gd files as sheets: the lossless rule keeps every line (unrecognized code stays
## verbatim GDScript block rows), declarations verify-lift to variable rows, and trigger
## functions ACE-lift into real events when the round-trip verifies. Returns false for
## non-code clipboards so the regular paste paths continue.
func _paste_gdscript_text(text: String) -> bool:
	if text.strip_edges().is_empty() or EventSheetSnippet.is_snippet_text(text):
		return false
	if not _looks_like_gdscript(text):
		return false
	if not _ensure_sheet_for_editing():
		return false
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(text)
	if imported.events.is_empty():
		return false
	var rows: Array = imported.events.duplicate()
	var lifted_events: int = 0
	var context: Dictionary = _active_view().get_selected_context()
	var anchor: Resource = context.get("source_resource", null)
	var changed: bool = _perform_undoable_sheet_edit("Paste GDScript", func() -> bool:
		var insert_after: Resource = anchor
		for row: Variant in rows:
			if row is EventRow:
				_assign_fresh_event_uids(row)
			_insert_row_below_selection(row, insert_after)
			insert_after = row
		return true
	)
	if not changed:
		return false
	for row: Variant in rows:
		if row is EventRow:
			lifted_events += 1
	_refresh_after_edit()
	if lifted_events > 0:
		_mark_dirty("Pasted GDScript: %d row(s), %d event(s) auto-converted." % [rows.size(), lifted_events])
	else:
		_mark_dirty("Pasted GDScript as %d block row(s) — no trigger functions to convert." % rows.size())
	return true

# ── Visual theme editor ───────────────────────────────────────────────────────
var _theme_editor: EventSheetThemeEditor = null

func _open_theme_editor() -> void:
	if _theme_editor == null:
		_theme_editor = EventSheetThemeEditor.new()
	_theme_editor.open(self, _active_theme_style)

## Called by the theme editor's "Apply To Current Sheet": assigns the working style to the
## active sheet undoably and repaints.
func apply_theme_style(style: EventSheetEditorStyle) -> void:
	if _current_sheet == null or style == null:
		return
	var changed: bool = _perform_undoable_sheet_edit("Apply Theme", func() -> bool:
		_current_sheet.editor_style = style
		return true
	)
	if changed:
		_active_theme_style = style
		_refresh_after_edit()
		_refresh_theme_picker_selection()
		_mark_dirty("Theme applied from the theme editor.")

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
	_struct_rows.open_enum_dialog(enum_resource)

func _open_signal_dialog(signal_resource: Resource) -> void:  # viewport signal_edit_requested
	_struct_rows.open_signal_dialog(signal_resource)

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
func _on_variable_dialog_confirmed(var_name: String, type_name: String, default_value: Variant, scope: String, context: Dictionary = {}, is_constant: bool = false, exported: bool = true, combo_options: PackedStringArray = PackedStringArray(), attributes: Dictionary = {}) -> void:  # _variable_dlg.variable_confirmed
	_variables._on_variable_dialog_confirmed(var_name, type_name, default_value, scope, context, is_constant, exported, combo_options, attributes)
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

# ── Multi-view: split view (same sheet, two panes — VSCode-style) → dock/multi_view_manager.gd ──
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
	_set_status("Simple mode ON — advanced entries hidden." if enabled else "Expert mode — all entries shown.")

func _load_simple_mode_preference() -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings != null:
		_simple_mode = bool(settings.get_project_metadata("eventsheets", "simple_mode", false))

## Declutter toggle: show/hide the trailing "+ Add event…" affordance rows across every
## live view, and reflect the new state in the View menu checkbox.
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

## Toggles a floating OS window hosting another full-editing pane over the same sheet —
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
	_detached_window.title = "Event Sheet — detached view"
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
	_set_status("Detached view opened — drag it anywhere; both panes edit the same sheet.")

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
## others — e.g. keep the split zoomed out as an overview and click rows to focus them
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

# ── Export as Addon Pack (coverage Phase C) ─# ── Export as Addon Pack (coverage Phase C) ────────────────────────────────────────

## One-click addon publishing: writes the current behavior sheet (+ compiled script) into
## eventsheet_addons/<class_snake>/ where the zero-config scanner publishes its ACEs
## project-wide — the same layout the bundled packs use. base_dir_override is for tests.
func _export_addon_pack(base_dir_override: String = "") -> void:
	if _current_sheet == null:
		return
	if not _current_sheet.behavior_mode or _current_sheet.custom_class_name.strip_edges().is_empty():
		_set_status("Addon packs are behavior sheets — enable behavior mode and set a class name first (Sheet Type).", true)
		return
	var class_name_text: String = _current_sheet.custom_class_name.strip_edges()
	if not EventSheetIdentifierRules.is_valid(class_name_text):
		_set_status("\"%s\" can't be a class name (letters/digits/underscores, not a keyword)." % class_name_text, true)
		return
	var folder_name: String = class_name_text.to_snake_case()
	var base_dir: String = base_dir_override if not base_dir_override.is_empty() else "res://eventsheet_addons/%s" % folder_name
	var base_path: String = "%s/%s" % [base_dir, folder_name]
	DirAccess.make_dir_recursive_absolute(base_dir)
	var pack_sheet: EventSheetResource = _current_sheet.duplicate(true)
	var save_error: Error = ResourceSaver.save(pack_sheet, base_path + ".tres")
	if save_error != OK:
		_set_status("Export failed: couldn't save %s.tres (error %d)." % [base_path, save_error], true)
		return
	# Adopt the saved path BEFORE compiling so the generated "# Source:" header matches a
	# recompile of the exported .tres (the same no-drift rule the bundled packs follow).
	pack_sheet.take_over_path(base_path + ".tres")
	var compile_result: Dictionary = SheetCompiler.compile(pack_sheet, base_path + ".gd")
	if not bool(compile_result.get("success", false)):
		_set_status("Export failed: the sheet doesn't compile (%s)." % str(compile_result.get("errors")), true)
		return
	# Auto-docs: shared packs are documented by default.
	var readme_file: FileAccess = FileAccess.open("%s/README.md" % base_dir, FileAccess.WRITE)
	if readme_file != null:
		readme_file.store_string(_generate_pack_readme(pack_sheet))
		readme_file.close()
	# Lane A composition: packs travel complete — bundle included sheets unless the
	# project policy says reference-only.
	var bundled_count: int = 0
	if str(SheetCompiler._addon_policy("export_bundling", "bundle")) == "bundle":
		for include_path: String in pack_sheet.includes:
			if ResourceLoader.exists(include_path):
				var bundle_target: String = "%s/%s" % [base_dir, include_path.get_file()]
				if bundle_target != include_path and DirAccess.copy_absolute(include_path, bundle_target) == OK:
					bundled_count += 1
	if Engine.is_editor_hint() and is_inside_tree():
		EditorInterface.get_resource_filesystem().scan()
	var bundle_note: String = " (+%d bundled include(s))" % bundled_count if bundled_count > 0 else ""
	_set_status("Exported addon pack to %s (.tres + .gd)%s — its ACEs are now published project-wide." % [base_dir, bundle_note])

# ── Godot-feel: find bar, keyboard row ops, editor-native defaults ─# ── Godot-feel: find bar, keyboard row ops, editor-native defaults ─# ── Godot-feel: find bar, keyboard row ops, editor-native defaults ────────────────────
var _find_bar: HBoxContainer = null
var _find_edit: LineEdit = null
var _find_count_label: Label = null
var _replace_edit: LineEdit = null
var _find_resource_matches: Array[Resource] = []
var _find_cursor: int = -1

# ── Live Values panel — extracted to dock/live_values_panel.gd ───────────────────────
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

## Live event-trace sink (wired by the plugin): highlight the firing rows in every pane.
func update_fired_events(uids: PackedStringArray) -> void:
	for pane: EventSheetViewport in [_viewport, _multi_view._split_viewport, _detached_viewport]:
		if pane != null:
			pane.set_fired_events(uids)

## Tools ▸ Event Trace — highlights the rows whose events fire during a debug run (rung 3). It
## rides the Live Values stream, so it turns that on too. Recompile + run to start.
func _toggle_event_trace() -> void:
	if _current_sheet == null:
		return
	_current_sheet.emit_event_trace = not _current_sheet.emit_event_trace
	if _current_sheet.emit_event_trace:
		_current_sheet.emit_live_values = true
		_set_status("Event Trace ON: recompile and run — firing events highlight live (needs variables to stream).")
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

## Ctrl+F: a script-editor-style find bar (Enter/F3 next, Shift+F3 previous, Esc hides).
func _show_find_bar() -> void:
	_ensure_find_bar()
	_find_bar.visible = true
	_find_edit.grab_focus()
	_find_edit.select_all()

func _ensure_find_bar() -> void:
	if _find_bar != null:
		return
	_find_bar = HBoxContainer.new()
	_find_bar.name = "EventSheetFindBar"
	_find_edit = LineEdit.new()
	_find_edit.placeholder_text = "Find in sheet…  (Enter: next, Esc: close)"
	_find_edit.custom_minimum_size = Vector2(220.0, 0.0)
	_find_edit.text_changed.connect(_on_find_text_changed)
	_find_edit.text_submitted.connect(func(_text: String) -> void: _find_step(1))
	_find_edit.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventKey and (input_event as InputEventKey).pressed and (input_event as InputEventKey).keycode == KEY_ESCAPE:
			_find_bar.visible = false
			if _viewport != null:
				_viewport.grab_focus()
	)
	_find_bar.add_child(_find_edit)
	_find_count_label = Label.new()
	_find_count_label.text = ""
	_find_bar.add_child(_find_count_label)
	_replace_edit = LineEdit.new()
	_replace_edit.placeholder_text = "Replace with…"
	_replace_edit.custom_minimum_size = Vector2(160.0, 0.0)
	_find_bar.add_child(_replace_edit)
	var replace_button: Button = Button.new()
	replace_button.text = "Replace All"
	replace_button.pressed.connect(_replace_all_in_sheet)
	_find_bar.add_child(replace_button)
	var split_match_button: Button = Button.new()
	split_match_button.text = "Open in Split"
	split_match_button.tooltip_text = "Open the current match in the split pane."
	split_match_button.pressed.connect(_open_match_in_split)
	_find_bar.add_child(split_match_button)
	var close_button: Button = Button.new()
	close_button.text = "✕"
	close_button.flat = true
	close_button.pressed.connect(func() -> void: _find_bar.visible = false)
	_find_bar.add_child(close_button)
	_toolbar.add_child(_find_bar)

func _on_find_text_changed(text: String) -> void:
	_find_resource_matches = _viewport.search_all(text) if _viewport != null else []
	_find_cursor = -1
	if _find_resource_matches.is_empty():
		_find_count_label.text = "no matches" if not text.strip_edges().is_empty() else ""
		return
	_find_step(1)

func _find_step(direction: int) -> void:
	# Matches recompute on every step (results go stale after any edit) and search the
	# FULL tree — find lands inside folded groups by unfolding the path to the match.
	if _find_edit == null or _viewport == null or _find_edit.text.strip_edges().is_empty():
		return
	_find_resource_matches = _viewport.search_all(_find_edit.text)
	if _find_resource_matches.is_empty():
		if _find_count_label != null:
			_find_count_label.text = "no matches"
		return
	_find_cursor = wrapi(_find_cursor + direction, 0, _find_resource_matches.size())
	_find_count_label.text = "%d of %d" % [_find_cursor + 1, _find_resource_matches.size()]
	_viewport.reveal_resource(_find_resource_matches[_find_cursor])

## Replace All: substitutes the find text across comments, GDScript blocks, string
## params, pick-filter expressions, group names/descriptions and match branches —
## one undoable edit, count reported.
func _replace_all_in_sheet() -> void:
	if _viewport == null or _current_sheet == null or _find_edit == null or _replace_edit == null:
		return
	var find_text: String = _find_edit.text
	if find_text.is_empty():
		_set_status("Type something in Find first.", true)
		return
	var replace_text: String = _replace_edit.text
	var counter: Dictionary = {"count": 0}
	var changed: bool = _perform_undoable_sheet_edit("Replace All", func() -> bool:
		_replace_in_rows(_current_sheet.events, find_text, replace_text, counter)
		for function_resource: Variant in _current_sheet.functions:
			if function_resource is EventFunction:
				_replace_in_rows((function_resource as EventFunction).events if not (function_resource as EventFunction).events.is_empty() else (function_resource as EventFunction).rows, find_text, replace_text, counter)
		return int(counter.get("count", 0)) > 0
	)
	if changed:
		_refresh_after_edit()
		_mark_dirty("Replaced %d occurrence(s)." % int(counter.get("count", 0)))
	else:
		_set_status("No matches for \"%s\"." % find_text)

func _replace_in_rows(rows: Array, find_text: String, replace_text: String, counter: Dictionary) -> void:
	for row: Variant in rows:
		if row is CommentRow:
			counter["count"] = int(counter.get("count", 0)) + (row as CommentRow).text.count(find_text)
			(row as CommentRow).text = (row as CommentRow).text.replace(find_text, replace_text)
		elif row is RawCodeRow:
			counter["count"] = int(counter.get("count", 0)) + (row as RawCodeRow).code.count(find_text)
			(row as RawCodeRow).code = (row as RawCodeRow).code.replace(find_text, replace_text)
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			counter["count"] = int(counter.get("count", 0)) + group.group_name.count(find_text) + group.description.count(find_text)
			group.group_name = group.group_name.replace(find_text, replace_text)
			group.name = group.group_name
			group.description = group.description.replace(find_text, replace_text)
			_replace_in_rows(group.events if not group.events.is_empty() else group.rows, find_text, replace_text, counter)
		elif row is EventRow:
			var event_row: EventRow = row as EventRow
			for ace: Variant in event_row.conditions + event_row.actions:
				if ace is RawCodeRow:
					counter["count"] = int(counter.get("count", 0)) + (ace as RawCodeRow).code.count(find_text)
					(ace as RawCodeRow).code = (ace as RawCodeRow).code.replace(find_text, replace_text)
				elif ace is MatchRow:
					counter["count"] = int(counter.get("count", 0)) + (ace as MatchRow).branches_text.count(find_text)
					(ace as MatchRow).branches_text = (ace as MatchRow).branches_text.replace(find_text, replace_text)
				elif ace is Resource and ace.get("params") is Dictionary:
					if ace.get("comment") is String and not str(ace.get("comment")).is_empty():
						counter["count"] = int(counter.get("count", 0)) + str(ace.get("comment")).count(find_text)
						ace.set("comment", str(ace.get("comment")).replace(find_text, replace_text))
					var params: Dictionary = ace.get("params")
					for key: Variant in params.keys():
						if params[key] is String:
							counter["count"] = int(counter.get("count", 0)) + (params[key] as String).count(find_text)
							params[key] = (params[key] as String).replace(find_text, replace_text)
			for pick: Variant in event_row.pick_filters:
				if pick is PickFilter:
					counter["count"] = int(counter.get("count", 0)) + (pick as PickFilter).collection_value.count(find_text) + (pick as PickFilter).predicate_expression.count(find_text) + (pick as PickFilter).order_by_expression.count(find_text)
					(pick as PickFilter).collection_value = (pick as PickFilter).collection_value.replace(find_text, replace_text)
					(pick as PickFilter).predicate_expression = (pick as PickFilter).predicate_expression.replace(find_text, replace_text)
					(pick as PickFilter).order_by_expression = (pick as PickFilter).order_by_expression.replace(find_text, replace_text)
			if not event_row.with_node_target.is_empty():
				counter["count"] = int(counter.get("count", 0)) + event_row.with_node_target.count(find_text)
				event_row.with_node_target = event_row.with_node_target.replace(find_text, replace_text)
			_replace_in_rows(event_row.sub_events, find_text, replace_text, counter)

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
		_mark_dirty("Group \"%s\" is %s — Set Group Active targets \"%s\"." % [group.group_name, "runtime-toggleable" if group.runtime_toggleable else "compile-time only again", group.group_name.to_snake_case()])

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
		_set_status("Registered autoload \"%s\" — every sheet (and script) can call it now." % _current_sheet.autoload_name)
	else:
		_set_status(problem, true)

## The testable core: compiles next to the sheet and writes the autoload entry.
## Returns "" on success or the user-facing problem.
func _register_autoload_entry(sheet: EventSheetResource, sheet_path: String) -> String:
	var autoload_name: String = sheet.autoload_name.strip_edges()
	if autoload_name.is_empty() or not EventSheetIdentifierRules.is_valid(autoload_name):
		return "Autoload needs a valid name (Sheet Type… → Autoload name)."
	if sheet_path.is_empty():
		return "Save the sheet first — the autoload entry must point at a real file."
	var output_path: String = sheet_path.get_basename() + ".gd"
	var compile_result: Dictionary = SheetCompiler.compile(sheet, output_path)
	if not bool(compile_result.get("success", false)):
		return "Autoload not registered: the sheet doesn't compile (%s)." % str(compile_result.get("errors"))
	var setting_name: String = "autoload/%s" % autoload_name
	var target_value: String = "*%s" % output_path
	if ProjectSettings.has_setting(setting_name) and str(ProjectSettings.get_setting(setting_name)) != target_value:
		return "An autoload named \"%s\" already exists and points elsewhere — pick another name." % autoload_name
	ProjectSettings.set_setting(setting_name, target_value)
	if Engine.is_editor_hint():
		ProjectSettings.save()
	return ""

# ── Addon-author loop — extracted to dock/author_loop.gd ─────────────────────────────
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

# ── Project-wide find / replace / usages — extracted to dock/project_find.gd ─────────
# (Dock decomposition arc: state + logic live in the helper; these delegates keep the
# public/test surface stable.)
var _project_find: EventSheetProjectFind = null

func _open_project_find(initial_query: String = "") -> void:
	if _project_find == null:
		_project_find = EventSheetProjectFind.new(self)
	_project_find.open(initial_query)

# ── Project Doctor — health-audit window → dock/project_doctor_panel.gd ──
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
	return count

## Tools ▸ Check Sheet for Errors — run diagnostics on demand and report.
func _run_diagnostics_action() -> void:
	if _current_sheet == null:
		_set_status("Open or create a sheet first.", true)
		return
	var count: int = _run_diagnostics()
	if count > 0:
		_set_status("%d row(s) need attention — jumped to the first (hover the red rows for details)." % count, true)
	else:
		_set_status("No issues found — every ƒx expression and GDScript block compiles.")

## Fixed structural keys (not rebindable — they're grammar, not preference): shown read-only in the
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

## Writes the always-current project vocabulary reference (EventSheetVocabularyDoc) —
## the answer to "what can I say in this project?" as one committed markdown file.
func _generate_vocabulary_doc() -> void:
	var doc_path: String = EventSheetVocabularyDoc.write()
	if doc_path.is_empty():
		_set_status("Couldn't write the vocabulary doc to %s." % EventSheetVocabularyDoc.doc_path(), true)
		return
	if Engine.is_editor_hint() and is_inside_tree():
		EditorInterface.get_resource_filesystem().scan()
	_set_status("Vocabulary doc written to %s." % doc_path)

# ── Sheet backups — the save-time ring (core in EventSheetBackups) ────────────────────
var _backups_window: Window = null
var _backups_list: ItemList = null

func _open_sheet_backups() -> void:
	if _current_sheet == null or _current_sheet_path.is_empty():
		_set_status("Backups track saved sheets — save this sheet first.", true)
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
		restore_button.text = "Restore into editor (unsaved — Save to keep)"
		restore_button.pressed.connect(_on_restore_backup_pressed)
		box.add_child(restore_button)
		var body: MarginContainer = EventSheetPopupUI.margined(box)
		body.set_anchors_preset(Control.PRESET_FULL_RECT)
		_backups_window.add_child(body)
		add_child(_backups_window)
	_backups_list.clear()
	for backup_path: String in EventSheetBackups.list_backups(_current_sheet_path):
		var stamp: String = Time.get_datetime_string_from_unix_time(int(FileAccess.get_modified_time(backup_path))).replace("T", " ")
		_backups_list.add_item("%s — %s" % [stamp, backup_path.get_file()])
		_backups_list.set_item_metadata(_backups_list.item_count - 1, backup_path)
	if _backups_list.item_count == 0:
		_backups_list.add_item("(no backups yet — they appear from the second save on)")
		_backups_list.set_item_disabled(0, true)
	_backups_window.popup_centered()

func _on_restore_backup_pressed() -> void:
	var selected: PackedInt32Array = _backups_list.get_selected_items()
	if selected.is_empty() or _backups_list.get_item_metadata(selected[0]) == null:
		return
	_restore_backup_path(str(_backups_list.get_item_metadata(selected[0])))
	_backups_window.hide()

## Restores a backup INTO the editor as an unsaved change: every storage property of
## the backup is copied onto the open sheet (same object — tabs, viewport and code
## panel stay coherent), the user reviews and saves to keep it. Nothing on disk
## changes until that save, and the save itself backs up the pre-restore state.
func _restore_backup_path(backup_path: String) -> void:
	var backup: EventSheetResource = ResourceLoader.load(backup_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
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
	_set_status("Backup restored into the editor (unsaved) — Save to keep it, reopen the sheet to discard.")

## Writes a deep copy of the current sheet into the project templates dir (never
## overwrites — an existing name gets a -2/-3 suffix). It joins the New… menu
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
	_set_status("Template saved: %s — it's in the New… menu now." % target)

static func list_project_sheets() -> PackedStringArray:
	return EventSheetProjectFind.list_project_sheets()

static func find_in_sheet(sheet: EventSheetResource, needle: String) -> Array:
	return EventSheetProjectFind.find_in_sheet(sheet, needle)

## Find-bar "Open in Split" → dock/multi_view_manager.gd (jumps the split pane to the current match).
func _open_match_in_split() -> void:
	_multi_view._open_match_in_split()

# ── Bookmarks panel — extracted to dock/bookmarks_panel.gd ───────────────────────────
var _bookmarks_panel: EventSheetBookmarksPanel = null

func _ensure_bookmarks_panel() -> EventSheetBookmarksPanel:
	if _bookmarks_panel == null:
		_bookmarks_panel = EventSheetBookmarksPanel.new(self)
	return _bookmarks_panel

# Forwarding properties (tests assign these directly — keep them settable).
var _bookmarks_window: Window:
	get: return _ensure_bookmarks_panel().window
	set(value): _ensure_bookmarks_panel().window = value
var _bookmarks_list: ItemList:
	get: return _ensure_bookmarks_panel().list
	set(value): _ensure_bookmarks_panel().list = value

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

## Editor-native defaults: inherit the user's editor theme + display scale when no
## explicit sheet theme was chosen (presets/per-sheet themes still override).
## apply_zoom is true only for the initial setup — a live editor-theme change re-derives
## the style but must NOT re-apply the editor-scale zoom (that would clobber whatever the
## user manually zoomed to since opening the sheet).
func _apply_editor_native_defaults(apply_zoom: bool = true) -> void:
	if not Engine.is_editor_hint() or _viewport == null:
		return
	if _active_theme_style == null:
		var derived: EventSheetEditorStyle = EventSheetEditorThemeDeriver.derive_from_editor()
		if derived != null:
			apply_theme_style(derived)
	if apply_zoom:
		var editor_scale: float = EditorInterface.get_editor_scale()
		if editor_scale > 1.01:
			_viewport.set_zoom_factor(editor_scale)

# ── Quick-add bar ("type to insert") ──────────────────────────────────────
var _quick_add_edit: LineEdit = null

## Best ACE for a quick-add query. Leading words match a definition (display name / id,
## with the picker's synonym phrasing honored); trailing words fill its parameters
## positionally as raw values. Returns {definition, params} or {}.
func _quick_match(query: String) -> Dictionary:
	var text: String = query.strip_edges().to_lower()
	if text.is_empty() or _ace_registry == null:
		return {}
	var queries: Array[String] = [text]
	for synonym_query: String in ACEPickerDialog._c3_synonym_queries(text):
		queries.append(synonym_query.to_lower())
	var best: ACEDefinition = null
	var best_score: int = 0
	var best_rest: String = ""
	var best_name_length: int = 1 << 30
	for definition: ACEDefinition in _ace_registry.get_all_definitions():
		if bool(definition.metadata.get("hidden", false)):
			continue
		for candidate_name: String in [definition.display_name.to_lower(), definition.id.to_lower()]:
			if candidate_name.is_empty():
				continue
			for candidate_query: String in queries:
				var score: int = 0
				var rest: String = ""
				if candidate_query == candidate_name:
					score = 100
				elif candidate_query.begins_with(candidate_name + " "):
					score = 90
					rest = candidate_query.substr(candidate_name.length() + 1)
				elif candidate_name.begins_with(candidate_query):
					score = 60
				elif candidate_name.contains(candidate_query):
					score = 40
				# Shorter matched names win ties (the query "process" should pick
				# OnProcess, not OnPhysicsProcess).
				if score > best_score or (score == best_score and candidate_name.length() < best_name_length):
					best = definition
					best_score = score
					best_rest = rest
					best_name_length = candidate_name.length()
	if best == null or best_score == 0:
		return {}
	var params: Dictionary = {}
	var values: PackedStringArray = best_rest.split(" ", false)
	for index in range(mini(values.size(), best.parameters.size())):
		var parameter: Variant = best.parameters[index]
		if parameter is Dictionary:
			params[str((parameter as Dictionary).get("id", ""))] = values[index]
	return {"definition": best, "params": params}

## Applies the best match: triggers/conditions become a new event; actions append via the
## standard apply flow (below the current selection). Returns true when something landed.
func _quick_add(query: String) -> bool:
	if not _ensure_sheet_for_editing():
		return false
	var matched: Dictionary = _quick_match(query)
	if matched.is_empty():
		_set_status("Quick add: nothing matches \"%s\"." % query.strip_edges(), true)
		return false
	var definition: ACEDefinition = matched.get("definition")
	var mode: String = "" if definition.ace_type == ACEDefinition.ACEType.ACTION else "new_condition_event"
	var context: Dictionary = {
		"mode": mode,
		"selected_resource": _active_view().get_selected_context().get("source_resource", null)
	}
	_apply_ace_definition(definition, matched.get("params", {}), context)
	return true

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

# ── Sheet Type dialog (what the sheet compiles into) → dock/sheet_type_dialog.gd ──
# The dialog shell lives in the helper; the field-builders below (_add_sheet_type_field is shared with the
# pick dialog) and the _apply_sheet_type_settings service (driven directly by the addon-composition / tags /
# tool / singleton tests) stay here, so only the dialog's _ensure / widget reach-ins were repointed.
func _open_sheet_type_dialog() -> void:  # Sheet menu / identity-banner edit / Tools menu
	_sheet_type.open()

func _add_sheet_type_field(form: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(130.0, 0.0)
	row.add_child(label)
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	form.add_child(row)
	return edit

## Like _add_sheet_type_field, but a small multi-line TextEdit — used for the class description,
## which compiles to a `##` doc comment (Godot's Create Node tooltip supports multiple lines).
func _add_sheet_type_multiline_field(form: VBoxContainer, label_text: String, placeholder: String) -> TextEdit:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(130.0, 0.0)
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)
	var edit: TextEdit = TextEdit.new()
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0.0, 54.0)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	row.add_child(edit)
	form.add_child(row)
	return edit

## Applies the chosen sheet type (0 = plain, 1 = custom node, 2 = behavior) undoably and
## refreshes every identity surface (banner, tab badge, header, lint context). `family_enabled` marks
## a named sheet as a Family (instances collected into group family_<class>); it's cleared for a plain
## sheet, which has no class name to derive a family group from.
func _apply_sheet_type_settings(type_index: int, class_name_text: String, icon_path: String, host_class_text: String, tool_enabled: bool = false, addon_tags: PackedStringArray = PackedStringArray(), include_paths: PackedStringArray = PackedStringArray(), uses_classes: PackedStringArray = PackedStringArray(), requires_classes: PackedStringArray = PackedStringArray(), autoload_name_text: String = "", class_description_text: String = "", family_enabled: bool = false) -> void:
	if _current_sheet == null:
		return
	var changed: bool = _perform_undoable_sheet_edit("Set Sheet Type", func() -> bool:
		_current_sheet.behavior_mode = type_index == 2
		# The class description rides with the named-type identity (cleared for a plain sheet,
		# which has no class_name to attach a doc to).
		_current_sheet.class_description = class_description_text.strip_edges() if type_index != 0 else ""
		# Autoload (Singleton) sheets: extends Node, addressed project-wide by name.
		_current_sheet.autoload_mode = type_index == 4
		_current_sheet.autoload_name = autoload_name_text.strip_edges() if type_index == 4 else ""
		if type_index == 4:
			_current_sheet.host_class = "Node"
		# Editor Tool preset: an EditorScript with @tool — pair with On Editor Run.
		_current_sheet.tool_mode = tool_enabled or type_index == 3
		_current_sheet.custom_class_name = class_name_text.strip_edges() if type_index != 0 else ""
		_current_sheet.custom_class_icon = icon_path.strip_edges() if type_index != 0 else ""
		# Family rides with the named-type identity: a plain sheet has no class to form a group from, so
		# clear it there (mirrors custom_class_name) to avoid a stale flag that would emit nothing.
		_current_sheet.is_family = family_enabled and type_index != 0
		# Plain sheets aren't addons: clear tags like the class name/icon (otherwise a
		# type switch would leave stale tags that never emit — silent confusion).
		_current_sheet.addon_tags = addon_tags if type_index != 0 else PackedStringArray()
		# Lane A composition (meta-packs): includes apply like tags; plain sheets keep
		# their includes too (library sheets predate addon composition).
		var applied_includes: Array[String] = []
		for include_path: String in include_paths:
			if not include_path.strip_edges().is_empty():
				applied_includes.append(include_path.strip_edges())
		_current_sheet.includes = applied_includes
		var applied_uses: Array[String] = []
		for uses_class: String in uses_classes:
			if not uses_class.strip_edges().is_empty():
				applied_uses.append(uses_class.strip_edges())
		_current_sheet.uses_addons = applied_uses
		var applied_requires: Array[String] = []
		for requires_class: String in requires_classes:
			if not requires_class.strip_edges().is_empty():
				applied_requires.append(requires_class.strip_edges())
		_current_sheet.requires_behaviors = applied_requires
		if type_index == 3:
			_current_sheet.host_class = "EditorScript"
		elif not host_class_text.strip_edges().is_empty():
			_current_sheet.host_class = host_class_text.strip_edges()
		return true
	)
	if changed:
		_refresh_after_edit()
		_refresh_title_strip()
		_refresh_tab_bar()
		_mark_dirty("Sheet type updated.")

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
	if not _ensure_sheet_for_editing():
		return
	# Double-clicking empty space reads as "I want a new event here" — open the ACE picker in new-event
	# mode so the user picks the first condition/trigger immediately, rather than dropping a blank event
	# they then have to fill. Selection is cleared first so the new event lands at the end (where they
	# clicked), not nested under whatever happened to be selected. Mirrors the "Add Event" toolbar button
	# and the "+ Add event…" footer, so every "make a new event" path opens the same picker.
	if _viewport != null:
		_viewport.clear_selection()
	_on_add_event_requested()

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
	if _context_row == null:
		return
	match id:
		ROW_MENU_ADD_SUB_EVENT:
			_insert_child_event_for_context_row()
		ROW_MENU_ADD_COMMENT_SUB_EVENT:
			_insert_child_comment_for_context_row()
		ROW_MENU_ADD_EVENT_BELOW:
			_insert_context_row_below(EventRow.new(), "Added event.")
		ROW_MENU_ADD_GROUP_BELOW:
			var group: EventGroup = EventGroup.new()
			group.name = "Group"
			group.group_name = group.name
			_insert_context_row_below(group, "Added group.")
		ROW_MENU_ADD_COMMENT_BELOW:
			var comment: CommentRow = CommentRow.new()
			comment.text = "Comment"
			_insert_context_row_below(comment, "Added comment.")
		ROW_MENU_ADD_VARIABLE_BELOW:
			_add_tree_variable_below_context_row()
		ROW_MENU_ADD_GDSCRIPT_BELOW:
			var raw_block: RawCodeRow = RawCodeRow.new()
			raw_block.code = "# GDScript — emitted verbatim at class level"
			_insert_context_row_below(raw_block, "Added GDScript block.")
		ROW_MENU_ADD_GDSCRIPT_ACTION:
			_add_gdscript_action_to_context_row()
		ROW_MENU_COPY:
			_on_copy_requested()
		ROW_MENU_PASTE:
			_on_paste_requested()
		ROW_MENU_DELETE:
			_delete_selected_rows()
		ROW_MENU_TOGGLE_CONDITION_BLOCK:
			_toggle_context_condition_block()
		ROW_MENU_TOGGLE_GROUP_FOLD:
			_toggle_context_group_fold()
		ROW_MENU_ADD_SUB_CONDITION:
			_open_sub_condition_picker_for_context_row()
		ROW_MENU_MAKE_ELSE:
			_set_context_else_mode(EventRow.ElseMode.ELSE)
		ROW_MENU_MAKE_ELIF:
			_set_context_else_mode(EventRow.ElseMode.ELIF)
		ROW_MENU_EXTRACT_GDSCRIPT_FN:
			_extract_to_function_requested()
		ROW_MENU_BREAKPOINT_CONDITION:
			_set_breakpoint_condition_requested()
		ROW_MENU_TOGGLE_ENABLED:
			_toggle_context_row_enabled()
		ROW_MENU_EDIT_COMMENT:
			if _context_row.source_resource is CommentRow:
				_open_comment_dialog(_context_row.source_resource)
			else:
				_set_status("Select a comment row to edit it.", true)
		ROW_MENU_ATTACH_COMMENT:
			if _context_row.source_resource is CommentRow:
				_attach_comment_to_event_above(_context_row.source_resource as CommentRow)
			else:
				_set_status("Only comment rows can attach to an event.", true)
		ROW_MENU_ADD_PICK_FILTER:
			_open_pick_filter_dialog(_context_row.source_resource, -1)
		ROW_MENU_SCOPE_TO_NODE:
			if _context_row != null and _context_row.source_resource is EventRow:
				_open_with_node_dialog(_context_row.source_resource)
		ROW_MENU_ADD_ENUM:
			var new_enum: EnumRow = EnumRow.new()
			_insert_context_row_below(new_enum, "Added enum.")
			_open_enum_dialog(new_enum)
		ROW_MENU_OPEN_IN_SPLIT:
			_open_row_in_split(_context_row)
		ROW_MENU_ADD_SIGNAL:
			var new_signal: SignalRow = SignalRow.new()
			_insert_context_row_below(new_signal, "Added signal.")
			_open_signal_dialog(new_signal)
		ROW_MENU_ADD_MATCH:
			if _context_row.source_resource is EventRow:
				var new_match: MatchRow = MatchRow.new()
				var match_host: EventRow = _context_row.source_resource as EventRow
				var added_match: bool = _perform_undoable_sheet_edit("Add Match", func() -> bool:
					match_host.actions.append(new_match)
					return true
				)
				if added_match:
					_refresh_after_edit()
					_open_match_dialog(new_match)
			else:
				_set_status("Select an event to add a match to its actions.", true)
		ROW_MENU_FIND_USAGES:
			var usage_target: Resource = _context_row.source_resource if _context_row != null else null
			var usage_query: String = ""
			if usage_target is LocalVariable:
				usage_query = (usage_target as LocalVariable).name
			elif usage_target is EventGroup:
				usage_query = (usage_target as EventGroup).group_name
			elif _context_row != null and not _context_row.spans.is_empty():
				usage_query = str(_context_row.spans[0].text).get_slice(":", 0).strip_edges()
			if usage_query.is_empty():
				_set_status("Nothing identifiable to search for on this row.", true)
			else:
				_open_project_find(usage_query)
		ROW_MENU_GROUP_RUNTIME:
			_toggle_group_runtime()
		ROW_MENU_GROUP_COLOR:
			_open_group_color_picker()
		ROW_MENU_BULK_TOGGLE_ENABLED:
			_bulk_set_enabled_on(_top_level_selected_resources())
		ROW_MENU_BULK_DUPLICATE:
			_bulk_duplicate_rows(_top_level_selected_resources())
		ROW_MENU_BULK_GROUP:
			var group_problem: String = _bulk_group_rows(_top_level_selected_resources())
			if not group_problem.is_empty():
				_set_status(group_problem, true)
		ROW_MENU_SAVE_SNIPPET:
			_open_save_snippet_dialog()
		ROW_MENU_INSERT_SNIPPET:
			_open_insert_snippet()
		ROW_MENU_EDIT_GROUP_DESC:
			if _context_row.source_resource is EventGroup:
				var described_group: EventGroup = _context_row.source_resource as EventGroup
				if described_group.description.strip_edges().is_empty():
					var seeded: bool = _perform_undoable_sheet_edit("Add Group Description", func() -> bool:
						described_group.description = "Description"
						return true
					)
					if seeded:
						_refresh_after_edit()
				_set_status("Double-click the description line (or slow-double-click) to edit it.")
			else:
				_set_status("Select a group to edit its description.", true)

# ── Bulk operations on the multi-selection — bodies in EventSheetRowEditOps (dock/row_edit_ops.gd).
# Thin delegates: the toolbar bulk actions + tedium_test call these on the dock by name.
func _bulk_set_enabled_on(targets: Array) -> void:
	_row_edit_ops._bulk_set_enabled_on(targets)

func _bulk_duplicate_rows(targets: Array) -> void:
	_row_edit_ops._bulk_duplicate_rows(targets)

func _bulk_group_rows(targets: Array) -> String:
	return _row_edit_ops._bulk_group_rows(targets)

## Fresh uids on a duplicated row tree (groups recurse; EventRows re-bake stateful
## member uids — the paste contract).
func _refresh_clone_uids(resource: Resource) -> void:
	if resource is EventRow:
		_assign_fresh_event_uids(resource as EventRow)
	elif resource is EventGroup:
		var group: EventGroup = resource as EventGroup
		for child: Variant in (group.events if not group.events.is_empty() else group.rows):
			if child is Resource:
				_refresh_clone_uids(child as Resource)

# ── Asset drops with intent (the drag-into-layout reflex, grafted onto events):
# a scene dropped on an event row spawns, a sound plays — pre-filled, undoable. ───────

func _apply_asset_drop(target_event: Resource, asset_paths: PackedStringArray) -> void:
	if not (target_event is EventRow):
		_set_status("Drop scenes or sounds onto an event row to add a pre-filled action.", true)
		return
	if not _ensure_sheet_for_editing():
		return
	var counters: Dictionary = {"added": 0}
	var changed: bool = _perform_undoable_sheet_edit("Drop Asset", func() -> bool:
		for asset_path: String in asset_paths:
			var action: ACEAction = _action_for_asset(asset_path)
			if action != null:
				(target_event as EventRow).actions.append(action)
				counters["added"] = int(counters["added"]) + 1
		return int(counters["added"]) > 0)
	if changed:
		_mark_dirty("Added %d pre-filled action(s) from the dropped asset(s)." % int(counters["added"]))

## The pre-filled action for one dropped asset: scenes spawn (Spawn Scene At), sounds
## play (Play Sound) — the builtin descriptor's template baked exactly like a picker
## apply ({uid} re-baked per instance). Unknown extensions return null.
func _action_for_asset(asset_path: String) -> ACEAction:
	var extension: String = asset_path.get_extension().to_lower()
	var ace_id: String = ""
	var params: Dictionary = {}
	if extension in ["tscn", "scn"]:
		ace_id = "SpawnSceneAt"
		params = {"path": ACEParamsDialog.format_quoted_literal(asset_path), "position": "Vector2(0, 0)"}
	elif extension in ["ogg", "wav", "mp3"]:
		ace_id = "PlaySound"
		params = {"path": ACEParamsDialog.format_quoted_literal(asset_path)}
	else:
		return null
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		if descriptor.ace_id == ace_id:
			var action: ACEAction = ACEAction.new()
			action.provider_id = descriptor.provider_id
			action.ace_id = ace_id
			action.params = params
			action.codegen_template = str(descriptor.codegen_template)
			if action.codegen_template.contains("{uid}"):
				action.codegen_template = action.codegen_template.replace("{uid}", _fresh_uid_token())
			return action
	return null

# ── .gd preview / open-in-Godot / lift report — delegates to EventSheetPreviewGlue ────────
# The read-only .gd-preview banner, the "Edit Events" unlock, the glue that hands scripts/paths to
# Godot's own script editor (EditorInterface.edit_script), and the lift-report window now live in
# dock/preview_glue.gd. These thin forwarders keep the original names + signatures + returns so the
# in-file .connect() sites (below), the tests, and the sibling dock/ helpers (menu_bar →
# _open_lift_report; sheet_io + session_store → _refresh_preview_banner; new_addon_panel →
# _open_gdscript_path_in_godot; ace_apply → _on_preview_edit_requested) all resolve unchanged.
#
# WIDGETS STAY ON THE DOCK: `_preview_banner` + `_preview_label` (declared up top) — the glue's
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

# ── Sheet functions: the dialog with the expanding param list (Add ▾ → Function…) ────
var _function_dialog: EventSheetFunctionDialog = null

func _open_function_dialog() -> void:
	if not _ensure_sheet_for_editing():
		return
	if _function_dialog == null:
		_function_dialog = EventSheetFunctionDialog.new()
		_function_dialog.init_dialog(self)
		_function_dialog.set_taken_names_provider(func() -> PackedStringArray:
			var taken: PackedStringArray = PackedStringArray()
			if _current_sheet != null:
				for variable_name: Variant in _current_sheet.variables:
					taken.append(str(variable_name))
				for function_entry: Variant in _current_sheet.functions:
					if function_entry is EventFunction:
						taken.append((function_entry as EventFunction).function_name)
			return taken)
		_function_dialog.function_confirmed.connect(_apply_function_data)
	_function_dialog.open()

## Creates the EventFunction from validated dialog data (undoable). The body is
## authored as rows afterwards; CallFunction and the publish surface pick it up.
func _apply_function_data(data: Dictionary) -> void:
	var changed: bool = _perform_undoable_sheet_edit("Add Function", func() -> bool:
		var event_function: EventFunction = EventFunction.new()
		event_function.function_name = str(data.get("name"))
		event_function.return_type = int(data.get("return_type", TYPE_NIL))
		event_function.description = str(data.get("description", ""))
		for param_entry: Dictionary in (data.get("params", []) as Array):
			var param: ACEParam = ACEParam.new()
			param.id = str(param_entry.get("id"))
			param.type_name = str(param_entry.get("type_name", "Variant"))
			param.gdscript_default = str(param_entry.get("default", ""))
			param.description = str(param_entry.get("description", ""))
			event_function.params.append(param)
		event_function.expose_as_ace = bool(data.get("expose", false))
		event_function.ace_display_name = str(data.get("ace_display_name", ""))
		event_function.ace_category = str(data.get("ace_category", ""))
		# "Run only when" guards: the body runs inside an `if <guards>:` — an event-sheet-style
		# function gate (e.g. only act when a node setting is enabled). Each expression becomes an
		# Expression Is True condition on a wrapper row the body actions are authored under.
		var guards: PackedStringArray = PackedStringArray(data.get("guards", PackedStringArray()))
		if not guards.is_empty():
			var guard_row: EventRow = EventRow.new()
			for guard_expression: String in guards:
				var condition: ACECondition = ACECondition.new()
				condition.provider_id = "Core"
				condition.ace_id = "ExpressionIsTrue"
				condition.params = {"expr": guard_expression}
				guard_row.conditions.append(condition)
			event_function.events.append(guard_row)
		_current_sheet.functions.append(event_function)
		return true)
	if changed:
		_mark_dirty("Added function %s()." % str(data.get("name")))

# ── Welcome (Tools → Welcome…) — the window lives in dock/welcome_window.gd ──
func show_welcome_if_first_run() -> void:  # plugin calls this at editor startup (first run pops it)
	_welcome.show_if_first_run()

func show_welcome() -> void:  # Tools menu (id 13) + command palette ("Open Welcome")
	_welcome.show()

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

var _run_scene_menu: PopupMenu = null

## Sheet → playing game in one click: save (compile-on-save keeps the script fresh),
## find the scene(s) attaching this sheet's script (the doctor's reverse lookup),
## play the only one — or offer the pick menu.
func _run_from_sheet() -> void:
	if _current_sheet == null:
		return
	if _current_sheet.behavior_mode:
		_set_status("Behaviors run on a host — use Tools → Test Bench.", true)
		return
	_on_save_requested()
	if _current_sheet_path.is_empty():
		return  # Unsaved sheet: the Save As flow took over.
	var script_path: String = _run_target_script_path()
	var scenes: PackedStringArray = EventSheetProjectDoctor.scenes_attaching(script_path)
	if scenes.is_empty():
		_set_status("No scene attaches %s yet — attach it to a scene and run again." % script_path.get_file(), true)
		return
	if scenes.size() == 1:
		_play_scene_path(scenes[0])
		return
	if _run_scene_menu == null:
		_run_scene_menu = PopupMenu.new()
		_run_scene_menu.index_pressed.connect(func(index: int) -> void:
			_play_scene_path(str(_run_scene_menu.get_item_metadata(index))))
		add_child(_run_scene_menu)
	_run_scene_menu.clear()
	for scene_path: String in scenes:
		_run_scene_menu.add_item(scene_path.get_file())
		_run_scene_menu.set_item_metadata(_run_scene_menu.item_count - 1, scene_path)
	_run_scene_menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i(0, 0)))

## The script scenes actually attach for this sheet: GDScript-backed sheets ARE their
## .gd (review catch: pairing-rule resolution would invent <name>_generated.gd for
## them); .tres sheets resolve through the pairing rule.
func _run_target_script_path() -> String:
	if _current_sheet != null and not _current_sheet.external_source_path.is_empty():
		return _current_sheet.external_source_path
	return EventSheetProjectDoctor.output_path_for(_current_sheet_path)

func _play_scene_path(scene_path: String) -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		EditorInterface.play_custom_scene(scene_path)
	_set_status("Running %s." % scene_path.get_file())

# ── Session restore (open tabs survive an editor restart) → event_sheet_session_store.gd ──
func _persist_session() -> void:  # startup, tab edits, "Edit Events" unlock + session tests
	_session.persist()
func _restore_session() -> void:  # called once on setup
	_session.restore()

# ── Row snippets — save the selection, insert from the project library
# (EventSheetSnippetLibrary; the clipboard text format is the file format) ────────────
var _snippet_name_window: Window = null
var _snippet_name_edit: LineEdit = null
var _snippet_list_window: Window = null
var _snippet_list: ItemList = null

func _open_save_snippet_dialog() -> void:
	if _top_level_selected_resources().is_empty():
		_set_status("Select rows to save as a snippet.", true)
		return
	if _snippet_name_window == null:
		_snippet_name_window = Window.new()
		_snippet_name_window.title = "Save Selection as Snippet"
		_snippet_name_window.size = Vector2i(360, 100)
		_snippet_name_window.close_requested.connect(func() -> void: _snippet_name_window.hide())
		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		_snippet_name_edit = LineEdit.new()
		_snippet_name_edit.placeholder_text = "Snippet name (e.g. fade_and_free)"
		_snippet_name_edit.text_submitted.connect(func(_t: String) -> void: _confirm_save_snippet())
		box.add_child(_snippet_name_edit)
		var save_button: Button = Button.new()
		save_button.text = "Save to the project snippet library"
		save_button.pressed.connect(_confirm_save_snippet)
		box.add_child(save_button)
		_snippet_name_window.add_child(box)
		add_child(_snippet_name_window)
	_snippet_name_window.popup_centered()
	_snippet_name_edit.grab_focus()

func _confirm_save_snippet() -> void:
	var saved: String = _save_selection_snippet_named(_snippet_name_edit.text.strip_edges())
	if not saved.is_empty():
		_snippet_name_window.hide()

## The testable save core: serializes the top-level selection with the SAME serializer
## Copy uses and files it in the library. Returns the path, or "" on a problem.
func _save_selection_snippet_named(snippet_name: String) -> String:
	var targets: Array = _top_level_selected_resources()
	if targets.is_empty() or snippet_name.is_empty():
		_set_status("Name the snippet and select at least one row.", true)
		return ""
	var path: String = EventSheetSnippetLibrary.save_snippet(snippet_name, EventSheetSnippet.serialize_rows(targets, _current_sheet))
	if path.is_empty():
		_set_status("Couldn't write the snippet.", true)
		return ""
	if Engine.is_editor_hint() and is_inside_tree():
		EditorInterface.get_resource_filesystem().scan()
	_set_status("Snippet saved: %s — Insert Snippet… lists it now." % path)
	return path

func _open_insert_snippet() -> void:
	var snippets: PackedStringArray = EventSheetSnippetLibrary.list_snippets()
	if snippets.is_empty():
		_set_status("No snippets yet — select rows and Save Selection as Snippet… first.", true)
		return
	if _snippet_list_window == null:
		_snippet_list_window = Window.new()
		_snippet_list_window.title = "Insert Snippet"
		_snippet_list_window.size = Vector2i(380, 320)
		_snippet_list_window.close_requested.connect(func() -> void: _snippet_list_window.hide())
		_snippet_list = ItemList.new()
		_snippet_list.set_anchors_preset(Control.PRESET_FULL_RECT)
		_snippet_list.item_activated.connect(func(index: int) -> void:
			_insert_snippet_path(str(_snippet_list.get_item_metadata(index)))
			_snippet_list_window.hide())
		_snippet_list_window.add_child(_snippet_list)
		add_child(_snippet_list_window)
	_snippet_list.clear()
	for snippet_path: String in snippets:
		_snippet_list.add_item(snippet_path.get_file().get_basename().capitalize())
		_snippet_list.set_item_metadata(_snippet_list.item_count - 1, snippet_path)
		_snippet_list.set_item_tooltip(_snippet_list.item_count - 1, snippet_path)
	_snippet_list_window.popup_centered()

## Insert = the normal snippet paste (fresh uids, missing variables created — the
## whole paste contract for free).
func _insert_snippet_path(snippet_path: String) -> void:
	if not _paste_snippet_text(EventSheetSnippetLibrary.read_snippet(snippet_path)):
		_set_status("That file isn't a sheet snippet: %s" % snippet_path.get_file(), true)

# ── Context-driven row/ACE edit ops — bodies in EventSheetRowEditOps (dock/row_edit_ops.gd).
# The four dispatchers below (_on_*_context_menu_id_pressed) call these by bare name, context_menus.gd
# reads the is-disabled / is-negated probes via _dock.<name>, multi_view_manager wires
# _delete_selected_content, and the tests call the enable/indent/outdent/insert ops directly — so the
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

func _open_sub_condition_picker_for_context_row() -> void:
	_row_edit_ops._open_sub_condition_picker_for_context_row()

func _indent_selected_event() -> bool:
	return _row_edit_ops._indent_selected_event()

func _outdent_selected_event() -> bool:
	return _row_edit_ops._outdent_selected_event()

func _insert_context_row_below(resource_entry: Resource, message: String) -> void:
	_row_edit_ops._insert_context_row_below(resource_entry, message)

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
	var changed: bool = _perform_undoable_sheet_edit("Edit ACE Comment", func() -> bool:
		target.set("comment", new_comment)
		return true
	)
	if changed:
		_refresh_after_edit()
		_mark_dirty("ACE comment saved.")

# ── Starter templates ("new from template") — menu + sheet construction in dock/starter_templates.gd ──
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
	var options: Array[Dictionary] = []
	if _current_sheet == null:
		return options
	var event_rows: Array[EventRow] = []
	_collect_event_rows_recursive(_current_sheet.events, event_rows)
	for event_row in event_rows:
		options.append(
			{
				"uid": event_row.event_uid,
				"label": _format_event_target_label(event_row)
			}
		)
	return options

func _collect_event_rows_recursive(resources: Array, output: Array[EventRow]) -> void:
	for resource_entry in resources:
		if resource_entry is EventRow:
			output.append(resource_entry as EventRow)
			_collect_event_rows_recursive((resource_entry as EventRow).sub_events, output)
		elif resource_entry is EventGroup:
			_collect_event_rows_recursive(_group_children_array(resource_entry as EventGroup), output)

func _format_event_target_label(event_row: EventRow) -> String:
	if event_row == null:
		return "(invalid event)"
	var label: String = "Event %s" % event_row.event_uid
	if not event_row.comment.is_empty():
		label += " — %s" % event_row.comment
	elif not event_row.trigger_id.is_empty():
		label += " — %s" % event_row.trigger_id
	elif event_row.trigger != null and not event_row.trigger.ace_id.is_empty():
		label += " — %s" % event_row.trigger.ace_id
	return label

func _find_event_row_by_uid(event_uid: String) -> EventRow:
	if _current_sheet == null or event_uid.is_empty():
		return null
	var event_rows: Array[EventRow] = []
	_collect_event_rows_recursive(_current_sheet.events, event_rows)
	for event_row in event_rows:
		if event_row.event_uid == event_uid:
			return event_row
	return null

func _type_from_name(type_name: String) -> int:
	match type_name:
		"int":
			return TYPE_INT
		"float":
			return TYPE_FLOAT
		"bool":
			return TYPE_BOOL
		"String":
			return TYPE_STRING
		_:
			return TYPE_NIL

func _event_row_uses_or_mode(event_row: EventRow) -> bool:
	return event_row != null and event_row.condition_mode == EventRow.ConditionMode.OR

func _event_rows_use_or_mode(event_rows: Array[EventRow]) -> bool:
	if event_rows.is_empty():
		return false
	for event_row in event_rows:
		if not _event_row_uses_or_mode(event_row):
			return false
	return true

func _get_selected_rows_from_context() -> Array[EventRowData]:
	if _viewport == null:
		return []
	var selected_rows: Array[EventRowData] = _active_view().get_selected_rows()
	if selected_rows.is_empty():
		if _context_row != null:
			return [_context_row]
		return []
	if _context_row == null:
		return selected_rows
	for row_data in selected_rows:
		if row_data.row_uid == _context_row.row_uid:
			return selected_rows
	return [_context_row]

func _get_selected_event_rows_from_context() -> Array[EventRow]:
	var event_rows: Array[EventRow] = []
	for row_data in _get_selected_rows_from_context():
		if row_data != null and row_data.source_resource is EventRow:
			event_rows.append(row_data.source_resource as EventRow)
	return event_rows

func _build_ace_edit_context(event_row: EventRow, span_index: int, metadata: Dictionary) -> Dictionary:
	if event_row == null:
		return {}
	var ace_index: int = int(metadata.get("ace_index", -1))
	var kind: String = str(metadata.get("kind", ""))
	var definition: ACEDefinition = null
	var existing_params: Dictionary = {}
	var mode: String = ""
	match kind:
		"trigger":
			if event_row.trigger == null:
				return {}
			definition = _find_definition(event_row.trigger.provider_id, event_row.trigger.ace_id)
			existing_params = event_row.trigger.params if not event_row.trigger.params.is_empty() else event_row.trigger.parameters
			mode = "replace_trigger"
		"condition":
			if ace_index < 0 or ace_index >= event_row.conditions.size():
				return {}
			var condition_entry: ACECondition = event_row.conditions[ace_index]
			definition = _find_definition(condition_entry.provider_id, condition_entry.ace_id)
			existing_params = condition_entry.params if not condition_entry.params.is_empty() else condition_entry.parameters
			mode = "replace_condition"
		"action":
			if ace_index < 0 or ace_index >= event_row.actions.size() or not (event_row.actions[ace_index] is ACEAction):
				return {}
			var action_entry: ACEAction = event_row.actions[ace_index] as ACEAction
			definition = _find_definition(action_entry.provider_id, action_entry.ace_id)
			existing_params = action_entry.params if not action_entry.params.is_empty() else action_entry.parameters
			mode = "replace_action"
		_:
			return {}
	return {
		"mode": mode,
		"selected_resource": event_row,
		"row_data": _context_row,
		"definition": definition,
		"existing_params": existing_params.duplicate(true),
		"ace_index": ace_index,
		"span_index": span_index,
		"kind": kind
	}

func _find_definition(provider_id: String, ace_id: String) -> ACEDefinition:
	if _ace_registry == null:
		return null
	return _ace_registry.find_definition(provider_id, ace_id)

func _find_first_event_row_resource() -> EventRow:
	if _viewport == null:
		return null
	for row_entry: Dictionary in _viewport.get_flat_rows():
		var row_data: EventRowData = row_entry.get("row")
		if row_data != null and row_data.source_resource is EventRow:
			return row_data.source_resource as EventRow
	return null

func _select_first_event_row() -> void:
	if _viewport == null:
		return
	var rows: Array[Dictionary] = _viewport.get_flat_rows()
	for row_index: int in range(rows.size()):
		var row_data: EventRowData = rows[row_index].get("row")
		if row_data != null and row_data.source_resource is EventRow:
			_viewport._select_row(row_index)
			return

func _refresh_after_edit() -> void:
	if _viewport == null:
		return
	_viewport.set_sheet(_current_sheet)
	_sync_split_sheet()
	_sync_active_theme_binding()
	_refresh_exposed_node()
	_refresh_variable_panel()
	_refresh_code_panel()

func _sync_active_theme_binding() -> void:
	var next_style: EventSheetEditorStyle = (
		_current_sheet.editor_style
		if _current_sheet != null and _current_sheet.editor_style != null
		else null
	)
	if _active_theme_style == next_style:
		return
	if _active_theme_style != null and _active_theme_style.changed.is_connected(_on_active_theme_style_changed):
		_active_theme_style.changed.disconnect(_on_active_theme_style_changed)
	_active_theme_style = next_style
	if _active_theme_style != null and not _active_theme_style.changed.is_connected(_on_active_theme_style_changed):
		_active_theme_style.changed.connect(_on_active_theme_style_changed)

func _on_active_theme_style_changed() -> void:
	if _viewport == null or _current_sheet == null:
		return
	_viewport.set_sheet(_current_sheet)
	_set_status("Theme change detected and reloaded.")

func _mark_dirty(message: String) -> void:
	_dirty = true
	_refresh_title_strip()
	_set_status("%s%s" % [message, " *" if _dirty else ""])

func _set_status(text: String, is_error: bool = false) -> void:
	if _status_label == null:
		return
	# A leading ⚠ marks errors textually (not just by colour — colour-blind-safe and more salient so
	# a "won't compile / save failed" isn't missed). The full text is on the tooltip since the status
	# bar truncates long messages.
	_status_label.text = ("⚠  %s" % text) if is_error else text
	_status_label.tooltip_text = text
	_status_label.modulate = Color(1.0, 0.48, 0.48) if is_error else Color(1.0, 1.0, 1.0)

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
		_identity_banner.update_from_sheet(_current_sheet)
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
	# automatically — purely additive (they never displace the default vocabulary or the
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
	var sheet_paths: Array = _current_sheet.ace_provider_scripts if _current_sheet != null else []
	# Folder scan + code-registered providers (EventForgeBridge.register_script_as_provider
	# lets other plugins/tools extend the vocabulary without touching eventsheet_addons/).
	var provider_paths: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	for registered_path: String in EventForgeBridgeRuntime.get_registered_provider_scripts():
		if not provider_paths.has(registered_path):
			provider_paths.append(registered_path)
	# Registered autoloads with annotated scripts publish project-wide (event buses,
	# game state) — zero-config, like eventsheet_addons/.
	_autoload_provider_names.clear()
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = str(property_info.get("name", ""))
		if not setting_name.begins_with("autoload/"):
			continue
		var autoload_path: String = str(ProjectSettings.get_setting(setting_name, "")).trim_prefix("*")
		if not autoload_path.ends_with(".gd"):
			continue
		# Only ANNOTATED autoloads publish (reflection would otherwise dump every
		# public method of e.g. the plugin's own bridge into every picker — silent
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
	# provider isn't in the compiler's registry, so its rows used to silently produce no code — the
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
	tick.comment = "Auto-generated example — every row is an event, no GDScript"
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
