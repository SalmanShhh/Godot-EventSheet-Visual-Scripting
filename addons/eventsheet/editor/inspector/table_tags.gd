# Godot EventSheets - the tags a table's rows carry, read from one column of comma separated words.
#
# Pure functions over the rows of a table (an Array of Dictionaries) and the name of its tags column.
# The words are split on commas and trimmed, the way the packs that read these tables do.
@tool
extends RefCounted


## The words in one cell, trimmed, with the empty ones dropped.
static func words_of(cell: Variant) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	for part: String in str(cell if cell != null else "").split(","):
		var word: String = part.strip_edges()
		if not word.is_empty():
			words.append(word)
	return words


## Every tag any row carries, each once, in the order they first appear.
static func tags_in(rows: Array, column: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for row: Variant in rows:
		if not (row is Dictionary):
			continue
		for word: String in words_of((row as Dictionary).get(column, "")):
			if not found.has(word):
				found.append(word)
	return found


## True when some row carries `tag`. An empty tag is carried by no row, and means "none".
static func carries(rows: Array, column: String, tag: String) -> bool:
	return not tag.strip_edges().is_empty() and tags_in(rows, column).has(tag.strip_edges())
