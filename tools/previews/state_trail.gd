# Godot EventSheets - the Debugger's Trail tab (preview module).
#
# Rendered by tools/render_previews.gd. A STAGED run of the machine below is pushed through the very
# statics a real run pushes frames through - the values frames the game flushes, and the trace window
# that lands right after each of them - and then the tab's own body is filled from the resulting ring.
# So the picture cannot show a sentence, a pattern note or a moment the editor would not produce: the
# only thing staged here is the run.
#
# The staged run is the one worth photographing: an enemy is hit into a stagger and hit again while
# still staggered, which restarts the clock the Is in Stagger for over 6s row is waiting on. That is
# the self-transition the pattern note is for.
@tool
extends RefCounted

const PREVIEW_NAME: String = "state-trail"
const PREVIEW_SIZE: Vector2i = Vector2i(880, 540)

## The machine, and the uids its rows carry.
const DECLARED: PackedStringArray = ["Patrol", "Chase", "Stagger"]
const STARTS_IN: String = "Patrol"
const HIT_ROW: String = "row-hit"
const CALM_ROW: String = "row-calm"
const SPOT_ROW: String = "row-spot"
const LEAVING_ROW: String = "row-leaving-stagger"

## The run, one entry per streamed frame: [state, seconds held, the uids that window reported].
## Every quarter-second of it is a message the running game really sends.
const RUN: Array = [
	["PATROL", 0.5, []],
	["PATROL", 0.75, []],
	["CHASE", 0.02, [SPOT_ROW]],
	["CHASE", 0.27, []],
	["STAGGER", 0.03, [HIT_ROW]],
	["STAGGER", 0.28, []],
	["STAGGER", 0.02, [HIT_ROW]],
	["STAGGER", 0.27, []],
	["STAGGER", 0.02, [HIT_ROW]],
]


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = _sheet()
	var rows: Dictionary = EventSheetStateFacts.trail_rows(sheet)
	EventSheetStateTrail.clear()
	EventSheetStateWatch.clear()
	for step: Variant in RUN:
		var frame: Array = step
		var values: Dictionary = {
			EventSheetStateWatch.STATE_KEY: str(frame[0]),
			EventSheetStateWatch.SECONDS_KEY: float(frame[1]),
		}
		EventSheetStateWatch.note_frame(values)
		EventSheetStateTrail.note_frame(values, "", rows)
		var fired: PackedStringArray = PackedStringArray()
		for uid: Variant in (frame[2] as Array):
			fired.append(str(uid))
		EventSheetStateTrail.note_fired(fired, PackedInt32Array([0]), rows)

	var body: Dictionary = EventSheetDebuggerWindow.build_trail_body()
	EventSheetDebuggerWindow.fill_trail(body["sentences"], body["patterns"],
		EventSheetStateTrail.all_entries(), rows, EventSheetStateTrail.has_run(),
		EventSheetStateWatch.band_reading())
	var card: PanelContainer = EventSheetPopupUI.titled_card("Debugger ▸ Trail", body["root"])
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var framed: Control = EventSheetPopupUI.margined(card)
	framed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(framed)
	return framed


## The enemy the run above is of: it spots you, it is hit into a stagger, and it calms down after six
## seconds - with the row that answers leaving the stagger, so the note has both rows to name.
static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	EventSheetStatesDialog.write(sheet, DECLARED, STARTS_IN)
	var hit: EventRow = _event(HIT_ROW, "signal:hit", {})
	hit.actions.append(_action("GoToState", {"state": "STAGGER"}))
	sheet.events.append(hit)
	var calm: EventRow = _event(CALM_ROW, "OnProcess", {})
	calm.conditions.append(_condition("InStateForOver", {"state": "STAGGER", "seconds": "6"}))
	calm.actions.append(_action("GoToState", {"state": "PATROL"}))
	sheet.events.append(calm)
	var spot: EventRow = _event(SPOT_ROW, "OnProcess", {})
	spot.conditions.append(_condition("InState", {"state": "PATROL"}))
	spot.actions.append(_action("GoToState", {"state": "CHASE"}))
	sheet.events.append(spot)
	sheet.events.append(_event(LEAVING_ROW, "OnLeavingState", {"state": "STAGGER"}))
	return sheet


static func _event(uid: String, trigger_id: String, trigger_params: Dictionary) -> EventRow:
	var row: EventRow = EventRow.new()
	row.event_uid = uid
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	row.trigger_params = trigger_params
	return row


static func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	return condition


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action
