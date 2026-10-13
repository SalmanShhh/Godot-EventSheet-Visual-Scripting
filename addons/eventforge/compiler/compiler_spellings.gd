# EventForge - the few spellings the compiler writes that the reading layer must recognise.
#
# The compiler owns these words: the prefix every shared helper it appends carries, the member the
# Distance Travelled rows keep, and the way a sheet function's return type is spelled after `->`.
# The editor's readers need the very same words to tell the compiler's own plumbing from the
# author's code and to say a function's type on its head.
#
# WHY A FILE OF ITS OWN: naming the compiler class compiles the compiler and everything it names,
# and the reading layer was naming it for three constants' worth of spelling - so the first sheet
# open paid for a whole compiler before anything was saved. The spellings live here, the compiler
# reads them from here, and a reader asks this file instead. One source, so the two can never
# disagree.
#
# DELIBERATELY NO `class_name`, and it names nothing but the function resource it reads: reach it
# with a const preload, which compiles these few lines and nothing else.
@tool
extends RefCounted

## The prefix EVERY shared helper the compiler writes carries. They are the compiler's own plumbing -
## one definition per file, appended last, never something anybody sat down and wrote - so a reader
## opening an emitted file must not be shown them as the author's own functions.
const SHARED_HELPER_PREFIX: String = "__eventsheets_"

## The running total Distance Travelled reads, kept beside the class only when a row reads it.
const TRAVELLED_MEMBER: String = "_travelled"


## The return type a sheet function is written with after `->`. An explicit type NAME wins - it can
## express what a Variant.Type can't (custom/engine classes, typed collections), so a lifted
## `-> HealthPool` helper round-trips verbatim. "void" for TYPE_NIL, "Variant" for the TYPE_MAX
## sentinel (there is no Variant.Type for Variant).
static func function_return_type_name(event_function: EventFunction) -> String:
	if not event_function.return_type_name.strip_edges().is_empty():
		return event_function.return_type_name.strip_edges()
	if event_function.return_type == TYPE_NIL:
		return "void"
	if event_function.return_type == TYPE_MAX:
		return "Variant"
	return type_string(event_function.return_type)
