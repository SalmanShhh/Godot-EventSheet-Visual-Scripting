# meta-name: EventForge ACE Provider
# meta-description: Public members become event-sheet actions, conditions, expressions, and triggers
# meta-default: false
@tool
## Describe the pack here (this prose becomes the provider description).
## @ace_category("My Pack")
class_name _CLASS_
extends _BASE_

## Prose above a member is its picker description. Signals become Triggers.
signal something_happened


## Return types classify members: void = Action, bool = Condition,
## anything else = Expression.
func my_action(amount: int) -> void:
	pass


## Names like *_color, *_anim, *_signal, *_scene, *_audio pick their widget
## automatically; tune one parameter in one line with
## @ace_param(name, hint: expression, options: a|b, desc: "Help text").
func my_value() -> float:
	return 0.0
