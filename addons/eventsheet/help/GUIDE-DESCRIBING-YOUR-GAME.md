# Describing Your Game

Six weeks after you write a function you will not remember what it was for. That is not a discipline problem: the moment writing the sentence is cheap - while the function is being made - is exactly the moment nobody wants to stop and write prose, and by the time anybody wants the prose the function is old.

So this is not a documentation feature. It is one line per thing you made, kept where the file already keeps it, drafted for you out of the thing's own rows, and read back in every place the thing is listed.

## Table of Contents

1. [One description, and where it lives](#1-one-description-and-where-it-lives)
2. [No description yet](#2-no-description-yet)
3. [Drafts, out of the rows themselves](#3-drafts-out-of-the-rows-themselves)
4. [Describe the undescribed, and the drift note](#4-describe-the-undescribed-and-the-drift-note)
5. [Your Game: the manual that writes itself](#5-your-game-the-manual-that-writes-itself)
6. [The Project View](#6-the-project-view)
7. [Find across every sheet](#7-find-across-every-sheet)
8. [After a merge](#8-after-a-merge)

---

## 1. One description, and where it lives

A function, a variable, a group, a signal and the sheet itself can each carry one description. It is the `##` documentation comment the generated GDScript already writes directly above the declaration - not a field this plugin invented, and not a second copy of anything.

That has three consequences worth stating plainly:

- **Typing it in a dialog and typing it in the file are the same act.** Write it in the Function dialog's Doc comment field, or open the `.gd` and type the `##` line yourself. Both end up in the same place.
- **It survives.** Uninstall the plugin and the words are still in the file, doing what `##` lines do in any Godot project: showing in the editor's built-in help and in tooltips.
- **Two places can never disagree**, because there is only one place.

Where the line sits per kind, following what the file already does rather than imposing a shape on it:

| The thing | Where its one description lives |
| --- | --- |
| the sheet | the `##` block right after `extends` (Godot's class-doc position) |
| a plain function | its `##` block |
| a function published as a verb | its `## @ace_description(...)` line, because that is the text the picker shows |
| a variable | the `##` line above the declaration, which is also its Inspector tooltip |
| a signal | the `##` prose above its annotation block |
| a group | the group header's `description=` field - a group has no GDScript declaration to sit above |

## 2. No description yet

A thing with no description reads **"no description yet"**, in soft type, wherever it is listed - the Functions list, the manual page, the Project View.

It is a nudge and not a warning. Nothing is blocked, no count goes red, and a game with no descriptions at all works exactly as well as one with all of them. The point of showing it is that it appears while you are already looking at the thing, which is the one moment writing the line is cheap.

## 3. Drafts, out of the rows themselves

A function that raises hp and flashes an icon already says what it does; the words are just spread over its rows. So a description can be drafted from the rows:

> Set self.hp = hp - amount; print hit

Each row's sentence, in the words the row already shows, joined into one line. Groups draft from what their rows react to; the sheet head drafts from its groups; a parameter drafts from the first row that uses it.

Four things are true of every draft:

- **It is deterministic.** The same rows compose the same sentence, on every machine and in every run. No model, no network, no clock.
- **It is honest.** A block of hand-written code the editor cannot read as a sentence composes to *"runs its own code"* - true, and it tells you the rest of the story is in the file. A draft that flattered itself would be worse than no draft, because you would stop looking.
- **It lists what is there and counts the rest.** A function of forty actions names its first steps and then says how many more, rather than composing a forty-clause sentence.
- **It is never written on its own.** A draft is composed fresh each time it is shown and stored nowhere, so it cannot overwrite words you wrote and there is nowhere for a stale one to hide. In the Function dialog it appears under the Doc comment field with a **Use this draft** button; pressing it fills the field, where you edit it before saving.

## 4. Describe the undescribed, and the drift note

The Project Doctor grows a page: every describable thing with no line, each carrying the draft its own rows compose. Notes only - a project that ignores the whole page is a working project.

Beside it is the note a stored document could never write about itself. A description you accepted describes the rows **as they were**. Replace those rows and the words go on sounding authoritative while being wrong, which is worse than the gap, because a reader believes them. So a function whose description no longer names anything its rows do is listed, with a fresh draft beside the old words, and you decide.

Rewording is not drift. "Takes amount off hp, however much armour says" still talks about `hp` and `amount`, so nothing is said about it. Only losing the subject counts.

## 5. Your Game: the manual that writes itself

Beside the plugin's Manual is a page per sheet of yours: what it is, what it remembers, what it can be asked to do, what it announces, and how its rules are grouped.

It is composed the moment you open it and stored nowhere, so it cannot become the usual project documentation - written once, wrong within a month. A function you renamed a minute ago is renamed on the page.

The footer states coverage as a fact:

> 3 of 6 described.
>
> Still to describe: `variable:max_hp`, `function:hurt`, `group:Damage`.

No colour, no bar, no grade. The number is there so you can find the three, not so anybody is scored on them.

Exported, a page is Markdown, and the same sheet writes the same bytes every time - so a team can commit these pages and read what changed about their game in a pull request.

## 6. The Project View

**Tools ▸ Project View…** puts every open sheet on one page.

![The Project View: every sheet with its events, description coverage, findings and measured milliseconds, the search across every sheet, and the selected sheet's own page](images/project-view.png)

Every column is a number that already existed somewhere - the sheet's own rows, the Doctor's findings, a stored profiler run, the reading coverage the opened-script banner shows. The join happens once when the window opens. It is not a new scan of your project, and it does not run per frame.

One detail is deliberate: a sheet nobody profiled shows an **empty** milliseconds cell rather than a zero. Zero milliseconds is a claim about that sheet, and nobody measured it.

## 7. Find across every sheet

A name is not one thing. `hp` written is a different fact from `hp` read and from `hp` compared, and when you are hunting a bug you usually know which one you want - so the facet says which:

- **written** - a row that assigns it
- **read** - a row that uses its value
- **compared** - a condition that tests it
- **node**, **animation**, **mode** - the same name as a node reference, an animation, or a game mode

Every hit names the sheet and the function or group it sits in, so it reads as a place to go rather than a line number.

## 8. After a merge

A sheet opened from a file that a merge left damaged does not quietly pick a side. The row goes amber and shows **both** parents' spellings, labelled with the branches they came from, and the sentence beside it names neither as the right one - because the plugin does not know, and a guess printed there would be taken for an answer.
