# EventForge - a variable's Save choice, and the plain code it compiles to.
#
# Every sheet variable can say when it is saved: Never (no attribute), Auto, Load only, Save only or
# Manual. The choice is the variable attribute "save" ("auto", "load", "save", "manual"); the older
# "remember": true reads as Auto. A sheet with any saved variable gets one block at the very end of
# the file, in plain Godot with nothing of the plugin's in it:
#
#     ## <DOC>
#     @onready var __ef_save_boot: bool = _ef_load_saved()
#
#     func _ef_load_saved() -> bool:              # runs as the node becomes ready
#         add_to_group("persist")                 # so Save Game / Load Game find it
#         ... Auto and Load only variables read from user://remembered.cfg
#         tree_exiting.connect(_ef_store_saved)   # Auto and Save only, on leaving the tree or quit
#         return true
#
#     func _ef_store_saved(at_save_game: bool = false) -> void:
#         ... Auto and Save only variables written; Load only ones only when at_save_game
#
#     func save_state() -> Dictionary:            # Save Game: every saved variable
#     func load_state(state: Dictionary) -> void: # Load Game: all but Save only
#
# So Manual is only ever the save_state()/load_state() pair the Save System's Save Game and Load Game
# call on every node in the persist group; Load only also loads by itself and is written back only at
# Save Game; Save only is written by itself and never read back. The file and the section are the ones
# the old Remember Between Runs used (user://remembered.cfg, the class name or "vars"), so a game that
# remembered values before keeps them.
#
# A variable renamed after players saved it - or a class renamed, which moves its section - can keep
# loading the name it had: its attribute "saved_as" ({"section": "" for its own, "key": the old name})
# turns the read into a one-time fallback, plain code as ever:
#
#     score = __remember_cfg.get_value("Player", "score", __remember_cfg.get_value("Player", "points", score))
#     score = int(state.get("score", state.get("points", score)))
#
# The old key is only ever read, never erased: the next store writes the new one, and a "vars" section
# two scripts share must not lose the other script's value of the same name.
#
# Opened again, the block is read back into the choices it came from (importer/save_choice_lift.gd)
# and byte-gated, so a file written this way reopens and saves byte for byte, and a hand-written
# save_state()/load_state() is never claimed. DELIBERATELY NO `class_name`: the compiler and the
# lift reach it with a const preload.
@tool
extends RefCounted

## The stored choices, in the order the Save dropdown offers them after Never (which stores nothing).
const CHOICES: PackedStringArray = ["auto", "load", "save", "manual"]
## The doc line the block opens with. Frozen once shipped: the importer finds the block by it.
const DOC: String = "## Saved by each variable's Save choice (Save Studio > What gets saved) - change the choice, not these lines."
const STORE: String = "user://remembered.cfg"
const GROUP: String = "persist"
## The block's own load and store functions (and the older Remember Between Runs loader). A sheet that
## already has one of them carries a copy of the block as code, so it gets no second one.
const DECLARES: PackedStringArray = ["_ef_load_saved", "_ef_store_saved", "_ef_recall_remembered"]
## The pair Save Game and Load Game call. A sheet that writes its own keeps it: the block then leaves
## the pair out and still loads and stores its Auto, Load only and Save only variables.
const PAIR: PackedStringArray = ["save_state", "load_state"]
## The attribute naming where a renamed variable's values were saved before: {"section", "key"}.
const SAVED_AS: String = "saved_as"


## The choice a variable's attributes hold: one of CHOICES, or "" for Never.
static func choice_of(attributes: Variant) -> String:
	if not attributes is Dictionary:
		return ""
	var chosen: String = str((attributes as Dictionary).get("save", ""))
	if CHOICES.has(chosen):
		return chosen
	return "auto" if bool((attributes as Dictionary).get("remember", false)) else ""


## Writes `choice` onto `attributes` (Never erases it), dropping the older "remember" spelling. A
## choice that never reads a value back (Never, Save only) drops the old name it kept loading too.
static func set_choice(attributes: Dictionary, choice: String) -> void:
	attributes.erase("remember")
	if CHOICES.has(choice):
		attributes["save"] = choice
	else:
		attributes.erase("save")
	if not choice in ["auto", "load", "manual"]:
		attributes.erase(SAVED_AS)


## Makes `variable_name` on `sheet` keep loading what was saved under `old_key` in `old_section` ("" for
## its own section): the one-time fallback read the block writes. False when the sheet has no such
## variable. The newest rename replaces an older one - one name back is the one players last saved.
static func keep_loading(sheet: EventSheetResource, variable_name: String, old_section: String, old_key: String) -> bool:
	var was: Dictionary = {"section": old_section, "key": old_key}
	if sheet.variables.get(variable_name) is Dictionary:
		var descriptor: Dictionary = sheet.variables[variable_name]
		var attributes: Dictionary = (descriptor.get("attributes") as Dictionary).duplicate() if descriptor.get("attributes") is Dictionary else {}
		attributes[SAVED_AS] = was
		descriptor["attributes"] = attributes
		return true
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == variable_name:
			var row_attributes: Dictionary = (entry as LocalVariable).attributes.duplicate()
			row_attributes[SAVED_AS] = was
			(entry as LocalVariable).attributes = row_attributes
			return true
	return false


## The sheet's own variables, in the order they are written, as [{name, type, choice, saved_as, description}]:
## the sheet variables of a .tres sheet and the top-level variable rows of an opened script. Constants
## are left out - there is nothing to save in a value that never changes.
static func variables_of(sheet: EventSheetResource) -> Array:
	var found: Array = []
	if sheet == null:
		return found
	for key: Variant in sheet.variables.keys():
		var descriptor: Variant = sheet.variables[key]
		if descriptor is Dictionary and not bool((descriptor as Dictionary).get("const", false)):
			var attributes: Variant = (descriptor as Dictionary).get("attributes")
			var tooltip: String = str((attributes as Dictionary).get("tooltip", "")) if attributes is Dictionary else ""
			found.append({"name": str(key), "type": str((descriptor as Dictionary).get("type", "Variant")),
				"choice": choice_of(attributes), "saved_as": _saved_as(attributes),
				"description": tooltip if not tooltip.is_empty() else str((descriptor as Dictionary).get("description", ""))})
	for entry: Variant in sheet.events:
		if entry is LocalVariable and not (entry as LocalVariable).is_constant:
			var variable: LocalVariable = entry as LocalVariable
			found.append({"name": variable.name, "type": variable.type_name, "choice": choice_of(variable.attributes),
				"saved_as": _saved_as(variable.attributes), "description": variable.description})
	return found


static func _saved_as(attributes: Variant) -> Dictionary:
	var was: Variant = (attributes as Dictionary).get(SAVED_AS) if attributes is Dictionary else null
	return was if was is Dictionary else {}


## The ConfigFile section the sheet's values live under: its class name, or "vars".
static func section_of(sheet: EventSheetResource) -> String:
	var section: String = str(sheet.custom_class_name).strip_edges()
	return section if not section.is_empty() else "vars"


## The block for `sheet`, or no lines when nothing is saved (or the sheet already declares one of the
## block's functions, which `warnings` is told). A sheet with its own save_state()/load_state() gets the
## block without the pair, and Manual - which is only the pair - then saves nothing, which `warnings`
## is told too. The lines open with the blank that separates them.
static func block_lines(sheet: EventSheetResource, declared: Callable, warnings: Array) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var by_choice: Dictionary = {"auto": [], "load": [], "save": [], "manual": []}
	var saved: Array = []
	for variable: Dictionary in variables_of(sheet):
		if not str(variable["choice"]).is_empty():
			(by_choice[variable["choice"]] as Array).append(variable)
			saved.append(variable)
	if saved.is_empty():
		return lines
	var host: String = str(sheet.host_class).strip_edges()
	if not host.is_empty() and ClassDB.class_exists(host) and host != "Node" and not ClassDB.is_parent_class(host, "Node"):
		warnings.append("A variable's Save choice needs a Node host (it loads when the node is ready and saves when it leaves) - nothing is saved on host %s." % host)
		return lines
	for function_name: String in DECLARES:
		if declared.call(function_name):
			warnings.append("This sheet already writes %s(), so its variables' Save choices were not added - keep the hand-written save code, or remove it and let the choices write it." % function_name)
			return lines
	var own_pair: bool = declared.call(PAIR[0]) or declared.call(PAIR[1])
	if own_pair and not (by_choice["manual"] as Array).is_empty():
		warnings.append("This sheet writes its own save_state()/load_state(), so a Manual Save choice saves nothing - put those variables in the hand-written pair.")
	if own_pair and not (by_choice["load"] as Array).is_empty():
		warnings.append("This sheet writes its own save_state(), so a Load only variable is written back at Save Game only when that save_state() calls _ef_store_saved(true).")
	if own_pair and (by_choice["manual"] as Array).size() == saved.size():
		return lines
	var section: String = section_of(sheet)
	var loads: Array = by_choice["auto"] + by_choice["load"]
	var stores: Array = by_choice["auto"] + by_choice["save"]
	var stored_at_save: Array = by_choice["load"]
	lines.append("")
	lines.append(DOC)
	lines.append("@onready var __ef_save_boot: bool = _ef_load_saved()")
	lines.append("")
	lines.append("func _ef_load_saved() -> bool:")
	lines.append("\tadd_to_group(\"%s\")" % GROUP)
	if not loads.is_empty():
		lines.append("\tvar __remember_cfg: ConfigFile = ConfigFile.new()")
		lines.append("\tif __remember_cfg.load(\"%s\") == OK:" % STORE)
		for variable: Dictionary in loads:
			lines.append("\t\t%s = __remember_cfg.get_value(\"%s\", \"%s\", %s)" % [variable["name"], section, variable["name"],
				_or(_cfg_fallback(variable, section), variable["name"])])
	if not stores.is_empty():
		lines.append("\ttree_exiting.connect(_ef_store_saved)")
	lines.append("\treturn true")
	if not stores.is_empty() or not stored_at_save.is_empty():
		lines.append("")
		lines.append("func _ef_store_saved(at_save_game: bool = false) -> void:")
		lines.append("\tvar __remember_cfg: ConfigFile = ConfigFile.new()")
		lines.append("\t__remember_cfg.load(\"%s\")" % STORE)
		for variable: Dictionary in stores:
			lines.append("\t__remember_cfg.set_value(\"%s\", \"%s\", %s)" % [section, variable["name"], variable["name"]])
		if not stored_at_save.is_empty():
			lines.append("\tif at_save_game:")
			for variable: Dictionary in stored_at_save:
				lines.append("\t\t__remember_cfg.set_value(\"%s\", \"%s\", %s)" % [section, variable["name"], variable["name"]])
		lines.append("\t__remember_cfg.save(\"%s\")" % STORE)
	if own_pair:
		return lines
	var seam: Dictionary = seam_entries(saved)
	var restored: Array = saved.filter(func(variable: Dictionary) -> bool: return variable["choice"] != "save")
	lines.append("")
	lines.append("func save_state() -> Dictionary:")
	if not stored_at_save.is_empty():
		lines.append("\t_ef_store_saved(true)")
	lines.append("\treturn {")
	lines.append_array(seam["save"])
	lines.append("\t}")
	lines.append("")
	lines.append("func load_state(state: Dictionary) -> void:")
	lines.append("\tif state.is_empty():")
	lines.append("\t\treturn")
	lines.append_array(seam_entries(restored)["load"])
	return lines


## The save_state() entries and load_state() lines for `fields` ({name, type}), in the convention
## every save-capable script shares: snapshot keys drop a leading underscore, collections deep-copy,
## and a load coerces by type and keeps the current value when the key is missing. The last save
## entry carries no trailing comma.
static func seam_entries(fields: Array) -> Dictionary:
	var save_lines: PackedStringArray = PackedStringArray()
	var load_lines: PackedStringArray = PackedStringArray()
	for field: Variant in fields:
		if not field is Dictionary:
			continue
		var var_name: String = str((field as Dictionary).get("name", ""))
		var var_type: String = str((field as Dictionary).get("type", "Variant"))
		var key: String = var_name.trim_prefix("_")
		# A field that keeps loading an older name reads that key when its own is missing.
		var old_key: String = str(_saved_as(field).get("key", "")).trim_prefix("_")
		var fallback: String = "" if old_key.is_empty() or old_key == key else "state.get(\"" + old_key + "\", %s)"
		# A TYPED collection (Array[String], Dictionary[String, int]) refuses a plain assignment of
		# the untyped collection a loaded state holds, so it is filled in place with assign().
		var typed_base: String = var_type.get_slice("[", 0) if var_type.ends_with("]") else ""
		if typed_base == "Array" or typed_base == "Dictionary":
			save_lines.append("\t\t\"%s\": %s.duplicate(true)," % [key, var_name])
			load_lines.append("\t%s.assign((state.get(\"%s\", %s) as %s).duplicate(true))" % [var_name, key, _or(fallback, var_name), typed_base])
			continue
		match var_type:
			"Dictionary", "Array":
				save_lines.append("\t\t\"%s\": %s.duplicate(true)," % [key, var_name])
				load_lines.append("\t%s = (state.get(\"%s\", %s) as %s).duplicate(true)" % [var_name, key,
					_or(fallback, "{}" if var_type == "Dictionary" else "[]"), var_type])
			"int", "float", "bool":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = %s(state.get(\"%s\", %s))" % [var_name, var_type, key, _or(fallback, var_name)])
			"String":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = str(state.get(\"%s\", %s))" % [var_name, key, _or(fallback, var_name)])
			_:
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = state.get(\"%s\", %s)" % [var_name, key, _or(fallback, var_name)])
	if not save_lines.is_empty():
		save_lines[save_lines.size() - 1] = save_lines[save_lines.size() - 1].trim_suffix(",")
	return {"save": save_lines, "load": load_lines}


## The read of the older name a variable keeps loading from user://remembered.cfg, with a %s for what
## it falls back to in turn - or "" when it keeps loading nothing older.
static func _cfg_fallback(variable: Dictionary, section: String) -> String:
	var was: Dictionary = _saved_as(variable)
	var old_section: String = str(was.get("section", ""))
	var old_key: String = str(was.get("key", ""))
	if old_section.is_empty():
		old_section = section
	if old_key.is_empty() or (old_section == section and old_key == str(variable["name"])):
		return ""
	return "__remember_cfg.get_value(\"" + old_section + "\", \"" + old_key + "\", %s)"


## `default`, or the fallback read wrapped around it.
static func _or(fallback: String, default: String) -> String:
	return default if fallback.is_empty() else fallback % default
