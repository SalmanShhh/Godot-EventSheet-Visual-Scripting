# EventSheet - EventSheetDocFeedback: the foot of every page, and the two knobs a reader reaches for.
#
# Three small things, kept together because they are one idea - the reader answering the page back:
#
#   WAS THIS PAGE HELPFUL?  Yes / No, stored LOCALLY and sent nowhere. Nothing in this plugin phones
#                           anybody, and a feedback widget that quietly did would be the one thing
#                           on this surface a reader could not verify by reading it.
#   REPORT A PROBLEM        opens the tracker's documentation form in the reader's browser with the
#                           page name already in the title and in the form's page field. It OPENS a page; it never submits one - the
#                           reader types and presses the button themselves, in their own browser,
#                           signed in as themselves.
#   A- / A+                 the page's text size, remembered per reader. Independent of the editor's
#                           own help font size, because a reader who wants big documentation text
#                           does not necessarily want a big Script editor.
#
# Everything is static and PURE where it can be - the sentence, the URL, the next size in the ramp -
# so the suite pins the words and the arithmetic without a window.
@tool
class_name EventSheetDocFeedback
extends RefCounted

## Where a reader's answers and their text size live. Editor metadata, like every other reading
## position on this surface: it belongs to the reader, not to the project.
const SECTION := "eventsheets"
const HELPFUL_KEY := "doc_helpful"
const TEXT_SCALE_KEY := "doc_text_scale"

## The three states a page's answer can be in. UNSET is not "no" - a page nobody answered about is
## a page nobody answered about.
const UNSET := 0
const YES := 1
const NO := -1

## The text-size ramp, as a multiplier on whatever body size the page would otherwise use. Ends
## rather than wraps: A+ at the top does nothing, which is what a reader expects of a size button.
const MIN_SCALE := 0.8
const MAX_SCALE := 1.6
const SCALE_STEP := 0.1

## The one repository address and the issue forms (eventforge/report_links.gd).
const LINKS = preload("res://addons/eventforge/report_links.gd")

## The words at the foot of every page. Constants because they are also translation keys.
const PROMPT := "Was this page helpful?"
const YES_LABEL := "Yes"
const NO_LABEL := "No"
const REPORT_LABEL := "Report a problem"
const SMALLER_LABEL := "A-"
const LARGER_LABEL := "A+"


## What the reader last said about a page: YES, NO or UNSET.
static func helpful(doc_id: String) -> int:
	var id: String = doc_id.strip_edges()
	if id.is_empty():
		return UNSET
	return int(_answers().get(id, UNSET))


## Records an answer, or clears it when the reader presses the button they already pressed - the
## same gesture the bookmark star has, and the only way to take back a "No" pressed by accident.
## Returns the state the page is now in, so a caller sets its buttons from the return value.
static func set_helpful(doc_id: String, answer: int) -> int:
	var id: String = doc_id.strip_edges()
	if id.is_empty():
		return UNSET
	var answers: Dictionary = _answers()
	var now: int = UNSET if int(answers.get(id, UNSET)) == answer else answer
	if now == UNSET:
		answers.erase(id)
	else:
		answers[id] = now
	_store(HELPFUL_KEY, answers)
	return now


## The line the foot shows once a reader has answered, so the answer is visible rather than a
## button that silently changed colour. "" while the page is unanswered.
static func answer_line(answer: int) -> String:
	match answer:
		YES:
			return "Thanks - noted on this machine, and sent nowhere."
		NO:
			return "Noted on this machine. Report a problem opens the tracker if you want to say why."
	return ""


## The address a "Report a problem" opens: the documentation form, with the page named in the title and
## in the form's page field. Pure over its inputs, so the suite pins the address and the prefill rather
## than trusting a click. `repo_url` is kept for callers that pass one; the address itself is the one
## repository address in eventforge/report_links.gd.
##
## Only the page's name travels - nothing about the reader's machine or project. This button opens a
## page; it never sends one.
static func report_url(repo_url: String, page_title: String, doc_id: String) -> String:
	if repo_url.strip_edges().is_empty():
		return ""
	var named: String = page_title.strip_edges()
	if named.is_empty():
		named = doc_id.strip_edges()
	return LINKS.docs_url(named)


## The address behind "ask for a page about ..." - the row a search with no answers ends on. It opens the
## SAME documentation form "Report a problem" does, deliberately: a reader answering the Manual back has
## one place to do it, whether what they have to say is "this page is wrong" or "there is no page". The
## search is named in the title and in the page field; nothing is submitted.
static func ask_url(repo_url: String, query: String) -> String:
	var wanted: String = query.strip_edges()
	if repo_url.strip_edges().is_empty() or wanted.is_empty():
		return ""
	return LINKS.docs_url("no page yet - searched for: %s" % wanted, "Manual: no page about %s" % wanted)


# ── Text size ─────────────────────────────────────────────────────────────────────────────────


## The reader's chosen text multiplier, clamped to the ramp so a hand-edited config cannot make the
## Manual unreadable.
static func text_scale() -> float:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return 1.0
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return 1.0
	return clamped_scale(float(settings.get_project_metadata(SECTION, TEXT_SCALE_KEY, 1.0)))


## One press of A- or A+. Pure, so the ramp and its ends are pinned rather than clicked.
static func stepped_scale(current: float, steps: int) -> float:
	return clamped_scale(snappedf(current + float(steps) * SCALE_STEP, SCALE_STEP))


## Any number brought into the ramp.
static func clamped_scale(value: float) -> float:
	return clampf(snappedf(value, SCALE_STEP), MIN_SCALE, MAX_SCALE)


## Remembers a text size.
static func set_text_scale(value: float) -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings != null:
		settings.set_project_metadata(SECTION, TEXT_SCALE_KEY, clamped_scale(value))


## The size line beside the two buttons, so a reader can see what they have done. Pure.
static func scale_label(value: float) -> String:
	return "%d%%" % int(round(clamped_scale(value) * 100.0))


static func _answers() -> Dictionary:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return {}
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return {}
	var stored: Variant = settings.get_project_metadata(SECTION, HELPFUL_KEY, {})
	return stored as Dictionary if stored is Dictionary else {}


static func _store(key: String, value: Variant) -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings != null:
		settings.set_project_metadata(SECTION, key, value)
