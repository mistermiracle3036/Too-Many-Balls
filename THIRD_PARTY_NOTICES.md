# Third-party notices

Both mods in this repo are released under the MIT licence (see
`LICENSE` at the repo root). That licence covers **our code and our
original content only** — it makes no claim over ROM-derived material,
over the gen1recomp engine, or over Nintendo / Creatures / GAME FREAK
trademarks.

- **gen1recomp** — both mods target the
  [gen1recomp](https://github.com/bryanthaboi/gen1recomp) engine (mod
  API 2) and reach engine internals under the `engine_internals`
  permission.
- **Custom Poké Balls** by magalvao
  (https://github.com/magalvao/custom-pokeballs) — kanto_balls' mart
  shelf mechanism (`text_pointers:patch` on clerk TEXT entries) follows
  the pattern that mod established. No code or assets from it are
  included.
- **Pokeball Colors** (https://github.com/mistermiracle3036/Pokeball-Colors)
  — optional integration on both generations, in opposite directions and
  through public surfaces only; no code is shared or duplicated. On Gen 1
  kanto_balls registers its own color values into that mod's public
  table. On Gold the flow reverses: kanto_balls owns the thrown ball's
  palette, and Pokeball Colors reads it back out to colour the Pokemon
  Center heal machine.
- Pokémon and all related names are trademarks of Nintendo / Creatures
  Inc. / GAME FREAK inc. Neither mod contains ROM data or copyrighted
  assets; both are fan-made script mods and require the user's own game
  copy via gen1recomp.
