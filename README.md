# Kanto Balls

**Seven new Poké Balls for gen1recomp** (Red / Blue / Yellow), sold across
Kanto's marts — plus the small library mod that makes one of them possible.

| Ball | Where you get it | What makes it worth carrying |
| ---- | ---------------- | ---------------------------- |
| **PREMIER BALL** | **Free.** Buy 10+ balls in one purchase and the clerk throws one in per 10 | Plain Poké Ball odds — but you never pay for one, and the clerk says so in his own text box |
| **NEST BALL** | Ball marts, ₽1000 | **4×** on anything level 15 or under, tapering off up to 35 |
| **MOON BALL** | Pewter Mart — the last mart before Mt. Moon | **4×** on anything that evolves by Moon Stone |
| **HEAL BALL** | Ball marts, ₽300 | Normal odds, but what you catch arrives **fully healed** — HP, status and PP |
| **FAST BALL** | Ball marts, ₽1000 | **4×** on anything with base Speed 100+ — the birds, Dugtrio, Electrode, Tauros, Jolteon |
| **MIRROR BALL** | Ball marts, ₽1200 | **4×** when the wild Pokémon is the same species as the one you have out. Send out your own Pidgey to catch a better Pidgey |
| **SILPH BALL** | Saffron Mart, ₽9800 | Silph Co's abandoned first pass at the Master Ball. When it works, it **is** a Master Ball. One throw in two, it just breaks |

Every ball is a real item on a real shelf — no cheats, no menu, no new
currency. Buy them and throw them.

<img src="docs/mart-shelf.png" width="360" alt="A Kanto mart's ball shelf listing NEST, HEAL, FAST, MIRROR and SILPH BALLs with prices">

*(The SNAG BALL on that shelf is from [Pokemon Snag](https://github.com/mistermiracle3036/Pokemon-Snag),
a separate mod of mine — it is not part of Kanto Balls.)*

### The Premier Ball pays for itself

Buy ten or more of any ball in **one** purchase and the clerk hands them
over free, and says so in his own text box:

<img src="docs/premier-bonus.png" width="360" alt="A mart clerk saying: I'll throw in 2 PREMIER BALLS too!">

### The Silph Ball tells you when it breaks

A failed throw is not a miss, and it does not pretend to be one:

<img src="docs/silph-broke.png" width="360" alt="Battle text reading: The PROTOTYPE broke apart!">

## Two mods, one download page

| Mod | What it does |
| --- | --- |
| **[kanto_balls](kanto_balls/)** | The seven balls above. **Requires shop_events.** |
| **[shop_events](shop_events/)** | Library mod. Emits `shop.purchased` whenever you buy something at a mart, because the engine has no purchase event of its own. Does nothing visible by itself. |

**Install both**, even if you only want the balls — the Premier Ball's
bonus is built entirely on shop_events.

> **Development Preview:** both mods are in active development. Bug
> reports and ideas are welcome in [Issues](../../issues) — say which
> mod, include the version from your load log, and list your other mods.

## Also for mod authors

`kanto_balls/main.lua` is written to be read and copied. The seven balls
are seven *different* techniques, deliberately: no catch code at all,
reacting to another mod's event, multiplying the rate from live battle
state, querying species data, reading base stats, reading your own side of
the battle, and replacing the catch roll outright. Each one is commented
with the engine file and line it was verified against.

Between them they cover most of what the ball API can do, which is why
this started life as **Example Balls**.

## Installation

1. Download **both** zips from the [latest release](../../releases/latest):
   `kanto_balls-X.Y.Z.zip` and `shop_events-X.Y.Z.zip`.
2. Launcher → **MODS** → **Import mod .zip**, once per zip.
3. Fully quit and relaunch.

Already have **Example Balls** (`example_balls`) installed? Remove it
first. It was renamed to Kanto Balls at 0.2.0, and because a new id
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
  optional. All seven balls register their own colors when it is
  installed, so each one has its own look during the throw:

  <img src="docs/ball-colors.png" width="520" alt="All nine Kanto Balls in their own colors: Premier, Nest, Moon, Heal, Fast, Mirror, Silph, GS and Beast">

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
