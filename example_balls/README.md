# Example Balls

Four new balls for gen1recomp — and a template. Each ball demonstrates a
different mod-API pattern, and `main.lua` is commented to be copied.

| Ball | Where | What it does | The pattern it teaches |
| ---- | ----- | ------------ | ---------------------- |
| PREMIER BALL | Free: buy 10+ balls in one purchase and the clerk throws one in per 10 (buy 20, get 2), with an in-shop announcement | Plain 1× odds | A ball with no catch code + listening to another mod's event (`shop.purchased`) |
| NEST BALL (¥1000) | Great/Ultra marts | 4× vs Lv ≤ 15, 3× ≤ 25, 2× ≤ 35 | `attempt(ctx)` reading battle state |
| MOON BALL (¥1200) | Pewter Mart, before Mt. Moon | 4× vs species that evolve by Moon Stone | `attempt(ctx)` querying engine species data |
| HEAL BALL (¥300) | Great/Ultra marts | Normal odds; the catch arrives fully healed (HP, status, PP) | No `attempt` at all — the `pokemon.caught` event |

The clerk announces the bonus in the shop text box ("I'll throw in a
PREMIER BALL, too!"). Purchases under 10 balls award nothing — it has to
be one transaction.

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
