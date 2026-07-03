# EventForge - a registered custom block instance (the Custom Block API's one row resource).
#
# ONE generic resource for every registered block kind (preloads, region markers, pack-defined
# blocks...), not one class per kind: sheets stay loadable when a kind's descriptor is absent
# (the emitted lines simply do not lift and remain a readable GDScript block), the undo
# snapshot funnel duplicates it like any other row, and the sheet formats never learn new class
# names. The kind's field schema, GDScript emission, and display live on the registered
# EventSheetBlockKind (see registration/block_registry.gd); this resource only stores which
# kind it is and the field values.
@tool
class_name CustomBlockRow
extends Resource

## Which registered kind this block is (EventSheetBlockRegistry.get_kind). Public API once a
## kind ships - the same compatibility covenant as ace_ids.
@export var kind_id: String = ""

## Field id -> value, per the kind's fields() schema. Read with fields.get(id, default) so
## instances saved before a kind gained a field keep working.
@export var fields: Dictionary = {}

@export var enabled: bool = true
