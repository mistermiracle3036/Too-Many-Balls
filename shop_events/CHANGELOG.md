# Changelog

All notable changes to Shop Events are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com); the top heading always
matches the version in `manifest.json`. Shop Events and Kanto Balls
share this repo and release IN LOCKSTEP -- every release retags both to
the SAME version and attaches both zips, even when only one changed (a
repo has one "latest release" for update-checking purposes, so a
mismatched tag would point the other mod at the wrong file).

## 0.4.13
- No code change. Lockstep release with Too Many Balls 0.4.13.

## 0.4.12
- No code change. Lockstep release with Too Many Balls 0.4.12.

## 0.4.11
- No code change. Lockstep release with Too Many Balls 0.4.11.

## 0.4.10
- No code change. Lockstep release with Too Many Balls 0.4.10.

## 0.4.9
- No code change. Lockstep release with Too Many Balls 0.4.9.
- Verified against engine v0.1.79: the shared till sound and `Bag.add`
  path this mod listens to are unchanged on both generations.

## 0.4.8
- No code change. Lockstep release with Too Many Balls 0.4.8.

## 0.4.7

**Now works on Pokémon Gold.** Everything below has landed since the last
release (v0.3.4).

- **Gold support.** Gold's mart is a different screen from Kanto's, but
  purchases ring the same till this mod listens to — so `shop.purchased`
  fires on Gold buys exactly as it does on Red. Selling still never fires
  it, on either game.
- **A scripted item gift can no longer be mis-reported as a purchase.**
  Gold rings the same sound when you *sell*, which made a stale entry
  possible; it's now cleared before it can be misread.
- **An MIT licence and a credits section**, which ship inside the download.
- The ball mod this pairs with is now called **Too Many Balls** (was Kanto
  Balls) and the repo moved to `Too-Many-Balls`. Shop Events keeps its own
  name and id; existing installs keep updating, and old links redirect.

## 0.4.5
- No code change. Lockstep release with Too Many Balls 0.4.5.

## 0.4.4
- No code change. Lockstep release with Too Many Balls 0.4.4.

## 0.4.3
- No code change. Lockstep release with Too Many Balls 0.4.3.
- The ball mod this pairs with was renamed from **Kanto Balls** to **Too
  Many Balls**, and the repo moved to `Too-Many-Balls`; this manifest's
  `github` field follows it. Shop Events itself is unchanged, keeps its
  name and its `shop_events` id, and existing installs keep updating —
  GitHub redirects the old repo address.

**Updating from 0.3.4?** This mod gained Pokemon Gold support in 0.4.0
(details below); 0.3.5, 0.4.1, 0.4.2 and 0.4.3 were no-change lockstep
releases.

## 0.4.2
- No code change. Lockstep release with Kanto Balls 0.4.2.

**Updating from 0.3.4?** This mod gained Pokemon Gold support in 0.4.0
(details below); 0.3.5, 0.4.1 and 0.4.2 were no-change lockstep releases.

## 0.4.1
- No code change. Lockstep release with Kanto Balls 0.4.1.

**Updating from 0.3.4?** This mod gained Pokemon Gold support in 0.4.0
(details below); 0.3.5 was a no-change lockstep release.

## 0.4.0

**Updating from 0.3.4?** This mod gained Pokemon Gold support in this
version; 0.3.5 between was a no-change lockstep release.

- **Pokemon Gold support** (`games: ["gen1", "gen2"]`). Gold's mart is a
  different screen but buys land through the same shared `Bag.add` and
  ring the till through the same shared `Sound.play` — the event now
  recognises Gold's till sound (`Sfx_Transaction`) alongside Gen 1's
  (`Purchase`), so `shop.purchased` fires on Gold buys unchanged.
- **Gold sells stay silent.** Gold rings the same till when the player
  SELLS (Gen 1 doesn't); a sell gains nothing in the bag and emits no
  event, and no longer triggers the "nothing gained" diagnostic.
- **A stale fast-path entry can no longer leak.** A scripted item gift
  looks like a purchase to the `Bag.add` fast path; any unrelated sound
  now clears it, so a gift followed by a Gold sell can't be mis-reported
  as a purchase. The inventory diff remains the source of truth.
- MIT licence at the repo root and a Credits section in this README —
  the README is the one file that ships inside the zip.
- Lockstep release with Kanto Balls 0.4.0.

## 0.3.5
- No code change. Lockstep release with Kanto Balls 0.3.5.

## 0.3.4
- Repo renamed from `Shop-Tools---Custom-Balls` to `Kanto-Balls`; this
  manifest's `github` field follows it. Existing installs are unaffected —
  GitHub redirects the old name and the launcher follows redirects.
- Lockstep release with Kanto Balls 0.3.4.

## 0.3.3
- No code change. Lockstep release with Kanto Balls 0.3.3.

## 0.3.2
- No code change. Lockstep release with Kanto Balls 0.3.2.

## 0.3.1
- No code change. Lockstep release with Kanto Balls 0.3.1.

## 0.3.0
- No code change. Lockstep release with Kanto Balls 0.3.0.

## 0.2.5
- No code change. Lockstep release with Kanto Balls 0.2.5.

## 0.2.4
- No code change. Lockstep release with Kanto Balls 0.2.4.

## 0.2.3
- No code change. Lockstep release with Kanto Balls 0.2.3.

## 0.2.2
- No code change. Lockstep release with Kanto Balls 0.2.2.

## 0.2.1
- No code change. Lockstep release with Kanto Balls 0.2.1.

## 0.2.0
- No code change. Lockstep release with Kanto Balls 0.2.0, which is the
  rename of Example Balls (mod id `example_balls` -> `kanto_balls`) plus
  three new balls. Documentation updated to name the new consumer.

## 0.1.5
- Repo renamed to Shop Tools - Custom Balls for clarity; manifest
  `github` field updated to match. No code change. Released in lockstep
  with Example Balls per the repo's versioning rule.

## 0.1.4
- Repo move: now shares a repo with Example Balls (manifest `github`
  field added). No code change. Future releases retag both mods
  together -- see the lockstep note above.

## 0.1.3
- FIX: the Premier Ball award finally works. On-device diagnostics showed
  the Purchase-sound stage firing while the Bag.add wrap never ran --
  another installed mod is re-wrapping Bag.add from a stale original and
  orphaning ours. We no longer depend on that seam: the item and quantity
  now come from diffing save.inventory against a snapshot refreshed on
  every other sound (menu confirms fire Press_AB). The Bag.add wrap is
  kept only as a fast path.
- Diagnostics now name which path resolved each purchase.

## 0.1.2
- Diagnostics are now VISIBLE on device. 0.1.1 wrote them with
  mod.log:info, which goes to a console iOS does not have -- so the
  stage probes could never be read. They now also go through
  Runtime.reportError, which appends to the same list the mod manager's
  [ERRS] screen renders. Entries there are notices, not failures.
- Added a load-time probe line, so [ERRS] proves whether the wraps
  installed at all before any purchase is made.
- Option renamed to "Show purchase diagnostics" (default ON). Turn it
  off to keep [ERRS] clean once this is working.

## 0.1.1
- FIX ATTEMPT + diagnostics: 0.1.0's Premier Ball award never fired.
  Removed the ShopMenu.new "mart is open" wrap entirely -- the Purchase
  sound has exactly one call site in the engine (the buy path), so it
  alone is a sufficient discriminator, and the extra wrap added two
  silent failure modes (including replacing a nil onQuit with a
  function, which changed Menu's QUIT/onCancel behavior).
- Payload now also carries `save` and `data` from the Bag.add call, so
  listeners never depend on a captured game reference.
- New DEBUG option (default ON) logging each stage, so a failure names
  the missing signal instead of being invisible.

## 0.1.0
- Initial release: emits `shop.purchased { id, qty, game }` once per
  confirmed mart purchase. Triple-confirmed against the buy path only
  (mart open + bag add + the Purchase sound), so sells, PC withdrawals
  and script gifts never fire it.
