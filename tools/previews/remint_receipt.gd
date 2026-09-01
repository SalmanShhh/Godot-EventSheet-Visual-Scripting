# Godot EventSheets - the Re-mint receipt, drawn before a single digit moves (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The Doctor's Re-mint chip used to make its edit on the click and report it afterwards. This is what
# it opens instead: the sentence saying what is broken and what is deliberately not being touched,
# and one line per row that would be renamed - the name it declares now beside the name it would
# declare, digits and all, minted once so the button writes the ones in the picture.
@tool
extends RefCounted

const PREVIEW_NAME: String = "remint-receipt"
const PREVIEW_SIZE: Vector2i = Vector2i(700, 400)

## The token two branches both minted, and its scope. Fixed rather than drawn, so the picture is the
## same every time it is taken.
const DOUBLED: String = "a3f81c02"


static func build(host: Window) -> Node:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(_sheet())
	host.add_child(dock)
	dock.open_remint_receipt(DOUBLED)
	return dock._remint_receipt._dialog


## Two rows that each declare the same baked local - the file Godot refuses to parse, and the one
## state this receipt is about.
static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Sentry"
	sheet.host_class = "CharacterBody2D"
	var first: EventRow = EventRow.new()
	first.trigger_provider_id = "Core"
	first.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetProperty"
	action.codegen_template = "var __peer_%s := get_node(\"../Alarm\")" % DOUBLED
	first.actions.append(action)
	sheet.events.append(first)
	var second: EventRow = EventRow.new()
	second.trigger_provider_id = "Core"
	second.trigger_id = "OnReady"
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "EveryTick"
	condition.member_declaration = "var __peer_%s := 0.0" % DOUBLED
	condition.codegen_template = "__peer_%s > 1.0" % DOUBLED
	condition.codegen_prelude = "__peer_%s += delta" % DOUBLED
	condition.codegen_on_true = "__peer_%s = 0.0" % DOUBLED
	second.conditions.append(condition)
	sheet.events.append(second)
	return sheet
