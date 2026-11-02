# Godot EventSheets - the Doctor's Compiler section.
#
# The compiler returns warnings beside every script it writes, and until now only the MCP server read
# them. This section lists, in the Doctor's triage inbox, the warnings the sheets written in this
# editor session produced the last time they were saved - the same sentences the status line counts
# after a save and the rows' help strips say once selected, so a reader meets one wording wherever the
# problem turns up.
#
# WHAT IT READS. The record the editor keeps of each sheet's last write (EventSheetCompileFindings),
# not a fresh compile of every sheet in the project: compiling a whole project's sheets to audit it
# would make the Doctor as slow as opening every one of them, and the words are no better for it. So a
# sheet nobody saved this session earns nothing, and the headless runners (CLI, CI) - which write no
# sheets - report nothing here. It registers through the seam a pack uses, like every extension check.
@tool
class_name EventSheetCompilerWarningsDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the id its findings are filed as.
const CHECK_ID := "compiler_warnings"


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheetProjectDoctor.register_check(CHECK_ID, Callable(EventSheetCompilerWarningsDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(EventSheetCompileFindings.recorded_paths()))


## The whole section as findings for the given sheet files. Pure over the record, so a test can hand
## it a corpus of one. Empty when no listed file has a warning on record.
static func report(paths: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var total: int = 0
	var first_path: String = ""
	for path: String in paths:
		var warnings: Array = EventSheetCompileFindings.warnings_at(path)
		if warnings.is_empty():
			continue
		if first_path.is_empty():
			first_path = path
		total += warnings.size()
		for warning: Variant in warnings:
			findings.append(_finding("warning", CHECK_ID, path, "%s %s" % [path.get_file(), str(warning)], ""))
	if total > 0:
		findings.insert(0, _finding("info", CHECK_ID, first_path,
			"Compiler: %d warning(s) from the last save of %d sheet(s)." % [total, _count_files(findings)], ""))
	return findings


static func _count_files(findings: Array[Dictionary]) -> int:
	var seen: Dictionary = {}
	for finding: Dictionary in findings:
		seen[str(finding.get("path", ""))] = true
	return seen.size()
