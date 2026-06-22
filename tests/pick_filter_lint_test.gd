# Godot EventSheets — For Each (pick filter) fields are linted on save / Check Sheet for Errors.
#
# Before this, a row whose only error lived in a pick filter's collection / predicate / order-by slipped
# past the on-save lint entirely. EventSheetDiagnostics now lints them: the collection is wrapped per kind
# (so a GROUP name isn't read as bare GDScript) and the predicate/order-by stub the loop iterator (so a
# valid `item.field` resolves, but a typo'd identifier still flags).
@tool
extends RefCounted
class_name PickFilterLintTest

static func run() -> bool:
	var all_passed: bool = true

	# A typo'd predicate flags (iterator 'enemy' is stubbed, so only 'enmy' is undefined).
	all_passed = _check("typo'd predicate flags", _has_diag(_sheet(PickFilter.CollectionKind.EXPRESSION, "[1, 2, 3]", "enemy", "enmy < 2", "")), true) and all_passed
	# A valid predicate referencing the iterator does NOT flag.
	all_passed = _check("valid predicate (uses iterator) does not flag", _has_diag(_sheet(PickFilter.CollectionKind.EXPRESSION, "[1, 2, 3]", "enemy", "enemy < 2", "")), false) and all_passed
	# A bad collection expression flags.
	all_passed = _check("bad collection flags", _has_diag(_sheet(PickFilter.CollectionKind.EXPRESSION, "notavar + 1", "item", "", "")), true) and all_passed
	# A GROUP collection NAME is wrapped (get_nodes_in_group) — not linted as a bare identifier.
	all_passed = _check("GROUP collection name does not false-positive", _has_diag(_sheet(PickFilter.CollectionKind.GROUP, "enemies", "item", "", "")), false) and all_passed
	# A bad order-by flags.
	all_passed = _check("bad order-by flags", _has_diag(_sheet(PickFilter.CollectionKind.EXPRESSION, "[1, 2, 3]", "n", "", "nope.x")), true) and all_passed

	return all_passed

static func _sheet(kind: int, collection: String, iterator: String, predicate: String, order_by: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var pick: PickFilter = PickFilter.new()
	pick.enabled = true
	pick.collection_kind = kind
	pick.collection_value = collection
	pick.iterator_name = iterator
	pick.predicate_expression = predicate
	pick.order_by_expression = order_by
	event.pick_filters.append(pick)
	sheet.events.append(event)
	return sheet

static func _has_diag(sheet: EventSheetResource) -> bool:
	return EventSheetDiagnostics.analyze(sheet, null).size() >= 1

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] pick_filter_lint_test: %s" % label)
		return true
	print("[FAIL] pick_filter_lint_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
