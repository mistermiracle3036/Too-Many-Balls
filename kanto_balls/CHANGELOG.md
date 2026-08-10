# Changelog

All notable changes to Kanto Balls are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com); the top heading always
matches the version in `manifest.json`. Kanto Balls and Shop Events
share this repo and release IN LOCKSTEP -- every release retags both to
the SAME version and attaches both zips, even when only one changed (a
repo has one "latest release" for update-checking purposes, so a
mismatched tag would point the other mod at the wrong file).

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
