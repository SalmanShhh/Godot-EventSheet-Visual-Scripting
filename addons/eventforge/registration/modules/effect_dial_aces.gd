# EventForge module - the DIAL is the thing the row names, and the shader says what it is called.
#
# The four shipped Effects rows beside this file take the dial's name as a typed string:
# `Set effect parameter "dissolve" to 0.7`. Godot accepts whatever is typed there without a word -
# `&"disolve"` is a perfectly legal call that sets nothing, forever - so the commonest way an effect
# fails is a spelling mistake nobody is ever told about.
#
# These five rows take the name from the `.gdshader` instead. The picker builds one copy per node of
# the open scene per dial its shader really declares, with the node and the dial both already
# answered, so a reader picks `dissolve` rather than typing it and the name cannot be wrong. The row
# reads `Set effect.dissolve to 0.7` - the lead says the name belongs to the material rather than to
# a variable, and is muted, exactly as an autoload's name is on a global's row.
#
# PROJECT-SCOPED (see ACEDescriptor.is_project_scoped): only a shader file can name a dial, so the
# bare row is never browsable - browsing it could only hand back the free-string field it exists to
# replace - and the reverse index never claims a line for it, because whether a line is a dial row is
# a question about the project. effect_lift.gd asks that question and hands the answer over.
#
# The four shipped rows are untouched and keep compiling: their ace_ids and templates are frozen API,
# and they stay exactly right for a material that only exists at run time. These are new ids beside
# them.
@tool
class_name EventForgeEffectDialACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker category, shared with the four shipped Effects rows so the vocabulary has one effects
## section rather than two.
const CAT := "Effects"

## The class every one of these rows is hosted on - the one that wears a `material`. A 3D node keeps
## its shader on `material_override` and would need rows spelling THAT, so it is not offered one of
## these rather than offered a line that would not run.
const HOST := "CanvasItem"

## The member the rows write through, and the two calls Godot reads and writes a dial with.
const MATERIAL_MEMBER := "material"
const SET_CALL := "set_shader_parameter"
const GET_CALL := "get_shader_parameter"

## The parameter that carries the dial's name, named the same on every row here so one lift, one
## health check and one picker prefill address them all by it.
const DIAL_PARAM := "dial"

## The field a dial name is edited in. Its own hint, rather than a plain expression box, because the
## name is picked from a shader rather than typed - which is the whole of this vocabulary.
const DIAL_HINT := "shader_dial"

## The field a dial's VALUE is edited in. Also its own hint, because what the value is depends on the
## dial: the shader says whether it takes a number between two ends, a colour, a texture or a whole
## number, and the field it edits in is derived from that declaration rather than from a table. A
## dial nothing can be derived for edits in the ordinary value field, so this is never a dead end.
const VALUE_HINT := "shader_dial_value"

## What a copy starts on before the picker answers it from a real shader. A base row is never
## browsable, so this is what the compile gate builds its line from and nothing else ever shows.
const SAMPLE_DIAL := "dissolve"

## How long a fade takes when nobody says - the same half second every other fade in this vocabulary
## opens on, so two fades side by side start in step.
const DEFAULT_FADE_SECONDS := "0.5"


static func get_descriptors() -> Array[ACEDescriptor]:
	return [_set_row(), _fade_row(), _read_row(), _ask_row(), _own_row()]


## The ids this file publishes, asked rather than listed. The canvas needs them because these rows'
## OBJECT is the node wearing the material rather than the very general class they are hosted on, and
## a list kept by hand beside the rows would be one more thing to remember to edit.
static func published_ace_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in get_descriptors():
		ids.append(descriptor.ace_id)
	return ids


## `Set effect.dissolve to 0.7`. The one row a dial gets used through most, and the one the health
## check offers to re-pick when a shader stops declaring the name it holds.
static func _set_row() -> ACEDescriptor:
	return F.make_descriptor("Core", "EffectSetDial", "Set Effect Dial", ACEDescriptor.ACEType.ACTION,
		"%s.%s(&\"{%s}\", {value})" % [MATERIAL_MEMBER, SET_CALL, DIAL_PARAM], "",
		[_dial_param("The dial to turn. Picked from the shader this node's material runs, so the name is always one the shader really declares."),
			F.make_param("value", "String", "1.0", "Value",
				"What to set it to. The shader says what kind of value the dial takes, and what it starts at.",
				VALUE_HINT)],
		CAT, "Set {%s} to {value}" % DIAL_PARAM, HOST) \
		.described("Turns one dial of the effect this node wears. Writes `ShaderMaterial.set_shader_parameter`, with the name taken from the shader rather than typed - a mistyped name is a call Godot accepts and never acts on.") \
		.project_scoped() \
		.featured()


## `Fade effect.dissolve to 1.0 over 0.8 s`. One tween walks the dial there; nothing is kept between
## frames. It carries its own "On node" because the node is named INSIDE the lambda rather than in
## front of the call - `create_tween()` belongs to the node running the sheet.
static func _fade_row() -> ACEDescriptor:
	return F.make_descriptor("Core", "EffectFadeDial", "Fade Effect Dial", ACEDescriptor.ACEType.ACTION,
		"create_tween().tween_method(func(v): {target.}%s.%s(&\"{%s}\", v), {from}, {to}, {seconds})" % [
			MATERIAL_MEMBER, SET_CALL, DIAL_PARAM], "",
		[_target_param("The node whose effect to fade. Leave it blank for this node."),
			_dial_param("The dial to walk. Picked from the shader this node's material runs."),
			F.make_param("from", "String", "0.0", "From", "Where the fade starts.", VALUE_HINT),
			F.make_param("to", "String", "1.0", "To", "Where the fade ends.", VALUE_HINT),
			F.make_param("seconds", "String", DEFAULT_FADE_SECONDS, "Seconds",
				"How long the fade takes.", "expression")],
		CAT, "Fade {%s} to {to} over {seconds} s" % DIAL_PARAM, HOST) \
		.described("Walks one dial of this node's effect to a new value over time instead of jumping to it - a dissolve, a freeze setting in, a glow coming up. One tween, no state to keep.") \
		.project_scoped() \
		.featured()


## The dial read back, for any value field. `effect.dissolve` is what the row says and
## `material.get_shader_parameter(&"dissolve")` is what it writes.
static func _read_row() -> ACEDescriptor:
	return F.make_descriptor("Core", "EffectDial", "Effect Dial", ACEDescriptor.ACEType.EXPRESSION,
		"%s.%s(&\"{%s}\")" % [MATERIAL_MEMBER, GET_CALL, DIAL_PARAM], "",
		[_dial_param("The dial to read.")],
		CAT, "{%s}" % DIAL_PARAM, HOST) \
		.described("Reads one dial of this node's effect back. Use it in any value field - the name is picked from the shader, so a read can no longer quietly return nothing.") \
		.project_scoped()


## The same read as a question: `effect.dissolve > 0.5`. Its own row rather than the expression
## dropped into Compare Values, because what a reader is asking about is the dial.
static func _ask_row() -> ACEDescriptor:
	return F.make_descriptor("Core", "EffectDialIs", "Effect Dial Is", ACEDescriptor.ACEType.CONDITION,
		"%s.%s(&\"{%s}\") {op} {value}" % [MATERIAL_MEMBER, GET_CALL, DIAL_PARAM], "",
		[_dial_param("The dial to ask about."),
			F.make_param("op", "String", ">", "Operator", "Comparison.", "", F.COMPARISON_OPTIONS),
			F.make_param("value", "String", "0.5", "Value", "What to compare the dial against.",
				VALUE_HINT)],
		CAT, "{%s} {op} {value}" % DIAL_PARAM, HOST) \
		.described("True while one dial of this node's effect compares as the row says. Reads `ShaderMaterial.get_shader_parameter`.") \
		.project_scoped()


## THE row that is not a dial: a material is a FILE, and two nodes pointing at the same one share
## every dial on it. This gives the node its own copy first, which is Godot's own answer and the one
## a reader needs before any of the rows above mean only this node.
static func _own_row() -> ACEDescriptor:
	return F.make_descriptor("Core", "EffectOwnMaterial", "Make The Effect This Node's Own",
		ACEDescriptor.ACEType.ACTION,
		"{target.}%s = {target.}%s.duplicate()" % [MATERIAL_MEMBER, MATERIAL_MEMBER], "",
		[_target_param("The node to give its own copy. Leave it blank for this node.")],
		CAT, "Make the effect this node's own", HOST) \
		.described("Gives this node its own copy of the material before anything turns a dial on it. Without it, every dial row written at run time turns the dial for every other node wearing the same `.tres`.")


## The dial field, said the same way on every row that has one.
static func _dial_param(about: String) -> ACEParam:
	var dial: ACEParam = F.make_param(DIAL_PARAM, "String", SAMPLE_DIAL, "Dial", about, DIAL_HINT)
	dial.display_lens = EventForgeValueLens.LENS_EFFECT_DIAL
	return dial


## The "On node" field the two rows that name their node INSIDE the line carry themselves. Every
## other row here is left to the node-scoped transform, which appends the identical field.
static func _target_param(about: String) -> ACEParam:
	return F.make_param("target", "String", "", "On node", about, "expression")
