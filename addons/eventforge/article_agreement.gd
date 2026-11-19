# EventForge - the English article before a type or class name ("an int", "a float").
#
# A leaf on purpose, with no `class_name` and nothing it names: the sentences that need it are built when a
# card or a finding is read, so it is loaded by path then and the first open of the editor never compiles it.
@tool
extends RefCounted


## The English indefinite article that goes before a type or class name read aloud: "an int", "an Array",
## "an Area2D", "a float", "a String", "a Node2D". A name written as a run of capital letters (AABB,
## HBoxContainer, AStar2D, UDPServer) is read by its first LETTER's name, so it follows the letter, not
## the vowel; any other name follows its first sound, with the few "you" and "wun" starts spelled out.
## An empty name takes "a" ("a value" reads well; the caller supplies the noun).
static func article_for(type_name: String) -> String:
	var word: String = type_name.strip_edges()
	if word.is_empty():
		return "a"
	var first: String = word.substr(0, 1)
	var lowered: String = word.to_lower()
	var second_is_capital: bool = word.length() > 1 and word.substr(1, 1) != word.substr(1, 1).to_lower()
	# A letter-spelled start: AABB, AStar2D, HBox, IPAddress, OS, RDShader, XRCamera, FBXDocument.
	if first == first.to_upper() and first != first.to_lower() and second_is_capital:
		return "an" if "aefhilmnorsx".contains(lowered.substr(0, 1)) else "a"
	if lowered.begins_with("uni") or lowered.begins_with("use") or lowered.begins_with("uti") \
			or lowered.begins_with("one") or lowered.begins_with("eu") or lowered.begins_with("ur"):
		return "a"
	return "an" if "aeiou".contains(lowered.substr(0, 1)) else "a"


## `type_name` with its article: "an int", "a float". An empty name gives "a value".
static func with_article(type_name: String) -> String:
	var word: String = type_name.strip_edges()
	if word.is_empty():
		return "a value"
	return "%s %s" % [article_for(word), word]


## A finished sentence whose template said "a <name>" and was filled with `type_name`, with that "a"
## (or "A" opening the sentence) made "an" where the name needs it. The template stays one key, so every
## translation keeps working: a sentence in another language holds no English "a <name>" to rewrite and
## passes through unchanged.
static func agree_article(sentence: String, type_name: String) -> String:
	var word: String = type_name.strip_edges()
	if word.is_empty() or article_for(word) != "an":
		return sentence
	var pattern: RegEx = RegEx.new()
	var escaped: String = word
	for special: String in ["\\", ".", "[", "]", "(", ")", "*", "+", "?", "{", "}", "|", "^", "$"]:
		escaped = escaped.replace(special, "\\" + special)
	if pattern.compile("(?<![A-Za-z0-9_])([Aa]) (?=" + escaped + "(?![A-Za-z0-9_]))") != OK:
		return sentence
	var result: String = ""
	var cursor: int = 0
	for found: RegExMatch in pattern.search_all(sentence):
		result += sentence.substr(cursor, found.get_end(1) - cursor) + "n"
		cursor = found.get_end(1)
	return result + sentence.substr(cursor)
