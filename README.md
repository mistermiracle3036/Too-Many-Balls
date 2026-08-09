# Shop Tools - Custom Balls

Two gen1recomp mods, released together from one repo:

| Mod | What it does |
| --- | --- |
| **[shop_events](shop_events/)** | Library mod. Emits `shop.purchased` whenever the player buys something at a mart — the engine has no purchase event of its own. No visible behavior by itself. |
| **[example_balls](example_balls/)** | Four new balls, each demonstrating a different mod-API pattern: **Premier** (free from the clerk when you buy 10+ of a ball at once), **Nest**, **Moon**, **Heal**. Requires shop_events. |

Install shop_events even if you only want the balls — example_balls
depends on it. Colors for all four balls register automatically if
[Pokeball Colors](https://github.com/mistermiracle3036/Pokeball-Colors)
is also installed; neither mod here requires it.

> **Development Preview:** both mods are in active development. Bug
> reports and ideas are welcome in [Issues](../../issues) — say which
> mod, include the version from your load log, and list your other
> mods.

## Why one repo, two mods

They're released here together, but they're **not one mod** — each has
its own manifest, its own id, and its own on/off toggle in the F10 mod
browser. shop_events is meant to be reusable by other authors' mods
independent of the ball pack, so keeping it a separate install matters.

The one consequence of sharing a repo: **every release retags and
re-zips both mods to the same version number**, even when only one of
them actually changed. See each mod's CHANGELOG for why.

## Installation

See each mod's own README (linked above) for its specific steps —
short version: download the release zip(s) for what you want, Import
mod .zip, quit and relaunch. shop_events is required by example_balls
either way.

## Compatibility

- **[Pokeball Colors](https://github.com/mistermiracle3036/Pokeball-Colors)** —
  optional. example_balls registers canon colors for all four of its
  balls when Pokeball Colors is installed.
- **[Custom Poké Balls](https://github.com/magalvao/custom-pokeballs)**
  by magalvao — coexists; both append to the same mart shelves.
- **[Pokémon Snag](https://github.com/mistermiracle3036/Pokemon-Snag)** —
  no direct interaction.

## Credits

By **Mister Miracle**
([@mistermiracle3036](https://github.com/mistermiracle3036)).
Built for [gen1recomp](https://github.com/bryanthaboi/gen1recomp).
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
