# Godot EventSheets - what the optimiser's fixes actually did, measured.
#
# A tool that changes your code to make it faster owes you the number. Without one it is teaching
# superstition: the row was changed, the game feels the same, and the reader learns to believe
# whatever the tool said rather than what the machine did.
#
# So every applied fix leaves a RECEIPT: what the row cost when the fix was made, and which
# completed run that number came from. After the NEXT profiled run the note under the row reads
# "2.4 -> 0.3 ms" - or says the fix did not help, just as plainly, with the way back beside it.
#
# The receipts live beside the editor's other remembered choices (user://), never in the sheet: a
# sheet's bytes are its author's, and a measurement is not part of the program.
@tool
class_name EventSheetOptimiserReceipts
extends RefCounted

const STORE_PATH := "user://eventsheets_optimiser_receipts.cfg"

## How much faster a fix has to make a row before it is called an improvement, as a share of what
## the row cost before. Below this the two runs simply disagreed by noise, and the receipt says the
## honest thing rather than claiming a win.
const MEANINGFUL_SHARE := 0.15

## sheet path -> row uid -> {kind, before_ms, before_when}. Read once per editor session, written
## whenever a fix is applied or a receipt is dismissed.
static var _receipts: Dictionary = {}
static var _loaded: bool = false


## Remembers what a row cost the moment a fix was applied to it. `before_ms` is what the overlay was
## showing - the honest "before", because it is the number the reader had just looked at. `undo`
## carries what it would take to put the change back, so the way out survives closing the editor.
static func note_fix(sheet_path: String, uid: String, kind: String, undo: Dictionary = {}) -> void:
	if sheet_path.strip_edges().is_empty() or uid.strip_edges().is_empty():
		return
	_load()
	var per_sheet: Dictionary = _receipts.get(sheet_path, {})
	var receipt: Dictionary = undo.duplicate()
	receipt["kind"] = kind
	receipt["before_ms"] = EventSheetRunProfile.ms_for(uid)
	receipt["before_when"] = EventSheetRunProfile.stored_when()
	per_sheet[uid] = receipt
	_receipts[sheet_path] = per_sheet
	_save()


## The receipt for one row, or {} when that row carries none.
static func receipt_for(sheet_path: String, uid: String) -> Dictionary:
	_load()
	return (_receipts.get(sheet_path, {}) as Dictionary).get(uid, {})


## Forgets one row's receipt - what the note's dismissal does, and what applying a second fix to the
## same row does before it writes its own.
static func forget(sheet_path: String, uid: String) -> void:
	_load()
	var per_sheet: Dictionary = _receipts.get(sheet_path, {})
	if per_sheet.erase(uid):
		_receipts[sheet_path] = per_sheet
		_save()


## THE sentence: what the fix on this row did, measured, or "" when the row carries no receipt.
## Three answers and no fourth - it worked, it did not, or nobody has run the game since.
static func reading(sheet_path: String, uid: String) -> String:
	var receipt: Dictionary = receipt_for(sheet_path, uid)
	if receipt.is_empty():
		return ""
	var after_when: String = EventSheetRunProfile.stored_when()
	if after_when.is_empty() or after_when == str(receipt.get("before_when", "")):
		return EventSheetL10n.translate("Fixed - run the game with the profiler to see whether it helped.")
	var before: float = float(receipt.get("before_ms", -1.0))
	var after: float = EventSheetRunProfile.ms_for(uid)
	if after < 0.0:
		return EventSheetL10n.translate("Fixed - the last run never measured this row, so there is nothing to compare.")
	if before < 0.0:
		return EventSheetL10n.translate("Fixed - it costs %.2f ms a fire now; there was no measurement before it to compare with.") % after
	if before - after >= before * MEANINGFUL_SHARE:
		return EventSheetL10n.translate("Fixed: %.2f -> %.2f ms a fire.") % [before, after]
	if after - before >= before * MEANINGFUL_SHARE:
		return EventSheetL10n.translate("This did not help: %.2f -> %.2f ms a fire. Put it back?") % [before, after]
	return EventSheetL10n.translate("This did not help: still %.2f ms a fire. Put it back?") % after


## True when the receipt has been measured against a later run AND the row got no faster - the one
## case the note offers a way back rather than a number to be pleased about.
static func disappointed(sheet_path: String, uid: String) -> bool:
	var receipt: Dictionary = receipt_for(sheet_path, uid)
	if receipt.is_empty():
		return false
	var after_when: String = EventSheetRunProfile.stored_when()
	if after_when.is_empty() or after_when == str(receipt.get("before_when", "")):
		return false
	var before: float = float(receipt.get("before_ms", -1.0))
	var after: float = EventSheetRunProfile.ms_for(uid)
	if before < 0.0 or after < 0.0:
		return false
	return before - after < before * MEANINGFUL_SHARE


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file: ConfigFile = ConfigFile.new()
	if file.load(STORE_PATH) != OK:
		return
	for sheet_path: String in file.get_sections():
		var per_sheet: Dictionary = {}
		for uid: String in file.get_section_keys(sheet_path):
			per_sheet[uid] = file.get_value(sheet_path, uid, {})
		_receipts[sheet_path] = per_sheet


static func _save() -> void:
	var file: ConfigFile = ConfigFile.new()
	for sheet_path: Variant in _receipts:
		for uid: Variant in _receipts[sheet_path] as Dictionary:
			file.set_value(str(sheet_path), str(uid), (_receipts[sheet_path] as Dictionary)[uid])
	file.save(STORE_PATH)


## Forgets every receipt, in memory and on disk - the reset a test needs between cases.
static func forget_all_for_test() -> void:
	_receipts.clear()
	_loaded = true
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(STORE_PATH)
