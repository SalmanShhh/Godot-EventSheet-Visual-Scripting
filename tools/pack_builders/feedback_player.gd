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

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(_player_lines())
	sheet.events.append(block)

	_verbs(sheet)
	Lib.verb_sentences(sheet, {
		"play": "Play feedbacks at [b]{at_strength}[/b]",
		"play_and_wait": "Play feedbacks at [b]{at_strength}[/b] and wait",
		"play_on_channel": "Play feedbacks on channel [b]{channel}[/b] at [b]{at_strength}[/b]",
		"play_backwards": "Play feedbacks backwards at [b]{at_strength}[/b]"
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
		"if channel.strip_edges().is_empty() or not is_inside_tree():\n\treturn\nget_tree().call_group(channel, \"play\", at_strength)")
	_default(sheet, "channel", "feedback")
	_default(sheet, "at_strength", "1.0")
	Lib.append_function(sheet, "stop", "Stop Feedbacks", "Feedback Player",
		"Stops the play where it is. Whatever a card already started keeps running on its own - this stops the LIST, not the shake it set going.",
		[], "if not playing:\n\treturn\n_live.clear()\n_resumed.emit()\n_close()")
	Lib.append_function(sheet, "skip_to_end", "Skip To End", "Feedback Player",
		"Stops waiting and does everything that is left at once - the cutscene skip of a feedback list. Every card from the head down is felt, without the pauses between them.",
		[], "if not playing:\n\treturn\n_live.clear()\n_paused = false\n_resumed.emit()\nvar left: Array = _order\nvar from: int = _head\nvar at_strength: float = _head_strength\n_close()\nfor index: int in range(from, left.size()):\n\tif not (left[index] is Dictionary):\n\t\tcontinue\n\tvar card: Dictionary = left[index]\n\tif _card_runs(card, at_strength) and not _is_timing(str(card.get(\"verb\", \"\"))):\n\t\t_do_step(card, at_strength)")
	Lib.append_function(sheet, "restore", "Restore Initial Values", "Feedback Player",
		"Puts every value this player's Tween Property cards changed back the way they found it. The undo of a list that moved the object rather than flashing it.",
		[], "for entry: Variant in _restore_to:\n\tvar card: Dictionary = entry as Dictionary\n\tvar object: Object = card.get(\"object\") as Object\n\tif object != null and is_instance_valid(object):\n\t\tobject.set(str(card.get(\"property\", \"\")), card.get(\"value\"))\n_restore_to.clear()")
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


## Pre-fills the last-appended ACE's parameter default, so the dialog opens with a usable value
## (authoring-time metadata only - defaults never appear in the compiled .gd).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


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
		"\t\t_live.clear()",
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
		"\tif _alive(token) and index < order.size():",
		"\t\tpush_warning(\"Feedback Player: a loop on %s never came back, so the play was given up after %d steps.\" % [name, MAX_PLAY_STEPS])",
		"\tif _alive(token):",
		"\t\t_live.erase(token)",
		"\t\t_close()",
		"",
		"## Holds a walk while the player is paused. It waits on the resume signal rather than polling, so a",
		"## pause costs nothing while it lasts, ends the frame it is lifted, and wakes for a stop as well -",
		"## every door that ends a pause raises the same signal.",
		"func _wait_out_pause(token: int) -> void:",
		"\tif _paused and _alive(token):",
		"\t\tawait _resumed",
		"",
		"## What one card does, and where the head goes next. The timing words move the head; every other",
		"## word is a feedback, which is felt and stepped over.",
		"func _take(order: Array, index: int, card: Dictionary, at_strength: float, token: int) -> int:",
		"\tvar word: String = str(card.get(\"verb\", \"\")).strip_edges().to_lower()",
		"\tif not _card_runs(card, at_strength):",
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
		"\t\t\tawait MomentRunner.hold(self, _longest_above(order, index), float(card.get(\"seconds\", 0.0)), clock)",
		"\t\tLOOP_START:",
		"\t\t\tpass",
		"\t\tLOOP_BACK:",
		"\t\t\tvar back: int = _loop_target(order, index, card)",
		"\t\t\tvar left: int = int(card.get(\"loops_left\", card.get(\"loops\", 1)))",
		"\t\t\tif left > 0 and back >= 0:",
		"\t\t\t\tcard[\"loops_left\"] = left - 1",
		"\t\t\t\tawait MomentRunner.then(self, MomentRunner.seconds_of(float(card.get(\"seconds\", 0.0))), clock)",
		"\t\t\t\treturn back",
		"\t\t\tcard[\"loops_left\"] = int(card.get(\"loops\", 1))",
		"\t\t_:",
		"\t\t\tnow_playing = str(card.get(\"label\", word))",
		"\t\t\t_do_step(card, at_strength)",
		"\t\t\tawait _repeat_rest(card, at_strength, clock, token)",
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
		"\tif not bool(card.get(\"active\", true)):",
		"\t\treturn false",
		"\tvar chance: float = float(card.get(\"chance\", 100.0))",
		"\tif chance < 100.0 and randf() * 100.0 >= chance:",
		"\t\treturn false",
		"\tif at_strength < float(card.get(\"min_strength\", 0.0)):",
		"\t\treturn false",
		"\tvar ceiling: float = float(card.get(\"max_strength\", 0.0))",
		"\treturn ceiling <= 0.0 or at_strength <= ceiling",
		"",
		"## One feedback, felt. The ten moment words go to the Juice behaviour beside this node - the same",
		"## call a moment file makes - and this node's own words are done here.",
		"func _do_step(card: Dictionary, at_strength: float) -> void:",
		"\tvar word: String = str(card.get(\"verb\", \"\")).strip_edges().to_lower()",
		"\tvar amount: float = float(card.get(\"amount\", 1.0))",
		"\tvar effect: String = str(card.get(\"effect\", \"\"))",
		"\tvar seconds: float = maxf(float(card.get(\"seconds\", 0.0)), 0.0)",
		"\tmatch word:",
		"\t\tTWEEN_PROPERTY:",
		"\t\t\t_tween_property(effect, MomentRunner.scaled(amount, at_strength), MomentRunner.seconds_of(seconds))",
		"\t\tEMIT_SIGNAL:",
		"\t\t\ton_feedback_signal.emit(effect)",
		"\t\tPLAY_PLAYER:",
		"\t\t\tvar other: Node = get_node_or_null(NodePath(effect))",
		"\t\t\tif other != null and other.has_method(\"play\"):",
		"\t\t\t\tother.call(\"play\", at_strength * maxf(amount, 0.0))",
		"\t\t_:",
		"\t\t\tvar juice: Node = _juice()",
		"\t\t\tif juice != null:",
		"\t\t\t\tjuice.call(\"moment_step\", word, amount, effect, seconds, at_strength * maxf(strength, 0.0))",
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
		"\tcreate_tween().tween_property(host, NodePath(property), value, seconds)",
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
		"\tvar walk: int = index - 1",
		"\twhile walk >= 0:",
		"\t\tvar card: Dictionary = order[walk] as Dictionary",
		"\t\tvar word: String = str(card.get(\"verb\", \"\"))",
		"\t\tif word == HOLD_UNTIL:",
		"\t\t\tbreak",
		"\t\tif bool(card.get(\"active\", true)):",
		"\t\t\tlongest = maxf(longest, maxf(float(card.get(\"seconds\", 0.0)), 0.0))",
		"\t\twalk -= 1",
		"\treturn longest",
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
		"\tprogress = 0.0",
		"\t_order = order",
		"\t_head = 0",
		"\t_head_strength = at_strength",
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
