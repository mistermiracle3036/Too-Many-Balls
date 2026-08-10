-- Kanto Balls
--
-- Seven balls for gen1recomp.  This mod is also meant to be READABLE:
-- each ball is one self-contained pattern with the engine file/line it
-- was verified against (engine 0.1.75), so it can be copied into your
-- own mod and changed.
--
--   PREMIER  no catch code at all + listening to another mod's event
--   NEST     an attempt() that multiplies the catch rate from battle
--            state (the target's level)
--   MOON     an attempt() that queries engine species data (evolutions)
--   HEAL     no attempt() -- reacts to the pokemon.caught event instead
--   FAST     an attempt() reading the target's BASE stats
--   MIRROR   an attempt() reading YOUR side of the battle, not theirs
--   SILPH    an attempt() that replaces the roll outright, and can fail
--
-- A ball needs three registrations to exist (see registerBall below):
--   1. mod.content.balls:register(id, record)   -- the catch behavior
--   2. mod.content.items:register(id, record)   -- the bag/mart item
--   3. ItemEffects.BALLS[id] = true             -- bag "toss" targeting
-- and, to be obtainable, either a mart shelf patch or some award logic.
--
-- (Renamed from `example_balls` at 0.2.0.  Same repo, same lockstep
-- versioning with shop_events.)

return function(mod)
  local VERSION = "0.2.3"
  mod.exports.version = VERSION

  local ItemEffects = require("src.inventory.ItemEffects")
  local Bag = require("src.inventory.Bag")
  local Pokemon = require("src.pokemon.Pokemon")

  -- Ownership, declared so other mods (notably pokeball_colors) can
  -- check at runtime instead of via a handoff note.  This mod owns
  -- these ball records WHOLE -- record fields AND their colors.  No
  -- other mod should register a color for these ids; we publish ours
  -- into pokeball_colors ourselves at the bottom of this file.
  local BALL_IDS = {
    "PREMIER_BALL", "NEST_BALL", "MOON_BALL", "HEAL_BALL",
    "FAST_BALL", "MIRROR_BALL", "SILPH_BALL",
  }
  local OWNED = {}
  for _, id in ipairs(BALL_IDS) do OWNED[id] = true end
  mod.exports.owns = { kanto_balls = true, balls = OWNED }
  mod.exports.balls = BALL_IDS

  ----------------------------------------------------------------------
  -- shared helper: the three registrations every ball needs
  ----------------------------------------------------------------------
  local function registerBall(id, name, price, ballRecord)
    -- poke-ball-tier stock numbers; attempt (if any) supersedes them
    ballRecord.randMax = ballRecord.randMax or 255
    ballRecord.hpFactor = ballRecord.hpFactor or 12
    ballRecord.wobbleFactor = ballRecord.wobbleFactor or 255
    ballRecord.tossAnim = ballRecord.tossAnim or "TOSS_ANIM"
    mod.content.balls:register(id, ballRecord)
    -- items schema accepts ONLY: id, name, index, price, machine,
    -- effect, ball, tossable, needsTarget (strict validation)
    mod.content.items:register(id, {
      id = id, name = name, price = price,
      tossable = true, ball = id,
    })
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
  -- The announcement trick: the shop footer is a bare table read --
  -- game.data.text["_PokemartBoughtItemText"] (ShopMenu.lua:21) --
  -- executed immediately AFTER the Purchase sound in the same callback.
  -- Our shop.purchased listener runs DURING that sound (shop_events
  -- emits from its Sound.play wrap), i.e. just before the read.  So:
  -- swap the stored string for the award line, and restore it at the
  -- top of the next purchase.  Non-destructive; the original is stashed
  -- once per loaded game.
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
    restoreBoughtText(game)

    if not ItemEffects.BALLS[p.id] then return end        -- balls only
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
    if game and game.data and game.data.text then
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
  -- MOON BALL -- querying engine species data in attempt().
  -- ctx.targetDef is the species record; its evolutions[] rows are
  -- { method = "LEVEL"|"ITEM"|"TRADE", item = ..., species = ... }
  -- (src/pokemon/Evolution.lua).  Reading the real data means this
  -- stays correct even if another mod edits who evolves by Moon Stone.
  ----------------------------------------------------------------------
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

  ----------------------------------------------------------------------
  -- HEAL BALL -- no attempt() at all; a different hook entirely.
  -- storeCaughtMon emits pokemon.caught with { battle, mon, species,
  -- isNew, ball, destination, game } (src/battle/BattleState.lua:4470).
  -- mon is the live table, so healing it heals the caught Pokemon
  -- wherever it landed.  Pokemon.heal is the engine's own full-restore
  -- (HP, status, every move's PP incl. PP Ups -- Pokemon.lua:90).
  ----------------------------------------------------------------------
  registerBall("HEAL_BALL", "HEAL BALL", 300, {})

  mod.events:on("pokemon.caught", function(p)
    if p.ball == "HEAL_BALL" and p.mon then
      Pokemon.heal(p.mon)
      mod.log:info("HEAL BALL: %s caught fully healed", tostring(p.species))
    end
  end)

  ----------------------------------------------------------------------
  -- FAST BALL -- reading the target's BASE stats, not its live ones.
  -- targetDef.baseStats is { hp, attack, defense, speed, special }, all
  -- 1-255 (src/mods/Schemas.lua:420).  Base speed >= 100 is exactly the
  -- "hard to keep up with" set in Gen 1 -- the birds, Electrode,
  -- Dugtrio, Alakazam, Persian, Tauros, Aerodactyl, Jolteon, Mew(two)
  -- and friends.  Reading the merged registry rather than a hardcoded
  -- species list means a mod that retunes base stats retunes this too.
  ----------------------------------------------------------------------
  local FAST_THRESHOLD = 100

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
  -- SILPH PROTOTYPE -- an attempt() that replaces the roll outright.
  -- Silph Co's abandoned first pass at the Master Ball: when it works it
  -- is a Master Ball, and one throw in four it simply does not work.
  --
  -- Returning without calling ctx.vanillaAttempt() is allowed and is
  -- what "supersedes the whole roll" means: catchAttempt's contract is
  -- `caught, shakes` (Catching.lua:88), guaranteed catch is `true, 3`,
  -- and `false, 0` is the zero-wobble miss ("You missed the POKeMON!").
  --
  -- The ball is spent either way, and that is engine behavior, not
  -- ours: BagMenu consume()s the item BEFORE calling battle:throwBall
  -- (src/ui/BagMenu.lua:162-164).  A dud costs you the prototype.
  --
  -- TEMPORARY, and marked so: it is on the Saffron Mart shelf at a
  -- deliberately painful price so it can be tested at all.  The plan is
  -- a Silph Co. employee handing you exactly one after the takeover --
  -- when that giver exists, this shelf entry comes off.
  ----------------------------------------------------------------------
  local SILPH_FAILURE_IN = 4   -- 1 throw in 4 is a dud

  -- set by the attempt below, consumed by the message wrap right after
  local silphFizzled = false

  registerBall("SILPH_BALL", "SILPH BALL", 9800, {
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

  ----------------------------------------------------------------------
  -- Mart shelves -- the first-party deep-registry mechanism, exactly as
  -- Custom Poke Balls by magalvao uses it.  __append extends the shelf.
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
  local SHELF = { "NEST_BALL", "HEAL_BALL", "FAST_BALL", "MIRROR_BALL" }

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
    NEST_BALL    = { body = { 132, 172,  84 }, accent = { 228, 204, 100 } },
    MOON_BALL    = { body = {  60,  68, 128 }, accent = { 232, 208,  96 } },
    HEAL_BALL    = { body = { 232, 160, 196 }, accent = { 248, 238, 244 } },
    FAST_BALL    = { body = { 232, 148,  48 }, accent = { 248, 232, 152 } },
    MIRROR_BALL  = { body = { 168, 180, 200 }, accent = { 244, 250, 255 } },
    SILPH_BALL   = { body = { 120,  88, 168 }, accent = {  96, 216, 200 } },
  }

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

  mod.log:info("kanto_balls %s loaded", VERSION)
end
