# Pack builder - boosts (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Boosts: temporary timed multipliers - the golden-cookie "Frenzy x7 for 77 seconds" of an idle game, as
## an AUTOLOAD sheet. Start a named boost with a multiplier and a duration; it counts itself down every
## frame and fires On Boost Expired when it runs out. Total Multiplier is the product of every active
## boost (Multiplier For Tag narrows it to one group), so you fold it straight into production the same way
## as prestige and upgrade multipliers. Stack several at once, extend one, or stop it early. Plain Godot,
## zero plugin dependency.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "Boost"
	sheet.host_class = "Node"
	sheet.custom_class_name = "BoostAddon"
	sheet.addon_category = "Boosts"
	sheet.addon_tags = PackedStringArray(["incremental", "idle", "boost"])
	var about: CommentRow = CommentRow.new()
	about.text = "Boosts: register as the Boost autoload. Start Boost(id, multiplier, duration) begins a timed multiplier that counts itself down and fires On Boost Expired when it ends. Total Multiplier multiplies every active boost together; Multiplier For Tag narrows it to a group. Fold Total Multiplier into your production alongside prestige and upgrade multipliers. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Boost Started\")",
		"## @ace_category(\"Boosts\")",
		"signal on_boost_started",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Boost Expired\")",
		"## @ace_category(\"Boosts\")",
		"signal on_boost_expired",
		"",
		"# id -> {multiplier, remaining (seconds), tag}. Absent = inactive.",
		"var _boosts: Dictionary = {}",
		"# The boost that just ran out (read inside On Boost Expired).",
		"var _last_expired_id: String = \"\""
	]))
	sheet.events.append(block)

	# Self-tick: count every active boost down, fire On Boost Expired as each ends.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if _boosts.is_empty():",
		"\treturn",
		"var expired: Array = []",
		"for id: String in _boosts.keys():",
		"\tvar boost: Dictionary = _boosts[id]",
		"\tboost.remaining -= delta",
		"\tif boost.remaining <= 0.0:",
		"\t\texpired.append(id)",
		"for id: String in expired:",
		"\t# Re-check: an On Boost Expired handler processed earlier this frame may have restarted or",
		"\t# extended a boost still queued here - do not erase one that is live again.",
		"\tif _boosts.has(id) and _boosts[id].remaining <= 0.0:",
		"\t\t_boosts.erase(id)",
		"\t\t_last_expired_id = id",
		"\t\ton_boost_expired.emit()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# --- Starting / stopping ---
	Lib.append_function(sheet, "start_boost", "Start Boost", "Boosts", "Starts (or restarts) a timed multiplier by id for `duration` seconds and fires On Boost Started.",
		[["id", "String"], ["multiplier", "float"], ["duration", "float"]], "\n".join(PackedStringArray([
			"_boosts[id] = {\"multiplier\": multiplier, \"remaining\": maxf(duration, 0.0), \"tag\": \"\"}",
			"on_boost_started.emit()"
		])))
	Lib.append_function(sheet, "start_tagged_boost", "Start Tagged Boost", "Boosts", "Like Start Boost, but with a tag so Multiplier For Tag can group it (e.g. \"production\", \"click\").",
		[["id", "String"], ["multiplier", "float"], ["duration", "float"], ["tag", "String"]], "\n".join(PackedStringArray([
			"_boosts[id] = {\"multiplier\": multiplier, \"remaining\": maxf(duration, 0.0), \"tag\": tag}",
			"on_boost_started.emit()"
		])))
	Lib.append_function(sheet, "extend_boost", "Extend Boost", "Boosts", "Adds seconds to an active boost's timer (does nothing if it is not active).",
		[["id", "String"], ["seconds", "float"]], "\n".join(PackedStringArray([
			"if _boosts.has(id):",
			"\t_boosts[id].remaining += seconds"
		])))
	Lib.append_function(sheet, "stop_boost", "Stop Boost", "Boosts", "Ends a boost immediately (no On Boost Expired - that is for timers running out).",
		[["id", "String"]], "\n".join(PackedStringArray([
			"if _boosts.has(id):",
			"\t_boosts.erase(id)"
		])))
	Lib.append_function(sheet, "clear_boosts", "Clear Boosts", "Boosts", "Ends every active boost at once.",
		[],
		"_boosts.clear()")

	# --- Conditions ---
	Lib.condition(sheet, "is_active", "Is Active", "Boosts", "Whether a boost with this id is currently running.",
		[["id", "String"]],
		"return _boosts.has(id)")
	Lib.condition(sheet, "any_active", "Any Active", "Boosts", "Whether any boost is currently running.",
		[],
		"return not _boosts.is_empty()")

	# --- Expressions ---
	Lib.number(sheet, "total_multiplier", "Total Multiplier", "Boosts", "The product of every active boost's multiplier (1.0 if none) - fold it into production.",
		[], "\n".join(PackedStringArray([
			"var product: float = 1.0",
			"for id: String in _boosts:",
			"\tproduct *= float(_boosts[id].multiplier)",
			"return product"
		])), TYPE_FLOAT)
	Lib.number(sheet, "multiplier_for_tag", "Multiplier For Tag", "Boosts", "The product of active boosts that share this tag (1.0 if none).",
		[["tag", "String"]], "\n".join(PackedStringArray([
			"var product: float = 1.0",
			"for id: String in _boosts:",
			"\tif str(_boosts[id].tag) == tag:",
			"\t\tproduct *= float(_boosts[id].multiplier)",
			"return product"
		])), TYPE_FLOAT)
	Lib.number(sheet, "multiplier_of", "Multiplier Of", "Boosts", "One boost's multiplier (1.0 if it is not active).",
		[["id", "String"]], "return float(_boosts[id].multiplier) if _boosts.has(id) else 1.0", TYPE_FLOAT)
	Lib.number(sheet, "time_left", "Time Left", "Boosts", "Seconds remaining on a boost (0 if not active) - for a countdown label.",
		[["id", "String"]], "return maxf(float(_boosts[id].remaining), 0.0) if _boosts.has(id) else 0.0", TYPE_FLOAT)
	Lib.number(sheet, "active_count", "Active Count", "Boosts", "How many boosts are currently running.",
		[], "return _boosts.size()", TYPE_INT)
	Lib.number(sheet, "last_expired", "Last Expired", "Boosts", "The id of the boost that just ran out (read inside On Boost Expired).",
		[], "return _last_expired_id", TYPE_STRING)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"# Each entry carries its own `remaining` seconds, so restored boosts resume mid-countdown.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"boosts\": _boosts.duplicate(true)",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_boosts = (state.get(\"boosts\", {}) as Dictionary).duplicate(true)"
	]))
	sheet.events.append(persistence)

	return Lib.save_pack(sheet, "res://eventsheet_addons/boosts/boosts_addon")
