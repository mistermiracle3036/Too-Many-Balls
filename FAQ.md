# Shop Tools - Custom Balls — FAQ

Every answer is collapsed. Tap only what you want revealed.

## General

<details>
<summary>Do I need shop_events if I only want the balls?</summary>

Yes. example_balls hard-depends on it — the Premier Ball's bonus is
implemented entirely as a shop_events listener. Install both zips from
the same release.
</details>

<details>
<summary>Why are two mods in one repo?</summary>

They ship together because example_balls needs shop_events, but they
stay two separate installs/toggles/manifests — shop_events is a small
reusable library other mod authors can depend on independent of the
ball pack. See the main README for the one real consequence of sharing
a repo (synced version numbers on every release).
</details>

## Shop Events

<details>
<summary>What does shop_events actually change in my game?</summary>

Nothing by itself. It's a library: it adds one event other mods can
listen to (`shop.purchased`). With nothing installed that uses it, you
won't notice it's there.
</details>

<details>
<summary>DEBUG option is on and I see stage lines in [ERRS]. Is
something broken?</summary>

No — those are notices, not failures. `mod.log` has no console on iOS,
so shop_events reports its diagnostics through the same feed the mod
manager's [ERRS] screen already shows, which is the only place they're
visible on-device. Turn "Show purchase diagnostics" off in shop_events'
OPTIONS once you've confirmed purchases are being detected.
</details>

## Example Balls

<details>
<summary>I bought 9 balls and got no Premier Ball. Bug?</summary>

No — it takes **10 or more of the same ball in a single purchase**. The
mart rings each item up separately, so 5 Poké Balls plus 5 Great Balls
counts as two purchases of 5, not one of 10. Buying 5 now and 5 later
doesn't stack either.
</details>

<details>
<summary>Where's my Premier Ball / how do I know I got one?</summary>

The mart clerk's own text box says so — "I'll throw in a PREMIER BALL,
too!" (or "...N PREMIER BALLS too!" for more than one) — right where
the normal "Here you are! Thank you!" line would be. Check your bag's
BALLS pocket after.
</details>

<details>
<summary>Where do I buy Moon Ball / Nest Ball / Heal Ball?</summary>

Moon Ball: Pewter Mart, before Mt. Moon. Nest and Heal: any mart that
already carries Great or Ultra Balls (same shelves Custom Poké Balls
uses). Premier Ball is never sold — see above.
</details>

<details>
<summary>Does Heal Ball do anything besides heal on catch?</summary>

No — normal catch odds, like a Poké Ball. The only difference is the
Pokémon arrives at full HP with status cleared and every move's PP
restored.
</details>

<details>
<summary>Can I use this as a template for my own ball mod?</summary>

Yes — that's the point. `example_balls/main.lua` is heavily commented;
each of the four balls demonstrates one self-contained API pattern with
the engine file/line it was verified against. Copy what you need.
</details>
