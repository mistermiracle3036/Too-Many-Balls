-- Kanto Balls
--
-- Custom balls for gen1recomp, on BOTH generations since 0.4.0: Red/
-- Blue/Yellow (Gen 1) and Gold (Gen 2).  This mod is also meant to be
-- READABLE: each ball is one self-contained pattern with the engine
-- file/line it was verified against (Gen 1 paths against engine 0.1.75,
-- Gen 2 paths against 0.1.78), so it can be copied into your own mod
-- and changed.
--
--   PREMIER  no catch code at all + listening to another mod's event
--   NEST     an attempt() that multiplies the catch rate from battle
--            state (the target's level)
--   MOON     an attempt() that queries engine species data (evolutions)
--            -- Gen 1 only: Gold has its own native MOON BALL
--   HEAL     no attempt() -- reacts to the pokemon.caught event instead
--   FAST     an attempt() reading the target's BASE stats
--            -- Gen 1 only: Gold has its own native FAST BALL
--   MIRROR   an attempt() reading YOUR side of the battle, not theirs
--   SILPH    an attempt() that replaces the roll outright, and can fail
--
-- Two more exist only behind the [DEV] CHEAP BALLS option, which also
-- drops every price to 1.  They are not earned content yet:
--
--   GS       no attempt() at all -- the reward is the persisted MARK
--            (mon.caughtBall), which kanto_ribbons reads
--   BEAST    an attempt() that reads live species data to decide what
--            counts as legendary, instead of a hardcoded list
--
-- HOW THE TWO GENERATIONS DIFFER (all verified against 0.1.78 source):
--
-- On Gen 1 a ball needs three registrations (see registerBall below):
--   1. mod.content.balls:register(id, record)   -- the catch behavior
--   2. mod.content.items:register(id, record)   -- the bag/mart item
--   3. ItemEffects.BALLS[id] = true             -- bag "toss" targeting
-- and a text_pointers mart patch to be obtainable.
--
-- On Gold none of those seams carry the behavior:
--   * The throw site (src/ui/gen2/BattleState.lua:2578) hands
--     Catching.attempt a FLAT opts table with no `data` key, so a
--     record in the merged `balls` registry never reaches the roll.
--     What IS live is the `catch.rate` hook -- its own comment
--     (src/battle/gen2/Catching.lua:344-348) says a mod that edits
--     o.catchRate changes the roll exactly as on Red, and one that
--     returns `caught, rate` replaces it outright.  Confirmed on
--     device with a read-only probe (g2probe 0.1.0): the hook fires
--     per throw and o carries catchRate/level/species/playerSpecies/
--     evolveItem/weight/gender -- and NO base stats, which is why
--     FAST BALL could not port even if Gold didn't already have one.
--     So ALL Gen 2 catch behavior lives in ONE catch.rate wrap below.
--   * The items registry has no Gen 2 row in Schemas.GEN2, so it
--     merges into the SHARED data.items that Gold reads -- but the
--     schema has no `pocket` field, and src/ui/gen2/BattleState.lua
--     :useItem only treats pocket == "BALL" as a ball.  We stamp
--     `pocket` onto our merged records at game.ready (the same
--     post-merge pattern FAFF0x's mods use for def.icon).
--   * Mart shelves: data.gen2Marts has NO registry (one of the
--     twelve unrouted gen2* tables), but it is a plain table of
--     lists (MartMenu.inventory reads marts.lists[martId+1]) that
--     src/world/gen2/World.lua holds BY REFERENCE -- so a
--     presence-checked append at game.ready stocks a real shelf.
--     We append only to lists that already sell GREAT/ULTRA balls,
--     so early-game marts stay vanilla, and never touch what other
--     mods added.  When the engine grows a marts registry this block
--     should move onto it.
--   * pokemon.caught fires on Gold with the same payload
--     (src/ui/gen2/BattleState.lua:2291), so HEAL and the caughtBall
--     mark port for free.
--
-- (Renamed from `example_balls` at 0.2.0.  Same repo, same lockstep
-- versioning with shop_events.)

return function(mod)
  local VERSION = "0.4.0"
  mod.exports.version = VERSION

  -- Which generation THIS boot is -- fixed for the whole run, the same
  -- call the loader itself uses (src/mods/Loader.lua:242).  Registries
  -- merge once after the entry chunks, so "what to register" has to be
  -- decided here, not at game.ready; this is the one place a
  -- generation check beats capability detection.
  local GameVersion = require("src.core.GameVersion")
  local GEN2 = GameVersion.generation() == 2

  local Bag = require("src.inventory.Bag")
  local Runtime = require("src.mods.Runtime")
  -- Gen 1 engine modules.  On a Gold boot the compat layer serves both
  -- as inert siblings (verified: gen2check reports no finding for
  -- either), and every USE below is gated on generation -- required
  -- unconditionally so the static scan can follow where they go.
  local ItemEffects = require("src.inventory.ItemEffects")
  local Pokemon = require("src.pokemon.Pokemon")

  ----------------------------------------------------------------------
  -- OPTIONS -- read at LOAD time, which is only legal because of the
  -- order in src/mods/Loader.lua: Loader:load calls _loadState() (which
  -- fills loader.modOptions from the persisted options file) at line 940,
  -- BEFORE the loop at 963 that runs each mod's entry chunk.  So a get()
  -- here returns the player's stored value, not a default.
  --
  -- define() MUST come before get(): options.get falls back to a row's
  -- `default` by looking it up in loader.optionSchemas[modId], and that
  -- table is empty until define() populates it.  Get first and a
  -- first-run player -- who has nothing stored -- reads nil instead of
  -- the default.  (nil is falsy so this one would happen to work, but
  -- the next option with a true default would not.)
  --
  -- Row shape verified against ManagerState:buildOptionRows: a toggle is
  -- { key, type = "toggle", label, default } and renders ON/OFF.
  ----------------------------------------------------------------------
  mod.options:define({
    { key = "cheap_balls", type = "toggle",
      label = "[DEV] CHEAP BALLS", default = false },
  })

  -- Everything this flag changes -- prices, which balls exist, which
  -- shelves carry them -- is decided during THIS entry chunk and folded
  -- into the merged registries afterwards (the merge loop runs after
  -- every entry chunk in Loader:load).  Nothing re-reads it later, so
  -- toggling the option takes effect only after a full quit and relaunch.
  local CHEAP = mod.options:get("cheap_balls") == true

  -- Ownership, declared so other mods (notably pokeball_colors) can
  -- check at runtime instead of via a handoff note.  This mod owns
  -- these ball records WHOLE -- record fields AND their colors.  No
  -- other mod should register a color for these ids; we publish ours
  -- into pokeball_colors ourselves at the bottom of this file.
  --
  -- MOON and FAST are Gen 1 only: Gold ships native Apricorn balls
  -- under the SAME ids (measured from tools/rom_manifest_gold.json,
  -- exactly those two collide), and our mechanics happen to match the
  -- modern canon for both -- so on Gold the natives simply stand and
  -- we register nothing.  Never change a shipped id to dodge this:
  -- SILPH_BALL etc. are in players' save bags and in mon.caughtBall.
  local BALL_IDS = {
    "PREMIER_BALL", "NEST_BALL", "HEAL_BALL", "MIRROR_BALL", "SILPH_BALL",
  }
  if not GEN2 then
    BALL_IDS[#BALL_IDS + 1] = "MOON_BALL"
    BALL_IDS[#BALL_IDS + 1] = "FAST_BALL"
  end
  -- GS and BEAST exist only under the dev flag, so they are appended to
  -- the owned set rather than baked into it -- pokeball_colors warns
  -- about a registered ball with no colour, and would otherwise warn
  -- about two balls that do not exist.
  if CHEAP then
    BALL_IDS[#BALL_IDS + 1] = "GS_BALL"
    BALL_IDS[#BALL_IDS + 1] = "BEAST_BALL"
  end
  local OWNED = {}
  for _, id in ipairs(BALL_IDS) do OWNED[id] = true end
  mod.exports.owns = { kanto_balls = true, balls = OWNED }
  mod.exports.balls = BALL_IDS

  ----------------------------------------------------------------------
  -- shared helper: every registration a ball needs, per generation.
  --
  -- Gen 1: the classic three (balls record, items record, bag toss
  -- targeting).  Gen 2: ONLY the items record -- the balls registry
  -- routes to data.gen2Balls but nothing at the Gold throw site reads
  -- a mod's record there (see the header), so registering one would
  -- just be dead weight; the behavior lives in the catch.rate wrap.
  ----------------------------------------------------------------------
  local function registerBall(id, name, price, ballRecord)
    -- [DEV] CHEAP BALLS: every ball this mod sells costs 1, so a shelf
    -- can be cleared for testing without grinding money first.
    if CHEAP then price = 1 end
    -- items schema accepts ONLY: id, name, index, price, machine,
    -- effect, ball, tossable, needsTarget (strict validation)
    mod.content.items:register(id, {
      id = id, name = name, price = price,
      tossable = true, ball = id,
    })
    if GEN2 then return end
    -- poke-ball-tier stock numbers; attempt (if any) supersedes them
    ballRecord.randMax = ballRecord.randMax or 255
    ballRecord.hpFactor = ballRecord.hpFactor or 12
    ballRecord.wobbleFactor = ballRecord.wobbleFactor or 255
    ballRecord.tossAnim = ballRecord.tossAnim or "TOSS_ANIM"
    mod.content.balls:register(id, ballRecord)
    ItemEffects.BALLS[id] = true
  end

  -- every attempt() below multiplies the same way: the stock formula
  -- reads `rateOverride or targetDef.catchRate` (Catching.lua:44), so a
  -- multiplier is "rewrite ctx.rateOverride, then delegate".  Never
  -- reimplement the roll.
  local function boost(ctx, mult)
    local rate = ctx.rateOverride or ctx.targetDef.catchRate or 45
    ctx.rateOverride = math.min(255, rate * mult)
  end

  ----------------------------------------------------------------------
  -- PREMIER BALL -- the minimum viable ball.
  -- No attempt() at all: with only the stock numbers above it catches
  -- exactly like a Poke Ball.  All of its interest is in HOW you get
  -- one: never sold; buy 10+ balls IN ONE PURCHASE at any mart and the
  -- clerk throws in floor(qty/10) Premier Balls free (buy 20, get 2),
  -- announced in the clerk's own text box.
  --
  -- The announcement trick (GEN 1 ONLY): the shop footer is a bare
  -- table read -- game.data.text["_PokemartBoughtItemText"]
  -- (ShopMenu.lua:21) -- executed immediately AFTER the Purchase sound
  -- in the same callback.  Our shop.purchased listener runs DURING that
  -- sound (shop_events emits from its Sound.play wrap), i.e. just
  -- before the read.  So: swap the stored string for the award line,
  -- and restore it at the top of the next purchase.  Non-destructive;
  -- the original is stashed once per loaded game.
  --
  -- On Gold the award itself works unchanged (shop_events 0.4.0 hears
  -- Gold's till), but the clerk line does not: Gold's mart text comes
  -- from the ROM text walker via MartMenu, not from a data.text slot we
  -- can swap.  The balls arrive silently in the BALLS pocket.  A
  -- visible announcement needs a MartMenu seam that does not exist yet.
  ----------------------------------------------------------------------
  registerBall("PREMIER_BALL", "PREMIER BALL", 200, {})

  local boughtText = { original = nil, swapped = false }

  local function restoreBoughtText(game)
    if boughtText.swapped and game and game.data and game.data.text then
      game.data.text["_PokemartBoughtItemText"] = boughtText.original
      boughtText.swapped = false
    end
  end

  mod.events:on("game.ready", function(p)
    boughtText.original = nil
    boughtText.swapped = false
  end)

  mod.events:on("shop.purchased", function(p)
    local game = p.game
    -- always restore first, so a non-award purchase shows vanilla text
    if not GEN2 then restoreBoughtText(game) end

    -- balls only.  ItemEffects.BALLS is the Gen 1 set; on Gold the
    -- merged item record's `ball` field answers the same question.
    local isBall
    if GEN2 then
      local data = p.data or (game and game.data)
      local def = data and data.items and data.items[p.id]
      isBall = def and def.ball ~= nil
    else
      isBall = ItemEffects.BALLS[p.id]
    end
    if not isBall then return end
    if p.id == "PREMIER_BALL" then return end             -- never self-count
    local award = math.floor((p.qty or 1) / 10)           -- 10+ in ONE buy
    if award < 1 then return end

    local save = p.save or (game and game.save)
    local data = p.data or (game and game.data)
    if not (save and data) then return end
    if not Bag.add(save, "PREMIER_BALL", award, data) then
      mod.log:warn("bag full -- PREMIER BALL award skipped")
      return
    end

    -- clerk line, GB text box: max 2 rows, max 18 chars per row
    if not GEN2 and game and game.data and game.data.text then
      if boughtText.original == nil then
        boughtText.original = game.data.text["_PokemartBoughtItemText"]
      end
      local line
      if award == 1 then
        line = "I'll throw in a\nPREMIER BALL, too!"
      else
        line = ("I'll throw in %d\nPREMIER BALLS too!"):format(award)
      end
      game.data.text["_PokemartBoughtItemText"] = line
      boughtText.swapped = true
    end
    mod.log:info("awarded %d free PREMIER BALL(s)", award)
  end)

  ----------------------------------------------------------------------
  -- NEST BALL -- reading battle state in attempt().
  -- attempt(ctx) supersedes the whole catch roll
  -- (src/battle/Catching.lua:94).  ctx carries: ballDef, targetMon,
  -- targetDef, rng, rateOverride, battle, vanillaAttempt().
  -- (Gen 1 path; the Gen 2 half of this ball is in the catch.rate wrap.)
  ----------------------------------------------------------------------
  registerBall("NEST_BALL", "NEST BALL", 1000, {
    attempt = function(ctx)
      local lv = ctx.targetMon.level or 100
      local mult = (lv <= 15 and 4) or (lv <= 25 and 3)
                or (lv <= 35 and 2) or 1
      if mult > 1 then boost(ctx, mult) end
      return ctx.vanillaAttempt()
    end,
  })

  ----------------------------------------------------------------------
  -- MOON BALL -- querying engine species data in attempt().  GEN 1
  -- ONLY: Gold has a native MOON_BALL (see the id note above).
  -- ctx.targetDef is the species record; its evolutions[] rows are
  -- { method = "LEVEL"|"ITEM"|"TRADE", item = ..., species = ... }
  -- (src/pokemon/Evolution.lua).  Reading the real data means this
  -- stays correct even if another mod edits who evolves by Moon Stone.
  ----------------------------------------------------------------------
  if not GEN2 then
    local function evolvesByMoonStone(def)
      for _, evo in ipairs((def and def.evolutions) or {}) do
        if evo.method == "ITEM" and evo.item == "MOON_STONE" then
          return true
        end
      end
      return false
    end

    registerBall("MOON_BALL", "MOON BALL", 1200, {
      attempt = function(ctx)
        if evolvesByMoonStone(ctx.targetDef) then boost(ctx, 4) end
        return ctx.vanillaAttempt()
      end,
    })
  end

  ----------------------------------------------------------------------
  -- HEAL BALL -- no attempt() at all; a different hook entirely.
  -- storeCaughtMon emits pokemon.caught with { battle, mon, species,
  -- isNew, ball, destination, game } (src/battle/BattleState.lua:4470),
  -- and Gold's catch tail emits the SAME name and payload
  -- (src/ui/gen2/BattleState.lua:2291), so one subscription covers both.
  -- mon is the live table, so healing it heals the caught Pokemon
  -- wherever it landed.
  --
  -- The heal itself is per-shape: Gen 1's Pokemon.heal is the engine's
  -- own full restore (HP, status, PP incl. PP Ups -- Pokemon.lua:90),
  -- but it reads the Gen 1 Data singleton for PP, which a Gold boot
  -- never fills.  A Gen 2 battle mon carries maxHp and per-move maxPp
  -- directly (src/battle/gen2/Mon.lua:234,415), so on Gold we restore
  -- from those fields instead.
  ----------------------------------------------------------------------
  registerBall("HEAL_BALL", "HEAL BALL", 300, {})

  local function healCaught(mon)
    if not GEN2 then return Pokemon.heal(mon) end
    local max = (mon.stats and mon.stats.hp) or mon.maxHp
    if max then
      mon.hp = max
      if mon.maxHp then mon.maxHp = max end
    end
    mon.status = nil
    for _, mv in ipairs(mon.moves or {}) do
      if mv.maxPp then mv.pp = mv.maxPp end
    end
  end

  mod.events:on("pokemon.caught", function(p)
    if p.ball == "HEAL_BALL" and p.mon then
      healCaught(p.mon)
      mod.log:info("HEAL BALL: %s caught fully healed", tostring(p.species))
    end
  end)

  ----------------------------------------------------------------------
  -- THE MARK -- which ball caught this Pokemon, recorded on the Pokemon.
  --
  -- The engine does NOT do this.  `caughtBall` appears nowhere in engine
  -- 0.1.75: storeCaughtMon puts the ball in the pokemon.caught payload
  -- (BattleState.lua:4500) and then drops it, so nothing anywhere
  -- remembers what you threw.  Without this listener the GS BALL is
  -- pointless -- its whole reward is the mark.
  --
  -- Writing an extra field onto the mon table is how snag_quest already
  -- persists mon.snagged / mon.snagFrom, and kanto_ribbons already reads
  -- those, so the mechanism is proven on this engine rather than assumed.
  --
  -- BUT WE ARE NOT THE OWNER.  pokeball_colors declares
  -- `exports.owns.caughtBallField = "mon.caughtBall"` and writes it from
  -- its own pokemon.caught listener -- it needs the field for the heal
  -- machine's per-ball colours.  Its ownership note says other mods may
  -- read it freely and must NOT write it.  0.3.1-0.3.4 here wrote it
  -- unconditionally, duplicating that write: harmless in practice, since
  -- both sides guard on nil and store the same value from the same
  -- payload, but a contract breach and a divergence waiting to happen.
  --
  -- So this is a FALLBACK only, for the setup pokeball_colors cannot
  -- cover: Kanto Balls installed without it.  Otherwise the GS BALL's
  -- mark -- and the kanto_ribbons ribbon that reads it -- would silently
  -- depend on an optional cosmetic mod being installed.
  --
  -- The test is "does pokeball_colors CLAIM the field", not "is it
  -- installed": versions before 0.1.12 have no writer, and a bare
  -- presence check would leave the mark missing on those setups.
  --
  -- Checked at catch time, not load time: mod.find cannot see a mod that
  -- has not loaded yet, and load order between two independent mods is
  -- not guaranteed either way.
  --
  -- On GOLD this fallback is the ONLY writer: pokeball_colors is a
  -- Gen 1 mod, so a Gold boot skips it, mod.find answers nil, and we
  -- write the mark ourselves.  Same code, no branch needed.
  --
  -- Recorded for EVERY ball, not just GS: it is one field either way, and
  -- a ribbon for "caught in a MOON BALL" then costs no new plumbing.
  -- Never overwritten -- a Pokemon is caught once, and a later trade or
  -- evolution must not relabel it.
  ----------------------------------------------------------------------
  local function markIsOwnedElsewhere()
    local pbc = mod.find("pokeball_colors")
    local owns = pbc and pbc.exports and pbc.exports.owns
    return owns ~= nil and owns.caughtBallField ~= nil
  end

  mod.events:on("pokemon.caught", function(p)
    if markIsOwnedElsewhere() then return end
    if p.mon and p.ball and p.mon.caughtBall == nil then
      p.mon.caughtBall = p.ball
    end
  end)

  ----------------------------------------------------------------------
  -- FAST BALL -- reading the target's BASE stats, not its live ones.
  -- GEN 1 ONLY: Gold has a native FAST_BALL, and the Gen 2 catch.rate
  -- opts carry no base stats anyway (probe-confirmed: FASTspd NONE).
  -- targetDef.baseStats is { hp, attack, defense, speed, special }, all
  -- 1-255 (src/mods/Schemas.lua:420).  Base speed >= 100 is exactly the
  -- "hard to keep up with" set in Gen 1 -- the birds, Electrode,
  -- Dugtrio, Alakazam, Persian, Tauros, Aerodactyl, Jolteon, Mew(two)
  -- and friends.  Reading the merged registry rather than a hardcoded
  -- species list means a mod that retunes base stats retunes this too.
  ----------------------------------------------------------------------
  local FAST_THRESHOLD = 100

  if not GEN2 then
    registerBall("FAST_BALL", "FAST BALL", 1000, {
      tossAnim = "GREATTOSS_ANIM",
      attempt = function(ctx)
        local base = ctx.targetDef and ctx.targetDef.baseStats
        if base and (base.speed or 0) >= FAST_THRESHOLD then
          boost(ctx, 4)
        end
        return ctx.vanillaAttempt()
      end,
    })
  end

  ----------------------------------------------------------------------
  -- MIRROR BALL -- reading YOUR side of the battle instead of theirs.
  -- ctx.battle is the running BattleState; battle.player is the battler
  -- table built by makeBattler (BattleState.lua:437), so
  -- battle.player.mon.species is whatever you have out right now.  4x
  -- when the wild Pokemon is the same species as your active one.
  --
  -- (Gen 1 has no genders, so this is as close as Kanto gets to a Love
  -- Ball.  It also means the ball rewards leading with the thing you
  -- are hunting -- send out your own Pidgey to catch a better Pidgey.)
  ----------------------------------------------------------------------
  registerBall("MIRROR_BALL", "MIRROR BALL", 1200, {
    attempt = function(ctx)
      local battle = ctx.battle
      local mine = battle and battle.player and battle.player.mon
                   and battle.player.mon.species
      local theirs = ctx.targetMon and ctx.targetMon.species
      if mine and theirs and mine == theirs then boost(ctx, 4) end
      return ctx.vanillaAttempt()
    end,
  })

  ----------------------------------------------------------------------
  -- GS BALL and BEAST BALL -- [DEV] CHEAP BALLS only.
  --
  -- Both are gated on the option because they are not earned content yet:
  -- with the flag off they are never registered, so they cannot appear in
  -- a bag, a mart or the item list at all.
  ----------------------------------------------------------------------
  -- BEAST BALL tuning, shared by both generations' catch paths:
  --
  -- "Legendary" is read from live species data rather than a hardcoded
  -- list, so a mod that adds legendaries is covered for free.  This was
  -- MEASURED on device (Gen 1, with Kanto Ascendant's Johto species
  -- loaded): catchRate <= 3 returned exactly ten species, all legendary,
  -- no false positives.
  --
  -- MEW is the one documented exception.  Gen 1 gives Mew catch rate
  -- 45, so it does NOT qualify on rate, and a pure rate test would have
  -- the Beast Ball actively HURT the most famous legendary in the game.
  -- CELEBI carries the same 45 on Gold for the same mythical reason
  -- (TODO/CONFIRM against a real Gold dex read; dev-gated ball, low
  -- stakes).  Named exceptions, not a species list.
  local LEGENDARY_RATE = 3
  local BEAST_EXCEPTIONS = { MEW = true, CELEBI = true }

  -- SET, do not multiply.  0.3.0/0.3.1 used 5x and it did almost
  -- nothing, which the stock formula explains exactly
  -- (Catching.lua stockAttempt): the first gate is
  --     rng(0, randMax) > rate  ->  outright fail
  -- With randMax 255, a legendary's catchRate of 3 multiplied by 5 is
  -- 15, so that gate passes 16 times in 256 -- about 6%.  Five times
  -- almost nothing is still almost nothing.  Measured on device
  -- against Entei and Mewtwo: many balls, no catch, mostly zero
  -- shakes, which is that gate failing.
  --
  -- 255 makes the first gate certain, leaving the HP term as the only
  -- barrier: a legendary at full HP still resists and a weakened one is
  -- near-certain -- the ball ignores the catch RATE, not the fight.
  -- Gold's formula has the same shape (rate * (3max-2hp) / 3max,
  -- src/battle/gen2/Catching.lua:301), so 255 means the same thing
  -- there: certain on rate, still gated by HP.
  local LEGENDARY_SET = 255
  local BEAST_PENALTY = 0.2

  if CHEAP then
    -- GS BALL -- deliberately the most boring ball in the mod: no
    -- attempt() at all, so it catches exactly like a Poke Ball.  The
    -- point is the MARK, not the mechanics.  mon.caughtBall persists, so
    -- kanto_ribbons can award a ribbon for a GS BALL catch.  That ribbon
    -- logic belongs in kanto_ribbons; this mod's whole job is to exist
    -- and be catchable with.  (And yes, taking the GS BALL to Gold is
    -- the joke finally landing.)
    registerBall("GS_BALL", "GS BALL", 200, {})

    -- boost() above only ever multiplies up, so it can leave the rate
    -- fractional when handed a value below 1.  A penalty needs its own
    -- helper: floor it, and never below 1, because a rate of 0 is not
    -- "very hard", it is a ball that can never work.
    local function scaleRate(ctx, mult)
      local rate = ctx.rateOverride or ctx.targetDef.catchRate or 45
      ctx.rateOverride = math.max(1, math.min(255, math.floor(rate * mult)))
    end

    registerBall("BEAST_BALL", "BEAST BALL", 1000, {
      tossAnim = "ULTRATOSS_ANIM",
      attempt = function(ctx)
        local def = ctx.targetDef
        local rate = def and def.catchRate or 255
        local species = ctx.targetMon and ctx.targetMon.species
        if rate <= LEGENDARY_RATE or BEAST_EXCEPTIONS[species] then
          ctx.rateOverride = LEGENDARY_SET
        else
          scaleRate(ctx, BEAST_PENALTY)
        end
        return ctx.vanillaAttempt()
      end,
    })
  end

  ----------------------------------------------------------------------
  -- SILPH PROTOTYPE -- an attempt() that replaces the roll outright.
  -- An abandoned first pass at the Master Ball: when it works it is a
  -- Master Ball, and one throw in two it simply does not work.
  --
  -- Returning without calling ctx.vanillaAttempt() is allowed and is
  -- what "supersedes the whole roll" means: catchAttempt's contract is
  -- `caught, shakes` (Catching.lua:88), guaranteed catch is `true, 3`,
  -- and `false, 0` is the zero-wobble miss ("You missed the POKeMON!").
  --
  -- The ball is spent either way, and that is engine behavior, not
  -- ours: BagMenu consume()s the item BEFORE calling battle:throwBall
  -- (src/ui/BagMenu.lua:162-164), and Gold's screen consumes at the
  -- same point (src/ui/gen2/BattleState.lua:2608).  A dud costs you
  -- the prototype.
  --
  -- NAMING: the id is SILPH_BALL everywhere and must never change (it
  -- is in save bags and mon.caughtBall).  On Gold the DISPLAY name is
  -- "PROTO BALL": Silph Co does not exist there (zero SILPH* strings
  -- in rom_manifest_gold.json), and the developer wants it reflavoured
  -- for Johto -- Kurt is the natural long-term hook.  TODO/CONFIRM the
  -- name with the developer; display-only, changeable any release.
  --
  -- TEMPORARY shelf, and marked so: on Gen 1 it is on the Saffron Mart
  -- shelf at a deliberately painful price so it can be tested at all
  -- (the plan is a Silph Co. employee handing you exactly one after
  -- the takeover); on Gold it rides the ULTRA-tier shelves the same
  -- provisional way.
  ----------------------------------------------------------------------
  -- 1 throw in 2 is a dud (was 1 in 4 through 0.2.x).
  local SILPH_FAILURE_IN = 2

  -- set by the attempt below, consumed by the message wrap right after
  local silphFizzled = false

  registerBall("SILPH_BALL", GEN2 and "PROTO BALL" or "SILPH BALL", 9800, {
    tossAnim = "ULTRATOSS_ANIM",
    flicker = true,
    attempt = function(ctx)
      silphFizzled = false
      if ctx.rng(1, SILPH_FAILURE_IN) == 1 then
        silphFizzled = true
        return false, 0        -- the prototype fizzles; ball is gone
      end
      return true, 3           -- otherwise it is a Master Ball
    end,
  })

  -- A failed throw's text comes from BattleState:ballMissMessage(shakes)
  -- (BattleState.lua:4378), not from anything the ball record can set --
  -- shakes == 0 is the stock "You missed the POKeMON!", which is wrong
  -- here: you didn't miss, the ball broke.  So wrap that one method.
  -- GEN 1 ONLY: Gold picks its failure line from the wobble counter
  -- inside the animation (GetPokeBallWobble re-rolls per wobble), so
  -- there is no message seam to wrap; a Gold dud reads as a break-out.
  --
  -- throwBall calls catchAttempt and then sayNext(ballMissMessage(...))
  -- with nothing in between that could throw another ball, so the flag
  -- set in attempt() above is still ours when we read it.  We check the
  -- flag AND shakes == 0 AND lastBall, so nothing else can trip it.
  --
  -- Stash-originals, not a sentinel: engine module tables survive a hot
  -- reload for the life of the process, so `if wrapped then return end`
  -- would leave the OLD wrapper live and make the new version look
  -- inert.  Rebuilding from the stash is always correct.
  --
  -- GB text box: 2 rows, 18 chars max per row.
  if not GEN2 then
    local SILPH_BREAK_TEXT = "The PROTOTYPE\nbroke apart!"

    local BattleState = require("src.battle.BattleState")
    BattleState._kbOriginals = BattleState._kbOriginals
      or { ballMissMessage = BattleState.ballMissMessage }
    local vanillaMissMessage = BattleState._kbOriginals.ballMissMessage

    BattleState.ballMissMessage = function(self, shakes)
      if silphFizzled and shakes == 0 and self.lastBall == "SILPH_BALL" then
        silphFizzled = false
        return SILPH_BREAK_TEXT
      end
      return vanillaMissMessage(self, shakes)
    end
  end

  ----------------------------------------------------------------------
  -- GEN 2 CATCH BEHAVIOR -- one catch.rate wrap for every ball.
  --
  -- Gold's Catching.attempt calls the hook with (ball, mon, def, o)
  -- where o is the SAME flat opts table vanilla then runs on
  -- (src/battle/gen2/Catching.lua:358-360): editing o.catchRate changes
  -- the roll, returning `caught, rate` replaces it.  Our ball ids are
  -- unknown to Gold's ball table, so recordFor answers nil and the rate
  -- math uses o.catchRate untouched -- exactly the seam we need.
  -- Probe-confirmed field inventory on device: catchRate, level,
  -- species, playerSpecies, evolveItem, weight, gender present; no
  -- base stats, no mon/def/battle.
  --
  -- Native balls (incl. Gold's own MOON and FAST) never match an arm
  -- here and pass straight through to vanilla.  On Gen 1 this wrap is
  -- NOT installed at all -- the ball records' attempt() already carries
  -- the behavior, and catch.rate wraps BattleState:catchAttempt there
  -- with different opts (rng/rateOverride), so one wrap serving both
  -- would double-boost Red.
  ----------------------------------------------------------------------
  if GEN2 then
    -- edit-in-place twin of boost(): Gold reads o.catchRate where
    -- Gen 1's attempt ctx reads rateOverride
    local function boostFlat(o, mult)
      local rate = o.catchRate or 45
      o.catchRate = math.max(1, math.min(255, math.floor(rate * mult)))
    end

    -- o.random is the battle's own rng, rand(random, n) -> 0..n-1
    -- (src/battle/gen2/Catching.lua:244); fall back to love.math the
    -- same way the engine's own rand() does.
    local function oneIn(o, n)
      if o.random then return o.random(n) == 0 end
      return love.math.random(n) == 1
    end

    mod.hooks:wrap("catch.rate", function(next_, ball, mon, def, o)
      if type(o) ~= "table" or not OWNED[ball] then
        return next_(ball, mon, def, o)
      end

      if ball == "NEST_BALL" then
        local lv = o.level or 100
        local mult = (lv <= 15 and 4) or (lv <= 25 and 3)
                  or (lv <= 35 and 2) or 1
        if mult > 1 then boostFlat(o, mult) end

      elseif ball == "MIRROR_BALL" then
        if o.species and o.playerSpecies
            and o.species == o.playerSpecies then
          boostFlat(o, 4)
        end

      elseif ball == "SILPH_BALL" then
        -- replace the roll outright: Master Ball or dud, ball spent
        -- either way.  rate is wFinalCatchRate, which the wobble
        -- animation runs on -- 255 plays the clean catch, 1 gives the
        -- dud a token rock before it breaks open.
        if oneIn(o, SILPH_FAILURE_IN) then return false, 1 end
        return true, 255

      elseif ball == "BEAST_BALL" then          -- only registered if CHEAP
        local rate = o.catchRate or 255
        if rate <= LEGENDARY_RATE or BEAST_EXCEPTIONS[o.species] then
          o.catchRate = LEGENDARY_SET
        else
          boostFlat(o, BEAST_PENALTY)
        end
      end
      -- PREMIER, HEAL, GS: no catch code by design -- plain odds.
      return next_(ball, mon, def, o)
    end)
  end

  ----------------------------------------------------------------------
  -- Mart shelves.
  --
  -- GEN 1: the first-party deep-registry mechanism, exactly as Custom
  -- Poke Balls by magalvao uses it.  __append extends the shelf.
  --
  -- One patch per clerk constant, with that clerk's WHOLE addition in a
  -- single __append: registry ops fold, so building the list first and
  -- appending once is safer than two patches racing on one field.
  --
  -- Constants are ROM-extracted, never guessable.  Every one below is
  -- verified present in BOTH tools/rom_manifest.json and
  -- rom_manifest_yellow.json -- Yellow renames objects on some maps, and
  -- a wrong constant fails SILENTLY (vanilla shelf, no error).
  ----------------------------------------------------------------------
  local SHELF = { "NEST_BALL", "HEAL_BALL", "MIRROR_BALL" }
  if not GEN2 then SHELF[#SHELF + 1] = "FAST_BALL" end

  -- [DEV] CHEAP BALLS puts the two dev balls on every ball shelf. With
  -- the flag off they were never registered above, so there is nothing to
  -- append and no shelf mentions them.
  if CHEAP then
    SHELF[#SHELF + 1] = "GS_BALL"
    SHELF[#SHELF + 1] = "BEAST_BALL"
  end

  if not GEN2 then
    local function shelfPlus(extra)
      local out = {}
      for _, id in ipairs(SHELF) do out[#out + 1] = id end
      for _, id in ipairs(extra or {}) do out[#out + 1] = id end
      return out
    end

    local BALL_MARTS = {
      { map = "CeladonMart2F", const = "TEXT_CELADONMART2F_CLERK1",
        stock = SHELF },
      { map = "LavenderMart", const = "TEXT_LAVENDERMART_CLERK",
        stock = SHELF },
      -- Saffron sits at the foot of Silph Co., so the prototype is sold
      -- here and nowhere else (see the SILPH BALL note above -- temporary)
      { map = "SaffronMart", const = "TEXT_SAFFRONMART_CLERK",
        stock = shelfPlus({ "SILPH_BALL" }) },
      { map = "FuchsiaMart", const = "TEXT_FUCHSIAMART_CLERK",
        stock = SHELF },
      { map = "CinnabarMart", const = "TEXT_CINNABARMART_CLERK",
        stock = SHELF },
      { map = "IndigoPlateauLobby", const = "TEXT_INDIGOPLATEAULOBBY_CLERK",
        stock = SHELF },
    }

    for _, row in ipairs(BALL_MARTS) do
      mod.content.text_pointers:patch(row.map, {
        [row.const] = { mart = { __append = row.stock } },
      })
    end

    -- MOON BALL is sold at PEWTER MART -- the last mart BEFORE Mt. Moon,
    -- so you can buy them on the way in rather than after.  Note this is
    -- one of the early POKE_BALL-only marts that Custom Poke Balls
    -- deliberately leaves alone; only this single ball is added there.
    mod.content.text_pointers:patch("PewterMart", {
      TEXT_PEWTERMART_CLERK = { mart = { __append = { "MOON_BALL" } } },
    })
  end

  ----------------------------------------------------------------------
  -- GEN 2 shelves + pockets, at game.ready (data is merged and
  -- gen2Marts populated by then -- Game2:load fills it at line 904 and
  -- emits game.ready at 1024).
  --
  -- gen2Marts has NO registry yet ("new API surface rather than a
  -- routing change" -- docs/mod-api-gen2-compat.md), so this is a
  -- direct, presence-checked append to the table MartMenu reads
  -- (marts.lists[martId+1], MartMenu.inventory).  Discipline for
  -- touching a table we do not own: append only, never remove or
  -- reorder, and skip anything already present -- so vanilla stock,
  -- another mod's additions and a second game.ready in one process are
  -- all safe.  Move this onto the registry the release it exists.
  --
  -- Shelf policy mirrors Gen 1's "Great/Ultra marts": we stock only
  -- lists that already carry GREAT_BALL or ULTRA_BALL (mid-game and
  -- later), and the prototype only where ULTRA_BALL is sold.  Chosen by
  -- CONTENT rather than by mart id because the numeric mart ids come
  -- from the ROM's mart_constants order, which is not in the manifest
  -- to verify -- matching on what a shelf sells cannot mis-target.
  ----------------------------------------------------------------------
  if GEN2 then
    mod.events:on("game.ready", function(p)
      local game = p.game
      local data = game and game.data
      if not data then return end

      -- pocket: the items schema has no such field, but Gold's bag and
      -- battle route on it (Bag.pocketOf, useItem's pocket == "BALL"),
      -- so stamp the MERGED record post-merge.  Without this the balls
      -- land in the ITEM pocket and cannot be thrown.
      for _, id in ipairs(BALL_IDS) do
        local def = data.items and data.items[id]
        if def and def.pocket == nil then def.pocket = "BALL" end
      end

      local marts = data.gen2Marts
      local lists = marts and (marts.lists or marts)
      if type(lists) ~= "table" then
        -- never fail silently: no mart table means no shelves, and the
        -- player would otherwise just see vanilla marts with no clue
        Runtime.reportError("kanto_balls", "GOLD: mart table missing")
        return
      end

      local stocked = false
      for _, list in ipairs(lists) do
        if type(list) == "table" then
          local has = {}
          for _, id in ipairs(list) do has[id] = true end
          if has.GREAT_BALL or has.ULTRA_BALL then
            for _, id in ipairs(SHELF) do
              if not has[id] then
                list[#list + 1] = id
                has[id] = true
              end
            end
            if has.ULTRA_BALL and not has.SILPH_BALL then
              list[#list + 1] = "SILPH_BALL"
            end
            stocked = true
          end
        end
      end
      if not stocked then
        Runtime.reportError("kanto_balls", "GOLD: no ball shelf found")
      end
    end)
  end

  ----------------------------------------------------------------------
  -- Colors -- registered via pokeball_colors' registerColors(colors)
  -- export (Pokeball Colors >= 0.1.13).  It owns the absent-check --
  -- "only when the key is absent, so a user override wins" -- so we
  -- can't get that part wrong by hand-writing it here, and it logs a
  -- warning for any ball that registers no color at all (previously a
  -- silent default-red at the Center with no clue why).
  --
  -- Must run by game.ready: that's the same point Pokeball Colors reads
  -- exports.colors from for the very first draw, well before a Center
  -- or battle is reachable.
  --
  -- On Gold this whole block is a quiet no-op: pokeball_colors is a
  -- Gen 1 mod, a Gold boot skips it, and mod.find answers nil.
  --
  -- Fallback: an older Pokeball Colors (pre-0.1.13) has exports.colors
  -- but no exports.registerColors.  Without the fallback, updating this
  -- mod would silently UN-color every ball for anyone who hasn't also
  -- updated Colors -- exactly the failure this helper exists to avoid.
  -- Drop the fallback once 0.1.13+ can be assumed.
  --
  -- SILPH BALL sets flicker = true, so its two colors swap during the
  -- throw (the Master/Ultra strobe) -- deliberate: it should look like
  -- a Master Ball with something wrong with it.
  ----------------------------------------------------------------------
  local COLORS = {
    PREMIER_BALL = { body = { 240, 240, 240 }, accent = { 200,  48,  48 } },
    -- bright spring green, NOT the olive it used to be: at 132,172,84 it
    -- sat 5.9 dE from the native SAFARI BALL, which every player has
    NEST_BALL    = { body = {  80, 200, 128 }, accent = { 228, 204, 100 } },
    HEAL_BALL    = { body = { 232, 160, 196 }, accent = { 248, 238, 244 } },
    MIRROR_BALL  = { body = { 168, 180, 200 }, accent = { 244, 250, 255 } },
    SILPH_BALL   = { body = { 120,  88, 168 }, accent = {  96, 216, 200 } },
  }
  if not GEN2 then
    COLORS.MOON_BALL = { body = {  60,  68, 128 }, accent = { 232, 208,  96 } }
    COLORS.FAST_BALL = { body = { 232, 148,  48 }, accent = { 248, 232, 152 } }
  end

  -- Only for balls that actually got registered: Pokeball Colors 0.1.13+
  -- warns about a registered ball carrying no colour, and registering a
  -- colour for a ball that does not exist is the mirror of that mistake.
  if CHEAP then
    -- GS: the gold-and-silver ball, so gold body against a silver band.
    -- pale gold against silver.  The old 224,188,76 was 2.2 dE from
    -- Custom Poke Balls' LEVEL BALL and 14.6 from the native ULTRA --
    -- lifting the value clears both, and reads more "gold AND silver".
    COLORS.GS_BALL = { body = { 248, 224, 160 }, accent = { 216, 220, 228 } }
    -- BEAST: Ultra Beast livery -- deep blue with the yellow flash.
    -- near-black navy under the yellow flash.  At 44,72,148 it was 10.2
    -- dE from our own MOON BALL and crowded GREAT and SILPH too; dropping
    -- the value clears all three at once, because value contrast is what
    -- survives at this sprite size.
    COLORS.BEAST_BALL = { body = {  16,  24,  56 }, accent = { 244, 216,  72 } }
  end

  mod.events:on("game.ready", function()
    local pbc = mod.find("pokeball_colors")
    if not (pbc and pbc.exports) then return end
    if pbc.exports.registerColors then
      pbc.exports.registerColors(COLORS)
      return
    end
    -- fallback for Pokeball Colors < 0.1.13 (no helper yet)
    if not pbc.exports.colors then return end
    for id, c in pairs(COLORS) do
      if not pbc.exports.colors[id] then
        pbc.exports.colors[id] = c
      end
    end
  end)

  ----------------------------------------------------------------------
  -- Superseded-mod notice.  example_balls was renamed to kanto_balls at
  -- 0.2.0, and a rename is not something the engine can redirect: the id
  -- IS the identity.  LauncherMods.installFromRelease passes
  -- expectId = modId and installZip refuses a zip whose manifest id
  -- differs (LauncherMods.lua:689), so an example_balls listing can never
  -- serve a kanto_balls download.
  --
  -- Worse, nothing stops both being installed: different ids install to
  -- different folders ("mods/" .. manifest.id), so a player who never
  -- removed the old one is silently running two mods that register
  -- overlapping balls.  The manifest now declares example_balls in
  -- `conflicts`, which the launcher surfaces in the install confirmation
  -- -- but that only helps someone installing today.  This catches the
  -- ones who already have both, and reportError is the only channel that
  -- exists on iOS.
  ----------------------------------------------------------------------
  if mod.find("example_balls") then
    Runtime.reportError("kanto_balls",
      "OLD EXAMPLE BALLS INSTALLED - REMOVE IT")
  end

  mod.log:info("kanto_balls %s loaded (gen %d)", VERSION, GEN2 and 2 or 1)
end
