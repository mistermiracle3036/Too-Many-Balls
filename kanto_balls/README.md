# Kanto Balls

Seven new Poké Balls for gen1recomp. `main.lua` is commented to be read
and copied: every ball is one self-contained pattern with the engine
file and line it was verified against.

*(Renamed from **Example Balls** at 0.2.0 — the mod id changed from
`example_balls` to `kanto_balls`, so remove the old one if you had it.)*

| Ball | Where | What it does |
| ---- | ----- | ------------ |
| PREMIER BALL | Free: buy 10+ balls in one purchase and the clerk throws one in per 10 (buy 20, get 2) | Plain 1× odds |
| NEST BALL (¥1000) | Great/Ultra marts | 4× vs Lv ≤ 15, 3× ≤ 25, 2× ≤ 35 |
| MOON BALL (¥1200) | Pewter Mart, before Mt. Moon | 4× vs species that evolve by Moon Stone |
| HEAL BALL (¥300) | Great/Ultra marts | Normal odds; the catch arrives fully healed (HP, status, PP) |
| FAST BALL (¥1000) | Great/Ultra marts | 4× vs species with base Speed ≥ 100 |
| MIRROR BALL (¥1200) | Great/Ultra marts | 4× when the wild Pokémon is the same species as the one you have out |
| SILPH BALL (¥9800) | Saffron Mart | Guaranteed catch — except one throw in four fizzles, and the ball is spent either way |

The clerk announces the Premier bonus in the shop text box ("I'll throw
in a PREMIER BALL, too!"). Purchases under 10 balls award nothing — it
has to be one transaction.

**About the SILPH BALL.** It is Silph Co's abandoned first pass at the
Master Ball: when it works it is a Master Ball, and it doesn't always
work. The Saffron Mart shelf is temporary — it's there so the ball can
be tested. The intent is that a Silph employee hands you exactly one
after the takeover.

## Requirements

- **[shop_events](../shop_events/)** (hard dependency — the Premier
  bonus listens to it; lives in this same repo)
- gen1recomp 0.1.38+

## Installation

**First install**

1. Download both zips from the [latest release](../../releases/latest)
   -- `shop_events-X.Y.Z.zip` and `kanto_balls-X.Y.Z.zip`. Both are
   required.
2. Launcher MODS -> **Import mod .zip**, once per zip (iOS: delete any
   older downloaded copies from Files first).
3. Fully quit and relaunch.

**Updates**

After the first install, the mod browser checks this repo's releases
automatically for each. Update both together when either shows
"available" -- see the note in Shop Events' README on why.

## Plays well with

- **Pokeball Colors** — all seven balls register their own colors on
  load. This mod owns those records and their colors; Pokeball Colors
  deliberately carries no entries for them, the same arrangement it has
  with Snag Quest's SNAG BALL.
- **Custom Poké Balls** by magalvao — coexists; both mods append to the
  same mart shelves, and no ball is duplicated between them.

## Using this as a template

Copy `main.lua` into your own mod and delete what you don't need. The
`registerBall` helper at the top is the three registrations every ball
requires. After it, each ball is one pattern:

- **Premier** — a ball with no catch code, plus consuming another mod's
  event
- **Nest** — `attempt(ctx)` reading live battle state
- **Moon** — `attempt(ctx)` querying engine species data
- **Heal** — no `attempt` at all; the `pokemon.caught` event
- **Fast** — `attempt(ctx)` reading the target's base stats
- **Mirror** — `attempt(ctx)` reading *your* side of the battle
- **Silph** — `attempt(ctx)` replacing the roll outright, including
  failing
