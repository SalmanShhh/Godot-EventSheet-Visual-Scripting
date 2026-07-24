# EventForge module - higher-order + typed-array operations for the "Variables: Array" vocabulary.
#
# Two additions the base Array vocabulary (collection_aces.gd) leaves out:
#  - Godot's higher-order Array functions - filter / map / reduce / any / all. Each takes a small
#    predicate or transform over the current element, written as a plain expression in the ƒx field.
#  - GDScript typed arrays (Array[int], Array[String], ...): querying is_typed / the element type / the
#    element class, and assign() - the type-converting way to fill a typed array from another array.
#
# WHY THE ELEMENT NAME IS A PARAMETER: the lambda variable is spelled by the author (default "x", and
# "acc" for the reduce accumulator) instead of being baked into the template. A baked name would SILENTLY
# shadow a sheet variable of the same name - GDScript emits no warning, so the row would compile clean and
# quietly compute the wrong answer. Exposing the name keeps the common case one word long and gives anyone
# with an `x` of their own a way out. (Elsewhere in the vocabulary, lambdas the author never writes into
# use `__`-prefixed names for the same collision reason - here the author DOES write the body, so the name
# has to be theirs.)
#
# ace_ids and codegen_templates are a compatibility covenant: frozen once shipped (deprecate, never rename).
@tool
class_name EventForgeArrayFunctionalACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const CAT := "Variables: Array"


static func get_descriptors() -> Array[ACEDescriptor]:
	var d: Array[ACEDescriptor] = []

	# --- Higher-order functions (the author names the element; the body is a plain expression) ---
	d.append(F.make_descriptor("Core", "ArrayFilter", "Filter", ACEDescriptor.ACEType.EXPRESSION,
		"{var_name}.filter(func({element}): return {predicate})", "",
		[_arr(), _predicate("Keep where", "x > 0", "A test on the current element; an element is KEPT when it is true (e.g. x > 0, x.alive, x.health < 50)."), _element()],
		CAT, "filter {var_name} where {predicate}")
		.described("Returns a NEW array with only the elements where the test is true (the original is unchanged). The current element is named by the Element field - `x` unless you rename it. Godot's Array.filter()."))

	d.append(F.make_descriptor("Core", "ArrayMap", "Map", ACEDescriptor.ACEType.EXPRESSION,
		"{var_name}.map(func({element}): return {expression})", "",
		[_arr(), F.make_param("expression", "String", "x * 2", "Transform to", "What each element becomes (e.g. x * 2, x.name, str(x)).", "expression"), _element()],
		CAT, "map {var_name} with {expression}")
		.described("Returns a NEW array with every element transformed by the expression (the original is unchanged). The current element is named by the Element field - `x` unless you rename it. Godot's Array.map()."))

	d.append(F.make_descriptor("Core", "ArrayReduce", "Reduce", ACEDescriptor.ACEType.EXPRESSION,
		"{var_name}.reduce(func({accumulator}, {element}): return {expression}, {seed})", "",
		[_arr(),
			F.make_param("expression", "String", "acc + x", "Combine", "How to fold the current element into the running result (e.g. acc + x to sum, max(acc, x) for the biggest).", "expression"),
			F.make_param("seed", "String", "0", "Starting value", "The initial running result, before the first element (e.g. 0 to sum, 1 to multiply, [] to build an array). Required - Reduce always starts from a value here.", "expression"),
			_element(),
			F.make_param("accumulator", "String", "acc", "Accumulator name", "What to call the running result inside the Combine expression. Rename it if your sheet already has a variable called acc.", "expression")],
		CAT, "reduce {var_name} with {expression} from {seed}")
		.described("Folds the whole array down to a SINGLE value: the accumulator holds the running result (starting at the seed) and is combined with each element in turn - e.g. acc + x from 0 sums the array. Godot's Array.reduce()."))

	d.append(F.make_descriptor("Core", "ArrayAny", "Any Match", ACEDescriptor.ACEType.CONDITION,
		"{var_name}.any(func({element}): return {predicate})", "",
		[_arr(), _predicate("Where", "x > 0", "A test on the current element."), _element()],
		CAT, "any of {var_name} where {predicate}")
		.described("True when AT LEAST ONE element satisfies the test; FALSE for an empty array. The current element is named by the Element field - `x` unless you rename it. Godot's Array.any()."))

	d.append(F.make_descriptor("Core", "ArrayAll", "All Match", ACEDescriptor.ACEType.CONDITION,
		"{var_name}.all(func({element}): return {predicate})", "",
		[_arr(), _predicate("Where", "x > 0", "A test on the current element."), _element()],
		CAT, "all of {var_name} where {predicate}")
		.described("True when EVERY element satisfies the test; also TRUE for an empty array (there is nothing that fails). The current element is named by the Element field - `x` unless you rename it. Godot's Array.all()."))

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
		.described("Replaces this array's contents with a COPY of the source array, converting each element to this array's element type - the type-safe way to fill a typed array (Array[int], ...) from another array. Converting values that fit is silent (a float 2.7 into an Array[int] truncates to 2); a value that cannot convert at all leaves the destination EMPTY and pushes an error. Godot's Array.assign()."))

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


## The author-chosen name for the current element inside the lambda (see the header note on shadowing).
static func _element() -> ACEParam:
	return F.make_param("element", "String", "x", "Element name", "What to call the current element inside the expression above. Rename it if your sheet already has a variable called x.", "expression")


## A boolean test over the current element - the shape filter / any / all share.
static func _predicate(display_name: String, default_value: String, description: String) -> ACEParam:
	return F.make_param("predicate", "String", default_value, display_name, description, "expression")
