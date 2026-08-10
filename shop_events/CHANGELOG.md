# Changelog

All notable changes to Shop Events are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com); the top heading always
matches the version in `manifest.json`. Shop Events and Kanto Balls
share this repo and release IN LOCKSTEP -- every release retags both to
the SAME version and attaches both zips, even when only one changed (a
repo has one "latest release" for update-checking purposes, so a
mismatched tag would point the other mod at the wrong file).

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
