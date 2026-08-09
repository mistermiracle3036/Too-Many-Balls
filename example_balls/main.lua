-- Example Balls -- a template mod
--
-- Four balls, four different mod-API patterns, each small enough to
-- copy into your own mod and change.  Everything here is verified
-- against engine 0.1.75 source; file/line references are to it.
--
--   PREMIER  no catch code at all + listening to another mod's event
--   NEST     an attempt() that multiplies the catch rate from battle
--            state (the target's level)
--   MOON     an attempt() that queries engine species data (evolutions)
--   HEAL     no attempt() -- reacts to the pokemon.caught event instead
--
-- A ball needs three registrations to exist (see registerBall below):
--   1. mod.content.balls:register(id, record)   -- the catch behavior
--   2. mod.content.items:register(id, record)   -- the bag/mart item
--   3. ItemEffects.BALLS[id] = true             -- bag "toss" targeting
-- and, to be obtainable, either a mart shelf patch or some award logic.

return function(mod)
  local VERSION = "0.1.5"
  mod.exports.version = VERSION
  mod.exports.owns = { example_balls = true }

  local ItemEffects = require("src.inventory.ItemEffects")
  local Bag = require("src.inventory.Bag")
  local Pokemon = require("src.pokemon.Pokemon")

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
  -- targetDef, rng, rateOverride, battle, vanillaAttempt().  The stock
  -- formula uses `rateOverride or targetDef.catchRate` (Catching.lua:44),
  -- so a multiplier is: rewrite ctx.rateOverride, then delegate.
  ----------------------------------------------------------------------
  registerBall("NEST_BALL", "NEST BALL", 1000, {
    attempt = function(ctx)
      local lv = ctx.targetMon.level or 100
      local mult = (lv <= 15 and 4) or (lv <= 25 and 3)
                or (lv <= 35 and 2) or 1
      if mult > 1 then
        local rate = ctx.rateOverride or ctx.targetDef.catchRate or 45
        ctx.rateOverride = math.min(255, rate * mult)
      end
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
      if evolvesByMoonStone(ctx.targetDef) then
        local rate = ctx.rateOverride or ctx.targetDef.catchRate or 45
        ctx.rateOverride = math.min(255, rate * 4)
      end
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
  -- Mart shelves -- the first-party deep-registry mechanism, exactly as
  -- Custom Poke Balls by magalvao uses it.  __append extends the shelf.
  -- NEST + HEAL join the Great/Ultra marts; MOON is sold only at
  -- Cerulean, the first mart past Mt. Moon (TEXT_CERULEANMART_CLERK is
  -- the same constant in Red/Blue and Yellow -- verified in both ROM
  -- manifests).  PREMIER is deliberately on no shelf.
  ----------------------------------------------------------------------
  local SHELF = { "NEST_BALL", "HEAL_BALL" }
  local BALL_MARTS = {
    CeladonMart2F = { "TEXT_CELADONMART2F_CLERK1" },
    LavenderMart = { "TEXT_LAVENDERMART_CLERK" },
    SaffronMart = { "TEXT_SAFFRONMART_CLERK" },
    FuchsiaMart = { "TEXT_FUCHSIAMART_CLERK" },
    CinnabarMart = { "TEXT_CINNABARMART_CLERK" },
    IndigoPlateauLobby = { "TEXT_INDIGOPLATEAULOBBY_CLERK" },
  }
  for mapId, consts in pairs(BALL_MARTS) do
    for _, const in ipairs(consts) do
      mod.content.text_pointers:patch(mapId, {
        [const] = { mart = { __append = SHELF } },
      })
    end
  end
  -- MOON BALL is sold at PEWTER MART -- the last mart BEFORE Mt. Moon,
  -- so you can buy them on the way in rather than after.  Note this is
  -- one of the early POKE_BALL-only marts that Custom Poke Balls
  -- deliberately leaves alone; only this single ball is added there.
  -- TEXT_PEWTERMART_CLERK is the same constant in Red/Blue and Yellow
  -- (verified in both tools/rom_manifest*.json).
  mod.content.text_pointers:patch("PewterMart", {
    TEXT_PEWTERMART_CLERK = { mart = { __append = { "MOON_BALL" } } },
  })

  ----------------------------------------------------------------------
  -- Colors -- the documented Pokeball Colors integration: register on
  -- game.ready, only when the key is absent, so a user override wins.
  -- { body = the ball's main color, accent = the smaller highlight }.
  ----------------------------------------------------------------------
  local COLORS = {
    PREMIER_BALL = { body = { 240, 240, 240 }, accent = { 200,  48,  48 } },
    NEST_BALL    = { body = { 132, 172,  84 }, accent = { 228, 204, 100 } },
    MOON_BALL    = { body = {  60,  68, 128 }, accent = { 232, 208,  96 } },
    HEAL_BALL    = { body = { 232, 160, 196 }, accent = { 248, 238, 244 } },
  }
  mod.events:on("game.ready", function()
    local pbc = mod.find("pokeball_colors")
    if not (pbc and pbc.exports and pbc.exports.colors) then return end
    for id, c in pairs(COLORS) do
      if not pbc.exports.colors[id] then
        pbc.exports.colors[id] = c
      end
    end
  end)

  mod.log:info("example_balls %s loaded", VERSION)
end
