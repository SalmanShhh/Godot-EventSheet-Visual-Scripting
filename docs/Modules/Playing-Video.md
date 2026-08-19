# Playing Video

**Video** is the object a sheet talks to when a film has to play inside the game: a logo on boot, an
intro before the menu, a cutscene between levels, a looping background behind a title. It has four
verbs - **Set Video**, **Play**, **Pause**, **Stop** - and one question, **Is playing**.

Underneath it is Godot's `VideoStreamPlayer` node. The rows write exactly the calls you would write
by hand, so a film driven from the picker compiles to plain Godot with no runtime library behind it,
and a hand-written player opened as a sheet reads back as these same rows.

Godot plays **Ogg Theora** (`.ogv`) out of the box, and nothing else without an add-on. That one fact
decides most of what this page has to say: a film has to be converted before it is imported, it will
be large, and it will not have alpha.

Whether a film has ENDED is a signal on the node (`finished`), which the sheet wires up the way it
wires any other node signal - so "play the intro, then open the menu" is two events, not one row.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Boot logos** - the two seconds before the title screen, skippable on any key.
- **Intros and cutscenes** - a pre-rendered sequence between levels, with the game paused behind it.
- **Animated backgrounds** - a slow loop behind a menu, quieter than a particle system.
- **Tutorial clips** - a short recording of the thing the text is describing.
- **Endings** - the reward film, played once and remembered.
- **Reading an existing script** - a hand-written player opens as these rows.

## Core concepts

- **One node shows the film.** A `VideoStreamPlayer` in your scene is what actually plays. Every row
  takes it as its first field, and `$VideoStreamPlayer` is the arrangement it arrives assuming.
- **Set Video loads, Play starts.** They are two rows because a film is often loaded once on start of
  layout and played much later.
- **Pause holds the frame; Stop rewinds.** Pausing keeps the picture where it is, so playing again
  carries on. Stopping goes back to the beginning.
- **The row names the file.** **Set video to intro.ogv** - the folders in front of it are filing, not
  part of what the row says.
- **Finishing is a signal.** The node emits `finished` when the film runs out; wire it up and the
  next event is what happens after.
- **Is playing is false when paused.** It answers "is the picture moving", which is the question a
  skip button and a HUD actually ask.
- **The audio is inside the film.** A `.ogv` carries its own sound; the music bus does not control
  it unless you route the player through one.
- **Only `.ogv` plays.** Godot ships one video format. Anything else is a conversion step before it
  is ever a row.

## Reference tables

| Name | Kind | What it does |
| --- | --- | --- |
| Set Video | Action | Loads a film into the player. |
| Play Video | Action | Starts the film from where it stands. |
| Pause Video | Action | Holds the film on its current frame, or lets it run on again. |
| Stop Video | Action | Stops the film and rewinds it to the beginning. |
| Video Is Playing | Condition | True while the film is running. |

## Use cases

**1. A boot logo.** On start of layout, **Set Video** the logo and **Play**. Wire the player's
finished signal to an event that goes to the title layout.

**2. A skippable intro.** The same shape, plus an event on any key pressed that does **Stop** and
goes to the next layout - so the skip and the natural end both land in one place.

**3. A cutscene between levels.** Play the film on a full-screen player over the paused game, and let
the finished signal load the next level.

**4. An animated menu background.** Play a short loop on start of layout and wire finished back to
**Play**, so it starts again the moment it ends.

**5. Pause when the game pauses.** In the pause event, **Pause Video**; in the resume event, pause it
false - the frame is exactly where the player left it.

**6. A tutorial clip beside the text.** Set the clip when the tutorial page opens, play it, and stop
it when the page closes so it is not still running behind the next one.

**7. A reward film played once.** Guard the play row with a saved flag so the ending plays the first
time and never again.

**8. A "now loading" film.** Play a short loop while a background load runs, and stop it when the
loaded layout is ready.

**9. Mute the film when the game is muted.** Route the player through the music bus, so the options
screen's volume rows reach it like everything else.

**10. Show a skip prompt only while it is playing.** Guard the prompt label's visibility on **Is
playing**, so it disappears the moment the film ends.

**11. A per-language intro.** Choose the file from the current locale and **Set Video** to it, so the
subtitled version plays where it should.

**12. A demo attract loop.** After a minute of no input on the title screen, play the demo film, and
stop it on the first key press.

**13. A film behind a transparent HUD.** Put the player under the HUD layer; the rows are the same
and the interface draws over the picture.

**14. Test the whole sequence from one row.** A debug key that sets the film and plays it saves
reloading the project every time you re-encode it.

**15. Stop everything on quit to menu.** A single **Stop Video** in the quit event keeps a film from
carrying on behind the menu that replaced it.

**16. Open an existing player script.** A hand-written `VideoStreamPlayer` file opened as a sheet
reads as these rows, which is the quickest way to see what it plays and when.

### Other use cases

**A results-screen replay** stitched from clips chosen by how the run went.

**A seasonal title background** swapped by date without touching a single other row.

**An in-game television** playing a loop on a quad in a 3D scene.

**A "what's new" clip** shown once per version, remembered like a patch note.

**A recorded credits roll**, which is far cheaper to make than an animated one.

## Tips and common mistakes

- **Only `.ogv` plays.** An `.mp4` dragged into the project will not import. Convert first; that is
  the single most common surprise here.
- **Video files are big.** A minute of Ogg Theora at a readable quality is tens of megabytes, and it
  ships in the export. Keep films short and the resolution modest.
- **There is no alpha.** Ogg Theora has no transparency, so a film cannot be laid over the game with
  a see-through background.
- **Seeking is unreliable.** Theora does not scrub well; build sequences out of several short films
  rather than jumping around inside one.
- **Nothing loops for you.** A film that should repeat needs its finished signal wired back to Play.
- **Is playing is false while paused.** If a skip prompt vanishes when the player pauses, that is why.
- **The web export may refuse it.** Browsers are stricter about video decoding; test a web build
  before a film becomes load-bearing.
- **Stop it before you change layouts.** A player left running while the scene changes can keep its
  sound going for a moment, which reads as a bug and is one row to fix.
