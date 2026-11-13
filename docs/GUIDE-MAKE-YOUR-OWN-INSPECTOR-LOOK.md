# Make Your Own Inspector Look

A **look** is how one property is drawn in Godot's Inspector in the place of its plain field: a progress bar, a row of stars, a dial. The looks that ship with this plugin (the progress bar is the first) are ordinary scripts, and so is every look you add. **A look is one script file.** Put it in `res://eventsheet_addons/looks/` and it is a look: nothing is registered, and the Variable window lists it the next time it opens.

A look is a script that extends `EventSheetInspectorLook`, which is a thin layer over Godot's own `EditorProperty`. Everything `EditorProperty` gives you (`add_focusable`, `set_bottom_editor`, `emit_changed`, `_set_read_only`) is still yours. The point of the base class is only to make the common case short.

## Table of Contents

1. [Scenarios Where This Excels](#1-scenarios-where-this-excels)
2. [Core Concepts](#2-core-concepts)
3. [Getting Started: a star rating in one file](#3-getting-started-a-star-rating-in-one-file)
4. [What the editor reads from the file](#4-what-the-editor-reads-from-the-file)
5. [The functions you can write](#5-the-functions-you-can-write)
6. [What a look writes into the script](#6-what-a-look-writes-into-the-script)
7. [Opening a look as an event sheet](#7-opening-a-look-as-an-event-sheet)
8. [Use Cases](#8-use-cases)
9. [Tips and Common Mistakes](#9-tips-and-common-mistakes)

---

## 1. Scenarios Where This Excels

- **A control your game's data deserves.** A `rating` is five stars, a `volume` is a bar, a `facing` is four arrows. The designer sets it by looking at it.
- **One look for many scripts.** A look is not tied to one variable: any int property can wear the star rating, and each says how many stars it wants.
- **A control a team shares.** The file is plain text in the project, so version control carries it and a teammate who does not open the event sheet still gets the control.
- **Starting from a shipped look.** Copy the shipped file into your looks folder, give it a new name, change what it draws.
- **Learning Godot's editor classes.** The file is the same `EditorProperty` code the engine documents, with the plumbing taken off.

## 2. Core Concepts

**The file name is the look's name.** `star_rating.gd` is the look `star_rating`, and the word in the marker the script carries: `@export_custom(PROPERTY_HINT_NONE, "eventsheet:star_rating:5")`. There is no `class_name` in a look file, on purpose: two copies of one look would otherwise be a duplicate class.

**The editor reads the file's text, it does not run it.** The name, hover, the types the look works on and the questions it asks are all read from the text, so the Variable window can list a look without building a control. The control is built only when the Inspector draws a property that wears the look.

**A look runs in the editor, so its file starts with `@tool`.** Godot has to run the script to draw the control. It does nothing in a running game: the marker is only a hint string, and without this plugin (or in an exported game) the property is a plain field. Because a look extends an editor class, leave `eventsheet_addons/looks/` out of an export.

**Your questions become the marker.** Each exported variable of the look (except `works_on`) is one question the Variable window asks, and one value in the marker, in file order.

## 3. Getting Started: a star rating in one file

Create `res://eventsheet_addons/looks/star_rating.gd`:

```gdscript
@tool
extends EventSheetInspectorLook

## Star rating
## A row of stars. Click one to set the value.

## The kinds of property this look can be put on.
@export var works_on: String = "int"
## How many stars the row shows.
@export var count: int = 5

var _stars: Array[Button] = []


func _look_built() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	for number: int in range(1, count + 1):
		var star: Button = Button.new()
		star.flat = true
		star.pressed.connect(_pick.bind(number))
		row.add_child(star)
		_stars.append(star)
	add_child(row)
	add_focusable(_stars[0])


func _value_shown(value: Variant) -> void:
	for index: int in range(_stars.size()):
		_stars[index].text = "★" if index < int(value) else "☆"


func _pick(number: int) -> void:
	set_field_value(number)
```

Now open the Variable window on an int variable. **Inspector look** lists **Star rating**, and one question under it: `count`. Pick it, leave 5, and the variable is written as:

```gdscript
@export_custom(PROPERTY_HINT_NONE, "eventsheet:star_rating:5") var rating: int = 3
```

Select a node that has that script. The Inspector draws five stars, three of them filled. Click the fourth and the property becomes 4, as one undo step.

## 4. What the editor reads from the file

| In the file | Used as |
|---|---|
| The first `##` line after `extends` | The look's name in the list |
| The `##` lines after it | The look's hover |
| `@export var works_on: String = "int,float"` | The types it can be put on. Empty means any type. A class name (`Texture2D`, `Curve`) works for a resource slot |
| Every other `@export var` | A question, asked in file order, written into the marker in that order |
| The `##` line above a question | The question's hover |
| `@export_enum("a", "b") var mode: String` | A question with a dropdown |
| `@export var outlined: bool = true` | A question with a tick box |
| `const MARKER_TEMPLATE := "kinds={kinds},store={store}"` | A look whose values must share one segment (`kinds=px|world,store=world`) |
| `const PREVIEW_SENTENCE := "Shown as a star rating."` | The sentence the Designer's preview card says under a variable wearing the look. Without it the card says "Shown with the look star_rating." |
| `const ALSO_DRAWS_ON := "int"` | Types the look draws when a script's marker already asks for it, without offering the look for them in the Variable window |

A question's label is the variable's name as you wrote it. A value that holds a colon, a quote or a line break cannot ride a marker; the look then writes nothing and the variable stays a plain field. A name that is already one of Godot's own (`name`, `size`, `visible`) cannot be a question, because the look is a node.

## 5. The functions you can write

You write these. You never override `_update_property`: the base needs it to keep the value in step.

| Function | Runs | Use it to |
|---|---|---|
| `_can_draw()` | Once, after the questions are answered and before anything is built | Say no when the values a marker carried make no sense (a table that is not a variable name). The Inspector then keeps Godot's plain field |
| `_look_built()` | Once, when the control is first needed, with the questions already answered | Make the control, connect signals, `add_child` |
| `_value_shown(value)` | On every refresh | Draw this value. Do not call `set_field_value` here |
| `_value_changed_from_outside(value)` | Before `_value_shown`, when the value moved without this look (undo, a script, another editor) | Stop an animation or reset a drag |

And these are ready to call:

| Call | What it does |
|---|---|
| `set_field_value(value)` | Writes a new value. The Inspector owns undo |
| `field_value()` | The property's value right now |
| `field_name()`, `field_type()`, `field_object()` | The property's name, its Variant type and the object it is on |
| `is_field_read_only()` | True when the Inspector has the property locked |
| `marker_args` | What the marker carried after the look's name, split on `:` exactly as written. For a marker with a grammar of its own (a list, then optional tails); most looks read their exported variables instead |

## 6. What a look writes into the script

The marker is `eventsheet:<file name>`, then each answer after a colon: `eventsheet:progress_bar:0:100` for the shipped progress bar with a min of 0 and a max of 100. The script is plain GDScript: the marker is only a hint string, so it compiles, exports and runs without any plugin.

The looks that ship are files too, in the plugin's own `looks` folder, and they are the best examples to read: `progress_bar.gd` (two numbers), `swatch_row.gd` (no questions at all, a widget wrapped as it is), `table_row.gd` (two names, and `_can_draw`), `unit.gd` (one question that holds a whole spec), `toggle_row.gd` (reads `marker_args` for its tails) and `table.gd` (a grid of cells). Each wraps a drawing widget the plugin already had, so the Inspector draws the same pixels as before the look became a file. The markers they write are the ones scripts already carry: a marker written before looks were files opens, saves back byte for byte and draws exactly as it did.

Opening a script that carries a marker for a look the project does not have still works. The sheet keeps the marker, saving writes it back byte for byte, and the Variable window offers it as "Look not installed" rather than dropping it.

**Save and show.** A choice made in the Inspector Designer is saved to the script at once and Godot is told the file changed, so the selected node's Inspector redraws with the new look without reselecting it.

## 7. Opening a look as an event sheet

A look is a plain script, so it opens as an event sheet like any other: its exported variables are variable rows, and each function is an event. Saving untouched writes the file back byte for byte. Edit the rows, save, and the look changes.

## 8. Use Cases

1. A star rating for a review score.
2. A progress bar for health, loading or reputation.
3. A row of arrows for a four-way facing.
4. A battery icon that fills for a charge level.
5. A thermometer for a heat value.
6. A row of lock icons for how many keys are held.
7. A pill that is green, amber or red by range.
8. A countdown ring for a cooldown in seconds.
9. A dial for a volume knob.
10. A strip of coloured dots for a difficulty level.
11. A slider with ticks at each allowed value.
12. A row of heart icons for lives.
13. A small bar chart of five related numbers.
14. A badge that shows a number over an icon.
15. A texture slot with a larger thumbnail beside it.

Other use cases:

- **A look for a typed resource.** `works_on` names a class such as `Curve`, and the look draws a preview under the slot.
- **A look with a unit.** One question names the unit, and the control shows it beside the number.
- **A look that reads a sibling.** `field_object()` gives the whole object, so the look can read another property of it.
- **A look that edits a list.** `works_on` is `Array` and the control is a small editor for its entries.
- **A look for a project's own type.** A look for one custom resource class, shared by every script that holds it.

## 9. Tips and Common Mistakes

- **No `@tool`, no control.** The look is drawn in the editor, so the file needs `@tool`. Without it Godot cannot build the control.
- **A new look does not show.** Check the file is in `res://eventsheet_addons/looks/`, it has `extends EventSheetInspectorLook`, and its name is a valid identifier.
- **Do not add `class_name`.** The file name is the identity.
- **Questions only grow at the end.** Variables already written with the look carry the old argument list; a shorter list reads with defaults for the rest, so add new questions last, with a default that reproduces the old marker.
- **A look with the same name as a shipped one wins.** Your file in the project replaces the shipped file of that name.
- **The marker never changes.** A marker already in a script keeps meaning what it meant, so keep a look's name and its first questions stable once it is in use.
