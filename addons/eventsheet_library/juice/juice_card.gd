## @ace_version(1.0.0)
@icon("res://eventsheet_addons/juice/icon.svg")
class_name JuiceCard
extends Resource
## The base of a juice card of your own. Write a script that extends JuiceCard, export the values you want on the card, and write play(target, strength): the Juice Player lists the script in its Add card box under Yours and plays it when the list reaches it. length, stop and restore are optional.

## The Juice Player playing this card, set just before `play` runs. Find a NodePath export with it.
var player: Node = null

## What the card does when the list reaches it. `target` is the object the Juice Player is under, and
## `strength` is the strength of this play (the row's strength times the player's own). Write a card's
## wait with `await` as in any other function: the player does not stop for it, and `length` says how
## long it lasts.
func play(_target: Node, _strength: float) -> void:
	pass

## How long the card takes, in seconds, so a Hold card and the length of the list can wait for it. A
## card that exports a number called seconds is that long unless it says otherwise.
func length() -> float:
	var named: Variant = get(&"seconds")
	return maxf(float(named), 0.0) if named is float or named is int else 0.0

## Called when the list is stopped, so a card that is still going can end now.
func stop() -> void:
	pass

## Called when the player is asked to put things back, so a card can undo what it changed.
func restore() -> void:
	pass
