# EventSheet - EventSheetRescueTips: the tools find you, once, quietly.
#
# Every rescue surface the editor ships is only useful if the reader knows it exists at the moment
# it would have helped. This is the ONE table of those moments: which feature speaks, at which
# moment, in which words. The rules that keep it from becoming a nag:
#
#   - ONE offer per moment per session. The second stutter, the second silent trigger - silence.
#   - One quiet line, never a dialog: whoever asks for the offer shows it on the status line and
#     moves on.
#   - A global "don't offer tips" switch, persisted per user, honoured before anything is said.
#
# Static and pure over its own state, so the once-per-session and the switch are pinned headlessly.
@tool
class_name EventSheetRescueTips
extends RefCounted

## Where the switch lives - per user, per machine, like the picker recents and the editor
## language. Never committed, never part of the project.
const SETTINGS_FILE := "user://eventforge_tips.cfg"

## The table: feature (what speaks), moment (the stable key a surface asks by), offer (the words,
## as the translation key of the editor's drop-in CSV catalogs). Moments are frozen the way check
## ids are - a surface that shipped asking for one keeps its answer.
const TIPS: Array[Dictionary] = [
	{
		"feature": "why_panel",
		"moment": "first_never_fired_trigger",
		"offer": "Tip: a trigger of this sheet has not fired this run - right-click its row and Ask why.",
	},
	{
		"feature": "row_timings",
		"moment": "first_slow_run",
		"offer": "Tip: that run stuttered - Tools > Row Timings shows which rows the frames went to.",
	},
	{
		"feature": "scene_attachment",
		"moment": "first_run_without_this_sheet",
		"offer": "The game ran, but this sheet never did - its script is not attached to anything in the scene you ran.",
	},
]

## The moments already offered this session. Session-local on purpose: a tip a reader saw an hour
## ago is not a tip any more, and one they saw last week might be again.
static var _shown: Dictionary = {}

## The switch, hydrated once per session from the settings file (editor only - headless keeps the
## default and tests drive the setter directly).
static var _enabled: bool = true
static var _loaded: bool = false


## The one call a surface makes at its moment: the offer's words, exactly once per session, or ""
## when it was already made, tips are off, or the moment is not in the table. The caller shows a
## non-empty answer on its quiet line and does nothing else.
static func offer(moment: String) -> String:
	_ensure_loaded()
	if not _enabled or _shown.has(moment):
		return ""
	for tip: Dictionary in TIPS:
		if str(tip.get("moment", "")) == moment:
			_shown[moment] = true
			return EventSheetL10n.translate(str(tip.get("offer", "")))
	return ""


## Whether offers are made at all - the global "don't offer tips" switch.
static func offers_enabled() -> bool:
	_ensure_loaded()
	return _enabled


## Flips the switch and remembers it per user. The words surfaces show for the switch live with
## the menu that hosts it.
static func set_offers_enabled(enabled: bool) -> void:
	_ensure_loaded()
	_enabled = enabled
	if not Engine.is_editor_hint():
		return
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value("tips", "enabled", enabled)
	if config.save(SETTINGS_FILE) != OK:
		push_warning("EventSheets: couldn't save the tips switch to %s - it lasts only this session." % SETTINGS_FILE)


## Forgets what was offered - a new debug run's moments are the new run's (the trace reset calls
## this), and tests use it to start cold.
static func reset_session() -> void:
	_shown.clear()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not Engine.is_editor_hint():
		return
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		_enabled = bool(config.get_value("tips", "enabled", true))
