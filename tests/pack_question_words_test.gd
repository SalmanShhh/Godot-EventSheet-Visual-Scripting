# Godot EventSheets - a pack question that names no value of its own says the values it was asked about.
#
# `Button Is` followed by the button asked about, one space between. The node the call is made on is the
# object column's to show, so it is never repeated after the words: not under the parameter that carries
# the receiver, and not under any other parameter that holds the same text.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "pack_question_words_test"


static func run() -> bool:
	var receiver: Dictionary = {"id": "target"}
	var amount: Dictionary = {"id": "amount"}
	var node: Dictionary = {"id": "node"}
	var words: String = "Is Hanging"
	return SUPPORT.pins(P, [
		["a sentence with nothing to add is left alone",
			EventSheetViewportRowBuilder.pack_question_with_values(words, [receiver], {"target": "$Player/Traversal"}), "Is Hanging"],
		["a value follows the words after one space",
			EventSheetViewportRowBuilder.pack_question_with_values(words, [receiver, amount], {"target": "$Player/Traversal", "amount": "3"}), "Is Hanging 3"],
		["the receiver is not repeated under another parameter that holds the same text",
			EventSheetViewportRowBuilder.pack_question_with_values(words, [receiver, node], {"target": "$Player/Traversal", "node": "$Player/Traversal"}), "Is Hanging"],
		["two values stay one space apart",
			EventSheetViewportRowBuilder.pack_question_with_values(words + " ", [amount, node], {"amount": "3", "node": "\"up\""}), "Is Hanging 3 \"up\""],
		["a blank value adds nothing",
			EventSheetViewportRowBuilder.pack_question_with_values(words, [amount], {"amount": "  "}), "Is Hanging"],
	])
