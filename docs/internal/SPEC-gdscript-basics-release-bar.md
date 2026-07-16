# SPEC: GDScript-basics coverage - the bar for the first public release

Status: PROPOSAL + coverage audit. The release rule proposed: EventSheets is ready to announce
as "a visual scripting solution for Godot" when EVERY feature on the official GDScript basics
page (docs.godotengine.org, gdscript_basics, 4.x) is authorable AND readable (round-trips) in
the condition/action model - beginner phrasing first, raw code never required for the basics.
Date: 2026-07-17

## Why this page is the bar

The basics page is what every Godot beginner reads first. If a sheet can express everything on
it, a jam project never hits a wall where "now you must write code"; anything beyond the page
(networking, shaders, servers) is legitimately pack/expert territory. Speed-to-game stays the
goal: each row below must be readable as a sentence, not a code fragment in a box.

## Coverage audit (page feature -> lane mapping -> status)

DONE = authorable + lifts back byte-gated. PARTIAL = works but not beginner-phrased or not
surfaced. GAP = needs work before release.

| Page feature | Lane mapping | Status |
| --- | --- | --- |
| Variables (typed/inferred) | variable rows + friendly types | DONE |
| Constants, local const | Set Local Constant action | DONE |
| Enums | enum rows + "+" field editor | DONE |
| Functions, params, returns | EventFunction blocks + dialog | DONE |
| Static functions/vars | static rows (G3/G4) | DONE |
| if/elif/else | conditions + Else/Else-If chips | DONE |
| match | switch/case block | DONE |
| for / while / break / continue | loop ACEs + G2 lift | DONE |
| Arrays / Dictionaries | Variables: Array/Dictionary ACEs (41) | DONE |
| Signals (declare/emit/connect) | SignalRow + On Signal/Emit/Connect | DONE |
| await / coroutines | Wait/Wait For Signal ACEs | DONE |
| Lambdas / Callables | LambdaValue/CallableFromMethod/Bind | DONE |
| Properties (set/get) | setter/getter property block | DONE |
| @export family | full export coverage + Inspector-look picker | DONE |
| @onready | dialog checkbox + lift | DONE |
| Doc comments (##) | doc-comment fields + BBCode dialog | DONE |
| Typed arrays (Array[int]) | type dropdown offers them | PARTIAL - authoring OK; picker
|  |  | phrasing is raw ("Array[int]" not "List of Numbers"). Beginner alias pass. |
| String formatting (%, format) | FormatString / Set Text (formatted) | PARTIAL - both exist
|  |  | but printf-phrased ("Score: %d"). Add a featured "Text From Pattern" using {name}
|  |  | placeholders (compiles to .format()) so beginners never meet %d. |
| Ternary (x if c else y) | Choose/ternary helper exists | PARTIAL - not featured; picker
|  |  | phrasing "Value If" + display template review. |
| null / nullable checks | Is Null/Is Valid ACEs | DONE |
| Inner classes | data-class block (view level) | PARTIAL - full nested classes stay
|  |  | verbatim (deliberate; document as expert territory, not a release blocker). |
| Multiline enums w/ values | lifts verbatim | GAP (deferred earlier) - needed? The page shows
|  |  | plain enums only -> reclassify NOT A BLOCKER, document. |
| @tool | tool_mode sheet type | DONE |
| Operators incl. **, %, bit ops | expression builder | PARTIAL - expression builder covers
|  |  | them; add the missing few to the operator palette (audit: ** and bit shifts). |

## Release checklist derived from the audit

1. **Beginner alias pass** (S): typed-array + ternary + format phrasing in the picker
   ("List of Numbers (Array[int])" pattern already used by friendly variable types).
2. **Text From Pattern featured ACE** (S): `"{a} scored {b}"`-style display, compiles to
   `%` / `format()` - one new Text ACE + featured flag.
3. **Operator palette audit** (S): expression builder palette gains `**`, `<<`, `>>`, `&`,
   `|`, `^` with plain-word tooltips; template probes with --check-only.
4. **Docs page** (M): `docs/GDSCRIPT-BASICS-COVERAGE.md` - the public "everything on the
   basics page, as sheet rows" table (marketing-grade receipt for the announcement post; also
   the regression contract). Suite test pins each row's ACE/kind exists so coverage cannot
   silently regress.
5. **Reclassifications documented** (XS): multiline-enum + full nested classes stated as
   out-of-scope-for-basics in the coverage doc.

Everything else on the page is already shipped and byte-gated - the bar is a short tail of
phrasing polish, one small ACE, and a public receipt, not new machinery.

## Decision asked

Approve the checklist (1-5) as the release gate, or amend. Item 4's public doc doubles as the
launch artifact; suggest it lands last so the table states shipped facts only.
