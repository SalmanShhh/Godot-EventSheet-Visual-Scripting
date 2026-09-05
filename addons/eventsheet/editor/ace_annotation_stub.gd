@tool
class_name EventSheetACEAnnotationStub
extends RefCounted

## Builds copy-ready provider-authoring stubs from an existing ACEDefinition, so an
## author can learn either dialect by example: right-click any ACE in the picker,
## paste the stub into a provider script, and edit. Two flavors: the ## @ace_*
## comment dialect and the typed _eventforge_register registrar.
##
## The two dialects do NOT cover the same ground, and a stub that silently dropped the
## difference taught the wrong lesson. Each stub therefore leads with plain `#` notes for
## whatever its dialect cannot express: per-row state (a descriptor-only feature), a
## multi-line template (an annotation is one line and stores a literal "\n" - nothing in
## the pipeline unescapes it), node scoping plus the target prefix registration adds by
## itself, and - for the registrar - looping conditions and starting values. Notes LEAD,
## never trail: a single-`#` line sitting between annotations and their member clears the
## pending annotations, so notes below the block would eat the stub they explain.
##
## Quoting differs per dialect, and both forms here are checked against the parsers.
## An annotation value is read verbatim between its first "(" and last ")" with one
## surrounding quote pair trimmed, so an inner quote must NOT be backslash-escaped and a
## value that IS a quoted literal ships wrapped in a second pair. A registrar call is real
## GDScript, so its strings escape normally.

## Widget-hint string -> EventForgeRegistrar constant name, for readable registrar stubs.
const HINT_CONSTANTS := {
	"expression": "EXPRESSION",
	"variable_reference": "VARIABLE",
	"color": "COLOR",
	"key_capture": "KEY_CAPTURE",
	"audio_path": "AUDIO_PATH",
	"scene_path": "SCENE_PATH",
	"animation_reference": "ANIMATION",
	"signal_reference": "SIGNAL_REFERENCE",
	"method_reference": "METHOD_REFERENCE",
	"property_reference": "PROPERTY_REFERENCE"
}


static func comment_stub(definition: ACEDefinition) -> String:
	if definition == null:
		return ""
	var notes: Array[String] = []
	_append_state_note(definition, notes)
	_append_node_scope_note(definition, notes)
	var codegen_template: String = str(definition.metadata.get("codegen_template", ""))
	if codegen_template.contains("\n"):
		notes.append("# MULTI-LINE TEMPLATE: one annotation is one line, and a \"\\n\" written into it stays two")
		notes.append("# literal characters - nothing in the pipeline unescapes it, so the escaped form below does")
		notes.append("# NOT round-trip. Author a multi-line template with the registrar's .template() (a real")
		notes.append("# GDScript string) or with a descriptor, and indent its nested lines with tabs.")
	var parameter_lines: Array[String] = []
	for parameter in _dialog_parameters(definition):
		var parameter_line: String = _comment_param_line(parameter, notes)
		if not parameter_line.is_empty():
			parameter_lines.append(parameter_line)

	var lines: Array[String] = []
	lines.append_array(notes)
	if not definition.description.is_empty():
		# Plain `##` prose IS the description, which is the terse dialect the guide teaches.
		# A description that spans lines or opens with "@" would be read as something else,
		# so those ship through the explicit annotation instead.
		if definition.description.contains("\n") or definition.description.begins_with("@"):
			lines.append("## @ace_description(\"%s\")" % _one_line(definition.description))
		else:
			lines.append("## %s" % definition.description)
	lines.append("## @ace_%s" % _type_keyword(definition.ace_type))
	if bool(definition.metadata.get("looping", false)):
		# A looping condition iterates the collection the method returns, once per item.
		# The annotation also forces the CONDITION kind, whatever the return type is.
		lines.append("## @ace_looping(%s)" % str(definition.metadata.get("looping_iterator", "item")))
	if not definition.display_name.is_empty():
		lines.append("## @ace_name(\"%s\")" % definition.display_name)
	if not definition.category.is_empty():
		lines.append("## @ace_category(\"%s\")" % definition.category)
	if _has_authored_caption(definition):
		lines.append("## @ace_display_template(\"%s\")" % _one_line(str(definition.metadata.get("display_template", ""))))
	if not codegen_template.is_empty():
		lines.append("## @ace_codegen_template(\"%s\")" % _comment_value(codegen_template))
	lines.append_array(parameter_lines)
	lines.append(_member_line(definition))
	return "\n".join(lines)


static func registrar_stub(definition: ACEDefinition) -> String:
	if definition == null:
		return ""
	var notes: Array[String] = []
	_append_state_note(definition, notes)
	_append_node_scope_note(definition, notes)
	if bool(definition.metadata.get("looping", false)):
		notes.append("# LOOPING: the registrar has no looping action. Keep \"## @ace_looping(%s)\" as a comment" % str(definition.metadata.get("looping_iterator", "item")))
		notes.append("# annotation above the method; it also forces the CONDITION kind.")
	var chain: Array[String] = ["\treg.%s(\"%s\")" % [_type_keyword(definition.ace_type), _member_name(definition)]]
	if not definition.display_name.is_empty():
		chain.append(".name(\"%s\")" % _escape_gdscript(definition.display_name))
	if not definition.category.is_empty():
		chain.append(".category(\"%s\")" % _escape_gdscript(definition.category))
	if not definition.description.is_empty():
		chain.append(".description(\"%s\")" % _escape_gdscript(definition.description))
	if _has_authored_caption(definition):
		chain.append(".display(\"%s\")" % _escape_gdscript(str(definition.metadata.get("display_template", ""))))
	var codegen_template: String = str(definition.metadata.get("codegen_template", ""))
	if not codegen_template.is_empty():
		chain.append(".template(\"%s\")" % _escape_gdscript(codegen_template))
	var has_default: bool = false
	for parameter in _dialog_parameters(definition):
		if not str(parameter.get("default_value", "")).is_empty():
			has_default = true
		var spec_parts: Array[String] = _registrar_param_spec(parameter)
		if not spec_parts.is_empty():
			chain.append(".param(\"%s\", {%s})" % [str(parameter.get("id", "")), ", ".join(spec_parts)])
	if has_default:
		notes.append("# STARTING VALUES: reg.param() carries hint/options/autocomplete/desc only. The value a row")
		notes.append("# shows on drop comes from the method's own GDScript default (func fire(power: float = 25.0))")
		notes.append("# or from a \"## @ace_param(power, default: 25.0)\" comment annotation.")

	var lines: Array[String] = []
	lines.append_array(notes)
	lines.append("static func _eventforge_register(reg: EventForgeRegistrar) -> void:")
	lines.append(" \\\n\t\t".join(chain))
	return "\n".join(lines)


## The `#` note both dialects need for a STATEFUL condition: neither can declare the
## per-row member, so the stub hands over the descriptor chain that can, spelled with this
## ACE's own member/prelude/on-true text.
static func _append_state_note(definition: ACEDefinition, notes: Array[String]) -> void:
	var member_template: String = str(definition.metadata.get("member_template", ""))
	if member_template.strip_edges().is_empty():
		return
	var chain_args: Array[String] = ["\"%s\"" % _escape_gdscript(member_template)]
	var prelude: String = str(definition.metadata.get("codegen_prelude", ""))
	var on_true: String = str(definition.metadata.get("codegen_on_true", ""))
	var on_exit: String = str(definition.metadata.get("codegen_on_exit", ""))
	if not on_exit.is_empty():
		chain_args.append("\"%s\"" % _escape_gdscript(prelude))
		chain_args.append("\"%s\"" % _escape_gdscript(on_true))
		chain_args.append("\"%s\"" % _escape_gdscript(on_exit))
	elif not on_true.is_empty():
		chain_args.append("\"%s\"" % _escape_gdscript(prelude))
		chain_args.append("\"%s\"" % _escape_gdscript(on_true))
	elif not prelude.is_empty():
		chain_args.append("\"%s\"" % _escape_gdscript(prelude))
	var chain: String = ".stateful(%s)" % ", ".join(chain_args)
	if bool(definition.metadata.get("evaluate_last", false)):
		chain += ".evaluated_last()"
	notes.append("# STATEFUL: this ACE owns per-row memory, which is a DESCRIPTOR feature - neither the ## @ace_*")
	notes.append("# dialect nor the registrar can declare it. Author this one as a descriptor (a module under")
	notes.append("# addons/eventforge/registration/modules/, or an EventForgeBridge dictionary) and chain:")
	notes.append("#   F.make_descriptor(...)%s" % chain)
	notes.append("# Three rules ride along. The member compiles INTO the sheet class, once per applied row.")
	notes.append("# Every local it declares must carry {uid}, which the dock bakes fresh at apply time and the")
	notes.append("# compiler never does. And the standalone-compile gate cannot build the context it needs, so")
	notes.append("# the ace_id belongs in NOT_STANDALONE in tests/builtin_ace_compile_test.gd or that gate fails.")


## The `#` note for a NODE-SCOPED ACE. Neither dialect has an annotation for node_type, and
## the template shown is the SHIPPED one: registration prefixes a node-scoped ACE whose every
## line is a plain member operation with "{target.}" and appends the optional "On node" param.
static func _append_node_scope_note(definition: ACEDefinition, notes: Array[String]) -> void:
	var node_type: String = str(definition.metadata.get("node_type", ""))
	if node_type.is_empty():
		return
	notes.append("# NODE-SCOPED (%s): node scoping is a descriptor field (node_type), which neither" % node_type)
	if _has_injected_target(definition):
		notes.append("# dialect annotates. The template below is the SHIPPED one: registration added the \"{target.}\"")
		notes.append("# prefix and the optional \"On node\" param by itself, so do not write either one again. A")
		notes.append("# template whose lines are not plain member operations - one leading with not/and/is, with")
		notes.append("# $ or %, or assigning the member it reads back - gets no target at all.")
	else:
		notes.append("# dialect annotates. This template got NO \"{target.}\" prefix and no \"On node\" param:")
		notes.append("# registration only adds them when every template line is a plain member operation, and one")
		notes.append("# leading with not/and/is, with $ or %, or with anything that is not an identifier is left")
		notes.append("# exactly as authored.")


## One `## @ace_param(...)` line for a parameter, or "" when there is nothing to say about it.
## Keys ride in the same fixed order the curate-script writer uses, so the same parameter always
## renders the same line. Anything the one-line grammar cannot carry adds a note instead of
## shipping a spec that would silently truncate.
static func _comment_param_line(parameter: Dictionary, notes: Array[String]) -> String:
	var parameter_id: String = str(parameter.get("id", ""))
	var spec_parts: Array[String] = []
	var hint_value: String = str(parameter.get("hint", ""))
	if not hint_value.is_empty():
		spec_parts.append("hint: %s" % hint_value)
	var option_pairs: Array = _option_pairs(parameter)
	if not option_pairs.is_empty():
		if _options_carry_comma(option_pairs):
			# The spec splits on commas outside quotes, so a comma inside a label would cut the
			# option list in half. Ship the values (never wrong, just unlabeled) and say so.
			var bare_keys: PackedStringArray = PackedStringArray()
			for pair in option_pairs:
				bare_keys.append(str((pair as Dictionary).get("key", "")))
			spec_parts.append("options: %s" % "|".join(bare_keys))
			notes.append("# OPTION LABELS (%s): a label containing a comma cannot ride @ace_param - the spec splits on" % parameter_id)
			notes.append("# commas outside quotes - so the keys below ship unlabeled. Set the labels from the registrar:")
			notes.append("#   .param(\"%s\", {\"options\": [{\"key\": \"...\", \"label\": \"...\"}]})" % parameter_id)
		else:
			spec_parts.append("options: %s" % _comment_options(option_pairs))
	var default_value: String = str(parameter.get("default_value", ""))
	if not default_value.is_empty():
		if default_value.begins_with("\"") and default_value.contains(","):
			notes.append("# STARTING VALUE (%s): %s cannot ride @ace_param - one quote pair is trimmed off a default" % [parameter_id, default_value])
			notes.append("# and the spec splits on commas outside quotes, so a quoted literal carrying a comma has no")
			notes.append("# one-line form. Give the method a GDScript default instead: func x(%s = %s)." % [parameter_id, default_value])
		else:
			spec_parts.append("default: %s" % _comment_default(default_value))
	var description: String = _one_line(str(parameter.get("description", "")))
	if not description.is_empty():
		if _description_survives_one_line(description):
			spec_parts.append("desc: \"%s\"" % description)
		else:
			notes.append("# PARAM HELP (%s): this description's double quotes cannot ride @ace_param - the spec trims" % parameter_id)
			notes.append("# one surrounding pair and splits on commas outside quotes, so it would come back truncated.")
			notes.append("#   .param(\"%s\", {\"desc\": \"%s\"})   <- set it from the registrar instead." % [parameter_id, _escape_gdscript(description)])
	if spec_parts.is_empty():
		return ""
	return "## @ace_param(%s, %s)" % [parameter_id, ", ".join(spec_parts)]


## True when `desc: "<text>"` reads back as the same text. The spec parser splits on commas OUTSIDE
## double quotes and then trims one surrounding pair, so a balanced inner pair rides along intact
## (`Engine class name, e.g. "CharacterBody2D".`) while an unbalanced quote - or a comma that lands
## between two inner pairs - would cut the spec in half and truncate the help text. This mirrors that
## scan, starting inside quotes because the value ships wrapped in its own pair. Dropping a
## description silently was the old behaviour and it lost the only help text the params dialog shows.
static func _description_survives_one_line(description: String) -> bool:
	var in_quotes: bool = true
	for index in range(description.length()):
		var character: String = description.substr(index, 1)
		if character == "\"":
			in_quotes = not in_quotes
		elif character == "," and not in_quotes:
			return false
	return in_quotes


## The `{"hint": ..., "options": ..., "autocomplete": ..., "desc": ...}` spec entries for one
## registrar .param() call. Labeled options keep their dict form, which is what preserves the
## label the picker reads while the row inserts the key.
static func _registrar_param_spec(parameter: Dictionary) -> Array[String]:
	var spec_parts: Array[String] = []
	var hint_value: String = str(parameter.get("hint", ""))
	if not hint_value.is_empty():
		if HINT_CONSTANTS.has(hint_value):
			spec_parts.append("\"hint\": EventForgeRegistrar.%s" % HINT_CONSTANTS[hint_value])
		else:
			spec_parts.append("\"hint\": \"%s\"" % hint_value)
	var option_pairs: Array = _option_pairs(parameter)
	if not option_pairs.is_empty():
		var entries: Array[String] = []
		var labeled: bool = false
		for pair in option_pairs:
			if str((pair as Dictionary).get("key", "")) != str((pair as Dictionary).get("label", "")):
				labeled = true
		for pair in option_pairs:
			var option_key: String = str((pair as Dictionary).get("key", ""))
			var option_label: String = str((pair as Dictionary).get("label", option_key))
			if labeled:
				entries.append("{\"key\": \"%s\", \"label\": \"%s\"}" % [_escape_gdscript(option_key), _escape_gdscript(option_label)])
			else:
				entries.append("\"%s\"" % _escape_gdscript(option_key))
		spec_parts.append("\"options\": [%s]" % ", ".join(entries))
	var autocomplete: Array = parameter.get("autocomplete", []) if parameter.get("autocomplete", []) is Array else []
	if not autocomplete.is_empty():
		var suggestions: Array[String] = []
		for suggestion in autocomplete:
			suggestions.append("\"%s\"" % _escape_gdscript(str(suggestion)))
		spec_parts.append("\"autocomplete\": [%s]" % ", ".join(suggestions))
	var description: String = str(parameter.get("description", ""))
	if not description.is_empty():
		spec_parts.append("\"desc\": \"%s\"" % _escape_gdscript(_one_line(description)))
	return spec_parts


## True when the row caption says something the picker would not say by itself. Reflection
## derives "<Name> {param} {param}" for a method with no caption of its own, and re-emitting
## that as an annotation would teach a line the author never has to write.
static func _has_authored_caption(definition: ACEDefinition) -> bool:
	var display_template: String = str(definition.metadata.get("display_template", ""))
	if display_template.is_empty() or display_template == definition.display_name:
		return false
	var derived: Array[String] = [definition.display_name]
	for parameter in definition.parameters:
		if parameter is Dictionary:
			derived.append("{%s}" % str((parameter as Dictionary).get("id", "value")))
	return display_template != " ".join(derived)


static func _type_keyword(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.CONDITION:
			return "condition"
		ACEDefinition.ACEType.EXPRESSION:
			return "expression"
		ACEDefinition.ACEType.TRIGGER:
			return "trigger"
		_:
			return "action"


## The member declaration under the annotations: a signal for triggers, a typed
## func skeleton otherwise (params from the definition, return type from the kind).
static func _member_line(definition: ACEDefinition) -> String:
	var member_name: String = _member_name(definition)
	if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
		var signal_args: Array[String] = []
		for parameter in _dialog_parameters(definition):
			signal_args.append(_typed_param(parameter))
		if signal_args.is_empty():
			return "signal %s" % member_name
		return "signal %s(%s)" % [member_name, ", ".join(signal_args)]
	var func_args: Array[String] = []
	for parameter in _dialog_parameters(definition):
		func_args.append(_typed_param(parameter))
	var return_text: String = "void"
	if bool(definition.metadata.get("looping", false)):
		# A looping condition returns the COLLECTION it loops over, not a bool.
		return_text = type_string(definition.return_type) if definition.return_type != TYPE_NIL else "Array"
	elif definition.ace_type == ACEDefinition.ACEType.CONDITION:
		return_text = "bool"
	elif definition.ace_type == ACEDefinition.ACEType.EXPRESSION:
		return_text = "Variant"
	return "func %s(%s) -> %s:\n\t%s" % [member_name, ", ".join(func_args), return_text, _member_body(return_text)]


## The skeleton body. A `pass` under a non-void return type is a PARSE ERROR ("not all code
## paths return a value"), which made every condition and expression stub uncompilable the
## moment it was pasted, so each return type gets a real zero value instead.
static func _member_body(return_text: String) -> String:
	match return_text:
		"void":
			return "pass"
		"bool":
			return "return false"
		"Variant":
			return "return null"
		"int":
			return "return 0"
		"float":
			return "return 0.0"
		"String":
			return "return \"\""
		_:
			return "return %s()" % return_text


static func _typed_param(parameter: Dictionary) -> String:
	var parameter_name: String = str(parameter.get("id", "value"))
	var parameter_type: int = int(parameter.get("type", TYPE_NIL))
	if parameter_type == TYPE_NIL or parameter_type == TYPE_MAX:
		return parameter_name
	return "%s: %s" % [parameter_name, type_string(parameter_type)]


## Snake-case member name from the definition id ("method:heal" -> heal, "AddVar" -> add_var).
static func _member_name(definition: ACEDefinition) -> String:
	var raw_id: String = definition.id
	var colon_index: int = raw_id.rfind(":")
	if colon_index != -1:
		raw_id = raw_id.substr(colon_index + 1)
	return raw_id.to_snake_case()


## Parameters the params dialog would show. The "On node" param registration injects into a
## node-scoped ACE is plumbing, not vocabulary, so stubs skip it - but ONLY that one: an ACE
## that authored its own `target` param (the picking and debug verbs do) keeps it.
static func _dialog_parameters(definition: ACEDefinition) -> Array:
	var output: Array = []
	for parameter in definition.parameters:
		if not (parameter is Dictionary):
			continue
		if _is_injected_target(parameter as Dictionary):
			continue
		output.append(parameter)
	return output


static func _has_injected_target(definition: ACEDefinition) -> bool:
	for parameter in definition.parameters:
		if parameter is Dictionary and _is_injected_target(parameter as Dictionary):
			return true
	return false


## The injected retarget param, by its exact signature: id `target` (or `on_node` when the ACE
## already had a `target` of its own) labeled "On node".
static func _is_injected_target(parameter: Dictionary) -> bool:
	var parameter_id: String = str(parameter.get("id", ""))
	if parameter_id != "target" and parameter_id != "on_node":
		return false
	return str(parameter.get("display_name", "")) == "On node"


static func _option_pairs(parameter: Dictionary) -> Array:
	var output: Array = []
	for option_entry in parameter.get("options", []):
		if option_entry is Dictionary:
			var option_dict: Dictionary = option_entry
			var option_key: String = str(option_dict.get("key", ""))
			output.append({"key": option_key, "label": str(option_dict.get("label", option_key))})
	return output


static func _options_carry_comma(option_pairs: Array) -> bool:
	for pair in option_pairs:
		var option_dict: Dictionary = pair
		if str(option_dict.get("key", "")).contains(",") or str(option_dict.get("label", "")).contains(","):
			return true
	return false


## `a|b=Label|"<="=at most` - the labeled option grammar. A bare entry is its own label; a key
## that itself contains the "=" separator ships quoted, because the split is on the FIRST "=".
static func _comment_options(option_pairs: Array) -> String:
	var entries: PackedStringArray = PackedStringArray()
	for pair in option_pairs:
		var option_dict: Dictionary = pair
		var option_key: String = str(option_dict.get("key", ""))
		var option_label: String = str(option_dict.get("label", option_key))
		if option_key.is_empty():
			# The BLANK choice ships quoted, exactly as the compiler's own writer spells it. Written
			# bare it is two separators with nothing between them, which reads back as a stray "|"
			# and the choice is gone - the one option whose absence is invisible in the text.
			entries.append("\"\"" if option_label.is_empty() or option_label == option_key \
				else "\"\"=%s" % option_label)
		elif option_key.contains("="):
			entries.append("\"%s\"=%s" % [option_key, option_label])
		elif option_label == option_key or option_label.is_empty():
			entries.append(option_key)
		else:
			entries.append("%s=%s" % [option_key, option_label])
	return "|".join(entries)


## A starting value as the param grammar reads it back. The parser trims ONE surrounding quote
## pair and splits the spec on commas outside quotes, so a value that is already a quoted
## literal, or that carries a comma, ships wrapped in one extra pair; everything else ships bare.
static func _comment_default(default_value: String) -> String:
	if default_value.begins_with("\"") or default_value.contains(","):
		return "\"%s\"" % default_value
	return default_value


## An annotation value is read VERBATIM, so quotes and backslashes must survive untouched.
## Only a real newline or tab is escaped, because a `##` line cannot carry one at all.
static func _comment_value(text: String) -> String:
	return text.replace("\r", "").replace("\n", "\\n").replace("\t", "\\t")


## Prose flattened onto one line, for the values that are sentences rather than code.
static func _one_line(text: String) -> String:
	return text.replace("\r", " ").replace("\n", " ").replace("\t", " ").strip_edges()


## A registrar call is real GDScript, so its strings escape the ordinary way.
static func _escape_gdscript(text: String) -> String:
	return text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t")
