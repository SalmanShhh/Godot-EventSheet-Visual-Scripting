# Inspector Look

An **Inspector look** is a script that draws one property in Godot's own Inspector in the place of its plain field: a bar for health, a row of stars for a rating, a dial for a direction. It is an ordinary script that extends `EventSheetInspectorLook`, a thin layer over Godot's `EditorProperty`, and it is one file.

This page is the six rows that make a look on a sheet. They appear on the sheet of a look and on no other sheet, because they only mean something there. Open a look (or start one with **New inspector look**) and the sheet reads in the words Godot's Inspector uses for it.

- **On Look Built** - the Inspector first needs the look, so it builds it.
- **On Value Shown** - the Inspector wants the current value drawn.
- **On Value Changed From Outside** - the value moved without this look moving it.
- **Set Field Value** - the person changed something, so write it back.
- **Make Control Take Focus** - the control the keyboard lands on.
- **The Field's Value** - the value right now, as an expression.

Every row compiles to the plain function or call it names (`func _look_built() -> void:`, `set_field_value(value)`, `add_focusable(control)`, `field_value()`), so the saved file is ordinary GDScript, and a look written by hand opens as these rows and saves back byte for byte.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **A control your game's data deserves.** A rating is five stars, a volume is a bar, a facing is four arrows.
- **A look you make without writing an editor class.** Start from New inspector look, add a row, save.
- **A look a team shares.** The file is plain text in the project.
- **Reading a shipped look.** Open it as a sheet, see how the Inspector draws it, copy it into your project and change it.
- **Learning Godot's editor classes.** The sheet and the file say the same thing, one in words and one in code.

## Core concepts

- **The three triggers are called by Godot, not by your rows.** A look is built once, shown many times and told about outside changes. You never call them; you say what happens.
- **On Value Shown runs on every refresh.** When the value is first drawn, after an edit, after undo. Put the value into your controls there, and never write a value back from there.
- **On Value Changed From Outside runs just before On Value Shown.** Undo, a script, another editor: use it to stop an animation or reset a drag.
- **Set Field Value is one undo step.** The Inspector owns undo, so a person pressing Ctrl+Z walks back what the look wrote.
- **The questions are variables.** An exported variable of the look is a question the Variable window asks. Its first `##` line is the label the window shows.
- **The rows appear only on a look sheet.** A sheet whose script extends `EventSheetInspectorLook` offers them; any other sheet does not.

## Reference tables

| Name | What it does | Ships as |
|------|--------------|----------|
| On Look Built | Runs once, when the Inspector first builds the look for a property. | `func _look_built() -> void:` |
| On Value Shown | Runs every time the Inspector refreshes the property, with the value to draw. | `func _value_shown(value: Variant) -> void:` |
| On Value Changed From Outside | Runs when the value moved without this look moving it, just before On Value Shown. | `func _value_changed_from_outside(value: Variant) -> void:` |
| Set Field Value | Writes a new value to the property the look draws, as one undo step. | `set_field_value({value})` |
| Make Control Take Focus | Makes a control the one the keyboard focus lands on. | `add_focusable({control})` |
| The Field's Value | The value of the property the look draws, right now. | `field_value()` |

## Use cases

**1. A plain field that shows the value.** On Value Shown, set a label's text to the value. It is the smallest look there is and the one New inspector look starts you with.

**2. A star rating.** On Look Built, add five buttons. On Value Shown, fill as many stars as the value. A button's pressed event runs Set Field Value with its number.

**3. A progress bar.** On Look Built, add a progress bar. On Value Shown, set its value. The bounds are questions the Variable window asks.

**4. A row of arrows for a facing.** Four buttons, each runs Set Field Value with its direction; On Value Shown lights the one that matches.

**5. A battery for a charge level.** On Value Shown, pick the icon by range and set it on a texture rect.

**6. A thermometer.** The same shape as the bar, drawn with a tall fill instead of a long one.

**7. A countdown ring.** On Value Shown, set the ring's fill to the value over its total.

**8. A pill that is green, amber or red.** On Value Shown, tint a panel by where the value falls.

**9. A dial for a volume knob.** Wrap a dial control, show the value in it, and write it back with Set Field Value when it turns.

**10. A row of heart icons for lives.** On Value Shown, show as many hearts as the value.

**11. A strip of coloured dots for a difficulty level.** Five dots, the first few lit.

**12. A badge that shows a number.** A label over an icon, the number set in On Value Shown.

**13. A texture slot with a larger thumbnail.** The look works on `Texture2D` and draws a picture under the slot.

**14. A control the keyboard can reach.** Make Control Take Focus on the first button, so tabbing to the property lands on it.

**15. A value that resets a drag.** On Value Changed From Outside, put a half-made drag back, so undo never leaves a ghost.

**16. A readout of the property's own value in another row.** The Field's Value, dropped into any field of a row, reads what the Inspector holds.

**17. A look for a project's own resource.** `works_on` names the class, and every script that holds one gets the same control.

### Other use cases

**A look that shows two numbers at once.** Two labels, both set in On Value Shown from the one value.

**A look that clamps what is typed.** Set Field Value with the value kept between two bounds.

**A look that reads a sibling property.** The object the look draws is reachable, so a bar can show a value against its neighbour's maximum.

**A look that is only a caption.** A label that says what the property is for, with the plain field left to Godot.

**A look for a list.** `works_on` is `Array`, and the control is a small editor for its entries.

## Tips and common mistakes

- **Do not write a value from On Value Shown.** It runs on every refresh, so a write there refreshes again. Write from the control's own event.
- **A new look does not show.** The file must be in `res://eventsheet_addons/looks/`, extend `EventSheetInspectorLook`, and have a name that is a valid identifier.
- **The rows are not offered on an ordinary sheet.** They are for a look sheet; the picker only lists them there.
- **Do not add `class_name`.** The file name is the look's name, and the word the marker uses.
- **A shipped look opens read-only.** Use Copy into my project in the Variable window, then change your copy.
- **A look runs in the editor.** Its file starts with `@tool`; leave `eventsheet_addons/looks/` out of an exported game.
