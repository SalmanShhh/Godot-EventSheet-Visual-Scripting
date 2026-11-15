# Godot EventSheets - the Juice Player's words: what a person reads, row by row.
#
# The node holds a list of juice cards. Its rows say so: the list is "juice" (Play Juice, Stop Juice,
# On Juice Started), one entry is a "juice card" (Add Juice Card, Juice Card Count), and the node is
# the Juice Player. Every name and sentence is pinned here as a VALUE, beside the id it belongs to: an
# id is a promise to saved sheets and never moves, a name may. The old words keep finding the rows in
# the picker, because the ids and the tags still say them.
class_name JuicePlayerWordsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_player_words"
const PACK_PATH: String = "res://eventsheet_addons/juice/juice_player.gd"
const CATEGORY: String = "Juice Player"

## The id, the name a person reads, and the sentence a row reads as ("" and "(name)" and "(same)" mean
## the row has no sentence of its own beyond its name).
const ROWS: Array = [
	["signal:on_feedbacks_started", "On Juice Started", "(name)"],
	["signal:on_feedbacks_finished", "On Juice Finished", ""],
	["signal:on_feedback_signal", "On Juice Signal", ""],
	["signal:on_feedback_started", "On Juice Card Started", ""],
	["signal:on_feedback_finished", "On Juice Card Finished", ""],
	["signal:on_feedback_skipped", "On Juice Card Skipped", ""],
	["signal:on_hold_reached", "On Hold Reached", ""],
	["signal:on_loop", "On Loop", ""],
	["method:play", "Play Juice", "Play juice at {at_strength}"],
	["method:play_and_wait", "Play Juice And Wait", "Play juice at {at_strength} and wait"],
	["method:play_backwards", "Play Juice Backwards", "Play juice backwards at {at_strength}"],
	["method:play_on_channel", "Play Juice On Channel", "Play juice on channel {channel} at {at_strength}"],
	["method:stop", "Stop Juice", ""],
	["method:skip_to_end", "Skip To End", ""],
	["method:restore", "Restore Initial Values", ""],
	["method:revert", "Revert", ""],
	["method:pause_feedbacks", "Pause Juice", ""],
	["method:resume_feedbacks", "Resume Juice", ""],
	["method:is_playing", "Is Playing", ""],
	["method:has_played", "Has Played", ""],
	["method:feedbacks_progress", "Juice Progress", ""],
	["method:feedbacks_duration", "Juice Duration", ""],
	["method:add_feedback", "Add Juice Card", "Add juice card {step} after {after_label}"],
	["method:insert_feedback_before", "Insert Juice Card Before", "Insert juice card {step} before {before_label}"],
	["method:replace_feedback", "Replace Juice Card", "Replace juice card {label} with {step}"],
	["method:remove_feedback", "Remove Juice Card", "Remove juice card {label}"],
	["method:move_feedback_to", "Move Juice Card To", "Move juice card {label} to {position}"],
	["method:enable_feedback", "Enable Juice Card", "Enable juice card {label}"],
	["method:disable_feedback", "Disable Juice Card", "Disable juice card {label}"],
	["method:set_feedback_field", "Set Juice Card Field", "Set juice card {label} {field} to {value}"],
	["method:set_feedback_timing", "Set Juice Card Timing", "Set juice card {label} timing: delay {delay} s, {repeat} times"],
	["method:set_feedback_chance", "Set Juice Card Chance", "Set juice card {label} chance {percent}%"],
	["method:set_feedback_label", "Rename Juice Card", "Rename juice card {label} to {new_label}"],
	["method:duplicate_feedback", "Duplicate Juice Card", "Duplicate juice card {label} as {new_label}"],
	["method:clear_feedbacks", "Clear Juice Cards", ""],
	["method:copy_feedbacks_from", "Copy Juice Cards From", "Copy juice cards from {other}"],
	["method:load_moment_file", "Load Moment File", "(same)"],
	["method:save_moment_file", "Save Moment File", "(same)"],
	["method:set_player_strength", "Set Juice Player Strength", "Set juice player strength {value}"],
	["method:set_player_cooldown", "Set Juice Player Cooldown", "Set juice player cooldown {seconds} s"],
	["method:set_can_play_while_playing", "Set Can Play While Playing", "(same)"],
	["method:mute_feedback_category", "Mute Juice Family", "Mute juice family {category}: {muted}"],
	["method:mute_category_on_channel", "Mute Juice Family On Channel", "Mute juice family {category} on channel {channel}: {muted}"],
	["method:scale_feedback_amounts", "Scale Juice Amounts", "Scale juice amounts {category} by {factor}"],
	["method:retime_feedbacks", "Scale Juice Timing", "Scale juice timing by {factor}"],
	["method:shuffle_feedbacks_between", "Shuffle Juice Cards Between", "Shuffle juice cards {first_label} to {last_label}"],
	["method:pick_one_feedback_of", "Pick One Juice Card Starting With", "Pick one juice card starting with {prefix}"],
	["method:jump_to_feedback", "Jump To Juice Card", "Jump to juice card {label}"],
	["method:skip_feedback_once", "Skip Juice Card Once", "Skip juice card {label} once"],
	["method:set_loop_count", "Set Loop Count", "(same)"],
	["method:hold_here", "Hold Here", ""],
	["method:release_hold", "Release Hold", ""],
	["method:feedback_is_playing", "Juice Card Is Playing", "Juice card {label} is playing"],
	["method:has_feedback", "Has Juice Card", "Has juice card {label}"],
	["method:feedback_is_enabled", "Juice Card Is Enabled", "Juice card {label} is enabled"],
	["method:feedback_count", "Juice Card Count", ""],
	["method:feedback_label_at", "Juice Card Label At", ""],
	["method:feedback_field", "Juice Card Field", ""],
	["method:feedback_progress", "Juice Card Progress", ""],
	["method:feedback_duration", "Juice Card Duration", ""],
	["method:current_feedback", "Current Juice Card", ""],
	["method:loops_left", "Loops Left", ""],
	["method:for_each_feedback", "For Each Juice Card", ""]
]


static func run() -> bool:
	var published: Dictionary = {}
	var categories: Dictionary = {}
	for definition: ACEDefinition in EventSheetACEGenerator.new().generate_from_script(load(PACK_PATH)):
		published[definition.id] = definition
		categories[definition.category] = true
	var names: Array = []
	var sentences: Array = []
	var expected_names: Array = []
	var expected_sentences: Array = []
	for row: Array in ROWS:
		var definition: ACEDefinition = published.get(row[0]) as ACEDefinition
		names.append([row[0], definition.display_name if definition != null else "<no such row>"])
		expected_names.append([row[0], row[1]])
		if row[2] in ["", "(name)", "(same)"] or definition == null:
			continue
		sentences.append([row[0], _plain(str(definition.metadata.get("display_template", "")))])
		expected_sentences.append([row[0], row[2]])
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["every row has its name", names, expected_names],
		["and its sentence", sentences, expected_sentences],
		["the pack is one picker category", categories.keys(), [CATEGORY]],
		["a new Play On Channel row starts on the Juice Players' group", _default_of(published, "method:play_on_channel", "channel"), "juice_players"],
	])
	return _search_pins(published) and ok


## The picker still finds a row by the words it had before: the method name and the tags say them.
static func _search_pins(published: Dictionary) -> bool:
	var rows: Array = []
	for id: String in ["method:play", "method:enable_feedback", "signal:on_feedback_started"]:
		var definition: ACEDefinition = published.get(id) as ACEDefinition
		rows.append(EventSheetQuickAdd.score("feedback", definition.display_name, "", definition.get_search_text()) > 0 if definition != null else false)
	var tags: String = (published.get("method:play") as ACEDefinition).get_search_text()
	return SUPPORT.pins(TEST_NAME, [
		["the old word finds Play, Enable and the card trigger", rows, [true, true, true]],
		["the new words are in the search text", [tags.contains("juice player"), tags.contains("feedback")], [true, true]],
	])


static func _plain(template: String) -> String:
	return template.replace("[b]", "").replace("[/b]", "").replace("[i]", "").replace("[/i]", "")


static func _default_of(published: Dictionary, id: String, param: String) -> String:
	var definition: ACEDefinition = published.get(id) as ACEDefinition
	if definition == null:
		return "<no such row>"
	for parameter: Variant in definition.parameters:
		if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == param:
			return str((parameter as Dictionary).get("default_value", ""))
	return "<no such param>"
