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
## {"fields": Dictionary, "consumed": int} (consumed >= 1) - or, for a RESOURCE kind,
## {"resource": Resource, "consumed": int} carrying a ready row instance. The importer re-emits
## the recovered block and drops the claim unless the output matches the consumed lines
## byte-exactly, so a permissive lift can never corrupt a sheet - it just fails to lift.
func lift(_lines: PackedStringArray, _i: int) -> Dictionary:
	return {}

## One-line sheet display, rendered as text spans beside the kind badge.
func summary(_block: CustomBlockRow) -> String:
	return title

# ── Resource kinds: the plugin's OWN row classes on the same registry (dogfooding) ──
# A kind may operate on a dedicated Resource class instead of CustomBlockRow instances - the
# built-in enum rows work this way, so the registry is a real dispatch surface the plugin itself
# depends on, not just an extension point. Saved sheets and dedicated dialogs are untouched;
# only emit/lift/summary route through the kind.

## Return true for row instances this kind owns (e.g. `entry is EnumRow`). Kinds built on
## CustomBlockRow leave this false - the registry resolves those by kind_id instead.
func handles(_entry: Resource) -> bool:
	return false

## GDScript lines for ANY instance this kind handles. Resource kinds override this; schema
## kinds inherit the CustomBlockRow form so nothing changes for them.
func emit_lines(entry: Resource) -> PackedStringArray:
	return emit(entry as CustomBlockRow)

## One-line display for ANY handled instance (resource kinds override; schema kinds delegate).
func summary_for(entry: Resource) -> String:
	return summary(entry as CustomBlockRow)

## The source-map kind tag for emitted ranges ("enum", "custom_block", ...) so line-to-row
## tooling keeps its vocabulary when a built-in row class migrates onto the registry.
func source_map_kind() -> String:
	return "custom_block"

## Whether the generic add surfaces (Add menu, palette, schema dialog) offer this kind.
## Resource kinds return false - their row classes have dedicated add/edit flows already.
func addable() -> bool:
	return true

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
