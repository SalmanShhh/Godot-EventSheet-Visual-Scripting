@tool
class_name EventSheetCategoryInference
extends RefCounted

const CATEGORY_KEYWORDS := {
	"Movement": ["move", "jump", "velocity", "floor", "wall", "dash", "slide"],
	"Combat": ["damage", "health", "hurt", "heal", "kill", "attack"],
	"Animation": ["animation", "play", "frame", "blend", "sprite"],
	"Inventory": ["inventory", "item", "equip", "slot", "loot"],
	"Audio": ["audio", "sound", "music", "volume"],
	"UI": ["ui", "label", "button", "panel", "dialog"],
	"Physics": ["physics", "body", "collision", "overlap", "impulse"],
	"Signals": ["signal", "emit", "pressed", "entered", "died"],
	"Navigation": ["path", "nav", "waypoint", "target"],
	"AI": ["ai", "think", "state", "patrol", "chase"]
}


static func infer_category(symbol_name: String, ace_type: int, return_type: int = TYPE_NIL, parameter_types: Array = []) -> String:
	if ace_type == ACEDefinition.ACEType.TRIGGER:
		return "Signals"
	var haystack: String = symbol_name.to_lower()
	for parameter_type in parameter_types:
		haystack += " " + str(parameter_type).to_lower()
	if return_type == TYPE_BOOL:
		haystack += " bool"
	for category_name in CATEGORY_KEYWORDS.keys():
		for keyword in CATEGORY_KEYWORDS[category_name]:
			if haystack.find(keyword) != -1:
				return category_name
	return "Gameplay"
