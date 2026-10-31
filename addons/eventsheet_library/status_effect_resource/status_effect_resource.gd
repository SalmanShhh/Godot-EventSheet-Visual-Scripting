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
## Colour the host is tinted while this is on; white is no tint.
@export var tint: Color = Color(1.0, 1.0, 1.0, 1.0)
## The picture that stands for this effect. Status Icon hands it straight to a HUD texture, so the bar over the health bar needs no table of its own.
@export var icon: Texture2D = null
# @inspector_header Every Tick #c0554a
## Damage dealt per tick, per stack, through the Health pack.
@export_range(0, 1000, 0.5) var tick_amount: float = 0.0
## Damage type of each tick, such as fire; blank is untyped.
@export var tick_type: String = ""
## How long between ticks, in seconds of game time. A paused or slowed game slows the ticking with it.
@export_range(0.05, 60, 0.05) var tick_seconds: float = 0.5
## Health restored on every tick, per stack - a regeneration, a bandage, a healing circle. It is applied after the tick damage, so an effect may do both.
@export_range(0, 1000, 0.5) var heal_amount: float = 0.0
# @inspector_header While It Lasts #7c9cf5
## Movement speed multiplier while on: 0.5 slows, 0 roots, 1.4 hastens.
@export_range(0, 10, 0.05) var speed_factor: float = 1.0
## Boosts tag this effect feeds while on, such as damage; blank feeds none.
@export var multiplier_tag: String = ""
## What the effect multiplies that tag by while on.
@export_range(0, 100, 0.05) var multiplier: float = 1.0
# @inspector_header Stacking #b48ead
## What a second application does: refresh, extend, or add stacks up to Max Stacks.
@export_enum("refresh", "extend", "add") var stacking: String = "refresh"
## The most stacks this effect can reach. Ticks and healing are multiplied by the stack count, so five stacks of a bleed bleed five times as fast.
@export_range(1, 999, 1) var max_stacks: int = 1
## Whether a Cleanse with no name takes this one off. Turn it off for a curse, a story debuff or anything the antidote is not supposed to answer.
@export var cleansable: bool = true
## Scene added under the host while this is on; empty shows only the tint.
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
