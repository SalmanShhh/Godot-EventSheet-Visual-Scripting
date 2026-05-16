# EventForge — Variable row format test
# Verifies that VariableRowUI.format_summary() produces correct one-line output
# for global variable canvas rows.
@tool
extends RefCounted
class_name VariableRowFormatTest

static func run() -> bool:
	# int variable
	var int_summary: String = VariableRowUI.format_summary("health", {"type": "int", "default": 100})
	assert(int_summary == "Global int health = 100",
		'Expected "Global int health = 100", got "%s"' % int_summary)

	# String variable (default should be quoted)
	var str_summary: String = VariableRowUI.format_summary("player_name", {"type": "String", "default": "Player"})
	assert(str_summary == 'Global String player_name = "Player"',
		'Expected \'Global String player_name = "Player"\', got "%s"' % str_summary)

	# String variable with already-quoted default should not be double-quoted
	var prequoted_summary: String = VariableRowUI.format_summary("player_name", {"type": "String", "default": '"Player"'})
	assert(prequoted_summary == 'Global String player_name = "Player"',
		'Expected \'Global String player_name = "Player"\', got "%s"' % prequoted_summary)

	# String variable should escape embedded quotes in summary
	var embedded_quotes_summary: String = VariableRowUI.format_summary("dialogue", {"type": "String", "default": 'He said "Hi"'})
	assert(embedded_quotes_summary == 'Global String dialogue = "He said \\"Hi\\""',
		'Expected \'Global String dialogue = "He said \\"Hi\\""\', got "%s"' % embedded_quotes_summary)

	# float variable
	var float_summary: String = VariableRowUI.format_summary("speed", {"type": "float", "default": 1.5})
	assert(float_summary == "Global float speed = 1.5",
		'Expected "Global float speed = 1.5", got "%s"' % float_summary)

	# bool variable
	var bool_summary: String = VariableRowUI.format_summary("is_alive", {"type": "bool", "default": true})
	assert(bool_summary == "Global bool is_alive = true",
		'Expected "Global bool is_alive = true", got "%s"' % bool_summary)

	# Missing default falls back to empty string (no quotes even for String type)
	var no_default: String = VariableRowUI.format_summary("counter", {"type": "int"})
	assert(no_default == "Global int counter = ",
		'Expected "Global int counter = ", got "%s"' % no_default)

	# String type with null default should NOT be quoted
	var str_no_default: String = VariableRowUI.format_summary("tag", {"type": "String"})
	assert(str_no_default == "Global String tag = ",
		'Expected "Global String tag = ", got "%s"' % str_no_default)

	print("[PASS] variable_row_format_test")
	return true
