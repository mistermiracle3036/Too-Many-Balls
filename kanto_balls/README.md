# Kanto Balls

Custom Poké Balls for gen1recomp — on **Red/Blue/Yellow and, since
0.4.0, Pokémon Gold**. `main.lua` is commented to be read and copied:
every ball is one self-contained pattern with the engine file and line
it was verified against, on both generations.

*(Renamed from **Example Balls** at 0.2.0 — the mod id changed from
`example_balls` to `kanto_balls`, so remove the old one if you had it.)*

<img src="https://raw.githubusercontent.com/mistermiracle3036/Kanto-Balls/main/docs/ball-colors.png" width="520" alt="All nine Kanto Balls in their own colors: Premier, Nest, Moon, Heal, Fast, Mirror, Silph, GS and Beast">

| Ball | Where | What it does |
| ---- | ----- | ------------ |
| PREMIER BALL | Free: buy 10+ balls in one purchase and the clerk throws one in per 10 (buy 20, get 2) | Plain 1× odds |
| NEST BALL (¥1000) | Great/Ultra marts | 4× vs Lv ≤ 15, 3× ≤ 25, 2× ≤ 35 |
| MOON BALL (¥1200) | Pewter Mart, before Mt. Moon — *Gen 1 only* | 4× vs species that evolve by Moon Stone |
| HEAL BALL (¥300) | Great/Ultra marts | Normal odds; the catch arrives fully healed (HP, status, PP) |
| FAST BALL (¥1000) | Great/Ultra marts — *Gen 1 only* | 4× vs species with base Speed ≥ 100 |
| MIRROR BALL (¥1200) | Great/Ultra marts | 4× when the wild Pokémon is the same species as the one you have out |
| SILPH BALL (¥9800) | Saffron Mart (Gold: "PROTO BALL", Ultra-tier marts) | Guaranteed catch — except one throw in **two** fizzles, and the ball is spent either way |

<img src="https://raw.githubusercontent.com/mistermiracle3036/Kanto-Balls/main/docs/mart-shelf.png" width="360" alt="A Kanto mart's ball shelf listing NEST, HEAL, FAST, MIRROR and SILPH BALLs with prices">

The clerk announces the Premier bonus in the shop text box ("I'll throw
in a PREMIER BALL, too!"). Purchases under 10 balls award nothing — it
has to be one transaction.

<img src="https://raw.githubusercontent.com/mistermiracle3036/Kanto-Balls/main/docs/premier-bonus.png" width="360" alt="A mart clerk saying: I'll throw in 2 PREMIER BALLS too!">

**About the SILPH BALL.** It is an abandoned first pass at the Master
Ball: when it works it is a Master Ball, and it doesn't always work. A
failed throw says so — "The PROTOTYPE broke apart!" — rather than
pretending you missed. The Saffron Mart shelf is temporary; it's there
so the ball can be tested. The intent is that a Silph employee hands you
exactly one after the takeover.

<img src="https://raw.githubusercontent.com/mistermiracle3036/Kanto-Balls/main/docs/silph-broke.png" width="360" alt="Battle text reading: The PROTOTYPE broke apart!">

**Every catch is marked.** Whichever of these balls you use, the Pokémon
remembers it (`mon.caughtBall`). The engine itself does not record this,
so the mod does — it is what lets [Kanto
Ribbons](https://github.com/mistermiracle3036/kanto_ribbons) award a
ribbon for how something was caught.

## On Pokémon Gold

Since 0.4.0 the mod loads on a Gold boot too. What's different there:

- **Five balls travel:** PREMIER, NEST, HEAL, MIRROR and the prototype,
  with the same behaviour as on Red. They appear at marts that already
  sell GREAT or ULTRA BALLs, and sort into the BALLS pocket.
- **MOON and FAST stay in Kanto** — Gold has its own native Moon Ball
  and Fast Ball (Kurt makes them from Apricorns), so ours step aside
  rather than fight them.
- **The prototype is labelled "PROTO BALL"** — Silph Co doesn't exist in
  Johto. Same item, same odds; a dud shows the normal break-out text
  there.
- **The Premier bonus pays out silently** — the free balls arrive in
  your BALLS pocket, but Gold's clerk has no text box we can borrow for
  the announcement yet.

## Requirements

- **[shop_events](../shop_events/)** (hard dependency — the Premier
  bonus listens to it; lives in this same repo)
- gen1recomp 0.1.38+ (Gold support needs 0.1.78+, which is when the
  engine gained Gen 2)

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

- **Pokeball Colors** — all the balls register their own colors on
  load. This mod owns those records and their colors; Pokeball Colors
  deliberately carries no entries for them, the same arrangement it has
  with Snag Quest's SNAG BALL. (Gen 1 only — Gold draws its own ball
  throw.)
- **Custom Poké Balls** by magalvao — coexists; both mods append to the
  same mart shelves, and no ball is duplicated between them.

## Using this as a template

Copy `main.lua` into your own mod and delete what you don't need. The
`registerBall` helper at the top is every registration a ball requires,
per generation. After it, each ball is one pattern:

- **Premier** — a ball with no catch code, plus consuming another mod's
  event
- **Nest** — `attempt(ctx)` reading live battle state
- **Moon** — `attempt(ctx)` querying engine species data
- **Heal** — no `attempt` at all; the `pokemon.caught` event
- **Fast** — `attempt(ctx)` reading the target's base stats
- **Mirror** — `attempt(ctx)` reading *your* side of the battle
- **Silph** — `attempt(ctx)` replacing the roll outright, including
  failing

And for Gold, the three Gen 2 seams in one place: a `catch.rate` wrap
carrying every ball's behaviour, the `pocket` stamp that puts custom
items in the BALLS pocket, and the presence-checked mart append —
each commented with why the Gen 1 mechanism doesn't reach there.

## Credits

- **Mister Miracle** — design, code and the ball colours.
- **Custom Poké Balls by magalvao**
  (https://github.com/magalvao/custom-pokeballs) — the mart-shelf
  mechanism follows the pattern that mod established. No code or assets
  from it are included; the influence is credited anyway.
- Built for the **gen1recomp** engine
  (https://github.com/bryanthaboi/gen1recomp).
- Pokémon and all related names are trademarks of Nintendo / Creatures
  Inc. / GAME FREAK inc. This mod contains no ROM data or copyrighted
  assets and requires your own game copy via gen1recomp. Code is MIT
  licensed (see `LICENSE` in the repo).
