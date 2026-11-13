@tool
extends RefCounted
## A fraction field typed as a percent. A parameter that reads as a percentage (the fraction lens) stores
## Godot's 0 to 1, so a person who sees "50%" on the row will type 50 or 50% into the field. This is the
## commit-time rewrite for that: `50%` and `50` (any plain number above 1) become `0.5`, `0.5` stays `0.5`,
## and anything that is not a plain number (an expression) is left exactly as written.
##
## It rides the generic commit-validator seam (EventSheets.register_param_commit_validator): a validator
## answering {"value": "..."} rewrites the committed text; one answering a prompt spec asks a question.


## The text as it should be stored: a fraction for a percent, the input itself for everything else.
static func to_fraction(text: String) -> String:
	var typed: String = text.strip_edges()
	var number: String = typed
	var had_sign: bool = typed.ends_with("%")
	if had_sign:
		number = typed.trim_suffix("%").strip_edges()
	if not number.is_valid_float():
		return text
	var amount: float = number.to_float()
	if not had_sign and amount <= 1.0:
		return text
	return str(snappedf(amount / 100.0, 0.000001))


## The commit validator: no question to ask, only a value to put right.
static func commit_validator(value: String) -> Dictionary:
	var fixed: String = to_fraction(value)
	return {} if fixed == value else {"value": fixed}
