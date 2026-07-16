# EventForge - drop-in translations reload LIVE: dropping a CSV into a scan folder makes its locale
# pickable via reload_if_changed() (the dock calls it on the editor's filesystem-changed ping), an
# unchanged folder is a cheap no-op false, and removing the ACTIVE language's file falls back to
# English instead of dangling. Uses a throwaway "xx" locale in the project-local scan folder
# (res://eventsheet_translations/) and cleans up after itself.
@tool
class_name L10nDropinReloadTest
extends RefCounted

const DROP_DIR := "res://eventsheet_translations"
const DROP_FILE := DROP_DIR + "/xx_dropin_test.csv"


static func run() -> bool:
	var ok: bool = true
	var made_dir: bool = not DirAccess.dir_exists_absolute(DROP_DIR)

	EventSheetL10n.ensure_loaded()
	var before_locale: String = EventSheetL10n.get_locale()
	ok = _check(ok, not EventSheetL10n.available_locales().has("xx"), "throwaway locale absent before the drop")
	ok = _check(ok, not EventSheetL10n.reload_if_changed(), "unchanged folders are a no-op (false)")

	# ---- drop a CSV in -> its locale appears and translates ----
	if made_dir:
		DirAccess.make_dir_recursive_absolute(DROP_DIR)
	var file: FileAccess = FileAccess.open(DROP_FILE, FileAccess.WRITE)
	file.store_string("keys,xx\nSave,XxSaveXx\n")
	file.close()
	ok = _check(ok, EventSheetL10n.reload_if_changed(), "a dropped CSV reports a reload (true)")
	ok = _check(ok, EventSheetL10n.available_locales().has("xx"), "the dropped locale is now pickable")
	EventSheetL10n.set_locale("xx")
	var translated: String = EventSheetL10n.translate("Save")
	ok = _check(ok, translated == "XxSaveXx", "the dropped catalog translates (got %s)" % translated)

	# ---- remove the active language's file -> clean English fallback ----
	DirAccess.remove_absolute(DROP_FILE)
	ok = _check(ok, EventSheetL10n.reload_if_changed(), "a removed CSV reports a reload (true)")
	ok = _check(ok, not EventSheetL10n.available_locales().has("xx"), "the removed locale is gone")
	var fallback: String = EventSheetL10n.get_locale()
	ok = _check(ok, fallback == "en", "removing the active language falls back to en (got %s)" % fallback)
	ok = _check(ok, EventSheetL10n.translate("Save") == "Save", "translate passes through after the fallback")

	# ---- restore the pre-test world ----
	if made_dir:
		DirAccess.remove_absolute(DROP_DIR)
	EventSheetL10n.set_locale(before_locale)
	return ok


static func _check(ok: bool, condition: bool, label: String) -> bool:
	if not condition:
		print("  [FAIL] ", label)
	return ok and condition
