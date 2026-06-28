@icon("res://eventsheet_addons/behavior.svg")
class_name SimpleAbilitiesBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("SimpleAbilitiesBehavior behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On Ability Activated")
## @ace_category("Abilities")
signal on_ability_activated
## @ace_trigger
## @ace_name("On Ability Ready")
## @ace_category("Abilities")
signal on_ability_ready
## @ace_trigger
## @ace_name("On Ability Created")
## @ace_category("Abilities")
signal on_ability_created
## @ace_trigger
## @ace_name("On Ability Removed")
## @ace_category("Abilities")
signal on_ability_removed
## @ace_trigger
## @ace_name("On Stack Consumed")
## @ace_category("Abilities")
signal on_stack_consumed
## @ace_trigger
## @ace_name("On Stack Gained")
## @ace_category("Abilities")
signal on_stack_gained
## @ace_trigger
## @ace_name("On Max Stacks Reached")
## @ace_category("Abilities")
signal on_max_stacks_reached

var abilities: Dictionary = {}
## Global multiplier applied to every Set Cooldown (0.8 = 20% cooldown reduction).
@export_range(0, 10, 0.05) var cooldown_multiplier: float = 1.0
var current_ability_id: String = ""

## One ability's runtime state — typed so the cooldown / stack / expiration hot paths read
## fields directly instead of float()/int()/bool()-casting an untyped Dictionary every frame.
class AbilityData:
	var cooldown: float = 0.0
	var max_cooldown: float = 0.0
	var stacks: int = 1
	var max_stacks: int = 1
	var enabled: bool = true
	var active: bool = false
	var data: Dictionary = {}
	var tags: Array = []
	var expiration: float = 0.0
	var max_expiration: float = 0.0
func _ensure_ability(id: String) -> AbilityData:
	if not abilities.has(id):
		abilities[id] = AbilityData.new()
	return abilities[id] as AbilityData

func _process(delta: float) -> void:
	if abilities.is_empty():
		return
	var expired: Array = []
	for id: String in abilities.keys():
		var a: AbilityData = abilities[id]
		if a.cooldown > 0.0:
			a.cooldown = maxf(0.0, a.cooldown - delta)
			if a.cooldown <= 0.0:
				if a.stacks < a.max_stacks:
					a.stacks = a.stacks + 1
					current_ability_id = id
					on_stack_gained.emit()
					if a.stacks < a.max_stacks and a.max_cooldown > 0.0:
						a.cooldown = a.max_cooldown
				current_ability_id = id
				on_ability_ready.emit()
		if a.max_expiration > 0.0:
			a.expiration = maxf(0.0, a.expiration - delta)
			if a.expiration <= 0.0:
				expired.append(id)
	for id: String in expired:
		abilities.erase(id)
		current_ability_id = id
		on_ability_removed.emit()

## @ace_action
## @ace_name("Create Ability")
## @ace_category("Abilities")
## @ace_description("Grants an empty ability (no cooldown, 1 stack, enabled). Fires On Ability Created if new.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.create_ability({id})")
func create_ability(id: String) -> void:
	if abilities.has(id):
		return
	_ensure_ability(id)
	current_ability_id = id
	on_ability_created.emit()

## @ace_action
## @ace_name("Create Ability With Cooldown")
## @ace_category("Abilities")
## @ace_description("Grants an ability and sets its cooldown. reset_instantly=true starts it ready.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.create_ability_with_cooldown({id}, {seconds}, {reset_instantly})")
func create_ability_with_cooldown(id: String, seconds: float, reset_instantly: bool) -> void:
	var is_new: bool = not abilities.has(id)
	var a: AbilityData = _ensure_ability(id)
	a.max_cooldown = maxf(0.0, seconds)
	a.cooldown = 0.0 if reset_instantly else maxf(0.0, seconds)
	if is_new:
		current_ability_id = id
		on_ability_created.emit()

## @ace_action
## @ace_name("Create Ability With Cooldown And Stacks")
## @ace_category("Abilities")
## @ace_description("Grants a charge-based ability; each stack regenerates over `seconds`. reset_instantly=true starts full.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.create_ability_with_stacks({id}, {seconds}, {max_stacks}, {reset_instantly})")
func create_ability_with_stacks(id: String, seconds: float, max_stacks: int, reset_instantly: bool) -> void:
	var is_new: bool = not abilities.has(id)
	var a: AbilityData = _ensure_ability(id)
	a.max_cooldown = maxf(0.0, seconds)
	a.max_stacks = maxi(1, max_stacks)
	a.stacks = a.max_stacks if reset_instantly else 0
	a.cooldown = 0.0 if reset_instantly else maxf(0.0, seconds)
	if is_new:
		current_ability_id = id
		on_ability_created.emit()

## @ace_action
## @ace_name("Create Temporary Ability")
## @ace_category("Abilities")
## @ace_description("Grants an ability that auto-removes after `seconds`. Calling again refreshes the timer.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.create_temporary_ability({id}, {seconds})")
func create_temporary_ability(id: String, seconds: float) -> void:
	var is_new: bool = not abilities.has(id)
	var a: AbilityData = _ensure_ability(id)
	a.max_expiration = maxf(0.0, seconds)
	a.expiration = maxf(0.0, seconds)
	if is_new:
		current_ability_id = id
		on_ability_created.emit()

## @ace_action
## @ace_name("Remove Ability After Duration")
## @ace_category("Abilities")
## @ace_description("Schedules removal of an existing ability after `seconds`.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.remove_ability_after({id}, {seconds})")
func remove_ability_after(id: String, seconds: float) -> void:
	if not abilities.has(id):
		return
	(abilities[id] as AbilityData).max_expiration = maxf(0.0, seconds)
	(abilities[id] as AbilityData).expiration = maxf(0.0, seconds)

## @ace_action
## @ace_name("Remove Ability")
## @ace_category("Abilities")
## @ace_description("Deletes an ability and all its data. Fires On Ability Removed.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.remove_ability({id})")
func remove_ability(id: String) -> void:
	if not abilities.has(id):
		return
	abilities.erase(id)
	current_ability_id = id
	on_ability_removed.emit()

## @ace_action
## @ace_name("Clear All Abilities")
## @ace_category("Abilities")
## @ace_description("Removes every ability. Fires On Ability Removed for each.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.clear_all_abilities()")
func clear_all_abilities() -> void:
	for id: String in abilities.keys():
		current_ability_id = id
		on_ability_removed.emit()
	abilities.clear()

## @ace_action
## @ace_name("Activate Ability")
## @ace_category("Abilities")
## @ace_description("Activates an ability if it is ready: consumes a stack, starts regen, fires On Ability Activated.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.activate_ability({id})")
func activate_ability(id: String) -> void:
	if not abilities.has(id):
		return
	var a: AbilityData = abilities[id]
	if not a.enabled or a.stacks <= 0:
		return
	a.stacks = a.stacks - 1
	current_ability_id = id
	on_stack_consumed.emit()
	if a.stacks < a.max_stacks and a.cooldown <= 0.0 and a.max_cooldown > 0.0:
		a.cooldown = a.max_cooldown
	current_ability_id = id
	on_ability_activated.emit()

## @ace_action
## @ace_name("Set Ability Cooldown")
## @ace_category("Abilities")
## @ace_description("Puts an ability on cooldown (scaled by the global cooldown multiplier).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.set_cooldown({id}, {seconds})")
func set_cooldown(id: String, seconds: float) -> void:
	if not abilities.has(id):
		return
	var cd: float = maxf(0.0, seconds * cooldown_multiplier)
	(abilities[id] as AbilityData).cooldown = cd
	(abilities[id] as AbilityData).max_cooldown = cd

## @ace_action
## @ace_name("Reset Cooldown")
## @ace_category("Abilities")
## @ace_description("Sets an ability's cooldown to 0 (instantly ready).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.reset_cooldown({id})")
func reset_cooldown(id: String) -> void:
	if abilities.has(id):
		(abilities[id] as AbilityData).cooldown = 0.0

## @ace_action
## @ace_name("Set Max Stacks")
## @ace_category("Abilities")
## @ace_description("Changes max charges (current stacks clamp down).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.set_max_stacks({id}, {max_stacks})")
func set_max_stacks(id: String, max_stacks: int) -> void:
	if not abilities.has(id):
		return
	var a: AbilityData = abilities[id]
	a.max_stacks = maxi(1, max_stacks)
	a.stacks = mini(a.stacks, a.max_stacks)

## @ace_action
## @ace_name("Set Stacks")
## @ace_category("Abilities")
## @ace_description("Sets current charges (clamped 0..max).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.set_stacks({id}, {stacks})")
func set_stacks(id: String, stacks: int) -> void:
	if not abilities.has(id):
		return
	(abilities[id] as AbilityData).stacks = clampi(stacks, 0, (abilities[id] as AbilityData).max_stacks)

## @ace_action
## @ace_name("Add Stacks")
## @ace_category("Abilities")
## @ace_description("Adds charges up to max. Fires On Stack Gained, and On Max Stacks Reached if it would overflow.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.add_stacks({id}, {count})")
func add_stacks(id: String, count: int) -> void:
	if not abilities.has(id):
		return
	var a: AbilityData = abilities[id]
	var before: int = a.stacks
	a.stacks = mini(a.max_stacks, before + count)
	if a.stacks > before:
		current_ability_id = id
		on_stack_gained.emit()
	if before + count > a.max_stacks:
		current_ability_id = id
		on_max_stacks_reached.emit()

## @ace_action
## @ace_name("Consume Ability Stack")
## @ace_category("Abilities")
## @ace_description("Removes one charge without activating; starts regen if needed.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.consume_stack({id})")
func consume_stack(id: String) -> void:
	if not abilities.has(id):
		return
	var a: AbilityData = abilities[id]
	if a.stacks <= 0:
		return
	a.stacks = a.stacks - 1
	current_ability_id = id
	on_stack_consumed.emit()
	if a.stacks < a.max_stacks and a.cooldown <= 0.0 and a.max_cooldown > 0.0:
		a.cooldown = a.max_cooldown

## @ace_action
## @ace_name("Set Ability Enabled")
## @ace_category("Abilities")
## @ace_description("Enables or disables activation.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.set_enabled({id}, {enabled})")
func set_enabled(id: String, enabled: bool) -> void:
	if abilities.has(id):
		(abilities[id] as AbilityData).enabled = enabled

## @ace_action
## @ace_name("Set Ability Active")
## @ace_category("Abilities")
## @ace_description("Sets the active flag (for channeled / toggle abilities).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.set_active({id}, {active})")
func set_active(id: String, active: bool) -> void:
	if abilities.has(id):
		(abilities[id] as AbilityData).active = active

## @ace_action
## @ace_name("Set Ability Data")
## @ace_category("Abilities")
## @ace_description("Stores a custom key/value (string) on an ability.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.set_ability_data({id}, {key}, {value})")
func set_ability_data(id: String, key: String, value: String) -> void:
	if abilities.has(id):
		(abilities[id] as AbilityData).data[key] = str(value)

## @ace_action
## @ace_name("Add Tag")
## @ace_category("Abilities")
## @ace_description("Tags an ability (safe if it already has the tag).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.add_tag({id}, {tag})")
func add_tag(id: String, tag: String) -> void:
	if not abilities.has(id):
		return
	var tags: Array = (abilities[id] as AbilityData).tags
	if not tags.has(tag):
		tags.append(tag)

## @ace_action
## @ace_name("Remove Tag")
## @ace_category("Abilities")
## @ace_description("Removes a tag from an ability.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.remove_tag({id}, {tag})")
func remove_tag(id: String, tag: String) -> void:
	if abilities.has(id):
		(abilities[id] as AbilityData).tags.erase(tag)

## @ace_action
## @ace_name("Clear All Tags")
## @ace_category("Abilities")
## @ace_description("Removes every tag from an ability.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.clear_tags({id})")
func clear_tags(id: String) -> void:
	if abilities.has(id):
		(abilities[id] as AbilityData).tags.clear()

## @ace_action
## @ace_name("Set Abilities With Tag Enabled")
## @ace_category("Abilities")
## @ace_description("Enables/disables every ability carrying a tag.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.set_tag_enabled({tag}, {enabled})")
func set_tag_enabled(tag: String, enabled: bool) -> void:
	for id: String in _ids_with_tag(tag):
		(abilities[id] as AbilityData).enabled = enabled

## @ace_action
## @ace_name("Remove All Abilities With Tag")
## @ace_category("Abilities")
## @ace_description("Deletes every ability with a tag. Fires On Ability Removed for each.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.remove_abilities_with_tag({tag})")
func remove_abilities_with_tag(tag: String) -> void:
	for id: String in _ids_with_tag(tag):
		abilities.erase(id)
		current_ability_id = id
		on_ability_removed.emit()

## @ace_action
## @ace_name("Reset Cooldown For Abilities With Tag")
## @ace_category("Abilities")
## @ace_description("Sets cooldown to 0 for every ability with a tag.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.reset_cooldown_for_tag({tag})")
func reset_cooldown_for_tag(tag: String) -> void:
	for id: String in _ids_with_tag(tag):
		(abilities[id] as AbilityData).cooldown = 0.0

## @ace_action
## @ace_name("Set Cooldown Multiplier")
## @ace_category("Abilities")
## @ace_description("Global cooldown scaling for all future Set Cooldown calls (0.8 = 20% cooldown reduction).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.set_cooldown_multiplier({multiplier})")
func set_cooldown_multiplier(multiplier: float) -> void:
	cooldown_multiplier = maxf(0.0, multiplier)

## @ace_condition
## @ace_name("Has Ability")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.has_ability({id})")
func has_ability(id: String) -> bool:
	return abilities.has(id)

## @ace_condition
## @ace_name("Is Ability Ready")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.is_ready({id})")
func is_ready(id: String) -> bool:
	if not abilities.has(id):
		return false
	var a: AbilityData = abilities[id]
	return a.enabled and a.stacks > 0

## @ace_condition
## @ace_name("Is Ability Active")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.is_active({id})")
func is_active(id: String) -> bool:
	return abilities.has(id) and (abilities[id] as AbilityData).active

## @ace_condition
## @ace_name("Is Ability Enabled")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.is_enabled({id})")
func is_enabled(id: String) -> bool:
	return abilities.has(id) and (abilities[id] as AbilityData).enabled

## @ace_condition
## @ace_name("Has Stacks Available")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.has_stacks({id})")
func has_stacks(id: String) -> bool:
	return abilities.has(id) and (abilities[id] as AbilityData).stacks > 0

## @ace_condition
## @ace_name("Ability Has Tag")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.ability_has_tag({id}, {tag})")
func ability_has_tag(id: String, tag: String) -> bool:
	return abilities.has(id) and (abilities[id] as AbilityData).tags.has(tag)

## @ace_condition
## @ace_name("Current Ability Is")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.current_ability_is({id})")
func current_ability_is(id: String) -> bool:
	return current_ability_id == id

## @ace_expression
## @ace_name("Current Ability ID")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.current_ability()")
func current_ability() -> String:
	return current_ability_id

## @ace_expression
## @ace_name("Cooldown Remaining")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_cooldown_remaining({id})")
func get_cooldown_remaining(id: String) -> float:
	return (abilities[id] as AbilityData).cooldown if abilities.has(id) else 0.0

## @ace_expression
## @ace_name("Cooldown Progress")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_cooldown_progress({id})")
func get_cooldown_progress(id: String) -> float:
	if not abilities.has(id) or (abilities[id] as AbilityData).max_cooldown <= 0.0:
		return 0.0
	return clampf((abilities[id] as AbilityData).cooldown / (abilities[id] as AbilityData).max_cooldown, 0.0, 1.0)

## @ace_expression
## @ace_name("Stacks")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_stacks({id})")
func get_stacks(id: String) -> int:
	return (abilities[id] as AbilityData).stacks if abilities.has(id) else 0

## @ace_expression
## @ace_name("Max Stacks")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_max_stacks({id})")
func get_max_stacks(id: String) -> int:
	return (abilities[id] as AbilityData).max_stacks if abilities.has(id) else 0

## @ace_expression
## @ace_name("Stack Cooldown Remaining")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_stack_cooldown_remaining({id})")
func get_stack_cooldown_remaining(id: String) -> float:
	return (abilities[id] as AbilityData).cooldown if abilities.has(id) else 0.0

## @ace_expression
## @ace_name("Stack Progress")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_stack_progress({id})")
func get_stack_progress(id: String) -> float:
	return get_cooldown_progress(id)

## @ace_expression
## @ace_name("Expiration Time")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_expiration_time({id})")
func get_expiration_time(id: String) -> float:
	return (abilities[id] as AbilityData).expiration if abilities.has(id) else 0.0

## @ace_expression
## @ace_name("Expiration Progress")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_expiration_progress({id})")
func get_expiration_progress(id: String) -> float:
	if not abilities.has(id) or (abilities[id] as AbilityData).max_expiration <= 0.0:
		return 0.0
	return clampf(1.0 - (abilities[id] as AbilityData).expiration / (abilities[id] as AbilityData).max_expiration, 0.0, 1.0)

## @ace_expression
## @ace_name("Max Expiration Time")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_max_expiration_time({id})")
func get_max_expiration_time(id: String) -> float:
	return (abilities[id] as AbilityData).max_expiration if abilities.has(id) else 0.0

## @ace_expression
## @ace_name("Ability Count")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_ability_count()")
func get_ability_count() -> int:
	return abilities.size()

## @ace_expression
## @ace_name("List Active Abilities")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.list_active_abilities()")
func list_active_abilities() -> String:
	return ",".join(abilities.keys())

## @ace_expression
## @ace_name("Ready Abilities")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_ready_abilities()")
func get_ready_abilities() -> String:
	var out: PackedStringArray = PackedStringArray()
	for id: String in abilities.keys():
		if is_ready(id):
			out.append(id)
	return ",".join(out)

## @ace_expression
## @ace_name("Ability Data")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_ability_data({id}, {key})")
func get_ability_data(id: String, key: String) -> String:
	if not abilities.has(id):
		return ""
	return str((abilities[id] as AbilityData).data.get(key, ""))

## @ace_expression
## @ace_name("Count Abilities By Tag")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.count_abilities_by_tag({tag})")
func count_abilities_by_tag(tag: String) -> int:
	return _ids_with_tag(tag).size()

## @ace_expression
## @ace_name("Ability By Tag Index")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.get_ability_by_tag_index({tag}, {index})")
func get_ability_by_tag_index(tag: String, index: int) -> String:
	var ids: Array = _ids_with_tag(tag)
	return str(ids[index]) if index >= 0 and index < ids.size() else ""

## @ace_expression
## @ace_name("List Abilities By Tag")
## @ace_category("Abilities")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$SimpleAbilitiesBehavior.list_abilities_by_tag({tag})")
func list_abilities_by_tag(tag: String) -> String:
	return ",".join(_ids_with_tag(tag))

func _ids_with_tag(tag: String) -> Array:
	var out: Array = []
	for id: String in abilities.keys():
		if (abilities[id] as AbilityData).tags.has(tag):
			out.append(id)
	return out

# Simple Abilities (event-sheet parity + Godot extras): grant abilities by id, cooldowns, stack charges that auto-regen, temporary abilities that auto-expire, per-ability custom data, and tags for bulk operations. Triggers fire for ANY ability; read Current Ability ID (or the Current Ability Is condition) to tell which one fired.
