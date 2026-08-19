# Making Web Requests

**AJAX** is the object a sheet talks to when the game needs something from a server: a leaderboard,
a daily seed, a patch note, a login check. It has two things it does - **Request** (ask a server for
something) and **Post** (send a server something) - and two things it says back: whether the request
**succeeded**, and what came back, as **AJAX.LastData**.

Underneath, all of it is Godot's `HTTPRequest` node. The rows write exactly the calls you would write
by hand, which means two things worth having: a request built from the picker compiles to plain
Godot with no runtime library behind it, and an existing script that already talks to a server opens
as a sheet and reads back as these same rows.

The answer does not arrive on the row that asked for it. A request is sent now and answered later,
so the row that asks and the rows that read the answer are two different events, joined by the
request node's `request_completed` signal - which the sheet wires up the way it wires any other node
signal. Everything on this page assumes that shape.

A server almost always answers in JSON, so the **JSON** object is this page's other half: **Parse**
turns text into a table, **ToString** turns a table into text. Both live in the picker beside the
AJAX rows.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Leaderboards** - post a score at the end of a run, read the top ten on the menu.
- **Daily challenges** - ask a server for today's seed so every player gets the same level.
- **Live content** - news, patch notes, an event banner, fetched when the title screen opens.
- **Analytics and telemetry** - post what happened, without blocking the game while it sends.
- **Accounts and saves in the cloud** - a login check, a save slot read back on another machine.
- **Reading an existing networked script** - it opens as these rows instead of as `HTTPRequest` calls.

## Core concepts

- **One node does the asking.** An `HTTPRequest` node in your scene is what actually talks to the
  network. Every row takes it as its first field, and `$HTTPRequest` - a node sitting beside the
  sheet's own node - is the arrangement it arrives assuming.
- **A request is asked now and answered later.** The row returns immediately. Nothing you do on the
  next row has the answer yet.
- **The answer arrives as a signal with four values.** The result (did it reach the server at all),
  the status code (what the server said about it), the headers, and the body as raw bytes.
- **Result and status are different questions.** **Request succeeded** asks whether the request got
  there and came back. A 404 is a successful request that was answered with "no".
- **The body is bytes until you say otherwise.** **AJAX.LastData** is the row that reads those bytes
  back as text - which is what you then hand to **JSON Parse**.
- **Posting sends text.** Build the body with **JSON ToString** and hand it to **Post**; the row
  writes the POST spelling Godot wants.
- **One request at a time per node.** An `HTTPRequest` that is already busy refuses a second ask.
  Two things asking at once want two nodes.
- **Nothing here retries for you.** A request that fails, fails once; retrying is a row you write.

## Reference tables

| Name | Kind | What it does |
| --- | --- | --- |
| Request | Action | Asks a server for something at a URL. |
| Post | Action | Sends data to a URL. |
| Cancel Request | Action | Stops a request that is still in flight. |
| Request Succeeded | Condition | True when the request reached the server and came back. |
| Status Is OK | Condition | True when the server answered 200. |
| Last Data | Expression | The answer that just arrived, as text. |

## Use cases

**1. Fetch a leaderboard on the menu.** On start of layout, **AJAX ▸ Request** the scores URL. In
the completed event, check **request succeeded**, read **AJAX.LastData**, **JSON Parse** it, and fill
the labels.

**2. Post a score at the end of a run.** Build a table with the name and the number, **JSON
ToString** it, and **AJAX ▸ Post** it to the submit URL.

**3. Today's seed.** Request a tiny endpoint that answers with one number, and hand it to the random
generator so every player gets the same level today.

**4. A news banner on the title screen.** Request a text file, put **AJAX.LastData** straight into a
label, and leave the banner empty when the request did not succeed.

**5. Check the game is up to date.** Request a version file, compare it with the project's version,
and show an "update available" line when they differ.

**6. A login check.** Post the name and password to a login endpoint and branch on **Status Is OK**.
Never store a password in the sheet; read it from the field the player typed into.

**7. Cloud saves.** Post the save table as JSON when the player quits, and request it back when they
sign in on another machine.

**8. Telemetry that never stalls the game.** Post the level and the time taken at the end of each
level and ignore the answer entirely - a post you do not read is still a post that arrived.

**9. A patch-note popup.** Request a markdown file, show it in a dialog, and remember the version you
last showed so it only appears once per patch.

**10. Remote config.** Request a small JSON table of numbers - drop rates, event multipliers - and
read them with the possessive rows instead of shipping a new build.

**11. A server-driven event calendar.** Request a list of dates, walk it with a For-each, and switch
the theme on when today is in the list.

**12. Retry once on failure.** When **request succeeded** is inverted, wait a second and Request
again, with a counter so it gives up after three tries.

**13. Cancel a request the player walked away from.** On leaving the menu, **Cancel Request** so a
late answer cannot fill in labels that are gone.

**14. Two requests at once.** Two `HTTPRequest` nodes, two completed events - the scores and the
news arrive independently and neither waits for the other.

**15. Read the status separately from the result.** Branch on **Status Is OK** inside the
succeeded event, so "the server said no" and "the network is down" show different messages.

**16. Open somebody else's networked script.** A hand-written `HTTPRequest` file opened as a sheet
reads as these rows already, which is usually the fastest way to see what it asks for.

### Other use cases

**A daily-reward check** that asks the server what day it is, so changing the device clock does not help.

**A community leaderboard filter** that posts a country code and reads only that country's rows.

**A crash reporter** that posts the last few log lines when the game restarts after a bad exit.

**A feature flag** that lets you turn an unfinished mode off in a live build without patching.

**A tiny content pack** fetched as JSON and used to add levels between releases.

## Tips and common mistakes

- **The answer is not on the next row.** If a row after Request reads **AJAX.LastData** and gets
  nothing, that is why: the answer arrives in the completed event.
- **Check the result before you read anything.** The very first row of a completed event should be
  the inverted **request succeeded** with a Stop event under it.
- **A 404 is a successful request.** Result and status answer different questions, and a page that
  says "your score was saved" on a 404 is the classic version of this bug.
- **Parse can fail.** A server that answers with an error page gives you HTML, not JSON, and
  **JSON Parse** hands back nothing. Guard the parsed value before reading fields out of it.
- **One node, one request.** Asking again while a node is busy quietly does nothing. Two things
  asking at once need two nodes.
- **Do not put secrets in the sheet.** An API key in a row ships inside the game. Anything that must
  stay secret belongs on a server you control.
- **The web export is stricter.** A browser refuses requests to other sites unless that site allows
  it. A request that works in the editor and not in a web build is nearly always this.
- **Nothing retries for you.** Networks fail; a game that shows an empty leaderboard forever after
  one bad request is a game missing one retry row.
