## @ace_version(1.0.0)
class_name HapticPatternResource
extends Resource
## One shape a controller or a phone can be felt in: how hard, how long, and how many times - the file the Haptic row plays.

# WHAT A HAPTIC PATTERN IS, and why it is a file rather than three numbers on a row.
#
# A rumble is not one number. A tap is one short pulse; an alarm is four of them with air between;
# a heavy landing is one long one. Those are three shapes, and a game uses each of them in twenty
# places - so the shape belongs somewhere it can be tuned once and felt everywhere, which is a file
# the project owns.
#
# NOTHING SHIPS. There is no house "light", no house "success" and no house "failure", because how
# a game feels in the hand is the game's. A new HapticPatternResource opens on the ONE shape that is
# not a taste - a single short tap at full strength - and everything else is made from there.
#
# THE FOUR NUMBERS, and nothing else:
#   amplitude     how hard, from 0 to 1. Both motors of a pad get it, and a phone gets a buzz of the
#                 same length; there is no weak-and-strong pair here because a shape that reads
#                 differently on every pad is not a shape.
#   seconds       how long one pulse lasts.
#   repeats       how many pulses. One is a tap; four is an alarm.
#   gap_seconds   the air between two pulses. Without it, four repeats are one long buzz, so the gap
#                 is what makes a repeat a repeat.
#
# PLAIN GDSCRIPT, AND NOT THE PLUGIN'S. This file ships in the project's own folder and names no
# plugin class, so a `.tres` made from it goes on loading after the editor is gone.

## How hard the pulse is, from 0 (nothing) to 1 (as hard as the device goes). Scaled by the player's
## own haptic strength before it reaches the device.
@export_range(0.0, 1.0, 0.01) var amplitude: float = 1.0

## How long one pulse lasts, in seconds.
@export_range(0.0, 5.0, 0.01, "or_greater") var seconds: float = 0.08

## How many pulses. One is a tap; four with air between them is an alarm.
@export_range(1, 32, 1, "or_greater") var repeats: int = 1

## The air between two pulses, in seconds. Without it a repeat is not felt as a repeat.
@export_range(0.0, 2.0, 0.01, "or_greater") var gap_seconds: float = 0.06


## How long the whole shape takes, from the start of the first pulse to the end of the last - what a
## moment step declares as its duration so a Hold above it knows how long to wait.
func length() -> float:
	var pulses: int = maxi(repeats, 1)
	return pulses * maxf(seconds, 0.0) + (pulses - 1) * maxf(gap_seconds, 0.0)
