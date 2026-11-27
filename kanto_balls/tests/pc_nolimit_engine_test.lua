-- pc_nolimit_engine_test.lua -- lib/pc_nolimit.lua against the REAL engine
-- Bag and Gen 2 ItemPcMenu (the pre-phone save test the Desk asked for,
-- REQUESTS 1220, 2026-11-27).
--
--   cd engine && luajit ../Shop-Tools---Custom-Balls/kanto_balls/tests/pc_nolimit_engine_test.lua
--
-- Love stubs copied from engine/tests/gen2_pc_screens_test.lua.

package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.graphics = love.graphics or {
  getColor = function() return 1, 1, 1, 1 end, setColor = function() end,
  rectangle = function() end, print = function() end, printf = function() end,
  draw = function() end, newQuad = function() return {} end,
  newImage = function() return nil end, getShader = function() return nil end,
  setShader = function() end,
  newShader = function() error("no shaders in this harness") end,
  getDimensions = function() return 160, 144 end,
  push = function() end, pop = function() end,
  translate = function() end, scale = function() end,
  circle = function() end, clear = function() end,
  setLineWidth = function() end,
}
love.math = love.math or { random = function(a, b) if b then return a end return a and 1 or 0.5 end }
love.filesystem = love.filesystem or {
  load = function() return nil end, getInfo = function() return nil end,
  read = function() return nil end, write = function() return true end,
  remove = function() return true end,
}
love.timer = love.timer or { getTime = function() return 0 end }
require("src.core.Logger").warn = function() end
require("src.core.GameVersion").set("crystal")

local Bag = require("src.inventory.Bag")
local ItemPcMenu = require("src.ui.gen2.ItemPcMenu")
local Save = require("src.core.gen2.Save")

local here = (arg and arg[0] or ""):match("^(.*)[/\\]tests[/\\]") or "."
local PcNoLimit = dofile(here .. "/lib/pc_nolimit.lua")

local checks, failures = 0, {}
local function check(ok, what)
  checks = checks + 1
  if not ok then failures[#failures + 1] = what end
end

-- 60 kinds plus POTION, each a plain tossable ITEM.
local ITEMS = {}
for i = 1, 60 do
  local id = ("KB_ITEM_%02d"):format(i)
  ITEMS[id] = { id = id, name = id, pocket = "ITEM", index = i, canToss = true }
end
ITEMS.POTION = { id = "POTION", name = "POTION", pocket = "ITEM", index = 100, canToss = true }

local function newGame(save)
  return {
    input = { wasPressed = function() return false end, isDown = function() return false end },
    save = save,
    data = { audio = {}, pokemon = {}, items = ITEMS, field = {} },
    stack = { _items = {}, push = function() end, pop = function() end, top = function() end },
  }
end

local save = Save.newGame({ playerName = "KRIS", trainerId = 1 })
local game = newGame(save)

-- VANILLA first: the 51st kind is refused (proves the test sees the cap).
PcNoLimit.install(false)
local pc = ItemPcMenu.new(game, { save = save, items = ITEMS })
for i = 1, 50 do pc:pcAdd(("KB_ITEM_%02d"):format(i), 1) end
check(pc:pcAdd("KB_ITEM_51", 1) == false, "vanilla PC took a 51st kind (cap not seen)")

-- NO LIMIT.
PcNoLimit.install(true)
check(pc:pcAdd("KB_ITEM_51", 1) == true, "deposit refused the 51st kind")
for i = 52, 60 do pc:pcAdd(("KB_ITEM_%02d"):format(i), 1) end
check(pc:pcAdd("POTION", 150) == true, "deposit refused 150 of one item")
pc:rebuild()
check(#pc.rows == 62, ("list has %d rows, want 62 (60 kinds + POTION as 99 + 51)"):format(#pc.rows))

-- Scroll to the bottom (CANCEL) and back up to the last item.
pc.listIndex = pc:listTotal()
pc:ensureVisible()
check(pc.scroll > 0 and pc.scroll <= pc:listTotal(), "list did not scroll past 50")
local last = pc.rows[#pc.rows]
pc.listIndex = #pc.rows
pc:ensureVisible()
check(last ~= nil, "no last row")

-- Withdraw the 60th kind from the bottom of the list.
local row
for _, r in ipairs(pc.rows) do if r.id == "KB_ITEM_60" then row = r end end
check(row ~= nil, "KB_ITEM_60 not listed")
if row then
  pc:withdraw(row, 1)
  check((save.inventory.KB_ITEM_60 or 0) == 1, "withdraw did not reach the bag")
  check(save.pcItems.KB_ITEM_60 == nil, "withdraw left the item in the PC")
end
-- Withdraw part of the 150 POTIONs.
local potion
for _, r in ipairs(pc.rows) do if r.id == "POTION" then potion = r break end end
if potion then
  pc:withdraw(potion, 10)
  check(save.pcItems.POTION == 140 and save.inventory.POTION == 10,
    ("POTION withdraw: pc %s bag %s"):format(tostring(save.pcItems.POTION), tostring(save.inventory.POTION)))
end

-- Bag.pcAdd (Mom, the overflow helper): past 50 kinds and past 99 of one id.
check(Bag.pcAdd(save, "KB_ITEM_60", 1, game.data, 50) == true, "Bag.pcAdd refused a kind past 50")
check(Bag.pcAdd(save, "POTION", 99, game.data, 50) == true, "Bag.pcAdd refused past 99 of one id")
check(save.pcItems.POTION == 239, "Bag.pcAdd POTION count wrong: " .. tostring(save.pcItems.POTION))

-- Off again restores the engine's own functions.
PcNoLimit.install(false)
-- A brand-new kind needs a slot, and the PC already holds over 50.
ITEMS.KB_NEW = { id = "KB_NEW", name = "KB_NEW", pocket = "ITEM", index = 101, canToss = true }
check(Bag.pcAdd(save, "KB_NEW", 1, game.data, 50) == false, "Bag.pcAdd cap not restored")
check(pc:pcAdd("KB_NEW", 1) == false, "deposit cap not restored")

if #failures == 0 then
  print(("pc_nolimit_engine_test: %d checks, 0 failures"):format(checks))
else
  print(("pc_nolimit_engine_test: %d checks, %d failures"):format(checks, #failures))
  for _, f in ipairs(failures) do print("  FAIL " .. f) end
  os.exit(1)
end
