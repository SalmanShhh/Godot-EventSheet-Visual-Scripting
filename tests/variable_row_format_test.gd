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

	# float variable
	var float_summary: String = VariableRowUI.format_summary("speed", {"type": "float", "default": 1.5})
	assert(float_summary == "Global float speed = 1.5",
		'Expected "Global float speed = 1.5", got "%s"' % float_summary)

	# bool variable
	var bool_summary: String = VariableRowUI.format_summary("is_alive", {"type": "bool", "default": true})
	assert(bool_summary == "Global bool is_alive = true",
		'Expected "Global bool is_alive = true", got "%s"' % bool_summary)

	# Missing default falls back to empty string
	var no_default: String = VariableRowUI.format_summary("counter", {"type": "int"})
	assert(no_default == "Global int counter = ",
		'Expected "Global int counter = ", got "%s"' % no_default)

	print("[PASS] variable_row_format_test")
	return true
