# EventForge module - higher-order + typed-array operations for the "Variables: Array" vocabulary.
#
# Two additions the base Array vocabulary (collection_aces.gd) leaves out:
#  - Godot's higher-order Array functions - filter / map / reduce / any / all. Each takes a small
#    predicate or transform over the current element `x` (and the running result `acc`, for reduce). The
#    lambda SIGNATURE is fixed (func(x) / func(acc, x)) so the emitted GDScript stays plain and parity-
#    safe; the author fills only the body expression through the ƒx field.
#  - GDScript typed arrays (Array[int], Array[String], ...): querying is_typed / the element type / the
#    element class, and assign() - the type-converting way to fill a typed array from another array.
#
# ace_ids and codegen_templates are a compatibility covenant: frozen once shipped (deprecate, never rename).
@tool
class_name EventForgeArrayFunctionalACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const CAT := "Variables: Array"


static func get_descriptors() -> Array[ACEDescriptor]:
	var d: Array[ACEDescriptor] = []

	# --- Higher-order functions (the current element is `x`; reduce also has the accumulator `acc`) ---
	d.append(F.make_descriptor("Core", "ArrayFilter", "Filter", ACEDescriptor.ACEType.EXPRESSION,
		"{var_name}.filter(func(x): return {predicate})", "",
		[_arr(), F.make_param("predicate", "String", "x > 0", "Keep where", "A test on the current element `x`; an element is kept when it is true (e.g. x > 0, x.alive, x.health < 50).", "expression")],
		CAT, "filter {var_name} where {predicate}")
		.described("Returns a NEW array with only the elements where the test is true - the current element is `x` (e.g. x > 0, x.alive). Godot's Array.filter(); the original array is left unchanged."))

	d.append(F.make_descriptor("Core", "ArrayMap", "Map", ACEDescriptor.ACEType.EXPRESSION,
		"{var_name}.map(func(x): return {expression})", "",
		[_arr(), F.make_param("expression", "String", "x * 2", "Transform to", "What each element `x` becomes (e.g. x * 2, x.name, str(x)).", "expression")],
		CAT, "map {var_name} with {expression}")
		.described("Returns a NEW array with every element `x` transformed by the expression (e.g. x * 2, x.name). Godot's Array.map(); the original array is left unchanged."))

	d.append(F.make_descriptor("Core", "ArrayReduce", "Reduce", ACEDescriptor.ACEType.EXPRESSION,
		"{var_name}.reduce(func(acc, x): return {expression}, {seed})", "",
		[_arr(), F.make_param("expression", "String", "acc + x", "Combine", "How to fold each element `x` into the running result `acc` (e.g. acc + x to sum, max(acc, x) for the biggest).", "expression"), F.make_param("seed", "String", "0", "Starting value", "The initial accumulator before the first element (e.g. 0 to sum, [] to build an array).", "expression")],
		CAT, "reduce {var_name} with {expression} from {seed}")
		.described("Folds the whole array down to a SINGLE value: `acc` is the running result (starting at the seed) and `x` the current element (e.g. acc + x from 0 sums the array). Godot's Array.reduce()."))

	d.append(F.make_descriptor("Core", "ArrayAny", "Any Match", ACEDescriptor.ACEType.CONDITION,
		"{var_name}.any(func(x): return {predicate})", "",
		[_arr(), F.make_param("predicate", "String", "x > 0", "Where", "A test on the current element `x`.", "expression")],
		CAT, "any of {var_name} where {predicate}")
		.described("True when AT LEAST ONE element satisfies the test - the current element is `x` (e.g. any x > 0). Godot's Array.any()."))

	d.append(F.make_descriptor("Core", "ArrayAll", "All Match", ACEDescriptor.ACEType.CONDITION,
		"{var_name}.all(func(x): return {predicate})", "",
		[_arr(), F.make_param("predicate", "String", "x > 0", "Where", "A test on the current element `x`.", "expression")],
		CAT, "all of {var_name} where {predicate}")
		.described("True when EVERY element satisfies the test (the current element is `x`), or the array is empty. Godot's Array.all()."))

	# --- Typed arrays (Array[int], Array[String], ...) ---
	d.append(F.make_descriptor("Core", "ArrayIsTyped", "Is Typed", ACEDescriptor.ACEType.CONDITION,
		"{var_name}.is_typed()", "",
		[_arr()],
		CAT, "{var_name} is a typed array")
		.described("True when the array is a typed container (e.g. Array[int]) rather than a plain untyped Array. Godot's Array.is_typed()."))

	d.append(F.make_descriptor("Core", "ArrayAssign", "Assign (Type-Converting)", ACEDescriptor.ACEType.ACTION,
		"{var_name}.assign({source})", "",
		[_arr("The destination array (often a typed one, e.g. an Array[int])."), F.make_param("source", "String", "other", "From array", "The array to copy elements from.", "variable_reference:Array")],
		CAT, "assign {source} into {var_name}")
		.described("Replaces this array's contents with a COPY of the source array, converting each element to this array's element type - the type-safe way to fill a typed array (Array[int], ...) from another array. Godot's Array.assign()."))

	d.append(F.make_descriptor("Core", "ArrayTypedBuiltin", "Element Type", ACEDescriptor.ACEType.EXPRESSION,
		"{var_name}.get_typed_builtin()", "",
		[_arr()],
		CAT, "{var_name} element type")
		.described("The element type a typed array holds, as a Variant.Type value (TYPE_INT, TYPE_STRING, ...); TYPE_NIL (0) when the array is untyped. Godot's Array.get_typed_builtin()."))

	d.append(F.make_descriptor("Core", "ArrayTypedClassName", "Element Class", ACEDescriptor.ACEType.EXPRESSION,
		"{var_name}.get_typed_class_name()", "",
		[_arr()],
		CAT, "{var_name} element class")
		.described("For an array typed to a class (e.g. Array[Node]), the element class name as a StringName; \"\" for a builtin-typed or untyped array. Godot's Array.get_typed_class_name()."))

	return d


## The shared first param: the Array variable this operation runs on. The `variable_reference:Array` hint
## scopes the dropdown to Array-typed sheet variables (a typed Array[int]/Array[String] qualifies too).
static func _arr(description: String = "The array variable.") -> ACEParam:
	return F.make_param("var_name", "String", "list", "Array", description, "variable_reference:Array")
