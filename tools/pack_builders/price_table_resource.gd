# Pack builder - price_table_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## PriceTableResource: a priced-interaction table - a shop's stock, an upgrade kiosk's tiers, a toll
## gate's fares, a skill tree's nodes - as ONE .tres data asset you fill in the Inspector. This is the
## data-driven half of the Priced Tables pack: instead of a wall of Add Entry actions, a designer edits
## one grid of id / label / price / currency / stock / unlocked / requires, saves the .tres, and the
## Priced Table behavior loads it in one step with Load Price Table. Variants (a second vendor, a hard
## mode price list) are other .tres files. A plain Resource (extends Resource), so it works with Godot's
## own Inspector and file system with no plugin at runtime.
##
## Because Inspector table cells hold scalars (a cell cannot nest an array), everything an entry needs
## lives in ONE row - the same table-drawer shape LootTableResource and QuestResource use.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "PriceTableResource"
	sheet.addon_version = "1.0.0"
	sheet.class_description = "A priced-interaction table as a data asset: what is for sale, what it costs, in which currency, how many are left, and whether it is unlocked yet. Load it into a Priced Table behavior with Load Price Table - the data-driven alternative to building a shop out of actions."
	sheet.addon_category = "Priced Tables"
	sheet.addon_tags = PackedStringArray(["shop", "economy", "resource"])
	sheet.variables = {
		"entries": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Entries",
				"tooltip": "One row per thing for sale: id, label, price and currency.",
				"drawer": "table", "table_columns": [
					{"name": "id", "type": "String"},
					{"name": "label", "type": "String"},
					{"name": "price", "type": "float"},
					{"name": "currency", "type": "String"},
					{"name": "stock", "type": "int"},
					{"name": "locked", "type": "bool"},
					{"name": "requires", "type": "String"}]}},
		"default_currency": {"type": "String", "default": "gold", "exported": true,
			"attributes": {"group": "Identity",
				"tooltip": "The currency id used by any entry that leaves its own currency cell blank - so a single-currency shop only fills it in once."}},
		"table_name": {"type": "String", "default": "shop", "exported": true,
			"attributes": {"group": "Identity",
				"tooltip": "A readable name for this table (\"Blacksmith\", \"Tier 2 upgrades\"), read back with the Table Name expression for a shop window's title."}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/price_table_resource/price_table_resource")
