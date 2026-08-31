# Godot EventSheets - the RUNNING game's own state, read back onto the sheet that declares it.
#
# An object's state is a variable, so watching it while the game runs is watching a variable: the
# same Live Values stream that already puts "now 100" beside a variable row carries the state and
# how long it has held, and this reads those two entries out of it. There is no second channel, no
# second protocol and no second store - a sheet that streams nothing here streams nothing at all.
#
# WHAT THE GAME SENDS, and why exactly these two:
#
#     "state"          State.keys()[state]                                     -> "CHASE"
#     "state_seconds"  (Time.get_ticks_msec() - state_entered_msec) / 1000.0    -> 3.2
#
# The second one is not a number invented for a readout: it is the LEFT-HAND SIDE of the line the
# Is in X for over Ns row compiles to, character for character. So the progress this shows beside
# that row is the very quantity the row compares, and the band and the row can never disagree.
#
# THE SAME SHAPE AS THE GAME'S MODES, one level down. The mode of a game rides this same stream
# (`"mode"`, `"mode_stack"`), written by the same place in the compiler, so a reader who has watched
# a game's mode has already watched an object's state.
#
# THE CADENCE IS THE STREAM'S. The running game flushes a values frame every 0.25 s, and this store
# is written only when one arrives. Nothing here counts, extrapolates or runs on an editor frame: a
# number shown between two frames is the number the last frame carried, which is why the reading can
# be trusted to be something the game actually said rather than something the editor guessed.
#
# STRICTLY READ-ONLY. Everything here takes plain Dictionaries and Strings and returns text. No
# sheet, no row and no resource is reachable from this file, which is what makes "play mode never
# edits the document" a property of the code rather than a promise about it.
#
# STATIC, deliberately: what the game is doing belongs to the RUN, not to a tab or a pane, so every
# view of every sheet reads the same answer and a closed dock does not lose it.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetStateWatch
extends RefCounted

## The two entries a states sheet adds to its live-values frame. FROZEN, and pinned against the
## compiler by a test rather than trusted: the emitter writes these names as literals (the way the
## game's modes are written), so the one thing that can go wrong is the two halves drifting apart.
const STATE_KEY: String = "state"
const SECONDS_KEY: String = "state_seconds"

## How often the running game flushes a values frame - the compiler's own throttle. Stated rather
## than felt: a band that ticks four times a second is telling the truth four times a second, and a
## reader is owed that number instead of having to time it.
const CADENCE_SECONDS: float = 0.25

## Which copy of the game -> its last streamed {state, seconds}. Keyed exactly the way the live
## values chips are keyed: "" for a lone run, and the feature tag ("host", "client") when a run is
## two games at once.
static var _frames: Dictionary = {}


## One streamed frame -> what this store knows. A frame WITHOUT the state entries drops whatever
## that instance last said rather than leaving it standing: a sheet whose object has no states
## streams no state, and a stale "current: Chase" over a game that is no longer in Chase - or no
## longer has states at all - is the one reading worse than none.
static func note_frame(values: Dictionary, instance: String = "") -> void:
	if not values.has(STATE_KEY):
		_frames.erase(instance)
		return
	# A lone run and a labelled one never mix, the same rule the value chips follow: a frame with no
	# label replaces every labelled one and the other way round, so a second run cannot leave a
	# reading naming a window from the first.
	var keys: Array = _frames.keys()
	var was_labelled: bool = not keys.is_empty() and not str(keys[0]).is_empty()
	if was_labelled != (not instance.is_empty()):
		_frames.clear()
	_frames[instance] = {
		"state": str(values[STATE_KEY]),
		"seconds": float(values.get(SECONDS_KEY, 0.0)),
	}


## The run ended, or the game was stopped. Announced rather than inferred - "no frame has arrived
## recently" and "the game is gone" look identical from here, and only one of them means the last
## reading is no longer true.
static func clear() -> void:
	_frames.clear()


## True while a running game is saying what state it is in. Every readout is gated on this: with no
## run there is no band reading and no progress, rather than a guess drawn as a fact.
static func is_live() -> bool:
	return not _frames.is_empty()


## How long the running game has been in its current state, in seconds - the number the timed row
## compares. -1.0 when nothing is streaming, which callers read as "no answer", never as zero.
static func held_seconds(instance: String = "") -> float:
	var frame: Variant = _frames.get(instance)
	return -1.0 if not (frame is Dictionary) else float((frame as Dictionary).get("seconds", 0.0))


## The states band's live half: "current: Chase · 3.2 s", or "host · current: Chase · 3.2 s   client
## · current: Patrol · 0.5 s" while a run is two games. "" when nothing is running, which is what
## keeps the band exactly what it was on a sheet nobody is playing.
static func band_reading() -> String:
	var readings: PackedStringArray = PackedStringArray()
	for instance: Variant in _frames:
		var frame: Dictionary = _frames[instance]
		var said: String = compose_band(str(frame.get("state", "")), float(frame.get("seconds", 0.0)))
		if said.is_empty():
			continue
		readings.append(said if str(instance).is_empty() else "%s · %s" % [str(instance), said])
	return "   ".join(readings)


## One game's band reading. The state arrives as the enum MEMBER the game sent (CHASE) and is said
## as the word the whole plugin says it with, so the band, the dropdown and the row cannot spell one
## state three ways. "" for a frame that named no state.
static func compose_band(member: String, seconds: float) -> String:
	if member.strip_edges().is_empty():
		return ""
	return EventSheetL10n.translate("current: %s · %s s") % [
		EventSheetStateFacts.word_for(member.strip_edges()), seconds_text(seconds)]


## The timed row's progress, in place: "3.2 of 6" - how long this object has been in a state against
## how long that row is waiting for. "" when nothing is running, so the row reads exactly as it reads
## with the game closed. Labelled per copy while a run is two games, exactly as the band is.
static func progress_reading(target_seconds: float) -> String:
	var readings: PackedStringArray = PackedStringArray()
	for instance: Variant in _frames:
		var held: float = held_seconds(str(instance))
		if held < 0.0:
			continue
		var said: String = compose_progress(held, target_seconds)
		readings.append(said if str(instance).is_empty() else "%s · %s" % [str(instance), said])
	return "   ".join(readings)


## The two numbers, said the way a person says them: no bar, no percentage, no unit repeated twice -
## the row already ends in "s", and a progress that spells the unit again reads as a second number.
static func compose_progress(held: float, target: float) -> String:
	return EventSheetL10n.translate("%s of %s") % [seconds_text(held), seconds_text(target)]


## 3.24 -> "3.2", 6.0 -> "6". One decimal, because the stream carries a new one four times a second
## and a third digit would be noise changing faster than a reader can read it; and a whole number
## keeps no ".0", because "6" is what the row's own parameter says.
static func seconds_text(seconds: float) -> String:
	var said: String = "%.1f" % maxf(seconds, 0.0)
	return said.trim_suffix(".0") if said.ends_with(".0") else said


## The hover words on the states band: what the live half of it is, and how often it is true. Said
## on the band rather than in a guide, because the number ticking in front of a reader is exactly
## where the question "how fresh is this" gets asked.
static func cadence_note() -> String:
	return EventSheetL10n.translate("While the game runs, this band says the state it is in and how long it has held - refreshed %s times a second, from the game's own report.") % str(int(round(1.0 / CADENCE_SECONDS)))
