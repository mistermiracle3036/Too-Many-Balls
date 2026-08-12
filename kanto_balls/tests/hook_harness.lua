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
    save = { get = function() end, set = function() end },
  }
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
      -- the roll outright
      for id, record in pairs(rec.registries.balls or {}) do
        if type(record) == "table" and record.attempt then
          pcheck(label .. " attempt " .. id, record.attempt, {
            targetMon = { level = 10, species = "PIDGEY", status = "SLP",
                          hp = 5 },
            targetDef = { catchRate = 45, baseStats = { speed = 100 },
                          evolutions = {} },
            rateOverride = nil,
            battle = { player = { mon = { species = "PIDGEY" } } },
            rng = function() return 1 end,
            vanillaAttempt = function() return true, 3 end,
          })
        end
      end

      -- the Gen 2 catch.rate wrap, once per ball we own
      local hook = rec.hooks["catch.rate"]
      if gen == 2 then
        check(hook ~= nil, label .. " registered no catch.rate hook")
      end
      if hook then
        for _, ball in ipairs(rec.exports.balls or {}) do
          pcheck(label .. " catch.rate " .. ball, hook,
            function() return false, 1 end, ball, nil, nil,
            { catchRate = 45, level = 10, species = "PIDGEY",
              playerSpecies = "PIDGEY", status = "sleep",
              random = function() return 0 end })
        end
      end

      -- exports other mods are promised
      check(type(rec.exports.requestBallSlots) == "function",
        label .. " requestBallSlots missing")
      if gen == 2 then
        check(type(rec.exports.registerBallPalette) == "function",
          label .. " registerBallPalette missing")
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
            -- craftable: give it the apricorns the recipe wants
            game.save.inventory.BLK_APRICORN = 4
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

              -- A craft must have consumed apricorns and produced a ball
              local made = game.save.inventory.SNARE_BALL or 0
              check(made >= 1, label .. " craft produced no SNARE_BALL")
              check((game.save.inventory.BLK_APRICORN or 0) == 2,
                label .. " craft consumed the wrong apricorn count")

              -- THE FAILURE PATH THAT COSTS MATERIALS: a full pocket must
              -- consume nothing.
              local full = fakeGame()
              full.data.items = game.data.items
              full.save.inventory.BLK_APRICORN = 2
              rec.stubs["src.inventory.Bag"].add = function() return false end
              local okFull, s2 = pcall(newFn, full)
              if okFull and s2 then
                _G.__PRESS = "a"
                pcheck(label .. " case craft when pack full",
                  s2.update, s2)
                _G.__PRESS = nil
                check((full.save.inventory.BLK_APRICORN or 0) == 2,
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
