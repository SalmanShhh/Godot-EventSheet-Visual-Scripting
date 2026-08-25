@tool
class_name EventSheetQuickAdd
extends RefCounted

# TYPING A ROW AS A SENTENCE - the Add picker's filter, taught to read a whole one.
#
# The filter used to take the query as one string: "flash" found Flash, and "boss flash" found
# nothing, because no row's name says both. But the sentence a reader has in their head is not the
# row's name - it is the OBJECT, the VERB and the VALUE, in whatever order they come out. "boss fla
# 0.4" is a complete thought, and the picker should land on it.
#
# So a query is split into WORDS and VALUES. Every word has to hit something - the row's name, the
# node it is aimed at, its category or its keywords - and each hit is scored by how squarely it
# lands, so `fla` picking out Flash as the start of a word outranks `fla` buried in the middle of
# another name. A VALUE (a number, a quoted string) is not a word at all: no row's name contains
# `0.4`, so asking one to would find nothing. It is what the row will be SET to, and it lands in
# the first parameter that can take it.
#
# Nothing here is modal and nothing here is a second Add flow. It is the same filter, the same
# Enter, and the same parameters dialog - only now the dialog opens with the value already in it.


## Scores, from the answer a reader meant to the one they might accept. A word's best hit counts;
## the total is the sum over the words, so a query naming both the object and the verb beats one
## naming either.
const SCORE_WHOLE_NAME: int = 500
const SCORE_NAME_STARTS: int = 400
const SCORE_WORD_STARTS: int = 300
const SCORE_OBJECT: int = 260
const SCORE_NAME_CONTAINS: int = 200
const SCORE_KEYWORDS: int = 100
const SCORE_FUZZY: int = 40

## What a value adds when the row has somewhere to put it. Deliberately small: it settles a tie
## between two rows the words matched equally, and never outranks a word.
const SCORE_VALUE_FITS: int = 30

## The parameter kinds a number can land in, and the ones a piece of text can. A parameter whose
## hint is `expression` takes either, which is what most value slots are.
const NUMBER_TYPES: Array[String] = ["int", "float", "integer", "double"]
const TEXT_TYPES: Array[String] = ["String", "string"]


## The query split into the words that FIND a row and the values that FILL it.
## {"words": PackedStringArray, "values": PackedStringArray}.
static func split(query: String) -> Dictionary:
	var words: PackedStringArray = PackedStringArray()
	var values: PackedStringArray = PackedStringArray()
	for token: String in tokenize(query):
		if is_value(token):
			values.append(token)
		else:
			words.append(token)
	return {"words": words, "values": values}


## One query as its tokens, QUOTE-AWARE: a `"`-opened run stays ONE token with its quotes kept
## (a value is a raw GDScript expression, so a piece of text needs them), while everything else
## splits on spaces. An unterminated quote is forgiven - the rest becomes the final token. THE
## tokenizer for both places a typed sentence is read, the picker's filter and the quick-add bar,
## because `play "jump land"` has to mean the same thing in each. Static and pure.
static func tokenize(text: String) -> PackedStringArray:
	var tokens: PackedStringArray = PackedStringArray()
	var current: String = ""
	var in_quotes: bool = false
	for character: String in text:
		if character == "\"":
			in_quotes = not in_quotes
			current += character
		elif character == " " and not in_quotes:
			if not current.is_empty():
				tokens.append(current)
				current = ""
		else:
			current += character
	if not current.is_empty():
		tokens.append(current)
	return tokens


## True when a token is a VALUE rather than a word to search with: a number, or text in quotes.
## Nothing else counts - a bare word is always a word, even when a parameter would accept it,
## because a reader typing `red` means to find a row about red rather than to fill a field with it.
static func is_value(token: String) -> bool:
	if token.is_valid_float() or token.is_valid_int():
		return true
	return token.length() >= 2 and ((token.begins_with("\"") and token.ends_with("\"")) \
		or (token.begins_with("'") and token.ends_with("'")))


## The part of a query the row LIST should be filtered by - the words, with the values taken out.
## Handing the whole query to a filter that wants every token to appear somewhere is what made
## "boss fla 0.4" find nothing: no row's text contains 0.4, and the row was dropped before it could
## be scored.
static func words_query(query: String) -> String:
	return " ".join(split(query)["words"])


## How well one row answers the query. `name` is what the row is called, `object` the thing it is
## aimed at (a shelf entry's node, "" for an ordinary row) and `keywords` everything else the row
## can be found by - its category, its description, its tags. 0 means a word found nothing, which
## is a row the reader did not mean.
static func score(query: String, name: String, object: String = "", keywords: String = "") -> int:
	var parts: Dictionary = split(query)
	var words: PackedStringArray = parts["words"]
	if words.is_empty():
		return 0
	var lowered_name: String = name.to_lower()
	var total: int = 0
	for word: String in words:
		var hit: int = _word_score(word.to_lower(), lowered_name, object.to_lower(), keywords.to_lower())
		if hit == 0:
			return 0
		total += hit
	# The same tie-break the rest of the plugin's pickers use: of two names that both contain the
	# query, the shorter one is more of it.
	return total - mini(lowered_name.length(), 99)


## One word's best hit against the row.
static func _word_score(word: String, name: String, object: String, keywords: String) -> int:
	if name == word:
		return SCORE_WHOLE_NAME
	if name.begins_with(word):
		return SCORE_NAME_STARTS
	if EventSheetCompletions.word_starts_with(name, word):
		return SCORE_WORD_STARTS
	if not object.is_empty() and object.contains(word):
		return SCORE_OBJECT
	if name.contains(word):
		return SCORE_NAME_CONTAINS
	if keywords.contains(word):
		return SCORE_KEYWORDS
	if ACEPickerDialog.fuzzy_match(word, name):
		return SCORE_FUZZY
	return 0


## The values a query carries, placed into the row's parameters: each value goes to the first
## parameter that can take it and has not already been given one. Returns {param_id: value},
## empty when the query carried no values or the row has nowhere to put them.
##
## `parameters` is the shipped parameter list (id, type_name, hint); `already` is what the row has
## been given by something else, so a shelf entry that already chose the node is not overwritten.
static func prefill(query: String, parameters: Array, already: Dictionary = {}) -> Dictionary:
	var values: PackedStringArray = split(query)["values"]
	var filled: Dictionary = {}
	for value: String in values:
		for parameter: Variant in parameters:
			if not (parameter is Dictionary):
				continue
			var param: Dictionary = parameter as Dictionary
			var param_id: String = str(param.get("id", ""))
			if param_id.is_empty() or filled.has(param_id) or already.has(param_id):
				continue
			if not takes(param, value):
				continue
			filled[param_id] = value
			break
	return filled


## True when this parameter could hold this literal. A number fits a numeric parameter and any
## expression; quoted text fits a text parameter and any expression. A dropdown, a colour swatch or
## a node reference fits neither - a value dropped into one of those would be a value the field
## cannot show.
static func takes(param: Dictionary, value: String) -> bool:
	var hint: String = str(param.get("hint", "")).get_slice(":", 0)
	if not (param.get("options", []) as Array).is_empty():
		return false
	var type_name: String = str(param.get("type_name", param.get("type", "")))
	var numeric: bool = value.is_valid_float() or value.is_valid_int()
	if hint == "expression":
		return true
	if numeric:
		return NUMBER_TYPES.has(type_name)
	return TEXT_TYPES.has(type_name) and hint.is_empty()


## What a query's values add to a row's score: a small nudge toward the row that can actually hold
## them, so "boss fla 0.4" prefers the verb with a number in it over the one without.
static func value_bonus(query: String, parameters: Array) -> int:
	return SCORE_VALUE_FITS * prefill(query, parameters).size()
