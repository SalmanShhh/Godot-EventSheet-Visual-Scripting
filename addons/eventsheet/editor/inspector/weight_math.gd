# Godot EventSheets - the sums behind a weighted table: each row's share of the total, how the odds
# read as words, and a roll of the table many times over.
#
# Pure functions over the rows of a table (an Array of Dictionaries) and the name of its weight
# column. Nothing here draws or stores anything; a control asks, shows the answer and forgets it.
# A weight below 0 counts as 0, the same as the packs that read these tables when the game runs.
@tool
extends RefCounted


## A row's weight: its number in `column`, never below 0, and 0 for anything that is not a number.
static func weight_of(row: Variant, column: String) -> float:
	if not (row is Dictionary):
		return 0.0
	var value: Variant = (row as Dictionary).get(column, 0.0)
	if value is int or value is float:
		return maxf(float(value), 0.0)
	return 0.0


## The sum of every row's weight.
static func total(rows: Array, column: String) -> float:
	var sum: float = 0.0
	for row: Variant in rows:
		sum += weight_of(row, column)
	return sum


## Each row's share of the total, 0 to 1, in row order. Every share is 0 when the total is 0.
static func shares(rows: Array, column: String) -> PackedFloat64Array:
	var result: PackedFloat64Array = PackedFloat64Array()
	var sum: float = total(rows, column)
	for row: Variant in rows:
		result.append(weight_of(row, column) / sum if sum > 0.0 else 0.0)
	return result


## A share as a percentage in words: one decimal, and none when it is a whole number ("62.5%", "50%").
static func percent_text(share: float) -> String:
	var percent: float = snappedf(share * 100.0, 0.1)
	if is_equal_approx(percent, roundf(percent)):
		return "%d%%" % int(roundf(percent))
	return "%.1f%%" % percent


## The row with the biggest share, or -1 when no row has any weight. The first wins a tie.
static func largest(rows: Array, column: String) -> int:
	var best: int = -1
	var best_weight: float = 0.0
	for index: int in rows.size():
		var weight: float = weight_of(rows[index], column)
		if weight > best_weight:
			best_weight = weight
			best = index
	return best


## How many times each row comes up in `times` picks made in proportion to the weights. `rng` is the
## caller's own generator, so a test can seed it. All zeros when no row has a weight.
static func roll(rows: Array, column: String, times: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(rows.size())
	var sum: float = total(rows, column)
	if sum <= 0.0:
		return counts
	for _step: int in times:
		var point: float = rng.randf() * sum
		var running: float = 0.0
		var chosen: int = -1
		for index: int in rows.size():
			var weight: float = weight_of(rows[index], column)
			if weight <= 0.0:
				continue
			running += weight
			chosen = index
			if point < running:
				break
		if chosen >= 0:
			counts[chosen] += 1
	return counts


## The name of a row for the odds line: its text in `label_column`, or "Row N" when that is empty.
static func row_name(row: Variant, label_column: String, index: int) -> String:
	if row is Dictionary:
		var text: String = str((row as Dictionary).get(label_column, "")).strip_edges()
		if not text.is_empty():
			return text
	return "Row %d" % (index + 1)


## The first column of `columns` (Dictionaries with "name" and "type") that holds text, or "" when none does.
static func first_text_column(columns: Array) -> String:
	for column: Variant in columns:
		if column is Dictionary and str((column as Dictionary).get("type", "")) in ["String", "StringName"]:
			return str((column as Dictionary).get("name", ""))
	return ""


## The odds as one line: the rows with a weight, biggest first, up to `limit` names, then "and N more".
## `more_words` is the translated format for the tail and takes the count ("and %d more").
static func odds_line(rows: Array, column: String, label_column: String, limit: int, more_words: String) -> String:
	var share_list: PackedFloat64Array = shares(rows, column)
	var order: Array[int] = []
	for index: int in rows.size():
		if share_list[index] > 0.0:
			order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool: return share_list[a] > share_list[b] if share_list[a] != share_list[b] else a < b)
	var parts: PackedStringArray = PackedStringArray()
	for position: int in mini(limit, order.size()):
		var index: int = order[position]
		parts.append("%s %s" % [row_name(rows[index], label_column, index), percent_text(share_list[index])])
	var line: String = ", ".join(parts)
	if order.size() > limit:
		line += " " + (more_words % (order.size() - limit))
	return line
