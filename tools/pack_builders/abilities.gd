# Pack builder - abilities (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Simple Abilities behavior (ported + expanded from the Simple Abilities addon for Godot).
## A per-instance ability manager: grant/remove abilities by string id, cooldowns, stack charges
## with auto-regen, temporary (auto-expiring) abilities, custom data, and tags for bulk ops.
## Godot-suited additions over the original: a CurrentAbilityID expression (the original _currentAbilityID
## had no reader), an exported global cooldown_multiplier (built-in cooldown reduction), a
## "Current Ability Is" condition (per-id trigger filtering), and a Ready Abilities list.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "SimpleAbilitiesBehavior"
	sheet.addon_category = "Abilities"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"cooldown_multiplier": {"type": "float", "default": 1.0, "exported": true, "attributes": {"tooltip": "Global multiplier applied to every Set Cooldown (0.8 = 20% cooldown reduction).", "range": {"min": "0", "max": "10", "step": "0.05"}}},
		"ability_set": {"type": "Resource", "default": null, "exported": true, "attributes": {"tooltip": "Optional: drop an AbilitySetResource (.tres) here to auto-create its whole loadout on ready - the data-driven way to define abilities without events."}},
		"abilities": {"type": "Dictionary", "default": {}, "exported": false},
		"current_ability_id": {"type": "String", "default": "", "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Simple Abilities (event-sheet parity + Godot extras): grant abilities by id, cooldowns, stack charges that auto-regen, temporary abilities that auto-expire, per-ability custom data, and tags for bulk operations. Triggers fire for ANY ability; read Current Ability ID (or the Current Ability Is condition) to tell which one fired."
	sheet.events.append(about)

	# Triggers (signals), conditions + expressions, and private helpers - as ## @ace_*-annotated
	# class-level GDScript (mirrors health.gd / line_of_sight.gd). Signals are arg-less; the firing
	# ability's id is exposed through current_ability_id (the Current Ability ID expression).
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## One ability's runtime state - typed so the cooldown / stack / expiration hot paths read",
		"## fields directly instead of float()/int()/bool()-casting an untyped Dictionary every frame.",
		"class AbilityData:",
		"\tvar cooldown: float = 0.0",
		"\tvar max_cooldown: float = 0.0",
		"\tvar stacks: int = 1",
		"\tvar max_stacks: int = 1",
		"\tvar enabled: bool = true",
		"\tvar active: bool = false",
		"\tvar data: Dictionary = {}",
		"\tvar tags: Array = []",
		"\tvar expiration: float = 0.0",
		"\tvar max_expiration: float = 0.0",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Ability Activated\")",
		"signal on_ability_activated",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Ability Ready\")",
		"signal on_ability_ready",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Ability Created\")",
		"signal on_ability_created",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Ability Removed\")",
		"signal on_ability_removed",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Stack Consumed\")",
		"signal on_stack_consumed",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Stack Gained\")",
		"signal on_stack_gained",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Max Stacks Reached\")",
		"signal on_max_stacks_reached",
		"",
		"## @ace_condition",
		"## @ace_name(\"Has Ability\")",
		"func has_ability(id: String) -> bool:",
		"\treturn abilities.has(id)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Ability Ready\")",
		"func is_ready(id: String) -> bool:",
		"\tif not abilities.has(id):",
		"\t\treturn false",
		"\tvar a: AbilityData = abilities[id]",
		"\treturn a.enabled and a.stacks > 0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Ability Active\")",
		"func is_active(id: String) -> bool:",
		"\treturn abilities.has(id) and (abilities[id] as AbilityData).active",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Ability Enabled\")",
		"func is_enabled(id: String) -> bool:",
		"\treturn abilities.has(id) and (abilities[id] as AbilityData).enabled",
		"",
		"## @ace_condition",
		"## @ace_name(\"Has Stacks Available\")",
		"func has_stacks(id: String) -> bool:",
		"\treturn abilities.has(id) and (abilities[id] as AbilityData).stacks > 0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Ability Has Tag\")",
		"func ability_has_tag(id: String, tag: String) -> bool:",
		"\treturn abilities.has(id) and (abilities[id] as AbilityData).tags.has(tag)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Current Ability Is\")",
		"func current_ability_is(id: String) -> bool:",
		"\treturn current_ability_id == id",
		"",
		"## @ace_expression",
		"## @ace_name(\"Current Ability ID\")",
		"func current_ability() -> String:",
		"\treturn current_ability_id",
		"",
		"## @ace_expression",
		"## @ace_name(\"Cooldown Remaining\")",
		"func get_cooldown_remaining(id: String) -> float:",
		"\treturn (abilities[id] as AbilityData).cooldown if abilities.has(id) else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Cooldown Progress\")",
		"func get_cooldown_progress(id: String) -> float:",
		"\tif not abilities.has(id) or (abilities[id] as AbilityData).max_cooldown <= 0.0:",
		"\t\treturn 0.0",
		"\treturn clampf((abilities[id] as AbilityData).cooldown / (abilities[id] as AbilityData).max_cooldown, 0.0, 1.0)",
		"",
		"## @ace_expression",
		"## @ace_name(\"Stacks\")",
		"func get_stacks(id: String) -> int:",
		"\treturn (abilities[id] as AbilityData).stacks if abilities.has(id) else 0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Max Stacks\")",
		"func get_max_stacks(id: String) -> int:",
		"\treturn (abilities[id] as AbilityData).max_stacks if abilities.has(id) else 0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Stack Cooldown Remaining\")",
		"func get_stack_cooldown_remaining(id: String) -> float:",
		"\treturn (abilities[id] as AbilityData).cooldown if abilities.has(id) else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Stack Progress\")",
		"func get_stack_progress(id: String) -> float:",
		"\treturn get_cooldown_progress(id)",
		"",
		"## @ace_expression",
		"## @ace_name(\"Expiration Time\")",
		"func get_expiration_time(id: String) -> float:",
		"\treturn (abilities[id] as AbilityData).expiration if abilities.has(id) else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Expiration Progress\")",
		"func get_expiration_progress(id: String) -> float:",
		"\tif not abilities.has(id) or (abilities[id] as AbilityData).max_expiration <= 0.0:",
		"\t\treturn 0.0",
		"\treturn clampf(1.0 - (abilities[id] as AbilityData).expiration / (abilities[id] as AbilityData).max_expiration, 0.0, 1.0)",
		"",
		"## @ace_expression",
		"## @ace_name(\"Max Expiration Time\")",
		"func get_max_expiration_time(id: String) -> float:",
		"\treturn (abilities[id] as AbilityData).max_expiration if abilities.has(id) else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Ability Count\")",
		"func get_ability_count() -> int:",
		"\treturn abilities.size()",
		"",
		"## @ace_expression",
		"## @ace_name(\"List Active Abilities\")",
		"func list_active_abilities() -> String:",
		"\treturn \",\".join(abilities.keys())",
		"",
		"## @ace_expression",
		"## @ace_name(\"Ready Abilities\")",
		"func get_ready_abilities() -> String:",
		"\tvar out: PackedStringArray = PackedStringArray()",
		"\tfor id: String in abilities.keys():",
		"\t\tif is_ready(id):",
		"\t\t\tout.append(id)",
		"\treturn \",\".join(out)",
		"",
		"## @ace_expression",
		"## @ace_name(\"Ability Data\")",
		"func get_ability_data(id: String, key: String) -> String:",
		"\tif not abilities.has(id):",
		"\t\treturn \"\"",
		"\treturn str((abilities[id] as AbilityData).data.get(key, \"\"))",
		"",
		"## @ace_expression",
		"## @ace_name(\"Count Abilities By Tag\")",
		"func count_abilities_by_tag(tag: String) -> int:",
		"\treturn _ids_with_tag(tag).size()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Ability By Tag Index\")",
		"func get_ability_by_tag_index(tag: String, index: int) -> String:",
		"\tvar ids: Array = _ids_with_tag(tag)",
		"\treturn str(ids[index]) if index >= 0 and index < ids.size() else \"\"",
		"",
		"## @ace_expression",
		"## @ace_name(\"List Abilities By Tag\")",
		"func list_abilities_by_tag(tag: String) -> String:",
		"\treturn \",\".join(_ids_with_tag(tag))",
		"",
		"func _ensure_ability(id: String) -> AbilityData:",
		"\tif not abilities.has(id):",
		"\t\tabilities[id] = AbilityData.new()",
		"\treturn abilities[id] as AbilityData",
		"",
		"func _ids_with_tag(tag: String) -> Array:",
		"\tvar out: Array = []",
		"\tfor id: String in abilities.keys():",
		"\t\tif (abilities[id] as AbilityData).tags.has(tag):",
		"\t\t\tout.append(id)",
		"\treturn out"
	]))
	sheet.events.append(block)

	# Data-driven: if an AbilitySetResource was dropped in the Inspector, create its whole loadout on ready.
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var on_ready_body: RawCodeRow = RawCodeRow.new()
	on_ready_body.code = "\n".join(PackedStringArray([
		"if ability_set != null:",
		"\t# Deferred so the loadout is created after every node has readied AND connected its triggers -",
		"\t# the host (which carries the event sheet) readies AFTER this child, so emitting On Ability",
		"\t# Created synchronously here would fire before the sheet's handler is connected.",
		"\tload_ability_set.call_deferred(ability_set)"
	]))
	on_ready.actions.append(on_ready_body)
	sheet.events.append(on_ready)

	# Per-frame: count down cooldowns (regenerating stacks), and expire temporary abilities.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if abilities.is_empty():",
		"\treturn",
		"var expired: Array = []",
		"for id: String in abilities.keys():",
		"\tvar a: AbilityData = abilities[id]",
		"\tif a.cooldown > 0.0:",
		"\t\ta.cooldown = maxf(0.0, a.cooldown - delta)",
		"\t\tif a.cooldown <= 0.0:",
		"\t\t\tif a.stacks < a.max_stacks:",
		"\t\t\t\ta.stacks = a.stacks + 1",
		"\t\t\t\tcurrent_ability_id = id",
		"\t\t\t\ton_stack_gained.emit()",
		"\t\t\t\tif a.stacks < a.max_stacks and a.max_cooldown > 0.0:",
		"\t\t\t\t\ta.cooldown = a.max_cooldown",
		"\t\t\tcurrent_ability_id = id",
		"\t\t\ton_ability_ready.emit()",
		"\tif a.max_expiration > 0.0:",
		"\t\ta.expiration = maxf(0.0, a.expiration - delta)",
		"\t\tif a.expiration <= 0.0:",
		"\t\t\texpired.append(id)",
		"for id: String in expired:",
		"\tabilities.erase(id)",
		"\tcurrent_ability_id = id",
		"\ton_ability_removed.emit()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# ── Actions (EventFunction, exposed as ACEs) ──
	Lib.append_function(sheet, "create_ability", "Create Ability", "Abilities",
		"Grants an empty ability (no cooldown, 1 stack, enabled). Fires On Ability Created if new.",
		[["id", "String"]], "\n".join(PackedStringArray([
		"if abilities.has(id):",
		"\treturn",
		"_ensure_ability(id)",
		"current_ability_id = id",
		"on_ability_created.emit()"
	])))

	Lib.append_function(sheet, "create_ability_with_cooldown", "Create Ability With Cooldown", "Abilities",
		"Grants an ability and sets its cooldown. reset_instantly=true starts it ready.",
		[["id", "String"], ["seconds", "float"], ["reset_instantly", "bool"]], "\n".join(PackedStringArray([
		"var is_new: bool = not abilities.has(id)",
		"var a: AbilityData = _ensure_ability(id)",
		"a.max_cooldown = maxf(0.0, seconds)",
		"a.cooldown = 0.0 if reset_instantly else maxf(0.0, seconds)",
		"if is_new:",
		"\tcurrent_ability_id = id",
		"\ton_ability_created.emit()"
	])))

	Lib.append_function(sheet, "create_ability_with_stacks", "Create Ability With Cooldown And Stacks", "Abilities",
		"Grants a charge-based ability; each stack regenerates over `seconds`. reset_instantly=true starts full.",
		[["id", "String"], ["seconds", "float"], ["max_stacks", "int"], ["reset_instantly", "bool"]], "\n".join(PackedStringArray([
		"var is_new: bool = not abilities.has(id)",
		"var a: AbilityData = _ensure_ability(id)",
		"a.max_cooldown = maxf(0.0, seconds)",
		"a.max_stacks = maxi(1, max_stacks)",
		"a.stacks = a.max_stacks if reset_instantly else 0",
		"a.cooldown = 0.0 if reset_instantly else maxf(0.0, seconds)",
		"if is_new:",
		"\tcurrent_ability_id = id",
		"\ton_ability_created.emit()"
	])))

	Lib.append_function(sheet, "create_temporary_ability", "Create Temporary Ability", "Abilities",
		"Grants an ability that auto-removes after `seconds`. Calling again refreshes the timer.",
		[["id", "String"], ["seconds", "float"]], "\n".join(PackedStringArray([
		"var is_new: bool = not abilities.has(id)",
		"var a: AbilityData = _ensure_ability(id)",
		"a.max_expiration = maxf(0.0, seconds)",
		"a.expiration = maxf(0.0, seconds)",
		"if is_new:",
		"\tcurrent_ability_id = id",
		"\ton_ability_created.emit()"
	])))

	Lib.append_function(sheet, "remove_ability_after", "Remove Ability After Duration", "Abilities",
		"Schedules removal of an existing ability after `seconds`.",
		[["id", "String"], ["seconds", "float"]], "\n".join(PackedStringArray([
		"if not abilities.has(id):",
		"\treturn",
		"(abilities[id] as AbilityData).max_expiration = maxf(0.0, seconds)",
		"(abilities[id] as AbilityData).expiration = maxf(0.0, seconds)"
	])))

	Lib.append_function(sheet, "remove_ability", "Remove Ability", "Abilities",
		"Deletes an ability and all its data. Fires On Ability Removed.",
		[["id", "String"]], "\n".join(PackedStringArray([
		"if not abilities.has(id):",
		"\treturn",
		"abilities.erase(id)",
		"current_ability_id = id",
		"on_ability_removed.emit()"
	])))

	Lib.append_function(sheet, "clear_all_abilities", "Clear All Abilities", "Abilities",
		"Removes every ability. Fires On Ability Removed for each.",
		[], "\n".join(PackedStringArray([
		"for id: String in abilities.keys():",
		"\tcurrent_ability_id = id",
		"\ton_ability_removed.emit()",
		"abilities.clear()"
	])))

	Lib.append_function(sheet, "activate_ability", "Activate Ability", "Abilities",
		"Activates an ability if it is ready: consumes a stack, starts regen, fires On Ability Activated.",
		[["id", "String"]], "\n".join(PackedStringArray([
		"if not abilities.has(id):",
		"\treturn",
		"var a: AbilityData = abilities[id]",
		"if not a.enabled or a.stacks <= 0:",
		"\treturn",
		"a.stacks = a.stacks - 1",
		"current_ability_id = id",
		"on_stack_consumed.emit()",
		"if a.stacks < a.max_stacks and a.cooldown <= 0.0 and a.max_cooldown > 0.0:",
		"\ta.cooldown = a.max_cooldown",
		"current_ability_id = id",
		"on_ability_activated.emit()"
	])))

	Lib.append_function(sheet, "set_cooldown", "Set Ability Cooldown", "Abilities",
		"Puts an ability on cooldown (scaled by the global cooldown multiplier).",
		[["id", "String"], ["seconds", "float"]], "\n".join(PackedStringArray([
		"if not abilities.has(id):",
		"\treturn",
		"var cd: float = maxf(0.0, seconds * cooldown_multiplier)",
		"(abilities[id] as AbilityData).cooldown = cd",
		"(abilities[id] as AbilityData).max_cooldown = cd"
	])))

	Lib.append_function(sheet, "reset_cooldown", "Reset Cooldown", "Abilities",
		"Refreshes an ability: clears its cooldown AND grants the next charge back, so a spent ability is ready again (readiness is charge-based). The kill-refresh / cooldown-reset mechanic. On a full ability it just clears the timer.",
		[["id", "String"]], "\n".join(PackedStringArray([
		"if not abilities.has(id):",
		"\treturn",
		"var a: AbilityData = abilities[id]",
		"a.cooldown = 0.0",
		"if a.stacks < a.max_stacks:",
		"\ta.stacks = a.stacks + 1",
		"\tcurrent_ability_id = id",
		"\ton_stack_gained.emit()",
		"\tif a.stacks < a.max_stacks and a.max_cooldown > 0.0:",
		"\t\ta.cooldown = a.max_cooldown"
	])))

	Lib.append_function(sheet, "set_max_stacks", "Set Max Stacks", "Abilities",
		"Changes max charges (current stacks clamp down).",
		[["id", "String"], ["max_stacks", "int"]], "\n".join(PackedStringArray([
		"if not abilities.has(id):",
		"\treturn",
		"var a: AbilityData = abilities[id]",
		"a.max_stacks = maxi(1, max_stacks)",
		"a.stacks = mini(a.stacks, a.max_stacks)"
	])))

	Lib.append_function(sheet, "set_stacks", "Set Stacks", "Abilities",
		"Sets current charges (clamped 0..max).",
		[["id", "String"], ["stacks", "int"]], "\n".join(PackedStringArray([
		"if not abilities.has(id):",
		"\treturn",
		"(abilities[id] as AbilityData).stacks = clampi(stacks, 0, (abilities[id] as AbilityData).max_stacks)"
	])))

	Lib.append_function(sheet, "add_stacks", "Add Stacks", "Abilities",
		"Adds charges up to max. Fires On Stack Gained, and On Max Stacks Reached if it would overflow.",
		[["id", "String"], ["count", "int"]], "\n".join(PackedStringArray([
		"if not abilities.has(id):",
		"\treturn",
		"var a: AbilityData = abilities[id]",
		"var before: int = a.stacks",
		"a.stacks = mini(a.max_stacks, before + count)",
		"if a.stacks > before:",
		"\tcurrent_ability_id = id",
		"\ton_stack_gained.emit()",
		"if before + count > a.max_stacks:",
		"\tcurrent_ability_id = id",
		"\ton_max_stacks_reached.emit()"
	])))

	Lib.append_function(sheet, "consume_stack", "Consume Ability Stack", "Abilities",
		"Removes one charge without activating; starts regen if needed.",
		[["id", "String"]], "\n".join(PackedStringArray([
		"if not abilities.has(id):",
		"\treturn",
		"var a: AbilityData = abilities[id]",
		"if a.stacks <= 0:",
		"\treturn",
		"a.stacks = a.stacks - 1",
		"current_ability_id = id",
		"on_stack_consumed.emit()",
		"if a.stacks < a.max_stacks and a.cooldown <= 0.0 and a.max_cooldown > 0.0:",
		"\ta.cooldown = a.max_cooldown"
	])))

	Lib.append_function(sheet, "set_enabled", "Set Ability Enabled", "Abilities",
		"Enables or disables activation.",
		[["id", "String"], ["enabled", "bool"]], "\n".join(PackedStringArray([
		"if abilities.has(id):",
		"\t(abilities[id] as AbilityData).enabled = enabled"
	])))

	Lib.append_function(sheet, "set_active", "Set Ability Active", "Abilities",
		"Sets the active flag (for channeled / toggle abilities).",
		[["id", "String"], ["active", "bool"]], "\n".join(PackedStringArray([
		"if abilities.has(id):",
		"\t(abilities[id] as AbilityData).active = active"
	])))

	Lib.append_function(sheet, "set_ability_data", "Set Ability Data", "Abilities",
		"Stores a custom key/value (string) on an ability.",
		[["id", "String"], ["key", "String"], ["value", "String"]], "\n".join(PackedStringArray([
		"if abilities.has(id):",
		"\t(abilities[id] as AbilityData).data[key] = str(value)"
	])))

	Lib.append_function(sheet, "add_tag", "Add Tag", "Abilities",
		"Tags an ability (safe if it already has the tag).",
		[["id", "String"], ["tag", "String"]], "\n".join(PackedStringArray([
		"if not abilities.has(id):",
		"\treturn",
		"var tags: Array = (abilities[id] as AbilityData).tags",
		"if not tags.has(tag):",
		"\ttags.append(tag)"
	])))

	Lib.append_function(sheet, "remove_tag", "Remove Tag", "Abilities",
		"Removes a tag from an ability.",
		[["id", "String"], ["tag", "String"]], "\n".join(PackedStringArray([
		"if abilities.has(id):",
		"\t(abilities[id] as AbilityData).tags.erase(tag)"
	])))

	Lib.append_function(sheet, "clear_tags", "Clear All Tags", "Abilities",
		"Removes every tag from an ability.",
		[["id", "String"]], "\n".join(PackedStringArray([
		"if abilities.has(id):",
		"\t(abilities[id] as AbilityData).tags.clear()"
	])))

	Lib.append_function(sheet, "set_tag_enabled", "Set Abilities With Tag Enabled", "Abilities",
		"Enables/disables every ability carrying a tag.",
		[["tag", "String"], ["enabled", "bool"]], "\n".join(PackedStringArray([
		"for id: String in _ids_with_tag(tag):",
		"\t(abilities[id] as AbilityData).enabled = enabled"
	])))

	Lib.append_function(sheet, "remove_abilities_with_tag", "Remove All Abilities With Tag", "Abilities",
		"Deletes every ability with a tag. Fires On Ability Removed for each.",
		[["tag", "String"]], "\n".join(PackedStringArray([
		"for id: String in _ids_with_tag(tag):",
		"\tabilities.erase(id)",
		"\tcurrent_ability_id = id",
		"\ton_ability_removed.emit()"
	])))

	Lib.append_function(sheet, "reset_cooldown_for_tag", "Reset Cooldown For Abilities With Tag", "Abilities",
		"Refreshes every ability with a tag: clears each cooldown and grants a charge back, so a whole group is ready again.",
		[["tag", "String"]], "\n".join(PackedStringArray([
		"for id: String in _ids_with_tag(tag):",
		"\tvar a: AbilityData = abilities[id]",
		"\ta.cooldown = 0.0",
		"\tif a.stacks < a.max_stacks:",
		"\t\ta.stacks = a.stacks + 1",
		"\t\tcurrent_ability_id = id",
		"\t\ton_stack_gained.emit()",
		"\t\tif a.stacks < a.max_stacks and a.max_cooldown > 0.0:",
		"\t\t\ta.cooldown = a.max_cooldown"
	])))

	Lib.append_function(sheet, "set_cooldown_multiplier", "Set Cooldown Multiplier", "Abilities",
		"Global cooldown scaling for all future Set Cooldown calls (0.8 = 20% cooldown reduction).",
		[["multiplier", "float"]], "\n".join(PackedStringArray([
		"cooldown_multiplier = maxf(0.0, multiplier)"
	])))

	# Data-driven: create a whole loadout from an AbilitySetResource in one call (the .tres is read
	# dynamically, so this pack never depends on the resource class existing at build time).
	Lib.append_function(sheet, "load_ability_set", "Load Ability Set", "Abilities",
		"Creates every ability listed in an AbilitySetResource (.tres): id, cooldown, max stacks, temporary duration, and comma-separated tags. Each is granted ready. Drop the resource in the Inspector to auto-load on ready, or call this to swap loadouts at runtime.",
		[["resource", "Resource"]], "\n".join(PackedStringArray([
		"if resource == null:",
		"\treturn",
		"var rows: Variant = resource.get(\"abilities\")",
		"if not (rows is Array):",
		"\treturn",
		"for row: Variant in (rows as Array):",
		"\tif not (row is Dictionary):",
		"\t\tcontinue",
		"\tvar entry: Dictionary = row",
		"\tvar id: String = str(entry.get(\"id\", \"\"))",
		"\tif id.is_empty():",
		"\t\tcontinue",
		"\tvar is_new: bool = not abilities.has(id)",
		"\tvar a: AbilityData = _ensure_ability(id)",
		"\ta.max_cooldown = maxf(0.0, float(entry.get(\"cooldown\", 0.0)))",
		"\ta.max_stacks = maxi(1, int(entry.get(\"max_stacks\", 1)))",
		"\ta.stacks = a.max_stacks",
		"\ta.cooldown = 0.0",
		"\tvar temporary: float = float(entry.get(\"temporary\", 0.0))",
		"\tif temporary > 0.0:",
		"\t\ta.max_expiration = temporary",
		"\t\ta.expiration = temporary",
		"\tvar tag_text: String = str(entry.get(\"tags\", \"\"))",
		"\tfor tag: String in tag_text.split(\",\", false):",
		"\t\tvar trimmed: String = tag.strip_edges()",
		"\t\tif not trimmed.is_empty() and not a.tags.has(trimmed):",
		"\t\t\ta.tags.append(trimmed)",
		"\tif is_new:",
		"\t\tcurrent_ability_id = id",
		"\t\ton_ability_created.emit()"
	])))

	# Save-state seam - deliberately unpublished; the Save System provides the user-facing verbs.
	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"# Ability entries are AbilityData objects, so each one is flattened to plain fields",
		"# here and rebuilt on load.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\tvar saved: Dictionary = {}",
		"\tfor id: String in abilities.keys():",
		"\t\tvar a: AbilityData = abilities[id]",
		"\t\tsaved[id] = {",
		"\t\t\t\"cooldown\": a.cooldown,",
		"\t\t\t\"max_cooldown\": a.max_cooldown,",
		"\t\t\t\"stacks\": a.stacks,",
		"\t\t\t\"max_stacks\": a.max_stacks,",
		"\t\t\t\"enabled\": a.enabled,",
		"\t\t\t\"active\": a.active,",
		"\t\t\t\"data\": a.data.duplicate(true),",
		"\t\t\t\"tags\": a.tags.duplicate(true),",
		"\t\t\t\"expiration\": a.expiration,",
		"\t\t\t\"max_expiration\": a.max_expiration",
		"\t\t}",
		"\treturn {",
		"\t\t\"abilities\": saved",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\tabilities.clear()",
		"\tvar saved: Dictionary = (state.get(\"abilities\", {}) as Dictionary)",
		"\tfor id: String in saved.keys():",
		"\t\tvar entry: Dictionary = saved[id]",
		"\t\tvar a: AbilityData = _ensure_ability(id)",
		"\t\ta.cooldown = float(entry.get(\"cooldown\", 0.0))",
		"\t\ta.max_cooldown = float(entry.get(\"max_cooldown\", 0.0))",
		"\t\ta.stacks = int(entry.get(\"stacks\", 1))",
		"\t\ta.max_stacks = int(entry.get(\"max_stacks\", 1))",
		"\t\ta.enabled = bool(entry.get(\"enabled\", true))",
		"\t\ta.active = bool(entry.get(\"active\", false))",
		"\t\ta.data = (entry.get(\"data\", {}) as Dictionary).duplicate(true)",
		"\t\ta.tags = (entry.get(\"tags\", []) as Array).duplicate(true)",
		"\t\ta.expiration = float(entry.get(\"expiration\", 0.0))",
		"\t\ta.max_expiration = float(entry.get(\"max_expiration\", 0.0))"
	]))
	sheet.events.append(persistence)

	return Lib.save_pack(sheet, "res://eventsheet_addons/abilities/abilities_behavior")
