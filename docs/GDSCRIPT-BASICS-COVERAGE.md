# GDScript basics, as event sheet rows

Everything on Godot's official GDScript basics page can be written - and read back - in the
event sheet's condition/action lanes. This table is the receipt: each language feature, how it
reads in a sheet, and how you author it. It states shipped facts only, and the test suite pins
every row (`tests/gdscript_basics_coverage_test.gd`), so this coverage cannot silently regress.

Two deliberate scope notes live at the bottom - everything else on the page round-trips
byte-exactly: open the generated `.gd`, save it untouched, and you get the identical file.

| GDScript feature | In the sheet | How you author it |
| --- | --- | --- |
| Variables (typed and inferred) | Variable rows with plain-language types | Add > Global/Local Variable (typed containers explained in the Type dropdown) |
| Constants | A constant row / local constant action | The variable dialog's Constant toggle; Set Local Constant |
| Enums | Enum blocks with per-value fields | Add > Enum (the "+" adds each value as a field) |
| Functions, parameters, returns | Expandable ƒ Define blocks | Add > Function… (the verb studio) |
| Static functions and variables | static-marked rows | The Static toggle in the function/variable dialogs |
| `if` / `elif` / `else` | Condition lane + System Else / Else If chips | Right-click an event > Make Else / Make Else-If |
| `match` | A switch/case block | Right-click > the switch block (Simple Mode included) |
| `for` / `while` loops | For Each / Repeat / While rows | Right-click > Add Pick Filter (For Each) |
| `break` / `continue` | Break Loop / Continue Loop actions | The Loops category in the picker |
| Loop counters | The Loop index field + Loop Index expressions | Name it on any loop; read with Loop Index / Loop Index Of |
| Arrays and Dictionaries | 41 Variables: Array / Dictionary verbs | The picker's Variables sections |
| Typed containers (`Array[int]`, ...) | Offered with plain-language hints | The variable dialog's Type dropdown |
| Signals (declare / emit / connect / await) | Signal rows + On Signal / Emit / Connect | Add > Signal Event…; the Signals category |
| `await` / coroutines | Wait and await-marked actions | The Wait ACEs; the action's await toggle |
| Lambdas and Callables | Lambda / Callable expressions | Helpers: Lambda Value, Callable From Method, Bind |
| Properties (`set` / `get`) | A setter/getter property block | The variable dialog's Setter/Getter fields |
| `@export` (all families) | The Inspector-look picker + decor | The variable dialog ("Inspector look", groups, ranges) |
| `@onready` | The @onready toggle | The variable dialog; node-drag creates them |
| Doc comments (`##`) | Doc fields on classes, variables, functions | The Doc comment fields (BBCode toolbar included) |
| Ternary (`x if c else y`) | Value If (one of two values) | The Helpers category |
| String formatting | Text From Pattern ({name} slots) / Format String | The Text category (featured) |
| `null` checks | Is Null / Is Valid conditions | The picker's null-check conditions |
| Operators (incl. `**`, `%`, bit ops) | The operator palette, tooltip-explained | The ƒx expression builder's Operators row |
| `@tool` / editor scripts | Tool-mode sheets + On Editor Run | Sheet > New Editor Tool… |
| Preloads and constants-from-files | Preload Resource blocks | Add > Preload Resource… |
| Multi-line enums (explicit values) | The same enum block, shape remembered | The enum dialog's "one value per line" toggle |
| Inner classes (data shape) | The data-class block (fields editable) | Opens from lifted scripts; Add > data class |

## Scope notes (deliberate, not gaps)

- **Full inner classes with methods** read as a data-class block at the view level (fields
  editable); their method bodies stay verbatim code. Deliberate: a class-in-a-class is expert
  territory, and the covenant (never corrupt, always round-trip) holds either way.
