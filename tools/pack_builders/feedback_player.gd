# Pack builder - feedback_player (the Juice Player: a NODE beside the Juice pack, the list of juice cards an object
# plays; the file keeps its old name; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## The Juice Player: a node you add under any object, holding the list of juice cards that object
## plays when something happens to it.
##
## THE THIRD HOME OF A MOMENT. A beat of juice can be written down three ways in this project:
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
## answers the moment-step call, found by that call rather than by a class, so the Juice Player
## compiles and runs in a project that deleted the Juice behaviour - it just has nothing to shake.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "JuicePlayer"
	sheet.addon_provider_id = "FeedbackPlayer"
	sheet.class_description = "The list of juice cards an object plays: add this node under it, fill the list with shakes, flashes, holds and loops, and one row plays the lot. A Juice node does one effect when a row asks; a Juice Player plays a list of juice cards, one after another. The list is the same shape a moment file holds, so it can be saved out and shared; the strength on the row scales every amount in it."
	sheet.addon_category = "Juice Player"
	sheet.addon_tags = PackedStringArray(["juice", "juice player", "feedback", "game feel"])
	sheet.variables = {
		"steps": {"type": "Array[Dictionary]", "default": [], "exported": true,
			"attributes": {"tooltip": "The juice cards this object plays, in order. Each one is a card: what it does, how much, how long, and the timing words between them.",
				"drawer": "cards", "cards_schema": "feedback_steps", "cards_kind_key": "verb",
				"cards_stripe_key": "category",
				"header": "Juice Player", "header_color": "#8a6fd4",
				"info": "One juice card per effect. Pause and Hold space them out, Loop Start and Loop Back repeat a stretch, and everything else is felt. Play plays the list; the strength on the row scales every amount in it. A Juice node does one effect when a row asks; a Juice Player plays a list of them."}},
		"strength": {"type": "float", "default": 1.0, "exported": true,
			"attributes": {"tooltip": "Scales every amount in the list before the row's own strength applies."}},
		"direction": {"type": "String", "default": "top to bottom", "exported": true,
			"attributes": {"tooltip": "Which end of the list a play starts from.",
				"drawer": "toggle_row", "look_line": true, "toggle_options": ["top to bottom", "bottom to top"]}},
		"while_playing": {"type": "String", "default": "restart", "exported": true,
			"attributes": {"tooltip": "What a second play does while the first is still running: restart it, ignore the new one, or let the two overlap.",
				"drawer": "toggle_row", "look_line": true, "toggle_options": ["restart", "ignore", "overlap"]}},
		"autoplay": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Plays the list once, at full strength, when this node enters the scene: a spawn pop, a pickup shimmer."}},
		"loop": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Plays the whole list again and again until Stop Juice or Set Looping ends it. A pass waits at least a frame, so a list with no time in it cannot lock the game."}},
		"loop_times": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "How many passes a loop makes before it stops by itself. 0 is until stopped.",
				"range": {"min": "0", "max": "100", "step": "1", "or_greater": true}}},
		"loop_wait": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Seconds between one pass and the next. 0 waits one frame.",
				"range": {"min": "0", "max": "10", "step": "0.01", "or_greater": true, "suffix": "s"}}},
		"cooldown": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Seconds that must pass between plays; sooner requests are refused."}},
		"moment_file": {"type": "Resource", "default": null, "exported": true,
			"attributes": {"tooltip": "A Juice list file (or an old moment file) played INSTEAD of the list. Edit it once and every player using it changes. Make Unique gives one object its own."}}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Juice Player: add this node under an object (the node was called Feedback Player before version 0.21.0), fill its list in the Inspector, and one row plays the whole beat. Cards are dragged into order, ticked off, and tuned in place; Pause and Hold space them out and Loop Back repeats a stretch. The ten shake-and-flash words are played by the Juice behaviour beside this node, so put one there too. The list is the same shape a moment file holds - drop a file on the slot to play it instead, or save the list out as one. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var started: SignalRow = SignalRow.new()
	started.signal_name = "on_feedbacks_started"
	started.params = PackedStringArray(["at_strength: float"])
	started.trigger = true
	started.ace_name = "On Juice Started"
	started.ace_category = "Juice Player"
	sheet.events.append(started)

	var finished: SignalRow = SignalRow.new()
	finished.signal_name = "on_feedbacks_finished"
	finished.params = PackedStringArray([])
	finished.trigger = true
	finished.ace_name = "On Juice Finished"
	finished.ace_category = "Juice Player"
	sheet.events.append(finished)

	var spoken: SignalRow = SignalRow.new()
	spoken.signal_name = "on_feedback_signal"
	spoken.params = PackedStringArray(["word: String"])
	spoken.trigger = true
	spoken.ace_name = "On Juice Signal"
	spoken.ace_category = "Juice Player"
	sheet.events.append(spoken)

	# The five that speak about ONE card rather than about the play: each carries the label the row
	# addresses that card by, so a trigger and an edit row name the same thing the same way.
	_trigger(sheet, "on_feedback_started", ["label: String"], "On Juice Card Started")
	_trigger(sheet, "on_feedback_finished", ["label: String"], "On Juice Card Finished")
	_trigger(sheet, "on_feedback_skipped", ["label: String", "why: String"], "On Juice Card Skipped")
	_trigger(sheet, "on_hold_reached", [], "On Hold Reached")
	_trigger(sheet, "on_loop", ["loops_left: int"], "On Loop")

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(_player_lines())
	sheet.events.append(block)

	var addressing: RawCodeRow = RawCodeRow.new()
	addressing.code = "\n".join(_addressing_lines())
	sheet.events.append(addressing)

	var world: RawCodeRow = RawCodeRow.new()
	world.code = "\n".join(_world_card_lines())
	sheet.events.append(world)

	var scene: RawCodeRow = RawCodeRow.new()
	scene.code = "\n".join(_scene_card_lines())
	sheet.events.append(scene)

	var stopping: RawCodeRow = RawCodeRow.new()
	stopping.code = "\n".join(_looping_and_stopping_lines())
	sheet.events.append(stopping)

	var typed: RawCodeRow = RawCodeRow.new()
	typed.code = "\n".join(_typed_card_lines())
	sheet.events.append(typed)

	_verbs(sheet)
	_list_verbs(sheet)
	_asking_verbs(sheet)
	Lib.verb_sentences(sheet, {
		"play": "Play juice at [b]{at_strength}[/b]",
		"play_and_wait": "Play juice at [b]{at_strength}[/b] and wait",
		"play_on_channel": "Play juice on channel [b]{channel}[/b] at [b]{at_strength}[/b]",
		"play_backwards": "Play juice backwards at [b]{at_strength}[/b]",
		"add_feedback": "Add juice card [b]{step}[/b] after [b]{after_label}[/b]",
		"insert_feedback_before": "Insert juice card [b]{step}[/b] before [b]{before_label}[/b]",
		"replace_feedback": "Replace juice card [b]{label}[/b] with [b]{step}[/b]",
		"remove_feedback": "Remove juice card [b]{label}[/b]",
		"move_feedback_to": "Move juice card [b]{label}[/b] to [b]{position}[/b]",
		"enable_feedback": "Enable juice card [b]{label}[/b]",
		"disable_feedback": "Disable juice card [b]{label}[/b]",
		"set_feedback_field": "Set juice card [b]{label}[/b] [b]{field}[/b] to [b]{value}[/b]",
		"set_feedback_timing": "Set juice card [b]{label}[/b] timing: delay [b]{delay}[/b] s, [b]{repeat}[/b] times",
		"set_feedback_chance": "Set juice card [b]{label}[/b] chance [b]{percent}[/b]%",
		"set_feedback_label": "Rename juice card [b]{label}[/b] to [b]{new_label}[/b]",
		"duplicate_feedback": "Duplicate juice card [b]{label}[/b] as [b]{new_label}[/b]",
		"copy_feedbacks_from": "Copy juice cards from [i]{other}[/i]",
		"load_moment_file": "Load moment file [b]{path}[/b]",
		"save_moment_file": "Save moment file to [b]{path}[/b]",
		"stop_all_juice_players": "Stop all juice players, restore [b]{and_restore}[/b]",
		"set_all_juice_players_enabled": "Set all juice players enabled [b]{enabled}[/b]",
		"toggle_juice_paused": "Toggle juice paused",
		"set_looping": "Set looping [b]{on}[/b]",
		"set_player_strength": "Set juice player strength [b]{value}[/b]",
		"set_player_cooldown": "Set juice player cooldown [b]{seconds}[/b] s",
		"set_can_play_while_playing": "While playing, [b]{answer}[/b]",
		"mute_feedback_category": "Mute juice family [b]{category}[/b]: [b]{muted}[/b]",
		"mute_category_on_channel": "Mute juice family [b]{category}[/b] on channel [b]{channel}[/b]: [b]{muted}[/b]",
		"scale_feedback_amounts": "Scale juice amounts [b]{category}[/b] by [b]{factor}[/b]",
		"retime_feedbacks": "Scale juice timing by [b]{factor}[/b]",
		"shuffle_feedbacks_between": "Shuffle juice cards [b]{first_label}[/b] to [b]{last_label}[/b]",
		"pick_one_feedback_of": "Pick one juice card starting with [b]{prefix}[/b]",
		"jump_to_feedback": "Jump to juice card [b]{label}[/b]",
		"skip_feedback_once": "Skip juice card [b]{label}[/b] once",
		"set_loop_count": "Set loop count [b]{label}[/b] to [b]{loops}[/b]",
		"feedback_is_playing": "Juice card [b]{label}[/b] is playing",
		"has_feedback": "Has juice card [b]{label}[/b]",
		"feedback_is_enabled": "Juice card [b]{label}[/b] is enabled"
	})
	_label_hints(sheet)
	_spell_all(sheet)
	Lib.feature_verbs(sheet, ["play", "play_and_wait", "stop"])
	if not Lib.save_pack(sheet, "res://eventsheet_addons/juice/juice_player"):
		return false
	return Lib.save_pack(_old_name_sheet(), "res://eventsheet_addons/juice/feedback_player", Lib.BEHAVIOR_ICON, false)


## Looping the whole list on the node, ending everything a play started, and stopping every player at once.
static func _looping_and_stopping_lines() -> PackedStringArray:
	return PackedStringArray([
		"# --- Looping a list, and stopping everything ---",
		"# A list that loops is walked again and again by one coroutine that waits at least a frame between",
		"# passes, so a list with nothing in it that takes time cannot lock the game. Every way a play can end",
		"# (Stop, Revert, the node leaving the scene, every player stopped at once) ends what the cards",
		"# STARTED as well as the walk: a list of instant cards has finished walking long before the shake it",
		"# began does, so ending the walk alone would end nothing.",
		"",
		"## The group every Juice Player joins by itself, so one call on the tree reaches all. Not the default channel of Play Juice On Channel.",
		"const PLAYERS_GROUP: String = \"every_juice_player\"",
		"",
		"## Whether juice plays at all, for the whole game, set by Set All Juice Players Enabled. It lives on the script, so it holds across scenes.",
		"static var _all_enabled: bool = true",
		"",
		"## True once this player has said it was asked to play while every player was switched off, so it is said once.",
		"var _told_switched_off: bool = false",
		"",
		"## Counts the plays, so a loop that was stopped or replaced can tell and end after its pass.",
		"var _loop_run: int = 0",
		"",
		"## Plays the list once, or over and over while Loop is ticked: the pass is walked, then the loop",
		"## waits Wait Between seconds (one frame at least) and walks it again, until Times passes have been",
		"## made (0 is until stopped), Loop is turned off or the play is stopped.",
		"func _play_list(at_strength: float, backwards: bool) -> void:",
		"\t_loop_run += 1",
		"\tvar mine: int = _loop_run",
		"\tvar passes: int = 0",
		"\twhile true:",
		"\t\tawait _walk(_steps_now(), at_strength, backwards)",
		"\t\tpasses += 1",
		"\t\tif not loop or mine != _loop_run or not is_inside_tree():",
		"\t\t\treturn",
		"\t\tif loop_times > 0 and passes >= loop_times:",
		"\t\t\treturn",
		"\t\tif loop_wait > 0.0:",
		"\t\t\tawait get_tree().create_timer(loop_wait).timeout",
		"\t\telse:",
		"\t\t\tawait get_tree().process_frame",
		"\t\tif mine != _loop_run or not is_inside_tree():",
		"\t\t\treturn",
		"",
		"## The name this player's values are kept under in the Juice node's book.",
		"func _key() -> String:",
		"\treturn \"juice player %d\" % get_instance_id()",
		"",
		"## Writes down what a property was, ONCE for each object and property: the first value is the one",
		"## Restore puts back, whatever the cards after it did to the property.",
		"func _keep_first(object: Object, property: String, before: Variant) -> void:",
		"\tfor entry: Variant in _restore_to:",
		"\t\tvar held: Dictionary = entry as Dictionary",
		"\t\tif held.get(\"object\") == object and str(held.get(\"property\", \"\")) == property:",
		"\t\t\treturn",
		"\t_restore_to.append({\"object\": object, \"property\": property, \"value\": before})",
		"",
		"## The Juice behaviour beside this node, without a word of complaint when there is none. A node that says it",
		"## yields to other Juice nodes (the one for a 3D view does) is played through only when no other answers, so a",
		"## scene that has both keeps playing through the one it always played through.",
		"func _juice_quiet() -> Node:",
		"\tif _juice_node != null and is_instance_valid(_juice_node) and not _yields_to_other(_juice_node):",
		"\t\treturn _juice_node",
		"\tvar yielding: Node = null",
		"\tvar looked: Array = []",
		"\tif host != null:",
		"\t\tlooked.append_array(host.get_children())",
		"\tlooked.append_array(get_children())",
		"\tfor child: Variant in looked:",
		"\t\tvar node: Node = child as Node",
		"\t\tif node != null and node.has_method(\"moment_step\"):",
		"\t\t\tif not _yields_to_other(node):",
		"\t\t\t\t_juice_node = node",
		"\t\t\t\treturn _juice_node",
		"\t\t\tif yielding == null:",
		"\t\t\t\tyielding = node",
		"\t_juice_node = yielding",
		"\treturn yielding",
		"",
		"## Whether a Juice node plays only when no other Juice node sits beside the player.",
		"static func _yields_to_other(node: Node) -> bool:",
		"\treturn node.has_method(\"yields_to_other_juice\") and bool(node.call(\"yields_to_other_juice\"))",
		"",
		"## Tells the Juice node a play is beginning, so it writes down what every value its cards will touch is",
		"## worth now (once) and what each will be worth when the cards have run their course.",
		"func _tell_juice_began(list: Array) -> void:",
		"\tvar juice: Node = _juice_quiet()",
		"\tif juice != null and juice.has_method(\"juice_player_began\"):",
		"\t\tjuice.call(\"juice_player_began\", _key(), list)",
		"",
		"## Tells the Juice node this player's cards are over: with `put_back` false every value lands where the",
		"## cards would have left it, with true it goes back to what it was before the first card. The shake, the",
		"## slowmo and the hold on the clock end either way.",
		"func _tell_juice_ended(put_back: bool) -> void:",
		"\t_end_chroma_shake()",
		"\t_end_grayscale()",
		"\tvar juice: Node = _juice_quiet()",
		"\tif juice != null and juice.has_method(\"juice_player_ended\"):",
		"\t\tjuice.call(\"juice_player_ended\", _key(), put_back)",
		"",
		"## Ends everything the cards of this player set going, whether or not the walk is still on: the tweens it",
		"## started (a value stays where it had got to), a fade on a bus, the sounds, the forces, the cards of your",
		"## own, and the effects the Juice node is holding.",
		"func _end_effects() -> void:",
		"\t_stop_tweens()",
		"\t_stop_rumble()",
		"\tfor moved: Tween in _bus_tweens:",
		"\t\tif moved != null and moved.is_valid():",
		"\t\t\tmoved.kill()",
		"\t_bus_tweens.clear()",
		"\tstop_sound(\"\", 0.0)",
		"\t_release_forces()",
		"\t_release_holds()",
		"\t_take_ways_back()",
		"\t_removals.clear()",
		"\t_told_own(\"stop\")",
		"\t_tell_juice_ended(false)",
		"",
		"## What leaving the scene does: the play ends and so does what it started, so a slowmo or a shake cannot",
		"## outlive the thing that began it. On Juice Finished is said a moment later, so a player that was only",
		"## taken out of the tree (put away in a pool) says it and one that was freed does not.",
		"func _exit_tree() -> void:",
		"\t_loop_run += 1",
		"\t_put_flares_back()",
		"\t_end_effects()",
		"\t_told_nested(\"stop\")",
		"\tif not playing:",
		"\t\treturn",
		"\t_live.clear()",
		"\t_waiting.clear()",
		"\t_resumed.emit()",
		"\tplaying = false",
		"\t_paused = false",
		"\t_held = false",
		"\tprogress = 1.0",
		"\tnow_playing = \"\"",
		"\tcall_deferred(\"emit_signal\", \"on_feedbacks_finished\")",
		"",
		"## What the scene tree tells every player in the group. A name of this pack's own, never the bare word",
		"## stop: an audio player, an animation player or a timer in the same group answers to that one too.",
		"## @ace_hidden",
		"func stop_juice_from_group(and_restore: bool) -> void:",
		"\tif and_restore:",
		"\t\trevert()",
		"\telse:",
		"\t\tstop()",
		"",
		"## Pauses, resumes or flips the player a Pause Or Resume card names, or this one when it names none.",
		"func _pause_player(card: Dictionary) -> void:",
		"\tvar other: Node = self",
		"\tif _names_a_node(card, \"player\"):",
		"\t\tother = _target(card, \"player\", false)",
		"\t\tif other == null or not other.has_method(\"toggle_juice_paused\"):",
		"\t\t\t_card_missing(card, \"points at no Juice Player\")",
		"\t\t\treturn",
		"\tmatch str(card.get(\"mode\", \"pause\")):",
		"\t\t\"resume\":",
		"\t\t\tother.call(\"resume_feedbacks\")",
		"\t\t\"toggle\":",
		"\t\t\tother.call(\"toggle_juice_paused\")",
		"\t\t_:",
		"\t\t\tother.call(\"pause_feedbacks\")",
	])


## The old name, kept at its old path and uid so scenes and scripts made before the rename keep working.
static func _old_name_sheet() -> EventSheetResource:
	var old_name: EventSheetResource = EventSheetResource.new()
	old_name.host_class = "JuicePlayer"
	old_name.custom_class_name = "FeedbackPlayer"
	old_name.class_description = "The old name of Juice Player. Kept so projects made before version 0.21.0 keep working. Use Juice Player."
	return old_name


## The verbs a sheet reads on the node: the plays, the two that ask, and the two that answer.
static func _verbs(sheet: EventSheetResource) -> void:
	Lib.append_function(sheet, "play", "Play Juice", "Juice Player",
		"Plays this node's list of juice cards and carries straight on with the rows under this one. The strength scales every amount in the list, so a light hit and a heavy one are one list at two numbers.",
		[["at_strength", "float", "Scales every amount in the list. 1 is the list as tuned, 0.5 a lighter version of the same beat."]],
		"if _may_start():\n\t_play_list(at_strength, direction == BOTTOM_TO_TOP)")
	_default(sheet, "at_strength", "1.0")
	Lib.append_function(sheet, "play_and_wait", "Play Juice And Wait", "Juice Player",
		"Plays the list and WAITS for the last card to finish - the rows under this one are what happens afterwards. Use it when the hit has to land before the death animation starts.",
		[["at_strength", "float", "Scales every amount in the list, exactly as Play Juice does."]],
		"if _may_start():\n\tawait _play_list(at_strength, direction == BOTTOM_TO_TOP)\n\tvar still: float = _ends_at - float(Time.get_ticks_msec()) / 1000.0\n\tif still > 0.0:\n\t\tawait MomentRunner.then(self, still, MomentRunner.CLOCK_REAL)")
	_default(sheet, "at_strength", "1.0")
	_await_call(sheet, "play_and_wait({at_strength})")
	Lib.append_function(sheet, "play_backwards", "Play Juice Backwards", "Juice Player",
		"Plays the list from the far end, so the last juice card is felt first. The other half of a beat that has to undo itself - a door that opened, closing.",
		[["at_strength", "float", "Scales every amount in the list, exactly as Play Juice does."]],
		"if _may_start():\n\t_play_list(at_strength, direction != BOTTOM_TO_TOP)")
	_default(sheet, "at_strength", "1.0")
	Lib.append_function(sheet, "play_on_channel", "Play Juice On Channel", "Juice Player",
		"Plays every Juice Player in a group at once, at one strength - the whole squad flinching, every button in a menu bouncing. Put the players in the group and name it here.",
		[["channel", "String", "The group every player that should feel this is in."],
			["at_strength", "float", "Scales every amount in every list it reaches."]],
		"if channel.strip_edges().is_empty() or not is_inside_tree():\n\treturn\nget_tree().call_group(channel, \"play_feedbacks_from_channel\", at_strength)")
	_default(sheet, "channel", "juice_players")
	_default(sheet, "at_strength", "1.0")
	_quoted_call(sheet, "play_on_channel(\"{channel}\", {at_strength})")
	Lib.append_function(sheet, "stop", "Stop Juice", "Juice Player",
		"Stops the play where it is and ends what its cards started, even when the list has already been walked: a shake, a slowmo, a hold on the clock, a tween part of the way, a sound, a force, a shape switched off, a light, an effect on a bus. Whatever a card held for a time is given back now; a value it was moving stays where it had got to, and Restore Initial Values puts it back. A loop stops too.",
		[], "_loop_run += 1\n_end_effects()\n_told_nested(\"stop\")\nif not playing:\n\treturn\n_live.clear()\n_waiting.clear()\n_resumed.emit()\n_close()")
	Lib.append_function(sheet, "skip_to_end", "Skip To End", "Juice Player",
		"Stops waiting and does everything that is left at once - the cutscene skip of a juice list. Every card from the head down is felt, without the pauses between them.",
		[], "if not playing:\n\treturn\n_live.clear()\n_paused = false\n_resumed.emit()\nvar left: Array = _order\nvar from: int = _head + 1 if _head_taken else _head\nvar at_strength: float = _head_strength\nvar late: Array = _waiting.values()\n_waiting.clear()\n_close()\n_end_chroma_shake()\n_told_nested(\"skip_to_end\")\nfor index: int in range(from, left.size()):\n\tif not (left[index] is Dictionary):\n\t\tcontinue\n\tvar card: Dictionary = left[index]\n\tif _card_runs(card, at_strength, index) and not _is_timing(word_of(card)):\n\t\t_do_step(card, at_strength, true)\nfor waiting: Variant in late:\n\tvar card: Dictionary = waiting as Dictionary\n\t_do_step(card, at_strength, true)")
	Lib.append_function(sheet, "restore", "Restore Initial Values", "Juice Player",
		"Puts every value this player's cards changed back to what it was before the FIRST card touched it, and ends the shake, the slowmo and the other effects the Juice node was holding for them. The undo of a list that moved the object rather than flashing it, or turned a light, a layer or a node's order.",
		[], "_stop_tweens()\n_stop_rumble()\n_restore_buses()\n_release_forces()\n_release_holds()\n_take_ways_back()\n_tell_juice_ended(true)\n_told_own(\"restore\")\n_told_nested(\"restore\")\nfor entry: Variant in _restore_to:\n\tvar card: Dictionary = entry as Dictionary\n\tvar object: Object = card.get(\"object\") as Object\n\tif object != null and is_instance_valid(object):\n\t\tobject.set(str(card.get(\"property\", \"\")), card.get(\"value\"))\n_restore_to.clear()")
	Lib.append_function(sheet, "revert", "Revert", "Juice Player",
		"Stops the play and puts back what it changed, the LAST change first - so a stack of tweens unwinds in the order it was built rather than all at once.",
		[], "stop()\n_restore_to.reverse()\nrestore()")
	Lib.append_function(sheet, "stop_all_juice_players", "Stop All Juice Players", "Juice Player",
		"Stops every Juice Player in the scene and ends what they started: sounds, shakes, a slowmo, a fade on a bus, a force. With 'and restore' every object goes back to how it was before its player first touched it. It acts on every player whichever object the row is on.",
		[["and_restore", "bool", "Put every object back the way it was, as well as stopping."]],
		"if not is_inside_tree():\n\treturn\nget_tree().call_group(PLAYERS_GROUP, \"stop_juice_from_group\", and_restore)")
	_default(sheet, "and_restore", "false")
	Lib.append_function(sheet, "set_all_juice_players_enabled", "Set All Juice Players Enabled", "Juice Player",
		"The one switch for the whole game, for a cutscene or an options menu: while it is off a Play does nothing, whichever player it is asked of. It does not stop a play that is already running; Stop All Juice Players does that.",
		[["enabled", "bool", "False switches all juice off, true switches it back on."]],
		"_all_enabled = enabled")
	_default(sheet, "enabled", "true")
	Lib.append_function(sheet, "toggle_juice_paused", "Toggle Juice Paused", "Juice Player",
		"Pauses the play if it is running and resumes it if it is paused: one row for a button, or an alarm that holds while a door is open.",
		[], "if _paused:\n\tresume_feedbacks()\nelse:\n\tpause_feedbacks()")
	Lib.append_function(sheet, "set_looping", "Set Looping", "Juice Player",
		"Turns the Loop tick on or off from a row. Turned off, the pass that is running finishes and the list stops there; use Stop Juice to end it at once. Turning it on does not start a play: play the list as usual.",
		[["on", "bool", "True loops the list when it plays, false plays it once."]],
		"loop = on")
	_default(sheet, "on", "true")
	Lib.append_function(sheet, "pause_feedbacks", "Pause Juice", "Juice Player",
		"Holds the play where it is without losing its place. Resume Juice carries on from the same card.",
		[], "_paused = playing")
	Lib.append_function(sheet, "resume_feedbacks", "Resume Juice", "Juice Player",
		"Carries on from where Pause Juice left off.",
		[], "_paused = false\n_resumed.emit()")
	Lib.condition(sheet, "is_playing", "Is Playing", "Juice Player",
		"True while a play is running - between the started and the finished trigger.",
		[], "return playing")
	Lib.condition(sheet, "has_played", "Has Played", "Juice Player",
		"True once this player has played at least once, and stays true. The \"they have seen this already\" question, with nothing to store.",
		[], "return _played_once")
	Lib.number(sheet, "feedbacks_progress", "Juice Progress", "Juice Player",
		"How far down the list the play has got, 0 at the first card and 1 when the last one is done.",
		[], "return progress", TYPE_FLOAT)
	Lib.number(sheet, "feedbacks_duration", "Juice Duration", "Juice Player",
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
	row.ace_category = "Juice Player"
	sheet.events.append(row)


## Everything the Inspector's list does, as rows: add a card, put one somewhere, take one out, tune
## one, switch one off, and the handful of things only a running game can want (mute a family,
## scale the lot, shuffle for variety, jump the head). Every one of them names a card by its LABEL.
static func _list_verbs(sheet: EventSheetResource) -> void:
	Lib.append_function(sheet, "add_feedback", "Add Juice Card", "Juice Player",
		"Adds one juice card to this player's list while the game runs - the same card the Inspector adds, with the same fields. Leave the after box empty to put it at the end, or name a card to put it straight after that one.",
		[["step", "Dictionary", "The juice card itself: pick its kind and fill the card, exactly as in the Inspector's list."],
			["after_label", "String", "The label of the card this one goes after. Empty puts it at the end of the list."]],
		"var list: Array = _own_list()\nvar at: int = list.size()\nif not after_label.strip_edges().is_empty():\n\tat = _index_in(list, after_label)\n\tif at < 0:\n\t\t_no_such(after_label, \"Add Juice Card\")\n\t\treturn\n\tat += 1\nlist.insert(at, _carded(step))")
	_param_hint(sheet, "step", "feedback_step")
	_default(sheet, "step", "{\"verb\": \"shake\", \"amount\": 0.4, \"seconds\": 0.2}")
	_default(sheet, "after_label", "")
	_quoted_call(sheet, "add_feedback({step}, \"{after_label}\")")
	Lib.append_function(sheet, "insert_feedback_before", "Insert Juice Card Before", "Juice Player",
		"Puts a juice card into the list immediately ABOVE the card you name - the other half of Add Juice Card, for a step that has to be felt before something already in the beat.",
		[["step", "Dictionary", "The juice card itself: pick its kind and fill the card, exactly as in the Inspector's list."],
			["before_label", "String", "The label of the card this one goes above."]],
		"var list: Array = _own_list()\nvar at: int = _index_in(list, before_label)\nif at < 0:\n\t_no_such(before_label, \"Insert Juice Card Before\")\n\treturn\nlist.insert(at, _carded(step))")
	_param_hint(sheet, "step", "feedback_step")
	_default(sheet, "step", "{\"verb\": \"flash\", \"amount\": 1.0, \"seconds\": 0.1}")
	_default(sheet, "before_label", "shake")
	_quoted_call(sheet, "insert_feedback_before({step}, \"{before_label}\")")
	Lib.append_function(sheet, "replace_feedback", "Replace Juice Card", "Juice Player",
		"Swaps one card in the list for another, in place. THE weapon-change row: the beat the designer tuned stays the beat, and only the kick inside it changes. The new card keeps the old one's label unless it brings its own, so every other row that names it goes on working.",
		[["label", "String", "The label of the card being swapped out."],
			["step", "Dictionary", "What takes its place: a kind and its fields, as in the Inspector's list."]],
		"var list: Array = _own_list()\nvar at: int = _index_in(list, label)\nif at < 0:\n\t_no_such(label, \"Replace Juice Card\")\n\treturn\nvar fresh: Dictionary = _carded(step)\nif str(fresh.get(\"label\", \"\")).strip_edges().is_empty():\n\tfresh[\"label\"] = _label_of(list[at] as Dictionary)\nlist[at] = fresh")
	_default(sheet, "label", "kick")
	_param_hint(sheet, "step", "feedback_step")
	_default(sheet, "step", "{\"verb\": \"punch\", \"amount\": 1.0, \"seconds\": 0.1}")
	_quoted_call(sheet, "replace_feedback(\"{label}\", {step})")
	Lib.append_function(sheet, "remove_feedback", "Remove Juice Card", "Juice Player",
		"Takes one card out of the list. What an upgrade that drops a part of a beat does, and the undo of Add Juice Card.",
		[["label", "String", "The label of the card to take out."]],
		"var list: Array = _own_list()\nvar at: int = _index_in(list, label)\nif at < 0:\n\t_no_such(label, \"Remove Juice Card\")\n\treturn\nlist.remove_at(at)")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "remove_feedback(\"{label}\")")
	Lib.append_function(sheet, "move_feedback_to", "Move Juice Card To", "Juice Player",
		"Moves one card to a place in the list - the drag handle, as a row. The first card is 1; a number past the end puts it last.",
		[["label", "String", "The label of the card to move."],
			["position", "int", "Where it lands. The first card in the list is 1."]],
		"var list: Array = _own_list()\nvar at: int = _index_in(list, label)\nif at < 0:\n\t_no_such(label, \"Move Juice Card To\")\n\treturn\nvar card: Dictionary = list[at] as Dictionary\nlist.remove_at(at)\nlist.insert(clampi(position - 1, 0, list.size()), card)")
	_default(sheet, "label", "shake")
	_default(sheet, "position", "1")
	_quoted_call(sheet, "move_feedback_to(\"{label}\", {position})")
	Lib.append_function(sheet, "enable_feedback", "Enable Juice Card", "Juice Player",
		"Ticks one card's box, so it is felt again from the next play on. The enable box in the Inspector, as a row.",
		[["label", "String", "The label of the card to switch on."]],
		"var card: Dictionary = _edited(label, \"Enable Juice Card\")\nif not card.is_empty():\n\tcard[\"active\"] = true")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "enable_feedback(\"{label}\")")
	Lib.append_function(sheet, "disable_feedback", "Disable Juice Card", "Juice Player",
		"Unticks one card's box, so the play steps over it. What an accessibility option that drops the screen shake and keeps the sound does with one row.",
		[["label", "String", "The label of the card to switch off."]],
		"var card: Dictionary = _edited(label, \"Disable Juice Card\")\nif not card.is_empty():\n\tcard[\"active\"] = false")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "disable_feedback(\"{label}\")")
	Lib.append_function(sheet, "set_feedback_field", "Set Juice Card Field", "Juice Player",
		"Retunes ONE value on one card: how much, how long, which extra word. The number box in the Inspector, as a row, so a weapon or a difficulty can move an amount without a second list.",
		[["label", "String", "The label of the card being tuned."],
			["field", "String", "Which value on the card to write."],
			["value", "Variant", "What to write. A number for an amount or a length, a word for the extra one."]],
		"var card: Dictionary = _edited(label, \"Set Juice Card Field\")\nif card.is_empty():\n\treturn\nif field == \"verb\" or field == \"card_script\":\n\tpush_warning(\"Juice Player: the card \\\"%s\\\" on %s cannot have its %s changed, because that is what makes it the card it is, so Set Juice Card Field left it alone. Replace the card instead.\" % [label, name, field])\n\treturn\nif not FIELD_KEYS.has(field) and not TIMING_FIELD_KEYS.has(field) and not card.has(field):\n\tpush_warning(\"Juice Player: the card \\\"%s\\\" on %s has no field called \\\"%s\\\", so Set Juice Card Field did nothing.\" % [label, name, field])\n\treturn\ncard[field] = value")
	_default(sheet, "label", "shake")
	_param_options(sheet, "field", ["amount", "effect", "seconds", "delay", "interval", "repeat", "chance", "loops", "clock", "min_strength", "max_strength"])
	_param_autocomplete(sheet, "field", ["amount", "effect", "seconds", "delay", "interval", "repeat", "chance", "loops", "clock", "min_strength", "max_strength"])
	_param_hint(sheet, "field", "juice_card_field")
	_default(sheet, "field", "amount")
	_default(sheet, "value", "1.0")
	_param_hint(sheet, "value", "juice_card_value")
	_quoted_call(sheet, "set_feedback_field(\"{label}\", \"{field}\", {value})")
	Lib.append_function(sheet, "set_feedback_timing", "Set Juice Card Timing", "Juice Player",
		"Moves one card in time: how long it waits first, how many times it repeats and how far apart, and which clock it counts on. The card's Timing foldout, as a row.",
		[["label", "String", "The label of the card being retimed."],
			["delay", "float", "How long the card waits after the head reaches it, in seconds."],
			["repeat", "int", "How many times it is felt. 1 is once."],
			["interval", "float", "The gap between repeats, in seconds."],
			["clock", "String", "Which clock it counts on: game time slows with a slowmo, real time never does."]],
		"var card: Dictionary = _edited(label, \"Set Juice Card Timing\")\nif card.is_empty():\n\treturn\ncard[\"delay\"] = maxf(delay, 0.0)\ncard[\"repeat\"] = maxi(repeat, 1)\ncard[\"interval\"] = maxf(interval, 0.0)\ncard[\"clock\"] = clock")
	_default(sheet, "label", "shake")
	_default(sheet, "delay", "0.0")
	_default(sheet, "repeat", "1")
	_default(sheet, "interval", "0.0")
	_param_options(sheet, "clock", ["game", "real"])
	_default(sheet, "clock", "game")
	_quoted_call(sheet, "set_feedback_timing(\"{label}\", {delay}, {repeat}, {interval}, \"{clock}\")")
	Lib.append_function(sheet, "set_feedback_chance", "Set Juice Card Chance", "Juice Player",
		"How often one card is felt at all, as a percentage. 100 is every time, 25 is a quarter of the hits - the cheapest variety there is.",
		[["label", "String", "The label of the card being rolled for."],
			["percent", "float", "The chance it is felt, 0 to 100."]],
		"var card: Dictionary = _edited(label, \"Set Juice Card Chance\")\nif not card.is_empty():\n\tcard[\"chance\"] = clampf(percent, 0.0, 100.0)")
	_default(sheet, "label", "shake")
	_default(sheet, "percent", "100.0")
	_quoted_call(sheet, "set_feedback_chance(\"{label}\", {percent})")
	Lib.append_function(sheet, "set_feedback_label", "Rename Juice Card", "Juice Player",
		"Renames one card. Every other row addresses cards by this name, so renaming one is renaming what the rest of the sheet has to say.",
		[["label", "String", "The card's name now."],
			["new_label", "String", "What it is called from here on."]],
		"var card: Dictionary = _edited(label, \"Rename Juice Card\")\nif not card.is_empty():\n\tcard[\"label\"] = new_label")
	_default(sheet, "label", "shake")
	_default(sheet, "new_label", "big shake")
	_quoted_call(sheet, "set_feedback_label(\"{label}\", \"{new_label}\")")
	Lib.append_function(sheet, "duplicate_feedback", "Duplicate Juice Card", "Juice Player",
		"Copies one card and puts the copy straight under it, under a name of its own. Two shakes a frame apart out of one tuned card.",
		[["label", "String", "The label of the card to copy."],
			["new_label", "String", "What the copy is called. Empty names it after the original."]],
		"var list: Array = _own_list()\nvar at: int = _index_in(list, label)\nif at < 0:\n\t_no_such(label, \"Duplicate Juice Card\")\n\treturn\nvar copy: Dictionary = (list[at] as Dictionary).duplicate(true)\ncopy[\"label\"] = new_label if not new_label.strip_edges().is_empty() else _label_of(copy) + \" copy\"\nlist.insert(at + 1, copy)")
	_default(sheet, "label", "shake")
	_default(sheet, "new_label", "")
	_quoted_call(sheet, "duplicate_feedback(\"{label}\", \"{new_label}\")")
	Lib.append_function(sheet, "clear_feedbacks", "Clear Juice Cards", "Juice Player",
		"Empties the list. What a player that is about to be handed a whole beat by Copy Juice Cards From or Load Moment File wants first.",
		[], "steps.clear()\nmoment_file = null")
	Lib.append_function(sheet, "copy_feedbacks_from", "Copy Juice Cards From", "Juice Player",
		"Takes another player's whole list and makes it this one's - a copy, so retuning either afterwards leaves the other alone. One tuned enemy hit, given to every enemy that spawns.",
		[["other", "Node", "The Juice Player to copy the list off."]],
		"if other == null:\n\treturn\nvar carried: Variant = other.get(\"steps\")\nif not (carried is Array):\n\tpush_warning(\"Juice Player: %s cannot copy cards from %s, which is not a Juice Player, so Copy Juice Cards From did nothing.\" % [name, other.name])\n\treturn\nvar list: Array = _own_list()\nlist.clear()\nfor entry: Variant in carried as Array:\n\tif entry is Dictionary:\n\t\tlist.append((entry as Dictionary).duplicate(true))")
	Lib.append_function(sheet, "load_moment_file", "Load Moment File", "Juice Player",
		"Brings a moment file's beat INTO this player's list, as a copy - so it can be retuned by rows afterwards without ever writing to the file two other objects may be playing.",
		[["path", "String", "The moment file to read, as its res:// path."]],
		"if not ResourceLoader.exists(path):\n\tpush_warning(\"Juice Player: %s has no moment file at \\\"%s\\\" to load, so Load Moment File did nothing.\" % [name, path])\n\treturn\nvar file: Resource = load(path)\nif file == null or not (file.get(\"steps\") is Array):\n\tpush_warning(\"Juice Player: %s cannot load \\\"%s\\\", which is not a moment file, so Load Moment File did nothing.\" % [name, path])\n\treturn\nmoment_file = file\n_own_list()")
	_default(sheet, "path", "res://eventsheet_addons/juice/impact.tres")
	_quoted_call(sheet, "load_moment_file(\"{path}\")")
	Lib.append_function(sheet, "save_moment_file", "Save Moment File", "Juice Player",
		"Writes this list out as a moment file, so a beat tuned while the game ran can be shared, shipped or loaded back. Only the four keys a file holds are written, and only for the ten moment words a file can be played by: a card that is switched off, the timing words a list adds, and this node's own three (a property tween, a signal, a nested player) are named in a warning and left out.",
		[["path", "String", "Where to write it. At run time that is a user:// path, which is the only place a game may write."]],
		"var kind: Script = load(\"res://eventsheet_addons/moment_resource/moment_resource.gd\") as Script\nif kind == null:\n\tpush_warning(\"Juice Player: %s cannot save a moment file because this project has no moment file script, so Save Moment File did nothing.\" % name)\n\treturn\nvar written: Array[Dictionary] = []\nvar left_behind: PackedStringArray = PackedStringArray()\nvar left_keys: PackedStringArray = PackedStringArray()\nfor entry: Variant in _steps_now():\n\tif not (entry is Dictionary):\n\t\tcontinue\n\tvar card: Dictionary = entry as Dictionary\n\tvar word: String = word_of(card)\n\tif not bool(card.get(\"active\", true)) or _is_timing(word) or _is_own_word(word):\n\t\tleft_behind.append(_label_of(card))\n\t\tcontinue\n\twritten.append({\"verb\": str(card.get(\"verb\", \"\")), \"amount\": float(card.get(\"amount\", 1.0)), \"effect\": str(card.get(\"effect\", \"\")), \"seconds\": float(card.get(\"seconds\", 0.0))})\n\tvar dropped: PackedStringArray = keys_a_file_drops(card)\n\tif not dropped.is_empty():\n\t\tleft_keys.append(\"%s (%s)\" % [_label_of(card), \", \".join(dropped)])\nvar file: Resource = kind.new()\nfile.set(\"moment_name\", name)\nfile.set(\"steps\", written)\nfor note: String in _moment_file_notes(left_behind, left_keys):\n\tpush_warning(note)\nif ResourceSaver.save(file, path) != OK:\n\tpush_warning(\"Juice Player: %s could not write \\\"%s\\\", so Save Moment File saved nothing.\" % [name, path])")
	_default(sheet, "path", "user://my_moment.tres")
	_quoted_call(sheet, "save_moment_file(\"{path}\")")
	Lib.append_function(sheet, "set_player_strength", "Set Juice Player Strength", "Juice Player",
		"Turns this whole player up or down without retuning a single card - the object's own volume knob, on top of the strength the play row asks for.",
		[["value", "float", "What every amount in the list is scaled by. 1 is the list as tuned."]],
		"strength = maxf(value, 0.0)")
	_default(sheet, "value", "1.0")
	Lib.append_function(sheet, "set_player_cooldown", "Set Juice Player Cooldown", "Juice Player",
		"The shortest gap between two plays, in seconds. A play asked for sooner is refused, which is how a rapid-fire hit stops stacking its own juice.",
		[["seconds", "float", "The gap. 0 lets every play through."]],
		"cooldown = maxf(seconds, 0.0)")
	_default(sheet, "seconds", "0.1")
	Lib.append_function(sheet, "set_can_play_while_playing", "Set Can Play While Playing", "Juice Player",
		"What a second play does while the first is still running: start again from the top, be ignored, or run alongside it.",
		[["answer", "String", "Restart, ignore, or overlap."]],
		"while_playing = answer")
	_param_options(sheet, "answer", ["restart", "ignore", "overlap"])
	_default(sheet, "answer", "restart")
	_quoted_call(sheet, "set_can_play_while_playing(\"{answer}\")")
	Lib.append_function(sheet, "mute_feedback_category", "Mute Juice Family", "Juice Player",
		"Silences a whole family of cards at once - every screen effect, every camera move, every sound - and lets them back with the same row. THE accessibility option: one row per switch on the settings screen, and no card has to be found and unticked.",
		[["category", "String", "The family to silence."],
			["muted", "bool", "On silences it; off lets it be felt again."]],
		"var family: String = category.strip_edges().to_lower()\nif family.is_empty():\n\treturn\nif muted:\n\t_muted[family] = true\nelse:\n\t_muted.erase(family)")
	_param_options(sheet, "category", ["audio", "transform", "camera", "screen", "pause", "loop", "signal"])
	_default(sheet, "category", "screen")
	_default(sheet, "muted", "true")
	_quoted_call(sheet, "mute_feedback_category(\"{category}\", {muted})")
	Lib.append_function(sheet, "mute_category_on_channel", "Mute Juice Family On Channel", "Juice Player",
		"The same switch, thrown for every Juice Player in a group at once - which is what a settings screen wants, because the option is about the game rather than about one object.",
		[["channel", "String", "The group every player the switch reaches is in."],
			["category", "String", "The family to silence."],
			["muted", "bool", "On silences it; off lets it be felt again."]],
		"if channel.strip_edges().is_empty() or not is_inside_tree():\n\treturn\nget_tree().call_group(channel, \"mute_feedback_category\", category, muted)")
	_default(sheet, "channel", "juice_players")
	_param_options(sheet, "category", ["audio", "transform", "camera", "screen", "pause", "loop", "signal"])
	_default(sheet, "category", "screen")
	_default(sheet, "muted", "true")
	_quoted_call(sheet, "mute_category_on_channel(\"{channel}\", \"{category}\", {muted})")
	Lib.append_function(sheet, "scale_feedback_amounts", "Scale Juice Amounts", "Juice Player",
		"Multiplies how much every card in a family does - the effect-strength slider on a settings screen, where half is still the same beat and not a shorter one. Leave the family empty to move the whole list.",
		[["category", "String", "The family to scale, or empty for every card."],
			["factor", "float", "What each amount is multiplied by. 0.5 is half as much."]],
		"var family: String = category.strip_edges().to_lower()\nfor entry: Variant in _own_list():\n\tif not (entry is Dictionary):\n\t\tcontinue\n\tvar card: Dictionary = entry as Dictionary\n\tif family.is_empty() or _category_of(card) == family:\n\t\tcard[\"amount\"] = float(card.get(\"amount\", 1.0)) * factor")
	_param_options(sheet, "category", ["", "audio", "transform", "camera", "screen", "pause", "loop", "signal"])
	_default(sheet, "category", "")
	_default(sheet, "factor", "0.5")
	_quoted_call(sheet, "scale_feedback_amounts(\"{category}\", {factor})")
	Lib.append_function(sheet, "retime_feedbacks", "Scale Juice Timing", "Juice Player",
		"Stretches or squeezes the whole beat in time: every length, every wait and every gap multiplied by the same number. Half makes a snappier version of a beat nobody has to retune card by card.",
		[["factor", "float", "What every length is multiplied by. 0.5 is twice as fast."]],
		"var scale: float = maxf(factor, 0.0)\nfor entry: Variant in _own_list():\n\tif not (entry is Dictionary):\n\t\tcontinue\n\tvar card: Dictionary = entry as Dictionary\n\tfor key: String in [\"seconds\", \"delay\", \"interval\"]:\n\t\tif card.has(key):\n\t\t\tcard[key] = float(card[key]) * scale")
	_default(sheet, "factor", "0.5")
	Lib.append_function(sheet, "shuffle_feedbacks_between", "Shuffle Juice Cards Between", "Juice Player",
		"Reorders the stretch of the list between two cards, both included, at random. The cheapest variety a repeated hit can have: the same juice cards, in a different order every time.",
		[["first_label", "String", "One end of the stretch."],
			["last_label", "String", "The other end."]],
		"var list: Array = _own_list()\nvar from: int = _index_in(list, first_label)\nvar to: int = _index_in(list, last_label)\nif from < 0 or to < 0:\n\t_no_such(first_label if from < 0 else last_label, \"Shuffle Juice Cards Between\")\n\treturn\nif to < from:\n\tvar swapped: int = from\n\tfrom = to\n\tto = swapped\nvar stretch: Array = list.slice(from, to + 1)\nstretch.shuffle()\nfor offset: int in range(stretch.size()):\n\tlist[from + offset] = stretch[offset]")
	_default(sheet, "first_label", "shake_a")
	_default(sheet, "last_label", "shake_c")
	_quoted_call(sheet, "shuffle_feedbacks_between(\"{first_label}\", \"{last_label}\")")
	Lib.append_function(sheet, "pick_one_feedback_of", "Pick One Juice Card Starting With", "Juice Player",
		"Ticks exactly one of the cards whose label starts with what you type and unticks the rest, so shake_a, shake_b and shake_c become one shake chosen fresh each time. Variety out of the list itself, with no branch in the sheet.",
		[["prefix", "String", "The start of the labels to choose between."]],
		"var wanted: String = prefix.strip_edges()\nif wanted.is_empty():\n\treturn\nvar matches: Array = []\nfor entry: Variant in _own_list():\n\tif entry is Dictionary and _label_of(entry as Dictionary).begins_with(wanted):\n\t\tmatches.append(entry)\nif matches.is_empty():\n\t_no_such(wanted, \"Pick One Juice Card Starting With\")\n\treturn\nvar chosen: int = randi() % matches.size()\nfor index: int in range(matches.size()):\n\t(matches[index] as Dictionary)[\"active\"] = index == chosen")
	_default(sheet, "prefix", "shake_")
	_quoted_call(sheet, "pick_one_feedback_of(\"{prefix}\")")
	Lib.append_function(sheet, "jump_to_feedback", "Jump To Juice Card", "Juice Player",
		"Moves the head of a RUNNING play to the card you name, so the rest of the beat starts there. What a hit that interrupts its own wind-up wants.",
		[["label", "String", "The label of the card to carry on from."]],
		"_jump_to = label.strip_edges()")
	_default(sheet, "label", "impact")
	_quoted_call(sheet, "jump_to_feedback(\"{label}\")")
	Lib.append_function(sheet, "skip_feedback_once", "Skip Juice Card Once", "Juice Player",
		"Steps over one card the NEXT time the play reaches it, and then forgets about it. The one-off exception a disable would have to be undone after.",
		[["label", "String", "The label of the card to step over once."]],
		"if _index_of(label) < 0:\n\t_no_such(label, \"Skip Juice Card Once\")\n\treturn\n_skip_once[label.strip_edges()] = true")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "skip_feedback_once(\"{label}\")")
	Lib.append_function(sheet, "set_loop_count", "Set Loop Count", "Juice Player",
		"How many times a Loop Back card sends the head round. A charge that gets longer the further it is held, without a second list.",
		[["label", "String", "The label of the Loop Back card."],
			["loops", "int", "How many times round. 0 walks straight past it."]],
		"var card: Dictionary = _edited(label, \"Set Loop Count\")\nif card.is_empty():\n\treturn\ncard[\"loops\"] = maxi(loops, 0)\nvar at: int = _index_in(_order, label)\nif at >= 0:\n\t_loops_left[at] = maxi(loops, 0)")
	_default(sheet, "label", "loop_back")
	_default(sheet, "loops", "2")
	_quoted_call(sheet, "set_loop_count(\"{label}\", {loops})")
	Lib.append_function(sheet, "hold_here", "Hold Here", "Juice Player",
		"Stops the head where it is and leaves it there - a charge held, a beat waiting on the player. Release Hold carries on from the same card, and nothing ticks while it waits.",
		[], "_held = playing")
	Lib.append_function(sheet, "release_hold", "Release Hold", "Juice Player",
		"Lets a held play carry on from the card it stopped on.",
		[], "_held = false\n_resumed.emit()")


## The rows that ASK rather than do: whether a card is playing, how many there are, what one of them
## says. Every one of them addresses a card by the same label the edit rows use - and by the same
## SPELLING of that label, which is why each of them writes its call out with the quotes in it. A
## card's label is a word a designer picked off the Inspector's list, not an expression: `shake` in
## the box has to reach the game as `has_feedback("shake")`, exactly as Remove Juice Card and every
## other editing row already spells the same address.
static func _asking_verbs(sheet: EventSheetResource) -> void:
	Lib.condition(sheet, "feedback_is_playing", "Juice Card Is Playing", "Juice Player",
		"True while the head is on that card - the moment the hit is being felt rather than the whole beat around it.",
		[["label", "String", "The label of the card being asked about."]],
		"return playing and now_playing == label.strip_edges()")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "feedback_is_playing(\"{label}\")")
	Lib.condition(sheet, "has_feedback", "Has Juice Card", "Juice Player",
		"True when this player's list holds a card by that name. The question a row asks before it retunes one, and the one a Doctor finding is about.",
		[["label", "String", "The label to look for."]],
		"return _index_of(label) >= 0")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "has_feedback(\"{label}\")")
	Lib.condition(sheet, "feedback_is_enabled", "Juice Card Is Enabled", "Juice Player",
		"True when that card's box is ticked - so a settings screen can show the switch the way the list actually has it.",
		[["label", "String", "The label of the card being asked about."]],
		"var at: int = _index_of(label)\nreturn at >= 0 and bool((_steps_now()[at] as Dictionary).get(\"active\", true))")
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "feedback_is_enabled(\"{label}\")")
	Lib.number(sheet, "feedback_count", "Juice Card Count", "Juice Player",
		"How many cards this player's list holds, ticked or not - the number the head of the Inspector shows.",
		[], "return _steps_now().size()", TYPE_INT)
	Lib.number(sheet, "feedback_label_at", "Juice Card Label At", "Juice Player",
		"The name of the card at a place in the list, so a settings screen can list a beat without knowing what is in it. The first card is 1; a number past the end answers with nothing.",
		[["position", "int", "Which card. The first in the list is 1."]],
		"var list: Array = _steps_now()\nvar at: int = position - 1\nif at < 0 or at >= list.size() or not (list[at] is Dictionary):\n\treturn \"\"\nreturn _label_of(list[at] as Dictionary)", TYPE_STRING)
	_default(sheet, "position", "1")
	Lib.number(sheet, "feedback_field", "Juice Card Field", "Juice Player",
		"What one card says at one of its fields - the amount it does, how long it lasts, the extra word it carries. The read half of Set Juice Card Field, so a slider can be shown at the value the list actually holds.",
		[["label", "String", "The label of the card being read."],
			["field", "String", "Which value to read."]],
		"return _card_named(label).get(field, null)", TYPE_MAX)
	_default(sheet, "label", "shake")
	_param_options(sheet, "field", ["amount", "effect", "seconds", "delay", "interval", "repeat", "chance", "loops", "clock", "min_strength", "max_strength"])
	_param_autocomplete(sheet, "field", ["amount", "effect", "seconds", "delay", "interval", "repeat", "chance", "loops", "clock", "min_strength", "max_strength"])
	_param_hint(sheet, "field", "juice_card_field")
	_default(sheet, "field", "amount")
	_quoted_call(sheet, "feedback_field(\"{label}\", \"{field}\")")
	Lib.number(sheet, "feedback_progress", "Juice Card Progress", "Juice Player",
		"How far through one card the play is, 0 before it starts and 1 once it is done. Read off the plan rather than off a tick, so asking it costs nothing.",
		[["label", "String", "The label of the card being watched."]],
		"return _progress_of(label)", TYPE_FLOAT)
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "feedback_progress(\"{label}\")")
	Lib.number(sheet, "feedback_duration", "Juice Card Duration", "Juice Player",
		"How long ONE card lasts, its own wait included - beside Juice Duration, which is how long the whole beat lasts.",
		[["label", "String", "The label of the card being measured."]],
		"var card: Dictionary = _card_named(label)\nvar own: float = card_length(card) if _is_timing(word_of(card)) else card_span(card)\nreturn own + maxf(float(card.get(\"delay\", 0.0)), 0.0)", TYPE_FLOAT)
	_default(sheet, "label", "shake")
	_quoted_call(sheet, "feedback_duration(\"{label}\")")
	Lib.number(sheet, "current_feedback", "Current Juice Card", "Juice Player",
		"The label of the card the head is on right now, or nothing when no play is running.",
		[], "return now_playing", TYPE_STRING)
	Lib.number(sheet, "loops_left", "Loops Left", "Juice Player",
		"How many times round a Loop Back card still has to go in the play that is running.",
		[["label", "String", "The label of the Loop Back card."]],
		"if playing:\n\tvar at: int = _index_in(_order, label)\n\tif at >= 0:\n\t\treturn int(_loops_left.get(at, 0))\nreturn int(_card_named(label).get(\"loops\", 0))", TYPE_INT)
	_default(sheet, "label", "loop_back")
	_quoted_call(sheet, "loops_left(\"{label}\")")


## The label boxes of the rows that name a card list the labels of the player the row acts on, when the saved
## scene shows them; a label typed still works, since a list built while the game runs is not in the scene.
static func _label_hints(sheet: EventSheetResource) -> void:
	for entry: Variant in sheet.functions:
		var fn: EventFunction = entry as EventFunction
		if fn == null or not fn.expose_as_ace:
			continue
		for parameter: ACEParam in fn.params:
			if parameter.hint.is_empty() and ["label", "after_label", "before_label"].has(parameter.id):
				parameter.hint = "juice_card_label"


## The lines somebody who played a list by hand wrote, for EVERY action and condition the node has, so
## an opened script reads them as THIS verb instead of as a sound or a plain method call. Derived from
## each function's own parameters rather than listed: a text parameter is a quoted word, a number or a
## node is one argument, a dictionary or a variant is the whole rest of the call.
##
## The node is spelled out, never a wildcard: `$AudioStreamPlayer.play(0.5)` is a sound and must stay
## one. Both names the node has had are covered here; a node a scene says is a Juice Player is covered
## by the reader. A text value that is not a plain word (a label with a space in it) reads as before.
## The spelled line is kept as the row's own text, so saving writes the file back exactly.
static func _spell_all(sheet: EventSheetResource) -> void:
	for entry: Variant in sheet.functions:
		var fn: EventFunction = entry as EventFunction
		if fn == null or not fn.expose_as_ace or not fn.looping_iterator.is_empty():
			continue
		if fn.return_type != TYPE_NIL and fn.return_type != TYPE_BOOL:
			continue
		var lead: String = "await " if fn.codegen_template_override.begins_with("await ") else ""
		var lines: PackedStringArray = PackedStringArray()
		for node_name: String in ["FeedbackPlayer", "JuicePlayer"]:
			for arguments: String in _argument_spellings(fn):
				lines.append("%s$%s.%s(%s)" % [lead, node_name, fn.function_name, arguments])
		fn.lift_examples = lines


## The argument lists one function is written with: the plain one, and for every text parameter that
## starts empty the same list with that parameter left as an empty string.
static func _argument_spellings(fn: EventFunction) -> PackedStringArray:
	var spellings: PackedStringArray = PackedStringArray()
	var count: int = fn.params.size()
	spellings.append(", ".join(_spelled_arguments(fn, -1)))
	for index: int in range(count):
		var parameter: ACEParam = fn.params[index]
		if parameter.type_name == "String" and parameter.id != "path" and parameter.default_value.strip_edges().is_empty():
			spellings.append(", ".join(_spelled_arguments(fn, index)))
	return spellings


static func _spelled_arguments(fn: EventFunction, empty_at: int) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	for index: int in range(fn.params.size()):
		var parameter: ACEParam = fn.params[index]
		var sample: String = parameter.default_value.strip_edges()
		if parameter.type_name == "String" and parameter.id == "path":
			parts.append("[[%s|text: \"res://moment.tres\"]]" % parameter.id)
		elif parameter.type_name == "String":
			if index == empty_at:
				parts.append("\"\"")
			else:
				parts.append("[[%s|name: \"%s\"]]" % [parameter.id, sample if sample.is_valid_identifier() else "shake"])
		elif parameter.type_name == "Dictionary" or parameter.type_name == "Variant":
			parts.append("[[%s|expression: %s]]" % [parameter.id, "{\"verb\": \"shake\"}" if parameter.type_name == "Dictionary" else "0.5"])
		else:
			parts.append("[[%s|argument: %s]]" % [parameter.id, sample if not sample.is_empty() and not sample.contains(",") else "1"])
	return parts


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


## Lets the last-appended ACE's parameter be typed freely, with these words offered as suggestions: the box
## for a value whose names a project can add to (the fields of a card of your own).
static func _param_autocomplete(sheet: EventSheetResource, param_id: String, suggestions: Array) -> void:
	var typed: Array[String] = []
	for suggestion: Variant in suggestions:
		typed.append(str(suggestion))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.autocomplete = typed


## Names the EDITOR a parameter opens. The Juice Player uses one: a step, which opens the very
## card the Inspector unfolds, so a juice card authored by a row and one authored in the list are the
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
		"## Autoplay: when the node enters the scene with the box ticked, the list plays once at full strength.",
		"func _ready() -> void:",
		"\tif not is_in_group(PLAYERS_GROUP):",
		"\t\tadd_to_group(PLAYERS_GROUP)",
		"\t_listen_for_controllers()",
		"\tif autoplay:",
		"\t\tplay(1.0)",
		"",
		"# --- The play: one list, one head, one strength ---",
		"# A play is a walk down the list, and its identity is a TOKEN. Every walk in flight holds one, and a",
		"# suspended step does nothing at all once its token has left the live list - which is how a stop, a",
		"# restart or a skip ends a coroutine without a flag per step, and how \"overlap\" runs two plays at",
		"# once without either of them ending the other.",
		"#",
		"# The card the head is on is not copied. A card carries its own live values while it runs (the loops",
		"# it has left), and those are what the remote Inspector of the running node shows.",
		"",
		"## Most steps one play may run, loops included, before it gives up.",
		"const MAX_PLAY_STEPS: int = 4096",
		"",
		"## Direction word: walk the list from the first card to the last.",
		"const TOP_TO_BOTTOM: String = \"top to bottom\"",
		"## Direction word: walk the list from the last card to the first.",
		"const BOTTOM_TO_TOP: String = \"bottom to top\"",
		"## Answer to a play while already playing: stop and start again from the top.",
		"const RESTART: String = \"restart\"",
		"## Answer to a play while already playing: do nothing and let it carry on.",
		"const IGNORE: String = \"ignore\"",
		"## Answer to a play while already playing: start a second play alongside the first.",
		"const OVERLAP: String = \"overlap\"",
		"",
		"# The words below are this node's own. Every other word is played by the Juice behaviour",
		"# beside it - the same call a moment file makes - so a card list and a moment file are the same",
		"# ten words plus timing.",
		"## Step word: stop the play here until Resume is called.",
		"const PAUSE: String = \"pause\"",
		"## Step word: wait here until the named signal arrives.",
		"const HOLD_UNTIL: String = \"hold_until\"",
		"## Step word: marks the card a Loop Back returns to.",
		"const LOOP_START: String = \"loop_start\"",
		"## Step word: go back to the Loop Start card, a set number of times.",
		"const LOOP_BACK: String = \"loop_back\"",
		"## Step word: tween a property of a node to a value.",
		"const TWEEN_PROPERTY: String = \"tween_property\"",
		"## Step word: emit a signal on a node.",
		"const EMIT_SIGNAL: String = \"emit_signal\"",
		"## Step word: start another Juice Player and let it run.",
		"const PLAY_PLAYER: String = \"play_player\"",
		"## The word a card of your own is played under, so a class named Pause is not taken for the built-in word.",
		"const YOURS: String = \"yours\"",
		"## Step word: play a sound.",
		"const SOUND: String = \"sound\"",
		"## Step word: stop a sound an earlier Sound card started, by that card's name, with an optional fade.",
		"const STOP_SOUND: String = \"stop_sound\"",
		"## Step word: move a bus's volume to a value over a time. Restore Initial Values puts it back.",
		"const FADE_BUS: String = \"fade_bus\"",
		"## Step word: rumble a controller, or buzz a phone, for a time.",
		"const VIBRATE: String = \"vibrate\"",
		"## The volume a fade-out ends on, below which nothing is heard.",
		"const SILENT_DB: float = -80.0",
		"## Heard-from word: the sound comes from the object this player is under, so it sits in space.",
		"const HEARD_HERE: String = \"here\"",
		"## Heard-from word: the sound plays flat, the same wherever the listener is.",
		"const HEARD_EVERYWHERE: String = \"everywhere\"",
		"## Most sounds one player has going at once. A new one takes the oldest voice when all are busy.",
		"const SOUND_VOICES: int = 4",
		"## The lowest pitch a roll may land on, because a pitch scale has to stay above zero.",
		"const LOWEST_PITCH: float = 0.05",
		"",
		"## Raised whenever a pause ends, however it ended. Private, so it is plumbing rather than vocabulary.",
		"## @ace_hidden",
		"signal _resumed",
		"",
		"## Live while the game runs - written by the play, read in the remote Inspector of the running node.",
		"var playing: bool = false",
		"## How far through the cards the play has got, from 0 to 1.",
		"var progress: float = 0.0",
		"## Label of the card being played now, or empty when nothing is playing.",
		"var now_playing: String = \"\"",
		"",
		"## Tokens of the plays still running, so a stale play can tell it was stopped.",
		"var _live: Array[int] = []",
		"## The token handed to the next play that starts.",
		"var _next_token: int = 0",
		"## True while the play is paused on a Pause card.",
		"var _paused: bool = false",
		"## True once the list has played at least once, which Skip Next Time reads.",
		"var _played_once: bool = false",
		"## When the list last played, in seconds, used to enforce its cooldown.",
		"var _last_played_at: float = -1000.0",
		"## The cards in the order this play walks them.",
		"var _order: Array = []",
		"## Index in the order of the card being played.",
		"var _head: int = 0",
		"## Strength the current play was started at, which scales every card in it.",
		"var _head_strength: float = 1.0",
		"",
		"# A Skip To End does the",
		"# cards the walk has not reached, and the head is the one card that could be in both: without",
		"# this it would be decided twice, which would consume a Skip Next Time twice over and feel a",
		"# card the walk is still in the middle of a second time.",
		"## Whether the card the head is on has already been answered by the walk.",
		"var _head_taken: bool = false",
		"## Cards started beside the walk, counted for each play by its token, so a play stays open until they are felt.",
		"var _pending: Dictionary = {}",
		"## The cards waiting out their own delay, by ticket, which a Skip To End feels at once.",
		"var _waiting: Dictionary = {}",
		"## The ticket handed to the next card that waits.",
		"var _next_ticket: int = 0",
		"",
		"# A moment file dropped on two players is ONE resource shared by both, so a counter",
		"# written into its steps would have each play counting the other's loops down, and the file on",
		"# disk would come back from a play changed.",
		"## Loops still to run for each Loop Back card, kept per play.",
		"var _loops_left: Dictionary = {}",
		"## The random roll each card's chance is answered with, kept per play.",
		"var _rolls: Dictionary = {}",
		"## The properties this play changed and the values to put back on Restore.",
		"var _restore_to: Array = []",
		"# Each tween is kept by handle, because otherwise it goes on writing over the restored value the",
		"# very next frame, which is a Restore that visibly does nothing.",
		"## The tweens this player started, so a Revert or a Restore can stop them before it puts a value back.",
		"var _tweens: Array[Tween] = []",
		"",
		"## Players this play started through a Play Player card; they follow it.",
		"var _nested: Array[Node] = []",
		"",
		"## Most cards of your own a player keeps hold of at once, the oldest let go first.",
		"const MOST_OWN_RUNNING: int = 16",
		"## The cards of your own a play has started and not yet stopped, so Stop and Restore can reach them.",
		"var _own_running: Array[Resource] = []",
		"",
		"## The few players this node plays its Sound cards through, kept and reused instead of made per hit.",
		"var _voices: Array[Node] = []",
		"",
		"## The voice each Sound card's sound is on, by the card's name, so a Stop Sound card can find it.",
		"var _sounding: Dictionary = {}",
		"## The bus volumes a Fade Bus card moved, by bus name, as they were before the first one - what Restore puts back.",
		"var _bus_restore: Dictionary = {}",
		"## The tweens that are moving a bus volume right now.",
		"var _bus_tweens: Array[Tween] = []",
		"## When the card that ends last will have ended, on the wall clock, so a wait can last until the cards are done.",
		"var _ends_at: float = 0.0",
		"## Which voice a run of hits takes next once every voice is busy.",
		"var _next_voice: int = 0",
		"## The Sound cards already complained about, so a missing sound is said once and not on every hit.",
		"var _told_sound: Dictionary = {}",
		"",
		"## The Juice behaviour found beside this player, kept once found.",
		"var _juice_node: Node = null",
		"## True once the missing-Juice warning has been printed, so it is printed only once.",
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
		"\tif not _all_enabled:",
		"\t\tif not _told_switched_off:",
		"\t\t\t_told_switched_off = true",
		"\t\t\tpush_warning(\"Juice Player: %s did not play because every Juice Player is switched off (Set All Juice Players Enabled).\" % name)",
		"\t\treturn false",
		"\tvar now: float = float(Time.get_ticks_msec()) / 1000.0",
		"\tif cooldown > 0.0 and now - _last_played_at < cooldown:",
		"\t\treturn false",
		"\tif playing and while_playing == IGNORE:",
		"\t\treturn false",
		"\tif playing and while_playing == RESTART:",
		"\t\t# The interrupted walk stops where it is, and its play is CLOSED here rather than left",
		"\t\t# open: a sheet pairing On Juice Started with On Juice Finished must get both,",
		"\t\t# and the walk that was cut short will never reach the end that would have said so.",
		"\t\t# It ends the way Stop Juice ends, waking a held head and telling the players this",
		"\t\t# play started through a Play Player card: half a beat carrying on under the restart is",
		"\t\t# exactly what the restart was asked to replace.",
		"\t\t_live.clear()",
		"\t\t_waiting.clear()",
		"\t\t_resumed.emit()",
		"\t\t_told_nested(\"stop\")",
		"\t\t_close()",
		"\t_last_played_at = now",
		"\treturn true",
		"",
		"## The longest path through a list of steps: a stretch between two holds runs at once, so it is as",
		"## long as its slowest card, and the holds and pauses add up. A Hold that names a card waits for that",
		"## card alone, so what is still running beside it carries on into what comes next. The Inspector head,",
		"## the card badge and the expression all read this one function, so no two of them can disagree.",
		"## @ace_hidden",
		"static func duration_of(list: Array) -> float:",
		"\tvar walked: Dictionary = _timeline(list)",
		"\treturn maxf(float(walked[\"at\"]), float(walked[\"latest\"]))",
		"",
		"## The one pass over a list that every answer about time reads: where each felt card starts, where the",
		"## head is after the Pauses and Holds, and when the latest card ends. A card's Delay and Repeat hold up",
		"## THAT card only, so the cards under it start where they would have without it; a Pause moves the head",
		"## along, and a Hold waits for the latest END of the cards since the last Hold (or for the one card it",
		"## names), then its own wait. Returns {plan, at, latest, ends}: `at` is the head, `latest` the last end,",
		"## `ends` the end of each card of the stretch by label.",
		"static func _timeline(list: Array) -> Dictionary:",
		"\tvar plan: Array = []",
		"\tvar at: float = 0.0",
		"\tvar latest: float = 0.0",
		"\tvar ends: Dictionary = {}",
		"\tfor entry: Variant in list:",
		"\t\tif not (entry is Dictionary):",
		"\t\t\tcontinue",
		"\t\tvar card: Dictionary = entry as Dictionary",
		"\t\tif not bool(card.get(\"active\", true)):",
		"\t\t\tcontinue",
		"\t\tvar word: String = word_of(card)",
		"\t\tif word == LOOP_START or word == LOOP_BACK:",
		"\t\t\tcontinue",
		"\t\tvar delay: float = maxf(float(card.get(\"delay\", 0.0)), 0.0)",
		"\t\tvar seconds: float = card_length(card)",
		"\t\tif word == HOLD_UNTIL:",
		"\t\t\tvar arrived: float = at + delay",
		"\t\t\tat = maxf(arrived, _waited_until(card, ends, latest)) + seconds",
		"\t\t\tlatest = maxf(latest, at)",
		"\t\t\tends.clear()",
		"\t\telif word == PAUSE:",
		"\t\t\tat += delay + seconds",
		"\t\telse:",
		"\t\t\tvar starts: float = at + delay",
		"\t\t\tvar ends_at: float = starts + card_span(card)",
		"\t\t\tplan.append({\"card\": card, \"at\": starts, \"seconds\": seconds, \"repeat\": maxi(int(card.get(\"repeat\", 1)), 1), \"every\": maxf(float(card.get(\"interval\", 0.0)), 0.0)})",
		"\t\t\tlatest = maxf(latest, ends_at)",
		"\t\t\tends[card_label(card)] = maxf(float(ends.get(card_label(card), 0.0)), ends_at)",
		"\treturn {\"plan\": plan, \"at\": at, \"latest\": latest, \"ends\": ends}",
		"",
		"## How long a felt card lasts from its first play to the end of its last: its own length plus the gaps",
		"## of its repeats. A card that is not repeated lasts its length.",
		"## @ace_hidden",
		"static func card_span(card: Dictionary) -> float:",
		"\tvar repeat: int = maxi(int(card.get(\"repeat\", 1)), 1)",
		"\tvar interval: float = maxf(float(card.get(\"interval\", 0.0)), 0.0)",
		"\treturn card_length(card) + float(repeat - 1) * interval",
		"",
		"## The moment a Hold stops waiting: the end of the card it names, or the latest end of the stretch when it",
		"## names nothing or names a card that is not above it in that stretch.",
		"static func _waited_until(hold: Dictionary, ends: Dictionary, latest: float) -> float:",
		"\tvar wanted: String = str(hold.get(\"waits_for\", \"\")).strip_edges()",
		"\tif wanted.is_empty() or not ends.has(wanted):",
		"\t\treturn latest",
		"\treturn float(ends[wanted])",
		"",
		"## The word a card is played under: `yours` for a card of your own (it holds the address of its script),",
		"## else its saved word, trimmed and in lower case. Every place that asks what a card is asks here.",
		"static func word_of(card: Dictionary) -> String:",
		"\tif card.has(\"card_script\"):",
		"\t\treturn YOURS",
		"\treturn str(card.get(\"verb\", \"\")).strip_edges().to_lower()",
		"",
		"## Whether a word moves the head rather than being felt.",
		"static func _is_timing(word: String) -> bool:",
		"\treturn word == PAUSE or word == HOLD_UNTIL or word == LOOP_START or word == LOOP_BACK",
		"",
		"## And whether a word is this NODE'S own rather than a moment's: a property walked to a value, a",
		"## signal, a nested player and a sound. The ten moment words are played by the Juice node beside this",
		"## one; these four are done here, and a moment FILE has nowhere to keep them.",
		"static func _is_own_word(word: String) -> bool:",
		"\treturn word == TWEEN_PROPERTY or word == EMIT_SIGNAL or word == PLAY_PLAYER or word == SOUND \\",
		"\t\t\tor word == STOP_SOUND or word == FADE_BUS or word == VIBRATE or word == YOURS or WORLD_WORDS.has(word)",
		"",
		"## The number a card's chance is answered with. One roll per card is thrown before the beat",
		"## begins, so a Skip To End reads the decision the walk would have read rather than throwing the",
		"## dice a second time for the same card.",
		"func _rolled_at(index: int) -> float:",
		"\tif not _rolls.has(index):",
		"\t\t_rolls[index] = randf() * 100.0",
		"\treturn float(_rolls[index])",
		"",
		"## And the roll that card will be answered with NEXT time, thrown the moment the walk has used",
		"## this one - which is what keeps a card inside a loop a fresh chance every time round.",
		"func _roll_again(index: int) -> void:",
		"\t_rolls[index] = randf() * 100.0",
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
		"\t\t_head_taken = false",
		"\t\tprogress = float(index) / float(maxi(order.size(), 1))",
		"\t\tindex = await _take(order, index, order[index] as Dictionary, at_strength, token)",
		"\t\tindex = _landing(order, index)",
		"\twhile _alive(token) and int(_pending.get(token, 0)) > 0:",
		"\t\tawait _resumed",
		"\t_pending.erase(token)",
		"\tif _alive(token) and index < order.size():",
		"\t\tpush_warning(\"Juice Player: a loop on %s never came back, so the play was given up after %d steps.\" % [name, MAX_PLAY_STEPS])",
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
		"## word is a juice card, which is felt and stepped over.",
		"func _take(order: Array, index: int, card: Dictionary, at_strength: float, token: int) -> int:",
		"\tvar word: String = word_of(card)",
		"\tvar refused: String = _why_not(card, at_strength, index)",
		"\t_head_taken = true",
		"\t_roll_again(index)",
		"\tif not refused.is_empty():",
		"\t\tif not _is_timing(word):",
		"\t\t\ton_feedback_skipped.emit(_label_of(card), refused)",
		"\t\treturn index + 1",
		"\tvar clock: String = MomentRunner.CLOCK_REAL if str(card.get(\"clock\", \"\")) == \"real\" else MomentRunner.CLOCK_GAME",
		"\tvar delay: float = maxf(float(card.get(\"delay\", 0.0)), 0.0)",
		"\t# A card that is felt and waits or repeats on its own is run beside the walk: its Delay and Repeat hold",
		"\t# up THAT card only, and the cards under it start when they would have without it. A Pause, a Hold and",
		"\t# the loop cards are the head's own waits, so their delay is waited out here.",
		"\tif not _is_timing(word) and (delay > 0.0 or int(card.get(\"repeat\", 1)) > 1):",
		"\t\t_run_beside(card, at_strength, clock, token)",
		"\t\treturn index + 1",
		"\tif delay > 0.0:",
		"\t\tawait MomentRunner.at(self, delay, clock)",
		"\t\tif not _alive(token):",
		"\t\t\treturn order.size()",
		"\tmatch word:",
		"\t\tPAUSE:",
		"\t\t\tawait MomentRunner.then(self, MomentRunner.seconds_of(float(card.get(\"seconds\", 0.0))), clock)",
		"\t\tHOLD_UNTIL:",
		"\t\t\ton_hold_reached.emit()",
		"\t\t\tawait MomentRunner.hold(self, left_above(order, index), float(card.get(\"seconds\", 0.0)), clock)",
		"\t\tLOOP_START:",
		"\t\t\tpass",
		"\t\tLOOP_BACK:",
		"\t\t\tvar back: int = _loop_target(order, index, card)",
		"\t\t\tvar left: int = int(_loops_left.get(index, int(card.get(\"loops\", 1))))",
		"\t\t\tif left > 0 and back >= 0:",
		"\t\t\t\t_loops_left[index] = left - 1",
		"\t\t\t\ton_loop.emit(left - 1)",
		"\t\t\t\tawait MomentRunner.then(self, MomentRunner.seconds_of(float(card.get(\"seconds\", 0.0))), clock)",
		"\t\t\t\treturn back",
		"\t\t\t_loops_left[index] = int(card.get(\"loops\", 1))",
		"\t\t_:",
		"\t\t\tawait _feel(card, at_strength, clock, token)",
		"\treturn index + 1",
		"",
		"## One felt card, played: announced, done, and repeated as often as it asks. Every felt card comes through here",
		"## whether the walk waited for it or started it beside itself.",
		"func _feel(card: Dictionary, at_strength: float, clock: String, token: int) -> void:",
		"\tnow_playing = str(card.get(\"label\", word_of(card)))",
		"\ton_feedback_started.emit(_label_of(card))",
		"\t_ends_at = maxf(_ends_at, float(Time.get_ticks_msec()) / 1000.0 + card_span(card))",
		"\t# Every pass is measured from THIS instant on the card's own clock, so a late frame moves one pass and not the ones after it.",
		"\tvar started: MomentRunner.Stopwatch = MomentRunner.stopwatch(self, clock)",
		"\t_do_step(card, at_strength)",
		"\tawait _repeat_rest(card, at_strength, token, started)",
		"\ton_feedback_finished.emit(_label_of(card))",
		"",
		"## A felt card that waits out its own delay or plays more than once, started beside the walk. The head has",
		"## moved on already; the play stays open until this card has finished, and a Stop ends it where it is.",
		"func _run_beside(card: Dictionary, at_strength: float, clock: String, token: int) -> void:",
		"\t_pending[token] = int(_pending.get(token, 0)) + 1",
		"\t_next_ticket += 1",
		"\tvar ticket: int = _next_ticket",
		"\tvar delay: float = maxf(float(card.get(\"delay\", 0.0)), 0.0)",
		"\t_ends_at = maxf(_ends_at, float(Time.get_ticks_msec()) / 1000.0 + delay + card_span(card))",
		"\tif delay > 0.0:",
		"\t\t_waiting[ticket] = card",
		"\t\tawait MomentRunner.at(self, delay, clock)",
		"\tif _alive(token):",
		"\t\t_waiting.erase(ticket)",
		"\t\tawait _feel(card, at_strength, clock, token)",
		"\t_waiting.erase(ticket)",
		"\t_pending[token] = int(_pending.get(token, 1)) - 1",
		"\t_resumed.emit()",
		"",
		"## The repeats a card asks for after its first play, pass k a time k * Every after the first on the stopwatch",
		"## that was started with it, so a pass that came late does not push the ones after it.",
		"func _repeat_rest(card: Dictionary, at_strength: float, token: int, started: MomentRunner.Stopwatch) -> void:",
		"\tvar repeat: int = maxi(int(card.get(\"repeat\", 1)), 1)",
		"\tvar interval: float = maxf(float(card.get(\"interval\", 0.0)), 0.0)",
		"\tfor pass_index: int in range(1, repeat):",
		"\t\tif not _alive(token):",
		"\t\t\treturn",
		"\t\tawait started.until(float(pass_index) * MomentRunner.seconds_of(interval))",
		"\t\tif not _alive(token):",
		"\t\t\treturn",
		"\t\t_do_step(card, at_strength)",
		"",
		"## Whether a card is felt at all: its enable box, its chance, and the strength window it asked for.",
		"func _card_runs(card: Dictionary, at_strength: float, index: int) -> bool:",
		"\treturn _why_not(card, at_strength, index).is_empty()",
		"",
		"## WHY a card was not felt, in one word, or \"\" when it was. The reason is what On Juice Card Skipped",
		"## carries, so a row can tell a card the player muted from one the dice went against - and it is",
		"## asked ONCE for each card the head reaches, because answering the same card twice would consume",
		"## a Skip Next Time twice over and throw the dice again for a decision already made.",
		"func _why_not(card: Dictionary, at_strength: float, index: int) -> String:",
		"\tif not bool(card.get(\"active\", true)):",
		"\t\treturn \"off\"",
		"\tvar named: String = _label_of(card)",
		"\tif _skip_once.has(named):",
		"\t\t_skip_once.erase(named)",
		"\t\treturn \"skipped once\"",
		"\t# A family switch silences what is FELT. A Pause, a Hold and the two loop cards only move the head,",
		"\t# so muting their family leaves the beat the length it was.",
		"\tif _muted.has(_category_of(card)) and not _is_timing(word_of(card)):",
		"\t\treturn \"muted\"",
		"\tvar chance: float = float(card.get(\"chance\", 100.0))",
		"\tif chance < 100.0 and _rolled_at(index) >= chance:",
		"\t\treturn \"chance\"",
		"\tif at_strength < float(card.get(\"min_strength\", 0.0)):",
		"\t\treturn \"strength\"",
		"\tvar ceiling: float = float(card.get(\"max_strength\", 0.0))",
		"\tif ceiling > 0.0 and at_strength > ceiling:",
		"\t\treturn \"strength\"",
		"\treturn \"\"",
		"",
		"## One juice card, felt. The ten moment words go to the Juice behaviour beside this node - the same",
		"## call a moment file makes - and this node's own words are done here.",
		"func _do_step(card: Dictionary, at_strength: float, skipping: bool = false) -> void:",
		"\t_card_in_play = card",
		"\t_play_card(card, at_strength, skipping)",
		"\t_card_in_play = {}",
		"",
		"## One juice card, felt, with the card named while it plays so a typed function says what is wrong in its words.",
		"func _play_card(card: Dictionary, at_strength: float, skipping: bool = false) -> void:",
		"\tvar word: String = word_of(card)",
		"\tvar amount: float = float(card.get(\"amount\", 1.0))",
		"\tvar effect: String = str(card.get(\"effect\", \"\"))",
		"\tvar seconds: float = maxf(float(card.get(\"seconds\", 0.0)), 0.0)",
		"\t# The player's own strength scales EVERY kind of card, not only the felt ones: a whole",
		"\t# object's juice turned down has to turn down the tween that moves it too.",
		"\tvar at: float = at_strength * maxf(strength, 0.0)",
		"\t# The no-flashing ceiling and floor belong to the words a player SEES, and the runner beside",
		"\t# this file holds that list for every home a moment has. None of this node's own three words",
		"\t# is one of them: a property tween's target is a position, a width or an angle, a signal",
		"\t# carries no amount at all, and a nested player is handed a strength rather than an amplitude.",
		"\t# Holding a tween to 200 pixels down to 0.3 would not be less flashing, it would be the wrong",
		"\t# number. The ten moment words below ARE in the list, and the Juice node holds them to it as",
		"\t# they arrive.",
		"\tif word == YOURS:",
		"\t\t_play_own_card(card, at)",
		"\t\treturn",
		"\tif WORLD_WORDS.has(word):",
		"\t\tif skipping and LASTS_ONLY_A_TIME.has(word):",
		"\t\t\treturn",
		"\t\t_play_world_card(word, card, at, seconds, skipping)",
		"\t\treturn",
		"\tmatch word:",
		"\t\tTWEEN_PROPERTY:",
		"\t\t\t# A card that holds none of the newer keys is the one-number tween it always was.",
		"\t\t\tif _is_whole_tween(card):",
		"\t\t\t\t_tween_card(card, at, seconds)",
		"\t\t\telse:",
		"\t\t\t\t_tween_property(card, effect, amount * at, maxf(seconds, 0.0))",
		"\t\tEMIT_SIGNAL:",
		"\t\t\tif _names_a_node(card, \"node\") and not str(card.get(\"signal\", \"\")).is_empty():",
		"\t\t\t\t_emit_on_node(card)",
		"\t\t\telse:",
		"\t\t\t\ton_feedback_signal.emit(effect)",
		"\t\tSOUND:",
		"\t\t\t# A skip jumps to where the beat ends, and a sound is not a place: it is not heard late.",
		"\t\t\tif not skipping:",
		"\t\t\t\t_play_sound(card, at)",
		"\t\tSTOP_SOUND:",
		"\t\t\tif not skipping:",
		"\t\t\t\tstop_sound(effect, seconds)",
		"\t\tFADE_BUS:",
		"\t\t\tif not skipping:",
		"\t\t\t\tfade_bus(effect, amount, seconds)",
		"\t\tVIBRATE:",
		"\t\t\tif not skipping:",
		"\t\t\t\t_vibrate(card, at)",
		"\t\tPLAY_PLAYER:",
		"\t\t\tvar other: Node = _player_to_play(card, effect)",
		"\t\t\tif other != null and other.has_method(\"play\"):",
		"\t\t\t\tplay_player(other, at * maxf(amount, 0.0))",
		"\t\t\t\t# A play started BY a skip is skipped too. The list that started it has already been",
		"\t\t\t\t# closed, so there is nothing left to tell it later - and a cutscene skip that leaves a",
		"\t\t\t\t# nested beat running at its full length has not skipped the cutscene.",
		"\t\t\t\tif skipping and other.has_method(\"skip_to_end\"):",
		"\t\t\t\t\tother.call(\"skip_to_end\")",
		"\t\t_:",
		"\t\t\tvar juice: Node = _juice()",
		"\t\t\tif juice != null and word == \"shake\" and MomentRunner.is_timed_shake(card) and juice.has_method(\"shake_from_card\"):",
		"\t\t\t\t# A Shake card with a tick or a curve lasts its Seconds and has a shape; one without keeps shaking",
		"\t\t\t\t# as it always has, and so does a Juice node too old to know the difference.",
		"\t\t\t\tjuice.call(\"shake_from_card\", card, at)",
		"\t\t\telif juice != null:",
		"\t\t\t\tjuice.call(\"moment_step\", word, amount, effect, seconds, at)",
		"",
		"## What a broadcast on a channel arrives as. A NAME OF THIS PACK'S OWN, never the bare word play:",
		"## an audio, video or animation player in the same group answers to that one too, and call_group",
		"## swallows the error - so a channel meant for juice would quietly start somebody's music.",
		"## @ace_hidden",
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
		"\t_flares.clear()",
		"",
		"## The Juice behaviour beside this node - found by the step call it answers rather than by its class,",
		"## so this pack names no other pack. Said once when there is none, because a list of ten shakes with",
		"## no behaviour under it would otherwise be ten warnings a frame.",
		"func _juice() -> Node:",
		"\tvar found: Node = _juice_quiet()",
		"\tif found != null:",
		"\t\treturn found",
		"\tif not _told_no_juice:",
		"\t\t_told_no_juice = true",
		"\t\tpush_warning(\"Juice Player: %s has no Juice behaviour beside it, so its shake, flash and hitstop steps did nothing. Add a Juice node under the same object.\" % name)",
		"\treturn null",
		"",
		"## What one play of a Sound card is made of: the stream, the level, the pitch and the bus. The two rolls",
		"## are numbers from 0 to 1 that land inside the card's spreads (0 is the bottom of one, 0.5 the middle and",
		"## 1 the top), so the game, which throws dice, and the editor's Listen button, which throws them too,",
		"## read one function and mean the same card.",
		"## @ace_hidden",
		"static func sound_settings(card: Dictionary, at_strength: float, pitch_roll: float, volume_roll: float) -> Dictionary:",
		"\tvar volume: float = float(card.get(\"volume_db\", 0.0)) + (clampf(volume_roll, 0.0, 1.0) * 2.0 - 1.0) * maxf(float(card.get(\"volume_spread_db\", 0.0)), 0.0)",
		"\tif bool(card.get(\"follows_strength\", false)):",
		"\t\tvolume += linear_to_db(maxf(at_strength, 0.0001))",
		"\tvar pitch: float = float(card.get(\"pitch\", 1.0)) + (clampf(pitch_roll, 0.0, 1.0) * 2.0 - 1.0) * maxf(float(card.get(\"pitch_spread\", 0.0)), 0.0)",
		"\treturn {",
		"\t\t\"stream\": str(card.get(\"stream\", \"\")),",
		"\t\t\"volume_db\": volume,",
		"\t\t\"pitch_scale\": maxf(pitch, LOWEST_PITCH),",
		"\t\t\"bus\": str(card.get(\"bus\", \"Master\")),",
		"\t\t\"here\": str(card.get(\"heard_from\", HEARD_HERE)) != HEARD_EVERYWHERE",
		"\t}",
		"",
		"## How long one card lasts on its own, its delay not counted. A Sound card lasts as long as its stream",
		"## plays at its pitch (a half second sound at double pitch is a quarter of a second); every other card",
		"## says so with its Seconds. The plan, the badge and the Hold all read this one function.",
		"## @ace_hidden",
		"static func card_length(card: Dictionary) -> float:",
		"\tif word_of(card) == YOURS:",
		"\t\treturn _own_length(card)",
		"\tif (word_of(card) == LIGHT or word_of(card) == ANIMATION_PARAMETER) and bool(card.get(\"back\", true)):",
		"\t\treturn maxf(float(card.get(\"seconds\", 0.0)), 0.0) + maxf(float(card.get(\"back_seconds\", 0.2)), 0.0)",
		"\tif word_of(card) == SCENE_LOOK or word_of(card) == BUS_EFFECT:",
		"\t\treturn maxf(float(card.get(\"seconds\", 0.0)), 0.0) + maxf(float(card.get(\"back_seconds\", 0.3)), 0.0)",
		"\tif word_of(card) != SOUND:",
		"\t\treturn maxf(float(card.get(\"seconds\", 0.0)), 0.0)",
		"\tvar stream: AudioStream = _stream_at(str(card.get(\"stream\", \"\")))",
		"\tif stream == null:",
		"\t\treturn 0.0",
		"\treturn stream.get_length() / maxf(float(card.get(\"pitch\", 1.0)), LOWEST_PITCH)",
		"",
		"## The script of a card of your own, by the uid (or path) the card holds, or null when that file is not",
		"## in the project any more.",
		"static func own_script_of(card: Dictionary) -> Script:",
		"\tvar address: String = str(card.get(\"card_script\", \"\")).strip_edges()",
		"\tif address.is_empty() or not ResourceLoader.exists(address):",
		"\t\treturn null",
		"\treturn load(address) as Script",
		"",
		"## A fresh card of your own holding the values the saved card keeps under its export names. A file kept",
		"## as text (a uid or a path) is loaded for an export that holds a Resource. Null when the script is gone or",
		"## is not a card (it has no `play`).",
		"static func own_card_of(card: Dictionary) -> Resource:",
		"\tvar script: Script = own_script_of(card)",
		"\tif script == null or not script.can_instantiate():",
		"\t\treturn null",
		"\tvar made: Variant = script.new()",
		"\tif not (made is Resource) or not (made as Resource).has_method(\"play\"):",
		"\t\treturn null",
		"\tfor property: Dictionary in script.get_script_property_list():",
		"\t\tvar export_name: String = str(property.get(\"name\", \"\"))",
		"\t\tif not (int(property.get(\"usage\", 0)) & PROPERTY_USAGE_STORAGE) or not card.has(export_name):",
		"\t\t\tcontinue",
		"\t\tvar stored: Variant = card[export_name]",
		"\t\tif int(property.get(\"type\", TYPE_NIL)) == TYPE_OBJECT and stored is String:",
		"\t\t\tstored = load(stored) if ResourceLoader.exists(stored) else null",
		"\t\t(made as Resource).set(export_name, stored)",
		"\treturn made as Resource",
		"",
		"## How long a card of your own says it takes. The editor does not run a script that is not a tool script, so",
		"## there the card's seconds stand in for it.",
		"static func _own_length(card: Dictionary) -> float:",
		"\tif Engine.is_editor_hint():",
		"\t\treturn maxf(float(card.get(\"seconds\", 0.0)), 0.0)",
		"\tvar made: Resource = own_card_of(card)",
		"\tif made == null or not made.has_method(\"length\"):",
		"\t\treturn 0.0",
		"\treturn maxf(float(made.call(\"length\")), 0.0)",
		"",
		"## Plays a card of your own: a fresh copy holding the card's values, told which player is playing it, and",
		"## kept until the list is stopped or restored so it can be told to stop or put things back.",
		"func _play_own_card(card: Dictionary, at: float) -> void:",
		"\tvar made: Resource = own_card_of(card)",
		"\tif made == null:",
		"\t\t_card_missing(card, \"names a card script that is not in the project\")",
		"\t\treturn",
		"\tif \"player\" in made:",
		"\t\tmade.set(\"player\", self)",
		"\t_own_running.append(made)",
		"\tif _own_running.size() > MOST_OWN_RUNNING:",
		"\t\t_own_running.remove_at(0)",
		"\tmade.call(\"play\", host, at)",
		"",
		"## Tells every card of your own that is still going to `stop` or `restore`. A card is let go of once it has",
		"## been told to put things back, so a Stop followed by a Restore reaches it twice.",
		"func _told_own(what: String) -> void:",
		"\tfor made: Resource in _own_running:",
		"\t\tif is_instance_valid(made) and made.has_method(what):",
		"\t\t\tmade.call(what)",
		"\tif what == \"restore\":",
		"\t\t_own_running.clear()",
		"",
		"## The sound a card names, or null when it names none or the file is not there.",
		"static func _stream_at(path: String) -> AudioStream:",
		"\tif path.is_empty() or not ResourceLoader.exists(path):",
		"\t\treturn null",
		"\treturn load(path) as AudioStream",
		"",
		"## A voice of the kind asked for: a free one if there is one, else a new one while there is room, else",
		"## the oldest one taken over (and made the kind asked for).",
		"func _voice_for(kind: String) -> Node:",
		"\tfor index: int in range(_voices.size() - 1, -1, -1):",
		"\t\tif not is_instance_valid(_voices[index]):",
		"\t\t\t_voices.remove_at(index)",
		"\tfor voice: Node in _voices:",
		"\t\tif voice.get_class() == kind and not bool(voice.get(\"playing\")):",
		"\t\t\treturn voice",
		"\tif _voices.size() < SOUND_VOICES:",
		"\t\tvar fresh: Node = ClassDB.instantiate(kind) as Node",
		"\t\tadd_child(fresh)",
		"\t\t_voices.append(fresh)",
		"\t\treturn fresh",
		"\tvar slot: int = _next_voice % _voices.size()",
		"\t_next_voice += 1",
		"\tvar taken: Node = _voices[slot]",
		"\tif taken.get_class() == kind:",
		"\t\ttaken.call(\"stop\")",
		"\t\treturn taken",
		"\ttaken.queue_free()",
		"\tvar replacement: Node = ClassDB.instantiate(kind) as Node",
		"\tadd_child(replacement)",
		"\t_voices[slot] = replacement",
		"\treturn replacement",
		"",
		"## Says what is wrong with a Sound card once, naming this player and the card.",
		"func _tell_sound(card: Dictionary, what: String) -> void:",
		"\tvar told: String = _label_of(card) + what",
		"\tif _told_sound.has(told):",
		"\t\treturn",
		"\t_told_sound[told] = true",
		"\tpush_warning(\"Juice Player: the sound card \\\"%s\\\" on %s %s\" % [_label_of(card), name, what])",
		"",
		"",
		"## How much of the cards above is still to run when a Hold is reached - the number the Hold waits for.",
		"## Read off the same pass the plan reads: the latest END of the cards since the last Hold (their delays and",
		"## repeats counted), or only the end of the card the Hold names when it names one that is there (a name that",
		"## is no card above waits for the slowest, as a Hold that names nothing does), less the time the head has",
		"## already spent getting here.",
		"static func left_above(order: Array, index: int) -> float:",
		"\tvar walked: Dictionary = _timeline(order.slice(0, maxi(index, 0)))",
		"\tvar delay: float = 0.0",
		"\tvar wanted: String = \"\"",
		"\tif index >= 0 and index < order.size() and order[index] is Dictionary:",
		"\t\tdelay = maxf(float((order[index] as Dictionary).get(\"delay\", 0.0)), 0.0)",
		"\t\twanted = str((order[index] as Dictionary).get(\"waits_for\", \"\")).strip_edges()",
		"\tvar arrived: float = float(walked[\"at\"]) + delay",
		"\tvar until: float = float(walked[\"latest\"])",
		"\tif not wanted.is_empty() and (walked[\"ends\"] as Dictionary).has(wanted):",
		"\t\tuntil = float((walked[\"ends\"] as Dictionary)[wanted])",
		"\treturn maxf(until - arrived, 0.0)",
		"",
		"## The same number, asked of the walk's own copy of the list.",
		"func _longest_above(order: Array, index: int) -> float:",
		"\treturn left_above(order, index)",
		"",
		"## Where a Loop Back sends the head: the nearest Hold or Loop Start above it that the card is willing",
		"## to land on. -1 when there is none, which makes the loop a step that does nothing.",
		"func _loop_target(order: Array, index: int, card: Dictionary) -> int:",
		"\tvar to_hold: bool = bool(card.get(\"to_hold\", true))",
		"\tvar to_start: bool = bool(card.get(\"to_loop_start\", true))",
		"\tvar walk: int = index - 1",
		"\twhile walk >= 0:",
		"\t\tvar word: String = word_of(order[walk] as Dictionary)",
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
		"\t_ends_at = _started_at",
		"\t_order = order",
		"\t_head = 0",
		"\t_head_strength = at_strength",
		"\t_head_taken = false",
		"\t_nested.clear()",
		"\t_waiting.clear()",
		"\t_loops_left.clear()",
		"\t_rolls.clear()",
		"\tfor index: int in order.size():",
		"\t\tif order[index] is Dictionary:",
		"\t\t\t_loops_left[index] = int((order[index] as Dictionary).get(\"loops\", 1))",
		"\t\t\t_rolls[index] = randf() * 100.0",
		"\t_tell_juice_began(order)",
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
		"\t_remove_waiting()",
		"",
		"## When each card of a list starts and how long it lasts: [{card, at, seconds}], in list order. A",
		"## stretch between two holds starts together, a Pause pushes everything under it along, and the",
		"## loops are left out because a plan is what one pass looks like. The Inspector's timeline and the",
		"## editor preview both read this, so the picture and the sample can never disagree.",
		"## @ace_hidden",
		"static func schedule_of(list: Array) -> Array:",
		"\treturn _timeline(list)[\"plan\"]",
		"",
		"## How far through a play of a card an editor preview is `time` seconds into the list: 0 to 1 while one of the",
		"## card's plays (the first, or a repeat) is going, -1 when none is. The preview, the lit marks on the cards and",
		"## the sample of a card all ask this, so a card that repeats is seen repeating in the editor.",
		"## @ace_hidden",
		"static func through_at(plan: Dictionary, time: float) -> float:",
		"\tvar span: float = maxf(float(plan.get(\"seconds\", 0.0)), 0.05)",
		"\tvar repeats: int = maxi(int(plan.get(\"repeat\", 1)), 1)",
		"\tvar gap: float = maxf(float(plan.get(\"every\", 0.0)), 0.0)",
		"\tfor pass_index: int in range(repeats):",
		"\t\tvar through: float = (time - float(plan.get(\"at\", 0.0)) - float(pass_index) * gap) / span",
		"\t\tif through >= 0.0 and through <= 1.0:",
		"\t\t\treturn through",
		"\treturn -1.0",
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
		"\t\tvar through: float = through_at(plan, time)",
		"\t\tif through < 0.0:",
		"\t\t\tcontinue",
		"\t\tvar amount: float = float(card.get(\"amount\", 1.0)) * at_strength",
		"\t\tvar word: String = word_of(card)",
		"\t\tif word == \"shake\":",
		"\t\t\t# A card with a tick or a curve draws the shape the running shake has; one without draws the fall",
		"\t\t\t# it always drew.",
		"\t\t\tvar level: float = 1.0 - through",
		"\t\t\tif MomentRunner.is_timed_shake(card):",
		"\t\t\t\tvar kept: String = str(card.get(\"curve\", \"\")).strip_edges()",
		"\t\t\t\tvar curve: Curve = load(kept) as Curve if not kept.is_empty() and ResourceLoader.exists(kept) else null",
		"\t\t\t\tlevel = MomentRunner.shake_shape(through, bool(card.get(\"fade_in\", false)), bool(card.get(\"fade_out\", false)), curve)",
		"\t\t\toffset += Vector2(sin(time * 47.0), cos(time * 53.0)) * amount * 8.0 * level",
		"\t\telif word == \"punch\":",
		"\t\t\tswell += amount * 0.2 * sin(through * PI)",
		"\t\telif word == TWEEN_PROPERTY and not card.has(\"node\") and not card.has(\"to\"):",
		"\t\t\tvar property: String = str(card.get(\"effect\", \"\"))",
		"\t\t\tif base.has(property) and (base[property] is float or base[property] is int):",
		"\t\t\t\twritten[property] = lerpf(float(base[property]), amount, through)",
		"\tif base.get(\"position\") is Vector2 and offset != Vector2.ZERO:",
		"\t\twritten[\"position\"] = (base[\"position\"] as Vector2) + offset",
		"\tif base.get(\"scale\") is Vector2 and not is_zero_approx(swell):",
		"\t\twritten[\"scale\"] = (base[\"scale\"] as Vector2) * (1.0 + swell)",
		"\treturn written",
		"",
		"## Puts every bus a Fade Bus card moved back to the volume it had.",
		"func _restore_buses() -> void:",
		"\tfor moved: Tween in _bus_tweens:",
		"\t\tif moved != null and moved.is_valid():",
		"\t\t\tmoved.kill()",
		"\t_bus_tweens.clear()",
		"\tfor key: Variant in _bus_restore:",
		"\t\tvar index: int = AudioServer.get_bus_index(str(key))",
		"\t\tif index >= 0:",
		"\t\t\tAudioServer.set_bus_volume_db(index, float(_bus_restore[key]))",
		"\t_bus_restore.clear()",
		"",
		"## What the editor can show of a card's word: \"felt\" when it plays for real (a shake, a punch, a",
		"## tweened property, a sound, and the cards that move another node), \"time\" when the editor shows only its length (a wait, a loop word,",
		"## and the two that change the game's time), and \"skipped:<why>\" for the rest, with the reason in",
		"## words. One answer for the Inspector's play buttons, Debug view and the guide.",
		"## @ace_hidden",
		"static func editor_kind(word: String) -> String:",
		"\tmatch word:",
		"\t\t\"shake\", \"punch\", TWEEN_PROPERTY, SOUND, PARTICLES, ANIMATION, SPRITE_ANIMATION, SHOW_HIDE, SQUASH_STRETCH, PUNCH_POSITION, PUNCH_ROTATION, POP, FADE, COUNT_TO, REVEAL_TEXT, FILL_BAR, SHADER_VALUE, LOOK_AT, ROTATE_BY, ROTATE_TO, ROTATION_SHAKE, DRAW_ORDER, LIGHT, POSITION_SHAKE, GRAYSCALE:",
		"\t\t\treturn \"felt\"",
		"\t\tPAUSE, HOLD_UNTIL, LOOP_START, LOOP_BACK, \"hitstop\", \"slowmo\":",
		"\t\t\treturn \"time\"",
		"\t\tSTOP_SOUND:",
		"\t\t\treturn \"skipped:it ends a sound the running game started\"",
		"\t\tFADE_BUS:",
		"\t\t\treturn \"skipped:it moves a bus volume, which the editor leaves alone\"",
		"\t\tVIBRATE:",
		"\t\t\treturn \"skipped:a controller or a phone is not in the editor\"",
		"\t\tGRAB_FOCUS:",
		"\t\t\treturn \"skipped:focus belongs to the running game\"",
		"\t\tPUSH, FORCE_FOR_A_TIME, GRAVITY_FOR_A_TIME, FREEZE_BODY:",
		"\t\t\treturn \"skipped:not shown in the editor, physics needs the running game\"",
		"\t\tCOLLISION_FOR, COLLISION_LAYER_FOR:",
		"\t\t\treturn \"skipped:not shown in the editor, physics needs the running game\"",
		"\t\tREMOVE_NODE:",
		"\t\t\treturn \"skipped:it would remove a node from your scene\"",
		"\t\tSWITCH_NODE:",
		"\t\t\treturn \"skipped:it would switch a node of your scene off\"",
		"\t\tSCENE_LOOK:",
		"\t\t\treturn \"skipped:it would change the look the editor saves\"",
		"\t\tBUS_EFFECT:",
		"\t\t\treturn \"skipped:the editor's buses are the project's own\"",
		"\t\tSPRING:",
		"\t\t\treturn \"skipped:a spring needs the running game's Spring node\"",
		"\t\tSLOW_OBJECT:",
		"\t\t\treturn \"skipped:it would slow the animations of your scene in the editor\"",
		"\t\tANIMATION_PARAMETER:",
		"\t\t\treturn \"skipped:an animation tree runs in the game\"",
		"\t\tSPAWN_SCENE:",
		"\t\t\treturn \"skipped:not shown in the editor, it adds a scene to the running game\"",
		"\t\tCALL_METHOD:",
		"\t\t\treturn \"skipped:not shown in the editor, it would run your own code\"",
		"\t\tEMIT_SIGNAL:",
		"\t\t\treturn \"skipped:a signal runs the game's own code\"",
		"\t\tPLAY_PLAYER:",
		"\t\t\treturn \"skipped:another player runs its own list\"",
		"\treturn \"skipped:the running game draws it\""
	])


## The second half of the runtime: everything the rows that EDIT a list are built on. A list is
## edited in the Inspector by dragging cards and in the game by naming them, and the two have to
## mean the same thing - so a card's LABEL is the address, the address is resolved in exactly one
## place, and a row that names a card nobody has says so rather than doing nothing.
static func _addressing_lines() -> PackedStringArray:
	return PackedStringArray([
		"# --- Addressed by label: the rows that edit the list while the game runs ---",
		"# Every row that names one juice card names it by its LABEL - the name typed on the card in the",
		"# Inspector, or, for a card nobody named, its own word. That is the whole addressing scheme: a",
		"# list tuned in the Inspector and a list retuned by rows can never disagree about which step is",
		"# meant, and a label that is not in the list is said out loud rather than quietly ignored.",
		"",
		"# An OVERRIDE list: a word that is",
		"# not in it belongs to no family, so Mute Juice Family leaves it alone, and a card carrying",
		"# its own `category` key answers with that instead of with this. It is the RUNTIME copy of the",
		"# question, and the editor's card list takes its stripe colours from here rather than keeping a",
		"# second one, so a word can only ever have one family.",
		"## Which family a card belongs to when it does not say so itself.",
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
		"\t\"play_player\": \"signal\",",
		"\t\"sound\": \"audio\",",
		"\t\"stop_sound\": \"audio\",",
		"\t\"fade_bus\": \"audio\",",
		"\t\"vibrate\": \"device\",",
		"\t\"tween_property\": \"transform\",",
		"\t\"particles\": \"scene\",",
		"\t\"spawn_scene\": \"scene\",",
		"\t\"push\": \"scene\",",
		"\t\"force_for_a_time\": \"scene\",",
		"\t\"gravity_for_a_time\": \"scene\",",
		"\t\"freeze_body\": \"scene\",",
		"\t\"animation\": \"transform\",",
		"\t\"sprite_animation\": \"transform\",",
		"\t\"show_hide\": \"transform\",",
		"\t\"squash_stretch\": \"transform\",",
		"\t\"punch_position\": \"transform\",",
		"\t\"punch_rotation\": \"transform\",",
		"\t\"pop\": \"transform\",",
		"\t\"fade\": \"transform\",",
		"\t\"grab_focus\": \"transform\",",
		"\t\"count_to\": \"transform\",",
		"\t\"reveal_text\": \"transform\",",
		"\t\"fill_bar\": \"transform\",",
		"\t\"shader_value\": \"transform\",",
		"\t\"call_method\": \"signal\",",
		"\t\"pause_player\": \"signal\",",
		"\t\"collision_for\": \"scene\",",
		"\t\"collision_layer_for\": \"scene\",",
		"\t\"remove_node\": \"scene\",",
		"\t\"draw_order\": \"scene\",",
		"\t\"switch_node\": \"scene\",",
		"\t\"look_at\": \"transform\",",
		"\t\"rotate_by\": \"transform\",",
		"\t\"rotate_to\": \"transform\",",
		"\t\"rotation_shake\": \"transform\",",
		"\t\"light\": \"scene\",",
		"\t\"scene_look\": \"screen\",",
		"\t\"bus_effect\": \"audio\",",
		"\t\"spring\": \"transform\",",
		"\t\"slow_object\": \"pause\",",
		"\t\"animation_parameter\": \"transform\",",
		"\t\"chromatic_shake\": \"screen\",",
		"\t\"grayscale\": \"screen\",",
		"\t\"position_shake\": \"transform\"",
		"}",
		"",
		"## Keys that Set Juice Card Field and Juice Card Field accept.",
		"const FIELD_KEYS: PackedStringArray = [\"amount\", \"effect\", \"seconds\", \"delay\", \"interval\", \"repeat\", \"chance\", \"loops\"]",
		"## The keys beyond the eight above that the Set Juice Card Field row writes on any card: the clock and the strength window of the Timing foldout.",
		"const TIMING_FIELD_KEYS: PackedStringArray = [\"clock\", \"min_strength\", \"max_strength\"]",
		"## The keys a moment file's step can hold, plus the two every card carries that a file has no use for: its label and its switch.",
		"const MOMENT_KEYS: PackedStringArray = [\"verb\", \"amount\", \"effect\", \"seconds\", \"label\", \"active\"]",
		"",
		"## The keys of a card that a moment file would leave off: everything but its kind, amount, effect and seconds,",
		"## and the label and switch every card carries. Save Moment File names them before it writes, so nothing",
		"## a card holds is dropped without being said.",
		"## @ace_hidden",
		"static func keys_a_file_drops(card: Dictionary) -> PackedStringArray:",
		"	var dropped: PackedStringArray = PackedStringArray()",
		"	for key: Variant in card:",
		"		if not MOMENT_KEYS.has(str(key)):",
		"			dropped.append(str(key))",
		"	return dropped",
		"",
		"## What Save Moment File says before it writes: the cards it left out of the file altogether, and the keys it left",
		"## off the cards it kept, each in a sentence that names this player. Nothing a card holds is dropped unsaid.",
		"## @ace_hidden",
		"func _moment_file_notes(left_behind: PackedStringArray, left_keys: PackedStringArray) -> PackedStringArray:",
		"	var notes: PackedStringArray = PackedStringArray()",
		"	if not left_behind.is_empty():",
		"		notes.append(\"Juice Player: a moment file holds the ten moment words only - no timing, no card that is switched off, and none of this node's own three (a property tween, a signal, a nested player) - so %s left these out of the file: %s.\" % [name, \", \".join(left_behind)])",
		"	if not left_keys.is_empty():",
		"		notes.append(\"Juice Player: a moment file holds a card's kind, amount, effect and seconds and nothing else, so %s left these off the cards it kept: %s.\" % [name, \"; \".join(left_keys)])",
		"	return notes",
		"",
		"## Juice families muted right now.",
		"var _muted: Dictionary = {}",
		"",
		"## The list whose cards this player has copied for itself; until then they are shared with scene copies.",
		"var _owned_steps: Array[Dictionary] = []",
		"",
		"## Labels to skip once on the next play, removed as they are used.",
		"var _skip_once: Dictionary = {}",
		"",
		"## True while a Hold Here is holding the play still on its current card.",
		"var _held: bool = false",
		"## Label of the card a Jump To Juice Card asked to carry on from, or empty.",
		"var _jump_to: String = \"\"",
		"",
		"## When this play began, on the wall clock, so one card's own progress can be answered without a tick running to count it.",
		"var _started_at: float = 0.0",
		"",
		"## The name one card answers to: what it was called in the list, or its own word when it was never",
		"## named. THE ONE PLACE a label is derived, so every row addresses cards identically, and a Hold that",
		"## waits for one card names it the same way.",
		"## @ace_hidden",
		"static func card_label(card: Dictionary) -> String:",
		"\tvar named: String = str(card.get(\"label\", \"\")).strip_edges()",
		"\treturn named if not named.is_empty() else str(card.get(\"verb\", \"\")).strip_edges()",
		"",
		"## The same name, asked of the card by this node.",
		"func _label_of(card: Dictionary) -> String:",
		"\treturn card_label(card)",
		"",
		"## Which family a card belongs to: its own word for it when it carries one, else the family its",
		"## word belongs to, else none at all.",
		"func _category_of(card: Dictionary) -> String:",
		"\tvar said: String = str(card.get(\"category\", \"\")).strip_edges().to_lower()",
		"\tif not said.is_empty():",
		"\t\treturn said",
		"\treturn str(CATEGORY_OF.get(word_of(card), \"\"))",
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
		"## Said when a row names a juice card this player has not got. A warning rather than an error,",
		"## because the rest of the beat is still worth playing; in the editor the same mistake is a quiet",
		"## finding on the row itself, which is where it can actually be fixed.",
		"func _no_such(label: String, row: String) -> void:",
		"\tpush_warning(\"Juice Player: %s has no juice card labelled \\\"%s\\\", so %s did nothing.\" % [name, label, row])",
		"",
		"## The list the EDIT rows work on: this player's own. A player whose moment-file slot is filled is",
		"## playing a beat two other objects may be playing too, and an edit row must never write into that",
		"## file - so the first edit takes a copy of it into this list and lets the slot go. The beat is",
		"## unchanged; it is simply this object's own now. The same goes for the list itself: copies of one",
		"## scene share the card dictionaries inside it, so the first edit also swaps every card for a copy",
		"## made in place (the list keeps its identity, so a play already walking it carries on). A player",
		"## nothing ever edits copies nothing. A stream, a curve or any other resource on a card stays the",
		"## very same resource; only the dictionaries and arrays around it are copied.",
		"func _own_list() -> Array:",
		"\tif moment_file != null:",
		"\t\tvar carried: Variant = moment_file.get(\"steps\")",
		"\t\tsteps.clear()",
		"\t\tif carried is Array:",
		"\t\t\tfor entry: Variant in carried as Array:",
		"\t\t\t\tif entry is Dictionary:",
		"\t\t\t\t\tsteps.append((entry as Dictionary).duplicate(true))",
		"\t\tmoment_file = null",
		"\t\t_owned_steps = steps",
		"\t\treturn steps",
		"\tif not is_same(_owned_steps, steps):",
		"\t\tfor at: int in range(steps.size()):",
		"\t\t\tsteps[at] = (steps[at] as Dictionary).duplicate(true)",
		"\t\t_owned_steps = steps",
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
		"\t# A card of your own holds the keys of its own exports and nothing a moment file's step has, so its",
		"\t# `seconds` is the one it exports or none at all.",
		"\tif step.has(\"card_script\"):",
		"\t\treturn step.duplicate()",
		"\tvar card: Dictionary = {\"verb\": \"\", \"amount\": 1.0, \"effect\": \"\", \"seconds\": 0.0}",
		"\tfor key: Variant in step:",
		"\t\tcard[key] = step[key]",
		"\treturn card",
		"",
		"## Where the head goes when Jump To Juice Card has been asked for: the label's place in the order",
		"## being walked, or where the head was going anyway. Asked once per step, and it reads an empty",
		"## string in every play nobody jumped in.",
		"func _landing(order: Array, index: int) -> int:",
		"\tif _jump_to.is_empty():",
		"\t\treturn index",
		"\tvar landed: int = _index_in(order, _jump_to)",
		"\tif landed < 0:",
		"\t\t_no_such(_jump_to, \"Jump To Juice Card\")",
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
		"## Every label in the list, in order - what For Each Juice Card loops over, and what a settings",
		"## screen that lists a beat's parts is built out of.",
		"## @ace_looping(feedback_label)",
		"## @ace_name(\"For Each Juice Card\")",
		"## @ace_category(\"Juice Player\")",
		"## @ace_description(\"Runs the actions under it once per juice card in this player's list, top to bottom, with the label of each one in hand.\")",
		"func for_each_feedback() -> Array:",
		"\tvar labels: Array = []",
		"\tfor entry: Variant in _steps_now():",
		"\t\tif entry is Dictionary:",
		"\t\t\tlabels.append(_label_of(entry as Dictionary))",
		"\treturn labels"
	])


## The fourth part of the runtime: the cards that change the scene, the light, the look and the sound, and the
## holds that put each of them back. One small function per card, like the part before it.
static func _scene_card_lines() -> PackedStringArray:
	return PackedStringArray([
		"# --- Cards that change the scene, the light, the look and the sound ---",
		"# A \"for a time\" card changes a value and puts it back when its time is up. Two cards can change the same value",
		"# (a collision shape switched off by a hit and again by a dodge): it goes back when the LAST of them is done, to",
		"# what it was before the FIRST touched it, so an overlap can never leave a shape off for good. Stop, Restore and",
		"# the player leaving the scene put everything back at once. Where Godot refuses a change in the middle of a",
		"# physics step (a shape's disabled tick, a layer, a mask) the change is made at the safe moment instead.",
		"",
		"## What every player's cards hold changed right now, by object, property and layer: the value from before, and who holds it.",
		"static var _holds: Dictionary = {}",
		"",
		"## The number the next hold takes as its ticket, so a timer that outlives a Stop can never end a later hold.",
		"static var _next_hold: int = 0",
		"",
		"## The ways back of a bus effect, each a Callable, kept until its time is up or the play ends.",
		"var _ways_back: Array[Callable] = []",
		"",
		"## The lights this player has flaring and will let go back by themselves, with what each rested at, until the flare is over.",
		"var _flares: Array[Dictionary] = []",
		"",
		"## The effects a Bus Effect card added because its bus lacked them, by bus and kind: the effect, and how many cards still hold it.",
		"static var _added_effects: Dictionary = {}",
		"",
		"## The nodes a Remove Node card is holding back until this list has finished.",
		"var _removals: Array[Node] = []",
		"",
		"## The classes of a collision shape, the nodes a card can switch off.",
		"const SHAPE_CLASSES: PackedStringArray = [\"CollisionShape2D\", \"CollisionShape3D\", \"CollisionPolygon2D\", \"CollisionPolygon3D\"]",
		"",
		"## The most a 2D node can be drawn in front of or behind the rest: Godot refuses a z index past it.",
		"const MOST_Z_INDEX: int = 4096",
		"",
		"## How many times a second a rotation shake swings from one side to the other and back.",
		"const SHAKE_HERTZ: float = 12.0",
		"",
		"## The words whose effect a skip to the end leaves out, because they last only a time and the skip is already past it.",
		"const LASTS_ONLY_A_TIME: PackedStringArray = [",
		"\t\"collision_for\", \"collision_layer_for\", \"draw_order\", \"switch_node\", \"rotation_shake\", \"light\", \"scene_look\", \"bus_effect\",",
		"\t\"spring\", \"slow_object\", \"animation_parameter\", \"chromatic_shake\", \"position_shake\"",
		"]",
		"",
		"## The switch a value of the look does nothing without, by the start of its name. The longest start comes first.",
		"const LOOK_SWITCHES: Array = [",
		"\t[\"volumetric_fog_\", \"volumetric_fog_enabled\"], [\"adjustment_\", \"adjustment_enabled\"], [\"glow_\", \"glow_enabled\"], [\"fog_\", \"fog_enabled\"]",
		"]",
		"",
		"## Changes one property of an object, and says which hold it is. The first hold on a property writes down what it was",
		"## (the way back goes there, and so does Restore); later holds on the same property only add themselves. `layer` is 0",
		"## for a whole property, or a layer number from 1 to 32 when the thing held is one layer or one mask bit. `deferred`",
		"## writes at the safe moment, which Godot asks for on a shape, a layer and a mask.",
		"func _hold(target: Object, property: String, value: Variant, deferred: bool = false, layer: int = 0) -> Dictionary:",
		"\tif target == null or not is_instance_valid(target):",
		"\t\treturn {}",
		"\tvar key: String = \"%d|%s|%d\" % [target.get_instance_id(), property, layer]",
		"\tvar hold: Dictionary = _holds.get(key, {})",
		"\tvar first_value: Variant = target.get(property)",
		"\tif hold.is_empty():",
		"\t\tvar before: Variant = first_value",
		"\t\tif layer > 0:",
		"\t\t\tbefore = bool(target.call(\"get_%s_value\" % property, layer))",
		"\t\thold = {\"object\": target, \"property\": property, \"layer\": layer, \"deferred\": deferred, \"before\": before, \"tickets\": []}",
		"\t\t_holds[key] = hold",
		"\telif layer == 0:",
		"\t\tfirst_value = hold[\"before\"]",
		"\t_keep_first(target, property, first_value)",
		"\t_next_hold += 1",
		"\t(hold[\"tickets\"] as Array).append({\"id\": _next_hold, \"owner\": get_instance_id()})",
		"\t_put(hold, value)",
		"\treturn {\"key\": key, \"ticket\": _next_hold}",
		"",
		"## Writes a value to the object a hold is on: the whole property, or one layer of it.",
		"static func _put(hold: Dictionary, value: Variant) -> void:",
		"\tvar object: Object = hold[\"object\"] as Object",
		"\tvar property: String = str(hold[\"property\"])",
		"\tif int(hold[\"layer\"]) > 0:",
		"\t\tobject.call_deferred(\"set_%s_value\" % property, int(hold[\"layer\"]), bool(value))",
		"\telif bool(hold[\"deferred\"]):",
		"\t\tobject.set_deferred(property, value)",
		"\telse:",
		"\t\tobject.set(property, value)",
		"",
		"## Holds a property for `seconds` and then lets it go. With no scene tree to count the time in, the hold is let go at",
		"## once.",
		"func _hold_for(target: Object, property: String, value: Variant, seconds: float, deferred: bool = false, layer: int = 0) -> void:",
		"\tvar ticket: Dictionary = _hold(target, property, value, deferred, layer)",
		"\tif ticket.is_empty():",
		"\t\treturn",
		"\tif not is_inside_tree():",
		"\t\t_end_hold(ticket)",
		"\t\treturn",
		"\tget_tree().create_timer(maxf(seconds, 0.0)).timeout.connect(_end_hold.bind(ticket))",
		"",
		"## Lets one hold go. When it was the last on its property, the property goes back to what it was before the first.",
		"static func _end_hold(ticket: Dictionary) -> void:",
		"\tvar key: String = str(ticket.get(\"key\", \"\"))",
		"\tvar held: Dictionary = _holds.get(key, {})",
		"\tif held.is_empty():",
		"\t\treturn",
		"\tvar tickets: Array = held[\"tickets\"]",
		"\tfor index: int in range(tickets.size()):",
		"\t\tif int((tickets[index] as Dictionary)[\"id\"]) == int(ticket.get(\"ticket\", 0)):",
		"\t\t\ttickets.remove_at(index)",
		"\t\t\tbreak",
		"\tif not tickets.is_empty():",
		"\t\treturn",
		"\t_holds.erase(key)",
		"\t_give_back(held)",
		"",
		"## Puts a held property back to what it was before the first card, unless the object is gone.",
		"static func _give_back(held: Dictionary) -> void:",
		"\tvar object: Object = held.get(\"object\") as Object",
		"\tif object != null and is_instance_valid(object):",
		"\t\t_put(held, held[\"before\"])",
		"",
		"## Lets every hold of THIS player go at once, which is what Stop, Restore and leaving the scene do. A thing another",
		"## player is still holding stays held until that one lets go.",
		"func _release_holds() -> void:",
		"\tvar mine: int = get_instance_id()",
		"\tfor key: String in _holds.keys():",
		"\t\tvar held: Dictionary = _holds[key]",
		"\t\tvar tickets: Array = held[\"tickets\"]",
		"\t\tvar before: int = tickets.size()",
		"\t\tfor index: int in range(tickets.size() - 1, -1, -1):",
		"\t\t\tif int((tickets[index] as Dictionary)[\"owner\"]) == mine:",
		"\t\t\t\ttickets.remove_at(index)",
		"\t\tif before > 0 and tickets.is_empty():",
		"\t\t\t_holds.erase(key)",
		"\t\t\t_give_back(held)",
		"",
		"## Keeps a way back for a change no node holds, and takes it when the time is up. With no scene tree to count in, it",
		"## is taken at once.",
		"func _way_back_in(seconds: float, back: Callable) -> void:",
		"\t_ways_back.append(back)",
		"\tif not is_inside_tree():",
		"\t\t_take_way_back(back)",
		"\t\treturn",
		"\tget_tree().create_timer(maxf(seconds, 0.0)).timeout.connect(_take_way_back.bind(back))",
		"",
		"## Takes one way back, once.",
		"func _take_way_back(back: Callable) -> void:",
		"\tif not _ways_back.has(back):",
		"\t\treturn",
		"\t_ways_back.erase(back)",
		"\tif back.is_valid():",
		"\t\tback.call()",
		"",
		"## Takes every way back at once.",
		"func _take_ways_back() -> void:",
		"\tfor back: Callable in _ways_back.duplicate():",
		"\t\t_take_way_back(back)",
		"",
		"## Whether a node is a collision shape or a collision polygon, in 2D or in 3D.",
		"static func _is_shape(node: Node) -> bool:",
		"\tfor named: String in SHAPE_CLASSES:",
		"\t\tif node.is_class(named):",
		"\t\t\treturn true",
		"\treturn false",
		"",
		"## Every collision shape at or under a node.",
		"static func _shapes_under(root: Node) -> Array[Node]:",
		"\tvar found: Array[Node] = []",
		"\tif _is_shape(root):",
		"\t\tfound.append(root)",
		"\tfor named: String in SHAPE_CLASSES:",
		"\t\tfor shape: Node in root.find_children(\"*\", named, true, false):",
		"\t\t\tfound.append(shape)",
		"\treturn found",
		"",
		"## Hands a node back to its pool, or frees it, through the file that decides which.",
		"func _retire(target: Node) -> void:",
		"\tif not is_instance_valid(target) or target.is_queued_for_deletion():",
		"\t\treturn",
		"\tvar pool: String = \"res://eventsheet_addons/pooled_nodes.gd\"",
		"\tif ResourceLoader.exists(pool):",
		"\t\t(load(pool) as Script).call(\"retire\", target)",
		"\telse:",
		"\t\ttarget.queue_free()",
		"",
		"## Removes the nodes that waited for the end of the list.",
		"func _remove_waiting() -> void:",
		"\tvar waiting: Array[Node] = _removals.duplicate()",
		"\t_removals.clear()",
		"\tfor target: Node in waiting:",
		"\t\t_retire(target)",
		"",
		"## One step of a 3D turn: the node's angle `through` of the way from where it was to where it faces, keeping its size",
		"## and its place.",
		"func _turn_towards(through: float, node: Node3D, from_turn: Quaternion, goal_turn: Quaternion) -> void:",
		"\tif not is_instance_valid(node):",
		"\t\treturn",
		"\tvar now: Transform3D = node.global_transform",
		"\tnode.global_transform = Transform3D(Basis(from_turn.slerp(goal_turn, through)).scaled(now.basis.get_scale()), now.origin)",
		"",
		"## One step of a rotation shake: the angle at rest plus a swing the shape of the shake makes smaller or larger. The",
		"## last step is the rest itself.",
		"func _shake_turn(through: float, node: Node, path: NodePath, rest: float, radians: float, span: float, fade_in: bool, fade_out: bool, curve: Curve) -> void:",
		"\tif not is_instance_valid(node):",
		"\t\treturn",
		"\tif through >= 1.0:",
		"\t\tnode.set_indexed(path, rest)",
		"\t\treturn",
		"\tnode.set_indexed(path, rest + radians * MomentRunner.shake_shape(through, fade_in, fade_out, curve) * sin(through * span * TAU * SHAKE_HERTZ))",
		"",
		"## The three names a light answers to: how bright it is, what colour it is, and what switches it on and off. A 2D",
		"## light says energy, color and enabled; a 3D light says light_energy, light_color and visible. Empty for a node that",
		"## is no light.",
		"## @ace_hidden",
		"static func light_properties(light: Node) -> Dictionary:",
		"\tif light is Light2D:",
		"\t\treturn {\"energy\": \"energy\", \"colour\": \"color\", \"on\": \"enabled\"}",
		"\tif light is Light3D:",
		"\t\treturn {\"energy\": \"light_energy\", \"colour\": \"light_color\", \"on\": \"visible\"}",
		"\treturn {}",
		"",
		"## Writes down a light that is flaring and will go back by itself, so a player that goes away before the flare is",
		"## over can put it back. Gives the note, which is what ends it.",
		"## @ace_hidden",
		"func _note_flare(light: Node, energy: String, colour: String, rest_energy: float, rest_colour: Color) -> Dictionary:",
		"\tvar flare: Dictionary = {\"light\": light, \"energy\": energy, \"colour\": colour, \"rest_energy\": rest_energy, \"rest_colour\": rest_colour}",
		"\t_flares.append(flare)",
		"\treturn flare",
		"",
		"## A flare ran its whole way: there is nothing to put back.",
		"func _forget_flare(flare: Dictionary) -> void:",
		"\t_flares.erase(flare)",
		"",
		"## Puts every light that is still flaring back to what it rested at, the way the other cards put their own back when",
		"## the player goes away. A Stop does not come here: it leaves a light where it got to.",
		"func _put_flares_back() -> void:",
		"\tfor flare: Dictionary in _flares:",
		"\t\tvar light: Object = flare.get(\"light\") as Object",
		"\t\tif light != null and is_instance_valid(light):",
		"\t\t\tlight.set(str(flare[\"energy\"]), flare[\"rest_energy\"])",
		"\t\t\tlight.set(str(flare[\"colour\"]), flare[\"rest_colour\"])",
		"\t_flares.clear()",
		"",
		"## A colour from what a card keeps: a colour, or the text of one.",
		"static func _colour_of(value: Variant) -> Color:",
		"\treturn value as Color if value is Color else Color(str(value))",
		"",
		"## The switch a value of the look does nothing without, or an empty word when it needs none.",
		"## @ace_hidden",
		"static func look_switch_of(property: String) -> String:",
		"\tfor entry: Array in LOOK_SWITCHES:",
		"\t\tif property.begins_with(str(entry[0])):",
		"\t\t\treturn str(entry[1])",
		"\treturn \"\"",
		"",
		"## The resources a node holds a look in, as the members that hold them.",
		"static func _look_members(holder: Node) -> PackedStringArray:",
		"\tif holder is WorldEnvironment:",
		"\t\treturn PackedStringArray([\"environment\", \"camera_attributes\"])",
		"\tif holder is Camera3D:",
		"\t\treturn PackedStringArray([\"environment\", \"attributes\"])",
		"\treturn PackedStringArray()",
		"",
		"## The file that sweeps a bus, or null when the project does not carry it.",
		"static func _bus_mix() -> Script:",
		"\tvar path: String = \"res://eventsheet_addons/bus_mix.gd\"",
		"\treturn load(path) as Script if ResourceLoader.exists(path) else null",
		"",
		"## Walks a bus back to where one kind of effect rested, on the root of the tree, which no scene change can free.",
		"## When this card added the effect, the last card to give it back takes it off the bus once the walk is done.",
		"func _sweep_back(bus: String, how: String, resting: float, over: float) -> void:",
		"\tvar mix: Script = _bus_mix()",
		"\tif mix != null and is_inside_tree():",
		"\t\tmix.call(\"sweep\", get_tree().root, bus, how, resting, over)",
		"\tif not _added_effects.has(bus + \"|\" + how):",
		"\t\treturn",
		"\tif over <= 0.0 or not is_inside_tree():",
		"\t\t_bus_let_go(bus, how)",
		"\telse:",
		"\t\tget_tree().create_timer(over).timeout.connect(Callable(get_script(), \"_bus_let_go\").bind(bus, how))",
		"",
		"## Takes one card's hold of the effect a way of changing a bus runs through. An effect the bus lacks is added at its",
		"## end for the card, and taken off again by the last card to let go.",
		"static func _bus_hold(bus: String, how: String) -> void:",
		"\tvar index: int = AudioServer.get_bus_index(bus)",
		"\tif index < 0:",
		"\t\treturn",
		"\tvar key: String = bus + \"|\" + how",
		"\tif not _added_effects.has(key) and not _bus_has_kind(index, how):",
		"\t\t_added_effects[key] = {\"effect\": null, \"holds\": 0}",
		"\tvar mix: Script = _bus_mix()",
		"\tif mix != null:",
		"\t\tmix.call(\"arm\", bus, how)",
		"\tif _added_effects.has(key):",
		"\t\tvar added: Dictionary = _added_effects[key]",
		"\t\tif added[\"effect\"] == null:",
		"\t\t\tadded[\"effect\"] = _last_bus_effect_of(index, how)",
		"\t\tadded[\"holds\"] = int(added[\"holds\"]) + 1",
		"",
		"## Whether a bus carries an effect of the kind a way of changing it uses.",
		"static func _bus_has_kind(index: int, how: String) -> bool:",
		"\treturn _last_bus_effect_of(index, how) != null",
		"",
		"## The last effect of a bus that is the kind a way of changing it uses, or null.",
		"static func _last_bus_effect_of(index: int, how: String) -> AudioEffect:",
		"\tfor slot: int in range(AudioServer.get_bus_effect_count(index) - 1, -1, -1):",
		"\t\tvar effect: AudioEffect = AudioServer.get_bus_effect(index, slot)",
		"\t\tvar wanted: bool = effect is AudioEffectLowPassFilter",
		"\t\tif how == \"dive\":",
		"\t\t\twanted = effect is AudioEffectAmplify",
		"\t\telif how == \"wash\":",
		"\t\t\twanted = effect is AudioEffectReverb",
		"\t\tif wanted:",
		"\t\t\treturn effect",
		"\treturn null",
		"",
		"## Gives back one card's hold of an effect it added. The last card to let go takes the effect off the bus and forgets",
		"## where the bus rested, so the layout ends as it began.",
		"static func _bus_let_go(bus: String, how: String) -> void:",
		"\tvar key: String = bus + \"|\" + how",
		"\tvar added: Dictionary = _added_effects.get(key, {})",
		"\tif added.is_empty():",
		"\t\treturn",
		"\tadded[\"holds\"] = int(added[\"holds\"]) - 1",
		"\tif int(added[\"holds\"]) > 0:",
		"\t\treturn",
		"\t_added_effects.erase(key)",
		"\tvar index: int = AudioServer.get_bus_index(bus)",
		"\tif index >= 0 and added[\"effect\"] != null:",
		"\t\tfor slot: int in range(AudioServer.get_bus_effect_count(index)):",
		"\t\t\tif AudioServer.get_bus_effect(index, slot) == added[\"effect\"]:",
		"\t\t\t\tAudioServer.remove_bus_effect(index, slot)",
		"\t\t\t\tbreak",
		"\tvar mix: Script = _bus_mix()",
		"\tvar book: StringName = mix.get_script_constant_map().get(\"RESTING_META\", &\"\") if mix != null else &\"\"",
		"\tif book != &\"\" and Engine.has_meta(book):",
		"\t\tvar resting: Dictionary = Engine.get_meta(book)",
		"\t\tvar per_bus: Dictionary = resting.get(bus, {})",
		"\t\tper_bus.erase(how)",
		"\t\tif per_bus.is_empty():",
		"\t\t\tresting.erase(bus)",
		"",
		"## The engine nodes that have a speed of their own: what Slow One Object slows. An AnimationTree has none.",
		"const SPEED_CLASSES: PackedStringArray = [\"AnimationPlayer\", \"AnimatedSprite2D\", \"AnimatedSprite3D\", \"GPUParticles2D\", \"CPUParticles2D\",",
		"\t\t\"GPUParticles3D\", \"CPUParticles3D\"]",
		"",
		"## The parts of an AnimationTree parameter list that are the tree's own bookkeeping, written by the tree while it plays.",
		"const TREE_BOOKKEEPING: PackedStringArray = [\"fade_in_remaining\", \"fade_out_remaining\", \"time_to_restart\"]",
		"",
		"## The springs a Spring card has kicked and not yet seen land, by spring and property: the way back that settles each.",
		"var _springs_moving: Dictionary = {}",
		"",
		"## Every node at or under a node that has a speed of its own.",
		"## @ace_hidden",
		"static func speed_nodes_under(root: Node) -> Array[Node]:",
		"\tvar found: Array[Node] = []",
		"\tif root == null:",
		"\t\treturn found",
		"\tfor named: String in SPEED_CLASSES:",
		"\t\tif root.is_class(named):",
		"\t\t\tfound.append(root)",
		"\t\t\tbreak",
		"\tfor named: String in SPEED_CLASSES:",
		"\t\tfor node: Node in root.find_children(\"*\", named, true, false):",
		"\t\t\tif not found.has(node):",
		"\t\t\t\tfound.append(node)",
		"\treturn found",
		"",
		"## The Spring node that moves a node's values: the node itself, or the child that can kick a property.",
		"## @ace_hidden",
		"static func spring_of(node: Node) -> Node:",
		"\tif node == null:",
		"\t\treturn null",
		"\tif node.has_method(\"bump_property\"):",
		"\t\treturn node",
		"\tfor child: Node in node.get_children():",
		"\t\tif child.has_method(\"bump_property\"):",
		"\t\t\treturn child",
		"\treturn null",
		"",
		"## A kick in the kind of value the property holds: what a card keeps, made a number, two or three numbers or a colour,",
		"## and scaled by the strength of the play.",
		"## @ace_hidden",
		"static func spring_kick(amount: Variant, current: Variant, at: float) -> Variant:",
		"\tvar number: float = 1.0",
		"\tif amount is float or amount is int:",
		"\t\tnumber = float(amount)",
		"\telif amount is Vector2:",
		"\t\tnumber = (amount as Vector2).x",
		"\telif amount is Vector3:",
		"\t\tnumber = (amount as Vector3).x",
		"\telif amount is Color:",
		"\t\tnumber = (amount as Color).r",
		"\tmatch typeof(current):",
		"\t\tTYPE_VECTOR2:",
		"\t\t\treturn (amount as Vector2 if amount is Vector2 else Vector2(number, number)) * at",
		"\t\tTYPE_VECTOR3:",
		"\t\t\treturn (amount as Vector3 if amount is Vector3 else Vector3(number, number, number)) * at",
		"\t\tTYPE_COLOR:",
		"\t\t\treturn (amount as Color if amount is Color else Color(number, number, number, number)) * at",
		"\treturn number * at",
		"",
		"## Settles a spring at the value it rests on, at once: what a Stop does to a spring that is still bouncing.",
		"func _spring_rest(spring: Node, target: Node, property: String) -> void:",
		"\tif spring == null or not is_instance_valid(spring):",
		"\t\treturn",
		"\tvar entry: Variant = (spring.get(\"property_springs\") as Dictionary).get(property)",
		"\tif entry == null:",
		"\t\treturn",
		"\tentry.set(\"active\", false)",
		"\tentry.set(\"velocity\", Vector4.ZERO)",
		"\tentry.set(\"value\", entry.get(\"target\"))",
		"\tif target != null and is_instance_valid(target):",
		"\t\ttarget.set_indexed(NodePath(property), entry.call(\"unpack\"))",
		"",
		"## A spring landed by itself: there is nothing left for a Stop to settle.",
		"func _spring_landed(landed: String, spring: Node) -> void:",
		"\tvar key: String = \"%d|%s\" % [spring.get_instance_id(), landed]",
		"\tif _springs_moving.has(key):",
		"\t\t_ways_back.erase(_springs_moving[key])",
		"\t\t_springs_moving.erase(key)",
		"",
		"## The parameters of an AnimationTree a card may move: numbers, whole numbers, ticks and a Vector2 that are not read-only,",
		"## and not the playback object of a state machine or the timers a one-shot keeps for itself.",
		"## @ace_hidden",
		"static func writable_parameters(tree: AnimationTree) -> PackedStringArray:",
		"\tvar found: PackedStringArray = PackedStringArray()",
		"\tif tree == null:",
		"\t\treturn found",
		"\tfor entry: Dictionary in tree.get_property_list():",
		"\t\tvar named: String = str(entry.get(\"name\", \"\"))",
		"\t\tif not named.begins_with(\"parameters/\") or (int(entry.get(\"usage\", 0)) & PROPERTY_USAGE_READ_ONLY) != 0:",
		"\t\t\tcontinue",
		"\t\tif not [TYPE_FLOAT, TYPE_INT, TYPE_BOOL, TYPE_VECTOR2].has(int(entry.get(\"type\", TYPE_NIL))):",
		"\t\t\tcontinue",
		"\t\tif not TREE_BOOKKEEPING.has(named.get_file()):",
		"\t\t\tfound.append(named)",
		"\treturn found",
		"",
		"## Writes one parameter of an AnimationTree, unless the tree is gone.",
		"func _set_parameter(value: Variant, tree: AnimationTree, parameter: String) -> void:",
		"\tif is_instance_valid(tree):",
		"\t\ttree.set(parameter, value)",
		"",
		"## The number a way of changing a bus can take: a cutoff in hertz for a muffle, a level in decibels for a dive (an",
		"## amplify of +400 dB would be the end of the speakers), a share of wet for a wash.",
		"## @ace_hidden",
		"static func bus_value_for(how: String, value: float) -> float:",
		"\tmatch how:",
		"\t\t\"dive\":",
		"\t\t\treturn clampf(value, -80.0, 24.0)",
		"\t\t\"wash\":",
		"\t\t\treturn clampf(value, 0.0, 1.0)",
		"\treturn clampf(value, 20.0, 20500.0)"
	])


## The third part of the runtime: the cards that reach other nodes and the world. Written as
## plain statics and methods, one small function per card, so the emitted file reads like a
## hand-written one.
static func _world_card_lines() -> PackedStringArray:
	return PackedStringArray([
		"# --- Cards that reach other nodes: particles, animation, scenes, bodies, UI and shaders ---",
		"# A card of these words points at a node with a NodePath written relative to this player (the editor",
		"# fills it in with Godot's node picker), so a scene can be moved or copied and its cards still find",
		"# their nodes. A card that points at nothing acts on the object this player is under. A path that",
		"# finds no node is said ONCE, in the Output panel, and the card does nothing: it never raises an",
		"# error and never says it again on the next play.",
		"",
		"## Step word: restart, start or stop a particles node.",
		"const PARTICLES: String = \"particles\"",
		"## Step word: play a clip of an AnimationPlayer.",
		"const ANIMATION: String = \"animation\"",
		"## Step word: play an animation of an AnimatedSprite2D or AnimatedSprite3D.",
		"const SPRITE_ANIMATION: String = \"sprite_animation\"",
		"## Step word: show a node, hide it, or show it for a time.",
		"const SHOW_HIDE: String = \"show_hide\"",
		"## Step word: call a method of a node.",
		"const CALL_METHOD: String = \"call_method\"",
		"## Step word: add a copy of a scene to the running scene.",
		"const SPAWN_SCENE: String = \"spawn_scene\"",
		"## Step word: give a body one shove.",
		"const PUSH: String = \"push\"",
		"## Step word: a steady force on a RigidBody for a time.",
		"const FORCE_FOR_A_TIME: String = \"force_for_a_time\"",
		"## Step word: a different gravity scale on a RigidBody for a time.",
		"const GRAVITY_FOR_A_TIME: String = \"gravity_for_a_time\"",
		"## Step word: hold a RigidBody still for a time.",
		"const FREEZE_BODY: String = \"freeze_body\"",
		"## Step word: squash and stretch the object this player is under, through the Juice node.",
		"const SQUASH_STRETCH: String = \"squash_stretch\"",
		"## Step word: kick the position of the object this player is under, through the Juice node.",
		"const PUNCH_POSITION: String = \"punch_position\"",
		"## Step word: kick the rotation of the object this player is under, through the Juice node.",
		"const PUNCH_ROTATION: String = \"punch_rotation\"",
		"## Step word: scale a node up from its middle and let it settle.",
		"const POP: String = \"pop\"",
		"## Step word: fade a node through its modulate.",
		"const FADE: String = \"fade\"",
		"## Step word: give a Control the keyboard and gamepad focus.",
		"const GRAB_FOCUS: String = \"grab_focus\"",
		"## Step word: a label counts to a number.",
		"const COUNT_TO: String = \"count_to\"",
		"## Step word: the letters of a label appear one after another.",
		"const REVEAL_TEXT: String = \"reveal_text\"",
		"## Step word: a bar glides to a value.",
		"const FILL_BAR: String = \"fill_bar\"",
		"## Step word: move one value of the shader on a node.",
		"const SHADER_VALUE: String = \"shader_value\"",
		"## Step word: pause, resume or flip another Juice Player, or this one.",
		"const PAUSE_PLAYER: String = \"pause_player\"",
		"## Step word: switch a collision shape off for a time.",
		"const COLLISION_FOR: String = \"collision_for\"",
		"## Step word: take a body or an area off a collision layer, or stop it seeing one, for a time.",
		"const COLLISION_LAYER_FOR: String = \"collision_layer_for\"",
		"## Step word: free a node, or hand it back to its pool.",
		"const REMOVE_NODE: String = \"remove_node\"",
		"## Step word: draw a 2D node in front of the rest for a time.",
		"const DRAW_ORDER: String = \"draw_order\"",
		"## Step word: hide a node, stop its scripts or disable its collision, for a time or for good.",
		"const SWITCH_NODE: String = \"switch_node\"",
		"## Step word: turn a node to face another.",
		"const LOOK_AT: String = \"look_at\"",
		"## Step word: turn a node by an angle.",
		"const ROTATE_BY: String = \"rotate_by\"",
		"## Step word: turn a node to an angle.",
		"const ROTATE_TO: String = \"rotate_to\"",
		"## Step word: wobble the angle of a node and settle it.",
		"const ROTATION_SHAKE: String = \"rotation_shake\"",
		"## Step word: flare a light and let it go back.",
		"const LIGHT: String = \"light\"",
		"## Step word: move one value of the scene's look for a time.",
		"const SCENE_LOOK: String = \"scene_look\"",
		"## Step word: hold an effect of an audio bus for a time.",
		"const BUS_EFFECT: String = \"bus_effect\"",
		"## Step word: kick a value of a 2D node and let its Spring node settle it.",
		"const SPRING: String = \"spring\"",
		"## Step word: slow the animations and particles under a node for a time.",
		"const SLOW_OBJECT: String = \"slow_object\"",
		"## Step word: move one parameter of an AnimationTree and bring it back.",
		"const ANIMATION_PARAMETER: String = \"animation_parameter\"",
		"## Step word: split the screen's colours apart along a direction for a time and let them close.",
		"const CHROMATIC_SHAKE: String = \"chromatic_shake\"",
		"## Step word: put the colour out of the screen, all of it or a circle growing from a point.",
		"const GRAYSCALE: String = \"grayscale\"",
		"## Step word: shake the position of a node and put it back.",
		"const POSITION_SHAKE: String = \"position_shake\"",
		"",
		"## Every word this node plays itself that points at another node or at the world.",
		"const WORLD_WORDS: PackedStringArray = [",
		"\t\"particles\", \"animation\", \"sprite_animation\", \"show_hide\", \"call_method\", \"spawn_scene\", \"push\",",
		"\t\"force_for_a_time\", \"gravity_for_a_time\", \"freeze_body\", \"squash_stretch\", \"punch_position\",",
		"\t\"punch_rotation\", \"pop\", \"fade\", \"grab_focus\", \"count_to\", \"reveal_text\", \"fill_bar\", \"shader_value\", \"pause_player\",",
		"\t\"collision_for\", \"collision_layer_for\", \"remove_node\", \"draw_order\", \"switch_node\", \"look_at\", \"rotate_by\",",
		"\t\"rotate_to\", \"rotation_shake\", \"light\", \"scene_look\", \"bus_effect\", \"spring\", \"slow_object\", \"animation_parameter\", \"chromatic_shake\", \"grayscale\", \"position_shake\"",
		"]",
		"",
		"## Particles word: play the burst again from the start.",
		"const DO_RESTART: String = \"restart\"",
		"## Particles word: switch emitting on.",
		"const DO_START: String = \"start\"",
		"## Particles word: switch emitting off.",
		"const DO_STOP: String = \"stop\"",
		"## Show or Hide word: show the node.",
		"const DO_SHOW: String = \"show\"",
		"## Show or Hide word: hide the node.",
		"const DO_HIDE: String = \"hide\"",
		"## Show or Hide word: show the node for the card's seconds, then hide it.",
		"const DO_FLASH: String = \"flash\"",
		"",
		"## Push direction word: along a fixed direction.",
		"const PUSH_FIXED: String = \"fixed\"",
		"## Push direction word: away from a picked node.",
		"const PUSH_AWAY: String = \"away\"",
		"## Push direction word: the way the body is already moving.",
		"const PUSH_ALONG: String = \"along\"",
		"",
		"## The transition words of a Tween, as Godot names them.",
		"const TRANSITIONS: Dictionary = {",
		"\t\"linear\": Tween.TRANS_LINEAR, \"sine\": Tween.TRANS_SINE, \"quint\": Tween.TRANS_QUINT,",
		"\t\"quart\": Tween.TRANS_QUART, \"quad\": Tween.TRANS_QUAD, \"expo\": Tween.TRANS_EXPO,",
		"\t\"elastic\": Tween.TRANS_ELASTIC, \"cubic\": Tween.TRANS_CUBIC, \"circ\": Tween.TRANS_CIRC,",
		"\t\"bounce\": Tween.TRANS_BOUNCE, \"back\": Tween.TRANS_BACK, \"spring\": Tween.TRANS_SPRING",
		"}",
		"",
		"## The ease words of a Tween, as Godot names them.",
		"const EASES: Dictionary = {",
		"\t\"in\": Tween.EASE_IN, \"out\": Tween.EASE_OUT, \"in_out\": Tween.EASE_IN_OUT, \"out_in\": Tween.EASE_OUT_IN",
		"}",
		"",
		"## The cards that have already said their node is missing, by label, so it is said once.",
		"var _told_cards: Dictionary = {}",
		"",
		"## The materials a Shader Value card gave one node, by node id, so a second card reuses the copy.",
		"var _own_materials: Dictionary = {}",
		"",
		"## The forces a Force For A Time card is holding on bodies right now: body, force and the timer's end.",
		"var _held_forces: Array[Dictionary] = []",
		"",
		"## The path a card holds under a key, or an empty path when it holds none. A card written by hand may",
		"## hold the path as text, so both spellings read.",
		"static func _path_of(card: Dictionary, key: String) -> NodePath:",
		"\tvar stored: Variant = card.get(key, NodePath())",
		"\treturn stored if stored is NodePath else NodePath(str(stored))",
		"",
		"## The node a card points at, or null. A card that names none acts on the object this player is under",
		"## when `host_when_empty` is set, and on nothing otherwise.",
		"func _target(card: Dictionary, key: String, host_when_empty: bool) -> Node:",
		"\tvar path: NodePath = _path_of(card, key)",
		"\tif path.is_empty():",
		"\t\treturn host if host_when_empty else null",
		"\treturn get_node_or_null(path)",
		"",
		"## Says once that a card could not do its work, and tells On Juice Card Skipped why.",
		"func _card_missing(card: Dictionary, reason: String) -> void:",
		"\tvar label: String = _label_of(card)",
		"\ton_feedback_skipped.emit(label, \"target missing\")",
		"\tif _told_cards.has(label):",
		"\t\treturn",
		"\t_told_cards[label] = true",
		"\tpush_warning(\"Juice Player: the card \\\"%s\\\" on %s %s, so it did nothing.\" % [label, name, reason])",
		"",
		"## A tween of this player's own, kept so a Restore or a stop can end it. Tweens that have finished are let go.",
		"func _new_tween() -> Tween:",
		"\tfor held: int in range(_tweens.size() - 1, -1, -1):",
		"\t\tif not is_instance_valid(_tweens[held]) or not _tweens[held].is_running():",
		"\t\t\t_tweens.remove_at(held)",
		"\tvar made: Tween = create_tween()",
		"\t_tweens.append(made)",
		"\treturn made",
		"",
		"## Writes down what a property was, so Restore Initial Values can put it back.",
		"func _remember(object: Object, property: String) -> Variant:",
		"\tvar before: Variant = object.get_indexed(NodePath(property))",
		"\t_keep_first(object, property, before)",
		"\treturn before",
		"",
		"## The number a card's text means: a plain number, or a name read from the game - an autoload and then",
		"## its properties (\"GameState.score\"), else a property of the object this player is under. Null when",
		"## the text names nothing that holds a number.",
		"func _number_from(text: String) -> Variant:",
		"\tvar said: String = text.strip_edges()",
		"\tif said.is_empty():",
		"\t\treturn null",
		"\tif said.is_valid_float():",
		"\t\treturn said.to_float()",
		"\tvar parts: PackedStringArray = said.split(\".\")",
		"\tvar current: Variant = get_node_or_null(\"/root/\" + parts[0])",
		"\tif current == null and host != null:",
		"\t\tcurrent = host.get(parts[0])",
		"\tfor part: int in range(1, parts.size()):",
		"\t\tif not (current is Object):",
		"\t\t\treturn null",
		"\t\tcurrent = (current as Object).get(parts[part])",
		"\tif current is float or current is int:",
		"\t\treturn float(current)",
		"\treturn null",
		"",
		"## One world card, done. The words are the ones in WORLD_WORDS; `at` is the strength already multiplied",
		"## by this player's own, and `seconds` the card's length.",
		"func _play_world_card(word: String, card: Dictionary, at: float, seconds: float, skipping: bool = false) -> void:",
		"\tmatch word:",
		"\t\tPARTICLES:",
		"\t\t\t_particles(card)",
		"\t\tANIMATION:",
		"\t\t\t_animation(card, seconds)",
		"\t\tSPRITE_ANIMATION:",
		"\t\t\t_sprite_animation(card, seconds)",
		"\t\tSHOW_HIDE:",
		"\t\t\t_show_hide(card, seconds)",
		"\t\tCALL_METHOD:",
		"\t\t\t_call_method(card)",
		"\t\tSPAWN_SCENE:",
		"\t\t\t_spawn_scene(card)",
		"\t\tPUSH:",
		"\t\t\t_push(card, at)",
		"\t\tFORCE_FOR_A_TIME:",
		"\t\t\t_force_for_a_time(card, seconds)",
		"\t\tGRAVITY_FOR_A_TIME:",
		"\t\t\t_gravity_for_a_time(card, seconds)",
		"\t\tFREEZE_BODY:",
		"\t\t\t_freeze_body(card, seconds)",
		"\t\tSQUASH_STRETCH, PUNCH_POSITION, PUNCH_ROTATION:",
		"\t\t\t_punch_through_juice(word, card, at, seconds)",
		"\t\tPOP:",
		"\t\t\t_pop(card, seconds)",
		"\t\tFADE:",
		"\t\t\t_fade(card, seconds)",
		"\t\tGRAB_FOCUS:",
		"\t\t\t_grab_focus(card)",
		"\t\tCOUNT_TO:",
		"\t\t\t_count_to(card, seconds)",
		"\t\tREVEAL_TEXT:",
		"\t\t\t_reveal_text(card, seconds)",
		"\t\tFILL_BAR:",
		"\t\t\t_fill_bar(card, seconds)",
		"\t\tSHADER_VALUE:",
		"\t\t\t_shader_value(card, seconds)",
		"\t\tPAUSE_PLAYER:",
		"\t\t\t_pause_player(card)",
		"\t\tCOLLISION_FOR:",
		"\t\t\t_collision_for(card, seconds)",
		"\t\tCOLLISION_LAYER_FOR:",
		"\t\t\t_collision_layer_for(card, seconds)",
		"\t\tREMOVE_NODE:",
		"\t\t\t_remove_node(card, skipping)",
		"\t\tDRAW_ORDER:",
		"\t\t\t_draw_order(card, seconds)",
		"\t\tSWITCH_NODE:",
		"\t\t\t_switch_node(card, seconds)",
		"\t\tLOOK_AT:",
		"\t\t\t_look_at(card, 0.0 if skipping else seconds)",
		"\t\tROTATE_BY:",
		"\t\t\t_turn_card(card, 0.0 if skipping else seconds, true)",
		"\t\tROTATE_TO:",
		"\t\t\t_turn_card(card, 0.0 if skipping else seconds, false)",
		"\t\tROTATION_SHAKE:",
		"\t\t\t_rotation_shake(card, at, seconds)",
		"\t\tLIGHT:",
		"\t\t\t_light(card, at, seconds)",
		"\t\tSCENE_LOOK:",
		"\t\t\t_scene_look(card, seconds)",
		"\t\tBUS_EFFECT:",
		"\t\t\t_bus_effect(card, seconds)",
		"\t\tSPRING:",
		"\t\t\t_spring(card, at)",
		"\t\tSLOW_OBJECT:",
		"\t\t\t_slow_object(card, seconds)",
		"\t\tANIMATION_PARAMETER:",
		"\t\t\t_animation_parameter(card, seconds)",
		"\t\tCHROMATIC_SHAKE:",
		"\t\t\t_chromatic_shake(card, at, seconds)",
		"\t\tGRAYSCALE:",
		"\t\t\t_grayscale(card, at, seconds, skipping)",
		"\t\tPOSITION_SHAKE:",
		"\t\t\t_position_shake(card, at, seconds)",
		"",
		"## The Juice node a Chromatic Shake card started a shake on, so Stop, Restore and leaving the scene can close the split.",
		"var _chroma_node: Node = null",
		"",
		"## What a Chromatic Shake card asks the Juice node's own row for: [amount in pixels, seconds, mode, angle]. The strength",
		"## scales the amount and nothing else; the Juice node then holds it to the no-flashing choice and the effect-strength",
		"## dial, as it does for the row. A direction that wanders is the row's angle below zero; an angle is turned into the",
		"## 0 to 360 the row takes.",
		"## @ace_hidden",
		"static func chromatic_shake_asked(card: Dictionary, at: float, seconds: float) -> Array:",
		"\tvar angle: float = -1.0",
		"\tif str(card.get(\"direction\", \"wander\")) == \"angle\":",
		"\t\tangle = fposmod(float(card.get(\"angle\", 0.0)), 360.0)",
		"\tvar mode: String = \"constant\" if str(card.get(\"mode\", \"reducing\")) == \"constant\" else \"reducing\"",
		"\treturn [maxf(float(card.get(\"amount\", 12.0)), 0.0) * maxf(at, 0.0), maxf(seconds, 0.01), mode, angle]",
		"",
		"## Splits the screen's colours apart through the Juice node's Chromatic Shake row, and keeps the node so the split can be closed.",
		"func _chromatic_shake(card: Dictionary, at: float, seconds: float) -> void:",
		"\tvar juice: Node = _juice()",
		"\tif juice == null or not juice.has_method(\"chromatic_shake\"):",
		"\t\treturn",
		"\tvar asked: Array = chromatic_shake_asked(card, at, seconds)",
		"\tjuice.call(\"chromatic_shake\", asked[0], asked[1], asked[2], asked[3])",
		"\t_chroma_node = juice",
		"",
		"## Puts the colours together at once if a Chromatic Shake card of this player split them.",
		"func _end_chroma_shake() -> void:",
		"\tvar juice: Node = _chroma_node",
		"\t_chroma_node = null",
		"\tif juice != null and is_instance_valid(juice) and juice.has_method(\"stop_chromatic_shake\"):",
		"\t\tjuice.call(\"stop_chromatic_shake\")",
		"",
		"## The Juice node a player would play through, found from where it is saved: under the same object or under the",
		"## player. The editor asks it to say in amber that a Chromatic Shake card has nothing to play it.",
		"## @ace_hidden",
		"static func juice_beside(player: Node) -> Node:",
		"\tif player == null:",
		"\t\treturn null",
		"\tvar looked: Array = player.get_children()",
		"\tvar parent: Node = player.get_parent()",
		"\tif parent != null:",
		"\t\tlooked.append_array(parent.get_children())",
		"\tvar chosen: Variant = player.get(\"acts_on\")",
		"\tif chosen is Node:",
		"\t\tlooked.append_array((chosen as Node).get_children())",
		"\tfor child: Variant in looked:",
		"\t\tvar node: Node = child as Node",
		"\t\tif node != null and node != player and node.has_method(\"chromatic_shake\"):",
		"\t\t\treturn node",
		"\treturn null",
		"",
		"## Takes one held force off its body, once.",
		"func _release_force(held: Dictionary) -> void:",
		"\tif not _held_forces.has(held):",
		"\t\treturn",
		"\t_held_forces.erase(held)",
		"\tvar body: Object = held.get(\"body\") as Object",
		"\tif body == null or not is_instance_valid(body):",
		"\t\treturn",
		"\tif body is RigidBody2D:",
		"\t\t(body as RigidBody2D).add_constant_central_force(-(held[\"force\"] as Vector2))",
		"\telif body is RigidBody3D:",
		"\t\t(body as RigidBody3D).add_constant_central_force(-(held[\"force\"] as Vector3))",
		"",
		"## Takes every held force off, at once.",
		"func _release_forces() -> void:",
		"\tfor held: Dictionary in _held_forces.duplicate():",
		"\t\t_release_force(held)",
		"",
		"## Squash and stretch, a position kick or a rotation kick, done by the Juice node beside this one.",
		"func _punch_through_juice(word: String, card: Dictionary, at: float, seconds: float) -> void:",
		"\tvar juice: Node = _juice()",
		"\tif juice == null:",
		"\t\treturn",
		"\tmatch word:",
		"\t\tSQUASH_STRETCH:",
		"\t\t\tjuice.call(\"squash_and_stretch\", float(card.get(\"amount\", 0.3)) * at, seconds)",
		"\t\tPUNCH_POSITION:",
		"\t\t\tjuice.call(\"punch_position\", Vector2(float(card.get(\"x\", 0.0)), float(card.get(\"y\", -10.0))) * at, seconds)",
		"\t\tPUNCH_ROTATION:",
		"\t\t\tjuice.call(\"punch_rotation\", float(card.get(\"amount\", 10.0)) * at, seconds)",
		"",
		"## The shader material of a node: a CanvasItem's material, or a 3D object's material override.",
		"static func _shader_material_of(target: Node) -> ShaderMaterial:",
		"\tif target is CanvasItem:",
		"\t\treturn (target as CanvasItem).material as ShaderMaterial",
		"\tif target is GeometryInstance3D:",
		"\t\treturn (target as GeometryInstance3D).material_override as ShaderMaterial",
		"\treturn null",
		"",
		"## Whether a Tween Property card holds any of the keys that make it the whole card. A card that holds",
		"## none of them is the one-number tween on this object it has always been.",
		"static func _is_whole_tween(card: Dictionary) -> bool:",
		"\tfor key: String in [\"node\", \"to\", \"from\", \"trans\", \"ease\", \"relative\", \"back\"]:",
		"\t\tif card.has(key):",
		"\t\t\treturn true",
		"\treturn false",
		"",
		"## Whether the card names a node under this key at all.",
		"static func _names_a_node(card: Dictionary, key: String) -> bool:",
		"\treturn not _path_of(card, key).is_empty()",
		"",
		"## The player a Play Player card plays: the one it picked, else the one its old typed name finds. Said",
		"## once, and refused, when it is this player itself or a player that is playing this one.",
		"func _player_to_play(card: Dictionary, typed: String) -> Node:",
		"\tvar other: Node = null",
		"\tif _names_a_node(card, \"player\"):",
		"\t\tother = _target(card, \"player\", false)",
		"\t\tif other == null:",
		"\t\t\t_card_missing(card, \"points at no Juice Player\")",
		"\t\t\treturn null",
		"\telse:",
		"\t\tother = get_node_or_null(NodePath(typed))",
		"\tif other == self or (other != null and _plays_through(other, self, 0)):",
		"\t\t_card_missing(card, \"would play a player that is already playing it\")",
		"\t\treturn null",
		"\treturn other",
		"",
		"## Whether `from` is playing, through the players it started, the one named `wanted`. The depth is a",
		"## guard against a ring of players that has no end.",
		"static func _plays_through(from: Node, wanted: Node, depth: int) -> bool:",
		"\tif depth > 8 or from.get(\"playing\") != true:",
		"\t\treturn false",
		"\tvar started: Variant = from.get(\"_nested\")",
		"\tif not (started is Array):",
		"\t\treturn false",
		"\tfor other: Variant in (started as Array):",
		"\t\tif other == wanted or (other is Node and _plays_through(other as Node, wanted, depth + 1)):",
		"\t\t\treturn true",
		"\treturn false"
	])


## The typed function behind every juice card: the work a card does, callable from code with named, typed arguments.
## One raw string, so the code reads as the GDScript it becomes.
static func _typed_card_lines() -> PackedStringArray:
	return PackedStringArray(TYPED_CARD_CODE.split("\n"))


const TYPED_CARD_CODE: String = r"""# --- Typed functions: the work of every card, callable from code ---
# A card is a dictionary the Inspector edits. Each kind below reads its own keys and calls the typed function of the
# same job, so a card, a sheet row and a line of hand-written GDScript all reach ONE implementation. On a typed
# variable (`@onready var juice: JuicePlayer = $JuicePlayer`) the editor completes every one of these with named,
# typed arguments, and a misspelt one is a parse error rather than a silent nothing. Every function returns nothing:
# a Tween handle would be null whenever a target is missing, and awaiting a null is a crash, not a warning.

## The four ways bus_effect_for changes an audio bus.
enum BusWay {
	## Cuts the high end of the bus, as a wall or a closed door would.
	MUFFLE,
	## Brings the level of the bus down.
	DIVE,
	## Adds reverb to the bus.
	WASH,
	## Switches on an effect the bus already has.
	SWITCH
}

## The word a card keeps for each BusWay, in the enum's order.
const BUS_WAY_WORDS: PackedStringArray = ["muffle", "dive", "wash", "switch"]

## The card being played this instant, so a typed function says what is wrong in its words; empty when code called it.
var _card_in_play: Dictionary = {}

## Says once that a typed function could not do its work: in the card's name when a card asked, in this player's name when code did.
func _miss(reason: String) -> void:
	if not _card_in_play.is_empty():
		_card_missing(_card_in_play, reason)
		return
	_warn_call(reason + ", so it did nothing")

## Says one thing about a call from code, once, in this player's name.
func _warn_call(text: String) -> void:
	var told: String = "call: " + text
	if _told_cards.has(told):
		return
	_told_cards[told] = true
	push_warning("Juice Player: a call on %s %s." % [name, text])

## Walks a property of a node to a value, the whole of the Tween Property card: where it starts, the transition and ease,
## whether it comes back, and whether the value is added to what is there. With no time it is set at once. What the
## property was is written down, so Restore Initial Values puts it back.
## @ace_hidden
func tween_property(target: Node, property: String, to: Variant, seconds: float = 0.2, from: Variant = null,
		trans: Tween.TransitionType = Tween.TRANS_LINEAR, ease_type: Tween.EaseType = Tween.EASE_IN_OUT,
		comes_back: bool = false, relative: bool = false) -> void:
	if target == null:
		_miss("points at a node that is not there")
		return
	property = property.strip_edges()
	if property.is_empty():
		return
	var before: Variant = target.get_indexed(NodePath(property))
	if before == null:
		_miss("points at %s, which has no property called \"%s\"" % [target.name, property])
		return
	_keep_first(target, property, before)
	if from != null:
		target.set_indexed(NodePath(property), from)
	if seconds <= 0.0 and not comes_back:
		target.set_indexed(NodePath(property), (before + to) if relative else to)
		return
	var shaped: Tween = _new_tween().set_trans(trans).set_ease(ease_type)
	var there: PropertyTweener = shaped.tween_property(target, NodePath(property), to, seconds * (0.5 if comes_back else 1.0))
	if relative:
		there.as_relative()
	if comes_back:
		shaped.tween_property(target, NodePath(property), before, seconds * 0.5)

## A Tween Property card. One that holds none of the newer keys is the one-number tween on this object it always was.
func _tween_card(card: Dictionary, at: float, seconds: float) -> void:
	var target: Node = _target(card, "node", true)
	var goal: Variant = card.get("to", float(card.get("amount", 1.0)))
	var relative: bool = bool(card.get("relative", false))
	# A number is scaled by the strength of the play, as the one-number tween always was; a colour or a
	# position is a place, not an amount, so only a value added to what is there is scaled.
	if goal is float or goal is int or (relative and (goal is Vector2 or goal is Vector3)):
		goal = goal * at
	var trans: Tween.TransitionType = TRANSITIONS.get(str(card.get("trans", "linear")), Tween.TRANS_LINEAR) as Tween.TransitionType
	var eased: Tween.EaseType = EASES.get(str(card.get("ease", "in_out")), Tween.EASE_IN_OUT) as Tween.EaseType
	tween_property(target, str(card.get("effect", "")), goal, seconds, card.get("from"), trans, eased, bool(card.get("back", false)), relative)

## The one-number Tween Property card, on the object this player is under.
func _tween_property(_card: Dictionary, property: String, value: float, seconds: float) -> void:
	if host == null:
		return
	tween_property(host, property, value, seconds)

## Fires a signal of a node, with the values given.
## @ace_hidden
func emit_signal_on(node: Node, signal_name: String, args: Array = []) -> void:
	if node == null or not node.has_signal(signal_name):
		_miss("points at no node with a signal called \"%s\"" % signal_name)
		return
	node.callv("emit_signal", [signal_name] + args)

## Says a word through On Juice Signal, for a row or a script that listens for it.
## @ace_hidden
func emit_juice_signal(word: String) -> void:
	on_feedback_signal.emit(word)

## An Emit Signal card: a signal of a node when it names both, else a word through On Juice Signal.
func _emit_on_node(card: Dictionary) -> void:
	var given: Variant = card.get("args", [])
	emit_signal_on(_target(card, "node", false), str(card.get("signal", "")), given as Array if given is Array else [])

## Plays another Juice Player (any node with a play method) with this one: it follows this player's Stop and Restore, and its strength is the one given.
## @ace_hidden
func play_player(other: Node, at_strength: float = 1.0) -> void:
	if other == null or other == self or _plays_through(other, self, 0):
		_miss("would play a player that is already playing it")
		return
	if not _nested.has(other):
		_nested.append(other)
	other.call("play", at_strength)

## Plays one sound through a voice this player keeps, so a fast run of hits reuses its voices instead of making a node each.
## It is heard from this object's place when `heard_from_here` is on and the object is a 2D or 3D node. `label` is the name
## stop_sound finds it by.
## @ace_hidden
func play_sound(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "Master",
		heard_from_here: bool = true, label: String = "") -> void:
	if stream == null:
		_miss("has no sound to play")
		return
	if AudioServer.get_bus_index(bus) < 0:
		_warn_call("asks for the bus \"%s\", which this project does not have, so it played on Master" % bus)
		bus = "Master"
	var kind: String = "AudioStreamPlayer"
	if heard_from_here and host is Node2D:
		kind = "AudioStreamPlayer2D"
	elif heard_from_here and host is Node3D:
		kind = "AudioStreamPlayer3D"
	var voice: Node = _voice_for(kind)
	voice.set("stream", stream)
	voice.set("volume_db", volume_db)
	voice.set("pitch_scale", maxf(pitch, LOWEST_PITCH))
	voice.set("bus", bus)
	if kind != "AudioStreamPlayer":
		voice.set("global_position", host.get("global_position"))
	voice.call("play")
	_sounding[label] = voice

## One Sound card, heard. Muting the Sound family never reaches here: the walk has already stepped over the card.
func _play_sound(card: Dictionary, at: float) -> void:
	var settings: Dictionary = sound_settings(card, at, randf(), randf())
	var stream: AudioStream = _stream_at(str(settings.get("stream", "")))
	if stream == null:
		if str(settings.get("stream", "")).is_empty():
			_tell_sound(card, "has no sound picked, so it stayed silent.")
		else:
			_tell_sound(card, "cannot find its sound \"%s\", so it stayed silent." % str(settings.get("stream", "")))
		return
	var bus: String = str(settings.get("bus", "Master"))
	if AudioServer.get_bus_index(bus) < 0:
		_tell_sound(card, "asks for the bus \"%s\", which this project does not have, so it played on Master." % bus)
		bus = "Master"
	play_sound(stream, float(settings.get("volume_db", 0.0)), float(settings.get("pitch_scale", 1.0)), bus, bool(settings.get("here", true)), _label_of(card))

## Stops the sound a Sound card named `label` started, or every sound this player has going when the label is empty,
## fading it out over `fade` seconds when that is above 0.
## @ace_hidden
func stop_sound(label: String = "", fade: float = 0.0) -> void:
	var wanted: String = label.strip_edges()
	for sounding: Variant in _sounding.keys():
		if not wanted.is_empty() and str(sounding) != wanted:
			continue
		var voice: Node = _sounding[sounding] as Node
		_sounding.erase(sounding)
		if voice == null or not is_instance_valid(voice) or not bool(voice.get("playing")):
			continue
		if fade > 0.0:
			var fading: Tween = create_tween()
			fading.tween_property(voice, "volume_db", SILENT_DB, fade)
			fading.tween_callback(voice.call.bind("stop"))
		else:
			voice.call("stop")

## Moves an audio bus's volume to `to_db` over `seconds`, remembering where it was so Restore can put it back. A bus this
## project does not have is said once and left alone.
## @ace_hidden
func fade_bus(bus: String, to_db: float, seconds: float = 0.3) -> void:
	var index: int = AudioServer.get_bus_index(bus.strip_edges())
	if index < 0:
		_miss("names the bus \"%s\", which this project does not have" % bus)
		return
	var key: String = AudioServer.get_bus_name(index)
	if not _bus_restore.has(key):
		_bus_restore[key] = AudioServer.get_bus_volume_db(index)
	if seconds <= 0.0:
		AudioServer.set_bus_volume_db(index, to_db)
		return
	var moved: Tween = get_tree().create_tween()
	_bus_tweens.append(moved)
	moved.tween_method(func(level: float) -> void: AudioServer.set_bus_volume_db(index, level), AudioServer.get_bus_volume_db(index), to_db, seconds)

## Rumbles every connected controller (the weak motor and the strong one, 0 to 1) and buzzes a phone for the same
## time. The web has neither, so there it does nothing. To pick one controller use vibrate_controller or
## vibrate_last_used; a phone has one motor, so it buzzes at the stronger of the two strengths.
## @ace_hidden
func vibrate(weak: float = 0.5, strong: float = 0.5, seconds: float = 0.2) -> void:
	vibrate_controller(EVERY_CONTROLLER, weak, strong, seconds)

## The controller number that means every connected controller and a phone.
const EVERY_CONTROLLER: int = -1
## The word a Vibrate card's controller choice holds for every controller.
const CONTROLLER_ALL: String = "all"
## The word a Vibrate card's controller choice holds for the controller used last.
const CONTROLLER_LAST: String = "last"

## Rumbles one controller by its number (0 is the first), or every controller and a phone when the number is
## below 0. A number with no controller behind it does nothing. The web has no rumble, so there it does nothing.
## @ace_hidden
func vibrate_controller(controller: int, weak: float = 0.5, strong: float = 0.5, seconds: float = 0.2) -> void:
	if OS.has_feature("web"):
		return
	seconds = maxf(seconds, 0.0)
	weak = clampf(weak, 0.0, 1.0)
	strong = clampf(strong, 0.0, 1.0)
	if controller >= 0:
		if Input.get_connected_joypads().has(controller):
			Input.start_joy_vibration(controller, weak, strong, seconds)
			_note_rumble(controller, seconds)
		return
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, seconds)
		_note_rumble(device, seconds)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(int(seconds * 1000.0), maxf(weak, strong))

## The controllers this player set rumbling; a player never stops another's motors.
var _rumbling: Array[int] = []
## When the latest rumble this player started ends, in seconds of the game clock.
var _rumble_ends_at: float = 0.0

## Writes down that a controller was set rumbling for a time.
func _note_rumble(device: int, seconds: float) -> void:
	if not _rumbling.has(device):
		_rumbling.append(device)
	_rumble_ends_at = maxf(_rumble_ends_at, float(Time.get_ticks_msec()) / 1000.0 + seconds)

## Stops the motors this player set going that are still running, so a Stop, a Restore or leaving the scene in
## the middle of a pattern of buzzes does not leave the last one humming. A phone cannot be told to stop.
func _stop_rumble() -> void:
	if float(Time.get_ticks_msec()) / 1000.0 < _rumble_ends_at:
		for device: int in _rumbling:
			if Input.get_connected_joypads().has(device):
				Input.stop_joy_vibration(device)
	_rumbling.clear()
	_rumble_ends_at = 0.0

## Rumbles the controller the player touched last, so the pad in their hands buzzes and the one on the shelf does
## not. Before any controller was touched, or when that one has been unplugged, it rumbles every controller instead.
## @ace_hidden
func vibrate_last_used(weak: float = 0.5, strong: float = 0.5, seconds: float = 0.2) -> void:
	var device: int = last_controller()
	vibrate_controller(device if device >= 0 and Input.get_connected_joypads().has(device) else EVERY_CONTROLLER, weak, strong, seconds)

## The number of the controller that sent the latest button press or stick push, or -1 when none has yet.
## @ace_hidden
static func last_controller() -> int:
	return _last_pad

## The controller heard last, kept for the whole game by the one listener below.
static var _last_pad: int = -1
## The one listener, made by the first player to enter a scene.
static var _pad_listener: Node = null

## Listens for controller input and keeps the number of whichever controller spoke last. It reads nothing else,
## and stick drift too small to be a push is ignored.
class PadListener:
	extends Node

	func _input(event: InputEvent) -> void:
		if event is InputEventJoypadButton:
			JuicePlayer._last_pad = (event as InputEventJoypadButton).device
		elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
			JuicePlayer._last_pad = (event as InputEventJoypadMotion).device

## Starts the controller listener once for the whole game.
func _listen_for_controllers() -> void:
	if _pad_listener != null and is_instance_valid(_pad_listener):
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	_pad_listener = PadListener.new()
	_pad_listener.name = "JuicePadListener"
	tree.root.add_child.call_deferred(_pad_listener)

## A Vibrate card, each motor scaled by the strength of the play.
func _vibrate(card: Dictionary, at: float) -> void:
	var weak: float = float(card.get("weak", 0.5)) * at
	var strong: float = float(card.get("strong", 0.5)) * at
	var seconds: float = float(card.get("seconds", 0.0))
	var which: String = str(card.get("controller", CONTROLLER_ALL)).strip_edges().to_lower()
	if which == CONTROLLER_LAST:
		vibrate_last_used(weak, strong, seconds)
	elif which.is_valid_int():
		vibrate_controller(int(which), weak, strong, seconds)
	else:
		vibrate(weak, strong, seconds)

## Whether a node is a particles node, said when it is not.
func _is_particles(node: Node) -> bool:
	if node == null or not ("emitting" in node):
		_miss("points at no particles node")
		return false
	return true

## Plays a particles node again from the start: a burst, a puff of dust.
## @ace_hidden
func restart_particles(node: Node) -> void:
	if not _is_particles(node):
		return
	_remember(node, "emitting")
	if node.has_method("restart"):
		node.call("restart")
	node.set("emitting", true)

## Switches a particles node on, so it keeps emitting.
## @ace_hidden
func start_particles(node: Node) -> void:
	if not _is_particles(node):
		return
	_remember(node, "emitting")
	node.set("emitting", true)

## Switches a particles node off.
## @ace_hidden
func stop_particles(node: Node) -> void:
	if not _is_particles(node):
		return
	_remember(node, "emitting")
	node.set("emitting", false)

## A Particles card: restart, start or stop.
func _particles(card: Dictionary) -> void:
	var target: Node = _target(card, "node", false)
	match str(card.get("do", DO_RESTART)):
		DO_STOP:
			stop_particles(target)
		DO_START:
			start_particles(target)
		_:
			restart_particles(target)

## Plays a clip of an AnimationPlayer. With `seconds` above 0 the clip is stretched to that length, so Scale Juice
## Timing speeds an animation up with the rest of the list.
## @ace_hidden
func play_animation(player: AnimationPlayer, animation: String, seconds: float = 0.0) -> void:
	if player == null:
		_miss("points at no animation player")
		return
	if not player.has_animation(animation):
		_miss("names the animation \"%s\", which that player does not have" % animation)
		return
	var length: float = player.get_animation(animation).length
	var speed: float = length / seconds if seconds > 0.0 and length > 0.0 else 1.0
	player.play(animation, -1.0, speed)

## An Animation card.
func _animation(card: Dictionary, seconds: float) -> void:
	play_animation(_target(card, "node", false) as AnimationPlayer, str(card.get("animation", "")), seconds)

## Plays an animation of an AnimatedSprite2D or AnimatedSprite3D, stretched to `seconds` when that is above 0.
## @ace_hidden
func play_sprite_animation(sprite: Node, animation: String, seconds: float = 0.0) -> void:
	var frames: SpriteFrames = sprite.get("sprite_frames") as SpriteFrames if sprite != null else null
	if frames == null or not sprite.has_method("play"):
		_miss("points at no animated sprite")
		return
	if not frames.has_animation(animation):
		_miss("names the animation \"%s\", which that sprite does not have" % animation)
		return
	var length: float = float(frames.get_frame_count(animation)) / maxf(frames.get_animation_speed(animation), 0.001)
	sprite.call("play", animation, length / seconds if seconds > 0.0 and length > 0.0 else 1.0)

## A Sprite Animation card.
func _sprite_animation(card: Dictionary, seconds: float) -> void:
	play_sprite_animation(_target(card, "node", false), str(card.get("animation", "")), seconds)

## Shows or hides a node, and for a flash hides it again after `flash_seconds`.
func _show_or_hide(node: Node, shown: bool, flash_seconds: float) -> void:
	if node == null or not ("visible" in node):
		_miss("points at no node that can be shown or hidden")
		return
	_remember(node, "visible")
	node.set("visible", shown)
	if flash_seconds >= 0.0:
		get_tree().create_timer(maxf(flash_seconds, 0.0)).timeout.connect(func() -> void:
			if is_instance_valid(node):
				node.set("visible", false))

## Shows a node.
## @ace_hidden
func show_node(node: Node) -> void:
	_show_or_hide(node, true, -1.0)

## Hides a node.
## @ace_hidden
func hide_node(node: Node) -> void:
	_show_or_hide(node, false, -1.0)

## Shows a node for `seconds` and hides it again.
## @ace_hidden
func show_node_for(node: Node, seconds: float) -> void:
	_show_or_hide(node, true, maxf(seconds, 0.0))

## A Show Or Hide card.
func _show_hide(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", true)
	match str(card.get("do", DO_FLASH)):
		DO_HIDE:
			hide_node(target)
		DO_SHOW:
			show_node(target)
		_:
			show_node_for(target, seconds)

## Calls a method of a node with the values given.
## @ace_hidden
func call_method(node: Node, method: String, args: Array = []) -> void:
	if node == null or not node.has_method(method):
		_miss("points at no node with a method called \"%s\"" % method)
		return
	node.callv(method, args)

## A Call Method card.
func _call_method(card: Dictionary) -> void:
	var given: Variant = card.get("args", [])
	call_method(_target(card, "node", false), str(card.get("method", "")), given as Array if given is Array else [])

## Adds a copy of a scene to the running scene, at `at` or at the object this player is under, taking it from the object
## pool when that scene has one.
## @ace_hidden
func spawn_scene(scene: PackedScene, at: Node = null) -> void:
	if scene == null:
		_miss("names a scene that is not in the project")
		return
	var anchor: Node = at if at != null else host
	if anchor == null:
		_miss("points at no node to drop the scene at")
		return
	var place: Variant = anchor.get("global_position")
	var pool: Node = get_node_or_null("/root/ObjectPool")
	var pooled: String = _pool_named_for(pool, scene)
	if not pooled.is_empty() and place != null:
		pool.call("spawn_safely", pooled, place)
		return
	var made: Node = scene.instantiate()
	var world: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	world.add_child.call_deferred(made)
	if place != null:
		made.set.call_deferred("global_position", place)

## A Spawn Scene card.
func _spawn_scene(card: Dictionary) -> void:
	var path: String = str(card.get("scene", ""))
	var scene: PackedScene = load(path) as PackedScene if not path.is_empty() and ResourceLoader.exists(path) else null
	var anchor: Node = _target(card, "node", true) if str(card.get("at", "here")) == "node" else host
	spawn_scene(scene, anchor)

## The name of the object pool that holds copies of this scene, or "" when none does.
func _pool_named_for(pool: Node, scene: PackedScene) -> String:
	if pool == null or not pool.has_method("spawn_safely"):
		return ""
	var pools: Variant = pool.get("_pools")
	if not (pools is Dictionary):
		return ""
	for pool_name: Variant in (pools as Dictionary):
		var entry: Variant = (pools as Dictionary)[pool_name]
		if entry is Dictionary and (entry as Dictionary).get("scene") == scene:
			return str(pool_name)
	return ""

## The direction of a push that has none: a vector of no length, of the kind the body uses.
static func _no_direction(in_3d: bool) -> Variant:
	if in_3d:
		return Vector3.ZERO
	return Vector2.ZERO

## A shove. A RigidBody takes it as an impulse, a CharacterBody has it added to its velocity once and carries on
## moving itself. Anything else is not a body, and the push says so.
func _shove(body: Node, way: Variant, speed: float) -> void:
	if body is RigidBody2D:
		(body as RigidBody2D).apply_central_impulse((way as Vector2) * speed * (body as RigidBody2D).mass)
	elif body is RigidBody3D:
		(body as RigidBody3D).apply_central_impulse((way as Vector3) * speed * (body as RigidBody3D).mass)
	elif body is CharacterBody2D:
		(body as CharacterBody2D).velocity += (way as Vector2) * speed
	elif body is CharacterBody3D:
		(body as CharacterBody3D).velocity += (way as Vector3) * speed
	else:
		_miss("points at something that is not a physics body")

## Shoves a body away from another node, at `speed`. A RigidBody takes it as an impulse; a CharacterBody has it added to
## its velocity once and carries on moving itself.
## @ace_hidden
func push_away_from(body: Node, from: Node, speed: float = 300.0) -> void:
	if body == null:
		_miss("points at no body")
		return
	var here: Variant = body.get("global_position")
	var there: Variant = from.get("global_position") if from != null else null
	if here == null or there == null or typeof(there) != typeof(here):
		_shove(body, _no_direction(body is Node3D), speed)
		return
	_shove(body, (here - there).normalized(), speed)

## Shoves a body further along the way it is already moving, at `speed`.
## @ace_hidden
func push_along_motion(body: Node, speed: float = 300.0) -> void:
	if body == null:
		_miss("points at no body")
		return
	var moving: Variant = body.get("linear_velocity")
	if moving == null:
		moving = body.get("velocity")
	if moving is Vector2 or moving is Vector3:
		_shove(body, moving.normalized(), speed)
		return
	_shove(body, _no_direction(body is Node3D), speed)

## Shoves a body along `way`, at `speed`. The way is made one long; a 2D body uses its x and y.
## @ace_hidden
func push_towards(body: Node, way: Vector3, speed: float = 300.0) -> void:
	if body == null:
		_miss("points at no body")
		return
	if body is Node3D:
		_shove(body, way.normalized(), speed)
	else:
		_shove(body, Vector2(way.x, way.y).normalized(), speed)

## A Push card. The strength of the play scales the speed unless the card says it does not.
func _push(card: Dictionary, at: float) -> void:
	var body: Node = _target(card, "body", true)
	var speed: float = float(card.get("speed", 300.0)) * (at if bool(card.get("scaled", true)) else 1.0)
	match str(card.get("direction", PUSH_AWAY)):
		PUSH_FIXED:
			push_towards(body, Vector3(float(card.get("x", 0.0)), float(card.get("y", -1.0)), float(card.get("z", 0.0))), speed)
		PUSH_ALONG:
			push_along_motion(body, speed)
		_:
			push_away_from(body, _target(card, "from", false), speed)

## Pushes a steady force on a RigidBody for `seconds`, taken away again when the time is up or on Restore. A 2D body
## uses the x and y of the force.
## @ace_hidden
func force_for_a_time(body: Node, force: Vector3, seconds: float = 0.5) -> void:
	if body == null:
		_miss("points at no body")
		return
	var held_force: Variant = force
	if body is RigidBody2D:
		held_force = Vector2(force.x, force.y)
		(body as RigidBody2D).add_constant_central_force(held_force)
	elif body is RigidBody3D:
		(body as RigidBody3D).add_constant_central_force(force)
	else:
		_miss("points at something that is not a RigidBody")
		return
	var held: Dictionary = {"body": body, "force": held_force}
	_held_forces.append(held)
	get_tree().create_timer(maxf(seconds, 0.0)).timeout.connect(_release_force.bind(held))

## A Force For A Time card.
func _force_for_a_time(card: Dictionary, seconds: float) -> void:
	force_for_a_time(_target(card, "body", true), Vector3(float(card.get("x", 0.0)), float(card.get("y", -400.0)), float(card.get("z", 0.0))), seconds)

## Gives a RigidBody a different gravity scale for `seconds`, then the one it had.
## @ace_hidden
func gravity_for_a_time(body: Node, gravity_scale: float = 0.2, seconds: float = 0.5) -> void:
	if body == null:
		_miss("points at no body")
		return
	if not (body is RigidBody2D or body is RigidBody3D):
		_miss("points at something that is not a RigidBody")
		return
	var before: Variant = _remember(body, "gravity_scale")
	body.set("gravity_scale", gravity_scale)
	get_tree().create_timer(maxf(seconds, 0.0)).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.set("gravity_scale", before))

## A Gravity For A Time card.
func _gravity_for_a_time(card: Dictionary, seconds: float) -> void:
	gravity_for_a_time(_target(card, "body", true), float(card.get("amount", 0.2)), seconds)

## Holds a RigidBody still for `seconds`. Freezing is not allowed in the middle of a physics step, so it is asked for at
## the end of the frame.
## @ace_hidden
func freeze_body(body: Node, seconds: float = 0.1) -> void:
	if body == null:
		_miss("points at no body")
		return
	if not (body is RigidBody2D or body is RigidBody3D):
		_miss("points at something that is not a RigidBody")
		return
	var before: Variant = _remember(body, "freeze")
	body.set_deferred("freeze", true)
	get_tree().create_timer(maxf(seconds, 0.0)).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.set_deferred("freeze", before))

## A Freeze Body card.
func _freeze_body(card: Dictionary, seconds: float) -> void:
	freeze_body(_target(card, "body", true), seconds)

## Scales a node up from its middle to `scale_to` times its size and lets it settle back over `seconds`.
## @ace_hidden
func pop(node: Node, scale_to: float = 1.3, seconds: float = 0.15) -> void:
	if node == null or not ("scale" in node):
		_miss("points at no node that can be scaled")
		return
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size / 2.0
	var rest: Variant = _remember(node, "scale")
	var made: Tween = _new_tween()
	made.tween_property(node, "scale", rest * scale_to, seconds * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	made.tween_property(node, "scale", rest, seconds * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## A Pop card.
func _pop(card: Dictionary, seconds: float) -> void:
	pop(_target(card, "node", true), float(card.get("amount", 1.3)), seconds)

## Fades a node to an alpha (0 clear, 1 solid) through its modulate.
## @ace_hidden
func fade_node(node: Node, alpha: float = 0.0, seconds: float = 0.3) -> void:
	if not (node is CanvasItem):
		_miss("points at no node that can be faded")
		return
	_remember(node, "modulate")
	_new_tween().tween_property(node, "modulate:a", alpha, seconds)

## A Fade card.
func _fade(card: Dictionary, seconds: float) -> void:
	fade_node(_target(card, "node", true), float(card.get("amount", 0.0)), seconds)

## Gives a Control the keyboard and gamepad focus.
## @ace_hidden
func focus_control(control: Control) -> void:
	if control == null:
		_miss("points at no control")
		return
	control.grab_focus()

## A Grab Focus card.
func _grab_focus(card: Dictionary) -> void:
	focus_control(_target(card, "node", false) as Control)

## Whether a node is a label-like node that holds text, said when it is not.
func _is_text_node(node: Node) -> bool:
	if node == null or not ("text" in node):
		_miss("points at no label")
		return false
	return true

## Counts a label from the number it shows to `to` over `seconds`.
## @ace_hidden
func count_label_to(label: Node, to: float, seconds: float = 0.6) -> void:
	if not _is_text_node(label):
		return
	_remember(label, "text")
	var shown: String = str(label.get("text")).strip_edges()
	var from: float = shown.to_float() if shown.is_valid_float() else 0.0
	_new_tween().tween_method(func(value: float) -> void:
		if is_instance_valid(label):
			label.set("text", str(int(round(value)))), from, to, seconds)

## A Count To card: the number is a plain number or a name read from the game.
func _count_to(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", false)
	var goal: Variant = _number_from(str(card.get("to", "")))
	if not _is_text_node(target):
		return
	if goal == null:
		_miss("names a number that is not there (\"%s\")" % str(card.get("to", "")))
		return
	count_label_to(target, float(goal), seconds)

## Reveals the letters of a label one after another. With `letters_per_second` above 0 the text the label holds right now
## is revealed at that speed; with 0 it takes exactly `seconds`.
## @ace_hidden
func reveal_text(label: Node, seconds: float = 0.8, letters_per_second: float = 0.0) -> void:
	if label == null or not ("visible_ratio" in label):
		_miss("points at no label")
		return
	_remember(label, "visible_ratio")
	label.set("visible_ratio", 0.0)
	var span: float = seconds
	if letters_per_second > 0.0:
		span = float(str(label.get("text")).length()) / letters_per_second
	_new_tween().tween_property(label, "visible_ratio", 1.0, span)

## A Reveal Text card.
func _reveal_text(card: Dictionary, seconds: float) -> void:
	reveal_text(_target(card, "node", false), seconds, float(card.get("speed", 0.0)))

## Glides a bar or slider to `to` over `seconds`.
## @ace_hidden
func fill_bar_to(bar: Range, to: float, seconds: float = 0.3) -> void:
	if bar == null:
		_miss("points at no bar")
		return
	_remember(bar, "value")
	_new_tween().tween_property(bar, "value", to, seconds)

## A Fill Bar card: the number is a plain number or a name read from the game.
func _fill_bar(card: Dictionary, seconds: float) -> void:
	var target: Range = _target(card, "node", false) as Range
	var goal: Variant = _number_from(str(card.get("to", "")))
	if target == null:
		_miss("points at no bar")
		return
	if goal == null:
		_miss("names a number that is not there (\"%s\")" % str(card.get("to", "")))
		return
	fill_bar_to(target, float(goal), seconds)

## Moves one value of the shader on a node over `seconds`. With `only_this` on, the node gets a copy of its material to
## itself first, so the others that share the file are left alone, and Restore gives the node its own material back.
## With `comes_back` the value goes there in half the time and back in the other half.
## @ace_hidden
func tween_shader_value(node: Node, parameter: String, to: Variant = null, seconds: float = 0.12,
		trans: Tween.TransitionType = Tween.TRANS_QUAD, comes_back: bool = true, only_this: bool = true) -> void:
	var shared: ShaderMaterial = _shader_material_of(node) if node != null else null
	if shared == null or shared.shader == null or parameter.is_empty():
		_miss("points at no node with a shader to move")
		return
	var material: ShaderMaterial = shared
	if only_this:
		var key: int = node.get_instance_id()
		if not _own_materials.has(key) or not is_instance_valid(_own_materials[key]):
			_own_materials[key] = shared.duplicate()
			var slot: String = "material" if node is CanvasItem else "material_override"
			_remember(node, slot)
			node.set(slot, _own_materials[key])
		material = _own_materials[key]
	var property: String = "shader_parameter/" + parameter
	var before: Variant = material.get_shader_parameter(parameter)
	if before == null:
		before = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), parameter)
	if before == null:
		_miss("names the shader value \"%s\", which that shader does not declare" % parameter)
		return
	_keep_first(material, property, before)
	var goal: Variant = to if to != null else before
	var way: Tween = _new_tween().set_trans(trans)
	if comes_back:
		way.tween_property(material, property, goal, seconds * 0.5)
		way.tween_property(material, property, before, seconds * 0.5)
	else:
		way.tween_property(material, property, goal, seconds)

## A Shader Value card.
func _shader_value(card: Dictionary, seconds: float) -> void:
	var trans: Tween.TransitionType = TRANSITIONS.get(str(card.get("trans", "sine")), Tween.TRANS_SINE) as Tween.TransitionType
	tween_shader_value(_target(card, "node", true), str(card.get("parameter", "")), card.get("to"), seconds, trans, bool(card.get("back", false)), bool(card.get("only_this", true)))

## Switches a collision shape off for `seconds`. Godot refuses a shape's disabled tick in the middle of a physics step, so
## it is changed at the safe moment, both ways.
## @ace_hidden
func disable_collision_for(shape: Node, seconds: float = 0.5) -> void:
	if shape == null or not _is_shape(shape):
		_miss("points at no collision shape")
		return
	_hold_for(shape, "disabled", true, seconds, true)

## A Collision For A Time card.
func _collision_for(card: Dictionary, seconds: float) -> void:
	disable_collision_for(_target(card, "node", false), seconds)

## Changes one layer of what a body is on, or of what it sees (`as_mask`), for `seconds`. Both are changed at the safe
## moment, so a call from a collision is safe.
## @ace_hidden
func set_collision_bit_for(body: Node, layer: int, on: bool, seconds: float = 0.5, as_mask: bool = true) -> void:
	if body == null or not (body is CollisionObject2D or body is CollisionObject3D):
		_miss("points at no body or area")
		return
	var part: String = "collision_mask" if as_mask else "collision_layer"
	_hold_for(body, part, on, seconds, true, clampi(layer, 1, 32))

## A Collision Layer For A Time card.
func _collision_layer_for(card: Dictionary, seconds: float) -> void:
	set_collision_bit_for(_target(card, "node", false), int(card.get("layer", 1)), bool(card.get("on", false)), seconds, str(card.get("part", "mask")) != "layer")

## Removes a node: handed back to its object pool when it came from one, freed when it did not. With `after_list` it waits
## for the list to end, so the sound and the particles of a death are not cut off with it; a node that holds this player
## waits whatever `after_list` says, because freeing it would end the list.
## @ace_hidden
func remove_node(node: Node, after_list: bool = true) -> void:
	if node == null:
		_miss("points at a node that is not there")
		return
	var holds_this_player: bool = node == self or node.is_ancestor_of(self)
	if not playing or not (after_list or holds_this_player):
		_retire(node)
	elif not _removals.has(node):
		_removals.append(node)

## A Remove Node card. A skip to the end removes it at once.
func _remove_node(card: Dictionary, skipping: bool) -> void:
	var target: Node = _target(card, "node", true)
	if skipping and target != null:
		_retire(target)
		return
	remove_node(target, bool(card.get("after_list", true)))

## Draws a 2D node in front of the rest (or behind it with a negative `z_index`) for `seconds`. Godot refuses a z index
## past 4096, so the number is held inside it.
## @ace_hidden
func draw_order_for(node: Node, z_index: int = 10, seconds: float = 0.5) -> void:
	if not (node is CanvasItem):
		_miss("points at no 2D node, and a 3D node is drawn by its distance from the camera")
		return
	_hold_for(node, "z_index", clampi(z_index, -MOST_Z_INDEX, MOST_Z_INDEX), seconds)

## A Draw Order card.
func _draw_order(card: Dictionary, seconds: float) -> void:
	draw_order_for(_target(card, "node", true), int(card.get("z_index", 10)), seconds)

## Switches a node off or on in the three ways Godot has, each its own tick: hidden, not processing, and its collision
## shapes disabled. `timed` holds the change for `seconds` and lets it go; otherwise it is written for good, with Restore
## able to undo it.
func _switch(node: Node, off: bool, timed: bool, seconds: float, hidden: bool, processing: bool, collision: bool) -> void:
	if node == null:
		_miss("points at a node that is not there")
		return
	var done: bool = false
	if hidden and "visible" in node:
		_switch_property(node, "visible", not off, timed, seconds, false)
		done = true
	if processing:
		_switch_property(node, "process_mode", Node.PROCESS_MODE_DISABLED if off else Node.PROCESS_MODE_INHERIT, timed, seconds, false)
		done = true
	if collision:
		for shape: Node in _shapes_under(node):
			_switch_property(shape, "disabled", off, timed, seconds, true)
			done = true
	if not done:
		_miss("has nothing ticked to switch")

## One property of a switched node: held for a time, or written for good with Restore able to undo it.
func _switch_property(target: Object, property: String, value: Variant, timed: bool, seconds: float, deferred: bool) -> void:
	if timed:
		_hold_for(target, property, value, seconds, deferred)
		return
	_keep_first(target, property, target.get(property))
	if deferred:
		target.set_deferred(property, value)
	else:
		target.set(property, value)

## Switches a node off for `seconds` and then back on: hidden (`hidden`), not processing (`processing`) and with its
## collision shapes disabled (`collision`), each its own tick.
## @ace_hidden
func switch_node_off_for(node: Node, seconds: float = 0.5, hidden: bool = true, processing: bool = true, collision: bool = false) -> void:
	_switch(node, true, true, seconds, hidden, processing, collision)

## Switches a node off until something switches it on again; Restore puts it back too.
## @ace_hidden
func switch_node_off(node: Node, hidden: bool = true, processing: bool = true, collision: bool = false) -> void:
	_switch(node, true, false, 0.0, hidden, processing, collision)

## Switches a node back on: shown, processing again and with its collision shapes enabled, as ticked.
## @ace_hidden
func switch_node_on(node: Node, hidden: bool = true, processing: bool = true, collision: bool = false) -> void:
	_switch(node, false, false, 0.0, hidden, processing, collision)

## A Switch Node card.
func _switch_node(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", true)
	var hidden: bool = bool(card.get("visible", true))
	var processing: bool = bool(card.get("process", true))
	var collision: bool = bool(card.get("collision", false))
	match str(card.get("do", "for_a_time")):
		"on":
			switch_node_on(target, hidden, processing, collision)
		"off":
			switch_node_off(target, hidden, processing, collision)
		_:
			switch_node_off_for(target, seconds, hidden, processing, collision)

## Whether a node is one the physics engine owns. Turning one fights the engine, so the call says where to point it instead.
func _refuses_turning(node: Node) -> bool:
	if node is RigidBody2D or node is RigidBody3D:
		_miss("points at a RigidBody, which the physics engine turns (point it at the sprite or mesh under the body instead)")
		return true
	return false

## The property a turn writes: a 2D node and a Control turn by `rotation`, a 3D node about its up axis.
static func _turn_path(node: Node) -> String:
	return "rotation:y" if node is Node3D else "rotation"

## Whether a node can be turned by these functions at all.
static func _can_turn(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control

## Turns a node by an angle or to one, over a time. A Control turns about its middle. What the angle was is written
## down, so Restore turns it back.
func _turn(node: Node, degrees: float, seconds: float, by: bool) -> void:
	if node == null or not _can_turn(node):
		_miss("points at no node that can be turned")
		return
	if _refuses_turning(node):
		return
	var path: NodePath = NodePath(_turn_path(node))
	var now: float = float(node.get_indexed(path))
	var wanted: float = deg_to_rad(degrees)
	var goal: float = now + wanted if by else now + angle_difference(now, wanted)
	_keep_first(node, "rotation", node.get("rotation"))
	if node is Control:
		_keep_first(node, "pivot_offset", (node as Control).pivot_offset)
		(node as Control).pivot_offset = (node as Control).size / 2.0
	if seconds <= 0.0:
		node.set_indexed(path, goal)
		return
	_new_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(node, path, goal, seconds)

## Turns a node by an angle in degrees over `seconds`. A 2D node and a Control turn by their rotation, a 3D node about
## its up axis.
## @ace_hidden
func rotate_by(node: Node, degrees: float = 45.0, seconds: float = 0.2) -> void:
	_turn(node, degrees, seconds, true)

## Turns a node to an angle in degrees over `seconds`, the short way round.
## @ace_hidden
func rotate_to(node: Node, degrees: float = 90.0, seconds: float = 0.2) -> void:
	_turn(node, degrees, seconds, false)

## A Rotate By or Rotate To card.
func _turn_card(card: Dictionary, seconds: float, by: bool) -> void:
	var degrees: float = float(card.get("degrees", 45.0 if by else 90.0))
	if by:
		rotate_by(_target(card, "node", true), degrees, seconds)
	else:
		rotate_to(_target(card, "node", true), degrees, seconds)

## Turns a node to face another node over `seconds`: in 2D the angle that points its right at it, in 3D the way the
## engine's own look at turns it, with the head up. A node at the same place has nothing to face, and a target straight
## above looks along the forward axis instead of flipping.
## @ace_hidden
func turn_to_face(node: Node, target: Node, seconds: float = 0.2) -> void:
	if node == null or target == null:
		_miss("points at a node or a target that is not there")
		return
	if _refuses_turning(node):
		return
	if node is Node2D and target is Node2D:
		var from: Node2D = node as Node2D
		var offset: Vector2 = (target as Node2D).global_position - from.global_position
		if offset.length() < 0.001:
			_miss("is at the same place as its target (there is nothing to face)")
			return
		var wanted: float = from.global_rotation + angle_difference(from.global_rotation, offset.angle())
		_keep_first(from, "rotation", from.rotation)
		if seconds <= 0.0:
			from.global_rotation = wanted
			return
		_new_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(from, NodePath("global_rotation"), wanted, seconds)
	elif node is Node3D and target is Node3D:
		var here: Node3D = node as Node3D
		var start: Vector3 = here.global_position
		var end: Vector3 = (target as Node3D).global_position
		if start.distance_to(end) < 0.001:
			_miss("is at the same place as its target (there is nothing to face)")
			return
		var up: Vector3 = Vector3.UP
		if absf((end - start).normalized().dot(Vector3.UP)) > 0.999:
			up = Vector3.FORWARD
		var goal_turn: Quaternion = Transform3D(Basis(), start).looking_at(end, up).basis.get_rotation_quaternion()
		_keep_first(here, "rotation", here.rotation)
		if seconds <= 0.0:
			_turn_towards(1.0, here, here.global_transform.basis.get_rotation_quaternion(), goal_turn)
			return
		_new_tween().tween_method(_turn_towards.bind(here, here.global_transform.basis.get_rotation_quaternion(), goal_turn), 0.0, 1.0, seconds)
	else:
		_miss("and its target are not both 2D nodes or both 3D nodes")

## A Look At card.
func _look_at(card: Dictionary, seconds: float) -> void:
	turn_to_face(_target(card, "node", true), _target(card, "target", false), seconds)

## Wobbles the angle of a node by up to `degrees` and settles it, with the same fade ticks and curve a Shake card has.
## The angle it had is written back at the end, whatever the last step was.
## @ace_hidden
func rotation_shake(node: Node, degrees: float = 10.0, seconds: float = 0.3, fade_in: bool = false,
		fade_out: bool = true, curve: Curve = null) -> void:
	if node == null or not _can_turn(node):
		_miss("points at no node that can be turned")
		return
	if _refuses_turning(node):
		return
	var path: NodePath = NodePath(_turn_path(node))
	var rest: float = float(node.get_indexed(path))
	_hold_for(node, "rotation", node.get("rotation"), seconds)
	_new_tween().tween_method(_shake_turn.bind(node, path, rest, deg_to_rad(degrees), maxf(seconds, 0.001), fade_in, fade_out, curve), 0.0, 1.0, maxf(seconds, 0.001))

## A Rotation Shake card: the strength of the play scales the angle.
func _rotation_shake(card: Dictionary, at: float, seconds: float) -> void:
	var curve: Curve = null
	var kept: String = str(card.get("curve", "")).strip_edges()
	if not kept.is_empty() and ResourceLoader.exists(kept):
		curve = load(kept) as Curve
	rotation_shake(_target(card, "node", true), float(card.get("degrees", 10.0)) * at, seconds, bool(card.get("fade_in", false)), bool(card.get("fade_out", true)), curve)

## The transition and ease a Light card's ease word stands for.
static func _light_ease_of(word: String) -> Array:
	match word:
		"linear":
			return [Tween.TRANS_LINEAR, Tween.EASE_IN_OUT]
		"in":
			return [Tween.TRANS_SINE, Tween.EASE_IN]
		"in_out":
			return [Tween.TRANS_SINE, Tween.EASE_IN_OUT]
	return [Tween.TRANS_SINE, Tween.EASE_OUT]

## Flares a light to `energy_to` and `colour_to` over `seconds`, and lets it go back by itself over `back_seconds` when
## `comes_back` is on. A light that was off is switched on for the flare and off again after. `energy_from` and
## `colour_from` name where the flare starts when it should not start where the light is now. `at_strength` scales how
## far the flare goes. Stop leaves the light where it got to; Restore puts it back.
## @ace_hidden
func flare_light(light: Node, energy_to: float = 3.0, colour_to: Color = Color(1.0, 0.6, 0.2), seconds: float = 0.08,
		comes_back: bool = true, back_seconds: float = 0.2, trans: Tween.TransitionType = Tween.TRANS_SINE,
		ease_type: Tween.EaseType = Tween.EASE_OUT, energy_from: Variant = null, colour_from: Variant = null,
		at_strength: float = 1.0) -> void:
	var names: Dictionary = light_properties(light) if light != null else {}
	if names.is_empty():
		_miss("points at no light")
		return
	var energy: String = str(names["energy"])
	var colour: String = str(names["colour"])
	var rest_energy: float = float(light.get(energy))
	var rest_colour: Color = light.get(colour)
	_keep_first(light, energy, rest_energy)
	_keep_first(light, colour, rest_colour)
	var peak: float = rest_energy + (energy_to - rest_energy) * at_strength
	var tint: Color = rest_colour.lerp(colour_to, clampf(at_strength, 0.0, 1.0))
	if energy_from != null:
		light.set(energy, float(energy_from))
	if colour_from != null:
		light.set(colour, _colour_of(colour_from))
	back_seconds = maxf(back_seconds, 0.0)
	if not bool(light.get(str(names["on"]))):
		if comes_back:
			_hold_for(light, str(names["on"]), true, seconds + back_seconds)
		else:
			light.set(str(names["on"]), true)
	var made: Tween = _new_tween().set_parallel(true)
	made.set_trans(trans).set_ease(ease_type)
	made.tween_property(light, NodePath(energy), peak, seconds)
	made.tween_property(light, NodePath(colour), tint, seconds)
	if comes_back:
		made.chain().tween_property(light, NodePath(energy), rest_energy, back_seconds)
		made.tween_property(light, NodePath(colour), rest_colour, back_seconds)
		made.finished.connect(_forget_flare.bind(_note_flare(light, energy, colour, rest_energy, rest_colour)))

## A Light card.
func _light(card: Dictionary, at: float, seconds: float) -> void:
	var how: Array = _light_ease_of(str(card.get("ease", "out")))
	flare_light(_target(card, "node", true), float(card.get("energy_to", 3.0)), _colour_of(card.get("colour_to", Color(1.0, 0.6, 0.2))), seconds,
			bool(card.get("back", true)), float(card.get("back_seconds", 0.2)), how[0] as Tween.TransitionType, how[1] as Tween.EaseType,
			card.get("energy_from") if card.has("energy_from") else null, card.get("colour_from") if card.has("colour_from") else null, at)

## The node whose look a Scene Look changes when none is named: the first WorldEnvironment in the running scene.
func _world_environment() -> Node:
	if not is_inside_tree() or get_tree().current_scene == null:
		return null
	var found: Array[Node] = get_tree().current_scene.find_children("*", "WorldEnvironment", true, false)
	return found[0] if not found.is_empty() else null

## Moves one value of the scene's look to a number and back, on the scene's OWN copy of it. `property` is a value of the
## Environment or the camera attributes, such as "glow_intensity". An Environment is a file many scenes share, so the
## first change gives this scene a copy; the file is never written and the original is put back when the time is up, on
## Stop and on Restore. `holder` is the WorldEnvironment or Camera3D to change; left empty it is the first WorldEnvironment in the scene.
## @ace_hidden
func tween_scene_look(property: String = "glow_intensity", to: float = 2.0, seconds: float = 0.1, back_seconds: float = 0.3, holder: Node = null) -> void:
	holder = holder if holder != null else _world_environment()
	var resource: Resource = null
	var members: PackedStringArray = _look_members(holder) if holder != null else PackedStringArray()
	back_seconds = maxf(back_seconds, 0.0)
	for named: String in members:
		var held: Resource = holder.get(named) as Resource
		var probe: Resource = held
		if probe == null:
			if named == "environment":
				probe = Environment.new()
			else:
				probe = CameraAttributesPractical.new()
		if property in probe:
			resource = probe
			if held == null or not held.resource_path.is_empty():
				resource = probe.duplicate() if held != null else probe
				_hold_for(holder, named, resource, seconds + back_seconds)
			break
	if resource == null:
		_miss("finds no look in this scene with a value called \"%s\"" % property)
		return
	var before: Variant = resource.get(property)
	var switch: String = look_switch_of(property)
	_hold_for(resource, property, before, seconds + back_seconds)
	if not switch.is_empty() and switch in resource and not bool(resource.get(switch)):
		_hold_for(resource, switch, true, seconds + back_seconds)
	var made: Tween = _new_tween()
	made.tween_property(resource, NodePath(property), before if is_nan(to) else to, seconds)
	made.tween_property(resource, NodePath(property), before, back_seconds)

## A Scene Look card.
func _scene_look(card: Dictionary, seconds: float) -> void:
	tween_scene_look(str(card.get("property", "glow_intensity")), float(card.get("to", NAN)), seconds, float(card.get("back_seconds", 0.3)), _target(card, "node", false))

## Holds an effect of an audio bus for `seconds`: switches one that is already on the bus on (`BusWay.SWITCH`, with `slot`
## its place), or muffles, dives or washes the bus (`to` is the cutoff in hertz, the level in decibels or the share of wet)
## and puts it back by itself over `back_seconds`. An effect the bus lacks is added at its END, which moves none of the
## others, and is taken off again when the way back is done.
## @ace_hidden
func bus_effect_for(bus: String = "Master", how: BusWay = BusWay.MUFFLE, to: float = 400.0, seconds: float = 0.5,
		back_seconds: float = 0.2, slot: int = 0) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		_miss("names the bus \"%s\", which this project does not have" % bus)
		return
	var word: String = BUS_WAY_WORDS[how]
	back_seconds = maxf(back_seconds, 0.0)
	if how == BusWay.SWITCH:
		if slot < 0 or slot >= AudioServer.get_bus_effect_count(index):
			_miss("names effect %d on the bus %s, which has %d" % [slot, bus, AudioServer.get_bus_effect_count(index)])
			return
		var was_on: bool = AudioServer.is_bus_effect_enabled(index, slot)
		AudioServer.set_bus_effect_enabled(index, slot, true)
		_way_back_in(seconds, AudioServer.set_bus_effect_enabled.bind(index, slot, was_on))
		return
	var mix: Script = _bus_mix()
	if mix == null or not is_inside_tree():
		_miss("needs the bus mix file of the project")
		return
	var wanted: float = bus_value_for(word, to)
	var resting: float = float(mix.call("read", bus, word))
	_bus_hold(bus, word)
	mix.call("sweep", get_tree().root, bus, word, wanted, 0.0)
	_way_back_in(seconds, _sweep_back.bind(bus, word, resting, back_seconds))

## A Bus Effect card.
func _bus_effect(card: Dictionary, seconds: float) -> void:
	var how: int = BUS_WAY_WORDS.find(str(card.get("how", "muffle")))
	var way: BusWay = BusWay.MUFFLE
	if how >= 0:
		way = how as BusWay
	bus_effect_for(str(card.get("bus", "Master")), way, float(card.get("to", 400.0)), seconds,
			float(card.get("back_seconds", 0.2)), int(card.get("slot", 0)))

## Slows the animations and particles under a node to `speed` times their own for `seconds`, and puts their speed back. A
## node of your own code has no speed to slow, and Godot has nothing to slow it with. The speed is the node's own, which
## multiplies with the game's time scale.
## @ace_hidden
func slow_object(node: Node, speed: float = 0.3, seconds: float = 0.5) -> void:
	var found: Array[Node] = speed_nodes_under(node)
	if found.is_empty():
		_miss("finds nothing under %s that has a speed to slow" % (str(node.name) if node != null else "it"))
		return
	for slowed: Node in found:
		_hold_for(slowed, "speed_scale", maxf(speed, 0.0), seconds)

## A Slow One Object card.
func _slow_object(card: Dictionary, seconds: float) -> void:
	slow_object(_target(card, "node", true), float(card.get("speed", 0.3)), seconds)

## Kicks a value of a 2D node (its scale, position, rotation or modulate) by `kick` and lets its Spring node settle it. The
## Spring node moves it back to where it rested, so nothing is left changed; a Stop settles it at once, and Restore puts back
## the value from before. `damping` and `frequency` retune the spring for this property; leave them at NAN to keep its own.
## @ace_hidden
func kick_spring(node: Node, property: String = "scale", kick: Variant = null, damping: float = NAN, frequency: float = NAN,
		at_strength: float = 1.0) -> void:
	if not (node is Node2D):
		_miss("points at a node a Spring node cannot move, which has to be a 2D node")
		return
	var spring: Node = spring_of(node)
	if spring == null:
		_miss("finds no Spring node under %s" % node.name)
		return
	var current: Variant = node.get_indexed(NodePath(property))
	if not [TYPE_FLOAT, TYPE_INT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR].has(typeof(current)):
		_miss("springs %s, which is not a number, a Vector2, a Vector3 or a colour" % property)
		return
	if not is_nan(damping) or not is_nan(frequency):
		var tuned_damping: float = damping if not is_nan(damping) else float(spring.get("default_damping"))
		var tuned_frequency: float = frequency if not is_nan(frequency) else sqrt(float(spring.get("default_stiffness"))) / TAU
		spring.call("set_property_spring", property, tuned_damping, tuned_frequency)
	_keep_first(node, property, current)
	spring.call("bump_property", property, spring_kick(kick, current, at_strength))
	var key: String = "%d|%s" % [spring.get_instance_id(), property]
	if _springs_moving.has(key):
		_ways_back.erase(_springs_moving[key])
	var settle: Callable = _spring_rest.bind(spring, node, property)
	_springs_moving[key] = settle
	_ways_back.append(settle)
	var landed: Callable = _spring_landed.bind(spring)
	if not spring.is_connected("spring_reached", landed):
		spring.connect("spring_reached", landed)

## A Spring card.
func _spring(card: Dictionary, at: float) -> void:
	kick_spring(_target(card, "node", true), str(card.get("property", "scale")), card.get("kick"),
			float(card["damping"]) if card.has("damping") else NAN, float(card["frequency"]) if card.has("frequency") else NAN, at)

## Moves one parameter of an AnimationTree to `to` over `seconds` and brings it back over `back_seconds` when `comes_back`
## is on. A number or a vector is walked; a tick or a whole number is set and put back when the time is up. Stop leaves it
## where it got to, Restore puts it back.
## @ace_hidden
func tween_animation_parameter(tree: AnimationTree, parameter: String, to: Variant = null, seconds: float = 0.2,
		comes_back: bool = true, back_seconds: float = 0.2) -> void:
	if tree == null:
		_miss("points at no animation tree")
		return
	if not writable_parameters(tree).has(parameter):
		_miss("names the parameter \"%s\", which this tree has no writable parameter of" % parameter)
		return
	var rest: Variant = tree.get(parameter)
	_keep_first(tree, parameter, rest)
	back_seconds = maxf(back_seconds, 0.0)
	var wanted: Variant = to if to != null else rest
	match typeof(rest):
		TYPE_BOOL:
			wanted = bool(wanted)
		TYPE_INT:
			wanted = int(wanted)
		TYPE_VECTOR2:
			wanted = wanted as Vector2 if wanted is Vector2 else Vector2(float(wanted), float(wanted))
		_:
			wanted = float(wanted)
	if typeof(rest) == TYPE_BOOL or typeof(rest) == TYPE_INT:
		if comes_back:
			_hold_for(tree, parameter, wanted, seconds)
		else:
			tree.set(parameter, wanted)
		return
	var made: Tween = _new_tween()
	made.tween_method(_set_parameter.bind(tree, parameter), rest, wanted, seconds)
	if comes_back:
		made.tween_method(_set_parameter.bind(tree, parameter), wanted, rest, back_seconds)

## An Animation Parameter card.
func _animation_parameter(card: Dictionary, seconds: float) -> void:
	tween_animation_parameter(_target(card, "node", false) as AnimationTree, str(card.get("parameter", "")), card.get("to"), seconds,
			bool(card.get("back", true)), float(card.get("back_seconds", 0.2)))

# --- The Grayscale and Position Shake cards ---

## The group the Screen FX layer joins, so this pack finds it without naming it.
const SCREEN_FX_GROUP: StringName = &"screen_fx_post_stack"

## The Screen FX layer a Grayscale card greyed, so Stop, Restore and leaving the scene can bring the colour back.
var _gray_screen: Node = null

## The Screen FX layer of the running scene, or null when there is none.
func _screen_fx() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(SCREEN_FX_GROUP)

## Where this player's object is for a screen effect: its place in the world for a 2D object, the place on the screen it
## shows at for a 3D one (the second item is true when the first is already a screen place, 0 to 1 across and down).
func _screen_origin() -> Array:
	if host is Node3D and is_inside_tree():
		var camera: Camera3D = get_viewport().get_camera_3d()
		var size: Vector2 = get_viewport().get_visible_rect().size
		if camera != null and size.x > 0.0 and size.y > 0.0:
			return [camera.unproject_position((host as Node3D).global_position) / size, true]
	if host is Control:
		return [(host as Control).get_global_rect().get_center(), false]
	if host is Node2D:
		return [(host as Node2D).global_position, false]
	return [Vector2(0.5, 0.5), true]

## A Grayscale card: the whole screen, or a circle growing from the object or from a place on the screen. The Screen FX
## layer does the work, so its no-flashing floor and ceiling and the effect-strength dial hold it.
func _grayscale(card: Dictionary, at: float, seconds: float, skipping: bool) -> void:
	var stay: bool = bool(card.get("stay", false))
	if skipping and not stay:
		return
	var screen: Node = _screen_fx()
	if screen == null or not screen.has_method("grayscale_from"):
		_miss("finds no Screen FX layer in the scene to grey")
		return
	var amount: float = clampf(float(card.get("amount", 1.0)) * at, 0.0, 1.0)
	_gray_screen = screen
	if str(card.get("shape", "screen")) != "circle":
		screen.call("grayscale", amount, seconds, float(card.get("fade_in", 0.2)), float(card.get("fade_out", 0.4)), stay)
		return
	var origin: Array = _screen_origin()
	var point: Vector2 = origin[0]
	var in_screen: bool = bool(origin[1])
	if str(card.get("from", "here")) == "screen":
		point = Vector2(float(card.get("screen_x", 0.5)), float(card.get("screen_y", 0.5)))
		in_screen = true
	screen.call("grayscale_from", point, float(card.get("reach", 800.0)), seconds, amount, float(card.get("softness", 0.2)),
			bool(card.get("colour_inside", false)), float(card.get("fade_out", 0.4)), stay, in_screen)

## Brings the colour back if a Grayscale card of this player greyed the screen.
func _end_grayscale() -> void:
	var screen: Node = _gray_screen
	_gray_screen = null
	if screen != null and is_instance_valid(screen) and screen.has_method("clear_grayscale"):
		screen.call("clear_grayscale", 0.0)

## Shakes ONLY the position of a node for `seconds`, by up to `amount` (pixels for a 2D node or a Control, metres for a
## 3D node), then puts it back exactly: never the camera, the rotation or the size. The Juice node beside this player does
## the shaking. The weights say how much of the amount goes along each axis (0 for none, so 0 and 1 and 0 shakes sideways
## only); `jumps_per_second` is how often it jumps to a new place. `at_strength` scales the amount.
## @ace_hidden
func shake_position(node: Node, amount: float = 8.0, seconds: float = 0.4, fade_in: bool = false, fade_out: bool = true,
		curve: Curve = null, x_weight: float = 1.0, y_weight: float = 1.0, z_weight: float = 1.0,
		jumps_per_second: float = 30.0, at_strength: float = 1.0) -> void:
	if node == null or not (node is Node2D or node is Control or node is Node3D):
		_miss("points at no node whose position can be shaken")
		return
	var looked: Array = []
	if host != null:
		looked.append_array(host.get_children())
	looked.append_array(get_children())
	for child: Variant in looked:
		var shaker: Node = child as Node
		if shaker != null and shaker.has_method("shake_position_on") and bool(shaker.call("shake_position_on", node, amount, seconds,
				fade_in, fade_out, curve, Vector3(x_weight, y_weight, z_weight), jumps_per_second, at_strength)):
			return
	_miss("finds no Juice node beside it that can shake %s" % node.name)

## A Position Shake card.
func _position_shake(card: Dictionary, at: float, seconds: float) -> void:
	var curve: Curve = null
	var kept: String = str(card.get("curve", "")).strip_edges()
	if not kept.is_empty() and ResourceLoader.exists(kept):
		curve = load(kept) as Curve
	shake_position(_target(card, "node", true), float(card.get("amount", 8.0)), seconds, bool(card.get("fade_in", false)),
			bool(card.get("fade_out", true)), curve, float(card.get("weight_x", 1.0)), float(card.get("weight_y", 1.0)),
			float(card.get("weight_z", 1.0)), float(card.get("jumps", 30.0)), at)"""
