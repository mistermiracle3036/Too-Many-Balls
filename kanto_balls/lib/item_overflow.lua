-- item_overflow.lua -- give an item to the Bag, and when the Bag has no room, to the player's PC.
--
-- MASTER: gen1recomp-work/exchange/shared/item_overflow.lua (owner: the Checker, REQUESTS 1032).
-- Copy this file into your mod BYTE FOR BYTE (e.g. lib/item_overflow.lua). Never edit your copy; ask the
-- Checker to change the master. Rule: exchange/decisions/2026-11-19-item-overflow-goes-to-the-pc.md
-- (developer 2026-11-19: "Send to PC can be general rule for what to do with item overflow").
-- First use, which this file is lifted from: Cherrygrove-Stantler/main.lua giveUltraBall (0.4.3, REQUESTS 1004).
--
-- ENGINE FACTS (engine v0.4.0, read 2026-11-20)
--   Bag:  src.inventory.Bag.add(save, id, qty, data) -> true | false. Only the item's OWN pocket needs room
--         (Bag.lua:443-460); nothing is added on false.
--   PC:   src.inventory.Bag.pcAdd(save, id, qty, data, cap) -> true | false, over save.pcItems
--         (Bag.lua:402-410). The engine's own deposit passes cap = game.data.field.pcItemCap or 50 (Gen 1
--         src/ui/PlayerPC.lua:169-172; Gen 2 MomShopping.lua:167, the PC half of ReceiveItem). Gen 1 and Gen 2
--         read the same save.pcItems, so one call covers Red, Gold, Silver and Crystal.
--   Gen 3 keeps its PC items elsewhere (src/core/game3/storage.lua); this helper does NOT touch it there and
--   returns nil, "gen3". TODO/CONFIRM if a Gen 3 mod needs it.
--
-- USE
--   local Overflow = <load this file the way your mod loads its other files>
--   if mod.save:get("my_reward_paid", false) ~= true then
--     local where = Overflow.give(mod, "ULTRA_BALL", 1)
--     if where then mod.save:set("my_reward_paid", true) end     -- set the paid flag IN THE SAME STEP
--     if where == "pc" then lines[#lines + 1] = Overflow.LINE end -- "No room. It went\nto your PC."
--     -- where == nil: neither had room (or no save yet). Nothing was added and the flag stays unset, so
--     -- the gift is still owed; retrying on a later map.entered is how Cherrygrove Stantler pays it.
--   end
--   With gift_jingle.lua: call Overflow.give first, then Gift.say(mod, itemId, line) for the jingle line.
--
-- API
--   Overflow.give(mod, itemId, count) -> "bag" | "pc" | nil, why
--     why is "no save", "gen3" or "full" (Bag and PC both refused). Never adds twice: it adds to the Bag
--     OR the PC, never both, and never sets your flags.
--   Overflow.LINE  the model line, 18 columns x 2 lines (decision file): "No room. It went\nto your PC."
--
-- LIMITS (decision file): key items and one-of-a-kind quest items the next beat needs in the Bag, and a
-- full PC, are NOT decided -- ask the developer, never drop silently. An approved full-Bag behaviour stays
-- until its owner asks the developer.

local Bag = require("src.inventory.Bag")
local GameVersion = require("src.core.GameVersion")

local Overflow = {}

Overflow.LINE = "No room. It went\nto your PC."

function Overflow.give(mod, itemId, count)
  local game = mod and mod.game
  local save = game and game.save
  if not (save and game.data) then return nil, "no save" end
  if GameVersion.generation() == 3 then return nil, "gen3" end
  count = count or 1
  local ok, added = pcall(Bag.add, save, itemId, count, game.data)
  if ok and added then return "bag" end
  local cap = (game.data.field and game.data.field.pcItemCap) or 50
  ok, added = pcall(Bag.pcAdd, save, itemId, count, game.data, cap)
  if ok and added then return "pc" end
  return nil, "full"
end

return Overflow
