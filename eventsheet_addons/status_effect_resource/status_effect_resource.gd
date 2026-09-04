## @ace_tags(status, effect, buff, debuff, resource)
## @ace_category("Status Effects")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/status_effect_resource/icon.svg")
class_name StatusEffectResource
extends Resource
## One status effect as a file you own: what it ticks for and in what kind of damage, how often, what it does to speed, the colour it tints the thing wearing it, the icon that stands for it, how a second application stacks, and whether it can be cleansed. The Status Effects behaviour reads these; six starters ship beside it to edit or delete.

# @inspector_header The Effect #e0793f
# @inspector_info Everything below is what the effect DOES while it is on. A field left at its default does nothing at all, so a pure flag - a status the movement packs and the state machine only ask about - is a file with nothing but a name.
## The word rows call this effect by ("burn"). Leave it blank and the file's own name is the word, so renaming the file renames the effect.
@export var status_name: String = ""
## The colour the host is tinted while this is on. White is no tint. The behaviour multiplies the tints of everything active, holds the shift under the accessibility ceiling while a player has asked for no flashing, and puts the original colour back when the last one ends.
@export var tint: Color = Color(1.0, 1.0, 1.0, 1.0)
## The picture that stands for this effect. Status Icon hands it straight to a HUD texture, so the bar over the health bar needs no table of its own.
@export var icon: Texture2D = null
# @inspector_header Every Tick #c0554a
## Damage dealt on every tick, per stack. It goes through the Health pack's typed pipeline, so resistances, armour and the damage report all apply exactly as they do to a hit.
@export_range(0, 1000, 0.5) var tick_amount: float = 0.0
## What kind of damage a tick is - "fire", "poison", whatever this game's damage type set calls it. Blank is untyped, which every Health behaviour still understands.
@export var tick_type: String = ""
## How long between ticks, in seconds of game time. A paused or slowed game slows the ticking with it.
@export_range(0.05, 60, 0.05) var tick_seconds: float = 0.5
## Health restored on every tick, per stack - a regeneration, a bandage, a healing circle. It is applied after the tick damage, so an effect may do both.
@export_range(0, 1000, 0.5) var heal_amount: float = 0.0
# @inspector_header While It Lasts #7c9cf5
## What this effect multiplies movement speed by while it is on: 0.5 for a slow, 0 for a root, 1.4 for a haste. The behaviour's Speed Factor expression is the product of every active effect's, and it is the movement pack that multiplies by it.
@export_range(0, 10, 0.05) var speed_factor: float = 1.0
## The Boosts tag this effect feeds while it is on - "damage", "production", whatever the game already groups multipliers by. Blank feeds none, and a project without the Boosts pack simply gets nothing here.
@export var multiplier_tag: String = ""
## What it multiplies that tag by. The Boosts pack stays the multiplier engine: this effect starts a tagged boost when it lands and stops it when it ends.
@export_range(0, 100, 0.05) var multiplier: float = 1.0
# @inspector_header Stacking #b48ead
## What a second application does: "refresh" puts the clock back to the new time, "extend" adds the new time to what was left, "add" refreshes the clock and adds stacks up to Max Stacks.
@export_enum("refresh", "extend", "add") var stacking: String = "refresh"
## The most stacks this effect can reach. Ticks and healing are multiplied by the stack count, so five stacks of a bleed bleed five times as fast.
@export_range(1, 999, 1) var max_stacks: int = 1
## Whether a Cleanse with no name takes this one off. Turn it off for a curse, a story debuff or anything the antidote is not supposed to answer.
@export var cleansable: bool = true
## A scene added under the host while this is on and freed when it ends - the flames, the drips, the frost. Leave it empty and the effect is invisible apart from its tint.
@export var particle_scene: PackedScene = null

## The three answers this file gives are pure - no host, no tree, no time - so a stacking rule
## can be read, tested and argued about by looking at this one resource.
##
## The word rows call this effect by: Status Name when it has been filled in, and otherwise
## the file's own name, so `burn.tres` is "burn" with nothing typed anywhere.
func called() -> String:
	if not status_name.strip_edges().is_empty():
		return status_name.strip_edges()
	return resource_path.get_file().get_basename()

## How many stacks are on after applying `added` more to `current`. "add" piles them up to
## Max Stacks; the other two rules leave the count where the bigger of the two puts it, which
## is what makes a refresh of a one-stack effect still one stack.
func stacks_after(current: int, added: int) -> int:
	var ceiling: int = maxi(max_stacks, 1)
	var arriving: int = maxi(added, 1)
	if stacking == "add":
		return mini(current + arriving, ceiling)
	return mini(maxi(current, arriving), ceiling)

## How many seconds are left after applying `added` more to `remaining`. "extend" adds the
## new time to what was left, which is what makes a second poison dart last longer; the other
## two rules put the clock back to the new time, which is what makes a burn re-applied every
## second never quite go out.
func seconds_after(remaining: float, added: float) -> float:
	if stacking == "extend":
		return maxf(remaining, 0.0) + maxf(added, 0.0)
	return maxf(added, 0.0)
