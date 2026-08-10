# Changelog

All notable changes to Kanto Balls are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com); the top heading always
matches the version in `manifest.json`. Kanto Balls and Shop Events
share this repo and release IN LOCKSTEP -- every release retags both to
the SAME version and attaches both zips, even when only one changed (a
repo has one "latest release" for update-checking purposes, so a
mismatched tag would point the other mod at the wrong file).

## 0.3.2
- **BEAST BALL now SETS the catch rate on a legendary instead of
  multiplying it.** The 5x from 0.3.0 was very nearly a no-op, and the
  stock formula says exactly why: `stockAttempt` fails outright when
  `rng(0, randMax) > rate`. With `randMax` 255, a legendary's catch rate
  of 3 multiplied by 5 is 15, so that gate passes about 6% of the time.
  Five times almost nothing is still almost nothing.
- Measured, not theorised: many Beast Balls against Entei and Mewtwo,
  neither caught, and *mostly zero shakes* — the signature of that first
  gate failing.
- It now sets the rate to 255 for legendaries, which makes that gate
  certain and leaves the HP term as the only barrier. A legendary at full
  HP still resists roughly two throws in three; a weakened one is close to
  certain. The ball ignores the catch RATE, not the fight.
- The 0.2x penalty against non-legendaries is unchanged, and was confirmed
  working on device.

## 0.3.1
- **Records which ball caught each Pokemon** as `mon.caughtBall`, on the
  Pokemon itself, for every ball this mod adds.
- This turned out to be necessary rather than optional: **the engine does
  not record it.** `caughtBall` appears nowhere in engine 0.1.75 --
  `storeCaughtMon` puts the ball in the `pokemon.caught` payload and then
  discards it. So through 0.3.0 the GS BALL left no mark at all, and its
  entire purpose is the mark.
- Writing an extra field onto the mon table is the same mechanism
  snag_quest already uses for `mon.snagged`, which kanto_ribbons already
  reads, so it is proven on this engine rather than assumed.
- Written once and never overwritten: a Pokemon is caught once, and a
  later trade or evolution must not relabel it.

## 0.3.0
- **SILPH BALL now fizzles 1 throw in 2**, up from 1 in 4. Partly tuning,
  partly diagnostic: ~6-8 throws on 0.2.3 never broke, which is a ~10%
  outcome at 25% odds -- suspicious but not proof. At 50% the same result
  would be ~1.6%, which would be proof the failure path never fires. The
  path itself was verified against engine source first, so a repeat is
  evidence about the roll and nothing else.
- **New: GS BALL and BEAST BALL**, both behind a new `[DEV] CHEAP BALLS`
  option (default OFF).
  - GS BALL has no `attempt()` at all and catches like a Poke Ball. The
    reward is the persisted mark -- `mon.caughtBall` -- which kanto_ribbons
    will read. No ribbon logic lives here.
  - BEAST BALL is 5x against a legendary and 0.2x against everything else.
    "Legendary" is read from live species data (`catchRate <= 3`) rather
    than a hardcoded list, so a mod that adds legendaries is covered for
    free. **Measured on device, not assumed:** with Kanto Ascendant's
    Johto species loaded, `catchRate <= 3` matched exactly ten species, all
    legendary, no false positives -- a hardcoded Kanto list would have
    silently ignored the six new ones.
  - **MEW is a documented exception.** Gen 1 gives Mew catch rate 45, so a
    pure rate test would have the Beast Ball actively *hurt* the most
    famous legendary in the game. One named exception, not a list.
- **New option `[DEV] CHEAP BALLS`** (default OFF): drops every Kanto Balls
  price to 1 and puts GS and BEAST on the ball shelves. With it off, the
  two are never registered at all -- they cannot appear in a bag, a mart or
  the item list. **Toggling it requires a full quit and relaunch**: the
  option is read during the mod's entry chunk and folded into the merged
  registries afterwards, and nothing re-reads it later.
- **Declares `example_balls` in `conflicts`**, and reports a one-line
  notice to [ERRS] if the old mod is still installed. A rename cannot be
  redirected -- the mod id is the identity, and `installZip` refuses a zip
  whose manifest id differs -- so nothing stops both being installed at
  once and registering overlapping balls. This is the guard against that.
- Removes the temporary 0.2.4/0.2.5 diagnostic; it has served its purpose.
- No change to NEST, MOON, HEAL, PREMIER, FAST or MIRROR. FAST and MIRROR
  were verified correct against engine source rather than altered:
  `targetDef.baseStats.speed` and `battle.player.mon.species` are both the
  right paths, and `ctx.targetDef` is populated in wild battles.

## 0.2.5
- Same diagnostic as 0.2.4, reformatted to fit the [ERRS] screen. No
  gameplay change.
- 0.2.4 printed sentences, which ran off the screen. [ERRS] word-wraps
  every entry at 16 columns into an 11-row window
  (`ManagerState.errorLines` / `LIST_ROWS`) and `reportError` prepends
  "kanto_balls: ", which costs a whole row by itself -- so each fact took
  about five rows. Output is now short packed tokens: `SPD DIG95 DUG120`,
  `FAST n/total`, `CR3 N=n`, then the qualifying species names packed into
  a single message, since word wrap fits two names per row.
- Drops the per-map A/B search. DIGLETT 95 / DUGTRIO 120 was confirmed on
  device, so Diglett's Cave is a valid single-location A/B for the Fast
  Ball and the search is no longer worth the rows it costs.

## 0.2.4
- **Test build. Adds a temporary diagnostic and nothing else** -- no ball
  behavior changes at all. Remove before 0.3.0 ships.
- Reports four lines to the mod manager's [ERRS] screen on the first
  `game.ready` of a session: DIGLETT and DUGTRIO base speeds, how many
  species clear the Fast Ball's speed-100 threshold, up to three maps
  whose encounter table holds a species on BOTH sides of that threshold
  (a single-location A/B test), and which species have `catchRate <= 3`.
- Why it exists: base stats and catch rates are extracted from the ROM at
  import time, so they are not readable from the engine repo -- it ships
  only a three-species test fixture. These numbers can only be observed on
  a real device with a real dataset, and both the Fast Ball threshold and
  the planned Beast Ball discriminator depend on them.
- Output goes through `Runtime.reportError`, not `mod.log`, because the
  log console does not exist on iOS.

## 0.2.3
- Confirmed against pokeball_colors 0.1.13: comments now cite that
  version specifically. No behavior change -- 0.2.2 already called
  `registerColors` with a fallback for pre-helper installs, which is
  the shape 0.1.13 documents.

## 0.2.2
- Colors now register via Pokeball Colors' `registerColors(colors)`
  export (0.1.12+) instead of hand-writing the find/null-check/absent-
  check loop here. Falls back to the old direct-write for anyone still
  on an older Pokeball Colors without the helper.

## 0.2.1
- SILPH BALL: a failed throw now says "The PROTOTYPE broke apart!"
  instead of the stock "You missed the POKeMON!" -- you didn't miss, the
  ball broke. Done by wrapping `BattleState:ballMissMessage`, since the
  ball record has no way to set that text.

## 0.2.0
- **Renamed.** `example_balls` / "Example Balls" is now `kanto_balls` /
  "Kanto Balls". The mod id changed, so this installs as a new mod --
  remove Example Balls if you had it. (Done now, at zero downloads, so
  that no one's install gets orphaned later.) The code is still written
  to be read and copied; it just isn't only a demo any more.
- **FAST BALL** (1000, Great/Ultra marts): 4x against species with base
  Speed 100 or higher, read from `targetDef.baseStats` so a mod that
  retunes base stats retunes this too.
- **MIRROR BALL** (1200, Great/Ultra marts): 4x when the wild Pokemon is
  the same species as the one you currently have out.
- **SILPH BALL** (9800, Saffron Mart): Silph Co's abandoned Master Ball
  prototype. A guaranteed catch three throws in four; the fourth
  fizzles, and the ball is spent either way. Master-tier toss animation
  and flicker. The mart shelf is temporary scaffolding for testing --
  the intent is a Silph employee handing you exactly one after the
  takeover.
- Ownership is now declared explicitly: `exports.owns.balls` lists every
  id this mod owns, records and colors both.

## 0.1.5
- Repo renamed to Shop Tools - Custom Balls for clarity; manifest
  `github` field updated to match. No code change. Released in lockstep
  with Shop Events per the repo's versioning rule.
