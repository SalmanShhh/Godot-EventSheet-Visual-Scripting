# Godot EventSheets - the two fields the rendering words added (preview module).
#
# Rendered by tools/render_previews.gd. Both fields are built by the REAL Parameters dialog, so the
# picture cannot drift from the behaviour:
#
#   VISIBLE TO       the named-mask picker the collision layers already use, pointed at the project's
#                    2D render layer names. The button reads its own selection back in words, which
#                    is what stops anyone computing a bitmask.
#   PRESET           the quality words, which are a FOLDER. The list is res://settings/quality/, so
#                    the picture is literally the files this repository ships, and New preset makes
#                    another one.
@tool
extends RefCounted

const PREVIEW_NAME: String = "rendering-quality-fields"
const PREVIEW_SIZE: Vector2i = Vector2i(760, 400)


static func build(host: Window) -> Control:
	ProjectSettings.set_setting("layer_names/2d_render/layer_1", "world")
	ProjectSettings.set_setting("layer_names/2d_render/layer_2", "minimap")
	var stage: Control = Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(stage)
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.init_dialog(stage, registry, Callable())
	# The dialog is a RefCounted and outlives this call only because the stage holds it - the fields
	# below were parented into the window it built.
	stage.set_meta("dialog", dialog)
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	fields.add_child(EventSheetPopupUI.form_row("Visible to",
		dialog._create_render_layer_2d_field("layers", "2")))
	fields.add_child(EventSheetPopupUI.form_row("Preset",
		dialog._create_quality_preset_field("preset", "\"res://settings/quality/medium.tres\"")))
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	strip.describe("Preset - a quality preset",
		EventSheetParamFieldFactory.HINT_PARAGRAPHS["quality_preset"])
	strip.set_reading("Settings - Apply quality Medium",
		"apply_quality(\"res://settings/quality/medium.tres\")")
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.add_child(EventSheetPopupUI.panel_section(fields))
	column.add_child(strip)
	var margined: MarginContainer = EventSheetPopupUI.margined(
		EventSheetPopupUI.titled_card("Crate - Show only to / Settings - Apply quality", column))
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(margined)
	return stage
