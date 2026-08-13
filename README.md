# Too Many Balls

**New Poké Balls for gen1recomp** — on Red / Blue / Yellow **and Pokémon
Gold** since 0.4.0 — sold on real mart shelves, plus the small library mod
that makes one of them possible.

*(Called **Kanto Balls** until 0.4.3. Renamed once the balls reached
Johto and "Kanto" stopped being true. Same mod, same ids, same downloads —
see [Installation](#installation).)*

| Ball | Where you get it | What makes it worth carrying |
| ---- | ---------------- | ---------------------------- |
| **PREMIER BALL** | **Free.** Buy 10+ balls in one purchase and the clerk throws one in per 10 | Plain Poké Ball odds — but you never pay for one, and the clerk says so in his own text box |
| **NEST BALL** | Ball marts, ₽1000 | **4×** on anything level 15 or under, tapering off up to 35 |
| **MOON BALL** | Pewter Mart — the last mart before Mt. Moon | **4×** on anything that evolves by Moon Stone |
| **HEAL BALL** | Ball marts, ₽300 | Normal odds, but what you catch arrives **fully healed** — HP, status and PP |
| **FAST BALL** | Ball marts, ₽1000 | **4×** on anything with base Speed 100+ — the birds, Dugtrio, Electrode, Tauros, Jolteon |
| **MIRROR BALL** | Ball marts, ₽1200 | **4×** when the wild Pokémon is the same species as the one you have out. Send out your own Pidgey to catch a better Pidgey |
| **SILPH BALL** | Saffron Mart, ₽9800 | Silph Co's abandoned first pass at the Master Ball. When it works, it **is** a Master Ball. One throw in two, it just breaks |

Every ball above is a real item on a real shelf — no cheats, no new
currency. Buy them and throw them.

<img src="docs/mart-shelf.png" width="360" alt="A Kanto mart's ball shelf listing NEST, HEAL, FAST, MIRROR and SILPH BALLs with prices">

*(The SNAG BALL on that shelf is from [Pokemon Snag](https://github.com/mistermiracle3036/Pokemon-Snag),
a separate mod of mine — it is not part of this one.)*

### The Premier Ball pays for itself

Buy ten or more of any ball in **one** purchase and the clerk hands them
over free, and says so in his own text box:

<img src="docs/premier-bonus.png" width="360" alt="A mart clerk saying: I'll throw in 2 PREMIER BALLS too!">

### The Silph Ball tells you when it breaks

A failed throw is not a miss, and it does not pretend to be one:

<img src="docs/silph-broke.png" width="360" alt="Battle text reading: The PROTOTYPE broke apart!">

## On Pokémon Gold, Kurt teaches you to make your own

Most of the balls above travel to Johto — Premier, Nest, Heal, Mirror and
the prototype (labelled **PROTO BALL** there, since Silph Co doesn't
exist in Johto). Moon and Fast stay behind; Gold already has its own,
made by Kurt.

And then Kurt does something else. Come back to him from the Slowpoke
Well and he decides you're worth teaching, and hands over a **BALL
CASE** — a key item that mixes Apricorns into five more balls:

| Ball | Costs | What it does |
| --- | --- | --- |
| **KECLEON BALL** | 1 Green + 1 Red Apricorn | Catches as well as a Great Ball — **and turns the colour of whatever you throw it at** |
| **DRIFT BALL** | 1 White + 1 Yellow | **4×** on light, airy Pokémon |
| **SNARE BALL** | 2 Black | Catches a sleeping or frozen target **outright**. A dud on anything awake |
| **CATALYST BALL** | 1 Green + 1 Yellow | **4×** on anything that evolves with a stone |
| **CRADLE BALL** | 1 White + 1 Pink + 1 Green + 1 Red | **Never misses** — and your catch starts over at level 1 |

The Kecleon Ball reads the wild Pokémon's own palette as it flies, so it
comes out pink at a Wigglytuff, red at a Scizor, blue at a Lapras. Throw
it at a shiny and the ball is shiny too.

The Cradle Ball is not a punishment. Your catch comes back at level 1
with level-1 moves, but its DVs and stat experience are untouched — so it
grows the whole curve from scratch and finishes *stronger* at 100 than
one caught late. Four Apricorns is the price of that.

The case stores balls as well: **STOW ALL** clears this mod's balls out
of your pack, **TAKE BACK** returns them, and a full pack gets back what
fits with the rest kept safe. Kurt's own seven recipes are untouched.

## Two mods, one download page

| Mod | What it does |
| --- | --- |
| **[kanto_balls](kanto_balls/)** | All fourteen balls, and the BALL CASE. **Requires shop_events.** |
| **[shop_events](shop_events/)** | Library mod. Emits `shop.purchased` whenever you buy something at a mart, because the engine has no purchase event of its own. Does nothing visible by itself. |

**Install both**, even if you only want the balls — the Premier Ball's
bonus is built entirely on shop_events.

> **Development Preview:** both mods are in active development. Bug
> reports and ideas are welcome in [Issues](../../issues) — say which
> mod, include the version from your load log, and list your other mods.

## Also for mod authors

`kanto_balls/main.lua` is written to be read and copied. Each ball is a
*different* technique, deliberately: no catch code at all, reacting to
another mod's event, multiplying the rate from live battle state,
querying species data, reading base stats, reading your own side of the
battle, replacing the catch roll outright, a ball whose whole effect is a
palette rather than maths, and one that rewrites the caught Pokémon after
the fact. Each one is commented with the engine file and line it was
verified against.

The Gold side is the same idea for the Gen 2 seams: one `catch.rate` wrap
carrying every ball, the `pocket` stamp, a presence-checked mart append,
a key item that opens a mod-owned screen, and an NPC handover driven off
script events — each with a note on why the Gen 1 mechanism doesn't reach
there.

Between them they cover most of what the ball API can do, which is why
this started life as **Example Balls**.

## Installation

1. Download **both** zips from the [latest release](../../releases/latest):
   `kanto_balls-X.Y.Z.zip` and `shop_events-X.Y.Z.zip`.
2. Launcher → **MODS** → **Import mod .zip**, once per zip.
3. Fully quit and relaunch.

**Upgrading from Kanto Balls?** Nothing to do — that was this mod's old
display name (changed at 0.4.3). The id never changed, so the mod browser
updates it in place and your saved balls are untouched.

Already have **Example Balls** (`example_balls`) installed? Remove it
first. That one was a real id change back at 0.2.0, and because a new id
installs to its own folder, nothing stops both running at once and
registering overlapping balls.

## Why one repo, two mods

They're released together, but they're **not one mod** — each has its own
manifest, its own id, and its own on/off toggle in the mod browser.
shop_events is meant to be reusable by other authors independent of the
ball pack, so keeping it a separate install matters.

The one consequence of sharing a repo: **every release retags and re-zips
both mods to the same version number**, even when only one of them
actually changed. See each mod's CHANGELOG for why.

## Compatibility

- **[Pokeball Colors](https://github.com/mistermiracle3036/Pokeball-Colors)** —
  optional, and it works on **both** games. On Red/Blue/Yellow every ball
  registers its own colors, so each has its own look during the throw. On
  Gold the throw is already coloured by this mod, and Colors adds the
  **Pokémon Center heal machine**: each party slot shows the ball its
  Pokémon was caught in, taken from the same palettes registered here.

  <img src="docs/ball-colors.png" width="520" alt="Nine of the balls in their own colors: Premier, Nest, Moon, Heal, Fast, Mirror, Silph, GS and Beast">

  *Requires Pokeball Colors with **COLORS** set to ADVANCED — without it
  every ball throws in the default palette. GS and BEAST are the two
  behind `[DEV] CHEAP BALLS`.*
- **[Custom Poké Balls](https://github.com/magalvao/custom-pokeballs)**
  by magalvao — coexists. Both append to the same mart shelves and no
  ball is duplicated between them.
- Mart shelves are verified present in Red, Blue **and** Yellow's data,
  but have only been played on Red/Blue so far.

## Credits

By **Mister Miracle**
([@mistermiracle3036](https://github.com/mistermiracle3036)).
Built for [gen1recomp](https://github.com/bryanthaboi/gen1recomp).
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
