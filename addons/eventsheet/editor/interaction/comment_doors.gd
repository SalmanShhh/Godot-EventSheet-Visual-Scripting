@tool
class_name EventSheetCommentDoors
extends RefCounted

# A NOUN IN A COMMENT IS A DOOR WHEN THE PROJECT CAN PROVE IT EXISTS.
#
# A note beside an event says "%HealthBar shows this", "goes back to Patrol", "the rest is in
# hud.gd". Those are names of real things, and until now they were grey prose: a reader who wanted
# the thing had to go and find it by hand. So a word a project INDEX already answers for becomes a
# door - underlined while reading, clicked to arrive.
#
# GROUNDED, NEVER GUESSED. Nothing here parses meaning out of English. A word is a door only when it
# is spelled exactly like something one of the indexes below holds, and a name nothing matches stays
# plain prose with no mark and no message. That is the whole rule, in both directions: a door always
# leads somewhere, and a sentence that merely reads like a name is left alone.
#
# THE SAME INDEXES EVERYTHING ELSE READS. There is no new scan and no second store here. Every one
# of the five kinds is a list `EventSheetCompletions` already builds and caches for the completion
# popup - the scene's nodes, this sheet's functions, this object's declared states, the game's
# declared modes, the project's own files. This seam only asks for them and looks names up. When
# that seam's caches are dropped (a sheet edit, the editor's filesystem ping) it hands back FRESH
# arrays, and the identity check below notices and rebuilds - so there is nothing extra to
# invalidate and no way for a door to point at something that has gone.
#
# EMISSION IS UNTOUCHED. A door is metadata on a span. The CommentRow's own `text` is never read
# back out of one, never rewritten, and the `#` / `##` line the compiler emits is the same line it
# always was. Doors exist while a comment is being READ in the editor and nowhere else.
#
# COST. The table is built once per sheet (five cached lookups and a walk of what they hold) and the
# per-line scan is one pass over the characters of the line. Both run when a comment row is BUILT,
# which is where the row's spans are made - never per frame and never per hover: the hit-test reads
# rectangles the renderer stamped, exactly as the colour swatch and the object label do.


## What a door can BE. The stable kind words of the completion seam, not new ones: a state answered
## here and a state answered in the Quick Add field are the same kind of thing and say so.
const KIND_NODE := EventSheetCompletions.KIND_NODE
const KIND_FUNCTION := EventSheetCompletions.KIND_FUNCTION
const KIND_STATE := EventSheetCompletions.KIND_STATE
const KIND_MODE := EventSheetCompletions.KIND_MODE
const KIND_SHEET := EventSheetCompletions.KIND_FILE

## The shortest name that may become a door. A short word is inside far too much ordinary prose for
## a match on one to be evidence of anything; a `$X` node reference is exempt because its sigil is
## already the evidence.
##
## FOUR, NOT THREE, and the reason is the rule this file states about itself: "a sentence that merely
## reads like a name is left alone". Run, Hit, Die, Won, Fly and End are perfectly ordinary state
## names AND perfectly ordinary English, so at three letters "Run the game before shipping" and "Hit
## points go here" both grew an underline under a word that was plain prose. A threshold cannot tell
## prose from a name and this one does not pretend to - it only stops the shortest words, which are
## the ones where a match is almost never evidence. A four-letter state name a project also uses as
## an ordinary word is still claimed, and the door is inert and the comment untouched either way.
const MIN_NAME_LENGTH: int = 4

## The files a name may open AS A SHEET. Both are formats the workspace opens; anything else in the
## project is a file this vocabulary has no door for.
const SHEET_EXTENSIONS: PackedStringArray = ["gd", "tres"]

## name -> {"kind": …, "target": …}, and the pools it was built from. The pools are held by
## REFERENCE so the next ask can tell a live table from a stale one without rebuilding either.
static var _table: Dictionary = {}
static var _table_key: String = ""
static var _table_pools: Array = []


## The door table for one sheet: every name the project can prove, and what each one opens.
##
## Rebuilt when the sheet changes or when any of the five lists it stands on has been rebuilt
## underneath it. The completion seam hands back its own arrays, so "has this been rebuilt" is an
## identity question rather than a comparison of contents.
static func table_for(sheet: EventSheetResource) -> Dictionary:
	var key: String = str(sheet.get_instance_id() if sheet != null else 0)
	var pools: Array = [
		EventSheetCompletions.candidates(null, EventSheetCompletions.FIELD_NODE),
		EventSheetCompletions.candidates(sheet, EventSheetCompletions.FIELD_STATE),
		EventSheetCompletions.candidates(sheet, EventSheetCompletions.FIELD_MODE),
		EventSheetCompletions.candidates(sheet, EventSheetCompletions.FIELD_FUNCTION),
		EventSheetCompletions.candidates(null, EventSheetCompletions.FIELD_FILE),
	]
	if key == _table_key and _same_pools(pools):
		return _table
	_table_key = key
	_table_pools = pools
	_table = build_table(pools)
	return _table


## True when every pool is the very array the held table was built from.
static func _same_pools(pools: Array) -> bool:
	if _table_pools.size() != pools.size():
		return false
	for at: int in range(pools.size()):
		if not is_same(_table_pools[at], pools[at]):
			return false
	return true


## Drops the held table. Nothing in the editor needs to call this - the identity check above covers
## every way an answer can change - but a test that swaps the whole project underneath the seam has
## no sheet identity to change and says so here instead.
static func clear_cache() -> void:
	_table.clear()
	_table_key = ""
	_table_pools = []


## The table itself, from the five pools handed in - the ask above builds them out of the cached
## lists; a test hands its own, so a claim rule can be pinned without a project shaped around it.
##
## The pools arrive in the order a collision is resolved in: a node reference
## (which carries its own sigil and cannot be anything else), then this object's states and the
## game's modes (declared words, and the reason a reader is looking), then this sheet's functions,
## then the project's sheet files. The first claim on a name wins, so a state and a function of the
## same name read as the state - and nothing silently changes meaning when a later list grows.
static func build_table(pools: Array) -> Dictionary:
	var table: Dictionary = {}
	for entry: Dictionary in (pools[0] as Array[Dictionary]):
		# A node entry already carries the spelling a comment writes it in - `$Path` or `%Name`.
		_claim(table, str(entry.get("text", "")), KIND_NODE, str(entry.get("text", "")), true)
	for entry: Dictionary in (pools[1] as Array[Dictionary]):
		var state_member: String = str(entry.get("text", ""))
		_claim(table, state_member, KIND_STATE, state_member)
		_claim(table, EventSheetStateFacts.word_for(state_member), KIND_STATE, state_member)
	for entry: Dictionary in (pools[2] as Array[Dictionary]):
		var mode_member: String = str(entry.get("text", ""))
		_claim(table, mode_member, KIND_MODE, mode_member)
		_claim(table, EventSheetModeFacts.word_for(mode_member), KIND_MODE, mode_member)
	for entry: Dictionary in (pools[3] as Array[Dictionary]):
		var function_name: String = str(entry.get("text", ""))
		_claim(table, function_name, KIND_FUNCTION, function_name)
	_claim_sheet_files(table, pools[4] as Array[Dictionary])
	return table


## The project's sheet files, by file NAME - which is how a comment says one ("the rest is in
## hud.gd"). A name TWO files answer to is dropped rather than pointed at one of them: an ambiguous
## door is a guess, and a guess is the one thing this may not be.
static func _claim_sheet_files(table: Dictionary, files: Array[Dictionary]) -> void:
	var by_name: Dictionary = {}
	for entry: Dictionary in files:
		var path: String = str(entry.get("text", "")).strip_edges().trim_prefix("\"").trim_suffix("\"")
		if not SHEET_EXTENSIONS.has(path.get_extension().to_lower()):
			continue
		var file_name: String = path.get_file()
		by_name[file_name] = "" if by_name.has(file_name) else path
	for file_name: Variant in by_name:
		if not str(by_name[file_name]).is_empty():
			_claim(table, str(file_name), KIND_SHEET, str(by_name[file_name]))


## Records one name, unless it is too short to be evidence or somebody already claimed it.
static func _claim(table: Dictionary, name: String, kind: String, target: String, sigil: bool = false) -> void:
	var word: String = name.strip_edges()
	if word.is_empty() or table.has(word):
		return
	if not sigil and word.length() < MIN_NAME_LENGTH:
		return
	table[word] = {"kind": kind, "target": target}


## The doors in ONE line of a comment: `[{start, length, text, kind, target}]`, in the order they
## appear, never overlapping. Empty for a line that names nothing the table holds, which is most
## lines of most comments.
##
## Two passes, because a declared name has two shapes. The token pass reads the line as the
## characters an identifier, a node reference or a file name is spelled with; the phrase pass then
## looks for the declared words that contain a SPACE ("Gave Up"), which no token can be. A phrase may
## not land on top of a token door - the first pass has already said what those characters are.
static func doors_in(line: String, table: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if line.is_empty() or table.is_empty():
		return found
	_token_doors(line, table, found)
	_phrase_doors(line, table, found)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["start"]) < int(b["start"]))
	return found


## The doors spelled as one run of characters: `%HealthBar`, `on_hit`, `hud.gd`, `PATROL`.
static func _token_doors(line: String, table: Dictionary, found: Array[Dictionary]) -> void:
	var at: int = 0
	while at < line.length():
		var length: int = _token_length(line, at)
		if length <= 0:
			at += 1
			continue
		var token: String = line.substr(at, length)
		if table.has(token):
			found.append(_door(at, token, table[token] as Dictionary))
		at += length


## How many characters the token starting at `at` runs for, 0 when nothing starts there. A token is
## a node reference (`$` or `%` then a path) or a plain name that may carry a dotted tail so a file
## name is one token rather than two.
static func _token_length(line: String, at: int) -> int:
	var head: String = line.substr(at, 1)
	var cursor: int = at
	if head == "$" or head == "%":
		cursor += 1
		while cursor < line.length() and (_is_name_character(line.substr(cursor, 1)) or line.substr(cursor, 1) == "/"):
			cursor += 1
		# A lone sigil is the modulo sign or a stray dollar, not a reference to anything.
		return cursor - at if cursor > at + 1 else 0
	if not _is_name_start(head):
		return 0
	while cursor < line.length() and _is_name_character(line.substr(cursor, 1)):
		cursor += 1
	# One dotted tail, which is what a file name is. A second dot ends the token, so a sentence
	# ending in a name keeps its full stop out of the door.
	if cursor < line.length() - 1 and line.substr(cursor, 1) == "." and _is_name_start(line.substr(cursor + 1, 1)):
		cursor += 1
		while cursor < line.length() and _is_name_character(line.substr(cursor, 1)):
			cursor += 1
	return cursor - at


## The declared WORDS that hold a space, found as whole phrases. Only phrases: a single word is a
## token and was already answered by the pass above.
static func _phrase_doors(line: String, table: Dictionary, found: Array[Dictionary]) -> void:
	for name: Variant in table:
		var phrase: String = str(name)
		if not phrase.contains(" "):
			continue
		var at: int = line.find(phrase)
		while at >= 0:
			if _stands_alone(line, at, phrase.length()) and not _overlaps(found, at, phrase.length()):
				found.append(_door(at, phrase, table[phrase] as Dictionary))
			at = line.find(phrase, at + phrase.length())


## True when the run at `at` is not glued to a name character on either side - "Gave Up" inside
## "Gave Upwards" is not the state.
static func _stands_alone(line: String, at: int, length: int) -> bool:
	if at > 0 and _is_name_character(line.substr(at - 1, 1)):
		return false
	var after: int = at + length
	return after >= line.length() or not _is_name_character(line.substr(after, 1))


static func _overlaps(found: Array[Dictionary], at: int, length: int) -> bool:
	for door: Dictionary in found:
		var start: int = int(door["start"])
		if at < start + int(door["length"]) and start < at + length:
			return true
	return false


static func _door(at: int, text: String, claim: Dictionary) -> Dictionary:
	return {"start": at, "length": text.length(), "text": text,
		"kind": str(claim.get("kind", "")), "target": str(claim.get("target", ""))}


## True for the characters a name is spelled with. Written out rather than asked of
## `is_valid_identifier`, which answers about a whole name and says no to a lone digit that is
## perfectly ordinary in the middle of one.
static func _is_name_character(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper() or character.is_valid_int()


static func _is_name_start(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper()


## Where each door lands INSIDE a comment span, as `{door, x, line, width}` offsets from the span's
## text origin: `x` across, `line` the wrapped visual line it fell on, `width` how wide the word
## draws. The renderer turns these into rectangles it both underlines and stamps for the hit-test,
## so what is drawn and what is clickable are one measurement rather than two.
##
## `breaks` is where the DRAW broke the text into visual lines, handed in rather than worked out
## again here: a door underlined on a line the renderer did not put the word on is worse than no
## underline, and the only way to be sure is to measure against the very break points being drawn.
static func door_boxes(text: String, doors: Array, breaks: PackedInt32Array, font: Font, font_size: int) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	if font == null or doors.is_empty() or text.is_empty():
		return boxes
	if breaks.is_empty():
		breaks = PackedInt32Array([0])
	for entry: Variant in doors:
		var door: Dictionary = entry
		var start: int = int(door.get("start", -1))
		var length: int = int(door.get("length", 0))
		if start < 0 or length <= 0 or start + length > text.length():
			continue
		var line_index: int = 0
		for at: int in range(breaks.size()):
			if breaks[at] <= start:
				line_index = at
		var line_start: int = breaks[line_index]
		# A door that straddles a wrap break is not drawn: half an underline under half a word says
		# less than none, and the word is still perfectly readable prose.
		if line_index + 1 < breaks.size() and start + length > breaks[line_index + 1]:
			continue
		boxes.append({
			"door": door,
			"line": line_index,
			"x": font.get_string_size(text.substr(line_start, start - line_start),
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x,
			"width": font.get_string_size(text.substr(start, length),
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x,
		})
	return boxes
