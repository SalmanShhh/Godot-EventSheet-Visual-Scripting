# EventSheets - a config-driven Custom Block kind you build WITHOUT subclassing.
#
# The Custom Block API is powerful but asks a beginner to subclass EventSheetBlockKind and override
# fields() / emit() / summary(). This wraps all of that in one data description: a field schema, an
# emit template with {field} placeholders, and a summary template. EventSheets.simple_block_kind(...)
# builds one of these from a Dictionary, so a whole new row type is a few lines instead of a script.
#
# Forward emission (compile) and the viewport summary work out of the box. Reverse recovery (lift, so a
# saved .gd re-opens AS this block) needs a parser, so it is opt-in via a `lift` Callable in the config;
# with none, the block still emits perfectly and simply re-imports as a verbatim GDScript block - the
# covenant's safe degrade-never-corrupt fallback.
@tool
class_name EventSheetSimpleBlockKind
extends EventSheetBlockKind

## The field schema entries ({id, label, type, default}), set by EventSheets.simple_block_kind.
var field_schema: Array[Dictionary] = []

## The emit template: one output line per line of the string, with {field_id} placeholders.
var emit_template: String = ""

## The one-line viewport summary template, with {field_id} placeholders.
var summary_template: String = ""

## Optional reverse parser: func(lines: PackedStringArray, i: int) -> Dictionary, returning
## {"fields": ..., "consumed": ...} (usually via verified_claim) or {} to decline.
var lift_callable: Callable = Callable()


func fields() -> Array[Dictionary]:
	return field_schema.duplicate(true)


func emit(block: CustomBlockRow) -> PackedStringArray:
	if emit_template.is_empty():
		return PackedStringArray()
	return _substitute(emit_template, block).split("\n")


func summary(block: CustomBlockRow) -> String:
	if summary_template.is_empty():
		return title
	return _substitute(summary_template, block)


func lift(lines: PackedStringArray, i: int) -> Dictionary:
	if not lift_callable.is_valid():
		return {}
	var result: Variant = lift_callable.call(lines, i)
	return result if result is Dictionary else {}


## Replaces every {field_id} in the template with that field's current value (or its default).
func _substitute(template: String, block: CustomBlockRow) -> String:
	var out: String = template
	for field: Dictionary in field_schema:
		var id: String = str(field.get("id", ""))
		if id.is_empty():
			continue
		var value: Variant = block.fields.get(id, field.get("default", ""))
		out = out.replace("{%s}" % id, str(value))
	return out
