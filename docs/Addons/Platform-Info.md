# Platform Info

Answers "what is this game running on?" from plain event rows: which OS and device, the screen's
size, DPI, refresh rate and safe area, touch support, the player's locale, the GPU, and the CPU -
so your sheets can switch control schemes, scale UI, and pick quality presets per platform. It is
the Construct Platform Info idea, shaped to what Godot actually exposes. Every verb is a direct
engine query (no caching, no state), and the pack itself is an event sheet - open it and extend it.

**Setup**: register `eventsheet_addons/platform_info/platform_info_addon.gd` as an autoload named
`PlatformInfo` (Project Settings > Globals), or let the Doctor's autoload check nudge you. Every
verb then appears in the picker under **Platform Info**.

## The vocabulary

Conditions: **Is On Mobile**, **Is On Desktop**, **Is On Web**, **Has Touchscreen**,
**Is Portrait**, **Is Debug Build**, **Has Feature Tag** (engine tags like `"mobile"`, or your own
custom export-preset tags like `"demo"`).

Expressions: **OS Name / OS Version / Device Model / Locale / Locale Language / Engine Version**,
**Screen Width / Height / DPI / Refresh Rate / Count / Scale**, **Safe Area Top / Left /
Bottom Inset / Right Inset**, **GPU Name / GPU Vendor / Rendering Method**,
**CPU Thread Count / CPU Name / Physical Memory (MB)**.

## Use cases

1. **Touch controls only where they belong.** On Ready + Is On Mobile - show the virtual joystick
   layer; Else - hide it and enable mouse capture. One event, no per-platform builds.
2. **Finger-sized buttons on any phone.** On Ready - set your HUD buttons' scale to
   `PlatformInfo.screen_dpi() / 160.0` so a button is the same physical size on a budget phone
   and a tablet.
3. **Notch-safe HUD.** On Ready - set the HUD container's top margin to
   `PlatformInfo.safe_area_top()` and its bottom margin to `PlatformInfo.safe_area_bottom_inset()`;
   health bars stop hiding under status bars and home indicators.
4. **A quality preset from the GPU.** On Ready + Expression Is True
   `"Intel" in PlatformInfo.gpu_vendor()` - drop shadows and half the particle counts; a chip-name
   check beats shipping a settings screen nobody opens.
5. **Default the language picker.** On Ready - set the language option to
   `PlatformInfo.locale_language()`; a Japanese player sees Japanese first, and your picker stays
   available for the rest.
6. **Hide Quit on the web.** On Ready + Is On Web - hide the Quit button (browsers ignore it) and
   show "click to enable sound" instead (autoplay rules).
7. **Portrait/landscape layout flip.** Every X Seconds 0.5 + Is Portrait - move the controls to a
   stacked layout; Else - side-by-side. Rotation handled with two rows.
8. **Cap the sim to the display.** On Ready - set your interpolation rate from
   `PlatformInfo.screen_refresh_rate()` so a 144 Hz monitor gets the smoothness it paid for.
9. **Background work that fits the machine.** On Ready - set the Time Slicer's per-frame budget to
   `PlatformInfo.cpu_thread_count() * 2` items; an 8-core desktop chews through spawns a phone
   trickles.
10. **Low-memory texture tier.** On Ready + Expression Is True
    `PlatformInfo.memory_physical_mb() < 3000.0` - load the half-resolution atlas.
11. **Debug overlay that ships safely.** Every Tick + Is Debug Build - draw the FPS/state overlay;
    it vanishes from release exports with zero effort.
12. **A demo build from one project.** Add a `demo` feature tag to the export preset, then
    Has Feature Tag "demo" - lock chapters 2+ and swap the title screen.
13. **Bug reports that diagnose themselves.** On feedback submit - append
    `PlatformInfo.os_name()`, `os_version()`, `device_model()`, `gpu_name()`, and
    `engine_version()` to the report text. Half your reproduction questions, pre-answered.
14. **Streamer mode on multi-monitor rigs.** On Ready + Expression Is True
    `PlatformInfo.screen_count() > 1` - offer "move dev console to second screen".
15. **Renderer-aware effects.** On Ready + Expression Is True
    `PlatformInfo.rendering_method() == "gl_compatibility"` - swap the volumetric fog for a
    gradient; the effect degrades on the renderer that can't afford it, silently.
16. **Touch-laptop hybrids.** Has Touchscreen + Is On Desktop - enable BOTH mouse hover and tap
    targets; the Surface player gets the best of each without picking a mode.

### Other use cases

- **hiDPI-crisp pixel art.** Multiply your integer zoom by `screen_scale()` on Retina/hiDPI
  displays so pixels stay square and sharp instead of blurry-fractional.
- **Store-specific niceties.** Custom feature tags per store export (steam, itch) gate the right
  overlay, achievements bridge, or rich-presence rows.
- **Orientation-locked minigames.** A sub-sheet that pauses the game with a "rotate your device"
  card while Is Portrait mismatches the minigame's needs.
- **Analytics that respect tiers.** Bucket sessions by GPU vendor + memory band to learn which
  preset most players actually land on before you tune defaults.
- **Support-tier gating.** Refuse the experimental mode below a thread-count/memory floor and
  say why, instead of letting a ten-year-old laptop discover it by freezing.
