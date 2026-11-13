# A rebuild of the rows states the sheet's patterns ONCE, and keeps what it stated.
#
# The registry of pattern claims lives exactly as long as one row build. The build used to walk the
# whole file for its claims, clear the registry a few lines later (which threw those claims away),
# and walk the file again the first time anything asked - so every rebuild paid for the walk twice,
# and the nearest-in-family (turret) claim, made only by that first walk, never survived a build at
# all. This pins both halves:
#   1. a built view holds the turret claim its file writes;
#   2. building the rows and drawing every one of them runs the file-level walk once.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "rebuild_claims_test"


static func run() -> bool:
	BehaviorShapeReadingTest._write_source()
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(BehaviorShapeReadingTest.SOURCE_PATH)
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1900.0, 1100.0)
	var walks_before: int = EventSheetViewportReadingRows.claim_walks
	view.set_sheet(sheet)
	view.settle_all_row_heights()
	var walks: int = EventSheetViewportReadingRows.claim_walks - walks_before
	var patterns: PackedStringArray = PackedStringArray()
	for claim: Variant in EventSheetPatternFacts.claims(view._sheet):
		patterns.append(str((claim as Dictionary).get("pattern", "")))
	var ok: bool = SUPPORT.pins(P, [
		["a built view holds the turret claim its file writes", patterns.has("turret"), true],
		["a build and a full draw run the file-level claim walk once", walks, 1],
	])
	view.free()
	return ok
