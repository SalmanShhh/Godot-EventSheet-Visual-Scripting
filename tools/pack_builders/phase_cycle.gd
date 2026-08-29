# Pack builder - phase_cycle (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Phase Cycle: a day/night (or wave, or season) clock as an AUTOLOAD, so every system in the game
## reads ONE current phase. Cycle Phases takes a comma-separated list and a length in seconds; the
## autoload ticks itself and fires On Phase Changed at every roll with the phase you left and the
## phase you entered. Phase Progress (0-1) drives sun dials and fades.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "Phases"
	sheet.host_class = "Node"
	sheet.custom_class_name = "PhaseCycleAddon"
	sheet.class_description = "A named cycle the whole game shares - day/night, seasons, waves, shop-then-fight. Give Cycle Phases a comma-separated list and a length in seconds; it ticks itself, rolls to the next name when the time is up, and fires On Phase Changed with the phase you left and the phase you entered. Phase Is branches on the current one and Phase Progress (0-1) drives sun dials and fades."
	sheet.addon_category = "Phase Cycle"
	sheet.addon_tags = PackedStringArray(["time", "day-night", "cycle"])

	var about: CommentRow = CommentRow.new()
	about.text = "Phase Cycle (autoload): register as the Phases autoload, then Cycle Phases(\"day,night\", 60) once at startup. The autoload ticks its own clock every frame - there is nothing to drive from a sheet. On Phase Changed fires at every roll with (previous, next); Phase Is branches on the current phase; Phase Progress runs 0-1 through it and wraps. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var phase_changed: SignalRow = SignalRow.new()
	phase_changed.signal_name = "on_phase_changed"
	phase_changed.params = PackedStringArray(["previous: String", "next: String"])
	phase_changed.trigger = true
	phase_changed.ace_name = "On Phase Changed"
	phase_changed.ace_category = "Phase Cycle"
	sheet.events.append(phase_changed)

	# Class-level state plus the clock itself. advance() is deliberately unpublished: the autoload
	# drives it from its own _process row below, so a sheet never has to hand it a delta.
	var state: RawCodeRow = RawCodeRow.new()
	state.code = "\n".join(PackedStringArray([
		"# The parsed phase names, which one is current, how long each lasts, and how far into the",
		"# current one we are. _running is false until Cycle Phases is called, and again after Stop Cycle.",
		"var _phases: PackedStringArray = PackedStringArray()",
		"var _index: int = 0",
		"var _seconds_per: float = 0.0",
		"var _elapsed: float = 0.0",
		"var _running: bool = false",
		"",
		"# The clock. A while loop (not an if) so one huge delta - a stall, a loading hitch, a sped-up",
		"# clock - rolls through every phase it crossed and fires On Phase Changed for each of them.",
		"## @ace_hidden",
		"func advance(delta: float) -> void:",
		"\tif not _running or _phases.is_empty() or _seconds_per <= 0.0:",
		"\t\treturn",
		"\t_elapsed += delta",
		"\twhile _elapsed >= _seconds_per:",
		"\t\t_elapsed -= _seconds_per",
		"\t\tvar previous: String = _phases[_index]",
		"\t\t_index = (_index + 1) % _phases.size()",
		"\t\ton_phase_changed.emit(previous, _phases[_index])"
	]))
	sheet.events.append(state)

	# An autoload exists for the whole game, so the frames it does not need matter: nothing is
	# cycling until Cycle Phases says so, and until then the clock costs nothing.
	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "set_process(_running)"
	ready_row.actions.append(ready_body)
	sheet.events.append(ready_row)

	# Self-tick: the autoload owns its own clock, the same way the Boosts autoload counts its
	# timers down. Nothing in a user sheet has to remember to feed it a delta.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "advance(delta)"
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	Lib.append_function(sheet, "cycle_phases", "Cycle Phases", "Phase Cycle",
		"Starts (or restarts) the cycle from a comma-separated list of phase names - \"day,night\" or \"spring,summer,autumn,winter\" - with each phase lasting seconds_each. Begins on the first name and fires On Phase Changed for it right away, so the systems listening set themselves up correctly on the first frame.",
		[["phases", "String"], ["seconds_each", "float"]],
		"\n".join(PackedStringArray([
			"_phases = PackedStringArray()",
			"for part: String in phases.split(\",\", false):",
			"\tvar phase_name: String = part.strip_edges()",
			"\tif not phase_name.is_empty():",
			"\t\t_phases.append(phase_name)",
			"_index = 0",
			"_elapsed = 0.0",
			"_seconds_per = maxf(seconds_each, 0.0)",
			"_running = not _phases.is_empty() and _seconds_per > 0.0",
			"# An empty list, or a length of zero, leaves nothing for a frame to advance - and the",
			"# clock is switched on before the first trigger so a handler that stops it here wins.",
			"set_process(_running)",
			"if _running:",
			"\ton_phase_changed.emit(\"\", _phases[0])"
		])),
		"Cycle phases [b]{phases}[/b], [b]{seconds_each}[/b] s each")

	Lib.append_function(sheet, "stop_cycle", "Stop Cycle", "Phase Cycle",
		"Freezes the cycle where it stands. The current phase and its progress keep their values (Phase Is and Phase Progress still read them) - only the clock stops. Call Cycle Phases again to start over.",
		[],
		"_running = false\n# A frozen cycle costs nothing per frame; Cycle Phases turns the clock back on.\nset_process(false)")

	Lib.condition(sheet, "phase_is", "Phase Is", "Phase Cycle",
		"True while the cycle is on the named phase - the branch for \"only spawn ghosts at night\". Names are matched exactly, so keep the spelling identical to the list you passed Cycle Phases.",
		[["phase_name", "String"]],
		"return not _phases.is_empty() and _phases[_index] == phase_name")

	Lib.number(sheet, "current_phase", "Current Phase", "Phase Cycle",
		"The name of the phase the cycle is on right now (nothing at all before Cycle Phases runs) - print it straight into a HUD label.",
		[],
		"return _phases[_index] if not _phases.is_empty() else \"\"",
		TYPE_STRING)

	Lib.number(sheet, "phase_progress", "Phase Progress", "Phase Cycle",
		"How far through the current phase the cycle is, from 0 at its start to 1 at its end. Feed it to a sun dial's rotation, a light's colour blend, or a Progress Of style bar.",
		[],
		"return clampf(_elapsed / _seconds_per, 0.0, 1.0) if _seconds_per > 0.0 else 0.0",
		TYPE_FLOAT)

	Lib.number(sheet, "phases_count", "Phases Count", "Phase Cycle",
		"How many phases the cycle holds - useful for a \"day 3 of 4\" readout or for stepping a dial in even slices.",
		[],
		"return _phases.size()",
		TYPE_INT)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"# Restoring assigns the clock directly - a load must not fire On Phase Changed.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"phases\": Array(_phases),",
		"\t\t\"index\": _index,",
		"\t\t\"seconds_per\": _seconds_per,",
		"\t\t\"elapsed\": _elapsed,",
		"\t\t\"running\": _running",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_phases = PackedStringArray(state.get(\"phases\", []) as Array)",
		"\t_index = int(state.get(\"index\", 0))",
		"\t_seconds_per = float(state.get(\"seconds_per\", 0.0))",
		"\t_elapsed = float(state.get(\"elapsed\", 0.0))",
		"\t_running = bool(state.get(\"running\", false))",
		"\t# A save taken mid-cycle reopens mid-cycle, so the clock follows the restored state.",
		"\tset_process(_running)"
	]))
	sheet.events.append(persistence)

	Lib.feature_verbs(sheet, ["cycle_phases", "current_phase"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/phase_cycle/phase_cycle_addon")
