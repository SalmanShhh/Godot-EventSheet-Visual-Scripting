# EventSheet - refactor-following (interop phase 4).
#
# Renaming a member of your own script is the most ordinary thing a developer does, and it is
# exactly what breaks sheets: the verb's identity changes, every row that used it still emits
# the OLD call, and the failure surfaces only when the player triggers it. The Doctor already
# catches that (the orphaned-verb check); this adds the part that makes it feel like the tool
# is on your side rather than scolding you - naming the member you almost certainly renamed it
# to.
#
# CONSERVATISM IS THE WHOLE DESIGN. A confident wrong suggestion is worse than none: it sends
# someone to "fix" a call that was never the problem. So a suggestion is offered only when one
# candidate is clearly the best, and silence is the default everywhere else.
@tool
class_name EventSheetRefactorFollow
extends RefCounted

## How close a name must be before it is worth naming out loud. Godot's String.similarity is
## bigram-based, and the threshold is set from MEASURED scores rather than intuition - the
## most common rename shape (a swapped verb prefix) scores far lower than it feels like it
## should:
##     start_wave ~ begin_wave = 0.444      do_fire ~ fire   = 0.667
##     start_fire ~ begin_fire = 0.444      fire    ~ quit   = 0.000
##     start_wave ~ stop       = 0.167      do_fire ~ reload = 0.182
## 0.40 admits the prefix swaps while leaving unrelated names (<0.2) far outside.
const MIN_SIMILARITY: float = 0.40
## A suggestion must beat the runner-up by this much. This, not the threshold, is the real
## guard against a confident wrong answer: sibling members share prefixes and score alike
## (set_value ~ set_valve and ~ set_valid are BOTH 0.750), and a tie means the tool does not
## actually know which one you meant.
const MIN_LEAD: float = 0.10


## The member `missing` was most likely renamed to, or "" when nothing is clearly closest.
## Static + pure, so every rule below is pinned without a project.
static func closest_member(missing: String, candidates: PackedStringArray) -> String:
	var needle: String = missing.strip_edges()
	if needle.is_empty():
		return ""
	var best: String = ""
	var best_score: float = 0.0
	var runner_up: float = 0.0
	for candidate: String in candidates:
		if candidate == needle:
			return ""  # not missing at all - never suggest a rename of something present
		var score: float = needle.similarity(candidate)
		if score > best_score:
			runner_up = best_score
			best_score = score
			best = candidate
		elif score > runner_up:
			runner_up = score
	if best_score < MIN_SIMILARITY:
		return ""
	if best_score - runner_up < MIN_LEAD:
		return ""  # ambiguous: two members look equally plausible, so say nothing
	return best


## The sentence the Doctor appends when a rename is the likely cause. "" keeps the existing
## message exactly as it was, which is what every non-obvious case gets.
static func rename_hint(missing: String, candidates: PackedStringArray) -> String:
	var suggestion: String = closest_member(missing, candidates)
	if suggestion.is_empty():
		return ""
	return " Did you rename it to %s()? If so, open Sheet > Custom ACE Providers, select it under the new name and use \"Keep Old Name\" to add a stand-in so existing rows keep working." % suggestion


## The member names a provider index entry offers, as a flat list for `closest_member`.
## Tolerates both index shapes (a member dictionary or a plain list).
static func member_names(entry: Variant) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if entry is Dictionary:
		var members: Variant = (entry as Dictionary).get("members", entry)
		if members is Dictionary:
			for member: Variant in (members as Dictionary).keys():
				names.append(str(member))
		elif members is Array or members is PackedStringArray:
			for member: Variant in members:
				names.append(str(member))
	elif entry is Array or entry is PackedStringArray:
		for member: Variant in entry:
			names.append(str(member))
	return names
