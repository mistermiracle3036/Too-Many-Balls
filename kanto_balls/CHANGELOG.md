# Changelog

All notable changes to Kanto Balls are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com); the top heading always
matches the version in `manifest.json`. Kanto Balls and Shop Events
share this repo and release IN LOCKSTEP -- every release retags both to
the SAME version and attaches both zips, even when only one changed (a
repo has one "latest release" for update-checking purposes, so a
mismatched tag would point the other mod at the wrong file).

## 0.4.3

**Updating from 0.3.4?** Everything since then: the mod is now called
**Too Many Balls** (this version), it runs on **Pokemon Gold** as well as
Red/Blue/Yellow (0.4.0 — five balls travel, MOON and FAST stay home since
Gold has its own, shelves at Great/Ultra marts, the prototype is labelled
PROTO BALL there), those Gold balls have their **own colours** rather than
throwing grey (0.4.2), the dev flag can stock every Johto mart (0.4.1),
three ball colours were retuned so no two look alike (0.3.5), and the repo
carries an MIT licence with credits in every download (0.4.0). How the
balls play on Red is unchanged throughout. Details under each version
below.

- **Renamed from "Kanto Balls" to "Too Many Balls."** The balls reach
  Johto now, so "Kanto" had stopped being true.
- **Nothing to do when you update, and nothing in your save changes.**
  Only the display name changed. The mod id is still `kanto_balls`, the
  download is still `kanto_balls-X.Y.Z.zip`, and every ball keeps the id
  it always had — so the mod browser updates it in place, your bag keeps
  its balls, and anything already caught keeps its record of which ball
  caught it. (Contrast the 0.2.0 rename from Example Balls, which *was* an
  id change and did need the old copy removed.)
- The GitHub repo moved to `Too-Many-Balls` to match. GitHub redirects the
  old address, so existing installs keep updating and old links keep
  working; both manifests now point at the new one.

**Fixes from the Gold test round:**

- **The free Premier Ball now works when you buy Gold's own balls.** Buying
  ten POKE BALLs awarded nothing, while ten of this mod's balls worked —
  the check was looking for a marker only our own items carry. It now asks
  what pocket the item lives in, which is how Gold itself decides what a
  ball is.
- **Seven bogus error lines are gone from the mod manager's [ERRS] screen.**
  Each ball reported "unresolved reference to balls" on a Gold boot. Purely
  cosmetic, but seven lines of noise is enough to bury a real error, which
  is the only thing that screen is for.
- **PREMIER BALL is now plain white when thrown**, instead of reading as an
  ordinary red-and-white Poké Ball.
- **GS BALL is a proper gold** rather than pale cream, with the silver as
  its highlight. Its old colour came from Gen 1, where the paleness existed
  only to avoid clashing with the Ultra Ball — a problem Gold doesn't have.

## 0.4.2

**Updating from 0.3.4?** Everything since then: the mod now runs on
**Pokemon Gold** as well as Red/Blue/Yellow (0.4.0 — five balls travel,
MOON and FAST stay home since Gold has its own, shelves at Great/Ultra
marts, the prototype is labelled PROTO BALL there), those Gold balls now
have their **own colours** instead of throwing grey (this version), the
dev flag can stock every Johto mart (0.4.1), three ball colours were
retuned so no two look alike (0.3.5), and the repo carries an MIT licence
with credits in every download (0.4.0). Red is unchanged throughout.

- **The Gold balls have colours now.** Gold picks a thrown ball's colour
  from the cart's own table, which only knows the eleven balls the cart
  ships — so ours all threw **grey**. Each one now has its own palette:
  Premier white-and-red, Nest green, Heal pink, Mirror pale silver, the
  prototype purple with its teal flash (plus GS and Beast under the dev
  flag).
- **These colours are a first pass and will need tuning.** They are
  carried over from the Gen 1 palette and have not been compared against
  Gold's own ball colours, which are a different set — expect at least
  one round of adjustment once they can be seen on a real throw.
- **MOON and FAST are left exactly as Gold draws them.** They are Kurt's
  balls there, and they should look like Kurt's balls.
- **Kanto Balls now owns ball colour on Gold**, because Pokeball Colors
  is a Gen 1-only mod by its author's decision and won't be colouring
  anything in Johto. Other ball mods can claim a colour through
  `exports.registerBallPalette(ballId, paletteName, row)` rather than
  installing a competing wrap — two mods wrapping the same method means
  load order decides the colour, silently. On Red nothing changes:
  Pokeball Colors still owns colour there.

## 0.4.1

**Updating from 0.3.4?** Everything since then, in one place: the mod now
runs on **Pokemon Gold** as well as Red/Blue/Yellow (0.4.0 — five balls
travel, MOON and FAST stay home since Gold has its own, shelves at
Great/Ultra-tier marts, the prototype is labelled PROTO BALL there),
three ball colours were retuned so no two balls look alike (0.3.5), and
the repo now carries a proper MIT licence with credits in every download
(0.4.0). On Red nothing about how the balls play has changed. The full
Gold details are under 0.4.0 below.

- **[DEV] CHEAP BALLS now stocks every Gold mart.** With the dev flag on,
  the balls (prototype included) appear at every mart in Johto — Violet,
  Cherrygrove, all of them — instead of only the Great/Ultra-tier ones,
  so a fresh Gold save can test the full set at the first counter it
  reaches. Prices are already 1 under the flag. Flag off: nothing
  changes, shelves stay Great/Ultra-tier. As ever, toggling it needs a
  full quit and relaunch.

## 0.4.0

- **Pokemon Gold support.** Both mods now declare `games: ["gen1",
  "gen2"]` and load on a Gold boot.
  - **Five balls come to Johto:** PREMIER, NEST, HEAL, MIRROR and the
    prototype ball, with the same behaviour as on Red. They are sold at
    the marts that already stock GREAT or ULTRA BALLs (the prototype
    only where ULTRA BALLs are sold), and sort into the BALLS pocket.
  - **MOON and FAST stay home.** Gold has its own native Moon Ball and
    Fast Ball under the same ids — ours step aside there rather than
    fight them. On Red both are unchanged.
  - **The SILPH BALL is called "PROTO BALL" on Gold** (display name
    only — same item, same id, same 1-in-2 fizzle). Silph Co doesn't
    exist in Johto, so the Kanto branding went. Its long-term Johto
    story (Kurt?) is still to be decided.
  - **The Premier bonus works on Gold** (10+ balls in one purchase, one
    free per 10) — but the clerk doesn't announce it yet; the balls
    arrive in the pocket silently. Gold's mart text has no seam for the
    announcement.
  - A Gold dud from the prototype shows the normal break-out text
    rather than "The PROTOTYPE broke apart!" — Gold picks its failure
    line inside the throw animation, which mods can't reach yet.
  - Every catch on Gold gets the `mon.caughtBall` mark from this mod
    (on Red, pokeball_colors owns the mark when installed).
  - Under the hood, for other mod authors: Gold's catch behaviour is
    ONE `catch.rate` wrap on the flat opts table (the throw site passes
    no registry data, so ball records don't reach the roll); shelves
    are a presence-checked append to `data.gen2Marts` (no registry
    exists yet); the BALLS pocket comes from stamping `pocket` onto the
    merged item records at game.ready. Each block in `main.lua` says
    which engine seam it uses and why.
- **MIT licence and visible credits.** `LICENSE` (MIT) at the repo root,
  and a Credits section in each mod's own README — the README is the one
  file that actually ships inside the zip, and until now the downloads
  carried no attribution at all. MIT covers our code; it claims nothing
  over ROM-derived material or Nintendo trademarks.
- This mod's README now shows the ball line-up and screenshots, and both
  screenshots and the ball grid ship on the repo.

## 0.3.5
- **Three ball colours retuned so they stop looking like other balls.**
  Measured rather than eyeballed: every ball a player could have installed
  was converted to CIE Lab and compared by perceptual distance, weighting
  the body colour since at this sprite size the body is most of the pixels.
  - **NEST** `132,172,84` → `80,200,128`. It sat **5.9 dE** from the
    native SAFARI BALL — the worst clash in the set, and one every player
    saw, since Safari is vanilla. Now 25.8.
  - **BEAST** `44,72,148` → `16,24,56`. It was **10.2 dE** from our own
    MOON BALL, and crowded GREAT and SILPH too. Dropping the value clears
    all three at once, because value contrast is what survives at 8px —
    and near-black under a yellow flash is Ultra Beast livery anyway.
  - **GS** `224,188,76` → `248,224,160`. It was **2.2 dE** from Custom
    Poke Balls' LEVEL BALL — effectively the same ball — and 14.6 from the
    native ULTRA. Pale gold clears both and reads more "gold *and*
    silver".
  - Result: always-present collisions drop from six pairs to one.
- **PREMIER and HEAL deliberately left alone.** Premier is close to Custom
  Poke Balls' TIMER, and Heal to its DREAM, but both pairs are close
  because both balls are canonically that colour. Moving ours would cost
  more identity than it buys, and neither clash exists without that mod.
- **`mon.caughtBall` is now written only as a fallback.** pokeball_colors
  owns that field — it declares `exports.owns.caughtBallField` and writes
  it for the heal machine's per-ball colours — and its ownership note says
  other mods must not write it. 0.3.1–0.3.4 wrote it unconditionally,
  which duplicated that write. Harmless in practice (both sides guard on
  nil and store the same value) but a contract breach. This mod now writes
  it only when nothing else claims it, so the GS BALL's mark still exists
  for someone running Kanto Balls without pokeball_colors.

## 0.3.4
- **Repo renamed from `Shop-Tools---Custom-Balls` to `Kanto-Balls`.** The
  manifest's `github` field follows it, which is the only part that had to
  change in code — it is what the launcher's update check and "other
  versions" list read.
- Nothing breaks for anyone already running this. GitHub permanently
  redirects the old repository across web, git and API, and the launcher
  fetches with `curl -sSL` (HostShell.lua), which follows redirects. Old
  download links keep resolving too. The manifest is updated so the stored
  string stops being a lie, not because anything depended on it.
- README and FAQ retitled to match.

## 0.3.3
- Documentation only. No code change.
- The repo README led with "Example Balls — four new balls", which had
  been wrong since 0.2.0 and undersold the mod to anyone deciding whether
  to download it. It now leads with the seven balls, what each one is
  actually good for, and where to buy it.
- Corrected the SILPH BALL fizzle rate in this README: it has been one
  throw in **two** since 0.3.0, not one in four.
- Documented that every catch is marked with `mon.caughtBall`, and that
  the engine does not record this itself — it is what lets Kanto Ribbons
  award a ribbon for how something was caught.
- FAQ updated for the rename: `example_balls` had survived in five places.
- Noted in the compatibility section that the mart shelves are verified
  present in Yellow's data but have only been played on Red/Blue.

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
