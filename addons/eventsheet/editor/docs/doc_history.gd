# EventSheet - EventSheetDocHistory: where the reader has been, and where they keep things.
#
# The four pieces of chrome every reader reaches for without thinking, kept in ONE place because
# they are one thing - a reading position:
#
#   BACK / FORWARD  the usual two stacks. Following a link pushes; going back pops onto forward;
#                   navigating after a back TRUNCATES forward, which is the behaviour every
#                   browser has trained into the reader's hand.
#   RECENT          the last pages visited, newest first, de-duplicated by id.
#   BOOKMARKS       the pages the reader starred. The sheet's own word for a kept place.
#   SCROLL          how far down each page they had read, so coming back lands where they left.
#
# STATIC, and per session by default: this is a reading position, not a preference. The host that
# wants it to outlive the editor (the docked Manual) writes `state()` into its own layout config
# and hands it back with `restore()` - which is why every field here serialises to plain
# Dictionaries and Arrays of Strings rather than to objects.
@tool
class_name EventSheetDocHistory
extends RefCounted

## How many pages the Recent menu offers. Enough to get back to what the reader was reading before
## they went looking for something, short enough to stay a menu rather than a list.
const MAX_RECENT := 12

## The config keys the host persists under. Frozen with the layout section they are written in.
const CONFIG_RECENT := "recent"
const CONFIG_BOOKMARKS := "bookmarks"

static var _back: Array[String] = []
static var _forward: Array[String] = []
static var _recent: Array[String] = []
static var _bookmarks: Array[String] = []
static var _scroll: Dictionary = {}
## The page the reader is on. Held rather than read off the browser, because the browser answers
## AFTER the navigation and the back stack has to be pushed before it.
static var _current: String = ""


## Records a navigation to `doc_id`. `pushed` is false for a move the history itself drove (a back
## or a forward), which must not push the page it just left back onto the stack it came from.
static func visit(doc_id: String, pushed: bool = true) -> void:
	var id: String = doc_id.strip_edges()
	if id.is_empty() or id == _current:
		return
	if pushed:
		if not _current.is_empty():
			_back.append(_current)
		_forward.clear()
	_current = id
	_recent.erase(id)
	_recent.insert(0, id)
	if _recent.size() > MAX_RECENT:
		_recent.resize(MAX_RECENT)


## The page on screen, as the history understands it.
static func current() -> String:
	return _current


static func can_go_back() -> bool:
	return not _back.is_empty()


static func can_go_forward() -> bool:
	return not _forward.is_empty()


## The page one step back, or "" when there is none. The caller navigates - this only moves the
## stacks - so a navigation that FAILS (a page that no longer ships) does not lose the position.
static func go_back() -> String:
	if _back.is_empty():
		return ""
	var target: String = _back[_back.size() - 1]
	_back.resize(_back.size() - 1)
	if not _current.is_empty():
		_forward.append(_current)
	_current = target
	return target


static func go_forward() -> String:
	if _forward.is_empty():
		return ""
	var target: String = _forward[_forward.size() - 1]
	_forward.resize(_forward.size() - 1)
	if not _current.is_empty():
		_back.append(_current)
	_current = target
	return target


## The pages visited this session, newest first.
static func recent() -> Array[String]:
	return _recent.duplicate()


## The starred pages, in the order they were starred.
static func bookmarks() -> Array[String]:
	return _bookmarks.duplicate()


static func is_bookmarked(doc_id: String) -> bool:
	return _bookmarks.has(doc_id.strip_edges())


## Stars or unstars a page, and reports what it now is - so a caller sets its star button from the
## return value instead of asking again.
static func toggle_bookmark(doc_id: String) -> bool:
	var id: String = doc_id.strip_edges()
	if id.is_empty():
		return false
	if _bookmarks.has(id):
		_bookmarks.erase(id)
		return false
	_bookmarks.append(id)
	return true


## Remembers how far down a page the reader had got.
static func remember_scroll(doc_id: String, offset: float) -> void:
	var id: String = doc_id.strip_edges()
	if id.is_empty():
		return
	if offset <= 0.0:
		_scroll.erase(id)
		return
	_scroll[id] = offset


## Where the reader was on a page, or 0.0 for one they have not read yet.
static func scroll_for(doc_id: String) -> float:
	return float(_scroll.get(doc_id.strip_edges(), 0.0))


## The half of this worth outliving the editor: what was read, and what was kept. The stacks are
## deliberately NOT in it - a back button that goes back to a page from last week is a back button
## that lies about where the reader has been.
static func state() -> Dictionary:
	return {CONFIG_RECENT: _recent.duplicate(), CONFIG_BOOKMARKS: _bookmarks.duplicate()}


## Restores what a host persisted. Ignores anything that is not a list of strings, so a config file
## edited by hand cannot take the surface down.
static func restore(state_dictionary: Dictionary) -> void:
	_recent = _string_list(state_dictionary.get(CONFIG_RECENT, []))
	if _recent.size() > MAX_RECENT:
		_recent.resize(MAX_RECENT)
	_bookmarks = _string_list(state_dictionary.get(CONFIG_BOOKMARKS, []))


## Drops everything, for a test that wants a fresh reader.
static func reset() -> void:
	_back = []
	_forward = []
	_recent = []
	_bookmarks = []
	_scroll = {}
	_current = ""


static func _string_list(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if not (value is Array or value is PackedStringArray):
		return out
	for entry: Variant in (value as Array if value is Array else Array(value as PackedStringArray)):
		var text: String = str(entry).strip_edges()
		if not text.is_empty() and not out.has(text):
			out.append(text)
	return out
