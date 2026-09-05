# Pack builder - feedback_player (a NODE beside the Juice pack: the list of feedbacks an object
# plays; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## The Feedback Player: a node you add under any object, holding the list of feedbacks that object
## plays when something happens to it.
##
## THE THIRD HOME OF A MOMENT. A beat of feedback can be written down three ways in this project:
## as a Moment block of rows in a sheet, as a moment FILE shared between objects, and as this
## node's list. All three hold the SAME step shape - a word plus how much, which extra word and how
## long - and all three time themselves through the runner beside the Juice pack, so a beat behaves
## the same wherever it was written. A moment file dropped on this node's slot replaces the list,
## and Save As File writes the list back out as one.
##
## WHAT THE LIST ADDS to the words a file holds: the timing a file cannot carry. Pause, Hold, Loop
## Start and Loop Back move the head; Tween Property, Emit Signal and Play Player are the three
## steps that are not a Juice word. Everything else on a card - the chance, the initial delay, the
## repeats, the clock, the strength window - is a KEY on the same dictionary, absent by default, so
## a moment file's step is already a valid card and a card that uses none of them saves as a file.
##
## IT NAMES NO OTHER PACK. The ten Juice words are played by asking whichever node beside this one
## answers the moment-step call, found by that call rather than by a class, so the Feedback Player
## compiles and runs in a project that deleted the Juice behaviour - it just has nothing to shake.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "FeedbackPlayer"
	sheet.class_description = "The list of feedbacks an object plays: add this node under it, fill the list with shakes, flashes, holds and loops, and one row plays the lot. The list is the same shape a moment file holds, so it can be saved out and shared; the strength on the row scales every amount in it."
	sheet.addon_category = "Feedback Player"
	sheet.addon_tags = PackedStringArray(["juice", "feedback", "game feel"])
	sheet.variables = {
		"steps": {"type": "Array[Dictionary]", "default": [], "exported": true,
			"attributes": {"tooltip": "The feedbacks this object plays, in order. Each one is a card: what it does, how much, how long, and the timing words between them.",
				"drawer": "cards", "cards_schema": "feedback_steps", "cards_kind_key": "verb",
				"cards_stripe_key": "category",
				"header": "Feedback Player", "header_color": "#8a6fd4",
				"info": "One card per feedback. Pause and Hold space them out, Loop Start and Loop Back repeat a stretch, and everything else is felt. Play plays the list; the strength on the row scales every amount in it."}},
		"strength": {"type": "float", "default": 1.0, "exported": true,
			"attributes": {"tooltip": "What every amount in the list is scaled by before the strength on the row is applied. Turn a whole object's feedback down without retuning a single card."}},
		"direction": {"type": "String", "default": "top to bottom", "exported": true,
			"attributes": {"tooltip": "Which end of the list a play starts from.",
				"drawer": "toggle_row", "toggle_options": ["top to bottom", "bottom to top"]}},
		"while_playing": {"type": "String", "default": "restart", "exported": true,
			"attributes": {"tooltip": "What a second play does while the first is still running: restart it, ignore the new one, or let the two overlap.",
				"drawer": "toggle_row", "toggle_options": ["restart", "ignore", "overlap"]}},
		"cooldown": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "The shortest gap between two plays, in seconds. A play asked for sooner than this is refused, which is how a rapid-fire hit stops stacking its own feedback."}},
		"moment_file": {"type": "Resource", "default": null, "exported": true,
			"attributes": {"tooltip": "Optional: a moment file to play INSTEAD of the list. Drop one here to share a beat between objects; Save As File writes this list out as one."}}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Feedback Player: add this node under an object, fill its list in the Inspector, and one row plays the whole beat. Cards are dragged into order, ticked off, and tuned in place; Pause and Hold space them out and Loop Back repeats a stretch. The ten shake-and-flash words are played by the Juice behaviour beside this node, so put one there too. The list is the same shape a moment file holds - drop a file on the slot to play it instead, or save the list out as one. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var started: SignalRow = SignalRow.new()
	started.signal_name = "on_feedbacks_started"
	started.params = PackedStringArray(["at_strength: float"])
	started.trigger = true
	started.ace_name = "On Feedbacks Started"
	started.ace_category = "Feedback Player"
	sheet.events.append(started)

	var finished: SignalRow = SignalRow.new()
	finished.signal_name = "on_feedbacks_finished"
	finished.params = PackedStringArray([])
	finished.trigger = true
	finished.ace_name = "On Feedbacks Finished"
	finished.ace_category = "Feedback Player"
	sheet.events.append(finished)

	var spoken: SignalRow = SignalRow.new()
	spoken.signal_name = "on_feedback_signal"
	spoken.params = PackedStringArray(["word: String"])
	spoken.trigger = true
	spoken.ace_name = "On Feedback Signal"
	spoken.ace_category = "Feedback Player"
	sheet.events.append(spoken)

	# The five that speak about ONE card rather than about the play: each carries the label the row
	# addresses that card by, so a trigger and an edit row name the same thing the same way.
	_trigger(sheet, "on_feedback_started", ["label: String"], "On Feedback Started")
	_trigger(sheet, "on_feedback_finished", ["label: String"], "On Feedback Finished")
	_trigger(sheet, "on_feedback_skipped", ["label: String", "why: String"], "On Feedback Skipped")
	_trigger(sheet, "on_hold_reached", [], "On Hold Reached")
	_trigger(sheet, "on_loop", ["loops_left: int"], "On Loop")

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(_player_lines())
	sheet.events.append(block)

	var addressing: RawCodeRow = RawCodeRow.new()
	addressing.code = "\n".join(_addressing_lines())
	sheet.events.append(addressing)

	_verbs(sheet)
	_list_verbs(sheet)
	_asking_verbs(sheet)
	Lib.verb_sentences(sheet, {
		"play": "Play feedbacks at [b]{at_strength}[/b]",
		"play_and_wait": "Play feedbacks at [b]{at_strength}[/b] and wait",
		"play_on_channel": "Play feedbacks on channel [b]{channel}[/b] at [b]{at_strength}[/b]",
		"play_backwards": "Play feedbacks backwards at [b]{at_strength}[/b]",
		"add_feedback": "Add feedback [b]{step}[/b] after [b]{after_label}[/b]",
		"insert_feedback_before": "Insert feedback [b]{step}[/b] before [b]{before_label}[/b]",
		"replace_feedback": "Replace feedback [b]{label}[/b] with [b]{step}[/b]",
		"remove_feedback": "Remove feedback [b]{label}[/b]",
		"move_feedback_to": "Move feedback [b]{label}[/b] to [b]{position}[/b]",
		"enable_feedback": "Enable feedback [b]{label}[/b]",
		"disable_feedback": "Disable feedback [b]{label}[/b]",
		"set_feedback_field": "Set feedback [b]{label}[/b] [b]{field}[/b] to [b]{value}[/b]",
		"set_feedback_timing": "Set feedback [b]{label}[/b] timing: delay [b]{delay}[/b] s, [b]{repeat}[/b] times",
		"set_feedback_chance": "Set feedback [b]{label}[/b] chance [b]{percent}[/b]%",
		"set_feedback_label": "Rename feedback [b]{label}[/b] to [b]{new_label}[/b]",
		"duplicate_feedback": "Duplicate feedback [b]{label}[/b] as [b]{new_label}[/b]",
		"copy_feedbacks_from": "Copy feedbacks from [i]{other}[/i]",
		"load_moment_file": "Load moment file [b]{path}[/b]",
		"save_moment_file": "Save moment file to [b]{path}[/b]",
		"set_player_strength": "Set player strength [b]{value}[/b]",
		"set_player_cooldown": "Set player cooldown [b]{seconds}[/b] s",
		"set_can_play_while_playing": "While playing, [b]{answer}[/b]",
		"mute_feedback_category": "Mute feedback category [b]{category}[/b]: [b]{muted}[/b]",
		"mute_category_on_channel": "Mute feedback category [b]{category}[/b] on channel [b]{channel}[/b]: [b]{muted}[/b]",
		"scale_feedback_amounts": "Scale feedback amounts [b]{category}[/b] by [b]{factor}[/b]",
		"retime_feedbacks": "Retime feedbacks by [b]{factor}[/b]",
		"shuffle_feedbacks_between": "Shuffle feedbacks [b]{first_label}[/b] to [b]{last_label}[/b]",
		"pick_one_feedback_of": "Pick one feedback of [b]{prefix}[/b]",
		"jump_to_feedback": "Jump to feedback [b]{label}[/b]",
		"skip_feedback_once": "Skip feedback [b]{label}[/b] once",
		"set_loop_count": "Set loop count [b]{label}[/b] to [b]{loops}[/b]",
		"feedback_is_playing": "Feedback [b]{label}[/b] is playing",
		"has_feedback": "Has feedback [b]{label}[/b]",
		"feedback_is_enabled": "Feedback [b]{label}[/b] is enabled"
	})
	Lib.feature_verbs(sheet, ["play", "play_and_wait", "stop"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/juice/feedback_player")


## The verbs a sheet reads on the node: the plays, the two that ask, and the two that answer.
static func _verbs(sheet: EventSheetResource) -> void:
	Lib.append_function(sheet, "play", "Play Feedbacks", "Feedback Player",
		"Plays this node's list of feedbacks and carries straight on with the rows under this one. The strength scales every amount in the list, so a light hit and a heavy one are one list at two numbers.",
		[["at_strength", "float", "Scales every amount in the list. 1 is the list as tuned, 0.5 a lighter version of the same beat."]],
		"if _may_start():\n\t_walk(_steps_now(), at_strength, direction == BOTTOM_TO_TOP)")
	_default(sheet, "at_strength", "1.0")
	Lib.append_function(sheet, "play_and_wait", "Play Feedbacks And Wait", "Feedback Player",
		"Plays the list and WAITS for the last card to finish - the rows under this one are what happens afterwards. Use it when the hit has to land before the death animation starts.",
		[["at_strength", "float", "Scales every amount in the list, exactly as Play Feedbacks does."]],
		"if _may_start():\n\tawait _walk(_steps_now(), at_strength, direction == BOTTOM_TO_TOP)")
	_default(sheet, "at_strength", "1.0")
	_await_call(sheet, "play_and_wait({at_strength})")
	Lib.append_function(sheet, "play_backwards", "Play Backwards", "Feedback Player",
		"Plays the list from the far end, so the last feedback is felt first. The other half of a beat that has to undo itself - a door that opened, closing.",
		[["at_strength", "float", "Scales every amount in the list, exactly as Play Feedbacks does."]],
		"if _may_start():\n\t_walk(_steps_now(), at_strength, direction != BOTTOM_TO_TOP)")
	_default(sheet, "at_strength", "1.0")
	Lib.append_function(sheet, "play_on_channel", "Play On Channel", "Feedback Player",
		"Plays every feedback player in a group at once, at one strength - the whole squad flinching, every button in a menu bouncing. Put the players in the group and name it here.",
		[["channel", "String", "The group every player that should feel this is in."],
			["at_strength", "float", "Scales every amount in every list it reaches."]],
		"if channel.strip_edges().is_empty() or not is_inside_tree():\n\treturn\nget_tree().call_group(channel, \"play_feedbacks_from_channel\", at_strength)")
	_default(sheet, "channel", "feedback")
	_default(sheet, "at_strength", "1.0")
	_quoted_call(sheet, "play_on_channel(\"{channel}\", {at_strength})")
	Lib.append_function(sheet, "stop", "Stop Feedbacks", "Feedback Player",
		"Stops the play where it is. Whatever a card already started keeps running on its own - this stops the LIST, not the shake it set going.",
		[], "if not playing:\n\treturn\n_live.clear()\n_resumed.emit()\n_told_nested(\"stop\")\n_close()")
	Lib.append_function(sheet, "skip_to_end", "Skip To End", "Feedback Player",
		"Stops waiting and does everything that is left at once - the cutscene skip of a feedback list. Every card from the head down is felt, without the pauses between them.",
		[], "if not playing:\n\treturn\n_live.clear()\n_paused = false\n_resumed.emit()\nvar left: Array = _order\nvar from: int = _head\nvar at_strength: float = _head_strength\n_close()\n_told_nested(\"skip_to_end\")\nfor index: int in range(from, left.size()):\n\tif not (left[index] is Dictionary):\n\t\tcontinue\n\tvar card: Dictionary = left[index]\n\tif _card_runs(card, at_strength) and not _is_timing(str(card.get(\"verb\", \"\"))):\n\t\t_do_step(card, at_strength)")
	Lib.append_function(sheet, "restore", "Restore Initial Values", "Feedback Player",
		"Puts every value this player's Tween Property cards changed back the way they found it. The undo of a list that moved the object rather than flashing it.",
		[], "_stop_tweens()\n_told_nested(\"restore\")\nfor entry: Variant in _restore_to:\n\tvar card: Dictionary = entry as Dictionary\n\tvar object: Object = card.get(\"object\") as Object\n\tif object != null and is_instance_valid(object):\n\t\tobject.set(str(card.get(\"property\", \"\")), card.get(\"value\"))\n_restore_to.clear()")
	Lib.append_function(sheet, "revert", "Revert", "Feedback Player",
		"Stops the play and puts back what it changed, the LAST change first - so a stack of tweens unwinds in the order it was built rather than all at once.",
		[], "stop()\n_restore_to.reverse()\nrestore()")
	Lib.append_function(sheet, "pause_feedbacks", "Pause Feedbacks", "Feedback Player",
		"Holds the play where it is without losing its place. Resume Feedbacks carries on from the same card.",
		[], "_paused = playing")
	Lib.append_function(sheet, "resume_feedbacks", "Resume Feedbacks", "Feedback Player",
		"Carries on from where Pause Feedbacks left off.",
		[], "_paused = false\n_resumed.emit()")
	Lib.condition(sheet, "is_playing", "Is Playing", "Feedback Player",
		"True while a play is running - between the started and the finished trigger.",
		[], "return playing")
	Lib.condition(sheet, "has_played", "Has Played", "Feedback Player",
		"True once this player has played at least once, and stays true. The \"they have seen this already\" question, with nothing to store.",
		[], "return _played_once")
	Lib.number(sheet, "feedbacks_progress", "Feedbacks Progress", "Feedback Player",
		"How far down the list the play has got, 0 at the first card and 1 when the last one is done.",
		[], "return progress", TYPE_FLOAT)
	Lib.number(sheet, "feedbacks_duration", "Feedbacks Duration", "Feedback Player",
		"The longest path through the list in seconds - the same number the head of the Inspector shows, so a row can wait exactly as long as the beat lasts.",
		[], "return duration_of(_steps_now())", TYPE_FLOAT)


## One trigger the sheet hears, in the shape all of this pack's triggers share.
static func _trigger(sheet: EventSheetResource, signal_name: String, params: Array,
		display_name: String) -> void:
	var row: SignalRow = SignalRow.new()
	row.signal_name = signal_name
	row.params = PackedStringArray(params)
	row.trigger = true
	row.ace_name = display_name
	row.ace_category = "Feedback Player"
	sheet.events.append(row)


## Everything the Inspector's list does, as rows: add a card, put one somewhere, take one out, tune
## one, switch one off, and the handful of things only a running game can want (mute a family,
## scale the lot, shuffle for variety, jump the head). Every one of them names a card by its LABEL.
static func _list_verbs(sheet: EventSheetResource) -> void:
	Lib.append_function(sheet, "add_feedback", "Add Feedback", "Feedback Player",
		"Adds one feedback to this player's list while the game runs - the same card the Inspector adds, with the same fields. Leave the after box empty to put it at the end, or name a card to put it straight after that one.",
		[["step", "Dictionary", "The feedback itself: pick its kind and fill the card, exactly as in the Inspector's list."],
			["after_label", "String", "The label of the card this one goes after. Empty puts it at the end of the list."]],
		"var list: Array = _own_list()\nvar at: int = list.size()\nif not after_label.strip_edges().is_empty():\n\tat = _index_in(list, after_label)\n\tif at < 0:\n\t\t_no_such(after_label, \"Add Feedback\")\n\t\treturn\n\tat += 1\nlist.insert(at, _carded(step))")
	_param_hint(sheet, "step", "feedback_step")
	_default(sheet, "step", "{\"verb\": \"shake\", \"amount\": 0.4, \"seconds\": 0.2}")
	_default(sheet, "after_label", "")
	_quoted_call(sheet, "add_feedback({step}, \"{after_label}\")")
	Lib.append_function(sheet, "insert_feedback_before", "Insert Feedback Before", "Feedback Player",
		"Puts a feedback into the list immediately ABOVE the card you name - the other half of Add Feedback, for a step that has to be felt before something already in the beat.",
		[["step", "Dictionary", "The feedback itself: pick its kind and fill the card, exactly as in the Inspector's list."],
			["before_label", "String", "The label of the card this one goes above."]],
		"var list: Array = _own_list()\nvar at: int = _index_in(list, before_label)\nif at < 0:\n\t_no_such(before_label, \"Insert Feedback Before\")\n\treturn\nlist.insert(at, _carded(step))")
	_param_hint(sheet, "step", "feedback_step")
	_default(sheet, "step", "{\"verb\": \"flash\", \"amount\": 1.0, \"seconds\": 0.1}")
	_default(sheet, "before_label", "shake")
	_quoted_call(sheet, "insert_feedback_before({step}, \"{before_label}\")")
	Lib.append_function(sheet, "replace_feedback", "Replace Feedback", "Feedback Player",
		"Swaps one card in the list for another, in place. THE weapon-change row: the beat the designer tuned stays the beat, and only the kick inside it changes. The new card keeps the old one's label unless it brings its own, so every other row that names it goes on working.",
		[["label", "String", "The label of the card being swapped out."],
			["step", "Dictionary", "What takes its place: a kind and its fields, as in the Inspector's list."]],
		"var list: Array = _own_list()\nvar at: int = _index_in(list, label)\nif at < 0:\n\t_no_such(label, \"Replace Feedback\")\n\treturn\nvar fresh: Dictionary = _carded(step)\nif str(fresh.get(\"label\", \"\")).strip_edges().is_empty():\n\tfresh[\"label\"] = _label_of(list[at] as Dictionary)\nlist[at] = fresh")
	_default(sheet, "label", "kick")
	_param_hint(sheet, "step", "feedback_step")
	_default(sheet, "step", "{\"verb\": \"recoil\", \"amount\": 1.0, \"seconds\": 0.1}")
	_quoted_call(sheet, "replace_feedback(\"{label}\", {step})")
	Lib.append_function(sheet, "remove_feedback", "Remove Feedback", "Feedback Player",
		"Takes one card out of the list. What an upgrade that drops a part of a beat does, and the undo of Add Feedback.",
		[["label", "String", "The label of the card to take out."]],
		"var list: Array = _own_list()\nvar at: int = _index_in(list, label)\nif at < 0:\n\t_no_such(label, \"Remove Feedback\")\n\treturn\nlist.remove_at(at)")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "remove_feedback(\"{label}\")")
	Lib.append_function(sheet, "move_feedback_to", "Move Feedback To", "Feedback Player",
		"Moves one card to a place in the list - the drag handle, as a row. The first card is 1; a number past the end puts it last.",
		[["label", "String", "The label of the card to move."],
			["position", "int", "Where it lands. The first card in the list is 1."]],
		"var list: Array = _own_list()\nvar at: int = _index_in(list, label)\nif at < 0:\n\t_no_such(label, \"Move Feedback To\")\n\treturn\nvar card: Dictionary = list[at] as Dictionary\nlist.remove_at(at)\nlist.insert(clampi(position - 1, 0, list.size()), card)")
	_default(sheet, "label", "shake")
	_default(sheet, "position", "1")
	_quoted_call(sheet, "move_feedback_to(\"{label}\", {position})")
	Lib.append_function(sheet, "enable_feedback", "Enable Feedback", "Feedback Player",
		"Ticks one card's box, so it is felt again from the next play on. The enable box in the Inspector, as a row.",
		[["label", "String", "The label of the card to switch on."]],
		"var card: Dictionary = _edited(label, \"Enable Feedback\")\nif not card.is_empty():\n\tcard[\"active\"] = true")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "enable_feedback(\"{label}\")")
	Lib.append_function(sheet, "disable_feedback", "Disable Feedback", "Feedback Player",
		"Unticks one card's box, so the play steps over it. What an accessibility option that drops the screen shake and keeps the sound does with one row.",
		[["label", "String", "The label of the card to switch off."]],
		"var card: Dictionary = _edited(label, \"Disable Feedback\")\nif not card.is_empty():\n\tcard[\"active\"] = false")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "disable_feedback(\"{label}\")")
	Lib.append_function(sheet, "set_feedback_field", "Set Feedback Field", "Feedback Player",
		"Retunes ONE value on one card: how much, how long, which extra word. The number box in the Inspector, as a row, so a weapon or a difficulty can move an amount without a second list.",
		[["label", "String", "The label of the card being tuned."],
			["field", "String", "Which value on the card to write."],
			["value", "Variant", "What to write. A number for an amount or a length, a word for the extra one."]],
		"var card: Dictionary = _edited(label, \"Set Feedback Field\")\nif card.is_empty():\n\treturn\nif not FIELD_KEYS.has(field):\n\tpush_warning(\"Feedback Player: a card has no field called \\\"%s\\\", so Set Feedback Field did nothing.\" % field)\n\treturn\ncard[field] = value")
	_default(sheet, "label", "shake")
	_param_options(sheet, "field", ["amount", "effect", "seconds", "delay", "interval", "repeat", "chance", "loops"])
	_default(sheet, "field", "amount")
	_default(sheet, "value", "1.0")
	_quoted_call(sheet, "set_feedback_field(\"{label}\", \"{field}\", {value})")
	Lib.append_function(sheet, "set_feedback_timing", "Set Feedback Timing", "Feedback Player",
		"Moves one card in time: how long it waits first, how many times it repeats and how far apart, and which clock it counts on. The card's Timing foldout, as a row.",
		[["label", "String", "The label of the card being retimed."],
			["delay", "float", "How long the card waits after the head reaches it, in seconds."],
			["repeat", "int", "How many times it is felt. 1 is once."],
			["interval", "float", "The gap between repeats, in seconds."],
			["clock", "String", "Which clock it counts on: game time slows with a slowmo, real time never does."]],
		"var card: Dictionary = _edited(label, \"Set Feedback Timing\")\nif card.is_empty():\n\treturn\ncard[\"delay\"] = maxf(delay, 0.0)\ncard[\"repeat\"] = maxi(repeat, 1)\ncard[\"interval\"] = maxf(interval, 0.0)\ncard[\"clock\"] = clock")
	_default(sheet, "label", "shake")
	_default(sheet, "delay", "0.0")
	_default(sheet, "repeat", "1")
	_default(sheet, "interval", "0.0")
	_param_options(sheet, "clock", ["game", "real"])
	_default(sheet, "clock", "game")
	_quoted_call(sheet, "set_feedback_timing(\"{label}\", {delay}, {repeat}, {interval}, \"{clock}\")")
	Lib.append_function(sheet, "set_feedback_chance", "Set Feedback Chance", "Feedback Player",
		"How often one card is felt at all, as a percentage. 100 is every time, 25 is a quarter of the hits - the cheapest variety there is.",
		[["label", "String", "The label of the card being rolled for."],
			["percent", "float", "The chance it is felt, 0 to 100."]],
		"var card: Dictionary = _edited(label, \"Set Feedback Chance\")\nif not card.is_empty():\n\tcard[\"chance\"] = clampf(percent, 0.0, 100.0)")
	_default(sheet, "label", "shake")
	_default(sheet, "percent", "100.0")
	_quoted_call(sheet, "set_feedback_chance(\"{label}\", {percent})")
	Lib.append_function(sheet, "set_feedback_label", "Set Feedback Label", "Feedback Player",
		"Renames one card. Every other row addresses cards by this name, so renaming one is renaming what the rest of the sheet has to say.",
		[["label", "String", "The card's name now."],
			["new_label", "String", "What it is called from here on."]],
		"var card: Dictionary = _edited(label, \"Set Feedback Label\")\nif not card.is_empty():\n\tcard[\"label\"] = new_label")
	_default(sheet, "label", "shake")
	_default(sheet, "new_label", "big shake")
	_quoted_call(sheet, "set_feedback_label(\"{label}\", \"{new_label}\")")
	Lib.append_function(sheet, "duplicate_feedback", "Duplicate Feedback", "Feedback Player",
		"Copies one card and puts the copy straight under it, under a name of its own. Two shakes a frame apart out of one tuned card.",
		[["label", "String", "The label of the card to copy."],
			["new_label", "String", "What the copy is called. Empty names it after the original."]],
		"var list: Array = _own_list()\nvar at: int = _index_in(list, label)\nif at < 0:\n\t_no_such(label, \"Duplicate Feedback\")\n\treturn\nvar copy: Dictionary = (list[at] as Dictionary).duplicate(true)\ncopy[\"label\"] = new_label if not new_label.strip_edges().is_empty() else _label_of(copy) + \" copy\"\nlist.insert(at + 1, copy)")
	_default(sheet, "label", "shake")
	_default(sheet, "new_label", "")
	_quoted_call(sheet, "duplicate_feedback(\"{label}\", \"{new_label}\")")
	Lib.append_function(sheet, "clear_feedbacks", "Clear Feedbacks", "Feedback Player",
		"Empties the list. What a player that is about to be handed a whole beat by Copy Feedbacks From or Load Moment File wants first.",
		[], "steps.clear()\nmoment_file = null")
	Lib.append_function(sheet, "copy_feedbacks_from", "Copy Feedbacks From", "Feedback Player",
		"Takes another player's whole list and makes it this one's - a copy, so retuning either afterwards leaves the other alone. One tuned enemy hit, given to every enemy that spawns.",
		[["other", "Node", "The Feedback Player to copy the list off."]],
		"if other == null:\n\treturn\nvar carried: Variant = other.get(\"steps\")\nif not (carried is Array):\n\tpush_warning(\"Feedback Player: %s is not a Feedback Player, so Copy Feedbacks From did nothing.\" % other.name)\n\treturn\nvar list: Array = _own_list()\nlist.clear()\nfor entry: Variant in carried as Array:\n\tif entry is Dictionary:\n\t\tlist.append((entry as Dictionary).duplicate(true))")
	Lib.append_function(sheet, "load_moment_file", "Load Moment File", "Feedback Player",
		"Brings a moment file's beat INTO this player's list, as a copy - so it can be retuned by rows afterwards without ever writing to the file two other objects may be playing.",
		[["path", "String", "The moment file to read, as its res:// path."]],
		"if not ResourceLoader.exists(path):\n\tpush_warning(\"Feedback Player: there is no moment file at \\\"%s\\\", so Load Moment File did nothing.\" % path)\n\treturn\nvar file: Resource = load(path)\nif file == null or not (file.get(\"steps\") is Array):\n\tpush_warning(\"Feedback Player: \\\"%s\\\" is not a moment file, so Load Moment File did nothing.\" % path)\n\treturn\nmoment_file = file\n_own_list()")
	_default(sheet, "path", "res://eventsheet_addons/juice/impact.tres")
	_quoted_call(sheet, "load_moment_file(\"{path}\")")
	Lib.append_function(sheet, "save_moment_file", "Save Moment File", "Feedback Player",
		"Writes this list out as a moment file, so a beat tuned while the game ran can be shared, shipped or loaded back. Only the four keys a file holds are written: a card that is switched off, and the timing words a list adds, are named in a warning and left out.",
		[["path", "String", "Where to write it. At run time that is a user:// path, which is the only place a game may write."]],
		"var kind: Script = load(\"res://eventsheet_addons/moment_resource/moment_resource.gd\") as Script\nif kind == null:\n\tpush_warning(\"Feedback Player: this project has no moment file script, so Save Moment File did nothing.\")\n\treturn\nvar written: Array[Dictionary] = []\nvar left_behind: PackedStringArray = PackedStringArray()\nfor entry: Variant in _steps_now():\n\tif not (entry is Dictionary):\n\t\tcontinue\n\tvar card: Dictionary = entry as Dictionary\n\tif not bool(card.get(\"active\", true)) or _is_timing(str(card.get(\"verb\", \"\"))):\n\t\tleft_behind.append(_label_of(card))\n\t\tcontinue\n\twritten.append({\"verb\": str(card.get(\"verb\", \"\")), \"amount\": float(card.get(\"amount\", 1.0)), \"effect\": str(card.get(\"effect\", \"\")), \"seconds\": float(card.get(\"seconds\", 0.0))})\nvar file: Resource = kind.new()\nfile.set(\"moment_name\", name)\nfile.set(\"steps\", written)\nif not left_behind.is_empty():\n\tpush_warning(\"Feedback Player: a moment file holds no timing and no card that is switched off, so these were left out of the file: %s.\" % \", \".join(left_behind))\nif ResourceSaver.save(file, path) != OK:\n\tpush_warning(\"Feedback Player: \\\"%s\\\" could not be written, so Save Moment File saved nothing.\" % path)")
	_default(sheet, "path", "user://my_moment.tres")
	_quoted_call(sheet, "save_moment_file(\"{path}\")")
	Lib.append_function(sheet, "set_player_strength", "Set Player Strength", "Feedback Player",
		"Turns this whole player up or down without retuning a single card - the object's own volume knob, on top of the strength the play row asks for.",
		[["value", "float", "What every amount in the list is scaled by. 1 is the list as tuned."]],
		"strength = maxf(value, 0.0)")
	_default(sheet, "value", "1.0")
	Lib.append_function(sheet, "set_player_cooldown", "Set Player Cooldown", "Feedback Player",
		"The shortest gap between two plays, in seconds. A play asked for sooner is refused, which is how a rapid-fire hit stops stacking its own feedback.",
		[["seconds", "float", "The gap. 0 lets every play through."]],
		"cooldown = maxf(seconds, 0.0)")
	_default(sheet, "seconds", "0.1")
	Lib.append_function(sheet, "set_can_play_while_playing", "Set Can Play While Playing", "Feedback Player",
		"What a second play does while the first is still running: start again from the top, be ignored, or run alongside it.",
		[["answer", "String", "Restart, ignore, or overlap."]],
		"while_playing = answer")
	_param_options(sheet, "answer", ["restart", "ignore", "overlap"])
	_default(sheet, "answer", "restart")
	_quoted_call(sheet, "set_can_play_while_playing(\"{answer}\")")
	Lib.append_function(sheet, "mute_feedback_category", "Mute Feedback Category", "Feedback Player",
		"Silences a whole family of cards at once - every screen effect, every camera move, every sound - and lets them back with the same row. THE accessibility option: one row per switch on the settings screen, and no card has to be found and unticked.",
		[["category", "String", "The family to silence."],
			["muted", "bool", "On silences it; off lets it be felt again."]],
		"var family: String = category.strip_edges().to_lower()\nif family.is_empty():\n\treturn\nif muted:\n\t_muted[family] = true\nelse:\n\t_muted.erase(family)")
	_param_options(sheet, "category", ["audio", "transform", "camera", "screen", "pause", "loop", "signal"])
	_default(sheet, "category", "screen")
	_default(sheet, "muted", "true")
	_quoted_call(sheet, "mute_feedback_category(\"{category}\", {muted})")
	Lib.append_function(sheet, "mute_category_on_channel", "Mute Feedback Category On Channel", "Feedback Player",
		"The same switch, thrown for every Feedback Player in a group at once - which is what a settings screen wants, because the option is about the game rather than about one object.",
		[["channel", "String", "The group every player the switch reaches is in."],
			["category", "String", "The family to silence."],
			["muted", "bool", "On silences it; off lets it be felt again."]],
		"if channel.strip_edges().is_empty() or not is_inside_tree():\n\treturn\nget_tree().call_group(channel, \"mute_feedback_category\", category, muted)")
	_default(sheet, "channel", "feedback")
	_param_options(sheet, "category", ["audio", "transform", "camera", "screen", "pause", "loop", "signal"])
	_default(sheet, "category", "screen")
	_default(sheet, "muted", "true")
	_quoted_call(sheet, "mute_category_on_channel(\"{channel}\", \"{category}\", {muted})")
	Lib.append_function(sheet, "scale_feedback_amounts", "Scale Feedback Amounts", "Feedback Player",
		"Multiplies how much every card in a family does - the effect-strength slider on a settings screen, where half is still the same beat and not a shorter one. Leave the family empty to move the whole list.",
		[["category", "String", "The family to scale, or empty for every card."],
			["factor", "float", "What each amount is multiplied by. 0.5 is half as much."]],
		"var family: String = category.strip_edges().to_lower()\nfor entry: Variant in _own_list():\n\tif not (entry is Dictionary):\n\t\tcontinue\n\tvar card: Dictionary = entry as Dictionary\n\tif family.is_empty() or _category_of(card) == family:\n\t\tcard[\"amount\"] = float(card.get(\"amount\", 1.0)) * factor")
	_param_options(sheet, "category", ["", "audio", "transform", "camera", "screen", "pause", "loop", "signal"])
	_default(sheet, "category", "")
	_default(sheet, "factor", "0.5")
	_quoted_call(sheet, "scale_feedback_amounts(\"{category}\", {factor})")
	Lib.append_function(sheet, "retime_feedbacks", "Retime Feedbacks", "Feedback Player",
		"Stretches or squeezes the whole beat in time: every length, every wait and every gap multiplied by the same number. Half makes a snappier version of a beat nobody has to retune card by card.",
		[["factor", "float", "What every length is multiplied by. 0.5 is twice as fast."]],
		"var scale: float = maxf(factor, 0.0)\nfor entry: Variant in _own_list():\n\tif not (entry is Dictionary):\n\t\tcontinue\n\tvar card: Dictionary = entry as Dictionary\n\tfor key: String in [\"seconds\", \"delay\", \"interval\"]:\n\t\tif card.has(key):\n\t\t\tcard[key] = float(card[key]) * scale")
	_default(sheet, "factor", "0.5")
	Lib.append_function(sheet, "shuffle_feedbacks_between", "Shuffle Feedbacks Between", "Feedback Player",
		"Reorders the stretch of the list between two cards, both included, at random. The cheapest variety a repeated hit can have: the same feedbacks, in a different order every time.",
		[["first_label", "String", "One end of the stretch."],
			["last_label", "String", "The other end."]],
		"var list: Array = _own_list()\nvar from: int = _index_in(list, first_label)\nvar to: int = _index_in(list, last_label)\nif from < 0 or to < 0:\n\t_no_such(first_label if from < 0 else last_label, \"Shuffle Feedbacks Between\")\n\treturn\nif to < from:\n\tvar swapped: int = from\n\tfrom = to\n\tto = swapped\nvar stretch: Array = list.slice(from, to + 1)\nstretch.shuffle()\nfor offset: int in range(stretch.size()):\n\tlist[from + offset] = stretch[offset]")
	_default(sheet, "first_label", "shake_a")
	_default(sheet, "last_label", "shake_c")
	_quoted_call(sheet, "shuffle_feedbacks_between(\"{first_label}\", \"{last_label}\")")
	Lib.append_function(sheet, "pick_one_feedback_of", "Pick One Feedback Of", "Feedback Player",
		"Ticks exactly one of the cards whose label starts with what you type and unticks the rest, so shake_a, shake_b and shake_c become one shake chosen fresh each time. Variety out of the list itself, with no branch in the sheet.",
		[["prefix", "String", "The start of the labels to choose between."]],
		"var wanted: String = prefix.strip_edges()\nif wanted.is_empty():\n\treturn\nvar matches: Array = []\nfor entry: Variant in _own_list():\n\tif entry is Dictionary and _label_of(entry as Dictionary).begins_with(wanted):\n\t\tmatches.append(entry)\nif matches.is_empty():\n\t_no_such(wanted, \"Pick One Feedback Of\")\n\treturn\nvar chosen: int = randi() % matches.size()\nfor index: int in range(matches.size()):\n\t(matches[index] as Dictionary)[\"active\"] = index == chosen")
	_default(sheet, "prefix", "shake_")
	_quoted_call(sheet, "pick_one_feedback_of(\"{prefix}\")")
	Lib.append_function(sheet, "jump_to_feedback", "Jump To Feedback", "Feedback Player",
		"Moves the head of a RUNNING play to the card you name, so the rest of the beat starts there. What a hit that interrupts its own wind-up wants.",
		[["label", "String", "The label of the card to carry on from."]],
		"_jump_to = label.strip_edges()")
	_default(sheet, "label", "impact")
	_quoted_call(sheet, "jump_to_feedback(\"{label}\")")
	Lib.append_function(sheet, "skip_feedback_once", "Skip Feedback Once", "Feedback Player",
		"Steps over one card the NEXT time the play reaches it, and then forgets about it. The one-off exception a disable would have to be undone after.",
		[["label", "String", "The label of the card to step over once."]],
		"if _index_of(label) < 0:\n\t_no_such(label, \"Skip Feedback Once\")\n\treturn\n_skip_once[label.strip_edges()] = true")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "skip_feedback_once(\"{label}\")")
	Lib.append_function(sheet, "set_loop_count", "Set Loop Count", "Feedback Player",
		"How many times a Loop Back card sends the head round. A charge that gets longer the further it is held, without a second list.",
		[["label", "String", "The label of the Loop Back card."],
			["loops", "int", "How many times round. 0 walks straight past it."]],
		"var card: Dictionary = _edited(label, \"Set Loop Count\")\nif card.is_empty():\n\treturn\ncard[\"loops\"] = maxi(loops, 0)\ncard[\"loops_left\"] = maxi(loops, 0)")
	_default(sheet, "label", "loop_back")
	_default(sheet, "loops", "2")
	_quoted_call(sheet, "set_loop_count(\"{label}\", {loops})")
	Lib.append_function(sheet, "hold_here", "Hold Here", "Feedback Player",
		"Stops the head where it is and leaves it there - a charge held, a beat waiting on the player. Release Hold carries on from the same card, and nothing ticks while it waits.",
		[], "_held = playing")
	Lib.append_function(sheet, "release_hold", "Release Hold", "Feedback Player",
		"Lets a held play carry on from the card it stopped on.",
		[], "_held = false\n_resumed.emit()")


## The rows that ASK rather than do: whether a card is playing, how many there are, what one of them
## says. Every one of them addresses a card by the same label the edit rows use - and by the same
## SPELLING of that label, which is why each of them writes its call out with the quotes in it. A
## card's label is a word a designer picked off the Inspector's list, not an expression: `shake` in
## the box has to reach the game as `has_feedback("shake")`, exactly as Remove Feedback and every
## other editing row already spells the same address.
static func _asking_verbs(sheet: EventSheetResource) -> void:
	_asked_condition(sheet, "feedback_is_playing", "Feedback Is Playing", "Feedback Player",
		"True while the head is on that card - the moment the hit is being felt rather than the whole beat around it.",
		[["label", "String", "The label of the card being asked about."]],
		"return playing and now_playing == label.strip_edges()")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "feedback_is_playing(\"{label}\")")
	_asked_condition(sheet, "has_feedback", "Has Feedback", "Feedback Player",
		"True when this player's list holds a card by that name. The question a row asks before it retunes one, and the one a Doctor finding is about.",
		[["label", "String", "The label to look for."]],
		"return _index_of(label) >= 0")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "has_feedback(\"{label}\")")
	_asked_condition(sheet, "feedback_is_enabled", "Feedback Is Enabled", "Feedback Player",
		"True when that card's box is ticked - so a settings screen can show the switch the way the list actually has it.",
		[["label", "String", "The label of the card being asked about."]],
		"var at: int = _index_of(label)\nreturn at >= 0 and bool((_steps_now()[at] as Dictionary).get(\"active\", true))")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "feedback_is_enabled(\"{label}\")")
	_asked_value(sheet, "feedback_count", "Feedback Count", "Feedback Player",
		"How many cards this player's list holds, ticked or not - the number the head of the Inspector shows.",
		[], "return _steps_now().size()", TYPE_INT)
	_asked_value(sheet, "feedback_label_at", "Feedback Label At", "Feedback Player",
		"The name of the card at a place in the list, so a settings screen can list a beat without knowing what is in it. The first card is 1; a number past the end answers with nothing.",
		[["position", "int", "Which card. The first in the list is 1."]],
		"var list: Array = _steps_now()\nvar at: int = position - 1\nif at < 0 or at >= list.size() or not (list[at] is Dictionary):\n\treturn \"\"\nreturn _label_of(list[at] as Dictionary)", TYPE_STRING)
	_default(sheet, "position", "1")
	_asked_value(sheet, "feedback_field", "Feedback Field", "Feedback Player",
		"What one card says at one of its fields - the amount it does, how long it lasts, the extra word it carries. The read half of Set Feedback Field, so a slider can be shown at the value the list actually holds.",
		[["label", "String", "The label of the card being read."],
			["field", "String", "Which value to read."]],
		"return _card_named(label).get(field, null)", TYPE_MAX)
	_default(sheet, "label", "shake")
	_param_options(sheet, "field", ["amount", "effect", "seconds", "delay", "interval", "repeat", "chance", "loops"])
	_default(sheet, "field", "amount")
	_quoted_call(sheet, "feedback_field(\"{label}\", \"{field}\")")
	_asked_value(sheet, "feedback_progress", "Feedback Progress", "Feedback Player",
		"How far through one card the play is, 0 before it starts and 1 once it is done. Read off the plan rather than off a tick, so asking it costs nothing.",
		[["label", "String", "The label of the card being watched."]],
		"return _progress_of(label)", TYPE_FLOAT)
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "feedback_progress(\"{label}\")")
	_asked_value(sheet, "feedback_duration", "Feedback Duration", "Feedback Player",
		"How long ONE card lasts, its own wait included - beside Feedbacks Duration, which is how long the whole beat lasts.",
		[["label", "String", "The label of the card being measured."]],
		"var card: Dictionary = _card_named(label)\nreturn maxf(float(card.get(\"seconds\", 0.0)), 0.0) + maxf(float(card.get(\"delay\", 0.0)), 0.0)", TYPE_FLOAT)
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "feedback_duration(\"{label}\")")
	_asked_value(sheet, "current_feedback", "Current Feedback", "Feedback Player",
		"The label of the card the head is on right now, or nothing when no play is running.",
		[], "return now_playing", TYPE_STRING)
	_asked_value(sheet, "loops_left", "Loops Left", "Feedback Player",
		"How many times round a Loop Back card still has to go in the play that is running.",
		[["label", "String", "The label of the Loop Back card."]],
		"var card: Dictionary = _card_named(label)\nreturn int(card.get(\"loops_left\", card.get(\"loops\", 0)))", TYPE_INT)
	_default(sheet, "label", "loop_back")
	_quoted_call(sheet, "loops_left(\"{label}\")")


## `Lib.condition` and `Lib.number`, with each parameter's own help carried across afterwards.
##
## Both build through `Lib.exposed_function`, which - unlike `Lib.append_function` beside it - keeps
## only a parameter's id and type and DROPS the third entry of its row, the sentence saying what the
## parameter is for. That sentence is load-bearing twice over: it is the help a picker shows under
## the box, and it is the thing the compiler needs before it writes a `## @ace_param(...)` line at
## all - so a verb whose parameters say nothing also ships no starting value, and a `_default` set on
## one would be metadata that never left this file. Carried here rather than fixed in the shared
## helper because every pack in the fleet is built through that helper, and teaching it to keep the
## sentence would re-emit all of them at once.
static func _asked_condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	Lib.condition(sheet, function_name, display_name, category, description, params, body)
	_carry_param_help(sheet, params)


## The same, for a verb that answers with a value rather than with yes or no.
static func _asked_value(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	Lib.number(sheet, function_name, display_name, category, description, params, body, ret)
	_carry_param_help(sheet, params)


## Puts the third entry of each params row - the parameter's own help - onto the verb just appended.
static func _carry_param_help(sheet: EventSheetResource, params: Array) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for param_pair: Array in params:
		if param_pair.size() < 3:
			continue
		for parameter: ACEParam in fn.params:
			if parameter.id == str(param_pair[0]):
				parameter.description = str(param_pair[2])


## Pre-fills the last-appended ACE's parameter default, so the dialog opens with a usable value.
## The value stays BARE for the same reason a dropdown key does - a word's quotes live in the call
## template, never in the value - and it reaches the shipped file as the `default:` part of that
## parameter's `## @ace_param(...)` line, which the compiler writes only for a parameter that also
## has help.
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## Offers the last-appended ACE's parameter a fixed list of words - a dropdown in the dialog rather
## than a box to spell one into. The keys stay BARE: a word's quotes belong in the call template, so
## the value the sheet stores is the word itself.
static func _param_options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed


## Names the EDITOR a parameter opens. The Feedback Player uses one: a step, which opens the very
## card the Inspector unfolds, so a feedback authored by a row and one authored in the list are the
## same dictionary spelled the same way.
static func _param_hint(sheet: EventSheetResource, param_id: String, hint: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.hint = hint


## Writes the last-appended verb's call out by hand, which is the only way a WORD parameter can
## carry its quotes: the dropdown stores `screen`, and the call has to say "screen".
static func _quoted_call(sheet: EventSheetResource, call: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	fn.codegen_template_override = "$%s.%s" % [sheet.custom_class_name, call]


## Marks the last-appended verb an AWAITING row: its call is written with `await` in front, which is
## what tells the compiler the handler around it is a coroutine and what draws the hourglass on the
## canvas. The call prefix is the pack's own class name, the same one the automatic template uses.
static func _await_call(sheet: EventSheetResource, call: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	fn.codegen_template_override = "await $%s.%s" % [sheet.custom_class_name, call]


## The whole player, as the shipped file reads it: the play's own bookkeeping, the walk down the
## list, and the private half of every verb above.
static func _player_lines() -> PackedStringArray:
	return PackedStringArray([
		"# --- The play: one list, one head, one strength ---",
		"# A play is a walk down the list, and its identity is a TOKEN. Every walk in flight holds one, and a",
		"# suspended step does nothing at all once its token has left the live list - which is how a stop, a",
		"# restart or a skip ends a coroutine without a flag per step, and how \"overlap\" runs two plays at",
		"# once without either of them ending the other.",
		"#",
		"# The card the head is on is not copied. A card carries its own live values while it runs (the loops",
		"# it has left), and those are what the remote Inspector of the running node shows.",
		"",
		"## The most steps one play may take, loops included. A Loop Back with nothing to end it would",
		"## otherwise be a play that never comes back; this is the number at which it gives up and says so.",
		"const MAX_PLAY_STEPS: int = 4096",
		"",
		"## The two directions a list is walked in, and the three answers to \"it is already playing\".",
		"const TOP_TO_BOTTOM: String = \"top to bottom\"",
		"const BOTTOM_TO_TOP: String = \"bottom to top\"",
		"const RESTART: String = \"restart\"",
		"const IGNORE: String = \"ignore\"",
		"const OVERLAP: String = \"overlap\"",
		"",
		"## The step words this node adds to the ten a moment file holds. Every other word is played by the",
		"## Juice behaviour beside it - the same call a moment file makes - so a card list and a moment file",
		"## are the same ten words plus timing.",
		"const PAUSE: String = \"pause\"",
		"const HOLD_UNTIL: String = \"hold_until\"",
		"const LOOP_START: String = \"loop_start\"",
		"const LOOP_BACK: String = \"loop_back\"",
		"const TWEEN_PROPERTY: String = \"tween_property\"",
		"const EMIT_SIGNAL: String = \"emit_signal\"",
		"const PLAY_PLAYER: String = \"play_player\"",
		"",
		"## Raised whenever a pause ends, however it ended. Private, so it is plumbing rather than vocabulary.",
		"signal _resumed",
		"",
		"## Live while the game runs - written by the play, read in the remote Inspector of the running node.",
		"var playing: bool = false",
		"var progress: float = 0.0",
		"var now_playing: String = \"\"",
		"",
		"var _live: Array[int] = []",
		"var _next_token: int = 0",
		"var _paused: bool = false",
		"var _played_once: bool = false",
		"var _last_played_at: float = -1000.0",
		"var _order: Array = []",
		"var _head: int = 0",
		"var _head_strength: float = 1.0",
		"var _restore_to: Array = []",
		"## The tweens this player started, so a Revert or a Restore can stop them before it puts a value",
		"## back. Without the handle the tween goes on writing over the restored value the very next frame,",
		"## which is a Restore that visibly does nothing.",
		"var _tweens: Array[Tween] = []",
		"",
		"## And the players this play set going through a Play Player card. A nested play obeys the outer",
		"## one: stopping, skipping or restoring the list that started it does the same to them.",
		"var _nested: Array[Node] = []",
		"",
		"var _juice_node: Node = null",
		"var _told_no_juice: bool = false",
		"",
		"## The steps this play walks: the moment file's when one is dropped on the slot, else the list.",
		"func _steps_now() -> Array:",
		"\tif moment_file != null:",
		"\t\tvar carried: Variant = moment_file.get(\"steps\")",
		"\t\tif carried is Array:",
		"\t\t\treturn carried as Array",
		"\treturn steps",
		"",
		"## Whether a walk is still the one it started as. A step that comes back after its token has left the",
		"## live list stops there, which is the whole of stopping.",
		"func _alive(token: int) -> bool:",
		"\treturn _live.has(token)",
		"",
		"## Whether a new play may start now - the cooldown and the \"can play while playing\" answer in one",
		"## place, so every door into the runner refuses for the same reasons.",
		"func _may_start() -> bool:",
		"\tvar now: float = float(Time.get_ticks_msec()) / 1000.0",
		"\tif cooldown > 0.0 and now - _last_played_at < cooldown:",
		"\t\treturn false",
		"\tif playing and while_playing == IGNORE:",
		"\t\treturn false",
		"\tif playing and while_playing == RESTART:",
		"\t\t# The interrupted walk stops where it is, and its play is CLOSED here rather than left",
		"\t\t# open: a sheet pairing On Feedbacks Started with On Feedbacks Finished must get both,",
		"\t\t# and the walk that was cut short will never reach the end that would have said so.",
		"\t\t_live.clear()",
		"\t\t_close()",
		"\t_last_played_at = now",
		"\treturn true",
		"",
		"## The longest path through a list of steps: a stretch between two holds runs at once, so it is as",
		"## long as its slowest card, and the holds and pauses add up. The Inspector head, the card badge and",
		"## the expression all read this one function, so no two of them can disagree.",
		"## @ace_hidden",
		"static func duration_of(list: Array) -> float:",
		"\tvar total: float = 0.0",
		"\tvar stretch: float = 0.0",
		"\tfor entry: Variant in list:",
		"\t\tif not (entry is Dictionary):",
		"\t\t\tcontinue",
		"\t\tvar card: Dictionary = entry as Dictionary",
		"\t\tif not bool(card.get(\"active\", true)):",
		"\t\t\tcontinue",
		"\t\tvar word: String = str(card.get(\"verb\", \"\"))",
		"\t\tvar seconds: float = maxf(float(card.get(\"seconds\", 0.0)), 0.0) + maxf(float(card.get(\"delay\", 0.0)), 0.0)",
		"\t\tif word == HOLD_UNTIL:",
		"\t\t\ttotal += stretch + seconds",
		"\t\t\tstretch = 0.0",
		"\t\telif word == PAUSE:",
		"\t\t\ttotal += seconds",
		"\t\telif word != LOOP_START and word != LOOP_BACK:",
		"\t\t\tstretch = maxf(stretch, seconds)",
		"\treturn total + stretch",
		"",
		"## Whether a word moves the head rather than being felt.",
		"static func _is_timing(word: String) -> bool:",
		"\treturn word == PAUSE or word == HOLD_UNTIL or word == LOOP_START or word == LOOP_BACK",
		"",
		"## The one walk down a list. Every door into the runner comes through here, so the direction, the",
		"## chance, the timing words and the loops are decided once.",
		"func _walk(list: Array, at_strength: float, backwards: bool) -> void:",
		"\tvar order: Array = []",
		"\tfor entry: Variant in list:",
		"\t\tif entry is Dictionary:",
		"\t\t\torder.append(entry)",
		"\tif backwards:",
		"\t\torder.reverse()",
		"\tvar token: int = _begin(order, at_strength)",
		"\tvar index: int = 0",
		"\tfor taken: int in range(MAX_PLAY_STEPS):",
		"\t\tif index >= order.size() or not _alive(token):",
		"\t\t\tbreak",
		"\t\tawait _wait_out_pause(token)",
		"\t\tif not _alive(token):",
		"\t\t\tbreak",
		"\t\t_head = index",
		"\t\tprogress = float(index) / float(maxi(order.size(), 1))",
		"\t\tindex = await _take(order, index, order[index] as Dictionary, at_strength, token)",
		"\t\tindex = _landing(order, index)",
		"\tif _alive(token) and index < order.size():",
		"\t\tpush_warning(\"Feedback Player: a loop on %s never came back, so the play was given up after %d steps.\" % [name, MAX_PLAY_STEPS])",
		"\tif _alive(token):",
		"\t\t_live.erase(token)",
		"\t\t_close()",
		"",
		"## Holds a walk while the player is paused OR held where it is. It waits on the resume signal",
		"## rather than polling, so a pause costs nothing while it lasts, ends the frame it is lifted, and",
		"## wakes for a stop as well - every door that ends a wait raises the same signal. The loop is",
		"## bounded rather than open because two doors can hold the head at once, and a resume that lifts",
		"## only one of them must go back to waiting rather than walking on.",
		"func _wait_out_pause(token: int) -> void:",
		"\tfor waited: int in range(MAX_PLAY_STEPS):",
		"\t\tif not ((_paused or _held) and _alive(token)):",
		"\t\t\treturn",
		"\t\tawait _resumed",
		"",
		"## What one card does, and where the head goes next. The timing words move the head; every other",
		"## word is a feedback, which is felt and stepped over.",
		"func _take(order: Array, index: int, card: Dictionary, at_strength: float, token: int) -> int:",
		"\tvar word: String = str(card.get(\"verb\", \"\")).strip_edges().to_lower()",
		"\tvar refused: String = _why_not(card, at_strength)",
		"\tif not refused.is_empty():",
		"\t\tif not _is_timing(word):",
		"\t\t\ton_feedback_skipped.emit(_label_of(card), refused)",
		"\t\treturn index + 1",
		"\tvar clock: String = MomentRunner.CLOCK_REAL if str(card.get(\"clock\", \"\")) == \"real\" else MomentRunner.CLOCK_GAME",
		"\tvar delay: float = maxf(float(card.get(\"delay\", 0.0)), 0.0)",
		"\tif delay > 0.0:",
		"\t\tawait MomentRunner.at(self, delay, clock)",
		"\t\tif not _alive(token):",
		"\t\t\treturn order.size()",
		"\tmatch word:",
		"\t\tPAUSE:",
		"\t\t\tawait MomentRunner.then(self, MomentRunner.seconds_of(float(card.get(\"seconds\", 0.0))), clock)",
		"\t\tHOLD_UNTIL:",
		"\t\t\ton_hold_reached.emit()",
		"\t\t\tawait MomentRunner.hold(self, _longest_above(order, index), float(card.get(\"seconds\", 0.0)), clock)",
		"\t\tLOOP_START:",
		"\t\t\tpass",
		"\t\tLOOP_BACK:",
		"\t\t\tvar back: int = _loop_target(order, index, card)",
		"\t\t\tvar left: int = int(card.get(\"loops_left\", card.get(\"loops\", 1)))",
		"\t\t\tif left > 0 and back >= 0:",
		"\t\t\t\tcard[\"loops_left\"] = left - 1",
		"\t\t\t\ton_loop.emit(left - 1)",
		"\t\t\t\tawait MomentRunner.then(self, MomentRunner.seconds_of(float(card.get(\"seconds\", 0.0))), clock)",
		"\t\t\t\treturn back",
		"\t\t\tcard[\"loops_left\"] = int(card.get(\"loops\", 1))",
		"\t\t_:",
		"\t\t\tnow_playing = str(card.get(\"label\", word))",
		"\t\t\ton_feedback_started.emit(_label_of(card))",
		"\t\t\t_do_step(card, at_strength)",
		"\t\t\tawait _repeat_rest(card, at_strength, clock, token)",
		"\t\t\ton_feedback_finished.emit(_label_of(card))",
		"\treturn index + 1",
		"",
		"## The repeats a card asks for after its first play, each one an interval apart.",
		"func _repeat_rest(card: Dictionary, at_strength: float, clock: String, token: int) -> void:",
		"\tvar repeat: int = maxi(int(card.get(\"repeat\", 1)), 1)",
		"\tvar interval: float = maxf(float(card.get(\"interval\", 0.0)), 0.0)",
		"\tfor pass_index: int in range(1, repeat):",
		"\t\tif not _alive(token):",
		"\t\t\treturn",
		"\t\tawait MomentRunner.then(self, MomentRunner.seconds_of(interval), clock)",
		"\t\tif not _alive(token):",
		"\t\t\treturn",
		"\t\t_do_step(card, at_strength)",
		"",
		"## Whether a card is felt at all: its enable box, its chance, and the strength window it asked for.",
		"func _card_runs(card: Dictionary, at_strength: float) -> bool:",
		"\treturn _why_not(card, at_strength).is_empty()",
		"",
		"## WHY a card was not felt, in one word, or \"\" when it was. The reason is what On Feedback Skipped",
		"## carries, so a row can tell a card the player muted from one the dice went against - and it is",
		"## asked once per card per play, because rolling the chance twice would be a different beat.",
		"func _why_not(card: Dictionary, at_strength: float) -> String:",
		"\tif not bool(card.get(\"active\", true)):",
		"\t\treturn \"off\"",
		"\tvar named: String = _label_of(card)",
		"\tif _skip_once.has(named):",
		"\t\t_skip_once.erase(named)",
		"\t\treturn \"skipped once\"",
		"\tif _muted.has(_category_of(card)):",
		"\t\treturn \"muted\"",
		"\tvar chance: float = float(card.get(\"chance\", 100.0))",
		"\tif chance < 100.0 and randf() * 100.0 >= chance:",
		"\t\treturn \"chance\"",
		"\tif at_strength < float(card.get(\"min_strength\", 0.0)):",
		"\t\treturn \"strength\"",
		"\tvar ceiling: float = float(card.get(\"max_strength\", 0.0))",
		"\tif ceiling > 0.0 and at_strength > ceiling:",
		"\t\treturn \"strength\"",
		"\treturn \"\"",
		"",
		"## One feedback, felt. The ten moment words go to the Juice behaviour beside this node - the same",
		"## call a moment file makes - and this node's own words are done here.",
		"func _do_step(card: Dictionary, at_strength: float) -> void:",
		"\tvar word: String = str(card.get(\"verb\", \"\")).strip_edges().to_lower()",
		"\tvar amount: float = float(card.get(\"amount\", 1.0))",
		"\tvar effect: String = str(card.get(\"effect\", \"\"))",
		"\tvar seconds: float = maxf(float(card.get(\"seconds\", 0.0)), 0.0)",
		"\t# The player's own strength scales EVERY kind of card, not only the felt ones: a whole",
		"\t# object's feedback turned down has to turn down the tween that moves it too.",
		"\tvar at: float = at_strength * maxf(strength, 0.0)",
		"\tmatch word:",
		"\t\tTWEEN_PROPERTY:",
		"\t\t\t_tween_property(effect, MomentRunner.scaled(amount, at), MomentRunner.seconds_of(seconds))",
		"\t\tEMIT_SIGNAL:",
		"\t\t\ton_feedback_signal.emit(effect)",
		"\t\tPLAY_PLAYER:",
		"\t\t\tvar other: Node = get_node_or_null(NodePath(effect))",
		"\t\t\tif other != null and other.has_method(\"play\"):",
		"\t\t\t\tif not _nested.has(other):",
		"\t\t\t\t\t_nested.append(other)",
		"\t\t\t\tother.call(\"play\", at * maxf(amount, 0.0))",
		"\t\t_:",
		"\t\t\tvar juice: Node = _juice()",
		"\t\t\tif juice != null:",
		"\t\t\t\tjuice.call(\"moment_step\", word, amount, effect, seconds, at)",
		"",
		"## What a broadcast on a channel arrives as. A NAME OF THIS PACK'S OWN, never the bare word play:",
		"## an audio, video or animation player in the same group answers to that one too, and call_group",
		"## swallows the error - so a channel meant for feedback would quietly start somebody's music.",
		"func play_feedbacks_from_channel(at_strength: float) -> void:",
		"\tplay(at_strength)",
		"",
		"## Everything this play set going through a Play Player card, told the same thing the outer list was",
		"## just told. A nested play is part of the beat around it: stopping, skipping or restoring the list",
		"## that started it has to reach the ones it started, or half the beat carries on alone.",
		"func _told_nested(what: String) -> void:",
		"\tfor other: Node in _nested:",
		"\t\tif is_instance_valid(other) and other.has_method(what):",
		"\t\t\tother.call(what)",
		"\tif what != \"restore\":",
		"\t\t_nested.clear()",
		"",
		"## The tweens this player started, stopped and forgotten. A value put back while the tween that moved",
		"## it is still running is written over on the very next frame, so a Restore stops them first.",
		"func _stop_tweens() -> void:",
		"\tfor walked: Tween in _tweens:",
		"\t\tif is_instance_valid(walked):",
		"\t\t\twalked.kill()",
		"\t_tweens.clear()",
		"",
		"## A property on the host walked to a value, with what it was written down first so Restore can put",
		"## it back. The walk is the engine's own tween, so nothing ticks while nothing is playing.",
		"func _tween_property(property: String, value: float, seconds: float) -> void:",
		"\tif host == null or property.strip_edges().is_empty():",
		"\t\treturn",
		"\tvar before: Variant = host.get(property)",
		"\tif before == null:",
		"\t\tpush_warning(\"Feedback Player: %s has no property called \\\"%s\\\", so that step did nothing.\" % [host.name, property])",
		"\t\treturn",
		"\t_restore_to.append({\"object\": host, \"property\": property, \"value\": before})",
		"\tif seconds <= 0.0:",
		"\t\thost.set(property, value)",
		"\t\treturn",
		"\t# The handle is KEPT: a Restore that only writes the value back is written over again by this",
		"\t# very tween on the next frame. Restoring stops them first.",
		"\t# The ones that have finished are let go of here rather than kept for the life of the node.",
		"\tfor held: int in range(_tweens.size() - 1, -1, -1):",
		"\t\tif not is_instance_valid(_tweens[held]) or not _tweens[held].is_running():",
		"\t\t\t_tweens.remove_at(held)",
		"\tvar walked: Tween = create_tween()",
		"\t_tweens.append(walked)",
		"\twalked.tween_property(host, NodePath(property), value, seconds)",
		"",
		"## The Juice behaviour beside this node - found by the step call it answers rather than by its class,",
		"## so this pack names no other pack. Said once when there is none, because a list of ten shakes with",
		"## no behaviour under it would otherwise be ten warnings a frame.",
		"func _juice() -> Node:",
		"\tif _juice_node != null and is_instance_valid(_juice_node):",
		"\t\treturn _juice_node",
		"\tvar looked: Array = []",
		"\tif host != null:",
		"\t\tlooked.append_array(host.get_children())",
		"\tlooked.append_array(get_children())",
		"\tfor child: Variant in looked:",
		"\t\tvar node: Node = child as Node",
		"\t\tif node != null and node.has_method(\"moment_step\"):",
		"\t\t\t_juice_node = node",
		"\t\t\treturn _juice_node",
		"\tif not _told_no_juice:",
		"\t\t_told_no_juice = true",
		"\t\tpush_warning(\"Feedback Player: %s has no Juice behaviour beside it, so its shake, flash and hitstop steps did nothing. Add a Juice node under the same object.\" % name)",
		"\treturn null",
		"",
		"## How much of the slowest step above is still to run when a Hold is reached - the number the hold",
		"## word waits for. Read back over the cards between this hold and the one above it.",
		"func _longest_above(order: Array, index: int) -> float:",
		"\tvar longest: float = 0.0",
		"\t# A card's delay is waited out by the walk itself, so by the time the Hold is reached the",
		"\t# cards above it have already been running for the sum of the delays under them. What is",
		"\t# LEFT of each one is its length less that, which is what the head of the list draws.",
		"\tvar spent: float = 0.0",
		"\tvar walk: int = index - 1",
		"\twhile walk >= 0:",
		"\t\tvar card: Dictionary = order[walk] as Dictionary",
		"\t\tvar word: String = str(card.get(\"verb\", \"\"))",
		"\t\tif word == HOLD_UNTIL:",
		"\t\t\tbreak",
		"\t\tif bool(card.get(\"active\", true)):",
		"\t\t\tvar delay: float = maxf(float(card.get(\"delay\", 0.0)), 0.0)",
		"\t\t\tvar seconds: float = maxf(float(card.get(\"seconds\", 0.0)), 0.0)",
		"\t\t\tif word == PAUSE:",
		"\t\t\t\tspent += delay + seconds",
		"\t\t\telse:",
		"\t\t\t\tif word != LOOP_START and word != LOOP_BACK:",
		"\t\t\t\t\tlongest = maxf(longest, seconds - spent)",
		"\t\t\t\tspent += delay",
		"\t\twalk -= 1",
		"\treturn maxf(longest, 0.0)",
		"",
		"## Where a Loop Back sends the head: the nearest Hold or Loop Start above it that the card is willing",
		"## to land on. -1 when there is none, which makes the loop a step that does nothing.",
		"func _loop_target(order: Array, index: int, card: Dictionary) -> int:",
		"\tvar to_hold: bool = bool(card.get(\"to_hold\", true))",
		"\tvar to_start: bool = bool(card.get(\"to_loop_start\", true))",
		"\tvar walk: int = index - 1",
		"\twhile walk >= 0:",
		"\t\tvar word: String = str((order[walk] as Dictionary).get(\"verb\", \"\"))",
		"\t\tif to_hold and word == HOLD_UNTIL:",
		"\t\t\treturn walk + 1",
		"\t\tif to_start and word == LOOP_START:",
		"\t\t\treturn walk + 1",
		"\t\twalk -= 1",
		"\treturn -1",
		"",
		"## The bookkeeping every play opens with: a token of its own, the live values seeded, the head at the",
		"## top and the started signal out.",
		"func _begin(order: Array, at_strength: float) -> int:",
		"\t_next_token += 1",
		"\t_live.append(_next_token)",
		"\tplaying = true",
		"\t_played_once = true",
		"\t_paused = false",
		"\t_held = false",
		"\t_jump_to = \"\"",
		"\tprogress = 0.0",
		"\t_started_at = float(Time.get_ticks_msec()) / 1000.0",
		"\t_order = order",
		"\t_head = 0",
		"\t_head_strength = at_strength",
		"\t_nested.clear()",
		"\tfor entry: Variant in order:",
		"\t\tif entry is Dictionary:",
		"\t\t\t(entry as Dictionary)[\"loops_left\"] = int((entry as Dictionary).get(\"loops\", 1))",
		"\ton_feedbacks_started.emit(at_strength)",
		"\treturn _next_token",
		"",
		"## And the bookkeeping the last walk out closes with.",
		"func _close() -> void:",
		"\tif not _live.is_empty():",
		"\t\treturn",
		"\tplaying = false",
		"\t_paused = false",
		"\t_held = false",
		"\tprogress = 1.0",
		"\tnow_playing = \"\"",
		"\ton_feedbacks_finished.emit()",
		"",
		"## When each card of a list starts and how long it lasts: [{card, at, seconds}], in list order. A",
		"## stretch between two holds starts together, a Pause pushes everything under it along, and the",
		"## loops are left out because a plan is what one pass looks like. The Inspector's timeline and the",
		"## editor preview both read this, so the picture and the sample can never disagree.",
		"## @ace_hidden",
		"static func schedule_of(list: Array) -> Array:",
		"\tvar plan: Array = []",
		"\tvar at: float = 0.0",
		"\tvar stretch: float = 0.0",
		"\tfor entry: Variant in list:",
		"\t\tif not (entry is Dictionary):",
		"\t\t\tcontinue",
		"\t\tvar card: Dictionary = entry as Dictionary",
		"\t\tif not bool(card.get(\"active\", true)):",
		"\t\t\tcontinue",
		"\t\tvar word: String = str(card.get(\"verb\", \"\"))",
		"\t\tvar delay: float = maxf(float(card.get(\"delay\", 0.0)), 0.0)",
		"\t\tvar seconds: float = maxf(float(card.get(\"seconds\", 0.0)), 0.0)",
		"\t\tif word == HOLD_UNTIL:",
		"\t\t\tat += stretch + delay + seconds",
		"\t\t\tstretch = 0.0",
		"\t\t\tcontinue",
		"\t\tif word == PAUSE:",
		"\t\t\tat += delay + seconds",
		"\t\t\tcontinue",
		"\t\tif word == LOOP_START or word == LOOP_BACK:",
		"\t\t\tcontinue",
		"\t\tplan.append({\"card\": card, \"at\": at + delay, \"seconds\": seconds})",
		"\t\tstretch = maxf(stretch, delay + seconds)",
		"\treturn plan",
		"",
		"## What the object would be doing `time` into a play - the editor's look at the list, sampled rather",
		"## than run. The shape is the plugin's shared behaviour-preview contract (exported values in, the",
		"## host's rest state in, the properties to write out), so the Tools-menu preview and the Inspector's",
		"## own Play button read one function and show one picture.",
		"##",
		"## Only the three words an editor can honestly show are sampled: a shake as a wobble, a punch as a",
		"## swell, and a tweened property walking to its value. A hitstop and a flash are things a running",
		"## game does to time and to the screen, and drawing a guess at them would be worse than the gap.",
		"## @ace_hidden",
		"static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary:",
		"\tvar list: Variant = params.get(\"steps\", [])",
		"\tif not (list is Array):",
		"\t\treturn {}",
		"\tvar at_strength: float = maxf(float(params.get(\"strength\", 1.0)), 0.0)",
		"\tvar written: Dictionary = {}",
		"\tvar offset: Vector2 = Vector2.ZERO",
		"\tvar swell: float = 0.0",
		"\tfor entry: Variant in schedule_of(list as Array):",
		"\t\tvar plan: Dictionary = entry as Dictionary",
		"\t\tvar card: Dictionary = plan.get(\"card\") as Dictionary",
		"\t\tvar span: float = maxf(float(plan.get(\"seconds\", 0.0)), 0.05)",
		"\t\tvar through: float = (time - float(plan.get(\"at\", 0.0))) / span",
		"\t\tif through < 0.0 or through > 1.0:",
		"\t\t\tcontinue",
		"\t\tvar amount: float = float(card.get(\"amount\", 1.0)) * at_strength",
		"\t\tvar word: String = str(card.get(\"verb\", \"\"))",
		"\t\tif word == \"shake\":",
		"\t\t\toffset += Vector2(sin(time * 47.0), cos(time * 53.0)) * amount * 8.0 * (1.0 - through)",
		"\t\telif word == \"punch\":",
		"\t\t\tswell += amount * 0.2 * sin(through * PI)",
		"\t\telif word == TWEEN_PROPERTY:",
		"\t\t\tvar property: String = str(card.get(\"effect\", \"\"))",
		"\t\t\tif base.has(property) and (base[property] is float or base[property] is int):",
		"\t\t\t\twritten[property] = lerpf(float(base[property]), amount, through)",
		"\tif base.get(\"position\") is Vector2 and offset != Vector2.ZERO:",
		"\t\twritten[\"position\"] = (base[\"position\"] as Vector2) + offset",
		"\tif base.get(\"scale\") is Vector2 and not is_zero_approx(swell):",
		"\t\twritten[\"scale\"] = (base[\"scale\"] as Vector2) * (1.0 + swell)",
		"\treturn written"
	])


## The second half of the runtime: everything the rows that EDIT a list are built on. A list is
## edited in the Inspector by dragging cards and in the game by naming them, and the two have to
## mean the same thing - so a card's LABEL is the address, the address is resolved in exactly one
## place, and a row that names a card nobody has says so rather than doing nothing.
static func _addressing_lines() -> PackedStringArray:
	return PackedStringArray([
		"# --- Addressed by label: the rows that edit the list while the game runs ---",
		"# Every row that names one feedback names it by its LABEL - the name typed on the card in the",
		"# Inspector, or, for a card nobody named, its own word. That is the whole addressing scheme: a",
		"# list tuned in the Inspector and a list retuned by rows can never disagree about which step is",
		"# meant, and a label that is not in the list is said out loud rather than quietly ignored.",
		"",
		"## Which family a card belongs to when it does not say so itself. An OVERRIDE list: a word that is",
		"## not in it belongs to no family, so Mute Feedback Category leaves it alone, and a card carrying",
		"## its own `category` key answers with that instead of with this. It is the RUNTIME copy of the",
		"## question, and the editor's card list takes its stripe colours from here rather than keeping a",
		"## second one, so a word can only ever have one family.",
		"const CATEGORY_OF: Dictionary = {",
		"\t\"shake\": \"camera\",",
		"\t\"zoom\": \"camera\",",
		"\t\"punch\": \"transform\",",
		"\t\"flash\": \"transform\",",
		"\t\"hitstop\": \"pause\",",
		"\t\"slowmo\": \"pause\",",
		"\t\"shockwave\": \"screen\",",
		"\t\"chromatic\": \"screen\",",
		"\t\"pulse\": \"screen\",",
		"\t\"hold\": \"screen\",",
		"\t\"pause\": \"pause\",",
		"\t\"hold_until\": \"pause\",",
		"\t\"loop_start\": \"loop\",",
		"\t\"loop_back\": \"loop\",",
		"\t\"emit_signal\": \"signal\",",
		"\t\"play_player\": \"signal\"",
		"}",
		"",
		"## The keys Set Feedback Field writes and Feedback Field reads. Named rather than open, so a typo",
		"## cannot quietly add a key nothing ever looks at - the one failure a dictionary with no schema",
		"## behind it is prone to.",
		"const FIELD_KEYS: PackedStringArray = [\"amount\", \"effect\", \"seconds\", \"delay\", \"interval\", \"repeat\", \"chance\", \"loops\"]",
		"",
		"## The families muted right now, as a set. Empty in every project that never mutes one, which is",
		"## why it costs a lookup in an empty dictionary rather than a branch per card.",
		"var _muted: Dictionary = {}",
		"",
		"## The labels Skip Feedback Once has been asked about and the play has not reached yet. Each is",
		"## taken out the moment it is used, so the row means once rather than from now on.",
		"var _skip_once: Dictionary = {}",
		"",
		"## Hold Here, and the label Jump To Feedback wants the head moved to at the next step.",
		"var _held: bool = false",
		"var _jump_to: String = \"\"",
		"",
		"## When this play began, on the wall clock, so one card's own progress can be answered without a",
		"## tick running to count it.",
		"var _started_at: float = 0.0",
		"",
		"## The name one card answers to: what it was called in the list, or its own word when it was never",
		"## named. THE ONE PLACE a label is derived, so every row addresses cards identically.",
		"func _label_of(card: Dictionary) -> String:",
		"\tvar named: String = str(card.get(\"label\", \"\")).strip_edges()",
		"\treturn named if not named.is_empty() else str(card.get(\"verb\", \"\")).strip_edges()",
		"",
		"## Which family a card belongs to: its own word for it when it carries one, else the family its",
		"## word belongs to, else none at all.",
		"func _category_of(card: Dictionary) -> String:",
		"\tvar said: String = str(card.get(\"category\", \"\")).strip_edges().to_lower()",
		"\tif not said.is_empty():",
		"\t\treturn said",
		"\treturn str(CATEGORY_OF.get(str(card.get(\"verb\", \"\")).strip_edges().to_lower(), \"\"))",
		"",
		"## Where a label sits in a list, or -1 when nothing in it answers to that name.",
		"func _index_in(list: Array, label: String) -> int:",
		"\tvar wanted: String = label.strip_edges()",
		"\tif wanted.is_empty():",
		"\t\treturn -1",
		"\tfor index: int in range(list.size()):",
		"\t\tif list[index] is Dictionary and _label_of(list[index] as Dictionary) == wanted:",
		"\t\t\treturn index",
		"\treturn -1",
		"",
		"## Where a label sits in the list this player is playing.",
		"func _index_of(label: String) -> int:",
		"\treturn _index_in(_steps_now(), label)",
		"",
		"## The card a label names, or an empty one. Empty rather than null so every reader can ask it a",
		"## question without checking first, and a card that is not there answers with the defaults.",
		"func _card_named(label: String) -> Dictionary:",
		"\tvar list: Array = _steps_now()",
		"\tvar at: int = _index_in(list, label)",
		"\treturn list[at] as Dictionary if at >= 0 else {}",
		"",
		"## Said when a row names a feedback this player has not got. A warning rather than an error,",
		"## because the rest of the beat is still worth playing; in the editor the same mistake is a quiet",
		"## finding on the row itself, which is where it can actually be fixed.",
		"func _no_such(label: String, row: String) -> void:",
		"\tpush_warning(\"Feedback Player: %s has no feedback labelled \\\"%s\\\", so %s did nothing.\" % [name, label, row])",
		"",
		"## The list the EDIT rows work on: this player's own. A player whose moment-file slot is filled is",
		"## playing a beat two other objects may be playing too, and an edit row must never write into that",
		"## file - so the first edit takes a copy of it into this list and lets the slot go. The beat is",
		"## unchanged; it is simply this object's own now.",
		"func _own_list() -> Array:",
		"\tif moment_file != null:",
		"\t\tvar carried: Variant = moment_file.get(\"steps\")",
		"\t\tsteps.clear()",
		"\t\tif carried is Array:",
		"\t\t\tfor entry: Variant in carried as Array:",
		"\t\t\t\tif entry is Dictionary:",
		"\t\t\t\t\tsteps.append((entry as Dictionary).duplicate(true))",
		"\t\tmoment_file = null",
		"\treturn steps",
		"",
		"## The card a row is about to write to, taken from this player's OWN list, or an empty dictionary",
		"## when the label names nothing - with the warning already said, so no row has to say it twice.",
		"func _edited(label: String, row: String) -> Dictionary:",
		"\tvar list: Array = _own_list()",
		"\tvar at: int = _index_in(list, label)",
		"\tif at < 0:",
		"\t\t_no_such(label, row)",
		"\t\treturn {}",
		"\treturn list[at] as Dictionary",
		"",
		"## One dictionary made into a card: its own keys over the four every moment file's step holds, so",
		"## a step written by a row and one added in the Inspector are the same shape and neither has to be",
		"## converted into the other. The enable key is left ABSENT, which is what on means.",
		"func _carded(step: Dictionary) -> Dictionary:",
		"\tvar card: Dictionary = {\"verb\": \"\", \"amount\": 1.0, \"effect\": \"\", \"seconds\": 0.0}",
		"\tfor key: Variant in step:",
		"\t\tcard[key] = step[key]",
		"\treturn card",
		"",
		"## Where the head goes when Jump To Feedback has been asked for: the label's place in the order",
		"## being walked, or where the head was going anyway. Asked once per step, and it reads an empty",
		"## string in every play nobody jumped in.",
		"func _landing(order: Array, index: int) -> int:",
		"\tif _jump_to.is_empty():",
		"\t\treturn index",
		"\tvar landed: int = _index_in(order, _jump_to)",
		"\tif landed < 0:",
		"\t\t_no_such(_jump_to, \"Jump To Feedback\")",
		"\t_jump_to = \"\"",
		"\treturn landed if landed >= 0 else index",
		"",
		"## How far through ONE card the play is, 0 before it starts and 1 once it is done. Read off the",
		"## plan rather than off a tick: the schedule says when each card starts and how long it lasts and",
		"## the clock says how long this play has been going, so nothing has to run to answer it.",
		"func _progress_of(label: String) -> float:",
		"\tif not playing:",
		"\t\treturn 0.0",
		"\tvar elapsed: float = float(Time.get_ticks_msec()) / 1000.0 - _started_at",
		"\tfor entry: Variant in schedule_of(_steps_now()):",
		"\t\tvar plan: Dictionary = entry as Dictionary",
		"\t\tif _label_of(plan.get(\"card\") as Dictionary) != label.strip_edges():",
		"\t\t\tcontinue",
		"\t\tvar span: float = maxf(float(plan.get(\"seconds\", 0.0)), 0.0)",
		"\t\tif span <= 0.0:",
		"\t\t\treturn 1.0 if elapsed >= float(plan.get(\"at\", 0.0)) else 0.0",
		"\t\treturn clampf((elapsed - float(plan.get(\"at\", 0.0))) / span, 0.0, 1.0)",
		"\treturn 0.0",
		"",
		"## Every label in the list, in order - what For Each Feedback loops over, and what a settings",
		"## screen that lists a beat's parts is built out of.",
		"## @ace_looping(feedback_label)",
		"## @ace_name(\"For Each Feedback\")",
		"## @ace_category(\"Feedback Player\")",
		"## @ace_description(\"Runs the actions under it once per feedback in this player's list, top to bottom, with the label of each one in hand.\")",
		"func for_each_feedback() -> Array:",
		"\tvar labels: Array = []",
		"\tfor entry: Variant in _steps_now():",
		"\t\tif entry is Dictionary:",
		"\t\t\tlabels.append(_label_of(entry as Dictionary))",
		"\treturn labels"
	])
