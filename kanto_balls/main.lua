-- Too Many Balls  (mod id: kanto_balls -- the display name changed at
-- 0.4.3 when the balls reached Johto; the ID never changes, it is in
-- players' save bags, in mon.caughtBall and in the zip name)
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
-- Two more are registered but never sold without the [DEV] CHEAP BALLS
-- option, which also drops every price to 1.  They are not earned
-- content yet -- but they DO exist on every boot, so one obtained under
-- the flag keeps its pocket, its name and its behaviour after the flag
-- goes off (0.4.9; before that, gating the registration orphaned them
-- into the ITEMS pocket):
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
--   * The throw site (src/ui/gen2/BattleState.lua:2684 on engine
--     0.1.79; :2578 on 0.1.78) hands Catching.attempt a FLAT opts table
--     with no `data` key -- re-verified on both -- so a
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
  local VERSION = "0.4.28"
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
    -- The faithfulness escape hatch for the bag headroom below.  It
    -- defaults to the GENEROUS direction on purpose: mod options do not
    -- persist on a Gold boot (engine bug -- the manager writes Gold's
    -- nested options block, the loader reads the top-level one), so a
    -- Gold-only player cannot change this, and the one state nobody
    -- should be stuck in is the one where the mod's own balls will not
    -- fit in the bag.
    { key = "vanilla_bag_limits", type = "toggle",
      label = "VANILLA BAG LIMITS", default = false },
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
    -- The first CRAFTED ball (briefs/BALL_CRAFT_TIER.md).  Registered on
    -- both generations so it exists everywhere, but only obtainable on
    -- Gold, where apricorns do: Gen 1 has no apricorn items at all.  The
    -- Gen 1 acquisition route is an open design question, so for now it
    -- sits in the same "exists, not obtainable" state as GS and BEAST --
    -- and for the same reason, it is registered rather than gated, or a
    -- traded/imported one would fall to the ITEMS pocket (see 0.4.9).
    "SNARE_BALL", "CATALYST_BALL", "DRIFT_BALL", "KECLEON_BALL",
    "CRADLE_BALL", "ACE_BALL",
  }
  if not GEN2 then
    BALL_IDS[#BALL_IDS + 1] = "MOON_BALL"
    BALL_IDS[#BALL_IDS + 1] = "FAST_BALL"
  end
  -- GS and BEAST are ALWAYS registered, and only their SHELVES are gated
  -- on the dev flag.  Through 0.4.8 the registration itself was gated,
  -- which had a bug the developer hit on device: a player who obtained
  -- one under [DEV] CHEAP BALLS and then turned the flag off still had
  -- the item in the save, but with no record registered `Bag.pocketOf`
  -- found no `pocket` and fell back to "ITEM" -- so the ball moved to
  -- the ITEMS pocket, under its raw id, and could not be thrown at all.
  --
  -- Existing and obtainable are different things.  A registration costs
  -- nothing visible on its own: no mart sells these without the flag,
  -- and nothing in the game enumerates the item catalogue at a player.
  -- So they exist, keep their pocket and their name, and stay
  -- unobtainable.
  BALL_IDS[#BALL_IDS + 1] = "GS_BALL"
  BALL_IDS[#BALL_IDS + 1] = "BEAST_BALL"
  -- Declared HERE, not down beside the Ball Case block that uses it most:
  -- the game.ready pocket stamp below runs earlier in the file, and a
  -- `local` declared after its use compiles that use as a GLOBAL -- nil at
  -- runtime, silently.  That is exactly what shipped in 0.4.11: the stamp
  -- read data.items[nil], found nothing, and the case sat in the ITEMS
  -- pocket.  Indexing a table with a nil KEY is legal in Lua, so there was
  -- no error to see -- which is the whole reason this trap keeps costing
  -- rounds.
  local CASE_ID = "BALL_CASE"

  -- Work that must wait for a quiet frame, drained by the single
  -- Game2.update wrap below.  Declared up here because TWO blocks feed
  -- it -- the Ball Case push and Kurt's coda -- and a `local` declared
  -- after its first use compiles that use as a nil global, silently
  -- (0.4.11 shipped exactly that bug).
  --
  -- One wrap, one queue: wrapping Game2.update twice would make load
  -- order decide which drain ran first.
  local pendingCoda = nil

  local OWNED = {}
  for _, id in ipairs(BALL_IDS) do OWNED[id] = true end
  mod.exports.owns = { kanto_balls = true, balls = OWNED }
  mod.exports.balls = BALL_IDS

  ----------------------------------------------------------------------
  -- BAG HEADROOM -- room for the balls we brought, and no more.
  --
  -- THE PROBLEM.  Gold's BALL pocket holds TWELVE distinct item ids
  -- (src/inventory/Bag.lua:15-20; a distinct id takes a slot whatever
  -- the quantity), and Gold's own in-bag balls already number eleven --
  -- POKE/GREAT/ULTRA/MASTER plus Kurt's seven.  Add ours and sixteen ids
  -- compete for twelve slots.  Gen 1 has no pockets at all: one flat bag
  -- of twenty, shared with every potion and TM, so eleven balls is a
  -- third of it.
  --
  -- WHAT THE CAP ACTUALLY DOES, checked rather than feared:
  -- Bag.capacity's only caller is Bag.add (:107) and the check fires
  -- only for an id NOT already held.  So a full pocket refuses a NEW
  -- ball, existing stacks still grow to 99, nothing is lost, and no UI
  -- reads capacity -- there is no "12/12" to break.  An over-cap pocket
  -- is a stable state, which is what makes this safe to change AND safe
  -- to change back: uninstall this mod holding sixteen ball ids and you
  -- simply cannot gain a seventeenth until you drop under the cap.
  --
  -- WHY +N RATHER THAN A BIG NUMBER.  We ask for exactly one slot per
  -- ball this mod registered.  A player without us is unaffected; the
  -- vanilla economy survives (choosing which of Kurt's seven to carry is
  -- a real Gold decision, and a blanket +18 would erase it); and it
  -- scales itself as the roster grows, which is the whole point.  Under
  -- [DEV] CHEAP BALLS the two dev balls are counted for free, because N
  -- is read off what was actually registered.
  --
  -- ONE WRAP SERVES BOTH GENERATIONS: src/inventory/Bag.lua is shared,
  -- and it is ADDITIVE rather than a replacement, so it can never shrink
  -- a bag another mod grew through the supported `constants.bagSize`
  -- route.  (That route exists and works on Gen 1 -- but it is a scalar
  -- registry write, so two mods setting it means last-writer-wins and we
  -- could silently shrink someone else's bag.  Adding to whatever the
  -- engine answers avoids that entirely.)
  --
  -- Which pocket gets the headroom differs: on Gold our balls live in
  -- BALL, on Gen 1 everything lives in the one ITEM bag.
  --
  -- TEMPORARY, in the same sense as the gen2Marts append: if the engine
  -- grows a per-pocket override (a `ballPocketSize` beside `bagSize`, or
  -- per-pocket keys under `constants`), this wrap should be deleted in
  -- favour of it.  Bag.capacity honours `bagSize` for the ITEM pocket
  -- only today (:43-45), which is why Gold has no supported route.
  ----------------------------------------------------------------------
  local ballSlots = #BALL_IDS

  do
    local Bag_ = Bag
    Bag_._kbOriginals = Bag_._kbOriginals or { capacity = Bag_.capacity }
    local vanillaCapacity = Bag_._kbOriginals.capacity

    if mod.options:get("vanilla_bag_limits") == true then
      -- Restore rather than skip: module tables live for the whole
      -- process, so a reload with the option newly ON would otherwise
      -- leave the OLD wrapper installed and look like it did nothing.
      Bag_.capacity = vanillaCapacity
    else
      Bag_.capacity = function(data, pocket)
        local base = vanillaCapacity(data, pocket)
        if type(base) ~= "number" then return base end
        local ours
        if GEN2 then
          ours = pocket == "BALL"
        else
          -- Gen 1 passes nil or "ITEM" for its single bag
          ours = pocket == nil or pocket == "ITEM"
        end
        if not ours then return base end
        return base + ballSlots
      end
    end
  end

  -- Other ball mods claim their own headroom here instead of installing
  -- a SECOND wrap on Bag.capacity -- same reason as registerBallPalette:
  -- two wrappers on one function means load order decides the answer,
  -- silently.  Read live, so a call at game.ready takes effect at once.
  mod.exports.requestBallSlots = function(n)
    if type(n) ~= "number" or n < 1 then return false end
    ballSlots = ballSlots + math.floor(n)
    return true
  end
  mod.exports.owns.ballPocketCapacity = true
  -- On Gold this mod also owns the ball -> palette wrap for EVERY ball,
  -- not just its own: exactly one mod may wrap BattleState:ballPalette
  -- or load order silently decides the colour.  Other ball mods call
  -- exports.registerBallPalette (defined near the colour block below)
  -- instead of installing their own.  Absent on Gen 1, where
  -- pokeball_colors owns colour.
  if GEN2 then mod.exports.owns.ballPalettesGen2 = true end

  ----------------------------------------------------------------------
  -- ITEM DESCRIPTIONS.
  --
  -- Gold shows these in three places -- the mart's buy list
  -- (src/ui/gen2/MartMenu.lua:873), the PACK
  -- (src/ui/gen2/PackMenu.lua:746) and the item PC
  -- (src/ui/gen2/ItemPcMenu.lua:531) -- and all three read a plain
  -- `description` field off the merged item record.  Ours had none, so
  -- a shelf full of our balls showed an empty box, which reads as
  -- broken rather than as terse.
  --
  -- `description` is NOT in the items schema (id, name, index, price,
  -- machine, effect, ball, tossable, needsTarget).  It rides as an
  -- extensible field: Schemas.check only rejects an unknown TOP-LEVEL
  -- key when it is a near-miss typo of a known one, and "description"
  -- is close to nothing in that list.
  --
  -- SHAPE: the drawer splits on `<NEXT>` or `\n` and prints two rows at
  -- column 1 of a 20-wide box, so it is TWO LINES of at most ~18
  -- characters.  A longer line is simply cut off, silently.
  --
  -- Gen 1 has no item-description UI at all (nothing under src/ui
  -- outside gen2/ reads the field), so these are a Gold nicety and
  -- harmless there.
  ----------------------------------------------------------------------
  local BALL_DESC = {
    PREMIER_BALL = "A gift ball.\nPlain catch odds.",
    NEST_BALL    = "Good on young,\nlow-level POKeMON.",
    HEAL_BALL    = "The catch arrives\nfully healed.",
    MIRROR_BALL  = "Best when it meets\nyour own species.",
    SILPH_BALL   = "A prototype ball.\nIt often breaks.",
    MOON_BALL    = "Good on those that\ntake a MOON STONE.",
    FAST_BALL    = "Good on very fast\nPOKeMON.",
    GS_BALL      = "A curious ball.\nIt marks its catch.",
    BEAST_BALL   = "Made for legends.\nPoor on all else.",
    SNARE_BALL   = "Holds a sleeping\nor frozen POKeMON.",
    CATALYST_BALL = "Good on those that\nevolve by stone.",
    DRIFT_BALL   = "Good on light and\nairy POKeMON.",
    -- Was "Turns the colour of\nits target." -- that first line is 19
    -- columns, one over, and it promised only the trick.  Now it leads
    -- with the odds, because that is what a player choosing a ball off
    -- this list needs to know first.
    KECLEON_BALL = "A good ball that\nmimics its target.",
    CRADLE_BALL  = "The catch begins\nagain at level 1.",
    ACE_BALL     = "Best on a target\nstill at full HP.",
  }

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
    --
    -- `ball` is a REFERENCE into the balls registry (f.id("balls")), so
    -- it is Gen 1 only: on Gold nothing reads a mod's ball record at the
    -- throw site, we register none, and carrying the field anyway made
    -- the loader report "items.NEST BALL.ball: unresolved reference to
    -- balls" for every ball on the [ERRS] screen -- seven lines of noise
    -- that would bury a real error (reported from device, 0.4.2).
    -- Nothing on Gold needs it: the bag and the battle both route on
    -- `pocket`, which the game.ready block below stamps.
    local record = { id = id, name = name, price = price, tossable = true,
                     description = BALL_DESC[id] }
    if not GEN2 then record.ball = id end
    mod.content.items:register(id, record)
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
  -- Gold announces it too, since 0.4.4 -- by a different route, because
  -- Gold's mart text is the ROM walker's rather than a data.text slot
  -- we can swap.  See the MartMenu wrap below the listener.
  ----------------------------------------------------------------------
  registerBall("PREMIER_BALL", "PREMIER BALL", 200, {})

  local boughtText = { original = nil, swapped = false }
  -- How many Premier Balls the listener below just awarded, read by the
  -- Gold clerk-line wrap further down.  Declared HERE, before the
  -- listener that assigns it: a `local` declared after its first use
  -- compiles that use as a GLOBAL, which is nil at runtime and silent.
  local premierAward = 0

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

    -- balls only.  ItemEffects.BALLS is the Gen 1 set.
    --
    -- On Gold the test is the item's POCKET, not its `ball` field.  0.4.0
    -- used `def.ball ~= nil` and that only ever matched OUR balls: `ball`
    -- is a Gen 1 schema field this mod sets on its own items, while
    -- Gold's own records come from the ROM extractor, which writes
    -- `pocket` (RomExtractorGen2.lua:3694) and no `ball` at all.  So
    -- buying ten POKE BALLs awarded nothing while buying ten of ours
    -- worked -- reported from device, 0.4.2.  `pocket` is the field Gold
    -- itself routes on (Bag.pocketOf, and useItem's pocket == "BALL"),
    -- so it is the right question on that generation.
    local isBall
    if GEN2 then
      local data = p.data or (game and game.data)
      local def = data and data.items and data.items[p.id]
      isBall = def ~= nil and (def.pocket == "BALL" or def.ball ~= nil)
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
    premierAward = award

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
  -- The clerk's line on GOLD.
  --
  -- 0.4.0-0.4.3 paid the bonus silently here and this comment claimed
  -- Gold had no seam for the announcement.  That was wrong: Gold's mart
  -- ends a successful purchase with `self:say(self.text.thanks)`
  -- (src/ui/gen2/MartMenu.lua:704), and `say` takes a LIST OF PAGES it
  -- then holds on self.message, advancing a page per button press
  -- (:469-482).  So the clerk can be given a second page.
  --
  -- The order inside completePurchase is what makes this safe:
  -- playTransaction (:701) rings the till, shop_events emits
  -- shop.purchased from its Sound.play wrap, our listener above awards
  -- and sets premierAward -- and only THEN does say() run (:704).  So by
  -- the time we look, the message exists and the award is known.
  --
  -- A page is a list of up to two lines (`page(...)` at :150) and the
  -- box is 20 tiles wide from column 1, so the same 18-character budget
  -- as the Gen 1 line.
  --
  -- COPY the page list, never append in place: extractedText falls
  -- through to the module-level TEXTS table when the cache has no
  -- extracted string (:316), so mutating it would add our line to every
  -- mart's thanks text for the rest of the process.
  ----------------------------------------------------------------------
  if GEN2 then
    local MartMenu = require("src.ui.gen2.MartMenu")
    MartMenu._kbOriginals = MartMenu._kbOriginals
      or { completePurchase = MartMenu.completePurchase }
    local vanillaComplete = MartMenu._kbOriginals.completePurchase

    MartMenu.completePurchase = function(self, total)
      premierAward = 0
      vanillaComplete(self, total)
      -- vanilla returns early on "not enough money" and "pack full"
      -- without ever ringing the till, so premierAward stays 0 there.
      if premierAward < 1 then return end
      local message = self.message
      if not (message and message.pages) then return end
      local line
      if premierAward == 1 then
        line = { "I'll throw in a", "PREMIER BALL, too!" }
      else
        line = { ("I'll throw in %d"):format(premierAward),
                 "PREMIER BALLS too!" }
      end
      local pages = {}
      for _, p in ipairs(message.pages) do pages[#pages + 1] = p end
      pages[#pages + 1] = line
      message.pages = pages
      premierAward = 0
    end
  end

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
  -- THE SAME ARRANGEMENT HOLDS ON GOLD, and it matters more there than
  -- 0.4.0-0.4.6 assumed.  Those versions claimed pokeball_colors was a
  -- Gen 1 mod that a Gold boot skips, so this fallback was "the only
  -- writer" -- wrong: Pokeball Colors runs on Gold too (0.1.22), where
  -- it colours the POKEMON CENTER HEAL MACHINE, and reading
  -- mon.caughtBall is exactly how it knows which ball to draw per party
  -- slot.  So on Gold the field is load-bearing for a mod that is
  -- present, not a fallback for one that is absent.
  --
  -- No code change was needed, which is the point of asking "does
  -- anything CLAIM the field" rather than "is that mod installed": the
  -- claim answers correctly on both generations, we stand aside when
  -- Colors is there and write it ourselves when it is not.
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
  -- SNARE BALL -- the first crafted ball, and a FINISHER.
  --
  -- Guaranteed on a sleeping or frozen target; an outright dud on
  -- anything else.  The dud is the design, not a rough edge: it is the
  -- reward for setting the status up, and softening it to 1x would make
  -- it a worse Poke Ball with extra steps.
  --
  -- STATUS IS SPELLED DIFFERENTLY ON EACH GENERATION, and this is
  -- exactly the assumption the craft brief warned not to make.  Read
  -- from source rather than assumed:
  --   Gen 1  src/battle/Status.lua ids are UPPERCASE codes -- SLP, FRZ,
  --          PSN, BRN, PAR.
  --   Gold   src/battle/gen2/Catching.lua's STATUS_BONUS keys are
  --          lowercase words -- sleep, freeze, burn, poison, toxic,
  --          paralyze.
  -- One normaliser covers both, and accepts either spelling on either
  -- generation so a mod-set status cannot silently miss.
  ----------------------------------------------------------------------
  local function isHeldStill(status)
    if type(status) ~= "string" then return false end
    local s = status:lower()
    return s == "slp" or s == "frz" or s == "sleep" or s == "freeze"
  end

  registerBall("SNARE_BALL", "SNARE BALL", 1200, {
    tossAnim = "ULTRATOSS_ANIM",
    attempt = function(ctx)
      local mon = ctx.targetMon
      if isHeldStill(mon and mon.status) then
        return true, 3            -- held still: it cannot get away
      end
      return false, 0             -- awake and moving: the snare closes on nothing
    end,
  })

  ----------------------------------------------------------------------
  -- CRADLE BALL -- a guaranteed catch that starts over at level 1.
  --
  -- Authored by ChatGPT against
  -- exchange/work-orders/too-many-balls-cradle-ball.md, reviewed here.
  --
  -- Not a punishment: DVs and stat exp are read and never replaced, so a
  -- mon caught at 40 and reset to 1 gains the whole stat-exp curve from
  -- scratch and ends up STRONGER at 100 than one caught late.  Four
  -- apricorns is the price of that, and the "downside" is the joke.
  --
  -- The guarantee uses the same replacement shape as SNARE and SILPH:
  -- Gen 1's attempt contract is `caught, shakes`, where true, 3 is the
  -- clean guaranteed catch; Gold's arm lives in the one catch.rate wrap.
  --
  -- The reset runs in pokemon.caught, which BOTH generations emit with
  -- the live mon AFTER it is in the party or box, so mutating that
  -- reference is what persists.
  --
  -- THE TWO GENERATIONS DO NOT SHARE A MON SHAPE, and this is the half
  -- the work order could not paste.  Verified against ./engine at
  -- v0.1.79 on intake rather than trusted:
  --   Gen 1 (src/pokemon/Pokemon.lua:60-85)  exp · stats · hp ·
  --         moves as { id, pp } · NO maxHp field at all
  --   Gold  (src/battle/gen2/Mon.lua:243-263) experience · stats ·
  --         maxHp · statExp · moves as { id, pp, maxPp }, which
  --         Mon.movesAtLevel already builds when handed data.moves
  ----------------------------------------------------------------------
  registerBall("CRADLE_BALL", "CRADLE BALL", 2000, {
    tossAnim = "ULTRATOSS_ANIM",
    attempt = function()
      return true, 3
    end,
  })

  local function resetCradleCaught(game, mon)
    local data = assert(game and game.data, "game data missing")
    local species = mon and mon.species
    local def = assert(data.pokemon and data.pokemon[species],
      "species missing: " .. tostring(species))

    if GEN2 then
      local Mon = require("src.battle.gen2.Mon")
      local growth = Mon.growthFor(data, def.growthRate)

      -- Everything is computed BEFORE the live record is touched, so a
      -- helper that fails leaves the caught Pokemon internally
      -- consistent rather than half-reset.
      local experience = Mon.experienceForLevel(growth, 1)
      local moves = Mon.movesAtLevel(def, 1, data.moves)
      local stats = Mon.stats(def.baseStats, mon.dvs, 1, mon.statExp)

      mon.level = 1
      mon.experience = experience
      mon.moves = moves
      mon.stats = stats
      mon.maxHp = stats.hp
      mon.hp = stats.hp

      -- caughtLevel deliberately keeps the ENCOUNTER level: the engine
      -- preserves it across evolution and daycare independently of the
      -- mon's current level, so resetting it would be a lie about where
      -- the Pokemon came from.
    else
      local Stats = require("src.pokemon.Stats")
      local Growth = require("src.pokemon.Growth")

      local exp = Growth.expForLevel(def.growthRate, 1, data.growth_rates)
      local moves = {}
      for _, id in ipairs(Pokemon.movesAtLevel(def, 1)) do
        local moveDef = data.moves and data.moves[id]
        moves[#moves + 1] = { id = id, pp = moveDef and moveDef.pp or 0 }
      end
      local stats = Stats.calc(def, 1, mon.dvs or {}, mon.statExp)

      mon.level = 1
      mon.exp = exp
      mon.moves = moves
      mon.stats = stats
      mon.hp = stats.hp
    end
  end

  mod.events:on("pokemon.caught", function(p)
    if not (p and p.ball == "CRADLE_BALL" and p.mon) then return end
    -- A failed reset must never cost the player the Pokemon they already
    -- caught, and must not escape the event bus into someone else's
    -- listener.  Named in [ERRS] rather than swallowed.
    local ok, err = pcall(resetCradleCaught, p.game, p.mon)
    if not ok then
      Runtime.reportError("kanto_balls", "CRADLE reset: " .. tostring(err))
      return
    end
    mod.log:info("CRADLE BALL: %s restarted at level 1", tostring(p.species))
  end)

  ----------------------------------------------------------------------
  -- ACE BALL -- rewards catching without first grinding the target down.
  --
  -- At full HP it is x4.  From there it falls in a straight line to x1
  -- at half HP, and stays at x1 below half.  Multiplying the species
  -- catch rate rather than replacing the roll leaves the ordinary HP and
  -- status parts of each generation's formula intact.
  --
  -- Gen 1 supplies targetMon.hp / targetMon.stats.hp in the ball attempt
  -- ctx (src/battle/Catching.lua:95-103).  Gold supplies the parallel
  -- o.hp / o.maxHp pair at its throw site
  -- (src/ui/gen2/BattleState.lua:2684-2700).
  ----------------------------------------------------------------------
  local function aceMultiplier(hp, maxHp)
    if type(hp) ~= "number" or type(maxHp) ~= "number" or maxHp <= 0 then
      return 1
    end
    local fraction = math.max(0, math.min(1, hp / maxHp))
    if fraction <= 0.5 then return 1 end
    return 1 + (fraction - 0.5) * 6
  end

  registerBall("ACE_BALL", "ACE BALL", 1200, {
    tossAnim = "ULTRATOSS_ANIM",
    attempt = function(ctx)
      local mon = ctx.targetMon
      local maxHp = mon and mon.stats and mon.stats.hp
      local mult = aceMultiplier(mon and mon.hp, maxHp)
      if mult > 1 then boost(ctx, mult) end
      return ctx.vanillaAttempt()
    end,
  })

  ----------------------------------------------------------------------
  -- CATALYST BALL -- the evolution-stone ball.
  --
  -- Reads `evolveItem`, which is in Gold's catch opts and is used by
  -- NOTHING -- not this mod, not Custom Poke Balls, not Kurt's seven.
  -- It was the one genuinely unclaimed field in the game.
  --
  -- Generalises our own MOON BALL from one stone to all of them, which
  -- is why MOON stays Gen 1-only and specific: they do not overlap.
  --
  -- Gold sets `evolveItem` only from an EVOLVE_ITEM row
  -- (src/ui/gen2/BattleState.lua's useItem), so its mere PRESENCE means
  -- "this species evolves by an item".  Gen 1 has no such field, so the
  -- attempt walks targetDef.evolutions for method == "ITEM" -- the MOON
  -- predicate with the specific stone check removed.
  ----------------------------------------------------------------------
  local function evolvesByItem(def)
    for _, evo in ipairs((def and def.evolutions) or {}) do
      if evo.method == "ITEM" then return true end
    end
    return false
  end

  registerBall("CATALYST_BALL", "CATALYST BALL", 1200, {
    attempt = function(ctx)
      if evolvesByItem(ctx.targetDef) then boost(ctx, 4) end
      return ctx.vanillaAttempt()
    end,
  })

  ----------------------------------------------------------------------
  -- DRIFT BALL -- the Heavy Ball's mirror.
  --
  -- HEAVY is taken twice over (Kurt's, and Custom Poke Balls'), but the
  -- INVERSE is claimed by nobody, and `weight` is already in the opts.
  --
  -- Units are the dex weight in TENTHS OF A POUND -- that is what
  -- Gold's own HeavyBallMultiplier reads before converting
  -- (src/battle/gen2/Catching.lua:64) -- so 200 is 20 lb and 500 is
  -- 50 lb.  TODO/CONFIRM the Gen 1 species record carries `weight` at
  -- all; if it does not, the Gen 1 arm simply never boosts rather than
  -- erroring, which is the safe way to be wrong.
  ----------------------------------------------------------------------
  local DRIFT_FEATHER = 200   -- 20 lb and under
  local DRIFT_LIGHT   = 500   -- 50 lb and under

  local function driftMultiplier(weight)
    if type(weight) ~= "number" then return 1 end
    if weight <= DRIFT_FEATHER then return 4 end
    if weight <= DRIFT_LIGHT then return 2 end
    return 1
  end

  registerBall("DRIFT_BALL", "DRIFT BALL", 1000, {
    attempt = function(ctx)
      local mult = driftMultiplier(ctx.targetDef and ctx.targetDef.weight)
      if mult > 1 then boost(ctx, mult) end
      return ctx.vanillaAttempt()
    end,
  })

  ----------------------------------------------------------------------
  -- KECLEON BALL -- a good all-round ball that changes colour to match
  -- what you throw it at.
  --
  -- IT WAS COSMETIC-ONLY UNTIL 0.4.28, and the developer's device report
  -- was "it feels worse".  The code was clean -- an unknown ball id gets
  -- `catchRate = opts.catchRate` at Catching.lua:283, arithmetically a
  -- Poke Ball -- so the finding was about the COMPANY it keeps, not a
  -- bug.  Every other ball in the craft tier is x4 when its condition
  -- holds (SNARE sleep/freeze, CATALYST stone-evolvers, DRIFT light
  -- targets) and CRADLE is a guaranteed catch.  A plain ball crafted
  -- from the same scarce apricorns, sitting in the same menu, reads as
  -- broken even while working correctly.
  --
  -- x1.5 UNCONDITIONAL is the answer, and 1.5 is not an invented number:
  -- it is what GREAT_BALL, SAFARI_BALL and PARK_BALL already carry in
  -- Catching.BALL_MULTIPLIER (Catching.lua:36-46), so this cannot drift
  -- out of step with the cart's own maths.  It fills the one slot four
  -- specialists leave empty -- strictly worse than any of them when
  -- their condition is met, strictly better when it is not.
  --
  -- It does NOT undercut buying Great Balls, because the currencies
  -- differ: Great Balls cost money, which is unlimited late; this costs
  -- two apricorns, capped by seven trees and their regrowth.
  --
  -- Not a fix for the report's own test case, and that was said plainly
  -- at the time: on a full-HP SNORLAX the HP term takes the species rate
  -- to a third before any ball touches it, so x1.5 moves /3 to /2 and a
  -- healthy target still shrugs it off.  The lever there is damage or
  -- status, not the ball.
  --
  -- The COLOUR trick still lives in the GOLD PALETTE WRAP further down,
  -- not here.  GEN 1 gets the ball and the multiplier but not the trick:
  -- colours there come from pokeball_colors' static table, which has no
  -- per-target hook, so on Red it throws in its own fixed green-and-red.
  --
  -- Price left at 800 deliberately -- it is craft-only, so the number is
  -- sell value rather than balance, and moving it was not asked for.
  ----------------------------------------------------------------------
  local KECLEON_MULT = 1.5

  registerBall("KECLEON_BALL", "KECLEON BALL", 800, {
    attempt = function(ctx)
      boost(ctx, KECLEON_MULT)
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

  -- Registered unconditionally; only the mart shelves below are gated on
  -- the dev flag (see the BALL_IDS note above for the pocket bug that
  -- gating the registration caused).  Under the flag `registerBall` also
  -- drops the price to 1, so "cheap" still means cheap.
  --
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

      elseif ball == "CRADLE_BALL" then
        -- Replace the roll outright.  Gold returns `caught,
        -- wFinalCatchRate`, and 255 drives the clean catch animation.
        return true, 255

      elseif ball == "ACE_BALL" then
        local mult = aceMultiplier(o.hp, o.maxHp)
        if mult > 1 then boostFlat(o, mult) end

      elseif ball == "CATALYST_BALL" then
        -- presence of evolveItem IS "evolves by an item" on Gold
        if o.evolveItem then boostFlat(o, 4) end

      elseif ball == "DRIFT_BALL" then
        local mult = driftMultiplier(o.weight)
        if mult > 1 then boostFlat(o, mult) end

      elseif ball == "SNARE_BALL" then
        -- Same contract as the Gen 1 attempt above: caught on a held
        -- target, an outright dud otherwise.  rate 1 on the dud gives
        -- the ball a token rock before it opens, matching SILPH.
        if isHeldStill(o.status) then return true, 255 end
        return false, 1

      elseif ball == "SILPH_BALL" then
        -- replace the roll outright: Master Ball or dud, ball spent
        -- either way.  rate is wFinalCatchRate, which the wobble
        -- animation runs on -- 255 plays the clean catch, 1 gives the
        -- dud a token rock before it breaks open.
        if oneIn(o, SILPH_FAILURE_IN) then return false, 1 end
        return true, 255

      elseif ball == "BEAST_BALL" then          -- sold only under CHEAP
        local rate = o.catchRate or 255
        if rate <= LEGENDARY_RATE or BEAST_EXCEPTIONS[o.species] then
          o.catchRate = LEGENDARY_SET
        else
          boostFlat(o, BEAST_PENALTY)
        end

      elseif ball == "KECLEON_BALL" then
        -- Unconditional, unlike every other arm here -- see the ball's
        -- own section for why a generalist earns the slot.  Same 1.5 the
        -- engine gives GREAT_BALL, and the same constant Gen 1's
        -- attempt() uses, so the two generations cannot disagree.
        boostFlat(o, KECLEON_MULT)
      end

      -- PREMIER, HEAL, GS: no catch code by design.
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
  -- GEN 2 shelves + pockets, at game.ready.  What this depends on is an
  -- ORDERING, not a line number: Game2:load populates data.gen2Marts and
  -- merges mod data BEFORE it emits game.ready.  (Cited as lines 904 and
  -- 1024 through 0.4.8; game.ready moved to 1006 in engine 0.1.79 with
  -- the ordering unchanged, which is exactly why the ordering is the
  -- thing to state.)
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
  --
  -- [DEV] CHEAP BALLS widens that to EVERY mart on Gold (Violet,
  -- Cherrygrove, all of them), prototype included -- so a fresh Gold
  -- save can test the full set at the first counter it reaches,
  -- without playing to a Great-tier mart first.  Same flag, same
  -- rules: prices are already 1, and it takes a full quit + relaunch.
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
      -- The case is a KEY ITEM, not a ball: its own pocket, and it must
      -- not eat one of the twelve ball slots.
      local caseDef = data.items and data.items[CASE_ID]
      if caseDef and caseDef.pocket == nil then
        caseDef.pocket = "KEY_ITEM"
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
          if CHEAP or has.GREAT_BALL or has.ULTRA_BALL then
            for _, id in ipairs(SHELF) do
              if not has[id] then
                list[#list + 1] = id
                has[id] = true
              end
            end
            if (CHEAP or has.ULTRA_BALL) and not has.SILPH_BALL then
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
  -- THE BALL CASE -- crafting, and the mod's own front door.
  --
  -- WHY A CASE AND NOT KURT.  The `apricorns` registry is 1:1 and
  -- ROM-bound (event ids and a checkevent chain in maps/KurtsHouse.asm),
  -- so combinations are not expressible through it and retargeting one
  -- of Kurt's seven would REMOVE a canon ball.  We use none of it:
  -- apricorns are ordinary bag items, so taking them is Bag.remove,
  -- giving a ball is Bag.add, and the recipe table below is ours with no
  -- ROM index to respect.  Kurt keeps working, untouched, and two
  -- economies coexist.  Full reasoning in briefs/BALL_CASE.md.
  --
  -- THE ENTRY POINT, verified at engine 0.1.79 rather than assumed --
  -- it was the open question that nearly made this an NPC instead:
  --   PackMenu:useSelected (src/ui/gen2/PackMenu.lua:303) hands a field
  --   use to world:useFieldItem(row.id) (:332).  A truthy result closes
  --   the PACK; nil falls through to the vanilla refusals.
  --   World:useFieldItem (src/world/gen2/World.lua:4353) is a plain
  --   if-chain on item id and RETURNS NIL for anything it does not know.
  -- So the wrap below only ever claims an id the engine already answered
  -- nil for: every vanilla item keeps its behaviour.
  --
  -- GOLD ONLY for now.  Gen 1's bag has its own use path
  -- (src/ui/BagMenu.lua) which is not read yet, and there is nothing to
  -- craft on Gen 1 regardless -- apricorns are Gen 2 items.  The case
  -- item is therefore not registered on a Gen 1 boot at all, rather than
  -- registered and inert.  TODO/CONFIRM the Gen 1 route when the Gen 1
  -- acquisition design is settled.
  ----------------------------------------------------------------------
  -- (CASE_ID is declared up beside BALL_IDS -- see the note there.)

  -- Recipes are DATA, deliberately: adding one is a row, and the whole
  -- table is what a future Kurt tutorial, a recipe-discovery gate or a
  -- second front end reads.  `inputs` is item id -> count.
  --
  -- `learned` is reserved and unused today: every recipe is available
  -- immediately.  When Kurt teaches recipes it becomes the gate, and
  -- nothing else has to change.  TODO/CONFIRM with the developer.
  -- The craft tier, in ladder order: cheap utility first, specialists
  -- after.  Every recipe is MULTI-apricorn and most are mixed colours,
  -- which is the whole advantage of owning the table -- Kurt is
  -- strictly 1:1 and ROM-bound, so a tier of single-apricorn recipes
  -- would be Kurt with extra steps.
  --
  -- COSTED AGAINST REAL SUPPLY, not the dev shelf: seven apricorn trees
  -- on a daily refill, one colour each.  A 2-apricorn recipe is about
  -- two days and a 3-apricorn mixed one is a small project, so the tier
  -- stays playable on tree supply and an apricorn farm would make it
  -- comfortable rather than mandatory.
  --
  -- CRADLE alone costs FOUR.  It is the capstone, and the recipe IS the
  -- balance for a guaranteed catch -- do not add a further penalty to
  -- the ball to compensate.
  local RECIPES = {
    {
      id = "CATALYST_BALL",
      label = "CATALYST BALL",
      inputs = { GRN_APRICORN = 1, YLW_APRICORN = 1 },
      blurb = "Good on those that",
      blurb2 = "evolve by stone.",
    },
    {
      id = "DRIFT_BALL",
      label = "DRIFT BALL",
      inputs = { WHT_APRICORN = 1, YLW_APRICORN = 1 },
      blurb = "For the light and",
      blurb2 = "hard to pin down.",
    },
    {
      id = "SNARE_BALL",
      label = "SNARE BALL",
      inputs = { BLK_APRICORN = 2 },
      blurb = "Holds a sleeping",
      blurb2 = "or frozen one.",
    },
    {
      id = "KECLEON_BALL",
      label = "KECLEON BALL",
      -- Kecleon's own green and red, and the cheapest recipe in the
      -- tier -- now the tier's generalist rather than its novelty.
      inputs = { GRN_APRICORN = 1, RED_APRICORN = 1 },
      blurb = "A good ball that",
      blurb2 = "mimics its target.",
    },
    {
      id = "CRADLE_BALL",
      label = "CRADLE BALL",
      inputs = {
        WHT_APRICORN = 1, PNK_APRICORN = 1,
        GRN_APRICORN = 1, RED_APRICORN = 1,
      },
      blurb = "A fresh start for",
      blurb2 = "what it catches.",
    },
    {
      id = "ACE_BALL",
      label = "ACE BALL",
      inputs = { WHT_APRICORN = 1, BLU_APRICORN = 1 },
      learned = "route_aces:ace_ball",
      blurb = "Best on a target",
      blurb2 = "still at full HP.",
    },
  }

  -- How many of `id` the bag holds.  save.inventory is a flat id->count
  -- map on both generations.
  local function held(save, id)
    local inv = save and save.inventory
    local n = inv and inv[id]
    return (type(n) == "number" and n) or 0
  end

  ----------------------------------------------------------------------
  -- RECIPE LEARNING -- a read-only cross-mod contract.
  --
  -- A teaching mod writes save.recipeUnlocks[recipe.learned] = true.
  -- We never check which mod is installed and never create that table:
  -- the save field is the contract, so either side may ship first and an
  -- unlock earned earlier appears as soon as the Case next builds rows.
  -- SaveSerializer walks arbitrary keys recursively with no whitelist
  -- (src/core/SaveSerializer.lua:12-42), including keys containing `:`.
  ----------------------------------------------------------------------
  local function recipeUnlocked(save, recipe)
    if not (recipe and recipe.learned) then return true end
    local unlocks = save and save.recipeUnlocks
    return type(unlocks) == "table" and unlocks[recipe.learned] == true
  end

  local function canCraft(save, recipe)
    -- Visibility is not security: keep the same gate here so another UI
    -- or future caller cannot craft a hidden recipe by reaching craft().
    if not recipeUnlocked(save, recipe) then return false end
    for id, need in pairs(recipe.inputs) do
      if held(save, id) < need then return false end
    end
    return true
  end

  -- Craft one.  Returns ok, reason.
  --
  -- THE ORDER MATTERS AND IS THE WHOLE POINT: the output is added FIRST,
  -- and the inputs are only consumed once that succeeded.  Bag.add
  -- refuses when the pocket is full (src/inventory/Bag.lua:107), and a
  -- naive consume-then-award would eat the apricorns and hand back
  -- nothing.  Test that path specifically -- it is the one that costs a
  -- player real materials if it is wrong.
  local function craft(save, data, recipe)
    if not (save and recipe) then return false, "no save" end
    if not canCraft(save, recipe) then return false, "need more" end
    if not Bag.add(save, recipe.id, 1, data) then
      return false, "pack full"
    end
    for id, need in pairs(recipe.inputs) do
      Bag.remove(save, id, need)
    end
    return true
  end

  ----------------------------------------------------------------------
  -- BALL CASE STORAGE -- only the balls this mod owns.
  --
  -- Authored by ChatGPT against
  -- exchange/work-orders/too-many-balls-case-storage.md, reviewed here.
  --
  -- WHY IT EXISTS: with the mod disabled its item ids stay in the save
  -- but nothing registers them, so they fall into the ITEMS pocket under
  -- raw names.  No mod can fix that from outside -- a disabled mod's
  -- entry chunk never runs and Loader:setEnabled emits no event -- so
  -- the player stows deliberately before switching off instead.
  --
  -- Apricorns are NOT stowed: they are ordinary vanilla items and look
  -- perfectly normal with the mod off.  The CASE is not stowed either --
  -- it is the container, and stowing it would strand the contents.
  ----------------------------------------------------------------------
  local STOWED_KEY = "stowed"

  local function stowedBalls()
    local value = mod.save:get(STOWED_KEY)
    if type(value) ~= "table" then return {} end
    return value
  end

  local function countStored(stowed)
    local total = 0
    for _, id in ipairs(BALL_IDS) do
      local n = stowed and stowed[id]
      if type(n) == "number" and n > 0 then total = total + n end
    end
    return total
  end

  local function countOwnedInBag(save)
    local total = 0
    for _, id in ipairs(BALL_IDS) do
      total = total + held(save, id)
    end
    return total
  end

  local function stowAll(save)
    if not save then return 0 end
    local stowed = stowedBalls()
    local moved = 0
    for _, id in ipairs(BALL_IDS) do
      local n = held(save, id)
      if n > 0 then
        -- Bag.remove maintains inventory AND bagOrder; never write
        -- save.inventory directly.
        Bag.remove(save, id, n)
        local old = stowed[id]
        if type(old) ~= "number" or old < 0 then old = 0 end
        stowed[id] = old + n
        moved = moved + n
      end
    end
    if moved > 0 then mod.save:set(STOWED_KEY, stowed) end
    return moved
  end

  local function takeBack(save, data)
    local stowed = stowedBalls()
    local before = countStored(stowed)
    if before == 0 or not save then return 0, before end

    local moved, blocked = 0, false
    for _, id in ipairs(BALL_IDS) do
      local n = stowed[id]
      if type(n) ~= "number" or n < 1 then n = 0 end
      -- ONE AT A TIME, deliberately.  Bag.add refuses a whole quantity
      -- when the pocket is full or the stack would pass 99, so asking
      -- for the lot would return nothing when only some fit.  This
      -- returns everything that fits and leaves the exact remainder.
      --
      -- And it ADDS BEFORE IT DECREMENTS: the stow is only reduced once
      -- Bag.add has said yes.  The reverse order would eat the player's
      -- balls against a full pocket, which is the one failure here that
      -- costs something real.
      while n > 0 do
        if not Bag.add(save, id, 1, data) then blocked = true break end
        n = n - 1
        moved = moved + 1
        if n > 0 then stowed[id] = n else stowed[id] = nil end
      end
      if blocked then break end
    end

    mod.save:set(STOWED_KEY, stowed)
    return moved, countStored(stowed)
  end

  if GEN2 then
    -- The case itself.  A KEY ITEM: its own 25-slot pocket, so it costs
    -- nothing from the twelve ball slots this mod is already stretching.
    -- `pocket` is stamped post-merge with the balls (the items schema
    -- has no such field), just like pocket = "BALL".
    mod.content.items:register(CASE_ID, {
      id = CASE_ID, name = "BALL CASE", price = 2000, tossable = false,
      description = "Mix APRICORNS into\nnew kinds of ball.",
    })

    ------------------------------------------------------------------
    -- The screen.  Registered through the `screens` registry, which
    -- keeps its Gen 1 target on Gold (Schemas.lua:568-570), so
    -- Screens.push resolves a mod-owned screen on both generations.
    -- A screen is { new(game, opts), update(dt), draw() } plus
    -- isOpaque -- the shape src/ui/gen2/ScriptMenu.lua uses.
    ------------------------------------------------------------------
    local Chrome = require("src.ui.gen2.Chrome")
    local Screens = require("src.ui.Screens")

    local Case = {}
    Case.__index = Case
    Case.isOpaque = true

    function Case.new(game)
      local self = setmetatable({}, Case)
      self.game = game
      self.save = game and game.save
      self.data = game and game.data
      self.index = 1
      self.message = nil
      return self
    end

    -- Rows are now TAGGED, not bare recipes: CANCEL used to be virtual
    -- (index == #rows + 1) and the two new actions could not be told
    -- apart that way.  Anything reading a row must switch on `kind`.
    function Case:rows()
      local rows = {}
      for _, recipe in ipairs(RECIPES) do
        -- Read the LIVE screen save every build: unlocks earned in this
        -- session appear immediately.  Locked recipes are hidden rather
        -- than greyed so a missing teaching mod never looks like a bug.
        if recipeUnlocked(self.save, recipe) then
          rows[#rows + 1] = { kind = "recipe", label = recipe.label,
                              recipe = recipe }
        end
      end
      rows[#rows + 1] = { kind = "stow", label = "STOW ALL" }
      rows[#rows + 1] = { kind = "take",
        label = "TAKE BACK (" .. tostring(countStored(stowedBalls())) .. ")" }
      rows[#rows + 1] = { kind = "cancel", label = "CANCEL" }
      return rows
    end

    function Case:close()
      local stack = self.game and self.game.stack
      if stack and stack.pop then stack:pop() end
    end

    function Case:update()
      local input = self.game and self.game.input
      if not input then return end
      -- A message box swallows the next press, the way every engine
      -- screen does it: read the result, then carry on.
      if self.message then
        if input:wasPressed("a") or input:wasPressed("b") then
          self.message = nil
        end
        return
      end
      local rows = self:rows()
      if input:wasPressed("down") then
        -- #rows, not #rows + 1: CANCEL is a real row now.
        self.index = math.min(#rows, self.index + 1)
      elseif input:wasPressed("up") then
        self.index = math.max(1, self.index - 1)
      elseif input:wasPressed("b") then
        self:close()
      elseif input:wasPressed("a") then
        local row = rows[self.index]
        if not row then return end

        if row.kind == "cancel" then
          return self:close()

        elseif row.kind == "recipe" then
          local recipe = row.recipe
          local ok, reason = craft(self.save, self.data, recipe)
          if ok then
            -- TWO lines, always.  The message box is 20 wide with
            -- borders, so 18 columns of text, and "Made a CATALYST
            -- BALL!" is 21 -- it soft-wrapped and scrolled on device.
            -- Splitting at the label keeps the longest craft line at
            -- 14 ("CATALYST BALL!") with room for a longer name later.
            self.message = { "Made a", recipe.label .. "!" }
          elseif reason == "pack full" then
            self.message = { "No room for it." }
          else
            self.message = { "Not enough", "APRICORNS." }
          end

        elseif row.kind == "stow" then
          local moved = stowAll(self.save)
          if moved > 0 then
            self.message = { "Stowed " .. tostring(moved) .. " balls." }
          else
            self.message = { "Nothing to stow." }
          end

        elseif row.kind == "take" then
          if countStored(stowedBalls()) == 0 then
            self.message = { "The case is", "empty." }
          else
            local moved, remaining = takeBack(self.save, self.data)
            if remaining > 0 then
              self.message = { "No room for the", "rest." }
            else
              self.message = { "Took " .. tostring(moved) .. " back." }
            end
          end
        end
      end
    end

    -- ROW SPACING IS 1, NOT 2, AND THAT IS A FIX RATHER THAN A STYLE
    -- CHOICE.  The screen is 18 tile rows (144px / 8), and the returned
    -- patch kept the old two-row spacing while adding three rows.  With
    -- five recipes that is eight rows from y=3 at stride 2 -- y=17,
    -- which is the box's own bottom border, off the usable area.  It
    -- only breaks once CRADLE lands, so the two returns were each fine
    -- alone and wrong together.
    --
    -- Stride 1 puts eight rows at y=3..10, well clear of the message
    -- box at y=12, and leaves room for several more recipes before this
    -- needs scrolling.
    function Case:draw()
      local rows = self:rows()
      Chrome.box(0, 0, 20, 12)
      Chrome.print("BALL CASE", 1, 1)
      -- ROWS START AT 2, NOT 3, AND THAT IS CAPACITY, NOT TASTE.
      -- Font.drawBox puts its bottom border at ty + th - 1
      -- (src/render/Font.lua:549), so this 12-tall box borders at row 11
      -- and its interior is rows 1..10.  With ACE BALL LOCKED there are
      -- eight rows and y=3 fits; the moment Route Aces unlocks it there
      -- are nine, and the last would land on 11 -- the border itself.
      -- Starting at 2 fits all nine.
      --
      -- The next recipe after that does NOT fit, and the harness asserts
      -- exactly this, so it will fail loudly rather than overflowing on
      -- someone's phone.  When that day comes the answer is a scrolling
      -- list, not another row of shaving.
      local y = 2
      for i, row in ipairs(rows) do
        -- A row that would do nothing is marked, in its OWN column so
        -- every label shares a left edge (the ragged edge the developer
        -- spotted on device at 0.4.12).
        local doesNothing = false
        if row.kind == "recipe" then
          doesNothing = not canCraft(self.save, row.recipe)
        elseif row.kind == "stow" then
          doesNothing = countOwnedInBag(self.save) == 0
        elseif row.kind == "take" then
          doesNothing = countStored(stowedBalls()) == 0
        end
        if doesNothing then Chrome.print("-", 2, y) end
        Chrome.print(row.label, 3, y)
        if i == self.index then Chrome.cursor(1, y) end
        y = y + 1
      end
      if self.message then
        Chrome.box(0, 12, 20, 6)
        for i, line in ipairs(self.message) do
          Chrome.print(line, 1, 13 + i)
        end
      end
    end

    mod.content.screens:register("KbBallCase", { new = Case.new })

    ------------------------------------------------------------------
    -- The wrap.  Stash-originals, never a sentinel: engine module
    -- tables live for the process, so a reload would otherwise keep an
    -- old wrapper live and make this version look inert.
    ------------------------------------------------------------------
    -- THE PUSH MUST BE DEFERRED BY A FRAME, and 0.4.11 learned why the
    -- hard way: it pushed inline and nothing happened at all.
    --
    -- PackMenu:useSelected takes a truthy result from useFieldItem and
    -- calls self:exitToField (src/ui/gen2/PackMenu.lua:353), which is
    -- `stack:clear()` -- and StateStack:clear is `while self:top() do
    -- self:pop() end` (src/core/StateStack.lua:56).  It empties the
    -- WHOLE stack, so a screen pushed during the call is torn down a
    -- moment later along with the pack.  Not a pop we could out-order:
    -- a loop that runs until the stack is empty cannot be beaten by
    -- pushing harder.
    --
    -- So: flag it here, and push after the frame's update has finished
    -- (Game2:update at src/core/Game2.lua:1081 drives the fixed step
    -- that runs the stack).  Pushing after vanilla's update also means
    -- the A press that opened the case is already consumed, so the case
    -- cannot immediately eat it as a selection.
    local pendingCase = false

    local World = require("src.world.gen2.World")
    World._kbOriginals = World._kbOriginals
      or { useFieldItem = World.useFieldItem }
    local vanillaUseFieldItem = World._kbOriginals.useFieldItem

    World.useFieldItem = function(self, itemId)
      if itemId ~= CASE_ID then
        return vanillaUseFieldItem(self, itemId)
      end
      if not self.game then return nil end
      pendingCase = true
      -- Truthy: the PACK closes, which is what we want -- the case
      -- opens over the overworld rather than on top of the bag.
      return "kb_ball_case"
    end

    local Game2 = require("src.core.Game2")
    Game2._kbOriginals = Game2._kbOriginals or { update = Game2.update }
    local vanillaGameUpdate = Game2._kbOriginals.update

    Game2.update = function(self, dt)
      vanillaGameUpdate(self, dt)

      -- Deferred dialogue (Kurt's coda) waits for a QUIET WORLD, not
      -- merely the next frame.  World:busy() is the engine's own guard
      -- (src/world/gen2/World.lua:1444): it is true while the VM is
      -- running, a text box or choice box is up, an object is moving, a
      -- map setup is fading, and so on.  Firing into a busy world is
      -- what made the coda flash past -- the box went up while the
      -- player's A press from Kurt's own dialogue was still in flight,
      -- and was dismissed by it.
      if pendingCoda then
        local world = self.world
        if world and world.busy and not world:busy() then
          local fn = pendingCoda
          pendingCoda = nil
          local ok, err = pcall(fn)
          if not ok then
            Runtime.reportError("kanto_balls", "CODA " .. tostring(err))
          end
        end
      end

      if not pendingCase then return end
      pendingCase = false
      local ok, err = pcall(Screens.push, self, "KbBallCase")
      if not ok then
        Runtime.reportError("kanto_balls", "CASE FAIL " .. tostring(err))
      end
    end
  end

  ----------------------------------------------------------------------
  -- KURT HANDS OVER THE BALL CASE.
  --
  -- Real content, not dev scaffolding: this is how the case is EARNED.
  -- The dev shelf still sells one until this is confirmed on a device.
  --
  -- HIS OWN LINES ARE UNTOUCHED.  On Gold, Kurt is a vanilla NPC whose
  -- talk runs the cart's decoded bytecode (npc.def.scriptKey ->
  -- Vm:start), and a Lua row list merged into gen2Scripts is explicitly
  -- not something that VM can run -- so the Gen 1 map_scripts takeover
  -- has no Gold equivalent and we do not attempt one.  Instead we wait
  -- for his script to FINISH (Vm:emitScriptEnded ->  "script.ended",
  -- src/script/gen2/Vm.lua:2245) and add a coda after it.  He says his
  -- piece; then he says ours.
  --
  -- THE GATE is the moment he GIVES you something, which is the rescue
  -- conversation itself.  See the long note below for how that was
  -- established and why the earlier badge gate was wrong.
  --
  -- Gold's rom manifest carries NO event-flag names at all (checked:
  -- every EVENT_ hit in it is a false positive inside HELD_PREVENT_*),
  -- and Gen 2 flags are numeric-only, so "the well is done" is not
  -- readable by name.  Reading the conversation instead needs no flag.
  --
  -- TODO/CONFIRM on device: that KURT_SCRIPT is KURT and not his
  -- granddaughter.  It came off the 0.4.13 probe (map 8:4 =
  -- KURTS_HOUSE, object 2) and the house holds more than one person --
  -- though the 0.4.19 probe run makes this near-certain, since the
  -- script it captured walks object 2 out of the house and later hands
  -- over an item, which is Kurt's part and nobody else's.
  ----------------------------------------------------------------------
  if GEN2 then
    -- ROM-derived, read from the running game with the 0.4.13 probe and
    -- never guessed.  If Gold's script pool is ever re-walked this may
    -- move, so the handover reports to [ERRS] when it fires rather than
    -- being invisible either way.
    local KURT_SCRIPT = "55:45e3"

    -- WHEN THIS FIRES: the conversation in which KURT GIVES YOU
    -- SOMETHING.  That is the rescue conversation -- he hands over a
    -- LURE BALL for saving him from Slowpoke Well -- and it is exactly
    -- the moment the developer asked for: his parting line on the way
    -- back, not the one on the way out.
    --
    -- HOW WE KNOW, from a probe on the running game (0.4.19, read off
    -- the PC rig's log) rather than from guessing.  His house object has
    -- ONE scriptKey for every story state, so script.ended alone cannot
    -- tell the branches apart -- but the two runs are unmistakable:
    --
    --   first meeting  … applymovement, DISAPPEAR object=2, end
    --                    (he walks out; gives nothing)
    --   the return     … writetext, promptbutton, VERBOSEGIVEITEM,
    --                    then a long checkevent/iftrue chain
    --                    (he hands over an item; he stays)
    --
    -- 0.4.14 gated on the HIVE badge as a stand-in for "the well is
    -- done" and that was simply wrong: a save can hold the badge while
    -- Kurt is still in his pre-well state, which is how the coda landed
    -- on the first meeting.  The badge and the interim skip-the-first
    -- counter are both gone -- this reads the actual story moment, so it
    -- needs no proxy and no `learned`-style bookkeeping.
    --
    -- WHY A BAG DIFF AND NOT THE OPCODE: watching for `verbosegiveitem`
    -- means keeping a `script.command` wrap installed forever, and
    -- Runtime.wantsHook("script.command") being true puts EVERY command
    -- of EVERY script in the game through the hooked path
    -- (src/script/gen2/Vm.lua:1747).  A snapshot of the bag on his
    -- script.started and a compare on script.ended costs nothing outside
    -- his conversation and answers the same question: did he give me
    -- something?
    --
    -- A later conversation where he hands over a finished apricorn ball
    -- also passes this test.  That is fine and deliberate: it is still
    -- post-rescue, the case is given once, and "Kurt gave you something"
    -- is the honest condition rather than a fragile guess at which gift.
    local kurtBag = nil

    mod.events:on("script.started", function(p)
      local ctx = p and p.ctx
      kurtBag = nil
      if not (ctx and ctx.scriptKey == KURT_SCRIPT) then return end
      if mod.save:get("caseGiven") then return end
      local save = mod.game and mod.game.save
      local inv = save and save.inventory
      if not inv then return end
      local snap = {}
      for id, n in pairs(inv) do snap[id] = n end
      kurtBag = snap
    end)

    mod.events:on("script.ended", function(p)
      local ctx = p and p.ctx
      local snap = kurtBag
      kurtBag = nil
      if not (ctx and ctx.scriptKey == KURT_SCRIPT) then return end
      if not p.completed then return end
      if not snap then return end
      if mod.save:get("caseGiven") then return end

      local game = mod.game
      local save = game and game.save
      if not save then return end

      -- Did anything in the bag go UP during his conversation?  Checked
      -- before we add the case ourselves, so our own gift cannot be the
      -- thing that satisfies the test.
      local gained = false
      for id, n in pairs(save.inventory or {}) do
        if type(n) == "number" and n > (snap[id] or 0) then
          gained = true
          break
        end
      end
      if not gained then return end
      -- Already carrying one (the dev shelf, or a previous save): mark
      -- it done rather than handing over a second.
      if (save.inventory and save.inventory[CASE_ID]) then
        mod.save:set("caseGiven", true)
        return
      end
      if not Bag.add(save, CASE_ID, 1, game.data) then return end
      mod.save:set("caseGiven", true)

      -- His coda, DEFERRED until the world is quiet -- see the drain in
      -- the Game2.update wrap above.  Queued rather than spoken here
      -- because script.ended fires while the VM is still unwinding and
      -- the player's A press is still in flight; both boxes went up and
      -- were dismissed instantly, which read on device as the lines
      -- "firing too fast".
      --
      -- WIDTH IS TWO LINES OF EIGHTEEN COLUMNS, and the first draft
      -- broke it badly: one line ran to 46 characters.  An over-length
      -- line does not clip -- TextBox soft-wraps it and the page then
      -- SCROLLS (src/render/TextBox.lua, MAX_COLS 18), which is the
      -- other half of what "too fast" looked like.  `\n` is the second
      -- line of a box; each row below is one box the player dismisses.
      pendingCoda = function()
        mod.world:queueScript({
          { "text", "APRICORNS aren't\njust for my seven." },
          { "text", "Take this CASE and\nmix your own." },
        })
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
  -- These colours are the GEN 1 throw palette.  Gold does not need them
  -- -- it draws a thrown ball from its own palette set, which is what
  -- the battleObjects rows and the ballPalette wrap below are for -- so
  -- on a Gold boot this registers colours nothing reads, harmlessly.
  --
  -- What is NOT harmless is the claim 0.4.0-0.4.6 made here, that a Gold
  -- boot skips pokeball_colors entirely.  It does not: Colors 0.1.22
  -- runs on Gold and paints the Pokemon Center heal machine, taking each
  -- ball's colour from ballPalette + battleObjects -- i.e. from the very
  -- registrations below -- so our balls are coloured at the Center with
  -- no coordination, and so is anything registered through
  -- exports.registerBallPalette.
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
    -- SNARE: dark green trap, pale bone catch.  Confirmed on device.
    SNARE_BALL   = { body = {  56, 104,  72 }, accent = { 224, 216, 176 } },
    -- The craft tier.  DEVICE-CONFIRMED 2026-08-13 except ACE.
    -- CATALYST: the evolution flash IS the ball, with a stone-grey band.
    -- It was the other way round for one round and came back reading as
    -- DARK PURPLE next to CRADLE's light purple -- two purple balls, and
    -- adjacent rows in the case at that.  Same inversion the PREMIER
    -- BALL hit in 0.4.2: a colour on `accent` only shades the body, so
    -- grey body + magenta accent dithers to purple at sprite size.  The
    -- ball a player is meant to recognise goes on `body`.
    CATALYST_BALL = { body = { 200,  72, 208 }, accent = { 216, 216, 224 } },
    -- DRIFT: pale sky and cloud-white, as light as it reads.
    DRIFT_BALL   = { body = { 152, 200, 232 }, accent = { 248, 250, 252 } },
    -- KECLEON: the lizard's green with its red stripe -- but this is the
    -- FALLBACK only; in battle the ball takes its target's own palette,
    -- confirmed on device (pink on a SLOWPOKE, yellow on a PIKACHU).
    KECLEON_BALL = { body = {  72, 168,  96 }, accent = { 216,  72,  88 } },
    -- CRADLE: soft nursery lavender with a warm cream accent. Confirmed.
    CRADLE_BALL  = { body = { 184, 168, 216 }, accent = { 248, 232, 200 } },
    -- ACE: trophy blue under a gold band. TODO/CONFIRM on a real throw.
    ACE_BALL     = { body = {  56,  88, 176 }, accent = { 240, 192,  64 } },
  }
  if not GEN2 then
    COLORS.MOON_BALL = { body = {  60,  68, 128 }, accent = { 232, 208,  96 } }
    COLORS.FAST_BALL = { body = { 232, 148,  48 }, accent = { 248, 232, 152 } }
  end

  -- GS and BEAST are registered on every boot now, so their colours are
  -- too: Pokeball Colors 0.1.13+ warns about a registered ball carrying
  -- no colour, and a ball held from an earlier dev session should look
  -- like itself whether or not the flag is on today.
  do
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

  ----------------------------------------------------------------------
  -- GOLD BALL COLOURS -- the THROW is ours; the Center is Colors'.
  --
  -- Gen 1's colour problem does not exist on Gold: the engine resolves a
  -- per-ball palette from the cart's own data/battle_anims/ball_colors.asm
  -- (src/ui/gen2/BattleState.lua:2101 ballPalette -> startBallAnim's
  -- opts.ballPalette -> AnimObjects ballPal -> BattleAnimView:objPalette).
  -- That table (BALL_COLORS, :2041) is module-local and covers the eleven
  -- cart balls; anything else falls to PAL_BATTLE_OB_GRAY (:2054).  So on
  -- Gold our balls would all throw GREY without this block.
  --
  -- WHO OWNS WHAT ON GOLD, corrected at 0.4.7.  Pokeball Colors withdrew
  -- from Gen 2 at its 0.1.21, which is what 0.4.2-0.4.6 were written
  -- against; it CAME BACK at 0.1.22 and is an optional integration on
  -- both generations now.  The split is clean and the two halves do not
  -- overlap:
  --   THROW  (this block)  a ball's colour in battle, ours, because the
  --                        engine's ball -> palette table is module-local
  --                        and only a wrap can extend it.
  --   CENTER (Colors)      the balls on the heal machine, which Gold
  --                        draws all in one palette.  Colors reads each
  --                        ball's colour back out of ballPalette +
  --                        battleObjects -- the registrations right here
  --                        -- so our balls, and anything registered
  --                        through registerBallPalette, are covered with
  --                        no coordination and no second colour table.
  -- It also needs mon.caughtBall to know which ball to draw per slot;
  -- see THE MARK above for why we stand aside from that field.
  --
  -- So this mod still owns the wrap.  Declared in
  -- exports.owns.ballPalettesGen2, and registerBallPalette below is the
  -- door other ball mods use instead of installing a SECOND wrap on the
  -- same method -- chained wrappers would make load order decide the
  -- colour, and silently.  Colors reading our answer, rather than either
  -- side wrapping twice, is what keeps that true now that both mods are
  -- on Gold.
  --
  -- TWO HALVES, and only one of them has a registry:
  --   values  `palettes` routes to gen2Palettes and `battleObjects` is a
  --           first-class Gen 2 key (Schemas.lua:1660), so the rows go in
  --           through the normal registry with no wrap and no internals.
  --   mapping ball id -> palette NAME has no registry at all, so the
  --           method wrap below is the only route.  Watch for the engine
  --           routing a registry at BALL_COLORS, or reading a `color`
  --           field off the ball's own record -- either deletes this wrap.
  --
  -- ROW SHAPE, verified rather than assumed (the one thing the incoming
  -- brief could not confirm): a battleObjects row is FOUR colours, not
  -- two.  RomExtractorGen2:battleObjectPals reads 8 bytes = 4 colours per
  -- row (:492), and the shader takes pal0..pal3 indexed by the sprite's
  -- own shade, lightest to darkest (GbcPalette.lua:47-65).  The
  -- "OBJ rows carry two colours" note at Schemas.lua:729 is about sprite
  -- and mon-pic rows, not these.
  --
  -- So each row below is { highlight, light, main, outline }.  These are
  -- a FIRST PASS carried over from the Gen 1 body/accent pairs and they
  -- are NOT tuned against Gold's own ball palettes -- Gold's are the
  -- cart's six fixed rows, a different set from anything the Gen 1 strip
  -- tool measured, so tuning starts over and has to happen on device.
  -- TODO/CONFIRM every value here against a real Gold throw.
  ----------------------------------------------------------------------
  -- DEVICE-CONFIRMED, 0.4.2 test round: the THIRD entry (pal2) is the
  -- tone that reads as the ball's body -- Premier came back looking like
  -- a red-and-white Poke Ball because its pal2 was the red accent, while
  -- every ball whose pal2 was its body colour (Nest green, Heal pink,
  -- Mirror silver, Silph purple, Beast navy) read correctly.  So pal2 is
  -- the colour to pick first; pal1 is the lighter shading above it.
  local BALL_PALETTE_ROWS = {
    -- ALL WHITE, at the developer's call after seeing it on device: the
    -- Premier Ball's whole identity is being plain white, and putting
    -- the red band on pal2 made it read as an ordinary Poke Ball.  White
    -- body, light grey shading, black outline.
    PAL_KB_PREMIER = { {255,255,255}, {248,248,248}, {216,216,216}, {24,24,24} },
    PAL_KB_NEST    = { {255,255,255}, {140,230,170}, { 80,200,128}, {24,24,24} },
    PAL_KB_HEAL    = { {255,255,255}, {248,238,244}, {232,160,196}, {24,24,24} },
    PAL_KB_MIRROR  = { {255,255,255}, {244,250,255}, {168,180,200}, {24,24,24} },
    -- the prototype: Master-ball purple over its teal flash
    PAL_KB_SILPH   = { {255,255,255}, { 96,216,200}, {120, 88,168}, {24,24,24} },
    PAL_KB_SNARE   = { {255,255,255}, {224,216,176}, { 56,104, 72}, {24,24,24} },
    -- CATALYST: pal2 was the stone grey and it read DARK PURPLE against
    -- CRADLE's light purple on device.  The magenta is the body now, and
    -- pal1 is a lighter magenta -- the same shading relationship NEST and
    -- HEAL already use, rather than a contrasting tone that muddies it.
    PAL_KB_CATALYST = { {255,255,255}, {236,168,244}, {200, 72,208}, {24,24,24} },
    PAL_KB_DRIFT   = { {255,255,255}, {248,250,252}, {152,200,232}, {24,24,24} },
    PAL_KB_KECLEON = { {255,255,255}, {216, 72, 88}, { 72,168, 96}, {24,24,24} },
    PAL_KB_CRADLE  = { {255,255,255}, {248,232,200}, {184,168,216}, {24,24,24} },
    -- Third entry is the body tone. TODO/CONFIRM on a real Gold throw --
    -- ACE is the one craft ball still unseen, because it stays hidden
    -- until Route Aces unlocks the recipe.
    PAL_KB_ACE     = { {255,255,255}, {240,192, 64}, { 56, 88,176}, {24,24,24} },
  }
  -- ball id -> palette name.  MOON and FAST are deliberately ABSENT: they
  -- are the cart's own Kurt balls on Gold and already get real colours
  -- there, which is what a Gold player expects them to look like.  We do
  -- not register those ids on Gold at all, and must not paint over them.
  local BALL_PALETTES = {
    PREMIER_BALL = "PAL_KB_PREMIER",
    NEST_BALL    = "PAL_KB_NEST",
    HEAL_BALL    = "PAL_KB_HEAL",
    MIRROR_BALL  = "PAL_KB_MIRROR",
    SILPH_BALL   = "PAL_KB_SILPH",
    SNARE_BALL   = "PAL_KB_SNARE",
    CATALYST_BALL = "PAL_KB_CATALYST",
    DRIFT_BALL   = "PAL_KB_DRIFT",
    KECLEON_BALL = "PAL_KB_KECLEON",
    CRADLE_BALL  = "PAL_KB_CRADLE",
    ACE_BALL     = "PAL_KB_ACE",
  }
  do
    -- GS: the pale cream carried over from Gen 1 did not read as GOLD on
    -- device (0.4.2 report), because on Gen 1 the pale value was there to
    -- clear a collision with the native ULTRA BALL -- a constraint Gold's
    -- palette set does not have.  So: a real saturated gold on pal2, with
    -- the silver as the lighter tone above it, which is the "gold AND
    -- silver" reading the ball is named for.
    BALL_PALETTE_ROWS.PAL_KB_GS =
      { {255,255,255}, {232,236,240}, {224,168, 32}, {24,24,24} }
    BALL_PALETTE_ROWS.PAL_KB_BEAST =
      { {255,255,255}, {244,216, 72}, { 16, 24, 56}, {24,24,24} }
    BALL_PALETTES.GS_BALL = "PAL_KB_GS"
    BALL_PALETTES.BEAST_BALL = "PAL_KB_BEAST"
  end

  if GEN2 then
    -- The values half: the documented Gen 2 shape for this registry is
    -- exactly patch(<context>, { <name> = <row> }) (Schemas.lua:1666).
    mod.content.palettes:patch("battleObjects", BALL_PALETTE_ROWS)

    -- The mapping half.  Stash-originals, never a sentinel: engine module
    -- tables live for the process, so a sentinel would keep an old
    -- wrapper live across a reload and make this version look inert.
    local BattleState2 = require("src.ui.gen2.BattleState")
    BattleState2._kbOriginals = BattleState2._kbOriginals
      or { ballPalette = BattleState2.ballPalette }
    local vanillaBallPalette = BattleState2._kbOriginals.ballPalette

    -- KECLEON BALL: the ball takes the TARGET's own colours.
    --
    -- No new art and no new palette data -- the engine already has a
    -- name for exactly this.  BattleAnimView:objPalette
    -- (src/ui/gen2/BattleAnimView.lua:95-99) special-cases
    -- PAL_BATTLE_OB_ENEMY and answers it with
    -- Palettes.monColors(enemy.species, enemy.shiny), which is the wild
    -- Pokemon's own battle palette -- SHINY INCLUDED, so a shiny target
    -- gets a shiny-coloured ball for free.
    --
    -- Guarded on there actually being an enemy, because ballPalette is
    -- not only called from the throw: pokeball_colors 0.1.22+ reads it
    -- to paint the Pokemon Center heal machine, where there is no
    -- battle at all.  Returning the enemy name there would resolve to
    -- nil and draw the ball unpaletted.  With no enemy in sight it
    -- falls back to its own green-and-red, which is also what a shelf
    -- or a bag icon should show.
    local KECLEON_ID = "KECLEON_BALL"

    BattleState2.ballPalette = function(self, itemId)
      if itemId == KECLEON_ID then
        local battle = self and self.battle
        local enemy = battle and battle.enemy
        if enemy and enemy.species then return "PAL_BATTLE_OB_ENEMY" end
      end
      local name = BALL_PALETTES[itemId]
      if name then return name end
      return vanillaBallPalette(self, itemId)
    end

    -- The door for other ball mods (Custom Poke Balls, snag_quest's SNAG
    -- BALL): claim a colour without a second wrap.  Call it at
    -- game.ready.  `row` is optional -- pass one to define a new palette
    -- name, omit it to point at a name that already exists (one of the
    -- cart's six, or one of ours).  Refuses to overwrite a ball this mod
    -- owns, and refuses to redefine a row someone else already defined,
    -- so the failure mode is "your call did nothing" rather than "your
    -- call silently recoloured someone else's ball".
    mod.exports.registerBallPalette = function(ballId, paletteName, row)
      if type(ballId) ~= "string" or type(paletteName) ~= "string" then
        return false
      end
      if OWNED[ballId] then return false end
      if row then
        local game = mod.game
        local set = game and game.data and game.data.gen2Palettes
          and game.data.gen2Palettes.battleObjects
        if not set then return false end
        if set[paletteName] == nil then set[paletteName] = row end
      end
      BALL_PALETTES[ballId] = paletteName
      return true
    end
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
