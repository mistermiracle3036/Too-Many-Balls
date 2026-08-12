-- Shop Events -- library mod
--
-- The engine has no "player bought something" event: ShopMenu's buy()
-- is a local function (src/ui/ShopMenu.lua), so nothing can hook it.
--
-- WHAT THIS DETECTS FROM (verified against engine 0.1.75; Gold half
-- against 0.1.78):
--   Gen 1: the one and only Sound.play(data, "Purchase") call site in
--   the whole engine is the mart buy path (ShopMenu.lua:75), fired
--   after the money check and AFTER the item has landed in the bag.
--   So that sound alone proves "a purchase just completed".
--   Gen 2 (Gold): the mart is a different screen entirely
--   (src/ui/gen2/MartMenu.lua) but the shape holds -- completePurchase
--   runs the same shared Bag.add(save, id, qty, data) (line 682), then
--   playTransaction rings Sound.play(data, "Sfx_Transaction") through
--   the same shared Sound module (line 670).  So both wraps below work
--   unchanged on Gold; the only difference is the sound's NAME, and
--   that Gold's till rings for SELLS too (PlayTransactionSound is the
--   money changing hands, either direction) -- which is why an empty
--   inventory diff on Gen 2 is a sell, not a failure (see below).
--
-- WHAT IT BUYS -- inventory diffing, not a Bag.add wrap:
--   0.1.0-0.1.2 learned the item/qty by wrapping Bag.add.  On the user's
--   device that wrap never fired even though ShopMenu indexes Bag.add at
--   call time -- almost certainly another installed mod re-wrapping
--   Bag.add from a stale stashed original and orphaning ours.  We cannot
--   police other mods' wraps, so we stopped depending on one.
--
--   Instead: keep a snapshot of save.inventory refreshed on every OTHER
--   sound (menu presses fire "Press_AB", so a fresh snapshot always
--   exists from just before the confirm), and on "Purchase" diff the
--   live inventory against it.  Whatever went up is what was bought.
--   This works no matter who else wraps what.
--
-- The Bag.add wrap is kept as a fast path when it does work; the diff is
-- the source of truth and covers it when it does not.
--
-- Event: Runtime.emit("shop.purchased", { id, qty, game, save, data })
--
-- Diagnostics: with the DEBUG option ON, stages are reported through
-- Runtime.reportError, which appends to the SAME list the mod manager's
-- [ERRS] screen renders.  mod.log:info goes to a console that does not
-- exist on iOS, so these are the only diagnostics the user can see.
-- They are notices, not failures.

return function(mod)
  local VERSION = "0.4.6"
  mod.exports.version = VERSION
  mod.exports.owns = { shop_events = true }

  -- Fixed for the whole run (the loader's own call, Loader.lua:242);
  -- only used to keep a Gold sell from reading as a broken purchase.
  local GEN2 = require("src.core.GameVersion").generation() == 2

  -- The two till sounds, one per generation.  "Purchase" is Gen 1's
  -- (ShopMenu.lua:75); "Sfx_Transaction" is Gold's (MartMenu.lua:670,
  -- PlayTransactionSound).  Sound.GEN2_ALIASES maps "Purchase" onto the
  -- Gold label for CALLERS, but a wrap sees the literal name each call
  -- site passed, so both spellings must match here.
  local PURCHASE_SOUNDS = { Purchase = true, Sfx_Transaction = true }

  local Bag = require("src.inventory.Bag")
  local Sound = require("src.core.Sound")
  local Runtime = require("src.mods.Runtime")


  mod.options:define({
    { key = "debug", type = "toggle",
      label = "Show purchase diagnostics", default = true },
  })
  local function dbg(fmt, ...)
    local msg = string.format(fmt, ...)
    mod.log:info(msg)
    -- visible on-device: lands in MOD MANAGER -> [ERRS]
    if mod.options:get("debug") then
      pcall(Runtime.reportError, "shop_events", msg)
    end
  end

  -- fast path (when our Bag.add wrap survives other mods) and the
  -- snapshot the diff falls back on
  local state = { pending = nil, game = nil, emitting = false,
                  snapshot = nil }

  local function inventoryOf()
    local g = state.game
    return g and g.save and g.save.inventory or nil
  end

  local function snapshot()
    local inv = inventoryOf()
    if not inv then return nil end
    local copy = {}
    for id, n in pairs(inv) do copy[id] = n end
    return copy
  end

  -- what went UP since the snapshot: that is what was just bought
  local function diffGained(before)
    local inv = inventoryOf()
    if not inv then return nil end
    local gained = {}
    for id, n in pairs(inv) do
      local was = (before and before[id]) or 0
      if type(n) == "number" and n > was then
        gained[#gained + 1] = { id = id, qty = n - was }
      end
    end
    return gained
  end

  -- hot-reload-safe: stash originals once, always rebuild from them
  Bag._seOriginals = Bag._seOriginals or { add = Bag.add }
  local vanillaAdd = Bag._seOriginals.add
  Bag.add = function(save, id, qty, data)
    local ok = vanillaAdd(save, id, qty, data)
    if ok and not state.emitting then
      state.pending = { id = id, qty = qty or 1, save = save, data = data }
    end
    return ok
  end

  local function emitPurchase(id, qty, save, data, how)
    state.emitting = true
    local ok, err = pcall(Runtime.emit, "shop.purchased",
      { id = id, qty = qty, game = state.game,
        save = save or (state.game and state.game.save),
        data = data or (state.game and state.game.data) })
    state.emitting = false
    dbg("emitted %s x%d (%s)", tostring(id), qty, how)
    if not ok then
      mod.log:warn("shop.purchased listener error: %s", tostring(err))
    end
  end

  Sound._seOriginals = Sound._seOriginals or { play = Sound.play }
  local vanillaPlay = Sound._seOriginals.play
  Sound.play = function(data, name)
    if PURCHASE_SOUNDS[name] then
      local before = state.snapshot
      local p = state.pending
      state.pending = nil
      if p then
        emitPurchase(p.id, p.qty, p.save, p.data, "bag wrap")
      else
        local gained = diffGained(before)
        if gained and #gained > 0 then
          for _, g in ipairs(gained) do
            emitPurchase(g.id, g.qty, nil, nil, "inventory diff")
          end
        elseif gained and GEN2 then
          -- Gold's till rings on SELLS too, and a sell gains nothing --
          -- expected, not a broken snapshot.  Stay silent so the [ERRS]
          -- screen does not fill up every time the player sells a berry.
        else
          dbg("purchase seen but nothing gained -- no snapshot?")
        end
      end
      state.snapshot = snapshot()
    elseif not state.emitting then
      -- every other sound refreshes the pre-purchase baseline; menu
      -- confirms fire Press_AB, so this is always fresh.  It also
      -- CLEARS the fast-path pending: a Bag.add that was a real mart
      -- buy is followed by the till in the SAME callback with no sound
      -- between (ShopMenu.lua:75; MartMenu completePurchase), so a
      -- pending that survives to another sound was a script gift or a
      -- pickup -- and on Gold, where the till also rings on sells,
      -- letting it linger would emit that gift as a "purchase" the
      -- next time the player sold something.
      state.pending = nil
      state.snapshot = snapshot()
    end
    return vanillaPlay(data, name)
  end

  -- payload.game for listeners; captured once the game exists
  mod.events:on("game.ready", function(p)
    state.game = p.game
    state.snapshot = snapshot()
  end)

  dbg("loaded %s (gen %d); Bag.add and Sound.play wrapped",
    VERSION, GEN2 and 2 or 1)
end
