@tool
## A provider written in the terse dialect: plain doc prose becomes the description,
## class-level @ace_category/@ace_icon default every member, and misspelled
## annotations are collected for the typo warning. Used by terse_provider_test.
## @ace_category("Weapons")
## @ace_icon("res://addons/eventsheet/icons/eventsheet.svg")
class_name TerseProviderSample
extends Node

## Fires after a reload completes.
signal reloaded


## Fires the weapon once.
func fire() -> void:
	pass


## This prose loses to the explicit annotation below.
## @ace_description("Refill the magazine.")
func reload() -> void:
	pass


## Counts the remaining shells.
## @ace_category("Ammo")
## @ace_icon("res://eventsheet_addons/behavior.svg")
func shells_left() -> int:
	return 3


## @ace_categry("Oops")
## @ace_names("Bogus")
func jam() -> void:
	pass
