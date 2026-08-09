# Example Balls

Four new balls for gen1recomp — and a template. Each ball demonstrates a
different mod-API pattern, and `main.lua` is commented to be copied.

| Ball | Where | What it does | The pattern it teaches |
| ---- | ----- | ------------ | ---------------------- |
| PREMIER BALL | Free — see below | Plain 1× odds | A ball with no catch code + listening to another mod's event (`shop.purchased`) |
| NEST BALL (¥1000) | Great/Ultra marts | 4× vs Lv ≤ 15, 3× ≤ 25, 2× ≤ 35 | `attempt(ctx)` reading battle state |
| MOON BALL (¥1200) | Pewter Mart, before Mt. Moon | 4× vs species that evolve by Moon Stone | `attempt(ctx)` querying engine species data |
| HEAL BALL (¥300) | Great/Ultra marts | Normal odds; the catch arrives fully healed (HP, status, PP) | No `attempt` at all — the `pokemon.caught` event |

## The Premier Ball

You can't buy a Premier Ball. The mart clerk throws them in free when
you buy balls in bulk — **10 or more balls in a single purchase gets you
one free Premier Ball, per 10.**

Any kind of ball qualifies — Poké, Great, Ultra, or one of the balls
added by this mod or others. But it has to be **10 of the same ball, in
one go**: the mart rings up each item separately, so 5 Poké Balls plus 5
Great Balls is two purchases of 5, not one of 10. Buying 5 now and 5
later gets you nothing either.

| You buy (one item, one purchase) | You get |
| --- | --- |
| 9 Poké Balls | nothing |
| 10 Poké Balls | 1 Premier Ball |
| 19 Great Balls | 1 Premier Ball |
| 20 Ultra Balls | 2 Premier Balls |
| 50 Poké Balls | 5 Premier Balls |

The clerk tells you right in the shop, where the usual "Here you are!
Thank you!" line would be:

```
I'll throw in a
PREMIER BALL, too!
```

...or, for more than one:

```
I'll throw in 2
PREMIER BALLS too!
```

Then check your bag's BALLS pocket. Premier Balls catch exactly like a
Poké Ball — the point is the colour and the bragging rights, not the
odds.

**Not seeing them?** The bonus needs
[shop_events](../shop_events/) installed and enabled — it's what detects
the purchase. Its DEBUG option (default ON) logs each detected purchase
to `[ERRS]` in the mod manager, which will confirm whether the buy was
seen.

## Requirements

- **[shop_events](../shop_events/)** (hard dependency — the Premier
  bonus listens to it; lives in this same repo)
- gen1recomp 0.1.38+

## Installation

**First install**

1. Download both zips from the [latest release](../../releases/latest)
   -- `shop_events-X.Y.Z.zip` and `example_balls-X.Y.Z.zip`. Both are
   required.
2. Launcher MODS -> **Import mod .zip**, once per zip (iOS: delete any
   older downloaded copies from Files first).
3. Fully quit and relaunch.

**Updates**

After the first install, the mod browser checks this repo's releases
automatically for each. Update both together when either shows
"available" -- see the note in Shop Events' README on why.

## Plays well with

- **Pokeball Colors** — all four balls register canon colors on load
  (Premier white/red, Nest green/gold, Moon deep blue/crescent gold,
  Heal pink/white). This is the documented integration pattern, used
  exactly as its README describes.
- **Custom Poké Balls** by magalvao — coexists; both mods append to the
  same mart shelves.

## Using this as a template

Copy `main.lua` into your own mod and delete what you don't need. The
`registerBall` helper at the top is the three registrations every ball
requires; each of the four balls below it is one self-contained pattern
with the engine file/line it was verified against.
