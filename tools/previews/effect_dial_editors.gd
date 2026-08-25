# Godot EventSheets - the dial's hint picks its editor (preview module).
#
# Rendered by tools/render_previews.gd. Every field here is built by the REAL Parameters dialog, from
# the real shader file, so the picture cannot drift from the behaviour: `dissolve` declares
# `hint_range(0.0, 1.0)` and gets the slider, `edge_tint` declares `source_color` and gets the
# colour, `burn_noise` is a sampler and gets the file picker, `steps` is a whole number with ends and
# gets the stepper. The same hints Godot's own Inspector obeys, read from the same file.
#
# The dialog's form is built without popping its window (which is what `_build_form` is separated for)
# and each value row is lifted out of it into one card, so four dials fit in one picture where the
# reader would meet them one at a time.
@tool
extends RefCounted

const PREVIEW_NAME: String = "effect-dial-editors"
const PREVIEW_SIZE: Vector2i = Vector2i(760, 460)

## The sheet the row belongs to - the boss whose sprite wears the burn material, which is what makes
## `dissolve` a dial of a real shader rather than a name somebody typed.
const FIXTURE: String = "res://tests/fixtures/effect_scene_boss.gd"

## The four dials, in the order the shader declares them.
const DIALS: Array[String] = ["dissolve", "edge_tint", "burn_noise", "steps"]


static func build(host: Window) -> Control:
	EventSheetSceneEffects.clear_cache()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = FIXTURE
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var stage: Control = Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(stage)
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.init_dialog(stage, registry, Callable())
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	# The dialog outlives this call only because the stage holds it: it is a RefCounted, and the
	# window it built is what the fields below were parented into.
	stage.set_meta("dialog", dialog)
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	for dial: String in DIALS:
		fields.add_child(EventSheetPopupUI.form_row("effect.%s" % dial,
			_value_editor(dialog, registry, dial)))
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	strip.describe("Value - a value", EventSheetParamFieldFactory.HINT_PARAGRAPHS[
		EventForgeEffectDialACEs.VALUE_HINT])
	strip.set_reading("Boss - Set effect.dissolve to 0.7",
		"material.set_shader_parameter(&\"dissolve\", 0.7)")
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.add_child(EventSheetPopupUI.panel_section(fields))
	column.add_child(strip)
	var margined: MarginContainer = EventSheetPopupUI.margined(
		EventSheetPopupUI.titled_card("Boss - Set effect dial", column))
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(margined)
	return stage


## The Value row the dialog builds for one dial, lifted out of the form it was built in. The form is
## rebuilt per dial because a form is one row's form; what is taken from it is the widget itself, so
## what the picture shows is what the dialog shows.
static func _value_editor(dialog: ACEParamsDialog, registry: EventSheetACERegistry,
		dial: String) -> Control:
	dialog._build_form(registry.find_definition("Core", "EffectSetDial"),
		{"target": "", "dial": dial, "value": ""})
	var built: Control = dialog._fields.get("value") as Control
	var row: Node = built
	while row != null and row.get_parent() != null and row.get_parent() != dialog._form:
		row = row.get_parent()
	if row == null or row.get_parent() == null:
		return Label.new()
	# The label the dialog put in front of it stays behind: this card writes its own, so a reader
	# sees the dial's name rather than the word "Value" four times.
	var value_row: Control = row as Control
	value_row.get_parent().remove_child(value_row)
	for child: Node in value_row.get_children():
		if child is Label:
			value_row.remove_child(child)
			child.queue_free()
	return value_row
