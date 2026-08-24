# Godot EventSheets - "Play as host + client": Godot's own Run Multiple Instances, set for you.
#
# Godot can already launch the game several times at once and hand each launch its own feature tags
# (Debug > Run Multiple Instances). Almost nobody finds it, so testing a networked game usually
# means exporting twice or launching a second copy from a terminal. This module is the ONE place
# that writes that setting: two instances, tagged `host` and `client`, so an On ready > Started as
# host event hosts in one window while the other joins it.
#
# NOTHING here is a launcher, and nothing is stored in a second place. The keys below are the
# editor's OWN project metadata - exactly the ones Godot's Run Instances dialog reads and writes -
# so that dialog shows what this button set, and unticking "Enable Multiple Instances" there turns
# it off again. Whatever else was configured per instance (its launch arguments) is carried over
# untouched: only the feature tags are ours to say.
#
# The pure half - what the config says, what each instance is called - is static and window-free,
# so the suite pins the words and the shape without an editor.
@tool
class_name EventSheetRunInstances
extends RefCounted

## Where Godot keeps the Run Instances settings: the editor's per-project metadata, section
## `debug_options`, alongside "Deploy with Remote Debug" and the other Debug-menu toggles.
const METADATA_SECTION := "debug_options"
const KEY_ENABLED := "multiple_instances_enabled"
const KEY_COUNT := "run_instance_count"
const KEY_CONFIG := "run_instances_config"

## The two per-instance keys this button writes. `features` is a comma-separated tag list, and
## `override_features` is what makes the instance use it instead of the main run's tags.
const ENTRY_OVERRIDE := "override_features"
const ENTRY_FEATURES := "features"

## The two tags the button sets, which are also the two the Started as row suggests first.
const HOST_TAG := "host"
const CLIENT_TAG := "client"
const TEST_TAGS: PackedStringArray = [HOST_TAG, CLIENT_TAG]


## The stored config with these tags written onto the first instances, and everything else about
## each instance left exactly as it was. Returned rather than written, so the caller decides which
## editor write it belongs to - and so the shape is pinned without an editor.
static func config_with_tags(stored: Array, tags: PackedStringArray) -> Array:
	var config: Array = []
	for index: int in range(maxi(tags.size(), stored.size())):
		var entry: Dictionary = {}
		if index < stored.size() and stored[index] is Dictionary:
			entry = (stored[index] as Dictionary).duplicate()
		if index < tags.size():
			entry[ENTRY_OVERRIDE] = true
			entry[ENTRY_FEATURES] = tags[index]
		config.append(entry)
	return config


## True when the editor is already set up to run these tags: enabled, enough instances, and each
## one overriding its tags with the one we would give it. What the tooltip reports, and what keeps
## a second press from claiming it changed something it did not.
static func says_tags(stored: Dictionary, tags: PackedStringArray) -> bool:
	if not bool(stored.get(KEY_ENABLED, false)) or int(stored.get(KEY_COUNT, 1)) < tags.size():
		return false
	var config: Array = stored.get(KEY_CONFIG, []) as Array
	for index: int in range(tags.size()):
		if index >= config.size() or not (config[index] is Dictionary):
			return false
		var entry: Dictionary = config[index] as Dictionary
		if not bool(entry.get(ENTRY_OVERRIDE, false)) or str(entry.get(ENTRY_FEATURES, "")) != tags[index]:
			return false
	return true


## One label per running instance - the tag it was started with, which is what a Live Values chip
## is headed by. An instance with no tag of its own is called by its number, and two instances
## carrying the same tag get their number too, so no two chips read alike.
##
## Empty when only one instance runs: a lone stream needs no heading, and the chip then reads
## exactly as it always did.
static func labels(stored: Dictionary) -> PackedStringArray:
	var count: int = int(stored.get(KEY_COUNT, 1))
	if not bool(stored.get(KEY_ENABLED, false)) or count < 2:
		return PackedStringArray()
	var config: Array = stored.get(KEY_CONFIG, []) as Array
	var tags: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for index: int in range(count):
		var entry: Dictionary = {}
		if index < config.size() and config[index] is Dictionary:
			entry = config[index] as Dictionary
		var tag: String = ""
		if bool(entry.get(ENTRY_OVERRIDE, false)):
			tag = str(entry.get(ENTRY_FEATURES, "")).split(",")[0].strip_edges()
		tags.append(tag)
		seen[tag] = int(seen.get(tag, 0)) + 1
	var named: PackedStringArray = PackedStringArray()
	for index: int in range(count):
		var tag: String = tags[index]
		if tag.is_empty():
			named.append(EventSheetL10n.translate("instance %d") % (index + 1))
		elif int(seen.get(tag, 0)) > 1:
			named.append("%s %d" % [tag, index + 1])
		else:
			named.append(tag)
	return named


## What the toolbar button promises, and how to take it back - the tooltip is the only place the
## reader is told that this is Godot's own setting rather than something this plugin invented.
static func tooltip() -> String:
	return EventSheetL10n.translate("Run two copies of the game at once, tagged %s and %s, and play the scene this sheet is attached to. It sets Godot's own Debug > Run Multiple Instances (2 instances, one feature tag each), so an On ready > Started as host event hosts in one window while the other joins. Untick Enable Multiple Instances in that same dialog to go back to one.") % [HOST_TAG, CLIENT_TAG]


# -- The editor half (writes the setting; refuses outside the editor) ---------------------------


## The three values as they stand right now. Empty outside the editor, where there are no editor
## settings to ask - which is also what makes every reader above degrade to "off" rather than
## guess.
static func stored() -> Dictionary:
	var settings: Object = _editor_settings()
	if settings == null:
		return {}
	return {
		KEY_ENABLED: bool(settings.call("get_project_metadata", METADATA_SECTION, KEY_ENABLED, false)),
		KEY_COUNT: int(settings.call("get_project_metadata", METADATA_SECTION, KEY_COUNT, 1)),
		KEY_CONFIG: settings.call("get_project_metadata", METADATA_SECTION, KEY_CONFIG, []) as Array
	}


## Turns the setting on for these tags. Returns {ok, message} - or {ok: false, reason} when there
## is no editor to write to. Writing what is already there is still ok: the button's job is to
## leave the editor in that state, not to have changed it.
static func apply_tags(tags: PackedStringArray) -> Dictionary:
	var settings: Object = _editor_settings()
	if settings == null:
		return {"ok": false, "reason": EventSheetL10n.translate(
			"Run Multiple Instances is an editor setting, and there is no editor here.")}
	var was_on: bool = says_tags(stored(), tags)
	settings.call("set_project_metadata", METADATA_SECTION, KEY_CONFIG,
		config_with_tags(stored().get(KEY_CONFIG, []) as Array, tags))
	settings.call("set_project_metadata", METADATA_SECTION, KEY_COUNT, tags.size())
	settings.call("set_project_metadata", METADATA_SECTION, KEY_ENABLED, true)
	# Whole sentences either way: a translator handed "Set to run" and "%s %d copies" separately
	# cannot put them in the order their own language asks for.
	var said: String = EventSheetL10n.translate("Already set to run %d copies, tagged %s.") if was_on \
		else EventSheetL10n.translate("Set to run %d copies, tagged %s.")
	return {"ok": true, "message": said % [tags.size(), ", ".join(tags)]}


## The label a debug session's values belong under - the tag the instance it came from was started
## with. "" for a lone run, which is every non-networked game.
static func label_for_session(session_id: int) -> String:
	var named: PackedStringArray = labels(stored())
	return named[session_id] if session_id >= 0 and session_id < named.size() else ""


static func _editor_settings() -> Object:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	return EditorInterface.get_editor_settings()
