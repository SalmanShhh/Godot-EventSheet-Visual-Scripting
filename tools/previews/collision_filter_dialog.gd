# Godot EventSheets - the With field of a filtered touch trigger (preview module).
#
# Rendered by tools/render_previews.gd. One card, one field, one help strip: the group the trigger
# filters on, picked from the project's own node groups, and under it the one line its author has to
# know - whether the node this row is filed under stops what arrives or only notices it. The two
# answers are photographed side by side because they are the same row read from the two sides Godot
# files the signal under, and the difference is the whole lesson.
@tool
extends RefCounted

const FILTERS := preload("res://addons/eventforge/registration/collision_filters.gd")

const PREVIEW_NAME: String = "collision-filter-dialog"
const PREVIEW_SIZE: Vector2i = Vector2i(1080, 520)

## The With field's own description, said the way the dialog says it: the parameter's text first,
## then the lesson of the node class.
const FIELD_NOTE: String = "Only react when the thing that arrived is in this group. Any node joins a group from the Node dock, and the emitted handler leaves immediately when it is not in it."


static func build(host: Window) -> Control:
	var pair: HBoxContainer = HBoxContainer.new()
	pair.add_theme_constant_override("separation", 16)
	pair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pair.add_child(_card("Hurtbox (Area2D) - On overlap with", "On overlap with enemies",
		"body_entered.connect(_on_body_entered_enemies)", FILTERS.AREA_NOTE))
	pair.add_child(_card("Crate (RigidBody2D) - On collision with", "On collision with enemies",
		"if not body.is_in_group(\"enemies\"):", FILTERS.BODY_NOTE))
	host.add_child(pair)
	return pair


## One dialog, filled in as it looks the moment the With field has focus.
static func _card(title: String, sentence: String, code: String, lesson: String) -> Control:
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	var group: LineEdit = LineEdit.new()
	group.text = "\"enemies\""
	fields.add_child(EventSheetPopupUI.form_row("With", group))
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	var body: String = "%s  %s" % [FIELD_NOTE, lesson]
	strip.follow(group, "With", body)
	strip.describe("With", body)
	strip.set_reading(sentence, code)
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.add_child(EventSheetPopupUI.panel_section(fields))
	column.add_child(strip)
	var card: PanelContainer = EventSheetPopupUI.titled_card(title, column)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return EventSheetPopupUI.margined(card)
