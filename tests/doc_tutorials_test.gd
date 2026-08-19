# Godot EventSheets - THE MANUAL, batch 7: the tutorials you do, the sandbox they run in, the fixed
# shape of a reference page, what's new, the wayfinding and the reader's own language.
#
# Everything pinned here is a DECISION rather than a pixel, because no headless run lays anything
# out: which step a fixture sheet completes, what a scratch tab is called and why it closes without
# asking, the ORDER of a reference page's sections, the id What's new lives at, the sentence a
# search that found nothing prints, and which page a reader in another language is shown.
#
# The one thing that cannot be tested here is the live vocabulary - there is no registry outside a
# running editor - so the reference-shape tests pin the shape over rows the test supplies itself.
@tool
class_name DocTutorialsTest
extends RefCounted

## A pack that ships in this repo, for the property-table assertions.
const SAMPLE_PACK := "health"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_tutorial_catalogue() and all_passed
	all_passed = _test_step_completion() and all_passed
	all_passed = _test_walking_the_steps() and all_passed
	all_passed = _test_scratch_tabs() and all_passed
	all_passed = _test_reference_shape() and all_passed
	all_passed = _test_whats_new() and all_passed
	all_passed = _test_glossary_redirect() and all_passed
	all_passed = _test_feedback_and_text_size() and all_passed
	all_passed = _test_locale_fallback() and all_passed
	return all_passed


## The six tutorials the Manual opens with, and the shape of a step.
static func _test_tutorial_catalogue() -> bool:
	var all_passed: bool = true
	all_passed = _check("six tutorials ship",
		EventSheetDocTutorials.tutorials().size(), 6) and all_passed
	# R35. Writing a tool is something a beginner has to be able to FIND, not just be capable of.
	all_passed = _check("the editor-tool tutorial is one of them",
		str(EventSheetDocTutorials.tutorial("make-an-editor-tool").get("title", "")),
		"Make an editor tool with an event sheet") and all_passed
	all_passed = _check("it walks six steps",
		EventSheetDocTutorials.step_count("make-an-editor-tool"), 6) and all_passed
	all_passed = _check("the first one is the first event",
		str(EventSheetDocTutorials.tutorial("first-event").get("title", "")),
		"Your first event") and all_passed
	all_passed = _check("and it is six steps, the way the mockup draws it",
		EventSheetDocTutorials.step_count("first-event"), 6) and all_passed
	# The tour is step 0 - that is what stops a beginner having to choose between two front doors.
	all_passed = _check("the tour is step 0",
		str(EventSheetDocTutorials.step("first-event", 0).get("text", "")).begins_with(
			"Start with the tour"), true) and all_passed
	# Step 2 is the mockup's own card: "Now add an action ... Add Action".
	all_passed = _check("step 2 asks for an action",
		str(EventSheetDocTutorials.step("first-event", 2).get("check", "")),
		"sheet_has_action") and all_passed
	all_passed = _check("and names the real control",
		str(EventSheetDocTutorials.step("first-event", 2).get("control", "")),
		"Add Action") and all_passed
	all_passed = _check("a tutorial this build does not carry is an empty answer",
		EventSheetDocTutorials.tutorial("zz-no-such-tutorial").is_empty(), true) and all_passed
	all_passed = _check("and has no steps to walk",
		EventSheetDocTutorials.step_count("zz-no-such-tutorial"), 0) and all_passed
	# The card the reader reads.
	all_passed = _check("the caption says where they are",
		EventSheetDocTutorials.step_caption("first-event", 2),
		"YOUR FIRST EVENT · step 3 of 6") and all_passed
	all_passed = _check("the list prints how long it takes",
		EventSheetDocTutorials.progress_label("first-event", 0), "5 min") and all_passed
	all_passed = _check("and where they left it",
		EventSheetDocTutorials.progress_label("first-event", 2), "5 min · step 3 of 6") and all_passed
	return all_passed


## A step completes when the SHEET contains what it asked for. Pinned over a fixture sheet, one
## edit at a time, because that is the whole promise the card makes.
static func _test_step_completion() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	all_passed = _check("an empty sheet completes nothing",
		EventSheetDocTutorials.step_done("sheet_has_event", sheet), false) and all_passed
	var event: EventRow = EventRow.new()
	sheet.events.append(event)
	all_passed = _check("a row makes it an event",
		EventSheetDocTutorials.step_done("sheet_has_event", sheet), true) and all_passed
	all_passed = _check("but not an action yet",
		EventSheetDocTutorials.step_done("sheet_has_action", sheet), false) and all_passed
	var action: ACEAction = ACEAction.new()
	action.provider_id = "System"
	action.ace_id = "Print"
	event.actions.append(action)
	all_passed = _check("adding one completes the action step",
		EventSheetDocTutorials.step_done("sheet_has_action", sheet), true) and all_passed
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "System"
	condition.ace_id = "EveryXSeconds"
	event.conditions.append(condition)
	all_passed = _check("and a condition completes the condition step",
		EventSheetDocTutorials.step_done("sheet_has_condition", sheet), true) and all_passed
	# A beginner's first action legitimately lands inside a group, so the walk goes down.
	var nested_sheet: EventSheetResource = EventSheetResource.new()
	var band: EventRow = EventRow.new()
	var inner: EventRow = EventRow.new()
	inner.actions.append(action)
	band.sub_events.append(inner)
	nested_sheet.events.append(band)
	all_passed = _check("an action inside a group counts too",
		EventSheetDocTutorials.step_done("sheet_has_action", nested_sheet), true) and all_passed
	# The rest of the checks, each over the one thing it asks about.
	var extras: EventSheetResource = EventSheetResource.new()
	extras.variables = {"score": 0}
	all_passed = _check("a variable completes the variable step",
		EventSheetDocTutorials.step_done("sheet_has_variable", extras), true) and all_passed
	var included: Array[String] = ["health"]
	extras.uses_addons = included
	all_passed = _check("an included behavior completes the behavior step",
		EventSheetDocTutorials.step_done("sheet_has_behavior", extras), true) and all_passed
	extras.external_source_path = "res://game/player.gd"
	all_passed = _check("a sheet opened from a script completes the open step",
		EventSheetDocTutorials.step_done("sheet_is_opened_script", extras), true) and all_passed
	# A step with no check is never "done": it is one the reader reads and presses Next on, and
	# reporting it complete the moment it appears would be the card lying about what happened.
	all_passed = _check("a step with no check is never done on its own",
		EventSheetDocTutorials.step_done("", extras), false) and all_passed
	all_passed = _check("and a check this build does not know is not done either",
		EventSheetDocTutorials.step_done("sheet_has_sandwich", extras), false) and all_passed
	return all_passed


## Back and Next never run off either end, and the last step says Finish.
static func _test_walking_the_steps() -> bool:
	var all_passed: bool = true
	all_passed = _check("Next moves one step",
		EventSheetDocTutorials.moved_step("first-event", 2, 1), 3) and all_passed
	all_passed = _check("Back moves one back",
		EventSheetDocTutorials.moved_step("first-event", 2, -1), 1) and all_passed
	all_passed = _check("Back on the first step stays there",
		EventSheetDocTutorials.moved_step("first-event", 0, -1), 0) and all_passed
	all_passed = _check("Next on the last step stays there",
		EventSheetDocTutorials.moved_step("first-event", 5, 1), 5) and all_passed
	all_passed = _check("and the last step is the last step",
		EventSheetDocTutorials.is_last_step("first-event", 5), true) and all_passed
	all_passed = _check("while the one before it is not",
		EventSheetDocTutorials.is_last_step("first-event", 4), false) and all_passed
	# The card itself: a title, where the reader is, the step, and the three buttons.
	var blocks: Array[Dictionary] = EventSheetDocTutorials.step_blocks("first-event", 2)
	all_passed = _check("the card is titled by the tutorial",
		str(blocks[0].get("text", "")), "Your first event") and all_passed
	# One ROW of three, not three rows: a step card's three answers are one decision.
	var actions: PackedStringArray = PackedStringArray()
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) != "buttons":
			continue
		for item: Variant in (block.get("items", []) as Array):
			actions.append(str((item as Dictionary).get("action", "")))
	all_passed = _check("and carries Back, Skip and Next on one row",
		" ".join(actions), "tutorial_back tutorial_skip tutorial_next") and all_passed
	all_passed = _check("a tutorial that does not exist draws nothing",
		EventSheetDocTutorials.step_blocks("zz-no-such-tutorial").is_empty(), true) and all_passed
	# The list, and the way in.
	var list: Array[Dictionary] = EventSheetDocTutorials.list_blocks()
	var chapters: int = 0
	for block: Dictionary in list:
		if str(block.get("kind", "")) == "heading" and int(block.get("level", 0)) == 2:
			chapters += 1
	all_passed = _check("the list has one chapter per tutorial", chapters, 6) and all_passed
	all_passed = _check("the list lives at a frozen id",
		EventSheetDocTutorials.LIST_DOC_ID, "reference:tutorials") and all_passed
	all_passed = _check("and one tutorial at its own",
		EventSheetDocTutorials.doc_id("first-event"), "reference:tutorial/first-event") and all_passed
	all_passed = _check("the router accepts it",
		bool(EventSheetDocExplain.resolve("reference:tutorial/first-event").get("valid", false)),
		true) and all_passed
	all_passed = _check("and refuses one this build does not carry",
		EventSheetDocReference.has_page("reference:tutorial/zz-nope"), false) and all_passed
	all_passed = _check("the trail says which part of the Manual it is",
		" ▸ ".join(Array(EventSheetDocReference.breadcrumb("reference:tutorial/first-event",
			"Your first event"))),
		"Manual ▸ Tutorials ▸ Your first event") and all_passed
	return all_passed


## What makes a tab scratch, what it is called, and why it closes without asking.
static func _test_scratch_tabs() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	all_passed = _check("an ordinary sheet is not scratch",
		EventSheetDocScratch.is_scratch(sheet), false) and all_passed
	all_passed = _check("and closing it asks the usual question",
		EventSheetDocScratch.closes_without_asking(sheet), false) and all_passed
	EventSheetDocScratch.mark(sheet, "Wait For Signal")
	all_passed = _check("marking it makes it one",
		EventSheetDocScratch.is_scratch(sheet), true) and all_passed
	all_passed = _check("it remembers the example it holds",
		EventSheetDocScratch.example_name(sheet), "Wait For Signal") and all_passed
	all_passed = _check("the tab reads as the mockup draws it",
		EventSheetDocScratch.tab_title("Wait For Signal"), "✎ Scratch - Wait For Signal") and all_passed
	all_passed = _check("an unnamed example is still a scratch tab",
		EventSheetDocScratch.tab_title(""), "✎ Scratch") and all_passed
	all_passed = _check("and it closes without asking",
		EventSheetDocScratch.closes_without_asking(sheet), true) and all_passed
	# Save As gives it a home, and a sheet with a home is not a scratch pad any more.
	EventSheetDocScratch.claim_saved(sheet)
	all_passed = _check("saving it somewhere ends that",
		EventSheetDocScratch.is_scratch(sheet), false) and all_passed
	all_passed = _check("and the close guard comes back",
		EventSheetDocScratch.closes_without_asking(sheet), false) and all_passed
	all_passed = _check("the button says what it does",
		EventSheetDocScratch.try_it_label(), "Try it in a scratch sheet") and all_passed
	return all_passed


## THE FIXED SHAPE: Properties, Conditions, Actions, Expressions, Triggers, in that order, on every
## page, and every table icon / name / parameters / one-line description.
static func _test_reference_shape() -> bool:
	var all_passed: bool = true
	all_passed = _check("the section order is the fixed one",
		" ".join(PackedStringArray(EventSheetDocReference.GROUP_ORDER)),
		"Properties Conditions Actions Expressions Triggers") and all_passed
	var grouped: Dictionary = {
		"Properties": [{"name": "max hp", "params": "100", "note": ""}],
		"Conditions": [{"name": "Is Dead", "params": "", "note": "True once hp reaches zero."}],
		"Actions": [{"name": "Damage", "params": "amount", "note": "Takes hp away."}],
	}
	all_passed = _check("a page with blurbs draws four columns",
		" ".join(EventSheetDocReference.table_columns(grouped)),
		"Mark Verb Parameters What it does") and all_passed
	all_passed = _check("and its property table names its own two middle columns",
		" ".join(EventSheetDocReference.table_columns(grouped, "Properties")),
		"Mark Property Default What it does") and all_passed
	var bare: Dictionary = {"Actions": [{"name": "Do It", "params": "", "note": ""}]}
	all_passed = _check("a page without blurbs leaves the last column out",
		" ".join(EventSheetDocReference.table_columns(bare)), "Mark Verb Parameters") and all_passed
	# The mark leads every row, and it is the sheet's own glyph for that kind.
	var rows: Array = EventSheetDocReference.table_rows(
		[{"name": "Is Dead", "params": "", "doc_id": "ace:P/is_dead"}], false,
		str(EventSheetDocReference.GROUP_MARKS.get("Conditions", "")))
	all_passed = _check("a condition row wears the diamond",
		str((rows[0] as Array)[0]), "◆") and all_passed
	all_passed = _check("and still links to its entry",
		str((rows[0] as Array)[1]), "[url=ace:P/is_dead]Is Dead[/url]") and all_passed
	all_passed = _check("an action wears the arrow",
		str(EventSheetDocReference.GROUP_MARKS.get("Actions", "")), "➜") and all_passed
	all_passed = _check("an expression the function sign",
		str(EventSheetDocReference.GROUP_MARKS.get("Expressions", "")), "ƒ") and all_passed
	all_passed = _check("a trigger the recurrence mark",
		str(EventSheetDocReference.GROUP_MARKS.get("Triggers", "")), "⟳") and all_passed
	# A behavior's Properties come off its own scripts, so the page can never invent a knob.
	var knobs: Array = EventSheetDocAceReference.property_rows(SAMPLE_PACK)
	all_passed = _check("a shipped behavior lists designer knobs",
		knobs.is_empty(), false) and all_passed
	all_passed = _check("a pack that is not installed lists none",
		EventSheetDocAceReference.property_rows("zz_no_such_pack").is_empty(), true) and all_passed
	# And the page itself puts Properties first.
	var page: Array[Dictionary] = EventSheetDocReference.blocks_for("pack", SAMPLE_PACK)
	var first_section: String = ""
	for block: Dictionary in page:
		if str(block.get("kind", "")) == "heading" and int(block.get("level", 0)) == 2:
			first_section = str(block.get("text", ""))
			break
	all_passed = _check("a behavior page opens with Properties",
		first_section, "Properties") and all_passed
	return all_passed


## What's new: the id it lives at, what the extraction takes, and the dot.
static func _test_whats_new() -> bool:
	var all_passed: bool = true
	all_passed = _check("it lives at a frozen id",
		EventSheetDocReference.doc_id(EventSheetDocReference.KIND_WHATS_NEW), "reference:whatsnew") and all_passed
	all_passed = _check("the router accepts it",
		bool(EventSheetDocExplain.resolve("reference:whatsnew").get("valid", false)), true) and all_passed
	all_passed = _check("it is titled the way an editor says it",
		EventSheetDocReference.title_for(EventSheetDocReference.KIND_WHATS_NEW, ""),
		"What's new") and all_passed
	# The extraction, over a fixture changelog rather than over whatever the repo says this week.
	var changelog: String = "# Changelog\n\n## [Unreleased]\n\n### Added\n\nA thing.\n\n## [1.2.0] - 2026-01-01\n\n### Fixed\n\nAnother thing.\n\n## [1.1.0] - 2025-12-01\n\n### Fixed\n\nOld news.\n"
	var page: String = EventSheetDocWhatsNew.page_markdown(changelog, "1.2.0")
	all_passed = _check("the page is titled What's new",
		page.begins_with("# What's new"), true) and all_passed
	all_passed = _check("it carries the unreleased section",
		page.contains("## Unreleased"), true) and all_passed
	all_passed = _check("and the last release",
		page.contains("## 1.2.0 - 2026-01-01"), true) and all_passed
	all_passed = _check("with its notes under it",
		page.contains("Another thing."), true) and all_passed
	all_passed = _check("and nothing older than that",
		page.contains("Old news."), false) and all_passed
	all_passed = _check("the baked file carries its frozen header",
		EventSheetDocWhatsNew.bundle_text(changelog, "1.2.0").begins_with(
			EventSheetDocWhatsNew.BUNDLE_HEADER), true) and all_passed
	# The dot: unread until this build's notes have been opened.
	all_passed = _check("a reader who never opened it gets the dot",
		EventSheetDocWhatsNew.has_unread("0.18.0", ""), true) and all_passed
	all_passed = _check("so does one who last read an older build",
		EventSheetDocWhatsNew.has_unread("0.18.0", "0.17.0"), true) and all_passed
	all_passed = _check("and one who has read this one does not",
		EventSheetDocWhatsNew.has_unread("0.18.0", "0.18.0"), false) and all_passed
	# The shipped bundle really carries the page, or the reader would open a blank one.
	EventSheetDocWhatsNew.reload()
	all_passed = _check("the page ships inside the plugin",
		EventSheetDocWhatsNew.markdown().begins_with("# What's new"), true) and all_passed
	return all_passed


## "Looking for layout? Here it is called Scene" - said BEFORE the empty list, and only for a word
## this glossary really knows.
static func _test_glossary_redirect() -> bool:
	var all_passed: bool = true
	var redirect: Dictionary = EventSheetDocGlossary.redirect_for("layout")
	all_passed = _check("a word from another editor is redirected",
		str(redirect.get("line", "")), "Looking for layout? Here it is called Scene") and all_passed
	all_passed = _check("and it names the page to open",
		str(redirect.get("key", "")), "layout") and all_passed
	all_passed = _check("the match is case-insensitive",
		str(EventSheetDocGlossary.redirect_for("Layout").get("here", "")), "Scene") and all_passed
	all_passed = _check("a word this editor spells the same is not redirected",
		EventSheetDocGlossary.redirect_for("sub-event").is_empty(), true) and all_passed
	all_passed = _check("nor is a word nobody has",
		EventSheetDocGlossary.redirect_for("zznotaword").is_empty(), true) and all_passed
	all_passed = _check("nor an empty search",
		EventSheetDocGlossary.redirect_for("").is_empty(), true) and all_passed
	# An entry whose explanation is a sentence rather than a name has nothing to redirect TO.
	all_passed = _check("an entry that explains rather than renames offers no word",
		EventSheetDocGlossary.here_word(
			"A condition on an object filters which instances the actions below it run on."),
		"") and all_passed
	return all_passed


## The foot of the page: the answer, the tracker URL, and the text-size ramp.
static func _test_feedback_and_text_size() -> bool:
	var all_passed: bool = true
	all_passed = _check("an unanswered page says nothing",
		EventSheetDocFeedback.answer_line(EventSheetDocFeedback.UNSET), "") and all_passed
	all_passed = _check("a yes says where it went",
		EventSheetDocFeedback.answer_line(EventSheetDocFeedback.YES).contains("sent nowhere"),
		true) and all_passed
	# The tracker: the page named in the title, and nothing else prefilled.
	var url: String = EventSheetDocFeedback.report_url(
		"https://example.invalid/project", "Working with Lists", "guide:GUIDE-WORKING-WITH-LISTS")
	all_passed = _check("Report a problem opens a NEW issue on the project",
		url, "https://example.invalid/project/issues/new?title=Manual%3A%20Working%20with%20Lists") and all_passed
	all_passed = _check("a page with no title falls back to its id",
		EventSheetDocFeedback.report_url("https://example.invalid/p", "", "reference:legend").contains(
			"reference"), true) and all_passed
	all_passed = _check("no repository is no button",
		EventSheetDocFeedback.report_url("", "Anything", "guide:X"), "") and all_passed
	# The ramp ends rather than wraps.
	all_passed = _check("A+ steps up", EventSheetDocFeedback.stepped_scale(1.0, 1), 1.1) and all_passed
	all_passed = _check("A- steps down", EventSheetDocFeedback.stepped_scale(1.0, -1), 0.9) and all_passed
	all_passed = _check("A+ at the top does nothing",
		EventSheetDocFeedback.stepped_scale(EventSheetDocFeedback.MAX_SCALE, 1),
		EventSheetDocFeedback.MAX_SCALE) and all_passed
	all_passed = _check("A- at the bottom does nothing",
		EventSheetDocFeedback.stepped_scale(EventSheetDocFeedback.MIN_SCALE, -1),
		EventSheetDocFeedback.MIN_SCALE) and all_passed
	all_passed = _check("and the size says itself",
		EventSheetDocFeedback.scale_label(1.2), "120%") and all_passed
	return all_passed


## The Manual per locale: the reader's own copy when it ships, English when it does not, and the
## note that says so.
static func _test_locale_fallback() -> bool:
	var all_passed: bool = true
	var available: PackedStringArray = PackedStringArray([
		"GUIDE-RECIPES", "GUIDE-THEMING", "fr/GUIDE-RECIPES"])
	all_passed = _check("a translated page is shown in that language",
		EventSheetDocLocale.page_for("GUIDE-RECIPES", "fr", available), "fr/GUIDE-RECIPES") and all_passed
	all_passed = _check("an untranslated one falls back to English",
		EventSheetDocLocale.page_for("GUIDE-THEMING", "fr", available), "GUIDE-THEMING") and all_passed
	all_passed = _check("an English reader is never prefixed",
		EventSheetDocLocale.page_for("GUIDE-RECIPES", "en", available), "GUIDE-RECIPES") and all_passed
	all_passed = _check("and a page that is already a translation is itself",
		EventSheetDocLocale.page_for("fr/GUIDE-RECIPES", "fr", available), "fr/GUIDE-RECIPES") and all_passed
	all_passed = _check("a page id says which language it is in",
		EventSheetDocLocale.locale_of("fr/GUIDE-RECIPES"), "fr") and all_passed
	all_passed = _check("an unprefixed one is English",
		EventSheetDocLocale.locale_of("GUIDE-RECIPES"), "en") and all_passed
	# A doc SET is not a locale, which is what stops "Addons/Quest" reading as a translation.
	all_passed = _check("a doc set is not a locale",
		EventSheetDocLocale.locale_of("Addons/Quest"), "en") and all_passed
	all_passed = _check("a region code is a locale",
		EventSheetDocLocale.is_locale_prefix("zh_CN"), true) and all_passed
	all_passed = _check("a Title Case directory is not",
		EventSheetDocLocale.is_locale_prefix("Modules"), false) and all_passed
	# The note, and when it is drawn.
	all_passed = _check("English readers never see the note",
		EventSheetDocLocale.note_block("GUIDE-THEMING", "en").is_empty(), true) and all_passed
	all_passed = _check("a reader on a translated page does not either",
		EventSheetDocLocale.note_block("fr/GUIDE-RECIPES", "fr").is_empty(), true) and all_passed
	all_passed = _check("a reader shown English instead does",
		EventSheetDocLocale.note_block("GUIDE-THEMING", "fr").is_empty(), false) and all_passed
	all_passed = _check("and it asks rather than apologises",
		EventSheetDocLocale.note_text(), "This page is not translated yet - help translate it") and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doc_tutorials_test: %s" % label)
		return true
	print("[FAIL] doc_tutorials_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
