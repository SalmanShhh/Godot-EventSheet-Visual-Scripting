# Godot EventSheets - the frame field IS the animation (preview module).
#
# Rendered by tools/render_previews.gd. Both fields here are built by the REAL Parameters dialog off
# the real fixture scene, so the picture cannot drift from the behaviour: the Animation field lists
# what `animation_scene_hero.tscn` actually has, with each clip's length or its loop word beside it,
# and the Frame field is the strip of that clip's own frames - contiguous, numbered from 0 the way
# Godot numbers them, the chosen one lit.
#
# The row being edited is On Animation Frame, aimed at the flipbook. Ask the same dialog about a
# KEYFRAMED clip and there is no strip at all, because a keyframed clip has no frames - which is the
# other half of the claim and the reason the number box never goes away.
@tool
extends RefCounted

const PREVIEW_NAME: String = "animation-frame-strip"
const PREVIEW_SIZE: Vector2i = Vector2i(760, 440)

const FIXTURE: String = "res://tests/fixtures/animation_scene_hero.gd"


static func build(host: Window) -> Control:
	EventSheetSceneAnimations.clear_cache()
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
	dialog._build_form(registry.find_definition("Core", "OnAnimationFrame"),
		{"animation": "\"walk\"", "frame": "3"})
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	fields.add_child(EventSheetPopupUI.form_row("Animation", _lifted(dialog, "animation")))
	fields.add_child(EventSheetPopupUI.form_row("Frame", _lifted(dialog, "frame")))
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	strip.describe("Frame - picked from the strip",
		EventSheetParamFieldFactory.HINT_PARAGRAPHS["animation_frame"])
	strip.set_reading("Player - On animation walk frame 3", "frame_changed … if frame == 3:")
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.add_child(EventSheetPopupUI.panel_section(fields))
	column.add_child(strip)
	var margined: MarginContainer = EventSheetPopupUI.margined(
		EventSheetPopupUI.titled_card("Player - On animation frame", column))
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(margined)
	return stage


## One field the dialog built, lifted out of the form row it was built in - the widget itself, so
## what the picture shows is what the dialog shows. The dialog's own label stays behind, because this
## card writes its own.
static func _lifted(dialog: ACEParamsDialog, key: String) -> Control:
	var built: Control = dialog._fields.get(key) as Control
	var row: Node = built
	while row != null and row.get_parent() != null and row.get_parent() != dialog._form:
		row = row.get_parent()
	if row == null or row.get_parent() == null:
		return Label.new()
	var field_row: Control = row as Control
	field_row.get_parent().remove_child(field_row)
	for child: Node in field_row.get_children():
		if child is Label:
			field_row.remove_child(child)
			child.queue_free()
	return field_row
