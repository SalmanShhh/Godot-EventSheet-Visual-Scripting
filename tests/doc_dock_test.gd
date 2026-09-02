# EventSheet - the Help DOCK (documentation where the reader keeps it)
#
# What this suite CAN reach, and what it deliberately does not try to:
#
# EditorDock "can only be instantiated by editor" (verified against this build), so the dock node
# itself never exists in a headless run - constructing one here would abort the test. Everything
# pinned below is therefore either a SOURCE fact (the boot contract, the registration path) or a
# behaviour of the parts the dock composes (the browser's compact mode, the routing seam).
#
# The rest is the harness's job, and it is listed in tools/render_docs_slice_preview.gd: the dock
# beside a sheet at dock width, the guide figures wrapping into that width instead of clipping,
# and the reveal-after-open question the spec left open for a real editor.
@tool
class_name DocDockTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const DOCK_PATH := "res://addons/eventsheet/editor/docs/doc_dock.gd"
const PLUGIN_PATH := "res://addons/eventforge/plugin.gd"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_registration() and all_passed
	all_passed = _test_dock_contract() and all_passed
	all_passed = _test_boot_deferral() and all_passed
	all_passed = _test_compact_browser() and all_passed
	all_passed = _test_help_scripts() and all_passed
	return all_passed


## The boot contract, as source facts: the plugin registers the dock BY PATH, the path it names is
## the file that exists, and the dock builds nothing at construction time.
static func _test_registration() -> bool:
	var all_passed: bool = true
	var plugin_source: String = _read(PLUGIN_PATH)
	all_passed = _check("plugin names the dock script by path",
		plugin_source.contains("\"%s\"" % DOCK_PATH), true) and all_passed
	all_passed = _check("plugin registers the dock with add_dock",
		plugin_source.contains("add_dock(_doc_dock)"), true) and all_passed
	all_passed = _check("plugin removes the dock again on unload",
		plugin_source.contains("remove_dock(_doc_dock)"), true) and all_passed
	all_passed = _check("the registered path exists", ResourceLoader.exists(DOCK_PATH), true) and all_passed
	var dock_script: Script = load(DOCK_PATH) as Script
	all_passed = _check("the dock script loads", dock_script != null, true) and all_passed
	return all_passed


## The dock's own contract, read off the script rather than off an instance: the layout key that
## makes it furniture, the slot it lands in, the layouts it offers, and the lazy build.
static func _test_dock_contract() -> bool:
	var all_passed: bool = true
	var dock_script: Script = load(DOCK_PATH) as Script
	if dock_script == null:
		return false
	var constants: Dictionary = dock_script.get_script_constant_map()
	# The layout key is what the editor writes a reader's dock slot under: renaming it silently
	# loses every existing layout, so it is pinned as a VALUE.
	all_passed = _check("layout key", str(constants.get("LAYOUT_KEY", "")), "EventSheetsHelp") and all_passed
	all_passed = _check("browser reached by path",
		str(constants.get("BROWSER_PATH", "")), "res://addons/eventsheet/editor/docs/doc_browser.gd") and all_passed
	var source: String = _read(DOCK_PATH)
	all_passed = _check("lands in the right-hand upper slot",
		source.contains("default_slot = EditorDock.DOCK_SLOT_RIGHT_UL"), true) and all_passed
	all_passed = _check("offers the floating layout",
		source.contains("EditorDock.DOCK_LAYOUT_FLOATING"), true) and all_passed
	all_passed = _check("the reader can close it", source.contains("closable = true"), true) and all_passed
	all_passed = _check("persists its page across sessions",
		source.contains("func _save_layout_to_config(") and source.contains("func _load_layout_from_config("),
		true) and all_passed
	# The lazy build is the boot budget: _init sets properties, and NOTHING is built until a reveal.
	var init_body: String = source.split("func _init() -> void:")[1].split("\n\n\n")[0]
	all_passed = _check("nothing is loaded while the dock is constructed",
		init_body.contains("load("), false) and all_passed
	all_passed = _check("nothing is added as a child while the dock is constructed",
		init_body.contains("add_child("), false) and all_passed
	# A dock is narrow by nature but not by rule: once built, the surface decides from its OWN
	# width, so a floated or dragged-wide dock shows the guide list beside the page again.
	all_passed = _check("the surface follows the dock's own width",
		source.contains("set_auto_compact"), true) and all_passed
	all_passed = _check("the content builds on a reveal",
		source.contains("NOTIFICATION_VISIBILITY_CHANGED") and source.contains("func _ensure_content()"),
		true) and all_passed
	return all_passed


## The half of the boot contract no class-name lint can see. Every reference in this file is
## already a load-by-path, so plugin_boot_lazy_test is green whether or not the dock builds itself
## during editor startup - and it WILL be revealed during startup, by the layout restore, for
## exactly the readers who left it open. Three source facts keep that honest:
##   - a reveal notification only SCHEDULES the build;
##   - the build itself draws no page, so the first open does not render one page and then another;
##   - the remembered page survives a session in which the dock was never opened.
static func _test_boot_deferral() -> bool:
	var all_passed: bool = true
	var source: String = _read(DOCK_PATH)
	var notification_body: String = _function_body(source, "func _notification(what: int) -> void:")
	all_passed = _check("the notification body was found", notification_body.is_empty(), false) and all_passed
	all_passed = _check("a reveal notification never builds inline",
		notification_body.contains("_ensure_content()"), false) and all_passed
	all_passed = _check("it schedules the build instead",
		notification_body.contains("_queue_content()"), true) and all_passed
	var queue_body: String = _function_body(source, "func _queue_content() -> void:")
	all_passed = _check("and the schedule leaves the current frame",
		queue_body.contains("call_deferred()"), true) and all_passed
	all_passed = _check("an invisible dock schedules nothing at all",
		queue_body.contains("not is_visible_in_tree()"), true) and all_passed

	var build_body: String = _function_body(source, "func _ensure_content() -> void:")
	all_passed = _check("the build body was found", build_body.is_empty(), false) and all_passed
	all_passed = _check("building the surface draws no page",
		build_body.contains("show_doc"), false) and all_passed
	all_passed = _check("the page a fresh surface lands on is drawn once",
		_function_body(source, "func _show_first_page() -> void:").contains("_shown_any"), true) and all_passed

	var save_body: String = _function_body(source, "func _save_layout_to_config(config: ConfigFile, section: String) -> void:")
	all_passed = _check("a session that never opened the dock keeps the remembered page",
		save_body.contains("_pending_doc_id if _browser == null"), true) and all_passed
	return all_passed


## Compact mode is what makes a dock-width surface readable: one half on screen at a time, and a
## width floor a dock slot can actually satisfy.
static func _test_compact_browser() -> bool:
	var all_passed: bool = true
	var browser: EventSheetDocBrowser = EventSheetDocBrowser.new()
	all_passed = _check("a window-hosted browser asks for both halves",
		browser.custom_minimum_size.x, EventSheetPalette.scaled_f(EventSheetDocBrowser.WIDE_MIN_WIDTH)) and all_passed
	all_passed = _check("and starts wide", browser.is_compact(), false) and all_passed
	browser.set_compact(true)
	all_passed = _check("a dock-hosted browser asks only for a readable column",
		browser.custom_minimum_size.x, EventSheetPalette.scaled_f(EventSheetDocBrowser.COMPACT_MIN_WIDTH)) and all_passed
	all_passed = _check("compact mode is reported", browser.is_compact(), true) and all_passed
	# BOTH halves narrow, not just the guide page. The generated half is invisible while a guide is
	# on screen and costs the layout nothing - and then the reader asks what a verb does, and a half
	# that kept its comfortable 460 px is suddenly the widest thing in a host that has horizontal
	# scrolling switched off: it either shoves the dock past its own floor or clips unreachably.
	all_passed = _check("the generated half narrows with it", browser.panel().is_compact(), true) and all_passed
	all_passed = _check("to a width a dock slot can actually give it",
		browser.panel().custom_minimum_size.x <= browser.custom_minimum_size.x, true) and all_passed
	all_passed = _check("and it is the shared compact width",
		browser.panel().custom_minimum_size.x,
		EventSheetPalette.scaled_f(EventSheetDocPanel.COMPACT_PAGE_WIDTH)) and all_passed
	all_passed = _check("the guide list folds away", browser._side.visible, false) and all_passed
	all_passed = _check("behind a toggle the reader can see", browser._contents_button.visible, true) and all_passed
	browser._on_contents_toggled(true)
	all_passed = _check("toggling it shows the guide list", browser._side.visible, true) and all_passed
	browser._fold_contents()
	all_passed = _check("picking a page gives the width back", browser._side.visible, false) and all_passed
	browser.set_compact(false)
	all_passed = _check("a wide host gives the generated half its column back",
		browser.panel().custom_minimum_size.x,
		EventSheetPalette.scaled_f(EventSheetDocPanel.PAGE_WIDTH)) and all_passed
	all_passed = _check("a wide host shows both halves again", browser._side.visible, true) and all_passed
	all_passed = _check("and its toggle disappears", browser._contents_button.visible, false) and all_passed
	browser.free()
	return all_passed


## Search Help only finds what was handed to it, and it is handed SCRIPTS - a renamed API file
## would otherwise register nothing at all, silently.
static func _test_help_scripts() -> bool:
	var all_passed: bool = true
	var dock_script: Script = load(DOCK_PATH) as Script
	var paths: Array = dock_script.get_script_constant_map().get("HELP_SCRIPT_PATHS", [])
	all_passed = _check("the API scripts registered into Help",
		str(paths), str(["res://addons/eventsheet/api/eventsheets.gd",
			"res://addons/eventsheet/api/simple_block_kind.gd"])) and all_passed
	for path: String in paths:
		all_passed = _check("registered Help script exists: %s" % path.get_file(),
			load(path) is Script, true) and all_passed
	return all_passed


## One function's body, read off the source: everything between its signature and the two blank
## lines that end it (the style the whole plugin is written in, and the suite enforces).
static func _function_body(source: String, signature: String) -> String:
	var parts: PackedStringArray = source.split(signature)
	if parts.size() < 2:
		return ""
	return parts[1].split("\n\n\n")[0]


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("doc_dock_test", label, actual, expected)
