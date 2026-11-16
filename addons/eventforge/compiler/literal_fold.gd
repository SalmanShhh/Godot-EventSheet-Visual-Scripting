# EventForge - writing a guarded number as the number.
#
# Some templates guard a value with a floor, `maxf({seconds}, 0.001)`, so a typed name or an
# expression can never be zero or negative. When the value in the slot is a plain float literal that is
# already at or above the floor, the guard is the literal and nothing else: `maxf(2.0, 0.001)` is `2.0`.
# A row that asks for it writes the short form, the one a person typing the script would write.
#
# Three rules keep it safe:
# - Float literals only. `maxf({x}, 1.0)` inside `length() / maxf({cps}, 1.0)` with `cps = 15` would
#   become `length() / 15`, an integer division and a different answer. `2` keeps its guard.
# - At or above the floor only. `0.0005` keeps `maxf(0.0005, 0.001)`.
# - All or nothing per template. A template with several guards either folds every one or none, so a
#   half-folded line never appears (it would match neither reading pattern).
# The decision is taken at emit time from the value in the slot, never stored as text: a value edited
# from `2.0` to `speed` gets its guard back.
@tool
extends RefCounted

const _GUARD_PATTERN: String = "maxf\\(\\{([A-Za-z_][A-Za-z0-9_]*)\\}, (-?[0-9]+\\.[0-9]+)\\)"
const _FLOAT_PATTERN: String = "^-?[0-9]+\\.[0-9]+$"
const _SLOT_PATTERN: String = "\\{[^}]*\\}"

static var _guard_re: RegEx = null
static var _float_re: RegEx = null
static var _slot_re: RegEx = null


static func _guard() -> RegEx:
	if _guard_re == null:
		_guard_re = RegEx.create_from_string(_GUARD_PATTERN)
	return _guard_re


## True when `value` is a float literal (digits, a point, digits) at or above `floor_text`.
static func is_foldable_value(value: String, floor_text: String) -> bool:
	if _float_re == null:
		_float_re = RegEx.create_from_string(_FLOAT_PATTERN)
	var text: String = value.strip_edges()
	if _float_re.search(text) == null:
		return false
	var number: float = text.to_float()
	# A negative zero is a different spelling of zero; leave it guarded rather than reason about its sign.
	if number == 0.0 and text.begins_with("-"):
		return false
	return number >= floor_text.to_float()


## The template with every guard replaced by its bare slot, or the template unchanged when any one
## guard in it does not fold.
static func fold_template(template: String, params: Dictionary) -> String:
	var hits: Array[RegExMatch] = _guard().search_all(template)
	if hits.is_empty():
		return template
	for hit: RegExMatch in hits:
		var slot: String = hit.get_string(1)
		if not params.has(slot) or not is_foldable_value(str(params[slot]), hit.get_string(2)):
			return template
	var out: String = template
	for hit: RegExMatch in hits:
		out = out.replace(hit.get_string(0), "{%s}" % hit.get_string(1))
	return out


## The folded spelling of a template (every guard gone) and the floor each slot needs, or {} when the
## template has no guard.
static func folded_variant(template: String) -> Dictionary:
	var floors: Dictionary = {}
	var out: String = template
	for hit: RegExMatch in _guard().search_all(template):
		var seen: String = str(floors.get(hit.get_string(1), ""))
		if seen.is_empty() or hit.get_string(2).to_float() > seen.to_float():
			floors[hit.get_string(1)] = hit.get_string(2)
		out = out.replace(hit.get_string(0), "{%s}" % hit.get_string(1))
	if floors.is_empty():
		return {}
	return {"template": out, "floors": floors}


## A template with every slot name blanked, so two templates that differ only in what their slots
## are called compare equal. The reader uses it to refuse a folded spelling that another verb already
## writes, which would move what a hand-written file reads as.
static func shape(template: String) -> String:
	if _slot_re == null:
		_slot_re = RegEx.create_from_string(_SLOT_PATTERN)
	return _slot_re.sub(template, "{}", true)
