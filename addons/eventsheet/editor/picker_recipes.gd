# EventSheet - EventSheetPickerRecipes: the picker never renders an EMPTY list.
#
# A search that finds nothing used to end in one grey line of advice. Now it ends in two shelves
# that are still worth clicking:
#
#   Nearest matches   the vocabulary ranked by the quick-add ranker's RELAXED reading (see
#                     EventSheetQuickAdd.loose_score) - the entries the query almost said.
#   Recipes           whole worked examples, as real insertable rows. These are the guides' own
#                     self-drawing figures (the fenced examples the Manual already draws as rows,
#                     gated on byte-exact round-trip - see EventSheetDocFigures), so the picker and
#                     the docs share ONE source and can never drift apart.
#
# A recipe inserts through the same public, guarded, one-undo-step snippet path the Manual's
# figures use, so there is one way rows reach a sheet rather than two.
#
# The corpus walk happens ONCE per session (every guide page parsed, every fence gated off the
# baked verdicts) and is cached; searching afterwards is a ranked walk of a small in-memory list.
# Static and pure over the shipped bundle, so the whole surface is pinned headlessly.
@tool
class_name EventSheetPickerRecipes
extends RefCounted

## How many nearest entries and recipes the empty-result shelves offer at most. Small on purpose:
## the shelf is a door, not a second catalog.
const NEAREST_LIMIT := 8
const RECIPES_LIMIT := 6

## The session cache: [{title, page_id, page_title, body}]. Built on first ask, dropped by
## clear_cache() (tests that touch the bundle or the vocabulary must drop it on the way out).
static var _recipes: Array[Dictionary] = []
static var _loaded: bool = false


## Every recipe the shipped guides carry: one per self-drawing figure, titled by its caption when
## the author wrote one and by the nearest heading above it otherwise.
static func all_recipes() -> Array[Dictionary]:
	if _loaded:
		return _recipes
	_loaded = true
	_recipes = []
	for page_id: String in EventSheetDocLibrary.page_ids():
		var page_title: String = EventSheetDocLibrary.page_title(page_id)
		var heading: String = page_title
		for block: Dictionary in EventSheetDocLibrary.page_blocks(page_id):
			if str(block.get("kind", "")) == "heading":
				heading = str(block.get("text", heading))
				continue
			if str(block.get("kind", "")) != "code":
				continue
			var verdict: Dictionary = EventSheetDocFigures.recognize(block)
			if str(verdict.get("mode", "")) != EventSheetDocFigures.MODE_FIGURE:
				continue
			var caption: String = str(verdict.get("caption", "")).strip_edges()
			_recipes.append({
				"title": caption if not caption.is_empty() else heading,
				"page_id": page_id,
				"page_title": page_title,
				"body": str(verdict.get("body", "")),
			})
	return _recipes


## The recipes nearest one query, best first - ranked by the same relaxed ranker the nearest
## entries use, over the recipe's title and its page's. With nothing typed, the first few recipes
## stand in, so the shelf exists even for an empty query in an empty section.
static func search(query: String, limit: int = RECIPES_LIMIT) -> Array[Dictionary]:
	var trimmed: String = query.strip_edges()
	var scored: Array[Dictionary] = []
	for recipe: Dictionary in all_recipes():
		var score: int = 1
		if not trimmed.is_empty():
			score = EventSheetQuickAdd.loose_score(trimmed, str(recipe.get("title", "")), "",
				str(recipe.get("page_title", "")))
			if score <= 0:
				continue
		var entry: Dictionary = recipe.duplicate()
		entry["score"] = score
		scored.append(entry)
	scored.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["score"]) > int(right["score"]))
	if scored.size() > limit:
		scored.resize(limit)
	return scored


## The vocabulary nearest one query, best first, for the "nothing matched" shelf: the relaxed
## ranker over every definition, so an entry the strict filter dropped for one bad word still
## stands where the reader can see it.
static func nearest_definitions(query: String, definitions: Array[ACEDefinition],
		limit: int = NEAREST_LIMIT) -> Array[ACEDefinition]:
	var trimmed: String = query.strip_edges()
	if trimmed.is_empty():
		return [] as Array[ACEDefinition]
	var scored: Array[Dictionary] = []
	for definition: ACEDefinition in definitions:
		if definition == null:
			continue
		var score: int = EventSheetQuickAdd.loose_score(trimmed, str(definition.display_name), "",
			str(definition.category))
		if score > 0:
			scored.append({"score": score, "definition": definition})
	scored.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["score"]) > int(right["score"]))
	var out: Array[ACEDefinition] = []
	for entry: Dictionary in scored:
		out.append(entry["definition"] as ACEDefinition)
		if out.size() >= limit:
			break
	return out


## Inserts one recipe into the open sheet as real rows, through the same one-undo-step snippet
## path the Manual's figures use. False when there is no sheet open or the body no longer lifts
## (a caller says so rather than reporting silent success).
static func insert(recipe: Dictionary, label: String = "Insert recipe") -> bool:
	var sheet: EventSheetResource = EventSheetDocFigures.sheet_for_body(str(recipe.get("body", "")))
	if sheet == null:
		return false
	var text: String = EventSheetSnippet.serialize_rows(sheet.events, sheet)
	if text.is_empty():
		return false
	# as_example: a recipe is a guide's worked example, marked exactly as the figure it came from.
	return EventSheets.insert_snippet(text, label, true)


## Drops the session cache - for tests, and for a bundle rebuilt underneath a running editor.
static func clear_cache() -> void:
	_recipes = []
	_loaded = false
