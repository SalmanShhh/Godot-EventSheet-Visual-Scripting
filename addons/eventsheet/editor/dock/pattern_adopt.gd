# Godot EventSheets - ADOPT BEHAVIOR: swapping a hand-written pattern for the shipped one.
#
# Naming a pattern is only half the teaching. The other half is being able to say "then use the
# tested one" and have it happen - the shipped behaviors exist, the readings now name the shape, and
# the step between the two used to be manual: add the node, rewrite the events, delete the old code.
#
# THE SHAPE OF EVERY ADOPTION IS THE SAME, and it is the only shape a beginner can trust:
#
#   claim  ->  plan  ->  preview  ->  apply
#
# `plan` is pure and answers with everything the dialog draws AND everything `apply` will do: the
# rows as they read now, the rows as they would read, which of them change, and the "keeps working
# because" line that says what was checked. `apply` re-derives the same plan and performs exactly
# the edits it described, through the dock's undo funnel. A plan that is not `ok` carries a REASON
# in the sheet's own words instead - refusing with a reason is a feature, because a hand-written
# shape that does something the behavior cannot must not be quietly rewritten into one that does
# less.
#
# BYTE-EXACTNESS. An adoption changes only the rows the plan lists. Every other row, every variable,
# every comment and every blank line of the opened file is untouched, so re-emitting the sheet
# reproduces them exactly as they were - the round-trip contract holds across an adoption.
#
# ─────────────────────────────────────────────────────────────────────────────────────────────
# THE ADAPTER SEAM - how the other patterns plug in
#
# One adapter per adoptable id (the claim's `adoptable`, named in EventSheetPatternVocabulary):
#
#   1. `_plan_<id>(sheet, claim) -> Dictionary` - PURE. Walk the sheet, decide whether the shape can
#      be taken over, and return `_refusal(reason)` or `_plan(...)`. Touch nothing.
#   2. `_apply_<id>(sheet, claim) -> int` - performs the edits the plan described and returns how
#      many it made. Called inside the dock's undo funnel, so it may mutate freely; it must make
#      exactly the changes the plan listed and no others.
#   3. Add the id to the two `match` statements in `plan` and `apply`.
#
# Nothing else changes: the dialog, the menu item, the Doctor's "this block is behavior X" note and
# the Manual page's Adopt button all read the plan, so a new adapter is offered everywhere at once.
@tool
class_name EventSheetPatternAdopt
extends RefCounted


## Whether a claim can be offered an Adopt item at all - it names a behavior AND this build has an
## adapter for it. Cheap enough for a context menu build; the real answer comes from `plan`.
static func is_adoptable(claim: Dictionary) -> bool:
	return ADAPTERS.has(str(claim.get("adoptable", "")))


## The adoptable ids this build can actually rewrite. A claim may name a behavior that has no
## adapter yet: the ⟡ chip and the coverage count still say so (the behavior does exist), but
## nothing offers to do it, because offering a refactor that cannot run is worse than not offering.
const ADAPTERS: PackedStringArray = ["core_cooldown"]


## THE PLAN: everything the preview draws and everything `apply` will do.
##   {ok, reason, adoptable, pack, title, before, after, changed, checks}
## `before` / `after` are the affected events as the sheet says them, in the same order and the same
## length, so a dialog can put them side by side and highlight where they differ; `changed` holds
## the indices into those two that are not the same row twice.
static func plan(sheet: EventSheetResource, claim: Dictionary) -> Dictionary:
	if sheet == null or claim.is_empty():
		return _refusal("", EventSheetL10n.translate("There is nothing here to adopt."))
	var adoptable: String = str(claim.get("adoptable", ""))
	match adoptable:
		"core_cooldown":
			return _plan_core_cooldown(sheet, claim)
	return _refusal(adoptable, EventSheetL10n.translate(
		"This editor has no automatic rewrite for that behavior yet."))


## Performs the plan. Returns how many rows it changed - 0 when the plan refused, which is what the
## dock's undo funnel reads as "nothing happened, do not open an undo step".
##
## The plan is derived AGAIN here rather than handed in, because the commit replaces every resource
## with snapshot duplicates: a plan built before the edit holds references that are no longer the
## sheet's. Same input, same walk, same answer.
static func apply(sheet: EventSheetResource, claim: Dictionary) -> int:
	if not bool(plan(sheet, claim).get("ok", false)):
		return 0
	match str(claim.get("adoptable", "")):
		"core_cooldown":
			return _apply_core_cooldown(sheet, claim)
	return 0


# ── The Cooldown adapter ──────────────────────────────────────────────────────────────────────


## THE COOLDOWN PATTERN -> the Cooldown verbs. A hand-written cooldown is three rows working
## together: one counts a number down every tick, one asks whether it has reached zero, one puts it
## back up. The shipped Cooldown keeps a DEADLINE instead of a number, so all three become two:
## `Start Cooldown <name> for <seconds>` and `Cooldown Is Ready <name>`, and the per-tick subtraction
## disappears entirely - which is the whole point, because a deadline does not need counting.
##
## REFUSED when the shape does something the deadline cannot: when nothing ever restarts the
## countdown (there is no length for the behavior to use), when the comparison is against something
## other than zero (the behavior only knows "ready" and "not ready"), or when the number is read
## anywhere else (a HUD showing the seconds left needs Cooldown Time Left, and rewriting the counter
## out from under it would break the readout).
static func _plan_core_cooldown(sheet: EventSheetResource, claim: Dictionary) -> Dictionary:
	var counted: String = _counted_variable(sheet, claim)
	if counted.is_empty():
		return _refusal("core_cooldown", EventSheetL10n.translate("This event no longer counts anything down."))
	var facts: Dictionary = _cooldown_facts(sheet, counted)
	var restarts: Array = facts["restarts"]
	var asks: Array = facts["asks"]
	if restarts.is_empty():
		return _refusal("core_cooldown", EventSheetL10n.translate(
			"Nothing ever puts %s back above zero, so there is no cooldown length for the behavior to use.") % counted)
	if asks.is_empty():
		return _refusal("core_cooldown", EventSheetL10n.translate(
			"No event asks whether %s has run out, so there is nothing for Cooldown Is Ready to replace.") % counted)
	for entry: Variant in asks:
		var operator: String = str((entry as Dictionary).get("op", ""))
		var against: String = str((entry as Dictionary).get("value", "")).strip_edges()
		if not ["<=", "<"].has(operator) or not _is_zero(against):
			return _refusal("core_cooldown", EventSheetL10n.translate(
				"%s is compared to %s, and the behavior only knows whether a cooldown is ready.") % [counted, against])
	var other_uses: PackedStringArray = facts["other_uses"]
	if not other_uses.is_empty():
		return _refusal("core_cooldown", EventSheetL10n.translate(
			"%s is also read by %s, which needs the number itself.") % [counted, ", ".join(other_uses)])
	var seconds: String = str((restarts[0] as Dictionary).get("value", ""))
	var before: PackedStringArray = PackedStringArray()
	var after: PackedStringArray = PackedStringArray()
	var changed: PackedInt32Array = PackedInt32Array()
	for entry: Variant in facts["rows"]:
		var row: Dictionary = entry as Dictionary
		before.append(str(row["before"]))
		after.append(str(row["after"]))
		if str(row["before"]) != str(row["after"]):
			changed.append(before.size() - 1)
	var checks: PackedStringArray = PackedStringArray([
		EventSheetL10n.translate("%s is used only by these events.") % counted,
		EventSheetL10n.translate("The behavior counts the same %s seconds the code did.") % seconds,
		EventSheetL10n.translate("Cooldown Is Ready becomes true at the moment the countdown reached zero.")
	])
	return _plan_ok("core_cooldown",
		EventSheetL10n.translate("Adopt behavior: %s") % EventSheetPatternVocabulary.pack_label("core_cooldown"),
		before, after, changed, checks)


## Rewrites the sheet: the per-tick subtraction goes, the comparison becomes Cooldown Is Ready, the
## restart becomes Start Cooldown. Every other row is left exactly as it was.
static func _apply_core_cooldown(sheet: EventSheetResource, claim: Dictionary) -> int:
	var counted: String = _counted_variable(sheet, claim)
	if counted.is_empty():
		return 0
	var edits: int = 0
	for event_row: EventRow in _all_events(sheet):
		for index: int in range(event_row.conditions.size()):
			var condition: ACECondition = event_row.conditions[index]
			if condition == null or condition.ace_id != "CompareVar":
				continue
			if str(condition.params.get("var_name", "")) != counted:
				continue
			condition.ace_id = "CooldownReady"
			condition.provider_id = "Core"
			condition.params = {"name": "\"%s\"" % counted}
			edits += 1
		var kept: Array[Resource] = []
		for action_entry: Variant in event_row.actions:
			if not (action_entry is ACEAction):
				kept.append(action_entry)
				continue
			var action: ACEAction = action_entry as ACEAction
			if action.ace_id == "SubtractVar" and str(action.params.get("var_name", "")) == counted:
				# The deadline needs no counting down, so the row that did it goes.
				edits += 1
				continue
			if action.ace_id == "SetVar" and str(action.params.get("var_name", "")) == counted:
				action.ace_id = "StartCooldown"
				action.provider_id = "Core"
				action.params = {"name": "\"%s\"" % counted, "seconds": str(action.params.get("value", "0"))}
				edits += 1
			kept.append(action)
		event_row.actions = kept
	return edits


## The variable the claim's event counts down, re-found on the LIVE sheet (a claim carries a row uid,
## not a resource, exactly so that it survives an undo funnel replacing every resource).
static func _counted_variable(sheet: EventSheetResource, claim: Dictionary) -> String:
	var wanted: String = str(claim.get("row_uid", ""))
	for event_row: EventRow in _all_events(sheet):
		if event_row.event_uid != wanted:
			continue
		for action: Variant in event_row.actions:
			if action is ACEAction and (action as ACEAction).ace_id == "SubtractVar":
				return str((action as ACEAction).params.get("var_name", ""))
	return ""


## Everything the Cooldown plan needs to know about one counted variable: where it is counted down,
## asked about and restarted, every OTHER place it is mentioned, and the affected events as the
## sheet says them before and after. One walk, so the preview and the rewrite can never disagree
## about which rows are involved.
static func _cooldown_facts(sheet: EventSheetResource, counted: String) -> Dictionary:
	var asks: Array = []
	var restarts: Array = []
	var other_uses: PackedStringArray = PackedStringArray()
	var rows: Array = []
	for event_row: EventRow in _all_events(sheet):
		var touched: bool = false
		var before: PackedStringArray = PackedStringArray()
		var after: PackedStringArray = PackedStringArray()
		for condition: ACECondition in event_row.conditions:
			if condition == null:
				continue
			var says: String = _condition_words(condition)
			before.append(says)
			if condition.ace_id == "CompareVar" and str(condition.params.get("var_name", "")) == counted:
				asks.append({"op": str(condition.params.get("op", "")), "value": str(condition.params.get("value", ""))})
				after.append(_words("Core", "CooldownReady", {"name": "\"%s\"" % counted}))
				touched = true
			else:
				if _mentions(condition.params, counted):
					other_uses.append(says)
				after.append(says)
		for action_entry: Variant in event_row.actions:
			if not (action_entry is ACEAction):
				continue
			var action: ACEAction = action_entry as ACEAction
			var action_says: String = _words(action.provider_id, action.ace_id, action.params)
			before.append(action_says)
			if action.ace_id == "SubtractVar" and str(action.params.get("var_name", "")) == counted:
				touched = true
				continue
			if action.ace_id == "SetVar" and str(action.params.get("var_name", "")) == counted:
				restarts.append({"value": str(action.params.get("value", ""))})
				after.append(_words("Core", "StartCooldown",
					{"name": "\"%s\"" % counted, "seconds": str(action.params.get("value", "0"))}))
				touched = true
				continue
			if _mentions(action.params, counted):
				other_uses.append(action_says)
			after.append(action_says)
		if not touched:
			continue
		rows.append({"before": " · ".join(before), "after": " · ".join(after) if not after.is_empty()
			else EventSheetL10n.translate("(this event is no longer needed)")})
	return {"asks": asks, "restarts": restarts, "other_uses": other_uses, "rows": rows}


# ── Shared plumbing ───────────────────────────────────────────────────────────────────────────


## Every EventRow of a sheet, its functions included - the one walk every adapter uses, so an
## adapter can never miss a row a preview counted (or count one a rewrite will not reach).
static func _all_events(sheet: EventSheetResource) -> Array[EventRow]:
	var found: Array[EventRow] = []
	if sheet == null:
		return found
	_collect(sheet.events, found)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect((function_entry as EventFunction).events, found)
	return found


static func _collect(source: Array, into: Array[EventRow]) -> void:
	for entry: Variant in source:
		if not (entry is EventRow):
			continue
		into.append(entry as EventRow)
		_collect((entry as EventRow).sub_events, into)


## What a row SAYS - the sheet's own words for it, from the descriptor's display text with the
## parameter values filled in. The preview speaks the sheet's language rather than GDScript,
## because the reader is being asked whether their EVENTS still make sense.
static func _words(provider_id: String, ace_id: String, params: Dictionary) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
	if descriptor == null:
		return ace_id
	var text: String = descriptor.display_text if not descriptor.display_text.is_empty() else descriptor.display_name
	for key: Variant in params.keys():
		# A name the sheet QUOTES is still one name to a reader: `cooldown "cooldown" is ready` is
		# the quoting of a code literal leaking into a sentence, so the preview drops it.
		text = text.replace("{%s}" % str(key), _unquoted(str(params[key])))
	return text.strip_edges()


static func _unquoted(value: String) -> String:
	var text: String = value.strip_edges()
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	return text


static func _condition_words(condition: ACECondition) -> String:
	return _words(condition.provider_id, condition.ace_id, condition.params)


## Whether any parameter value mentions the name as a WORD - so `cooldown` matches but
## `cooldown_bar` does not, and a row that merely contains the letters is not accused of using it.
static func _mentions(params: Dictionary, name: String) -> bool:
	for key: Variant in params.keys():
		if str(key) == "var_name":
			continue
		for word: String in _words_in(str(params[key])):
			if word == name:
				return true
	return false


static func _words_in(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var current: String = ""
	for index: int in text.length():
		var character: String = text[index]
		if character.is_valid_identifier() or (current.is_empty() and character == "_") \
				or (not current.is_empty() and (character.is_valid_int() or character == "_")):
			current += character
		elif not current.is_empty():
			found.append(current)
			current = ""
	if not current.is_empty():
		found.append(current)
	return found


## Whether a comparison value is zero however it was written - `0`, `0.0`, `0.00`.
static func _is_zero(value: String) -> bool:
	return value.is_valid_float() and is_zero_approx(value.to_float())


static func _refusal(adoptable: String, reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "adoptable": adoptable,
		"pack": EventSheetPatternVocabulary.pack_label(adoptable), "title": "",
		"before": PackedStringArray(), "after": PackedStringArray(),
		"changed": PackedInt32Array(), "checks": PackedStringArray()}


static func _plan_ok(adoptable: String, title: String, before: PackedStringArray,
		after: PackedStringArray, changed: PackedInt32Array, checks: PackedStringArray) -> Dictionary:
	return {"ok": true, "reason": "", "adoptable": adoptable,
		"pack": EventSheetPatternVocabulary.pack_label(adoptable), "title": title,
		"before": before, "after": after, "changed": changed, "checks": checks}
