# Changelog

All notable changes to Example Balls are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com); the top heading always
matches the version in `manifest.json`. Example Balls and Shop Events
share this repo and release IN LOCKSTEP -- every release retags both to
the SAME version and attaches both zips, even when only one changed (a
repo has one "latest release" for update-checking purposes, so a
mismatched tag would point the other mod at the wrong file).

## 0.1.5
- Repo renamed to Shop Tools - Custom Balls for clarity; manifest
  `github` field updated to match. No code change. Released in lockstep
  with Shop Events per the repo's versioning rule.

## 0.1.4
- Repo move: now shares a repo with Shop Events (manifest `github` field
  added). Version jumps 0.1.2 -> 0.1.4 to stay in lockstep with Shop
  Events' number, not because of any code change here.

## 0.1.2
- PREMIER BALL simplified per design review: awarded only for 10+ balls
  in a SINGLE purchase, floor(qty/10). The cross-purchase progress
  counter is gone.
- The clerk now announces the bonus in the shop text box ("I'll throw
  in a PREMIER BALL, too!" / "I'll throw in N PREMIER BALLS too!") by
  swapping the _PokemartBoughtItemText entry just before the engine
  reads it and restoring it on the next purchase. Non-destructive.

## 0.1.1
- MOON BALL moved from Cerulean Mart to Pewter Mart, so it is buyable
  before Mt. Moon rather than after.
- Premier award now reads save/data straight from the shop.purchased
  payload (shop_events 0.1.1) instead of a captured game reference.
- Requires shop_events 0.1.1+.

## 0.1.0
- Initial release: PREMIER (free per 10 balls bought via shop_events),
  NEST (level-scaled), MOON (Moon Stone evolvers, sold at Cerulean),
  HEAL (full heal on catch). Canon colors registered into Pokeball
  Colors when installed.
