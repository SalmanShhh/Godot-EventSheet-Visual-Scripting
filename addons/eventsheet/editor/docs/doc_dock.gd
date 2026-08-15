# EventSheet - EventSheetDocDock: the documentation, docked where the reader keeps it.
#
# A window is a visitor; a dock is furniture. This is the same reading surface the Documentation
# window shows (EventSheetDocBrowser: the guide tree, the rendered guide pages and the generated
# "what does this row do?" panel), parented by an EditorDock instead - so it persists in the
# editor layout, reopens where it was left, can be floated onto a second monitor, and sits BESIDE
# the sheet rather than over it. Once it is open, F1 and "What does this do?" update it in place
# instead of popping a window (see EventSheetDocWindow), which is the whole point of docking it.
#
# THE BOOT CONTRACT. EditorPlugin.add_dock takes an INSTANCE, so this node is constructed at every
# editor start - which is exactly the path that must stay cheap (the plugin's 1.8s -> 85ms win).
# Two rules keep it honest, and tests/plugin_boot_lazy_test.gd pins both:
#
#   1. This file names NO plugin class in code. Naming one would compile its whole dependency
#      subtree - the browser pulls the parser, the guide bundle, a viewport and the vocabulary
#      registry - the moment this script loads, i.e. at boot, for a dock most sessions never open.
#      Everything is reached with load(<path>) at call time.
#   2. The dock is an EMPTY MarginContainer until it is first shown. _ensure_content builds the
#      browser on the first open()/make_visible(), and a session that never opens it pays nothing
#      but one bare node.
#   3. A reveal the READER did not ask for - the editor restoring a layout in which this dock was
#      left open - only SCHEDULES the build. Building inside that notification would put the whole
#      surface, plus a page parse, back on the boot path for exactly the readers who use it most,
#      and no source lint can see that: every reference here is already a load-by-path.
#
# Narrow by nature: a dock slot is nowhere near the ~560 px the tree-beside-page layout wants, so
# the browser is put in COMPACT mode here (contents behind a toggle, prose gets the width). The
# figures inside the guides are content-sized in both axes and take the host width as a ceiling,
# so rows wrap into the column exactly as they would in a sheet that narrow - never clipped.
@tool
class_name EventSheetDocDock
extends EditorDock

## Everything heavy is reached by path (see the boot contract above).
const BROWSER_PATH: String = "res://addons/eventsheet/editor/docs/doc_browser.gd"
const L10N_PATH: String = "res://addons/eventsheet/editor/l10n.gd"
const API_PATH: String = "res://addons/eventsheet/api/eventsheets.gd"
const EXPLAIN_PATH: String = "res://addons/eventsheet/editor/docs/doc_explain.gd"

## The public API scripts registered into the editor's built-in Help, so Search Help finds the
## extension surface. It renders in the engine's class-reference shape with no visual control and
## cannot show rows - a cheap complement to this dock, never a replacement for it.
const HELP_SCRIPT_PATHS: Array[String] = [
	"res://addons/eventsheet/api/eventsheets.gd",
	"res://addons/eventsheet/api/simple_block_kind.gd",
]

## The layout section key. STABLE: it is what the editor writes the dock's slot and this dock's
## own remembered page under, so renaming it silently loses every reader's layout.
const LAYOUT_KEY: String = "EventSheetsHelp"

## The config key the last-read page is persisted under, inside the editor's own dock section.
const CONFIG_DOC_ID: String = "doc_id"

## The guide index, for the "Read this online" escape hatch when a page cannot show something
## (the native pages carry no images).
const INDEX_DOC_PATH: String = "docs/README.md"

## The live dock instance, so the Documentation window can hand a page to an already-open dock
## instead of popping a window over the sheet. Null whenever no dock is in the tree.
static var _active: EventSheetDocDock = null

var _browser: Control = null
var _status: Label = null
var _built: bool = false
## Set the moment a build is scheduled off the boot frame, so the two reveal notifications (which
## both fire during a layout restore) queue exactly one build between them.
var _build_queued: bool = false
## Whether anything has been drawn yet. It is what stops the first open from rendering TWO pages -
## the remembered one on the way in, and the one the caller actually asked for immediately after.
var _shown_any: bool = false
## The page the reader was on when the editor last closed, restored on the first build (the
## content does not exist yet when the layout is loaded).
var _pending_doc_id: String = ""


func _init() -> void:
	title = "EventSheets Help"
	layout_key = LAYOUT_KEY
	# The docs belong beside the sheet, not under it: a tall right-hand slot is the shape prose
	# wants. Floating is offered too, which is the answer for a reader on a second monitor.
	default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_HORIZONTAL | EditorDock.DOCK_LAYOUT_FLOATING
	closable = true
	icon_name = &"Help"


## The open dock, or null when none is in the tree. The Documentation window asks this before
## popping itself, so the reader's chosen home wins.
static func active_dock() -> EventSheetDocDock:
	if _active != null and is_instance_valid(_active) and _active.is_inside_tree():
		return _active
	return null


## Opens the dock on `doc_id` (empty for the index), building its content on the way if this is
## the first time. False when the id names nothing - the caller says so rather than the dock
## showing a blank page.
func show_documentation(doc_id: String = "", anchor: String = "") -> bool:
	_ensure_content()
	if _browser == null:
		return false
	# Claimed BEFORE the call: the reader named a page, so the remembered one must not be drawn
	# first and thrown away - that is a whole page parsed, built and discarded on the one click
	# that is already the slowest thing this surface does.
	_shown_any = true
	if not _browser.call("show_doc", doc_id, anchor):
		return false
	_set_status("")
	return true


## The reading surface, for a host or a harness that drives it directly. Null before the first
## reveal - the dock is deliberately empty until then.
func browser() -> Control:
	return _browser


## Both reveal paths build first, so the dock is never shown empty. A reader who opens the dock is
## asking for it now, so these two build immediately - it is the NOTIFICATIONS that must not.
func open() -> void:
	_ensure_content()
	_show_first_page()
	super()


func make_visible() -> void:
	_ensure_content()
	_show_first_page()
	super()


## THE BOOT PATH. The editor reveals docks by plain visibility while it restores a layout - so a
## reader who simply left this dock open last session would otherwise have the whole reading
## surface (the parser, the guide bundle, a viewport, the vocabulary registry) built, plus a page
## parsed and its figures gated, INSIDE editor startup. Every notification therefore only SCHEDULES
## the build; the editor finishes starting first, and the dock fills in a frame later.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			_active = self
			_queue_content()
		NOTIFICATION_VISIBILITY_CHANGED:
			_queue_content()
		NOTIFICATION_EXIT_TREE:
			if _active == self:
				_active = null


## Schedules the build off the current frame, once. Nothing happens for a dock that is not on
## screen: an invisible dock in a restored layout stays the empty container it was registered as.
func _queue_content() -> void:
	if _built or _build_queued or not is_visible_in_tree():
		return
	_build_queued = true
	_build_off_boot_frame.call_deferred()


func _build_off_boot_frame() -> void:
	_build_queued = false
	if _built or not is_visible_in_tree():
		return
	if is_inside_tree():
		# One more frame than call_deferred gives: the editor is still assembling itself when a
		# layout restore fires, and the point of this whole path is not to be in that assembly.
		await get_tree().process_frame
	if _built or not is_visible_in_tree():
		return
	_ensure_content()
	_show_first_page()


## The page a freshly built surface lands on - the one the reader left it on, or the index. Runs
## once: a caller that has already named a page owns the surface, and drawing this one first would
## be a page rendered only to be replaced.
func _show_first_page() -> void:
	if _browser == null or _shown_any:
		return
	_shown_any = true
	_browser.call("show_doc", _pending_doc_id, "")


## The page the reader was on travels with the layout, so reopening the editor reopens the page -
## the behaviour that makes this furniture rather than a window that forgets.
## The page written back is the one on screen, and - when the dock was never opened this session -
## the one that was on screen the LAST time it was. Without that fallback a session that simply
## left the dock closed would rewrite the remembered page as "", quietly losing it: the browser is
## null for exactly the sessions where nothing changed.
func _save_layout_to_config(config: ConfigFile, section: String) -> void:
	var doc_id: String = _pending_doc_id if _browser == null else str(_browser.call("current_doc_id"))
	config.set_value(section, CONFIG_DOC_ID, doc_id)


func _load_layout_from_config(config: ConfigFile, section: String) -> void:
	# The content does not exist yet (that is the point of building it lazily), so the id waits
	# for the first reveal.
	_pending_doc_id = str(config.get_value(section, CONFIG_DOC_ID, ""))
	if _browser != null and not _pending_doc_id.is_empty():
		_shown_any = true
		_browser.call("show_doc", _pending_doc_id, "")


## Builds the reading surface, once. Idempotent, and the ONLY place this dock touches anything
## heavy - see the boot contract in the header. It draws NO page: which page a fresh surface lands
## on is the caller's business (_show_first_page), or it would be drawn twice.
func _ensure_content() -> void:
	if _built:
		return
	_built = true
	var browser_script: Script = load(BROWSER_PATH) as Script
	if browser_script == null or not browser_script.can_instantiate():
		push_warning("[Godot EventSheets] The documentation browser could not be loaded from %s." % BROWSER_PATH)
		return
	_browser = browser_script.new() as Control
	if _browser == null:
		return
	# A dock slot is a column, not a window: one half of the surface at a time, and the width
	# floor drops from "tree beside page" to "a readable line of prose".
	_browser.call("set_compact", true)
	_browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_browser.connect("link_activated", _on_link_activated)
	_browser.connect("snippet_inserted", _on_snippet_inserted)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", _scaled(6))
	column.add_child(_browser)
	column.add_child(_build_footer())
	add_child(column)
	# Chrome translates for free once the dock is in the plugin's translation domain.
	load(L10N_PATH).apply_to(self)
	_register_api_help()


## The footer: what just happened, and the way out to the full-fidelity page. Both are one line,
## because every pixel here is a pixel of prose.
func _build_footer() -> HBoxContainer:
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", _scaled(6))
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = ""
	footer.add_child(_status)
	var online_button: Button = Button.new()
	online_button.text = "Read online"
	online_button.tooltip_text = "Opens this page in your browser, pinned to the version you installed. The online pages carry the screenshots this one leaves out."
	online_button.pressed.connect(_open_current_online)
	footer.add_child(online_button)
	return footer


## Registers the public API scripts into the editor's built-in Help. Done HERE rather than at
## plugin boot on purpose: it needs the API script compiled, and a reader who has just asked for
## documentation is exactly who benefits from Search Help knowing these classes.
func _register_api_help() -> void:
	var script_editor: Object = _script_editor()
	if script_editor == null:
		return
	for path: String in HELP_SCRIPT_PATHS:
		var script: Script = load(path) as Script
		if script != null:
			script_editor.call("update_docs_from_script", script)


## The online escape hatch follows the reader: the page on screen when it maps to a repo file, and
## the guide index when the surface is showing generated reference instead of a guide.
func _open_current_online() -> void:
	var api: Script = load(API_PATH) as Script
	var explain: Script = load(EXPLAIN_PATH) as Script
	if api == null or explain == null or _browser == null:
		return
	var route: Dictionary = explain.call("resolve", str(_browser.call("current_doc_id")))
	var target: String = str(route.get("target", ""))
	api.call("open_online_doc", target if not target.is_empty() else INDEX_DOC_PATH, "")
	_set_status("Opened that page in your browser.")


func _on_link_activated(target: String) -> void:
	_set_status("Opened %s in your browser." % target.get_file())


func _on_snippet_inserted() -> void:
	_set_status("Inserted the illustrated rows below your selection - one undo step.")


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


## The editor's script editor, or null headless. Reached without naming EditorInterface's return
## type, so this file keeps compiling in a suite that has no editor around it.
func _script_editor() -> Object:
	if not Engine.is_editor_hint():
		return null
	return EditorInterface.get_script_editor()


## Editor display scale, for the two spacings this file owns. The browser inside scales itself.
func _scaled(value: int) -> int:
	if not Engine.is_editor_hint():
		return value
	return int(round(float(value) * EditorInterface.get_editor_scale()))
