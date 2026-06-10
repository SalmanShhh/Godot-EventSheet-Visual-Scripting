## Demo EventSheet ACE addon. Drop scripts like this into res://eventsheet_addons/ and
## their annotated members become project-wide ACEs automatically — no manifest, no JSON,
## no per-sheet setup. Provider name comes from class_name, this comment is the addon
## description, and @ace_* annotations customize each ACE.
@tool
class_name DemoHealthAddon
extends RefCounted

## @ace_trigger
## @ace_name("On Healed")
## @ace_category("Health")
## @ace_description("Fires after health is restored.")
signal healed(amount: int)

## @ace_action
## @ace_name("Heal")
## @ace_category("Health")
## @ace_description("Restores health by an amount.")
## @ace_icon("res://addons/eventsheet/icons/eventsheet.svg")
## @ace_display_template("Heal {amount} HP")
## @ace_codegen_template("health += {amount}")
## @ace_param_hint(amount expression)
func heal(amount: int) -> void:
	healed.emit(amount)

## @ace_condition
## @ace_name("Is Hurt")
## @ace_category("Health")
## @ace_description("True while health is below the given threshold.")
## @ace_codegen_template("health < {threshold}")
func is_hurt(threshold: int) -> bool:
	return threshold > 0

## @ace_action
## @ace_name("Announce Heal")
## @ace_category("Health")
## @ace_description("Prints a heal announcement. No @ace_codegen_template on purpose: the
## generated script owns a DemoHealthAddon instance and calls this directly
## (instance-backed ACE — the zero-config default for template-less addon methods).")
func announce_heal(amount: int) -> void:
	print("[DemoHealthAddon] healed for %d" % amount)
