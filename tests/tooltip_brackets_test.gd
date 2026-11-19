# Square brackets in what a row shows on hover. Code such as `items[i]`, `a[b]` or `arr[code]` holds text that
# looks like a bold, italic or colour tag, and a string a person wrote can hold a real one. The hover card is
# built from the plugin's own words plus the user's text, and the user's text must always read as written: the
# card styles only the plugin's tags, and the sentence a row is read as keeps what the user typed, brackets
# included, even when the descriptor's own template carries markup.
@tool
class_name TooltipBracketsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "tooltip_brackets_test"

const NASTY: PackedStringArray = [
	"items[i]", "a[b]", "[u]", "[url]", "arr[code]", "[color=red]", "[color=red]hot[/color]", "[b]bold[/b]",
	"[i]", "[/i]", "[lb]", "[rb]", "x[0] = y[1]", "[1, 2, 3]", "m[i][j] += n[b]", "\"[i]\" + s[i]", "[", "]", "[]", "[[b]]",
]

const SOURCE: String = """extends Node2D


var items: Array = [1, 2, 3]


func probe(i: int, b: int, code: int) -> void:
	var local: Array = [0, 1, 2]
	local[i] = local[b] + local[code]
	var text: String = "[color=red]x[/color] [i]"
	print(text, local[i])
	items[i] += 1
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_card_shows_the_users_text_as_written() and ok
	ok = _test_only_a_closed_tag_is_markup() and ok
	ok = _test_the_sentence_keeps_the_users_brackets() and ok
	ok = _test_a_template_that_styles_its_values_does_not_eat_a_bracket() and ok
	ok = _test_labels_that_list_the_users_names_show_them_as_written() and ok
	return ok


static func _card_text(for_text: String) -> String:
	var helper: EventSheetViewportTooltipHelper = EventSheetViewportTooltipHelper.new()
	var card: Object = helper.build_custom_tooltip(for_text)
	if card == null:
		return "(default tooltip)"
	var rich: RichTextLabel = (card as Node).get_child(0) as RichTextLabel
	(card as Node).add_child(Node.new())
	var shown: String = rich.get_parsed_text()
	(card as Node).free()
	return shown


static func _test_the_card_shows_the_users_text_as_written() -> bool:
	var ok: bool = true
	for text: String in NASTY:
		var hidden: String = EventSheetBBCodeLite.literal(text)
		ok = SUPPORT.pin_value(TEST_NAME, "the user's text alone reads as written: %s" % text,
			_card_text(hidden), text if text.contains("[") else "(default tooltip)") and ok
		ok = SUPPORT.pin_value(TEST_NAME, "beside the plugin's own bold word: %s" % text,
			_card_text("[b]Note[/b] [color=#88cc88]fine[/color]\n" + hidden), "Note fine\n" + text) and ok
		ok = SUPPORT.pin_value(TEST_NAME, "the hidden bracket round-trips: %s" % text,
			EventSheetBBCodeLite.unliteral(hidden), text) and ok
	return ok


static func _test_only_a_closed_tag_is_markup() -> bool:
	return SUPPORT.pin_table(TEST_NAME, {
		"items[i]": false, "a[b]": false, "[i]": false, "[color=red]": false, "[b]": false, "plain": false, "": false,
		"[b]x[/b]": true, "[i]x[/i]": true, "[color=red]x[/color]": true, "[B]x[/B]": true,
		"a[i] then [b]bold[/b]": true,
	}, func(text: Variant) -> Variant: return EventSheetBBCodeLite.has_paired_markup(str(text)))


static func _builder_for(sheet: EventSheetResource) -> EventSheetViewportRowBuilder:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	var builder: EventSheetViewportRowBuilder = viewport._row_builder
	builder.init(viewport)
	return builder


static func _test_the_sentence_keeps_the_users_brackets() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true)
	var builder: EventSheetViewportRowBuilder = _builder_for(sheet)
	var sentences: PackedStringArray = PackedStringArray()
	for function: EventFunction in sheet.functions:
		for event: Variant in (function.events if not function.events.is_empty() else function.rows):
			if event is EventRow:
				sentences.append(builder.row_sentence(event as EventRow))
	var joined: String = "\n".join(sentences)
	ok = SUPPORT.pin_value(TEST_NAME, "the code the sheet read keeps its brackets",
		joined.contains("local[i]") and joined.contains("local[b]") and joined.contains("local[code]"), true) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "a list literal keeps its brackets", joined.contains("[0, 1, 2]"), true) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "a string holding markup keeps it", joined.contains("[color=red]x[/color] [i]"), true) and ok
	return ok


static func _test_a_template_that_styles_its_values_does_not_eat_a_bracket() -> bool:
	var ok: bool = true
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SpawnFormation"
	action.params = {"count": "items[i]", "scene": "scenes[b]", "formation": "\"ring\""}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(action)
	var builder: EventSheetViewportRowBuilder = _builder_for(EventSheetResource.new())
	var plain: String = builder.row_sentence(event)
	ok = SUPPORT.pin_value(TEST_NAME, "the template's own bold tags are gone", plain.contains("[b]{") or plain.contains("[/b]"), false) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "the value in a styled slot keeps its brackets", plain.contains("items[i]") and plain.contains("scenes[b]"), true) and ok
	var hover: String = builder.row_sentence(event, true)
	ok = SUPPORT.pin_value(TEST_NAME, "the hover form hides them", hover.contains("["), false) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "and the card shows them as written",
		_card_text(hover).contains("items[i]") and _card_text(hover).contains("scenes[b]"), true) and ok
	return ok


static func _test_labels_that_list_the_users_names_show_them_as_written() -> bool:
	var ok: bool = true
	var surface: Dictionary = {"properties": [{"name": "items[i]", "type": "Array", "default": "[b]x[/b]"}],
		"actions": [{"name": "Move [i]", "params": "a[b]", "category": "Walk"}]}
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = EventSheetAuthorLoop.publish_surface_text(surface)
	var shown: String = label.get_parsed_text()
	label.free()
	for expected: String in ["items[i]: Array = [b]x[/b]", "Move [i] (a[b])   [Walk]"]:
		ok = SUPPORT.pin_value(TEST_NAME, "the published surface shows %s" % expected, shown.contains(expected), true) and ok
	ok = SUPPORT.pin_table(TEST_NAME, {"a[b]": "a[lb]b]", "plain": "plain", "": "", "[[": "[lb][lb]"},
		func(text: Variant) -> Variant: return EventSheetBBCodeLite.escape(str(text))) and ok
	return ok
