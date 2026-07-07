# Addon Guides

Deep-dive guides for the bundled behavior packs in `eventsheet_addons/`. Each one covers when to reach
for the pack, its full ACE reference (Actions, Conditions, Expressions, Triggers), a dozen or more
worked use cases as event-sheet rows, and the tips and gotchas that bite in practice.

Every pack here is authored as an event sheet and compiles to plain GDScript with zero plugin
dependency, just like your own sheets - open its `.gd` in the editor to read it as events.

## Systems (autoload singletons)

These install as a single project-wide autoload you call from any sheet by name.

- [Currency Ledger](Currency-Ledger.md) - the `CurrencyLedger` singleton: name your currencies, then earn, spend, cap, and format money, with per-currency min/max, daily caps, and offline gain.
- [Loot Table](Loot-Table.md) - the `LootBox` singleton: weighted drop tables with guarantees, hard pity, nested tables, and seeded rolls.
- [Storylet Weaver](Storylet-Weaver.md) - the `Storylets` singleton: quality-based narrative - register small storylets with requirements, then Draw the best eligible one.
- [SkinVault](SkinVault.md) - the `SkinVault` singleton: cosmetic ownership with rarities, tier-based pity, a purchase handshake, and grant/revoke.
- [ProcRoom](ProcRoom.md) - the `ProcRoom` singleton: a seeded, tiered room-graph map (start to boss) with visited/available/locked traversal.
- [ComboBox](ComboBox.md) - the `ComboBox` singleton: an input-sequence detector - register token sequences, fire On Combo Matched, with per-gap timing windows and wildcards.

## Components (per-node behaviors)

These attach to a node as a behavior.

- [UtilityBrain](UtilityBrain.md) - attach to any AI node: score candidate actions by considerations and response curves, then Evaluate - the best action wins, with cooldowns, inertia, and interrupts.
- [Physics Car](Physics-Car.md) - attach to a RigidBody2D: throttle/brake/steer, keyboard or drive-toward-AI control, lateral grip, drift detection, and terrain multipliers.

## Building your own

Want to author a pack like these, or an editor tool? See [Building editor tools with event sheets](../GUIDE-BUILDING-EDITOR-TOOLS.md) and [Building on EventSheets](../GUIDE-BUILDING-ON-EVENTSHEETS.md).
