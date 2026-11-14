# Pack builder - priced_table (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Priced Table: the general priced-interaction table, worn by the thing that sells - a vendor, an
## upgrade kiosk, a toll gate, a skill tree, an unlock wall. Attach it to that node, drop a
## PriceTableResource (.tres) on its slot, and every entry answers the same four questions: what is it
## called, what does it cost, how many are left, and is it open yet. Buy Entry does the whole
## transaction - unlocked? in stock? affordable? - then takes the money, decrements the stock, and fires
## On Purchased or On Purchase Refused with the reason.
##
## The wallet is DECOUPLED on purpose: this pack holds no economy of its own. It asks, in order, a node
## in its wallet group that answers balance()/spend(), then the CurrencyLedger autoload if one is
## registered, and only then falls back to its own exported number - so it works with the shipped
## Currency Ledger, with your own wallet node, or with nothing at all, and never depends on any of them.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "PricedTableBehavior"
	sheet.class_description = "The priced-interaction table, worn by the thing that sells: a vendor, an upgrade kiosk, a toll gate, a skill tree. Load a PriceTableResource (.tres) of entries - id, label, price, currency, stock, locked, requires - and Buy Entry runs the whole transaction (unlocked? in stock? affordable?), takes the money through whatever wallet answers, and fires On Purchased or On Purchase Refused with the reason."
	sheet.addon_category = "Priced Tables"
	sheet.addon_tags = PackedStringArray(["shop", "economy", "purchase", "unlock"])
	sheet.variables = {
		"local_wallet": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Fallback balance used when no wallet node or ledger answers."}},
		"price_table": {"type": "Resource", "default": null, "exported": true,
			"attributes": {"tooltip": "Price table resource to load on ready; empty stocks the table with events."}},
		"wallet_group": {"type": "String", "default": "wallet", "exported": true,
			"attributes": {"tooltip": "Group searched for a wallet node before using the ledger autoload."}}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Priced Table behavior: attach it to the thing that sells (a vendor, a kiosk, a toll gate) and drop a Price Table resource (.tres) on its slot. Buy Entry checks unlocked / in stock / affordable, takes the money through whatever wallet answers (a node in the wallet group, then the CurrencyLedger autoload, then this table's own Local Wallet number), decrements the stock, and fires On Purchased or On Purchase Refused with the reason. Pair it with the Interaction pack by convention: focus the vendor, press the key, buy the focused entry. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var purchased: SignalRow = SignalRow.new()
	purchased.signal_name = "on_purchased"
	purchased.params = PackedStringArray(["entry_id: String", "price: float"])
	purchased.trigger = true
	purchased.ace_name = "On Purchased"
	purchased.ace_category = "Priced Tables"
	sheet.events.append(purchased)

	var refused: SignalRow = SignalRow.new()
	refused.signal_name = "on_purchase_refused"
	refused.params = PackedStringArray(["entry_id: String", "reason: String"])
	refused.trigger = true
	refused.ace_name = "On Purchase Refused"
	refused.ace_category = "Priced Tables"
	sheet.events.append(refused)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## One entry of the table: what it is, what it costs and how many are left.",
		"class PriceEntry extends RefCounted:",
		"\t## The id rows buy it by.",
		"\tvar id: String = \"\"",
		"\t## The name the game shows.",
		"\tvar label: String = \"\"",
		"\t## What one costs, never below 0.",
		"\tvar price: float = 0.0",
		"\t## The currency it is paid in.",
		"\tvar currency: String = \"gold\"",
		"\t## How many are left: -1 is unlimited, 0 is sold out.",
		"\tvar stock: int = -1",
		"\t## The stock the table shipped with, which Restock All goes back to.",
		"\tvar initial_stock: int = -1",
		"\t## False while a tier or a story gate keeps it closed.",
		"\tvar unlocked: bool = true",
		"\t## A free note saying what it needs, for the game's own UI.",
		"\tvar requires: String = \"\"",
		"",
		"\t# The entry as a saved state holds it. The keys are the file's spelling and never change.",
		"\tfunc to_dict() -> Dictionary:",
		"\t\treturn {\"id\": id, \"label\": label, \"price\": price, \"currency\": currency, \"stock\": stock,",
		"\t\t\t\"initial_stock\": initial_stock, \"unlocked\": unlocked, \"requires\": requires}",
		"",
		"\t# An entry read back from a saved state; a missing key reads as the field's default.",
		"\tstatic func from_dict(data: Dictionary) -> PriceEntry:",
		"\t\tvar entry: PriceEntry = PriceEntry.new()",
		"\t\tentry.id = str(data.get(\"id\", \"\"))",
		"\t\tentry.label = str(data.get(\"label\", \"\"))",
		"\t\tentry.price = float(data.get(\"price\", 0.0))",
		"\t\tentry.currency = str(data.get(\"currency\", \"gold\"))",
		"\t\tentry.stock = int(data.get(\"stock\", -1))",
		"\t\tentry.initial_stock = int(data.get(\"initial_stock\", entry.stock))",
		"\t\tentry.unlocked = bool(data.get(\"unlocked\", true))",
		"\t\tentry.requires = str(data.get(\"requires\", \"\"))",
		"\t\treturn entry",
		"",
		"# The live table: one entry per row in the order the table lists them, plus an id index into the",
		"# SAME entries (an object is a reference, so a write through either is seen by both).",
		"## Items loaded from the price table, each with its price and stock.",
		"var _entries: Array[PriceEntry] = []",
		"## Items looked up by id.",
		"var _by_id: Dictionary[String, PriceEntry] = {}",
		"## Name of the price table that is loaded.",
		"var _table_name: String = \"\"",
		"## Currency used by an entry that does not name one.",
		"var _default_currency: String = \"gold\"",
		"# Last-transaction context, carried by the triggers and readable afterwards with the Last / Refused",
		"# expressions (for a receipt line that outlives the handler).",
		"## Id of the item looked up most recently.",
		"var _last_id: String = \"\"",
		"## Price of the item looked up most recently.",
		"var _last_price: float = 0.0",
		"## Currency of the item looked up most recently.",
		"var _last_currency: String = \"\"",
		"## Id of the item whose purchase was refused.",
		"var _refused_id: String = \"\"",
		"## Why that purchase was refused, as a word.",
		"var _refused_reason: String = \"\"",
		"# An explicit wallet handed over by Use Wallet Node, tried before any search.",
		"## The wallet node purchases are charged to.",
		"var _wallet_node: Node = null",
		"",
		"# The wallet seam. This pack owns no economy: it asks whatever is there, in this order - the node",
		"# Use Wallet Node handed it, then the wallet group, then the CurrencyLedger autoload - and any node",
		"# with balance(currency) and spend(currency, amount) qualifies. The shipped Currency Ledger has",
		"# exactly that pair, and so can a purse you write yourself. A candidate missing either function is",
		"# skipped rather than called blindly, and nothing here references another pack's class, so the",
		"# table works with all of them installed or none of them.",
		"func _wallet() -> Node:",
		"\tif _wallet_node != null and is_instance_valid(_wallet_node) and _wallet_node.has_method(\"balance\") and _wallet_node.has_method(\"spend\"):",
		"\t\treturn _wallet_node",
		"\tif not is_inside_tree() or get_tree() == null:",
		"\t\treturn null",
		"\tfor member: Node in get_tree().get_nodes_in_group(wallet_group):",
		"\t\tif member.has_method(\"balance\") and member.has_method(\"spend\"):",
		"\t\t\treturn member",
		"\tvar ledger: Node = get_node_or_null(\"/root/CurrencyLedger\")",
		"\tif ledger != null and ledger.has_method(\"balance\") and ledger.has_method(\"spend\"):",
		"\t\treturn ledger",
		"\treturn null",
		"",
		"# What the buyer can spend of one currency right now. With no wallet answering, the fallback purse",
		"# is currency-blind on purpose - it is a single number, not an economy.",
		"func _balance_of(currency: String) -> float:",
		"\tvar wallet: Node = _wallet()",
		"\tif wallet != null:",
		"\t\treturn float(wallet.call(\"balance\", currency))",
		"\treturn local_wallet",
		"",
		"# Takes the price. Only ever called once the balance has already covered it.",
		"func _take(currency: String, amount: float) -> void:",
		"\tvar wallet: Node = _wallet()",
		"\tif wallet != null:",
		"\t\twallet.call(\"spend\", currency, amount)",
		"\t\treturn",
		"\tlocal_wallet -= amount",
		"",
		"# Records why a purchase did not happen and fires the trigger. Every refusal goes through here,",
		"# so the reason string and On Purchase Refused can never disagree.",
		"func _refuse(entry_id: String, reason: String) -> void:",
		"\t_refused_id = entry_id",
		"\t_refused_reason = reason",
		"\ton_purchase_refused.emit(entry_id, reason)",
		"",
		"# A grid off a PriceTableResource (a property). Returns an Array of row dicts; a stray",
		"# non-Dictionary element (a hand-edited .tres) is dropped rather than crashing the typed loops.",
		"func _rows(source: Variant, field: String) -> Array:",
		"\tvar raw: Variant = source.get(field)",
		"\tif not raw is Array:",
		"\t\treturn []",
		"\tvar out: Array = []",
		"\tfor element: Variant in raw:",
		"\t\tif element is Dictionary:",
		"\t\t\tout.append(element)",
		"\treturn out",
		"",
		"# One cell off a row, treating a PRESENT-but-null value as missing so the default still applies",
		"# (Dictionary.get only falls back when the key is ABSENT).",
		"func _cell(row: Dictionary, key: String, fallback: Variant) -> Variant:",
		"\tvar value: Variant = row.get(key, fallback)",
		"\treturn fallback if value == null else value",
		"",
		"func _num(value: Variant) -> float:",
		"\tif value is float or value is int:",
		"\t\treturn float(value)",
		"\tif value is String and (value as String).is_valid_float():",
		"\t\treturn (value as String).to_float()",
		"\treturn 0.0",
		"",
		"# Registers one record, replacing any entry that already had this id (so a second Load Price",
		"# Table re-prices rather than duplicating) and keeping the table's original order. The position",
		"# is found by id.",
		"func _put(record: PriceEntry) -> void:",
		"\tvar entry_id: String = record.id",
		"\tvar at: int = -1",
		"\tvar index: int = 0",
		"\tfor existing: PriceEntry in _entries:",
		"\t\tif existing.id == entry_id:",
		"\t\t\tat = index",
		"\t\t\tbreak",
		"\t\tindex += 1",
		"\tif at >= 0:",
		"\t\t_entries[at] = record",
		"\telse:",
		"\t\t_entries.append(record)",
		"\t_by_id[entry_id] = record"
	]))
	sheet.events.append(block)

	# Load the attached resource on ready, so a designer who only drops a .tres never writes a row.
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var on_ready_body: RawCodeRow = RawCodeRow.new()
	on_ready_body.code = "if price_table != null:\n\tload_price_table(price_table)"
	on_ready.actions.append(on_ready_body)
	sheet.events.append(on_ready)

	# --- Stocking ---
	Lib.append_function(sheet, "load_price_table", "Load Price Table", "Priced Tables",
		"Stocks this table from a PriceTableResource (.tres) - every entry with its price, currency, stock, locked flag and requirement note - in one step instead of a wall of Add Entry actions. Entries that share an id with one already stocked are REPLACED (so loading a second table re-prices rather than duplicating); ids it has never seen are appended.",
		[["table", "Resource"]],
		"\n".join(PackedStringArray([
			"if table == null:",
			"\treturn",
			"var raw_name: Variant = table.get(\"table_name\")",
			"_table_name = str(raw_name) if raw_name != null else \"\"",
			"var raw_currency: Variant = table.get(\"default_currency\")",
			"if raw_currency != null and not str(raw_currency).is_empty():",
			"\t_default_currency = str(raw_currency)",
			"for row: Dictionary in _rows(table, \"entries\"):",
			"\tvar entry_id: String = str(_cell(row, \"id\", \"\"))",
			"\tif entry_id.is_empty():",
			"\t\tcontinue",
			"\tvar currency: String = str(_cell(row, \"currency\", \"\"))",
			"\tvar stock: int = int(_num(_cell(row, \"stock\", -1)))",
			"\tvar entry: PriceEntry = PriceEntry.new()",
			"\tentry.id = entry_id",
			"\tentry.label = str(_cell(row, \"label\", \"\"))",
			"\tentry.price = maxf(_num(_cell(row, \"price\", 0.0)), 0.0)",
			"\tentry.currency = currency if not currency.is_empty() else _default_currency",
			"\tentry.stock = stock",
			"\tentry.initial_stock = stock",
			"\tentry.unlocked = not bool(_cell(row, \"locked\", false))",
			"\tentry.requires = str(_cell(row, \"requires\", \"\"))",
			"\t_put(entry)"
		])),
		"Load price table [b]{table}[/b]")

	Lib.append_function(sheet, "add_entry", "Add Entry", "Priced Tables",
		"Adds (or replaces) one entry from a sheet, for a table built at runtime - a shop whose stock is rolled per visit, a skill tree grown as the player levels. A stock of -1 is unlimited; the entry starts unlocked with no requirement note (set those with Set Entry Unlocked and the resource's requires column).",
		[["entry_id", "String"], ["label", "String"], ["price", "float"], ["currency", "String"], ["stock", "int"]],
		"\n".join(PackedStringArray([
			"if entry_id.is_empty():",
			"\treturn",
			"var entry: PriceEntry = PriceEntry.new()",
			"entry.id = entry_id",
			"entry.label = label",
			"entry.price = maxf(price, 0.0)",
			"entry.currency = currency if not currency.is_empty() else _default_currency",
			"entry.stock = stock",
			"entry.initial_stock = stock",
			"_put(entry)"
		])),
		"Add entry [b]{entry_id}[/b] ([b]{label}[/b]) at [b]{price}[/b] [b]{currency}[/b], stock [b]{stock}[/b]")

	Lib.append_function(sheet, "clear_table", "Clear Table", "Priced Tables",
		"Empties the table - every entry, price and stock count. Use it before loading a different table when you do NOT want the two merged by id.",
		[],
		"_entries.clear()\n_by_id.clear()")

	# --- The transaction ---
	Lib.append_function(sheet, "buy", "Buy Entry", "Priced Tables",
		"The whole purchase in one row: refuses (firing On Purchase Refused with a reason) when the id is unknown, the entry is locked, its stock is 0, or the wallet cannot cover the price; otherwise it takes the price through whatever wallet answers, counts the stock down by one, and fires On Purchased with the id and what was paid. Hand over the goods in On Purchased - the pack never guesses what an entry means.",
		[["entry_id", "String"]],
		"\n".join(PackedStringArray([
			"var record: PriceEntry = _by_id.get(entry_id, null)",
			"if record == null:",
			"\t_refuse(entry_id, \"unknown entry\")",
			"\treturn",
			"if not bool(record.unlocked):",
			"\t_refuse(entry_id, \"locked\")",
			"\treturn",
			"if int(record.stock) == 0:",
			"\t_refuse(entry_id, \"out of stock\")",
			"\treturn",
			"var price: float = float(record.price)",
			"var currency: String = str(record.currency)",
			"if _balance_of(currency) < price:",
			"\t_refuse(entry_id, \"too expensive\")",
			"\treturn",
			"_take(currency, price)",
			"if int(record.stock) > 0:",
			"\trecord.stock = int(record.stock) - 1",
			"_last_id = entry_id",
			"_last_price = price",
			"_last_currency = currency",
			"on_purchased.emit(entry_id, price)"
		])),
		"Buy [b]{entry_id}[/b]")

	# --- Stock + gating ---
	Lib.append_function(sheet, "restock", "Restock Entry", "Priced Tables",
		"Adds to one entry's remaining stock (a delivery, a daily refill). An unlimited entry (-1) is left alone, and stock never falls below 0.",
		[["entry_id", "String"], ["amount", "int"]],
		"\n".join(PackedStringArray([
			"var record: PriceEntry = _by_id.get(entry_id, null)",
			"if record == null or record.stock < 0:",
			"\treturn",
			"record.stock = maxi(int(record.stock) + amount, 0)"
		])),
		"Restock [b]{entry_id}[/b] by [b]{amount}[/b]")

	Lib.append_function(sheet, "restock_all", "Restock All", "Priced Tables",
		"Puts every entry back to the stock its table shipped with - the one row behind \"the shop restocks each morning\". Prices, locks and requirement notes are untouched.",
		[],
		"for record: PriceEntry in _entries:\n\trecord.stock = record.initial_stock")

	Lib.append_function(sheet, "set_stock", "Set Stock", "Priced Tables",
		"Forces one entry's remaining stock to an exact number. -1 makes it unlimited, 0 sells it out.",
		[["entry_id", "String"], ["stock", "int"]],
		"var record: PriceEntry = _by_id.get(entry_id, null)\nif record != null:\n\trecord.stock = stock")

	Lib.append_function(sheet, "set_price", "Set Price", "Priced Tables",
		"Re-prices one entry while the game runs - a sale, a haggle, a reputation discount. Negative prices are clamped to 0 (a free entry still goes through the whole purchase, so its trigger still fires).",
		[["entry_id", "String"], ["price", "float"]],
		"var record: PriceEntry = _by_id.get(entry_id, null)\nif record != null:\n\trecord.price = maxf(price, 0.0)",
		"Set price of [b]{entry_id}[/b] to [b]{price}[/b]")

	Lib.append_function(sheet, "set_unlocked", "Set Entry Unlocked", "Priced Tables",
		"Opens (or closes) one entry. A locked entry still shows in the table - Entry Is Unlocked greys it out in your UI, and buying it is refused with the reason \"locked\" - which is how a tier gate, a skill-tree prerequisite or a story unlock is expressed without deleting the row.",
		[["entry_id", "String"], ["unlocked", "bool"]],
		"var record: PriceEntry = _by_id.get(entry_id, null)\nif record != null:\n\trecord.unlocked = unlocked",
		"Set [b]{entry_id}[/b] unlocked to [b]{unlocked}[/b]")

	Lib.append_function(sheet, "use_wallet_node", "Use Wallet Node", "Priced Tables",
		"Points this table at ONE wallet node, tried before anything else - the direct way when the purse is already in hand (the player's own wallet node, a shared bank, a per-faction till). The contract is two functions, balance(currency) and spend(currency, amount); a node missing either is ignored, so a wrong drag can never silently swallow the money. Pass nothing to go back to searching the wallet group and then the CurrencyLedger autoload.",
		[["node", "Node"]],
		"_wallet_node = node",
		"Use wallet node [i]{node}[/i]")

	Lib.append_function(sheet, "set_local_wallet", "Set Local Wallet", "Priced Tables",
		"Sets the fallback purse - the number this table spends from when no wallet node and no CurrencyLedger autoload answer. It is deliberately the ONLY money action here: as soon as your game has a real economy, install one and this number stops being consulted.",
		[["amount", "float"]],
		"local_wallet = amount")

	# --- Conditions ---
	Lib.condition(sheet, "can_afford_entry", "Can Afford Entry", "Priced Tables",
		"True when the wallet covers this entry's price right now - the condition that greys out a shop button before the player clicks it. Reads through the same seam the purchase uses, so it can never disagree with Buy Entry.",
		[["entry_id", "String"]],
		"var record: PriceEntry = _by_id.get(entry_id, null)\nreturn record != null and _balance_of(str(record.currency)) >= float(record.price)")

	Lib.condition(sheet, "entry_in_stock", "Entry In Stock", "Priced Tables",
		"True while the entry has something left to sell. An unlimited entry (-1) is always in stock; an unknown id never is.",
		[["entry_id", "String"]],
		"var record: PriceEntry = _by_id.get(entry_id, null)\nreturn record != null and int(record.stock) != 0")

	Lib.condition(sheet, "entry_is_unlocked", "Entry Is Unlocked", "Priced Tables",
		"True when the entry is open for business - the gate behind a tier, a prerequisite or a story beat.",
		[["entry_id", "String"]],
		"var record: PriceEntry = _by_id.get(entry_id, null)\nreturn record != null and bool(record.unlocked)")

	Lib.condition(sheet, "has_entry", "Has Entry", "Priced Tables",
		"Whether the table holds an entry with this id at all - the guard that tells a typo apart from a sold-out row.",
		[["entry_id", "String"]],
		"return _by_id.has(entry_id)")

	Lib.condition(sheet, "is_sold_out", "Table Is Sold Out", "Priced Tables",
		"True when nothing in the table can be bought any more: every entry is either at 0 stock or locked. An empty table counts as sold out.",
		[],
		"\n".join(PackedStringArray([
			"for record: PriceEntry in _entries:",
			"\tif record.stock != 0 and record.unlocked:",
			"\t\treturn false",
			"return true"
		])))

	# --- Expressions: the entry ---
	Lib.number(sheet, "price_of", "Price Of", "Priced Tables",
		"What one entry costs (-1 when the table has no such id, so a missing price never reads as free).",
		[["entry_id", "String"]],
		"return float(_by_id[entry_id].price) if _by_id.has(entry_id) else -1.0", TYPE_FLOAT)

	Lib.number(sheet, "stock_of", "Stock Of", "Priced Tables",
		"How many of one entry are left: -1 for unlimited, 0 for sold out (which is also what an unknown id reads).",
		[["entry_id", "String"]],
		"return int(_by_id[entry_id].stock) if _by_id.has(entry_id) else 0", TYPE_INT)

	Lib.number(sheet, "currency_of", "Currency Of", "Priced Tables",
		"The currency id one entry is priced in - pass it to your wallet's own expressions to show the right icon.",
		[["entry_id", "String"]],
		"return str(_by_id[entry_id].currency) if _by_id.has(entry_id) else \"\"", TYPE_STRING)

	Lib.number(sheet, "label_of", "Label Of", "Priced Tables",
		"The player-facing name of one entry (\"Iron Sword\"), for the shop row's text.",
		[["entry_id", "String"]],
		"return str(_by_id[entry_id].label) if _by_id.has(entry_id) else \"\"", TYPE_STRING)

	Lib.number(sheet, "requirement_of", "Requirement Of", "Priced Tables",
		"The plain-language requirement note written on one entry (\"needs the guild badge\"), for the tooltip on a locked row. The pack never interprets it - YOUR game decides when to call Set Entry Unlocked.",
		[["entry_id", "String"]],
		"return str(_by_id[entry_id].requires) if _by_id.has(entry_id) else \"\"", TYPE_STRING)

	# --- Expressions: the table ---
	Lib.number(sheet, "entry_count", "Entry Count", "Priced Tables",
		"How many entries the table holds - the row count for a shop list.",
		[],
		"return _entries.size()", TYPE_INT)

	Lib.number(sheet, "entry_id_at", "Entry Id At", "Priced Tables",
		"The entry id at a position, in table order (\"\" out of range) - walk 0..Entry Count to build the shop UI.",
		[["index", "int"]],
		"return str(_entries[index].id) if index >= 0 and index < _entries.size() else \"\"", TYPE_STRING)

	Lib.number(sheet, "table_title", "Table Name", "Priced Tables",
		"The readable name written on the loaded table resource (\"Blacksmith\") - the shop window's title.",
		[],
		"return _table_name", TYPE_STRING)

	Lib.number(sheet, "wallet_balance", "Wallet Balance", "Priced Tables",
		"What the buyer can spend of one currency, read through the same seam a purchase uses: the node given to Use Wallet Node, else a wallet node in the wallet group, else the CurrencyLedger autoload, else this table's Local Wallet number (which is currency-blind).",
		[["currency", "String"]],
		"return _balance_of(currency)", TYPE_FLOAT)

	# --- Expressions: transaction context ---
	Lib.number(sheet, "last_purchased_id", "Last Purchased Id", "Priced Tables",
		"The entry bought most recently (\"\" before the first one) - readable long after On Purchased, for a receipt line.",
		[],
		"return _last_id", TYPE_STRING)

	Lib.number(sheet, "last_price_paid", "Last Price Paid", "Priced Tables",
		"What the last purchase actually cost - the number to show in \"-25 gold\" feedback.",
		[],
		"return _last_price", TYPE_FLOAT)

	Lib.number(sheet, "last_currency_paid", "Last Currency Paid", "Priced Tables",
		"The currency the last purchase was paid in.",
		[],
		"return _last_currency", TYPE_STRING)

	Lib.number(sheet, "refused_entry_id", "Refused Entry Id", "Priced Tables",
		"The entry of the most recent refusal (\"\" if none yet).",
		[],
		"return _refused_id", TYPE_STRING)

	Lib.number(sheet, "refused_reason", "Refused Reason", "Priced Tables",
		"Why the most recent purchase was refused, as plain words you can show: \"unknown entry\", \"locked\", \"out of stock\" or \"too expensive\".",
		[],
		"return _refused_reason", TYPE_STRING)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"# The whole table travels, so a shop reopens with the stock it was left with - and the",
		"# id index is rebuilt from the restored records rather than saved twice.",
		"# The table as the plain records a save holds.",
		"func _entries_as_dicts() -> Array:",
		"\tvar records: Array = []",
		"\tfor entry: PriceEntry in _entries:",
		"\t\trecords.append(entry.to_dict())",
		"\treturn records",
		"",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"entries\": _entries_as_dicts(),",
		"\t\t\"table_name\": _table_name,",
		"\t\t\"default_currency\": _default_currency,",
		"\t\t\"local_wallet\": local_wallet",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_entries.clear()",
		"\tfor saved: Variant in state.get(\"entries\", []) as Array:",
		"\t\tif saved is Dictionary:",
		"\t\t\t_entries.append(PriceEntry.from_dict(saved as Dictionary))",
		"\t_table_name = str(state.get(\"table_name\", \"\"))",
		"\t_default_currency = str(state.get(\"default_currency\", \"gold\"))",
		"\tlocal_wallet = float(state.get(\"local_wallet\", 0.0))",
		"\t_by_id.clear()",
		"\tfor record: PriceEntry in _entries:",
		"\t\t_by_id[record.id] = record"
	]))
	sheet.events.append(persistence)

	Lib.feature_verbs(sheet, ["load_price_table", "buy"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/priced_table/priced_table_behavior")
