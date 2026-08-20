# Too Many Balls

Custom Poké Balls for gen1recomp — on **Red/Blue/Yellow and, since
0.4.0, Pokémon Gold**. The collection keeps growing, which is where the
name came from. `main.lua` is commented to be read and copied: every ball
is
one self-contained pattern with the engine file and line it was verified
against, on both generations.

*(Previously called **Kanto Balls** — renamed at 0.4.3 once the balls
reached Johto. Same mod: the id is still `kanto_balls` and the download
is still `kanto_balls-X.Y.Z.zip`, so updates carry over and nothing in
your save changes. Before that it was **Example Balls**, id
`example_balls` — that one is a genuinely different id, so remove it if
you still have it.)*

<img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/ball-colors.png" width="520" alt="Every ball in its own colors: Premier, Nest, Moon, Heal, Fast, Mirror, Silph, GS, Beast, Snare, Drift and Cradle">

There are two ways to get a ball here. Most are **bought** at marts. The
rest are **crafted** from Apricorns in the BALL CASE, which is a Gold
feature — Kurt gives you the case, and it is worth having.

## Balls you buy

| Ball | Where | What it does |
| ---- | ----- | ------------ |
| PREMIER BALL | Free: buy 10+ balls in one purchase and the clerk throws one in per 10 (buy 20, get 2) | Plain 1× odds |
| NEST BALL (¥1000) | Great/Ultra marts | 4× vs Lv ≤ 15, 3× ≤ 25, 2× ≤ 35 |
| HEAL BALL (¥300) | Great/Ultra marts | Normal odds; the catch arrives fully healed (HP, status, PP) |
| MIRROR BALL (¥1200) | Great/Ultra marts | 4× when the wild Pokémon is the same species as the one you have out |
| MOON BALL (¥1200) | Pewter Mart, before Mt. Moon — *Gen 1 only* | 4× vs species that evolve by Moon Stone |
| FAST BALL (¥1000) | Great/Ultra marts — *Gen 1 only* | 4× vs species with base Speed ≥ 100 |
| LUXURY BALL (¥3000) | Great/Ultra marts | Plain odds; on Gold the catch starts at 120 happiness |
| SILPH BALL (¥9800) | Saffron Mart (Gold: "PROTO BALL", Ultra-tier marts) | Guaranteed catch — except one throw in **two** fizzles, and the ball is spent either way |

Gold also sells seven familiar later-generation balls at Great/Ultra
marts. Every one has a two-line description in the mart, so its condition
is visible before you buy it.

| Gold-only ball | Price | What it does |
| -------------- | ----- | ------------ |
| QUICK BALL | ¥1000 | 4× on the first battle turn; normal afterward |
| TIMER BALL | ¥1000 | Starts at 1×, then gains 1× every five turns up to 4× |
| NET BALL | ¥1000 | 3× on WATER- or BUG-type Pokémon |
| DUSK BALL | ¥1000 | 3× at night or inside a cave/dungeon |
| REPEAT BALL | ¥1000 | 3× on a species already marked caught in your Pokédex |
| DREAM BALL | ¥1000 | 4× on a sleeping Pokémon; freeze does not count |
| DIVE BALL | ¥1000 | 3× while fishing or surfing |

<img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/mart-shelf.png" width="360" alt="A Kanto mart's ball shelf listing NEST, HEAL, FAST, MIRROR and SILPH BALLs with prices">

The clerk announces the Premier bonus in the shop text box ("I'll throw
in a PREMIER BALL, too!"). Purchases under 10 balls award nothing — it
has to be one transaction.

<img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/premier-bonus.png" width="360" alt="A mart clerk saying: I'll throw in 2 PREMIER BALLS too!">

**About the SILPH BALL.** It is an abandoned first pass at the Master
Ball: when it works it is a Master Ball, and it doesn't always work. A
failed throw says so — "The PROTOTYPE broke apart!" — rather than
pretending you missed. The Saffron Mart shelf is temporary; it's there
so the ball can be tested. The intent is that a Silph employee hands you
exactly one after the takeover.

<img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/silph-broke.png" width="360" alt="Battle text reading: The PROTOTYPE broke apart!">

## Balls you make — the BALL CASE

*Pokémon Gold only.* Kurt has been making balls out of Apricorns for
years. When you come back to him from the Slowpoke Well he decides
you're worth teaching, and hands over a **BALL CASE**. Once the key item
is safely in your bag, he also gives you one **CHERISH BALL** as a
keepsake. It has plain catch odds and is not sold. If the BALL pocket is
full, the Cherish Ball may not fit, but the Case is never blocked or lost.

<table>
<tr>
<td><img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/kurt-case1.png" width="300" alt="Kurt saying: APRICORNS aren't just for my seven."></td>
<td><img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/kurt-case2.png" width="300" alt="Kurt saying: Take this CASE and mix your own."></td>
</tr>
</table>

The case is a key item — it goes to KEY ITEMS and stays there. Use it
from the pack and it opens a workbench: pick a ball, and if you have the
Apricorns it's made on the spot.

<img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/ball-case-pocket.png" width="300" alt="The BALL CASE in the KEY ITEMS pocket, described as: Mix APRICORNS into new kinds of ball.">

| Ball | Costs | What it does |
| ---- | ----- | ------------ |
| KECLEON BALL | 1 Green + 1 Red Apricorn | 1.5×, same as a Great Ball — **and it turns the colour of whatever you throw it at** |
| DRIFT BALL | 1 White + 1 Yellow Apricorn | 4× on light, airy Pokémon |
| SNARE BALL | 2 Black Apricorns | Catches a sleeping or frozen target outright; a dud on anything awake |
| CATALYST BALL | 1 Green + 1 Yellow Apricorn | 4× on species that evolve with a stone |
| CRADLE BALL | 1 White + 1 Pink + 1 Green + 1 Red Apricorn | Never misses — and the catch **starts over at level 1** |

<img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/craft-made.png" width="360" alt="The BALL CASE menu listing CATALYST, DRIFT, SNARE, KECLEON and CRADLE BALL, with a message reading: Made a KECLEON BALL!">

**The KECLEON BALL is the one to see.** It reads the wild Pokémon's own
palette as it flies. Same ball, three encounters:

<table>
<tr>
<td><img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/kecleon-wigglytuff-mon.png" width="240" alt="A wild WIGGLYTUFF"></td>
<td><img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/kecleon-scizor-mon.png" width="240" alt="A wild SCIZOR"></td>
<td><img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/kecleon-lapras-mon.png" width="240" alt="A wild LAPRAS"></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/kecleon-wigglytuff-ball.png" width="240" alt="The KECLEON BALL thrown at it, pink"></td>
<td><img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/kecleon-scizor-ball.png" width="240" alt="The KECLEON BALL thrown at it, red"></td>
<td><img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/kecleon-lapras-ball.png" width="240" alt="The KECLEON BALL thrown at it, blue"></td>
</tr>
</table>

Throw it at a shiny and you get a shiny-coloured ball.

**The CRADLE BALL is not a punishment.** Your catch comes back at level
1 with level-1 moves, but its DVs and stat experience are untouched — so
it grows the whole curve from scratch and ends up *stronger* at 100 than
one caught late. Four Apricorns is the price of that, and the downside
is the joke.

A level 41 DODUO, caught, and what arrives:

<table>
<tr>
<td><img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/cradle-mon-ori.png" width="240" alt="A wild DODUO at level 41"></td>
<td><img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/cradle-status1.png" width="240" alt="The caught DODUO at level 1 with 11 HP and 1 EXP point"></td>
<td><img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/cradle-status2.png" width="240" alt="Its moves: PECK and GROWL, the level-1 set, with two empty slots"></td>
</tr>
</table>

Level 1, 11 HP, one experience point, and PECK and GROWL in two of four
move slots — the level-1 set, rebuilt from scratch rather than trimmed.

The case also stores balls. **STOW ALL** moves every ball from this mod
out of your pack and into the case; **TAKE BACK** returns them. Nothing
is ever lost — if your pack is full you get back what fits and the rest
stays put. Apricorns are never stowed, and neither is the case.

Apricorns come off the seven Apricorn trees, and the recipes are costed
against that supply — the case is meant to be worth a detour, not a
vending machine.

## Two balls you won't see

**GS BALL** and **BEAST BALL** exist but aren't obtainable in normal
play; they're behind the *[DEV] CHEAP BALLS* option. They're still
registered on every boot on purpose, so if you ever got one they stay in
the BALLS pocket and look like themselves rather than turning into junk.

The **ACE BALL** is a case recipe that stays hidden until another mod
teaches it — that hook is for [Route
Aces](https://github.com/mistermiracle3036/) and isn't live yet. Nothing
to find for now.

**Every catch is marked.** Whichever of these balls you use, the Pokémon
remembers it (`mon.caughtBall`). The engine itself does not record this,
so the mod does — it is what lets [Kanto
Ribbons](https://github.com/mistermiracle3036/kanto_ribbons) award a
ribbon for how something was caught.

## On Pokémon Gold

Since 0.4.0 the mod loads on a Gold boot too. The bought balls appear on
Johto shelves that already stock GREAT or ULTRA BALLs:

<img src="https://raw.githubusercontent.com/mistermiracle3036/Too-Many-Balls/main/docs/mart-shelf-gold.png" width="360" alt="A Johto mart shelf listing the mod's balls alongside Gold's own">

What's different there:

- **Quick, Timer, Net, Dusk, Repeat, Dream and Dive are Gold-only here.**
  They use Gold's live turn count, species types, Pokédex, time of day and
  fishing/surfing state. Red keeps those shared ids available to Custom
  Poké Balls instead.

- **The whole craft tier is Gold-only**, because Kurt and the Apricorns
  are. The balls themselves are registered on Red as well, so one that
  arrives from elsewhere still works and still sorts correctly — there's
  just no way to make one there.
- **MOON and FAST stay in Kanto** — Gold has its own native Moon Ball
  and Fast Ball (Kurt makes them from Apricorns), so ours step aside
  rather than fight them.
- **The prototype is labelled "PROTO BALL"** — Silph Co doesn't exist in
  Johto. Same item, same odds; a dud shows the normal break-out text
  there.
- **The Premier bonus works, clerk line and all** — buy 10+ balls in one
  purchase and he adds "I'll throw in a PREMIER BALL, too!" to his
  thank-you, same as in Kanto.
- **Each ball has its own colour when thrown.** Gold colours balls
  itself, but only knows the ones the cart ships, so custom balls would
  otherwise all throw grey. This mod supplies its own palettes and
  leaves Gold's native Moon and Fast Balls exactly as they are. Add
  **Pokeball Colors** and those same colours show up on the Pokémon
  Center heal machine as well.
- **Your BALLS pocket grows to fit.** Gold's ball pocket holds twelve
  kinds, so the mod adds one slot per obtainable ball. Turn on
  *VANILLA BAG LIMITS* if you'd rather it
  didn't. The same thing happens on Red, Blue and Yellow — see below.

## Bag space

This mod adds more kinds of ball than either game left room for, so it
makes room: **one extra slot per obtainable ball**, and no more.

It counts the balls you can actually **get** on the game you're playing,
not every ball the mod knows about.

- On **Gold** that is twenty with the canon set active, added to the BALLS
  pocket's native twelve. If the shared seven are disabled or deferred to
  Custom Poké Balls, the addition is thirteen.
- On **Red, Blue and Yellow** there is only one bag, and eight obtainable
  balls reserve room: the seven on shelves plus the Premier Ball. The
  craft tier needs the BALL CASE, which is Kurt's and so Gold's, so it
  reserves no room in a Kanto bag.

It is added to whatever the game answers rather than replacing the
number, so it can never shrink a bag some other mod grew. Nothing but the
ball capacity changes, and **VANILLA BAG LIMITS** switches it off
entirely if you would rather keep the original limit.

## Requirements

- Nothing. This mod has no dependencies as of 0.6.0 — the purchase
  detection the Premier bonus needs is built in. (It used to require a
  separate **Shop Events** mod; that was folded in, and you can remove it
  if you still have it.)
- gen1recomp 0.1.38+ (Gold support needs 0.1.78+, which is when the
  engine gained Gen 2)

## Installation

**First install**

1. Download `kanto_balls-X.Y.Z.zip` from the
   [latest release](../../releases/latest). That is the whole mod.
2. Launcher MODS -> **Import mod .zip** (iOS: delete any older downloaded
   copies from Files first).
3. Fully quit and relaunch.

**Updates**

After the first install, the mod browser checks this repo's releases
automatically and updates in place.

## Options

- **[DEV] CHEAP BALLS** — puts GS and BEAST on every ball shelf and
  widens the Gold shelves to every mart. For testing.
- **VANILLA BAG LIMITS** — keeps Gold's stock twelve-kind ball pocket
  instead of growing it.
- **CANON BALL SET** — Gold only, on by default. Turn it off if a Gold
  version of **Custom Poké Balls** should own Quick, Timer, Net, Dusk,
  Repeat, Dream and Dive instead. If you switch it off while holding any
  of those seven, they appear as raw items in the ITEMS pocket until you
  enable the set again; they are not deleted.

*A note for Gold players:* the engine currently doesn't persist mod
options set on a Gold boot. Set these from a Red boot and they'll stick.

## Plays well with

- **Pokeball Colors** — optional on **both** games, and worth having on
  either.
  - *Red/Blue/Yellow:* every ball registers its own colors on load, so
    each has its own look during the throw. This mod owns those records
    and their colors; Pokeball Colors deliberately carries no entries for
    them, the same arrangement it has with Snag Quest's SNAG BALL.
  - *Gold:* the game already colours a thrown ball, and this mod supplies
    the palettes for its own. What Pokeball Colors adds there is the
    **Pokémon Center heal machine** — Gold draws every party ball in one
    colour, and Colors gives each slot the colour of the ball that Pokémon
    was actually caught in. It reads that from the same palettes this mod
    registers, so the two match with no setup.

  For other ball authors: claim a Gold colour through
  `exports.registerBallPalette(ballId, paletteName, row)` rather than
  wrapping `ballPalette` a second time — two wraps means load order
  decides the colour, silently. A ball registered that way is picked up
  by the heal machine too. There's a matching
  `exports.requestBallSlots(n)` if your mod needs pocket headroom of its
  own.
- **Custom Poké Balls** by magalvao — the shared ids are intentional.
  Custom Poké Balls owns Quick, Timer, Net, Dusk, Repeat, Dream and Dive
  on Red; Too Many Balls supplies them on Gold unless a Gold port of that
  mod is loaded. The **CANON BALL SET** option is the manual fallback.

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
- **Kecleon** — a ball whose whole effect is a palette, not maths
- **Cradle** — rewriting the caught Pokémon after the fact, safely

And for Gold, the Gen 2 seams in one place: a `catch.rate` wrap carrying
every ball's behaviour, the `pocket` stamp that puts custom items in the
BALLS pocket, the presence-checked mart append, a key item that opens a
mod-owned screen, and an NPC handover driven off script events — each
commented with why the Gen 1 mechanism doesn't reach there.

`tests/hook_harness.lua` runs the whole mod against stub engine modules
and presses every button, on both generations, in about a second. It is
not shipped in the zip; it's in the repo, and it exists because static
checks cannot see a menu row that calls a nil.

## Credits

- **Mister Miracle** — design, code and the ball colours.
- Parts of the craft tier were written by **ChatGPT** to written
  specifications in `exchange/work-orders/`, then reviewed and corrected
  before landing. The commit for each says which.
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
