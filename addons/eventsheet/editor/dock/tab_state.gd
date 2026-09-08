# Godot EventSheets - what an open tab keeps while another one is on screen (dock subsystem)
#
# A tab switch used to be a full load: every row rebuilt through the reading layers, the ACE
# vocabulary rebuilt from the sheet's providers and the addon folder, the undo log cleared, the
# generated-code panel recompiled. Two sheets open side by side therefore cost a reading on every
# glance between them. This is where a tab keeps its own: the reading its rows were built into, the
# selection and scroll they were left at, the log of edits made to it, and the compiled output the
# code panel showed - each stamped with the two things that can make them wrong.
#
# THE STAMP is two numbers, and both must still hold for a kept reading to be handed back:
#   - the tab's edit revision, bumped by every edit that refreshes the view (the undo funnel's
#     commit and every in-place edit come through the same refresh), and
#   - the modification time of the file the tab is stored in, read from disk at switch time.
# A revision that moved means the reader changed the sheet; a modification time that moved means
# something outside the editor did. Either way the rows are built again, once, and the status line
# says which of the two it was. When neither moved, nothing is built at all.
#
# The ACE vocabulary is kept the same way, against a SIGNATURE of everything it is derived from -
# the sheet's own provider scripts, the addon fleet's scan revision, the bridge's and the taught
# registrations, and the annotated autoloads with their modification times. Definitions are
# immutable and shared across tabs already, so keeping one is keeping a list of sources, never a
# second copy of a descriptor.
#
# The undo stack itself is the host editor's and cannot be swapped, so an edit is TAGGED with the
# tab it was made on instead: undoing it activates that tab first and restores there, which is what
# lets the stack outlive a switch without an undo ever landing on the wrong sheet. An edit whose
# tab has been closed restores nothing.
@tool
class_name EventSheetTabState
extends RefCounted

## How many edit snapshots keep their owning tab. An undo stack this deep is already far past what
## anyone walks back through by hand, and the map is only consulted to answer "whose edit was this".
const SNAPSHOT_OWNER_LIMIT := 512

var _dock: Control = null
## Minted per tab, never reused for the life of the dock - two tabs on the same file are two tabs.
var _next_tab_id: int = 0
## snapshot instance id -> the id of the tab whose edit made it (capped, oldest dropped first).
var _snapshot_owners: Dictionary = {}
var _snapshot_order: Array[int] = []
## What the shared ACE registry was last built from, and how many times it has been built. The
## count is the receipt a test reads: a switch between two tabs with the same sources must not
## move it.
var _registry_signature: String = ""
var _registry_builds: int = 0


func init(dock: Control) -> void:
	_dock = dock


# ── The stamp ────────────────────────────────────────────────────────────────


## The tab's own name for itself, minted on first ask and written into the tab's entry. Used to
## say which tab an edit belongs to, so it must outlive the tab's INDEX (tabs are closed and
## reordered around it) and the sheet object (the undo funnel replaces that on every commit).
func tab_id(index: int) -> String:
	if not _valid(index):
		return ""
	var tab: Dictionary = _dock._open_tabs[index]
	var existing: String = str(tab.get("id", ""))
	if not existing.is_empty():
		return existing
	_next_tab_id += 1
	var minted: String = "tab%d" % _next_tab_id
	tab["id"] = minted
	return minted


## The id of the tab on screen, empty when there is none.
func active_tab_id() -> String:
	return tab_id(_dock._active_tab_index)


## Which tab carries this id, -1 when it has been closed.
func index_of_tab_id(wanted: String) -> int:
	if wanted.is_empty():
		return -1
	for index: int in range(_dock._open_tabs.size()):
		if str((_dock._open_tabs[index] as Dictionary).get("id", "")) == wanted:
			return index
	return -1


## The active tab's edit revision moves on. Called from the one refresh every sheet mutation ends
## with, so an edit made in the funnel and an edit made in place stamp alike.
func bump_active_revision() -> void:
	if not _valid(_dock._active_tab_index):
		return
	var tab: Dictionary = _dock._open_tabs[_dock._active_tab_index]
	tab["rev"] = int(tab.get("rev", 0)) + 1


## The modification time of the file a tab is stored in, 0 for a sheet that has never been saved
## (nothing on disk can change behind it) and for a file that is gone.
func disk_stamp(index: int) -> int:
	if not _valid(index):
		return 0
	var tab: Dictionary = _dock._open_tabs[index]
	var path: String = str(tab.get("path", ""))
	if path.is_empty():
		var sheet: EventSheetResource = tab.get("sheet")
		path = sheet.external_source_path if sheet != null else ""
	if path.is_empty() or not FileAccess.file_exists(path):
		return 0
	return FileAccess.get_modified_time(path)


# ── Keeping and handing back ─────────────────────────────────────────────────


## Puts the live view away into the tab it belongs to: the built rows and their layout, the
## selection and scroll, the edits made to it, and the file baseline the reload watcher compares
## against. Called wherever the dock syncs the active tab's state back into its entry, so a tab is
## never left on screen and in its entry at once.
func capture_active() -> void:
	var index: int = _dock._active_tab_index
	if not _valid(index) or _dock._viewport == null:
		return
	var tab: Dictionary = _dock._open_tabs[index]
	# What the view is holding is kept as it is: whether it still answers for this tab is decided
	# when it is handed BACK, by the sheet identity in the capture itself.
	var kept: Dictionary = _dock._viewport.capture_view_state()
	kept["built_rev"] = int(tab.get("rev", 0))
	kept["built_disk"] = disk_stamp(index)
	tab["view"] = kept
	tab["mtime"] = _dock._external_mtime
	if _dock._history_panel != null:
		tab["history"] = _dock._history_panel.capture_log()


## Drops the reading a tab is holding, so the next switch to it reads the sheet again. The one
## caller is "open this sheet" arriving for a sheet that is already open: the sheet object is being
## handed in a second time, which is a claim that it wants reading - it may have been changed by
## whoever is handing it over, and nothing about that change came through the edit funnel.
func invalidate(index: int) -> void:
	if not _valid(index):
		return
	var tab: Dictionary = _dock._open_tabs[index]
	tab["view"] = {}
	tab["code"] = {}


## Seats the tab at index into the viewport, building its rows only when the stamp moved. Returns
## what the switch actually did, which is also what the status line says:
##   "kept"     - the reading was handed back whole; nothing was built and nothing is said
##   "loaded"   - a first reading of this tab (an open, or a tab whose sheet was replaced)
##   "rebuilt"  - the sheet changed in memory since the reading was put away
##   "reloaded" - the file changed on disk behind the tab
func seat(index: int) -> String:
	if not _valid(index) or _dock._viewport == null:
		return "loaded"
	var tab: Dictionary = _dock._open_tabs[index]
	tab_id(index)
	# The reload watcher compares against ONE baseline, so it is the active tab's - restored here
	# so the dialog it opens is about the file that is now on screen.
	_dock._external_mtime = int(tab.get("mtime", _dock._external_mtime))
	if _dock._history_panel != null:
		_dock._history_panel.adopt_log(tab.get("history", {}))
	var kept: Dictionary = tab.get("view", {})
	var disk_now: int = disk_stamp(index)
	var verdict: String = "loaded"
	if not kept.is_empty():
		if int(kept.get("built_disk", 0)) != disk_now:
			verdict = "reloaded"
		elif int(kept.get("built_rev", -1)) != int(tab.get("rev", 0)):
			verdict = "rebuilt"
		elif _dock._viewport.adopt_view_state(_dock._current_sheet, kept):
			return "kept"
		else:
			verdict = "rebuilt"
	tab["view"] = {}
	_dock._viewport.set_sheet(_dock._current_sheet)
	return verdict


# ── The vocabulary ───────────────────────────────────────────────────────────


## True when the ACE vocabulary the registry holds cannot answer for the tab now on screen -
## because the sheet lists different provider scripts, or because the addon fleet, the bridge's
## registrations, the taught verbs or an annotated autoload moved since it was built.
func registry_needs_rebuild() -> bool:
	return registry_signature() != _registry_signature


## Records that the registry has just been rebuilt, and from what.
func note_registry_built() -> void:
	_registry_signature = registry_signature()
	_registry_builds += 1


## How many times the vocabulary has been built this session - the receipt that a switch between
## two tabs with the same sources built it none.
func registry_builds() -> int:
	return _registry_builds


## Everything the vocabulary is derived from, as one string. Two switches that answer the same
## string would build the same registry, so the second may keep the first's.
func registry_signature() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet != null:
		for provider_path: Variant in sheet.ace_provider_scripts:
			parts.append("sheet|%s" % str(provider_path))
	parts.append("scan|%s" % EventSheetAddonScanner.scan_revision())
	for bridge_path: String in EventForgeBridgeRuntime.get_registered_provider_scripts():
		parts.append("bridge|%s" % bridge_path)
	for taught_path: Variant in ProjectSettings.get_setting(
			EventSheetDock.TAUGHT_PROVIDERS_SETTING, PackedStringArray()):
		parts.append("taught|%s" % str(taught_path))
	# An autoload joins the vocabulary only once its script carries an annotation, so the file's
	# own modification time is part of the answer - not just its path.
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = str(property_info.get("name", ""))
		if not setting_name.begins_with("autoload/"):
			continue
		var autoload_path: String = str(ProjectSettings.get_setting(setting_name, "")).trim_prefix("*")
		if not autoload_path.ends_with(".gd"):
			continue
		var stamp: int = FileAccess.get_modified_time(autoload_path) if FileAccess.file_exists(autoload_path) else 0
		parts.append("autoload|%s|%d" % [autoload_path, stamp])
	parts.append("manual|%d" % _dock._manual_ace_sources.size())
	return "\n".join(parts)


# ── The generated-code panel ─────────────────────────────────────────────────


## The compiled output already worked out for the tab on screen, empty when there is none for this
## revision of it. The panel recompiles a sheet only when the sheet changed, never because the
## reader looked at another tab and came back.
func cached_code() -> Dictionary:
	if not _valid(_dock._active_tab_index):
		return {}
	var tab: Dictionary = _dock._open_tabs[_dock._active_tab_index]
	var cached: Dictionary = tab.get("code", {})
	if cached.is_empty() or cached.get("sheet") != _dock._current_sheet:
		return {}
	if int(cached.get("rev", -1)) != int(tab.get("rev", 0)):
		return {}
	return cached


## Keeps a compile the panel just did against the revision it was made from.
func store_code(text: String, source_map: Array) -> void:
	if not _valid(_dock._active_tab_index):
		return
	var tab: Dictionary = _dock._open_tabs[_dock._active_tab_index]
	tab["code"] = {
		"sheet": _dock._current_sheet,
		"rev": int(tab.get("rev", 0)),
		"text": text,
		"map": source_map
	}


# ── Whose edit was this ──────────────────────────────────────────────────────


## Tags an edit's snapshot with the tab it was made on, so an undo can find its way back there.
func remember_snapshot_owner(snapshot: Resource) -> void:
	if snapshot == null:
		return
	var owner: String = active_tab_id()
	if owner.is_empty():
		return
	var key: int = snapshot.get_instance_id()
	if not _snapshot_owners.has(key):
		_snapshot_order.append(key)
	_snapshot_owners[key] = owner
	while _snapshot_order.size() > SNAPSHOT_OWNER_LIMIT:
		_snapshot_owners.erase(_snapshot_order.pop_front())


## Which tab an edit's snapshot belongs to, empty when nothing claimed it (an edit made before any
## tab existed, or one whose tag has aged out of the map).
func snapshot_owner(snapshot: Resource) -> String:
	if snapshot == null:
		return ""
	return str(_snapshot_owners.get(snapshot.get_instance_id(), ""))


func _valid(index: int) -> bool:
	return _dock != null and index >= 0 and index < _dock._open_tabs.size()
