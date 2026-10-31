## @ace_tags(shop, economy, resource)
## @ace_category("Priced Tables")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/price_table_resource/icon.svg")
class_name PriceTableResource
extends Resource
## A priced-interaction table as a data asset: what is for sale, what it costs, in which currency, how many are left, and whether it is unlocked yet. Load it into a Priced Table behavior with Load Price Table - the data-driven alternative to building a shop out of actions.

## One row per thing for sale: id, label, price and currency.
@export_group("Entries")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:id=String,label=String,price=float,currency=String,stock=int,locked=bool,requires=String") var entries: Array = []
## The currency id used by any entry that leaves its own currency cell blank - so a single-currency shop only fills it in once.
@export_group("Identity")
@export var default_currency: String = "gold"
## A readable name for this table ("Blacksmith", "Tier 2 upgrades"), read back with the Table Name expression for a shop window's title.
@export var table_name: String = "shop"
