## @ace_tags(shop, economy, purchase, unlock)
## @ace_category("Priced Tables")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/priced_table/icon.svg")
class_name PricedTableBehavior
extends Node
## The priced-interaction table, worn by the thing that sells: a vendor, an upgrade kiosk, a toll gate, a skill tree. Load a PriceTableResource (.tres) of entries - id, label, price, currency, stock, locked, requires - and Buy Entry runs the whole transaction (unlocked? in stock? affordable?), takes the money through whatever wallet answers, and fires On Purchased or On Purchase Refused with the reason.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("PricedTableBehavior behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On Purchased")
## @ace_category("Priced Tables")
signal on_purchased(entry_id: String, price: float)
## @ace_trigger
## @ace_name("On Purchase Refused")
## @ace_category("Priced Tables")
signal on_purchase_refused(entry_id: String, reason: String)

## Optional: drop a PriceTableResource (.tres) here to load its entries on ready - the data-driven way to stock a table without events. You can also load one later (or a different one) with Load Price Table.
@export var price_table: Resource = null
## The group this table looks in for a wallet node before it tries the CurrencyLedger autoload. Any node in the group that has a balance(currency) and a spend(currency, amount) function qualifies - that is the whole contract, so your own purse works too.
@export var wallet_group: String = "wallet"
## The fallback purse, used ONLY when no wallet node and no CurrencyLedger autoload answer. It is one number for every currency (this table's own money), which is enough for a prototype or a single-shop game; install a shared wallet the moment you have two tables.
@export var local_wallet: float = 0.0

# The live table: one record per entry in the order the table lists them, plus an id index into
# the SAME dictionaries (a Dictionary is a reference, so a write through either is seen by both).
# A record is {id, label, price, currency, stock, initial_stock, unlocked, requires}, where a
# stock of -1 means unlimited and 0 means sold out.
var _entries: Array = []
var _by_id: Dictionary = {}
var _table_name: String = ""
var _default_currency: String = "gold"
# Last-transaction context, carried by the triggers and readable afterwards with the Last / Refused
# expressions (for a receipt line that outlives the handler).
var _last_id: String = ""
var _last_price: float = 0.0
var _last_currency: String = ""
var _refused_id: String = ""
var _refused_reason: String = ""
# An explicit wallet handed over by Use Wallet Node, tried before any search.
var _wallet_node: Node = null
# The wallet seam. This pack owns no economy: it asks whatever is there, in this order - the node
# Use Wallet Node handed it, then the wallet group, then the CurrencyLedger autoload - and any node
# with balance(currency) and spend(currency, amount) qualifies. The shipped Currency Ledger has
# exactly that pair, and so can a purse you write yourself. A candidate missing either function is
# skipped rather than called blindly, and nothing here references another pack's class, so the
# table works with all of them installed or none of them.
func _wallet() -> Node:
	if _wallet_node != null and is_instance_valid(_wallet_node) and _wallet_node.has_method("balance") and _wallet_node.has_method("spend"):
		return _wallet_node
	if not is_inside_tree() or get_tree() == null:
		return null
	for member: Node in get_tree().get_nodes_in_group(wallet_group):
		if member.has_method("balance") and member.has_method("spend"):
			return member
	var ledger: Node = get_node_or_null("/root/CurrencyLedger")
	if ledger != null and ledger.has_method("balance") and ledger.has_method("spend"):
		return ledger
	return null

func _ready() -> void:
	if price_table != null:
		load_price_table(price_table)

## @ace_action
## @ace_featured
## @ace_name("Load Price Table")
## @ace_category("Priced Tables")
## @ace_description("Stocks this table from a PriceTableResource (.tres) - every entry with its price, currency, stock, locked flag and requirement note - in one step instead of a wall of Add Entry actions. Entries that share an id with one already stocked are REPLACED (so loading a second table re-prices rather than duplicating); ids it has never seen are appended.")
## @ace_display_template("Load price table [b]{table}[/b]")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.load_price_table({table})")
func load_price_table(table: Resource) -> void:
	if table == null:
		return
	var raw_name: Variant = table.get("table_name")
	_table_name = str(raw_name) if raw_name != null else ""
	var raw_currency: Variant = table.get("default_currency")
	if raw_currency != null and not str(raw_currency).is_empty():
		_default_currency = str(raw_currency)
	for row: Dictionary in _rows(table, "entries"):
		var entry_id: String = str(_cell(row, "id", ""))
		if entry_id.is_empty():
			continue
		var currency: String = str(_cell(row, "currency", ""))
		var stock: int = int(_num(_cell(row, "stock", -1)))
		_put({
			"id": entry_id,
			"label": str(_cell(row, "label", "")),
			"price": maxf(_num(_cell(row, "price", 0.0)), 0.0),
			"currency": currency if not currency.is_empty() else _default_currency,
			"stock": stock,
			"initial_stock": stock,
			"unlocked": not bool(_cell(row, "locked", false)),
			"requires": str(_cell(row, "requires", ""))
		})

## @ace_action
## @ace_name("Add Entry")
## @ace_category("Priced Tables")
## @ace_description("Adds (or replaces) one entry from a sheet, for a table built at runtime - a shop whose stock is rolled per visit, a skill tree grown as the player levels. A stock of -1 is unlimited; the entry starts unlocked with no requirement note (set those with Set Entry Unlocked and the resource's requires column).")
## @ace_display_template("Add entry [b]{entry_id}[/b] ([b]{label}[/b]) at [b]{price}[/b] [b]{currency}[/b], stock [b]{stock}[/b]")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.add_entry({entry_id}, {label}, {price}, {currency}, {stock})")
func add_entry(entry_id: String, label: String, price: float, currency: String, stock: int) -> void:
	if entry_id.is_empty():
		return
	_put({
		"id": entry_id,
		"label": label,
		"price": maxf(price, 0.0),
		"currency": currency if not currency.is_empty() else _default_currency,
		"stock": stock,
		"initial_stock": stock,
		"unlocked": true,
		"requires": ""
	})

## @ace_action
## @ace_name("Clear Table")
## @ace_category("Priced Tables")
## @ace_description("Empties the table - every entry, price and stock count. Use it before loading a different table when you do NOT want the two merged by id.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.clear_table()")
func clear_table() -> void:
	_entries.clear()
	_by_id.clear()

## @ace_action
## @ace_featured
## @ace_name("Buy Entry")
## @ace_category("Priced Tables")
## @ace_description("The whole purchase in one row: refuses (firing On Purchase Refused with a reason) when the id is unknown, the entry is locked, its stock is 0, or the wallet cannot cover the price; otherwise it takes the price through whatever wallet answers, counts the stock down by one, and fires On Purchased with the id and what was paid. Hand over the goods in On Purchased - the pack never guesses what an entry means.")
## @ace_display_template("Buy [b]{entry_id}[/b]")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.buy({entry_id})")
func buy(entry_id: String) -> void:
	var record: Dictionary = _by_id.get(entry_id, {})
	if record.is_empty():
		_refuse(entry_id, "unknown entry")
		return
	if not bool(record.unlocked):
		_refuse(entry_id, "locked")
		return
	if int(record.stock) == 0:
		_refuse(entry_id, "out of stock")
		return
	var price: float = float(record.price)
	var currency: String = str(record.currency)
	if _balance_of(currency) < price:
		_refuse(entry_id, "too expensive")
		return
	_take(currency, price)
	if int(record.stock) > 0:
		record.stock = int(record.stock) - 1
	_last_id = entry_id
	_last_price = price
	_last_currency = currency
	on_purchased.emit(entry_id, price)

## @ace_action
## @ace_name("Restock Entry")
## @ace_category("Priced Tables")
## @ace_description("Adds to one entry's remaining stock (a delivery, a daily refill). An unlimited entry (-1) is left alone, and stock never falls below 0.")
## @ace_display_template("Restock [b]{entry_id}[/b] by [b]{amount}[/b]")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.restock({entry_id}, {amount})")
func restock(entry_id: String, amount: int) -> void:
	var record: Dictionary = _by_id.get(entry_id, {})
	if record.is_empty() or int(record.stock) < 0:
		return
	record.stock = maxi(int(record.stock) + amount, 0)

## @ace_action
## @ace_name("Restock All")
## @ace_category("Priced Tables")
## @ace_description("Puts every entry back to the stock its table shipped with - the one row behind "the shop restocks each morning". Prices, locks and requirement notes are untouched.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.restock_all()")
func restock_all() -> void:
	for record: Dictionary in _entries:
		record.stock = int(record.initial_stock)

## @ace_action
## @ace_name("Set Stock")
## @ace_category("Priced Tables")
## @ace_description("Forces one entry's remaining stock to an exact number. -1 makes it unlimited, 0 sells it out.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.set_stock({entry_id}, {stock})")
func set_stock(entry_id: String, stock: int) -> void:
	var record: Dictionary = _by_id.get(entry_id, {})
	if not record.is_empty():
		record.stock = stock

## @ace_action
## @ace_name("Set Price")
## @ace_category("Priced Tables")
## @ace_description("Re-prices one entry while the game runs - a sale, a haggle, a reputation discount. Negative prices are clamped to 0 (a free entry still goes through the whole purchase, so its trigger still fires).")
## @ace_display_template("Set price of [b]{entry_id}[/b] to [b]{price}[/b]")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.set_price({entry_id}, {price})")
func set_price(entry_id: String, price: float) -> void:
	var record: Dictionary = _by_id.get(entry_id, {})
	if not record.is_empty():
		record.price = maxf(price, 0.0)

## @ace_action
## @ace_name("Set Entry Unlocked")
## @ace_category("Priced Tables")
## @ace_description("Opens (or closes) one entry. A locked entry still shows in the table - Entry Is Unlocked greys it out in your UI, and buying it is refused with the reason "locked" - which is how a tier gate, a skill-tree prerequisite or a story unlock is expressed without deleting the row.")
## @ace_display_template("Set [b]{entry_id}[/b] unlocked to [b]{unlocked}[/b]")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.set_unlocked({entry_id}, {unlocked})")
func set_unlocked(entry_id: String, unlocked: bool) -> void:
	var record: Dictionary = _by_id.get(entry_id, {})
	if not record.is_empty():
		record.unlocked = unlocked

## @ace_action
## @ace_name("Use Wallet Node")
## @ace_category("Priced Tables")
## @ace_description("Points this table at ONE wallet node, tried before anything else - the direct way when the purse is already in hand (the player's own wallet node, a shared bank, a per-faction till). The contract is two functions, balance(currency) and spend(currency, amount); a node missing either is ignored, so a wrong drag can never silently swallow the money. Pass nothing to go back to searching the wallet group and then the CurrencyLedger autoload.")
## @ace_display_template("Use wallet node [i]{node}[/i]")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.use_wallet_node({node})")
func use_wallet_node(node: Node) -> void:
	_wallet_node = node

## @ace_action
## @ace_name("Set Local Wallet")
## @ace_category("Priced Tables")
## @ace_description("Sets the fallback purse - the number this table spends from when no wallet node and no CurrencyLedger autoload answer. It is deliberately the ONLY money action here: as soon as your game has a real economy, install one and this number stops being consulted.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.set_local_wallet({amount})")
func set_local_wallet(amount: float) -> void:
	local_wallet = amount

## @ace_condition
## @ace_name("Can Afford Entry")
## @ace_category("Priced Tables")
## @ace_description("True when the wallet covers this entry's price right now - the condition that greys out a shop button before the player clicks it. Reads through the same seam the purchase uses, so it can never disagree with Buy Entry.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.can_afford_entry({entry_id})")
func can_afford_entry(entry_id: String) -> bool:
	var record: Dictionary = _by_id.get(entry_id, {})
	return not record.is_empty() and _balance_of(str(record.currency)) >= float(record.price)

## @ace_condition
## @ace_name("Entry In Stock")
## @ace_category("Priced Tables")
## @ace_description("True while the entry has something left to sell. An unlimited entry (-1) is always in stock; an unknown id never is.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.entry_in_stock({entry_id})")
func entry_in_stock(entry_id: String) -> bool:
	var record: Dictionary = _by_id.get(entry_id, {})
	return not record.is_empty() and int(record.stock) != 0

## @ace_condition
## @ace_name("Entry Is Unlocked")
## @ace_category("Priced Tables")
## @ace_description("True when the entry is open for business - the gate behind a tier, a prerequisite or a story beat.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.entry_is_unlocked({entry_id})")
func entry_is_unlocked(entry_id: String) -> bool:
	var record: Dictionary = _by_id.get(entry_id, {})
	return not record.is_empty() and bool(record.unlocked)

## @ace_condition
## @ace_name("Has Entry")
## @ace_category("Priced Tables")
## @ace_description("Whether the table holds an entry with this id at all - the guard that tells a typo apart from a sold-out row.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.has_entry({entry_id})")
func has_entry(entry_id: String) -> bool:
	return _by_id.has(entry_id)

## @ace_condition
## @ace_name("Table Is Sold Out")
## @ace_category("Priced Tables")
## @ace_description("True when nothing in the table can be bought any more: every entry is either at 0 stock or locked. An empty table counts as sold out.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.is_sold_out()")
func is_sold_out() -> bool:
	for record: Dictionary in _entries:
		if int(record.stock) != 0 and bool(record.unlocked):
			return false
	return true

## @ace_expression
## @ace_name("Price Of")
## @ace_category("Priced Tables")
## @ace_description("What one entry costs (-1 when the table has no such id, so a missing price never reads as free).")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.price_of({entry_id})")
func price_of(entry_id: String) -> float:
	return float(_by_id[entry_id].price) if _by_id.has(entry_id) else -1.0

## @ace_expression
## @ace_name("Stock Of")
## @ace_category("Priced Tables")
## @ace_description("How many of one entry are left: -1 for unlimited, 0 for sold out (which is also what an unknown id reads).")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.stock_of({entry_id})")
func stock_of(entry_id: String) -> int:
	return int(_by_id[entry_id].stock) if _by_id.has(entry_id) else 0

## @ace_expression
## @ace_name("Currency Of")
## @ace_category("Priced Tables")
## @ace_description("The currency id one entry is priced in - pass it to your wallet's own expressions to show the right icon.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.currency_of({entry_id})")
func currency_of(entry_id: String) -> String:
	return str(_by_id[entry_id].currency) if _by_id.has(entry_id) else ""

## @ace_expression
## @ace_name("Label Of")
## @ace_category("Priced Tables")
## @ace_description("The player-facing name of one entry ("Iron Sword"), for the shop row's text.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.label_of({entry_id})")
func label_of(entry_id: String) -> String:
	return str(_by_id[entry_id].label) if _by_id.has(entry_id) else ""

## @ace_expression
## @ace_name("Requirement Of")
## @ace_category("Priced Tables")
## @ace_description("The plain-language requirement note written on one entry ("needs the guild badge"), for the tooltip on a locked row. The pack never interprets it - YOUR game decides when to call Set Entry Unlocked.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.requirement_of({entry_id})")
func requirement_of(entry_id: String) -> String:
	return str(_by_id[entry_id].requires) if _by_id.has(entry_id) else ""

## @ace_expression
## @ace_name("Entry Count")
## @ace_category("Priced Tables")
## @ace_description("How many entries the table holds - the row count for a shop list.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.entry_count()")
func entry_count() -> int:
	return _entries.size()

## @ace_expression
## @ace_name("Entry Id At")
## @ace_category("Priced Tables")
## @ace_description("The entry id at a position, in table order ("" out of range) - walk 0..Entry Count to build the shop UI.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.entry_id_at({index})")
func entry_id_at(index: int) -> String:
	return str(_entries[index].id) if index >= 0 and index < _entries.size() else ""

## @ace_expression
## @ace_name("Table Name")
## @ace_category("Priced Tables")
## @ace_description("The readable name written on the loaded table resource ("Blacksmith") - the shop window's title.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.table_title()")
func table_title() -> String:
	return _table_name

## @ace_expression
## @ace_name("Wallet Balance")
## @ace_category("Priced Tables")
## @ace_description("What the buyer can spend of one currency, read through the same seam a purchase uses: the node given to Use Wallet Node, else a wallet node in the wallet group, else the CurrencyLedger autoload, else this table's Local Wallet number (which is currency-blind).")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.wallet_balance({currency})")
func wallet_balance(currency: String) -> float:
	return _balance_of(currency)

## @ace_expression
## @ace_name("Last Purchased Id")
## @ace_category("Priced Tables")
## @ace_description("The entry bought most recently ("" before the first one) - readable long after On Purchased, for a receipt line.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.last_purchased_id()")
func last_purchased_id() -> String:
	return _last_id

## @ace_expression
## @ace_name("Last Price Paid")
## @ace_category("Priced Tables")
## @ace_description("What the last purchase actually cost - the number to show in "-25 gold" feedback.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.last_price_paid()")
func last_price_paid() -> float:
	return _last_price

## @ace_expression
## @ace_name("Last Currency Paid")
## @ace_category("Priced Tables")
## @ace_description("The currency the last purchase was paid in.")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.last_currency_paid()")
func last_currency_paid() -> String:
	return _last_currency

## @ace_expression
## @ace_name("Refused Entry Id")
## @ace_category("Priced Tables")
## @ace_description("The entry of the most recent refusal ("" if none yet).")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.refused_entry_id()")
func refused_entry_id() -> String:
	return _refused_id

## @ace_expression
## @ace_name("Refused Reason")
## @ace_category("Priced Tables")
## @ace_description("Why the most recent purchase was refused, as plain words you can show: "unknown entry", "locked", "out of stock" or "too expensive".")
## @ace_icon("res://eventsheet_addons/priced_table/icon.svg")
## @ace_codegen_template("$PricedTableBehavior.refused_reason()")
func refused_reason() -> String:
	return _refused_reason

func _balance_of(currency: String) -> float:
	# What the buyer can spend of one currency right now. With no wallet answering, the fallback purse
	# is currency-blind on purpose - it is a single number, not an economy.
	var wallet: Node = _wallet()
	if wallet != null:
		return float(wallet.call("balance", currency))
	return local_wallet

func _take(currency: String, amount: float) -> void:
	# Takes the price. Only ever called once the balance has already covered it.
	var wallet: Node = _wallet()
	if wallet != null:
		wallet.call("spend", currency, amount)
		return
	local_wallet -= amount

func _refuse(entry_id: String, reason: String) -> void:
	# Records why a purchase did not happen and fires the trigger. Every refusal goes through here,
	# so the reason string and On Purchase Refused can never disagree.
	_refused_id = entry_id
	_refused_reason = reason
	on_purchase_refused.emit(entry_id, reason)

func _rows(source: Variant, field: String) -> Array:
	# A grid off a PriceTableResource (a property). Returns an Array of row dicts; a stray
	# non-Dictionary element (a hand-edited .tres) is dropped rather than crashing the typed loops.
	var raw: Variant = source.get(field)
	if not raw is Array:
		return []
	var out: Array = []
	for element: Variant in raw:
		if element is Dictionary:
			out.append(element)
	return out

func _cell(row: Dictionary, key: String, fallback: Variant) -> Variant:
	# One cell off a row, treating a PRESENT-but-null value as missing so the default still applies
	# (Dictionary.get only falls back when the key is ABSENT).
	var value: Variant = row.get(key, fallback)
	return fallback if value == null else value

func _num(value: Variant) -> float:
	if value is float or value is int:
		return float(value)
	if value is String and (value as String).is_valid_float():
		return (value as String).to_float()
	return 0.0

func _put(record: Dictionary) -> void:
	# Registers one record, replacing any entry that already had this id (so a second Load Price
	# Table re-prices rather than duplicating) and keeping the table's original order. The position
	# is found by id rather than by comparing the dictionaries, which is what keeps this honest
	# whichever way the engine defines Dictionary equality.
	var entry_id: String = str(record.id)
	var at: int = -1
	var index: int = 0
	for existing: Dictionary in _entries:
		if str(existing.id) == entry_id:
			at = index
			break
		index += 1
	if at >= 0:
		_entries[at] = record
	else:
		_entries.append(record)
	_by_id[entry_id] = record

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	# The whole table travels, so a shop reopens with the stock it was left with - and the
	# id index is rebuilt from the restored records rather than saved twice.
	return {
		"entries": _entries.duplicate(true),
		"table_name": _table_name,
		"default_currency": _default_currency,
		"local_wallet": local_wallet
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_entries = (state.get("entries", []) as Array).duplicate(true)
	_table_name = str(state.get("table_name", ""))
	_default_currency = str(state.get("default_currency", "gold"))
	local_wallet = float(state.get("local_wallet", 0.0))
	_by_id.clear()
	for record: Dictionary in _entries:
		_by_id[str(record.id)] = record

# Priced Table behavior: attach it to the thing that sells (a vendor, a kiosk, a toll gate) and drop a Price Table resource (.tres) on its slot. Buy Entry checks unlocked / in stock / affordable, takes the money through whatever wallet answers (a node in the wallet group, then the CurrencyLedger autoload, then this table's own Local Wallet number), decrements the stock, and fires On Purchased or On Purchase Refused with the reason. Pair it with the Interaction pack by convention: focus the vendor, press the key, buy the focused entry. This pack is an event sheet - extend it by editing it.
