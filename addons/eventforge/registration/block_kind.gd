# EventForge - the Custom Block API contract: one descriptor per registered row kind.
#
# ACEs answer "what can a row DO"; a block kind answers "what KINDS of rows exist" - the
# structural blocks between events (preloads, region markers, config blocks, pack-defined data
# blocks). Subclass this, register it (built-ins in EventSheetBlockRegistry; pack kinds are
# discovered from res://eventsheet_addons/ scripts), and every seam is wired generically:
# the compiler calls emit(), the importer probes lift() (byte-verify gated: your emit must
# reproduce the consumed source lines exactly or the claim is dropped and the lines stay a
# GDScript block), the viewport renders summary() as spans (never widgets), and the edit dialog
# is auto-built from fields().
#
# Descriptors are STATELESS singletons - per-row data lives only on CustomBlockRow.fields.
@tool
class_name EventSheetBlockKind
extends RefCounted

## Stable public id ("preload", "region", "my_pack.spawn_table"). Public API once shipped -
## the same compatibility covenant as ace_ids. Namespace pack-defined kinds with "<pack>.".
var kind_id: String = ""

## Display name for the badge/pill, the Add menu, and the edit dialog ("Preload Resource").
var title: String = ""

## Add-menu grouping.
var category: String = "Blocks"

## Field schema: each entry {id: String, label: String, type: Variant.Type, default: Variant}.
## Drives BOTH the generic edit dialog and defaults (read values with block.fields.get(id, default)).
func fields() -> Array[Dictionary]:
	return []

## Deterministic GDScript lines for this block. MUST be pure: same fields, same bytes - the
## round-trip covenant (and the importer's byte-verify) depend on it. Return [] to emit nothing.
func emit(_block: CustomBlockRow) -> PackedStringArray:
	return PackedStringArray()

## Try to claim source lines starting at index i. Return {} when the lines are not yours; else
## {"fields": Dictionary, "consumed": int} (consumed >= 1). The importer re-emits the recovered
## block and drops the claim unless the output matches the consumed lines byte-exactly, so a
## permissive lift can never corrupt a sheet - it just fails to lift.
func lift(_lines: PackedStringArray, _i: int) -> Dictionary:
	return {}

## One-line sheet display, rendered as text spans beside the kind badge.
func summary(_block: CustomBlockRow) -> String:
	return title

## A convenience for lift(): builds the fields Dictionary and verifies emit() reproduces the
## consumed lines byte-exactly, returning {} on mismatch. Kinds normally end lift() with this.
func verified_claim(recovered_fields: Dictionary, source_lines: PackedStringArray, i: int, consumed: int) -> Dictionary:
	var candidate: CustomBlockRow = CustomBlockRow.new()
	candidate.kind_id = kind_id
	candidate.fields = recovered_fields
	var emitted: PackedStringArray = emit(candidate)
	if emitted.size() != consumed:
		return {}
	for offset: int in range(consumed):
		if emitted[offset] != source_lines[i + offset]:
			return {}
	return {"fields": recovered_fields, "consumed": consumed}
