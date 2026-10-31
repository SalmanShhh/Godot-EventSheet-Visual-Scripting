# Pack builder - status_effect_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## StatusEffectResource: what burn, poison, slow, stun, freeze and shield actually ARE, as files.
##
## Every game has a handful of them and no two games have the same handful, so a list of them
## inside the plugin would be a list of somebody else's game. There is none. An effect is an
## ordinary resource: how much it ticks for and in what kind of damage, how often, how much it
## heals instead, what it does to speed, which multiplier tag it feeds, what colour it tints the
## thing wearing it, which icon stands for it, how a second application stacks, whether it can be
## cleansed, and which particle scene rides along.
##
## THE FILE'S NAME IS THE EFFECT'S NAME unless Status Name says otherwise, so `burn.tres` is the
## effect a row calls "burn" and there is no id field to fall out of step with the file holding it.
##
## THE TWO STACKING DECISIONS LIVE HERE, not in the behaviour: how many stacks a second application
## leaves, and how much time is left afterwards. They are the whole difference between refresh,
## extend and add, they are pure arithmetic, and keeping them beside the numbers they read means a
## rule can be checked by looking at one file.
##
## SIX STARTERS SHIP beside the Status Effects behaviour - burn, poison, slow, stun, freeze and
## shield - and every one of them is a file to edit, rename, duplicate or delete.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "StatusEffectResource"
	sheet.class_description = "One status effect as a file you own: what it ticks for and in what kind of damage, how often, what it does to speed, the colour it tints the thing wearing it, the icon that stands for it, how a second application stacks, and whether it can be cleansed. The Status Effects behaviour reads these; six starters ship beside it to edit or delete."
	sheet.addon_category = "Status Effects"
	sheet.addon_tags = PackedStringArray(["status", "effect", "buff", "debuff", "resource"])
	sheet.variables = {
		"status_name": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "The word rows call this effect by (\"burn\"). Leave it blank and the file's own name is the word, so renaming the file renames the effect.",
				"header": "The Effect", "header_color": "#e0793f",
				"info": "Everything below is what the effect DOES while it is on. A field left at its default does nothing at all, so a pure flag - a status the movement packs and the state machine only ask about - is a file with nothing but a name."}},
		"tint": {"type": "Color", "default": Color(1.0, 1.0, 1.0, 1.0), "exported": true,
			"attributes": {"tooltip": "Colour the host is tinted while this is on; white is no tint."}},
		"icon": {"type": "Texture2D", "default": null, "exported": true,
			"attributes": {"tooltip": "The picture that stands for this effect. Status Icon hands it straight to a HUD texture, so the bar over the health bar needs no table of its own."}},
		"tick_amount": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Damage dealt per tick, per stack, through the Health pack.",
				"header": "Every Tick", "header_color": "#c0554a",
				"range": {"min": "0", "max": "1000", "step": "0.5"}}},
		"tick_type": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "Damage type of each tick, such as fire; blank is untyped."}},
		"tick_seconds": {"type": "float", "default": 0.5, "exported": true,
			"attributes": {"tooltip": "How long between ticks, in seconds of game time. A paused or slowed game slows the ticking with it.",
				"range": {"min": "0.05", "max": "60", "step": "0.05"}}},
		"heal_amount": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Health restored on every tick, per stack - a regeneration, a bandage, a healing circle. It is applied after the tick damage, so an effect may do both.",
				"range": {"min": "0", "max": "1000", "step": "0.5"}}},
		"speed_factor": {"type": "float", "default": 1.0, "exported": true,
			"attributes": {"tooltip": "Movement speed multiplier while on: 0.5 slows, 0 roots, 1.4 hastens.",
				"header": "While It Lasts", "header_color": "#7c9cf5",
				"range": {"min": "0", "max": "10", "step": "0.05"}}},
		"multiplier_tag": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "Boosts tag this effect feeds while on, such as damage; blank feeds none."}},
		"multiplier": {"type": "float", "default": 1.0, "exported": true,
			"attributes": {"tooltip": "What the effect multiplies that tag by while on.",
				"range": {"min": "0", "max": "100", "step": "0.05"}}},
		"stacking": {"type": "String", "default": "refresh", "exported": true,
			"options": ["refresh", "extend", "add"],
			"attributes": {"tooltip": "What a second application does: refresh, extend, or add stacks up to Max Stacks.",
				"header": "Stacking", "header_color": "#b48ead"}},
		"max_stacks": {"type": "int", "default": 1, "exported": true,
			"attributes": {"tooltip": "The most stacks this effect can reach. Ticks and healing are multiplied by the stack count, so five stacks of a bleed bleed five times as fast.",
				"range": {"min": "1", "max": "999", "step": "1"}}},
		"cleansable": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Whether a Cleanse with no name takes this one off. Turn it off for a curse, a story debuff or anything the antidote is not supposed to answer."}},
		"particle_scene": {"type": "PackedScene", "default": null, "exported": true,
			"attributes": {"tooltip": "Scene added under the host while this is on; empty shows only the tint."}}
	}
	var reading: RawCodeRow = RawCodeRow.new()
	reading.code = "\n".join(PackedStringArray([
		"## The three answers this file gives are pure - no host, no tree, no time - so a stacking rule",
		"## can be read, tested and argued about by looking at this one resource.",
		"##",
		"## The word rows call this effect by: Status Name when it has been filled in, and otherwise",
		"## the file's own name, so `burn.tres` is \"burn\" with nothing typed anywhere.",
		"func called() -> String:",
		"\tif not status_name.strip_edges().is_empty():",
		"\t\treturn status_name.strip_edges()",
		"\treturn resource_path.get_file().get_basename()",
		"",
		"## How many stacks are on after applying `added` more to `current`. \"add\" piles them up to",
		"## Max Stacks; the other two rules leave the count where the bigger of the two puts it, which",
		"## is what makes a refresh of a one-stack effect still one stack.",
		"func stacks_after(current: int, added: int) -> int:",
		"\tvar ceiling: int = maxi(max_stacks, 1)",
		"\tvar arriving: int = maxi(added, 1)",
		"\tif stacking == \"add\":",
		"\t\treturn mini(current + arriving, ceiling)",
		"\treturn mini(maxi(current, arriving), ceiling)",
		"",
		"## How many seconds are left after applying `added` more to `remaining`. \"extend\" adds the",
		"## new time to what was left, which is what makes a second poison dart last longer; the other",
		"## two rules put the clock back to the new time, which is what makes a burn re-applied every",
		"## second never quite go out.",
		"func seconds_after(remaining: float, added: float) -> float:",
		"\tif stacking == \"extend\":",
		"\t\treturn maxf(remaining, 0.0) + maxf(added, 0.0)",
		"\treturn maxf(added, 0.0)"
	]))
	sheet.events.append(reading)
	return Lib.save_pack(sheet, "res://eventsheet_addons/status_effect_resource/status_effect_resource")
