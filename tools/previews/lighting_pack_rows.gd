# Godot EventSheets - the three lighting behaviours as rows on a sheet (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The sheet is authored the way a user authors one - the packs' own triggers, conditions and actions,
# picked and filled - so what the picture shows is the SENTENCE each verb ships with. The clock's
# moments are the events, the lights are the objects, and every number on a row is a number the
# emitted GDScript passes.
@tool
extends RefCounted

const PREVIEW_NAME: String = "lighting-pack-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(1200, 210)

const FLICKER: String = "res://eventsheet_addons/light_flicker/light_flicker_behavior.gd"
const PULSE: String = "res://eventsheet_addons/light_pulse/light_pulse_behavior.gd"
const CYCLE: String = "res://eventsheet_addons/day_night_cycle/day_night_cycle_behavior.gd"


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Village"
	sheet.host_class = "Node2D"
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style

	# On sunset: the beacon comes up at once, the torch catches a moment later.
	var dusk: EventRow = _triggered("DayNightCycleBehavior", "signal:sunset")
	dusk.actions.append(_action("LightPulseBehavior", "method:start_pulsing",
		{"target": "$Beacon/LightPulseBehavior", "after_seconds": "0.0"}))
	dusk.actions.append(_action("LightFlickerBehavior", "method:start_flickering",
		{"target": "$Torch/LightFlickerBehavior", "after_seconds": "1.5"}))
	sheet.events.append(dusk)

	# On the hour: the small hours run faster than the rest of the night.
	var bell: EventRow = _triggered("DayNightCycleBehavior", "signal:hour_struck")
	bell.actions.append(_action("DayNightCycleBehavior", "method:run_the_clock",
		{"target": "$Day/DayNightCycleBehavior", "times_faster": "4.0"}))
	sheet.events.append(bell)

	# And a plain question about the clock, answered every frame.
	var night: EventRow = EventRow.new()
	night.trigger_provider_id = "Core"
	night.trigger_id = "OnProcess"
	night.conditions.append(_condition("DayNightCycleBehavior", "method:it_is_night",
		{"target": "$Day/DayNightCycleBehavior"}))
	night.actions.append(_action("LightFlickerBehavior", "method:stop_flickering",
		{"target": "$Torch/LightFlickerBehavior", "settle_at": "0.6"}))
	sheet.events.append(night)

	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.set_ace_registry(_registry_with_the_packs())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	host.add_child(viewport)
	# A preview is photographed, never pointed at, and set LAST because the canvas takes the mouse
	# back while it builds: without this, wherever the machine's cursor happens to rest decides
	# whether a tooltip covers half the picture.
	viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return viewport


## A registry that knows the three packs, built the way the dock builds its own: from instances of
## the provider scripts. Freed straight after, because the definitions are what the registry keeps.
static func _registry_with_the_packs() -> EventSheetACERegistry:
	var sources: Array[Object] = []
	for path: String in [FLICKER, PULSE, CYCLE]:
		sources.append((load(path) as GDScript).new())
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources(sources, true)
	for source: Object in sources:
		if source is Node:
			(source as Node).free()
	return registry


static func _triggered(provider_id: String, trigger_id: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = provider_id
	row.trigger_id = trigger_id
	return row


static func _action(provider_id: String, ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = provider_id
	action.ace_id = ace_id
	action.params = params
	return action


static func _condition(provider_id: String, ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = provider_id
	condition.ace_id = ace_id
	condition.params = params
	return condition
