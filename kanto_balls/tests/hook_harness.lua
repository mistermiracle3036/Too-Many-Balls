-- hook_harness.lua -- run the mod without a game.
--
--   luajit tests/hook_harness.lua        (from the kanto_balls folder)
--
-- WHY THIS EXISTS.  luajit -bl, `modkit gen2check` and `modkit validate`
-- are ALL static.  They passed 0.4.11 twice over: a `local CASE_ID`
-- declared below its own use compiled that use as a nil global, and the
-- Ball Case screen was pushed into a stack that was about to be cleared.
-- Neither is a syntax error, so "it compiles" was true and meaningless.
--
-- This loads main.lua against stub engine modules, runs it on BOTH
-- generations, and then actually PRESSES THE BUTTONS: every registered
-- hook is called, and the Ball Case screen is opened, moved through,
-- crafted from and closed.  A nil call anywhere in that path fails the
-- run instead of reaching a device.
--
-- Deliberately no love, no ROM, no engine checkout: ~1s, offline.

local failures, checks = {}, 0

local function check(ok, what)
  checks = checks + 1
  if not ok then failures[#failures + 1] = what end
end

local function pcheck(what, fn, ...)
  local ok, err = pcall(fn, ...)
  check(ok, what .. (ok and "" or (" -> " .. tostring(err))))
  return ok
end

--------------------------------------------------------------------- stubs

-- Every engine module main.lua requires.  Each one only needs the members
-- the mod actually touches; anything missing shows up as a nil call, which
-- is the entire point of the exercise.
local function engineStubs(generation)
  local Bag = {
    add = function(save, id, qty)
      save.inventory[id] = (save.inventory[id] or 0) + (qty or 1)
      return true
    end,
    remove = function(save, id, qty)
      local left = (save.inventory[id] or 0) - (qty or 1)
      save.inventory[id] = left > 0 and left or nil
    end,
    capacity = function(_, pocket) return pocket == "BALL" and 12 or 20 end,
    slots = function() return 0 end,
    pocketOf = function() return "ITEM" end,
  }
  local pushed = {}
  return {
    ["src.inventory.Bag"] = Bag,
    ["src.mods.Runtime"] = {
      reportError = function(id, msg) return id, msg end,
      emit = function() end,
    },
    ["src.core.GameVersion"] = {
      generation = function() return generation end,
    },
    ["src.inventory.ItemEffects"] = { BALLS = {} },
    ["src.pokemon.Pokemon"] = {
      heal = function(mon) mon.hp = 999 end,
    },
    ["src.battle.BattleState"] = {
      ballMissMessage = function() return "vanilla miss" end,
    },
    ["src.ui.gen2.Chrome"] = {
      box = function() end, print = function() end, cursor = function() end,
    },
    ["src.ui.Screens"] = {
      push = function(game, id) pushed[#pushed + 1] = id return {} end,
      _pushed = pushed,
    },
    -- Gold's battle screen: the mod wraps ballPalette on it
    ["src.ui.gen2.BattleState"] = {
      ballPalette = function() return "PAL_BATTLE_OB_GRAY" end,
    },
    ["src.world.gen2.World"] = { useFieldItem = function() return nil end },
    -- Kurt's handover reads the badge through the engine's own helper
    ["src.world.gen2.FieldMoves"] = {
      hasBadge = function(save, badge)
        local owned = save and save.player and save.player.badges
        return (owned and owned[badge]) and true or false
      end,
    },
    ["src.core.Game2"] = { update = function() end },
    ["src.ui.gen2.MartMenu"] = {
      completePurchase = function(self) self.message = { pages = {} } end,
    },
  }
end

-- The mod API surface, capturing everything the mod registers so the
-- harness can call it back.
local function makeModApi(options)
  local rec = {
    options = options or {},
    events = {}, hooks = {}, registries = {}, exports = {},
    screens = {}, logged = {},
  }
  local function registry(name)
    rec.registries[name] = rec.registries[name] or {}
    local store = rec.registries[name]
    return {
      register = function(_, id, value)
        if name == "screens" then rec.screens[id] = value end
        store[id] = value
      end,
      patch = function(_, id, value) store[id] = value end,
      override = function(_, id, value) store[id] = value end,
      remove = function(_, id) store[id] = nil end,
    }
  end
  local content = setmetatable({}, {
    __index = function(t, name)
      local r = registry(name)
      rawset(t, name, r)
      return r
    end,
  })
  local mod = {
    content = content,
    exports = rec.exports,
    options = {
      define = function(_, rows) rec.optionRows = rows end,
      get = function(_, key) return rec.options[key] end,
    },
    events = {
      on = function(_, name, fn)
        rec.events[name] = rec.events[name] or {}
        table.insert(rec.events[name], fn)
      end,
    },
    hooks = {
      wrap = function(_, name, fn) rec.hooks[name] = fn end,
    },
    log = {
      info = function(_, ...) rec.logged[#rec.logged + 1] = { ... } end,
      warn = function(_, ...) rec.logged[#rec.logged + 1] = { ... } end,
    },
    find = function() return nil end,
    -- Real storage: the once-only guard on Kurt's handover is only
    -- meaningful if get/set actually round-trip.
    save = {
      get = function(_, key) return rec.saveStore[key] end,
      set = function(_, key, value) rec.saveStore[key] = value end,
    },
  }
  rec.saveStore = {}
  -- mod.game and mod.world are metatable reads in the real API
  -- (src/mods/Loader.lua), so they are here too -- and mod.game must be
  -- swappable mid-test, which is what rec.modGame is for.
  rec.queued = {}
  setmetatable(mod, { __index = function(_, key)
    if key == "game" then return rec.modGame end
    if key == "world" then
      return {
        queueScript = function(_, rows)
          rec.queued[#rec.queued + 1] = rows
          return true
        end,
      }
    end
    return nil
  end })
  return mod, rec
end

local function fakeGame()
  return {
    data = {
      items = {}, pokemon = {},
      gen2Marts = { lists = { { "POKE_BALL", "GREAT_BALL", "ULTRA_BALL" } } },
      gen2Palettes = { battleObjects = {} },
      text = {},
    },
    save = { inventory = {}, party = {}, pokedex = { caught = {}, seen = {} } },
    stack = { pop = function() end, push = function() end },
    input = { wasPressed = function(_, key) return key == _G.__PRESS end },
  }
end

local function loadMod(generation, options)
  local stubs = engineStubs(generation)
  local realRequire = require
  _G.require = function(name)
    local stub = stubs[name]
    if stub then return stub end
    return realRequire(name)
  end
  local chunk = assert(loadfile("main.lua"))
  local entry = chunk()
  local mod, rec = makeModApi(options)
  local ok, err = pcall(entry, mod)
  _G.require = realRequire
  rec.stubs = stubs
  return ok, err, rec
end

--------------------------------------------------------------- the passes

for _, gen in ipairs({ 1, 2 }) do
  for _, cheap in ipairs({ false, true }) do
    local label = ("gen%d cheap=%s"):format(gen, tostring(cheap))
    local ok, err, rec = loadMod(gen, { cheap_balls = cheap })
    check(ok, label .. " entry chunk -> " .. tostring(err))
    if ok then
      -- every ball that got an items record must also have a colour, or
      -- Pokeball Colors warns and the ball throws grey
      local items = rec.registries.items or {}
      check(next(items) ~= nil, label .. " registered no items")

      -- game.ready listeners: the pocket stamp, the shelves, the colours
      local game = fakeGame()
      for id in pairs(items) do
        game.data.items[id] = { id = id, price = 1 }
      end
      for _, fn in ipairs(rec.events["game.ready"] or {}) do
        pcheck(label .. " game.ready", fn, { game = game })
      end

      -- THE POCKET STAMP -- the 0.4.11 bug, caught here by asserting the
      -- outcome rather than trusting the code path ran.
      if gen == 2 then
        for id in pairs(items) do
          local def = game.data.items[id]
          local want = (id == "BALL_CASE") and "KEY_ITEM" or "BALL"
          check(def.pocket == want,
            ("%s %s pocket=%s want %s")
              :format(label, id, tostring(def.pocket), want))
        end
      end

      -- pokemon.caught: HEAL restores, the mark gets written
      for _, fn in ipairs(rec.events["pokemon.caught"] or {}) do
        pcheck(label .. " pokemon.caught", fn,
          { ball = "HEAL_BALL", mon = { hp = 1, stats = { hp = 20 },
            moves = {}, status = "SLP" }, species = "PIDGEY", game = game })
      end

      -- shop.purchased: the Premier award path
      for _, fn in ipairs(rec.events["shop.purchased"] or {}) do
        pcheck(label .. " shop.purchased", fn,
          { id = "POKE_BALL", qty = 10, game = game,
            save = game.save, data = game.data })
      end

      -- every Gen 1 ball's attempt(), including the ones that replace
      -- the roll outright.
      --
      -- These two loops used to CALL the catch code and assert nothing
      -- about the result -- "it did not crash" and no more. A ball whose
      -- multiplier silently did nothing passed both. So KECLEON, whose
      -- whole 0.4.24 change is a multiplier, is checked by OUTCOME on
      -- both generations: the rate must actually move, and move by the
      -- same factor on each, or the two can drift apart unnoticed.
      local KECLEON_MULT = 1.5
      local BASE_RATE = 45
      local sawGen1Kecleon = false
      for id, record in pairs(rec.registries.balls or {}) do
        if type(record) == "table" and record.attempt then
          local ctx = {
            targetMon = { level = 10, species = "PIDGEY", status = "SLP",
                          hp = 5 },
            targetDef = { catchRate = BASE_RATE, baseStats = { speed = 100 },
                          evolutions = {} },
            rateOverride = nil,
            battle = { player = { mon = { species = "PIDGEY" } } },
            rng = function() return 1 end,
            vanillaAttempt = function() return true, 3 end,
          }
          pcheck(label .. " attempt " .. id, record.attempt, ctx)
          if id == "KECLEON_BALL" then
            sawGen1Kecleon = true
            check(ctx.rateOverride == BASE_RATE * KECLEON_MULT,
              ("%s KECLEON gen1 rate is %s, expected %s")
                :format(label, tostring(ctx.rateOverride),
                        tostring(BASE_RATE * KECLEON_MULT)))
          end
        end
      end
      if gen == 1 then
        check(sawGen1Kecleon,
          label .. " KECLEON registered no gen1 attempt -- the buff is gone")
      end

      -- the Gen 2 catch.rate wrap, once per ball we own
      local hook = rec.hooks["catch.rate"]
      if gen == 2 then
        check(hook ~= nil, label .. " registered no catch.rate hook")
      end
      if hook then
        local sawGen2Kecleon = false
        for _, ball in ipairs(rec.exports.balls or {}) do
          local o = { catchRate = BASE_RATE, level = 10, species = "PIDGEY",
                      playerSpecies = "PIDGEY", status = "sleep",
                      random = function() return 0 end }
          pcheck(label .. " catch.rate " .. ball, hook,
            function() return false, 1 end, ball, nil, nil, o)
          if ball == "KECLEON_BALL" then
            sawGen2Kecleon = true
            -- The hook mutates o.catchRate in place; the engine reads it
            -- back out (Catching.lua:279).  UNCONDITIONAL, so no state
            -- in `o` can excuse it not having moved.
            --
            -- FLOORED here and not on Gen 1, which is correct for both:
            -- boostFlat floors because Gold's own multiply does
            -- (Catching.lua:279), while Gen 1's boost leaves the
            -- fraction alone because stockAttempt floors it downstream
            -- inside the wobble maths (src/battle/Catching.lua:62).
            -- 67 vs 67.5 is that difference and nothing more; the two
            -- generations are kept honest by sharing KECLEON_MULT, not
            -- by landing on the same byte.
            local want = math.floor(BASE_RATE * KECLEON_MULT)
            check(o.catchRate == want,
              ("%s KECLEON gen2 rate is %s, expected %s")
                :format(label, tostring(o.catchRate), tostring(want)))
          end
        end
        if gen == 2 then
          check(sawGen2Kecleon,
            label .. " KECLEON absent from exports.balls on gen 2")
        end
      end

      -- exports other mods are promised
      check(type(rec.exports.requestBallSlots) == "function",
        label .. " requestBallSlots missing")
      if gen == 2 then
        check(type(rec.exports.registerBallPalette) == "function",
          label .. " registerBallPalette missing")
      end

      ------------------------------------------- LOCKED RECIPES
      -- The cross-mod unlock gate (save.recipeUnlocks).  ChatGPT could
      -- not test the UNLOCKED half -- the default harness supplies no
      -- unlocks -- so this is the half that was never exercised, which
      -- is exactly where a gate goes wrong.
      if gen == 2 then
        local factory = rec.screens.KbBallCase
        local newFn = factory and ((type(factory) == "function") and factory
          or factory.new)
        if newFn then
          local function rowsWith(unlocks)
            local g = fakeGame()
            g.save.recipeUnlocks = unlocks
            local ok, s = pcall(newFn, g)
            if not (ok and s) then return nil end
            return s:rows(), g
          end

          local lockedRows = rowsWith(nil)
          check(lockedRows ~= nil, label .. " case failed with no unlocks")
          local unlockedRows = rowsWith({ ["route_aces:ace_ball"] = true })
          check(unlockedRows ~= nil, label .. " case failed with an unlock")

          if lockedRows and unlockedRows then
            local function hasAce(rows)
              for _, r in ipairs(rows) do
                if r.kind == "recipe" and r.recipe.id == "ACE_BALL" then
                  return true
                end
              end
              return false
            end
            check(not hasAce(lockedRows),
              label .. " ACE BALL is visible while LOCKED")
            check(hasAce(unlockedRows),
              label .. " ACE BALL stayed hidden after its unlock")
            check(#unlockedRows == #lockedRows + 1,
              label .. " unlocking changed the row count by more than one")

            -- An unlock nobody has a recipe for must be inert, and a
            -- garbage value must not read as unlocked.
            local junkRows = rowsWith({ ["nobody:nothing"] = true })
            check(junkRows and #junkRows == #lockedRows,
              label .. " an unrelated unlock key changed the list")
            local falseRows = rowsWith({ ["route_aces:ace_ball"] = false })
            check(falseRows and not hasAce(falseRows),
              label .. " a false unlock value counted as unlocked")

            -- And the gate must hold in craft(), not just in the list:
            -- hiding a row is not the same as refusing to make it.
            local g = fakeGame()
            g.save.recipeUnlocks = nil
            for _, id in ipairs({ "WHT_APRICORN", "BLU_APRICORN" }) do
              g.save.inventory[id] = 9
            end
            local aceRecipe
            for _, r in ipairs(unlockedRows) do
              if r.kind == "recipe" and r.recipe.id == "ACE_BALL" then
                aceRecipe = r.recipe
              end
            end
            check(aceRecipe ~= nil, label .. " could not find the ACE recipe")
            if aceRecipe and rec.exports.craftForTest then
              -- only if the mod ever exposes it; otherwise the row-level
              -- assertions above are the coverage
              rec.exports.craftForTest(g.save, g.data, aceRecipe)
              check((g.save.inventory.ACE_BALL or 0) == 0,
                label .. " craft() made a LOCKED recipe")
            end
          end
        end
      end

      -------------------------------------------- KECLEON'S PALETTE
      -- The ball's whole effect is here, so it is worth asserting in
      -- both directions: the target's own palette name in a battle, and
      -- its OWN colours when there is no enemy to copy (the heal
      -- machine calls this too, and a nil there draws unpaletted).
      if gen == 2 then
        local BS2 = rec.stubs["src.ui.gen2.BattleState"]
        local inBattle = { battle = { enemy = { species = "KECLEON" } } }
        check(BS2.ballPalette(inBattle, "KECLEON_BALL")
                == "PAL_BATTLE_OB_ENEMY",
          label .. " KECLEON did not take the target's palette")
        check(BS2.ballPalette({}, "KECLEON_BALL") == "PAL_KB_KECLEON",
          label .. " KECLEON has no fallback without an enemy")
        -- and it must not have hijacked anyone else's colour
        check(BS2.ballPalette(inBattle, "SNARE_BALL") == "PAL_KB_SNARE",
          label .. " KECLEON's rule leaked onto another ball")
        check(BS2.ballPalette(inBattle, "MOON_BALL")
                == "PAL_BATTLE_OB_GRAY",
          label .. " wrap swallowed a native ball's palette")
      end

      ------------------------------------------------- KURT'S HANDOVER
      -- The gate is "Kurt gave you something", read as a bag diff across
      -- his conversation.  Modelled here exactly as the probe saw it on
      -- the running game (0.4.19):
      --   first meeting -> he walks out and gives NOTHING
      --   the return    -> he hands over a LURE BALL and stays
      if gen == 2 then
        local started = rec.events["script.started"] or {}
        local ended = rec.events["script.ended"] or {}
        check(#started > 0, label .. " no script.started listener")
        check(#ended > 0, label .. " no script.ended listener")
        local KEY = "55:45e3"

        -- Run one Kurt conversation. `gift` is what he hands over during
        -- it, or nil for a conversation that gives nothing.
        local function kurtTalk(game, key, gift, completed)
          rec.modGame = game
          for _, fn in ipairs(started) do
            pcheck(label .. " kurt start", fn, { ctx = { scriptKey = key } })
          end
          if gift then
            game.save.inventory[gift] = (game.save.inventory[gift] or 0) + 1
          end
          for _, fn in ipairs(ended) do
            pcheck(label .. " kurt end", fn,
              { ctx = { scriptKey = key },
                completed = completed ~= false })
          end
        end

        -- THE FIRST MEETING: he gives nothing and leaves.  This is the
        -- bug reported on device at 0.4.14 and it must never pass.
        local firstMeeting = fakeGame()
        kurtTalk(firstMeeting, KEY, nil)
        check(firstMeeting.save.inventory.BALL_CASE == nil,
          label .. " KURT GAVE THE CASE ON THE FIRST MEETING")

        -- THE RETURN: he hands over the LURE BALL for the rescue.
        local rescue = fakeGame()
        kurtTalk(rescue, KEY, "LURE_BALL")
        check(rescue.save.inventory.BALL_CASE == 1,
          label .. " KURT DID NOT GIVE THE CASE ON HIS RETURN")

        -- ...and only ever once, however many gifts follow.
        kurtTalk(rescue, KEY, "MOON_BALL")
        kurtTalk(rescue, KEY, "FAST_BALL")
        check(rescue.save.inventory.BALL_CASE == 1,
          ("%s kurt gave %s cases, want exactly 1")
            :format(label, tostring(rescue.save.inventory.BALL_CASE)))

        -- THE CODA MUST NOT BE SPOKEN INSIDE script.ended.
        -- Reported from device at 0.4.20: both lines flashed past,
        -- because the box went up while the VM was still unwinding and
        -- the player's A press from Kurt's own dialogue was still in
        -- flight.  It is now deferred until World:busy() is false, and
        -- these assertions are what stop it drifting back.
        check(#rec.queued == 0,
          label .. " CODA SPOKE IMMEDIATELY, it must wait for a quiet world")

        local Game2Stub = rec.stubs["src.core.Game2"]
        local busyWorld = { busy = function() return true end }
        local calmWorld = { busy = function() return false end }

        pcheck(label .. " coda held while busy", Game2Stub.update,
          { world = busyWorld }, 0.016)
        check(#rec.queued == 0,
          label .. " CODA FIRED INTO A BUSY WORLD")

        pcheck(label .. " coda drains when calm", Game2Stub.update,
          { world = calmWorld }, 0.016)
        check(#rec.queued == 1,
          ("%s coda did not speak on a quiet frame (queued %d)")
            :format(label, #rec.queued))

        -- ...and only once, not every frame thereafter.
        pcheck(label .. " coda not repeated", Game2Stub.update,
          { world = calmWorld }, 0.016)
        check(#rec.queued == 1,
          label .. " CODA REPEATED on later frames")

        -- Every line must fit the box: two lines of <= 18 columns.
        -- An over-length line soft-wraps and SCROLLS rather than
        -- clipping, which is the other half of "too fast".
        for _, rows in ipairs(rec.queued) do
          for _, row in ipairs(rows) do
            if row[1] == "text" then
              for line in tostring(row[2]):gmatch("[^\n]+") do
                check(#line <= 18,
                  ("%s coda line is %d cols (max 18): %s")
                    :format(label, #line, line))
              end
            end
          end
        end

        -- Another NPC handing over an item must never trigger it.
        local otherNpc = fakeGame()
        kurtTalk(otherNpc, "55:0000", "POTION")
        check(otherNpc.save.inventory.BALL_CASE == nil,
          label .. " another NPC handed over the case")

        -- An ABANDONED conversation must not count, even with a gift:
        -- completed=false is a whiteout or a script that died.
        local abandoned = fakeGame()
        kurtTalk(abandoned, KEY, "LURE_BALL", false)
        check(abandoned.save.inventory.BALL_CASE == nil,
          label .. " an abandoned conversation handed over the case")
      end

      ----------------------------------------------- THE DEFERRED PUSH
      -- Regression test for the second 0.4.11 bug.  PackMenu clears the
      -- WHOLE stack right after useFieldItem returns truthy, so pushing
      -- the screen inline built and destroyed it in one breath.  The
      -- contract is therefore precise: useFieldItem must claim the item
      -- WITHOUT pushing, and the push must happen on the next Game2
      -- update.  Assert both halves, or a future edit can quietly move
      -- the push back inline and look fine.
      if gen == 2 then
        local WorldStub = rec.stubs["src.world.gen2.World"]
        local Game2Stub = rec.stubs["src.core.Game2"]
        local Screens = rec.stubs["src.ui.Screens"]
        local pushed = Screens._pushed
        for i = #pushed, 1, -1 do pushed[i] = nil end

        local worldSelf = { game = game }
        local claimed = select(2, pcall(WorldStub.useFieldItem,
          worldSelf, "BALL_CASE"))
        check(claimed ~= nil, label .. " useFieldItem did not claim the case")
        check(#pushed == 0,
          label .. " PUSHED INLINE -- the stack clear will eat it")

        pcheck(label .. " Game2.update flush", Game2Stub.update, game, 0.016)
        check(#pushed == 1 and pushed[1] == "KbBallCase",
          label .. " deferred push did not open the case")

        -- and an unrelated item must still reach vanilla
        local passed = select(2, pcall(WorldStub.useFieldItem,
          worldSelf, "BICYCLE"))
        check(passed == nil,
          label .. " wrap swallowed an item it does not own")
      end

      ------------------------------------------------------ THE BALL CASE
      -- The part no static check can see: open the screen and press
      -- every button on it.
      if gen == 2 then
        local factory = rec.screens.KbBallCase
        check(factory ~= nil, label .. " no KbBallCase screen registered")
        if factory then
          local newFn = (type(factory) == "function") and factory
            or factory.new
          check(type(newFn) == "function", label .. " screen has no new()")
          if type(newFn) == "function" then
            -- Stock every apricorn generously: the harness must not
            -- assume WHICH recipes exist or what order they sit in.
            -- Hard-coding SNARE's inputs here is what broke this test
            -- the moment the craft tier reordered the rows -- correctly,
            -- but the assertion should have been about "a recipe", not
            -- about that recipe.
            local APRICORNS = { "RED_APRICORN", "BLU_APRICORN",
              "YLW_APRICORN", "GRN_APRICORN", "WHT_APRICORN",
              "BLK_APRICORN", "PNK_APRICORN" }
            local function apricornTotal(save)
              local n = 0
              for _, id in ipairs(APRICORNS) do
                n = n + (save.inventory[id] or 0)
              end
              return n
            end
            for _, id in ipairs(APRICORNS) do
              game.save.inventory[id] = 9
            end

            local okNew, screen = pcall(newFn, game)
            check(okNew and screen ~= nil,
              label .. " screen new() -> " .. tostring(screen))
            if okNew and screen then
              for _, key in ipairs({ "down", "up", "a", "b" }) do
                _G.__PRESS = key
                pcheck(label .. " case update " .. key, screen.update, screen)
                pcheck(label .. " case draw after " .. key,
                  screen.draw, screen)
              end
              _G.__PRESS = nil

              -- EVERY row must craft: walk them all, and for each one
              -- assert a ball appeared and apricorns were spent.  This
              -- is what catches a recipe whose inputs name an item id
              -- that does not exist, which no static check can see.
              local rowCount = 0
              local s = select(2, pcall(newFn, game))
              if s then
                local rows = s:rows()
                rowCount = #rows
                check(rowCount >= 1, label .. " case lists no rows")
                -- Rows are TAGGED now (kind = recipe|stow|take|cancel).
                -- Craft only the recipe rows; the action rows have their
                -- own assertions below.
                -- THE MESSAGE BOX IS 20 WIDE WITH BORDERS, so 18
                -- columns of text, and an over-length line does not
                -- clip -- it soft-wraps and scrolls, which is what the
                -- coda assertion above already exists to stop.  The
                -- craft line interpolates a ball NAME, so it is the one
                -- message that grows every time a recipe is added:
                -- "Made a CATALYST BALL!" was 21 and shipped that way.
                -- Checked after EVERY press, not just the crafts.
                local msgSeen = 0
                local function checkMessage(what)
                  local m = s.message
                  if not m then return end
                  msgSeen = msgSeen + 1
                  check(#m <= 3,
                    ("%s %s message is %d lines (box fits 3)")
                      :format(label, what, #m))
                  for _, line in ipairs(m) do
                    check(#line <= 18,
                      ("%s %s message line is %d cols (max 18): %s")
                        :format(label, what, #line, line))
                  end
                end

                local recipeRows, sawStow, sawTake, sawCancel = 0, false, false, false
                for i, row in ipairs(rows) do
                  if row.kind == "stow" then sawStow = true end
                  if row.kind == "take" then sawTake = true end
                  if row.kind == "cancel" then sawCancel = true end
                  if row.kind == "recipe" then
                    recipeRows = recipeRows + 1
                    local recipe = row.recipe
                    s.index = i
                    s.message = nil
                    local before = apricornTotal(game.save)
                    local hadBall = game.save.inventory[recipe.id] or 0
                    _G.__PRESS = "a"
                    pcheck(label .. " craft " .. tostring(recipe.id),
                      s.update, s)
                    _G.__PRESS = nil
                    check((game.save.inventory[recipe.id] or 0) > hadBall,
                      label .. " craft made no " .. tostring(recipe.id))
                    check(apricornTotal(game.save) < before,
                      label .. " craft spent no apricorns for "
                        .. tostring(recipe.id))
                    checkMessage("craft " .. tostring(recipe.id))
                  end
                end
                check(recipeRows >= 1, label .. " case lists no recipes")
                check(sawStow and sawTake and sawCancel,
                  label .. " case is missing STOW/TAKE/CANCEL rows")

                -- EVERY ROW MUST FIT INSIDE THE BOX, and this assertion
                -- has now caught the same class of bug twice.
                -- Font.drawBox borders at ty + th - 1
                -- (src/render/Font.lua:549), so a 12-tall box at y=0 has
                -- interior rows 1..10 -- NOT 1..11.  Rows start at y=2
                -- with stride 1, so the last row is 2 + (n - 1) and it
                -- must be <= 10, i.e. at most NINE rows.
                local CASE_FIRST_ROW, CASE_LAST_INTERIOR = 2, 10
                check(CASE_FIRST_ROW + (rowCount - 1) <= CASE_LAST_INTERIOR,
                  ("%s %d rows overflow the case box (last y=%d, max %d)")
                    :format(label, rowCount,
                            CASE_FIRST_ROW + (rowCount - 1),
                            CASE_LAST_INTERIOR))

                ------------------------------------------ STOW / TAKE
                local function rowIndex(kind)
                  for i, r in ipairs(s:rows()) do
                    if r.kind == kind then return i end
                  end
                end
                local function press(kind)
                  s.index = rowIndex(kind)
                  s.message = nil
                  _G.__PRESS = "a"
                  pcheck(label .. " case " .. kind, s.update, s)
                  _G.__PRESS = nil
                  checkMessage(kind)
                end

                local ballsBefore = 0
                for _, id in ipairs(rec.exports.balls or {}) do
                  ballsBefore = ballsBefore + (game.save.inventory[id] or 0)
                end
                check(ballsBefore > 0,
                  label .. " nothing was crafted to stow")

                press("stow")
                local leftInBag = 0
                for _, id in ipairs(rec.exports.balls or {}) do
                  leftInBag = leftInBag + (game.save.inventory[id] or 0)
                end
                check(leftInBag == 0,
                  label .. " STOW left balls in the bag")
                -- apricorns must NOT be stowed: they are vanilla items
                check(apricornTotal(game.save) > 0,
                  label .. " STOW took the apricorns too")
                -- and neither may the case itself, or it strands them
                check(game.save.inventory.BALL_CASE == nil
                        or game.save.inventory.BALL_CASE > 0,
                  label .. " STOW swallowed the BALL CASE")

                press("take")
                local backInBag = 0
                for _, id in ipairs(rec.exports.balls or {}) do
                  backInBag = backInBag + (game.save.inventory[id] or 0)
                end
                check(backInBag == ballsBefore,
                  ("%s TAKE BACK returned %d of %d")
                    :format(label, backInBag, ballsBefore))

                -- THE ONE THAT COSTS REAL ITEMS: a full pocket must
                -- return what fits and keep the rest, losing nothing.
                press("stow")
                local vanillaAdd = rec.stubs["src.inventory.Bag"].add
                rec.stubs["src.inventory.Bag"].add = function() return false end
                press("take")
                rec.stubs["src.inventory.Bag"].add = vanillaAdd
                local stranded = 0
                for _, id in ipairs(rec.exports.balls or {}) do
                  stranded = stranded + (game.save.inventory[id] or 0)
                end
                check(stranded == 0,
                  label .. " TAKE BACK added into a full pocket")
                press("take")
                local recovered = 0
                for _, id in ipairs(rec.exports.balls or {}) do
                  recovered = recovered + (game.save.inventory[id] or 0)
                end
                check(recovered == ballsBefore,
                  ("%s FULL POCKET LOST BALLS: %d of %d came back")
                    :format(label, recovered, ballsBefore))

                -- COUNT, not just contents.  checkMessage returns early
                -- on a nil message, so if a press ever stopped setting
                -- one the width check would pass by inspecting nothing.
                -- One per recipe crafted, plus the five action presses
                -- above (stow, take, stow, take-into-full, take).
                check(msgSeen >= recipeRows + 5,
                  ("%s only %d messages checked, expected >= %d")
                    :format(label, msgSeen, recipeRows + 5))
              end

              -- THE FAILURE PATH THAT COSTS MATERIALS: a full pocket must
              -- consume nothing.
              local full = fakeGame()
              full.data.items = game.data.items
              for _, id in ipairs(APRICORNS) do
                full.save.inventory[id] = 9
              end
              local stocked = apricornTotal(full.save)
              rec.stubs["src.inventory.Bag"].add = function() return false end
              local okFull, s2 = pcall(newFn, full)
              if okFull and s2 then
                -- try EVERY recipe against a full pocket, not just one
                for i = 1, math.max(1, rowCount) do
                  s2.index = i
                  s2.message = nil
                  _G.__PRESS = "a"
                  pcheck(label .. " case craft when pack full",
                    s2.update, s2)
                  _G.__PRESS = nil
                end
                check(apricornTotal(full.save) == stocked,
                  label .. " FULL POCKET ATE THE APRICORNS")
              end
            end
          end
        end
      end
    end
  end
end

--------------------------------------------------------------------- report

print(("hook_harness: %d checks, %d failures"):format(checks, #failures))
for _, f in ipairs(failures) do print("  FAIL " .. f) end
os.exit(#failures == 0 and 0 or 1)
