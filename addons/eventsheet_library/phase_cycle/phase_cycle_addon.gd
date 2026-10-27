## @ace_tags(time, day-night, cycle)
## @ace_category("Phase Cycle")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/phase_cycle/icon.svg")
class_name PhaseCycleAddon
extends Node
## A named cycle the whole game shares - day/night, seasons, waves, shop-then-fight. Give Cycle Phases a comma-separated list and a length in seconds; it ticks itself, rolls to the next name when the time is up, and fires On Phase Changed with the phase you left and the phase you entered. Phase Is branches on the current one and Phase Progress (0-1) drives sun dials and fades.

## @ace_trigger
## @ace_name("On Phase Changed")
## @ace_category("Phase Cycle")
signal on_phase_changed(previous: String, next: String)

# The parsed phase names, which one is current, how long each lasts, and how far into the
# current one we are. _running is false until Cycle Phases is called, and again after Stop Cycle.
var _phases: PackedStringArray = PackedStringArray()
var _index: int = 0
var _seconds_per: float = 0.0
var _elapsed: float = 0.0
var _running: bool = false

func _ready() -> void:
	set_process(_running)

func _process(delta: float) -> void:
	advance(delta)

## @ace_action
## @ace_featured
## @ace_name("Cycle Phases")
## @ace_category("Phase Cycle")
## @ace_description("Starts (or restarts) the cycle from a comma-separated list of phase names - "day,night" or "spring,summer,autumn,winter" - with each phase lasting seconds_each. Begins on the first name and fires On Phase Changed for it right away, so the systems listening set themselves up correctly on the first frame.")
## @ace_display_template("Cycle phases [b]{phases}[/b], [b]{seconds_each}[/b] s each")
## @ace_icon("res://eventsheet_addons/phase_cycle/icon.svg")
## @ace_codegen_template("Phases.cycle_phases({phases}, {seconds_each})")
func cycle_phases(phases: String, seconds_each: float) -> void:
	_phases = PackedStringArray()
	for part: String in phases.split(",", false):
		var phase_name: String = part.strip_edges()
		if not phase_name.is_empty():
			_phases.append(phase_name)
	_index = 0
	_elapsed = 0.0
	_seconds_per = maxf(seconds_each, 0.0)
	_running = not _phases.is_empty() and _seconds_per > 0.0
	# An empty list, or a length of zero, leaves nothing for a frame to advance - and the
	# clock is switched on before the first trigger so a handler that stops it here wins.
	set_process(_running)
	if _running:
		on_phase_changed.emit("", _phases[0])

## @ace_action
## @ace_name("Stop Cycle")
## @ace_category("Phase Cycle")
## @ace_description("Freezes the cycle where it stands. The current phase and its progress keep their values (Phase Is and Phase Progress still read them) - only the clock stops. Call Cycle Phases again to start over.")
## @ace_icon("res://eventsheet_addons/phase_cycle/icon.svg")
## @ace_codegen_template("Phases.stop_cycle()")
func stop_cycle() -> void:
	_running = false
	# A frozen cycle costs nothing per frame; Cycle Phases turns the clock back on.
	set_process(false)

## @ace_condition
## @ace_name("Phase Is")
## @ace_category("Phase Cycle")
## @ace_description("True while the cycle is on the named phase - the branch for "only spawn ghosts at night". Names are matched exactly, so keep the spelling identical to the list you passed Cycle Phases.")
## @ace_icon("res://eventsheet_addons/phase_cycle/icon.svg")
## @ace_codegen_template("Phases.phase_is({phase_name})")
func phase_is(phase_name: String) -> bool:
	return not _phases.is_empty() and _phases[_index] == phase_name

## @ace_expression
## @ace_featured
## @ace_name("Current Phase")
## @ace_category("Phase Cycle")
## @ace_description("The name of the phase the cycle is on right now (nothing at all before Cycle Phases runs) - print it straight into a HUD label.")
## @ace_icon("res://eventsheet_addons/phase_cycle/icon.svg")
## @ace_codegen_template("Phases.current_phase()")
func current_phase() -> String:
	return _phases[_index] if not _phases.is_empty() else ""

## @ace_expression
## @ace_name("Phase Progress")
## @ace_category("Phase Cycle")
## @ace_description("How far through the current phase the cycle is, from 0 at its start to 1 at its end. Feed it to a sun dial's rotation, a light's colour blend, or a Progress Of style bar.")
## @ace_icon("res://eventsheet_addons/phase_cycle/icon.svg")
## @ace_codegen_template("Phases.phase_progress()")
func phase_progress() -> float:
	return clampf(_elapsed / _seconds_per, 0.0, 1.0) if _seconds_per > 0.0 else 0.0

## @ace_expression
## @ace_name("Phases Count")
## @ace_category("Phase Cycle")
## @ace_description("How many phases the cycle holds - useful for a "day 3 of 4" readout or for stepping a dial in even slices.")
## @ace_icon("res://eventsheet_addons/phase_cycle/icon.svg")
## @ace_codegen_template("Phases.phases_count()")
func phases_count() -> int:
	return _phases.size()

## @ace_hidden
func advance(delta: float) -> void:
	# The clock. A while loop (not an if) so one huge delta - a stall, a loading hitch, a sped-up
	# clock - rolls through every phase it crossed and fires On Phase Changed for each of them.
	if not _running or _phases.is_empty() or _seconds_per <= 0.0:
		return
	_elapsed += delta
	while _elapsed >= _seconds_per:
		_elapsed -= _seconds_per
		var previous: String = _phases[_index]
		_index = (_index + 1) % _phases.size()
		on_phase_changed.emit(previous, _phases[_index])

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	# Restoring assigns the clock directly - a load must not fire On Phase Changed.
	return {
		"phases": Array(_phases),
		"index": _index,
		"seconds_per": _seconds_per,
		"elapsed": _elapsed,
		"running": _running
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_phases = PackedStringArray(state.get("phases", []) as Array)
	_index = int(state.get("index", 0))
	_seconds_per = float(state.get("seconds_per", 0.0))
	_elapsed = float(state.get("elapsed", 0.0))
	_running = bool(state.get("running", false))
	# A save taken mid-cycle reopens mid-cycle, so the clock follows the restored state.
	set_process(_running)

# Phase Cycle (autoload): register as the Phases autoload, then Cycle Phases("day,night", 60) once at startup. The autoload ticks its own clock every frame - there is nothing to drive from a sheet. On Phase Changed fires at every roll with (previous, next); Phase Is branches on the current phase; Phase Progress runs 0-1 through it and wraps. This pack is an event sheet - extend it by editing it.
