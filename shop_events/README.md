# Shop Events

A library mod for gen1recomp. It does nothing visible on its own —
install it because another mod lists it as a dependency.

The engine has no "player bought something" event, so mods can't react
to mart purchases. This mod adds one:

```lua
mod.events:on("shop.purchased", function(p)
  -- p.id  = item id bought, e.g. "GREAT_BALL"
  -- p.qty = how many
  -- p.game
end)
```

Fired once per confirmed purchase, after payment. Selling, PC
withdrawals, and script item gifts never fire it.

Works on **Red/Blue/Yellow and, since 0.4.0, Pokémon Gold** — Gold's
mart is a different screen, but its buys ring through the same shared
till this mod listens to.

Known consumer: **[Kanto Balls](../kanto_balls/)** (the free
Premier Ball for 10+ balls bought in one purchase), in this same repo.

## Installation

**First install**

1. Download the zip from the [latest release](../../releases/latest).
2. Launcher MODS -> **Import mod .zip** (iOS: delete any older
   downloaded copy of the zip from Files first, so you don't import a
   stale one).
3. Fully quit and relaunch.

**Updates**

After the first install, the mod browser checks this repo's releases
automatically -- the entry shows "vX.Y.Z available", tap it, then
**Update**, then fully quit and relaunch.

Publishes `exports.owns = { shop_events = true }` and `exports.version`.

## Credits

- **Mister Miracle** — design and code.
- Built for the **gen1recomp** engine
  (https://github.com/bryanthaboi/gen1recomp).
- Pokémon and all related names are trademarks of Nintendo / Creatures
  Inc. / GAME FREAK inc. This mod contains no ROM data or copyrighted
  assets and requires your own game copy via gen1recomp. Code is MIT
  licensed (see `LICENSE` in the repo).
