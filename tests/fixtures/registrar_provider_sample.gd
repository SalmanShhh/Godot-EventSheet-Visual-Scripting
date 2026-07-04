@tool
## The typed-registrar twin of terse_provider_sample: the SAME members annotated
## through the static _eventforge_register hook instead of comments. Used by
## registrar_provider_test to pin that both dialects yield identical definitions.
class_name RegistrarProviderSample
extends Node

signal reloaded


static func _eventforge_register(reg: EventForgeRegistrar) -> void:
	reg.pack_category("Weapons")
	reg.pack_icon("res://addons/eventsheet/icons/eventsheet.svg")
	reg.trigger("reloaded").description("Fires after a reload completes.")
	reg.action("fire").description("Fires the weapon once.")
	reg.action("reload").description("Refill the magazine.")
	reg.expression("shells_left") \
		.category("Ammo") \
		.icon("res://eventsheet_addons/behavior.svg") \
		.description("Counts the remaining shells.")
	reg.action("aim") \
		.description("Aims the weapon.") \
		.param("mode", {"hint": EventForgeRegistrar.EXPRESSION, "desc": "How to aim, roughly."}) \
		.param("stance", {"options": ["crouch", "stand", "prone"]})


func fire() -> void:
	pass


func reload() -> void:
	pass


func shells_left() -> int:
	return 3


func aim(mode: String, stance: String) -> void:
	pass
