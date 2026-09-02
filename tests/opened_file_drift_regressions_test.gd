# EventForge - the two byte-drift shapes plugin_reads_itself_test found at birth, pinned at their roots.
#
# Both broke the lossless round-trip contract (open a .gd as a sheet, save untouched, byte-identical)
# without any lift being wrong:
#
#   1. The provider-declaration pass read a STRING LITERAL as a use-site: a hand-written file whose
#      string merely quoted `__eventsheet_provider_X.y()` gained an injected `var` declaration on
#      save. The pass now scans code text only (string contents blanked) and skips members the file
#      already declares itself - so an untouched opened file never gains a line, while a sheet whose
#      emitted code genuinely uses an undeclared provider member still gets its declaration.
#
#   2. The importer's trailing-blank trim popped the gap lines off a function block one at a time,
#      REVERSING the run - invisible while every gap line was empty, but a whitespace-only line (a
#      stray lone tab) swapped places with the empty line beside it. The trim now moves the run as a
#      slice in source order.
@tool
class_name OpenedFileDriftRegressionsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true

	# Shape 1a: the provider-member convention quoted inside a string literal is prose, not a
	# use-site - the file must round-trip without gaining a declaration.
	var quoted: String = "extends Node\n\nvar note: String = \"__eventsheet_provider_Score.add(1)\"\n\n\nfunc read_note() -> void:\n\tprint(note)\n"
	ok = _check("a string literal quoting the provider convention round-trips byte-identically",
		_recompile(quoted), quoted) and ok

	# Shape 1b: a file that genuinely uses a provider member AND declares it itself gets no duplicate.
	var self_declared: String = "extends Node\n\nvar __eventsheet_provider_Score := Score.new()\n\n\nfunc bump() -> void:\n\t__eventsheet_provider_Score.add(1)\n"
	ok = _check("a self-declared provider member round-trips byte-identically",
		_recompile(self_declared), self_declared) and ok

	# The positive control: a sheet whose emitted code uses an UNDECLARED provider member still gets
	# exactly one injected declaration (the dedup must never disarm the pass itself).
	var needs_declaration: EventSheetResource = EventSheetResource.new()
	needs_declaration.custom_class_name = "DriftFixture"
	var use_site: RawCodeRow = RawCodeRow.new()
	use_site.code = "func bump() -> void:\n\t__eventsheet_provider_Score.add(1)"
	needs_declaration.events.append(use_site)
	var generated: String = str(SheetCompiler.compile(needs_declaration, "user://_drift_regression_gen.gd").get("output", ""))
	ok = _check("an undeclared provider member still gets its declaration injected, exactly once",
		generated.count("var __eventsheet_provider_Score := Score.new()"), 1) and ok

	# Shape 2: a whitespace-only separator line (a lone tab) between two functions keeps its bytes
	# AND its place - the trailing-blank trim used to swap it with the empty line beside it.
	var tab_then_blank: String = "extends Node\n\n\nfunc first() -> void:\n\tpass\n\t\n\nfunc second() -> void:\n\tpass\n"
	ok = _check("a tab-only line then a blank between functions round-trips byte-identically",
		_recompile(tab_then_blank), tab_then_blank) and ok
	var blank_then_tab: String = "extends Node\n\n\nfunc first() -> void:\n\tpass\n\n\t\nfunc second() -> void:\n\tpass\n"
	ok = _check("a blank then a tab-only line between functions round-trips byte-identically",
		_recompile(blank_then_tab), blank_then_tab) and ok

	return ok


## Import the source as an opened external file, recompile untouched, and return the emitted text.
static func _recompile(source: String) -> String:
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	imported.external_source_path = "user://_drift_regression_rt.gd"
	return str(SheetCompiler.compile(imported, "user://_drift_regression_rt.gd").get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("opened_file_drift_regressions_test", label, actual, expected)
